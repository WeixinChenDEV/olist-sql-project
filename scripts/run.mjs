// Node only orchestrates IO; all cleaning, metrics and diagnostics run in SQL.
import {readFile,writeFile,readdir,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import path from 'node:path';
import {openDb,root,readSql,stringify,toCsv} from './db.mjs';

const started=performance.now();
const manifest=JSON.parse(await readFile(path.join(root,'data/manifest.json'),'utf8'));
await mkdir(path.join(root,'results'),{recursive:true});
const checks=[];
const analyses={};
const db=await openDb();
async function exportResult(name,result) {
  await writeFile(path.join(root,'results',name+'.json'),stringify(result.rows)+'\n');
  await writeFile(path.join(root,'results',name+'.csv'),toCsv(result.rows,result.fields.map(f=>f.name)));
}
const assert=(name,passed,detail={})=>{
  checks.push({check_name:name,passed,...detail});
  if(!passed) throw new Error('Validation failed: '+name);
};
try {
  console.log('Engine:',(await db.query('SELECT version() AS version')).rows[0].version);
  await db.exec(await readSql('01_raw.sql'));
  for(const file of manifest.files) {
    const bytes=await readFile(path.join(root,'data/raw',file.file));
    assert('source_hash:'+file.file,createHash('sha256').update(bytes).digest('hex')===file.sha256);
    if(!file.imported) continue;
    // Identifiers are manifest-generated and checked, never user SQL interpolation.
    if(!/^[a-z_]+$/.test(file.table)||file.columns.some(c=>!/^[a-z_]+$/.test(c))) throw new Error('Invalid identifier');
    await db.query(`COPY raw.${file.table} (${file.columns.join(',')}) FROM '/dev/blob' WITH (FORMAT csv,HEADER true,ENCODING 'UTF8')`,[],{blob:new Blob([bytes])});
    const count=Number((await db.query(`SELECT COUNT(*) AS n FROM raw.${file.table}`)).rows[0].n);
    assert('import_count:'+file.table,count===file.rows,{expected:file.rows,actual:count});
    console.log(`Imported ${file.table}: ${count.toLocaleString()} rows`);
  }
  await db.exec(await readSql('02_model.sql'));
  const audit=await db.query(await readSql('03_quality_audit.sql'));
  await exportResult('quality_audit',audit);
  const validation=await db.query(await readSql('04_validate.sql'));
  for(const row of validation.rows) assert(row.check_name,row.passed);
  for(const file of manifest.files.filter(f=>f.imported)) {
    const table=file.table==='product_category_name_translation'?'categories':file.table;
    const count=Number((await db.query(`SELECT COUNT(*) AS n FROM core.${table}`)).rows[0].n);
    assert('core_count:'+table,count===file.rows,{expected:file.rows,actual:count});
  }
  const files=(await readdir(path.join(root,'sql/analysis'))).filter(f=>f.endsWith('.sql')).sort();
  for(const file of files) {
    const result=await db.query(await readSql('analysis/'+file));
    const name=file.replace('.sql','');
    await exportResult(name,result); analyses[name]=result.rows;
    console.log(`Analysis ${name}: ${result.rows.length} result rows`);
  }
  const cohort=analyses['08_purchase_cohorts'];
  assert('cohort_month_zero_100pct',cohort.filter(r=>r.month_number===0).every(r=>Number(r.purchase_retention_pct)===100));
  assert('cohort_counts_within_size',cohort.every(r=>Number(r.active_customers)<=Number(r.cohort_size)));
  assert('safe_join_demo_reconciles',analyses['10_join_fanout_demo'][0].safe_join_reconciles);
  // Referential integrity is enforced on the full source with real FKs, not just sampled checks.
  assert('foreign_keys_present',Number((await db.query("SELECT COUNT(*) AS n FROM pg_constraint WHERE contype='f' AND connamespace='core'::regnamespace")).rows[0].n)===6);

  // Query optimization: warm each stage, then store three ANALYZE/BUFFERS plans.
  const castQuery="SELECT COUNT(*) FROM core.orders WHERE purchased_at::date=DATE '2018-01-15'";
  const rangeQuery="SELECT COUNT(*) FROM core.orders WHERE purchased_at>=TIMESTAMP '2018-01-15' AND purchased_at<TIMESTAMP '2018-01-16'";
  const perf=[];
  async function measure(label,sql) {
    const count=(await db.query(sql)).rows[0].count;
    const plans=[];
    for(let i=0;i<3;i++) plans.push((await db.query('EXPLAIN (ANALYZE,BUFFERS,FORMAT JSON) '+sql)).rows[0]['QUERY PLAN'][0]);
    const times=plans.map(p=>p['Execution Time']).sort((a,b)=>a-b);
    perf.push({stage:label,sql,result_count:count,median_execution_ms:times[1],plans});
  }
  await measure('01_cast_no_index',castQuery);
  await measure('02_range_no_index',rangeQuery);
  await db.exec(await readSql('05_indexes.sql'));
  await measure('03_range_with_index',rangeQuery);
  assert('optimization_results_identical',perf.every(p=>String(p.result_count)===String(perf[0].result_count)));
  await writeFile(path.join(root,'results/query_optimization.json'),stringify(perf)+'\n');

  const snapshot=await db.dumpDataDir('gzip');
  await writeFile(path.join(root,'data/local-db.tar.gz'),new Uint8Array(await snapshot.arrayBuffer()));
  await writeFile(path.join(root,'results/analysis_bundle.json'),stringify(analyses)+'\n');
  await writeFile(path.join(root,'results/validation.json'),stringify({
    status:'passed',engine:(await db.query('SELECT version() AS version')).rows[0].version,
    runtime:'PGlite 0.5.8 / Node.js',generated_at:new Date().toISOString(),
    analysis_queries:files.length,checks,elapsed_seconds:Number(((performance.now()-started)/1000).toFixed(2))
  })+'\n');
  console.log(`PASS: ${checks.length} checks; ${files.length} analysis queries. Database saved.`);
} catch(error) {
  await writeFile(path.join(root,'results/validation.json'),stringify({status:'failed',checks,error:error.message})+'\n');
  throw error;
} finally {await db.close();}
