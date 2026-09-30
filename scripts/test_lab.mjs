// Integration checks against the actual running local SQL lab.
import {writeFile} from 'node:fs/promises';
import path from 'node:path';
import {root,stringify} from './db.mjs';
const base=process.env.OLIST_LAB_URL||'http://127.0.0.1:8765';
const page=await (await fetch(base)).text();
const token=page.match(/const sessionToken='([a-f0-9]+)'/)[1];
const checks=[];
const check=(name,passed)=>{checks.push({name,passed});if(!passed)throw Error(name);};
async function query(sql,auth=token) {
 const response=await fetch(base+'/api/query',{method:'POST',headers:{'Content-Type':'application/json','X-Olist-Token':auth},body:JSON.stringify({sql})});
 return {status:response.status,body:await response.json()};
}
try {
 let r=await query('SELECT COUNT(*) AS orders FROM core.orders');
 check('saved_database_loaded',r.status===200&&Number(r.body.rows[0].orders)===99441);
 r=await query('SELECT 1; SELECT 2');
 check('multiple_statements_rejected',r.status===400);
 r=await query("WITH changed AS (DELETE FROM core.orders RETURNING order_id) SELECT * FROM changed");
 check('write_in_cte_rejected',r.status===400&&/read.only/i.test(r.body.error));
 r=await query('SELECT COUNT(*) AS orders FROM core.orders');
 check('rollback_preserves_data_and_recovers_session',r.status===200&&Number(r.body.rows[0].orders)===99441);
 r=await query('SELECT 1','invalid');
 check('session_token_required',r.status===403);
 r=await query('SELECT * FROM core.orders LIMIT 501');
 check('display_row_cap',r.status===200&&r.body.total_rows===501&&r.body.rows.length===500);
 r=await query("SELECT COUNT(*) AS n FROM core.orders WHERE purchased_at >= TIMESTAMP '2018-01-15' AND purchased_at < TIMESTAMP '2018-01-16'");
 check('indexed_date_query_result',r.status===200&&Number(r.body.rows[0].n)===307);
 await writeFile(path.join(root,'results/lab_validation.json'),stringify({status:'passed',checks})+'\n');
 console.log(`PASS: ${checks.length} SQL lab integration checks.`);
}catch(error){await writeFile(path.join(root,'results/lab_validation.json'),stringify({status:'failed',checks,error:error.message}));throw error;}
