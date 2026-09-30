import {readFile} from 'node:fs/promises';
import path from 'node:path';
import {openDb,root,stringify} from './db.mjs';
const args=process.argv.slice(2);
if(!args.length) {
 console.error('Usage: node scripts/query.mjs sql/analysis/02_monthly_growth.sql\n       node scripts/query.mjs --sql "SELECT COUNT(*) FROM core.orders"');
 process.exit(1);
}
const sql=args[0]==='--sql'?args.slice(1).join(' '):await readFile(path.resolve(root,args[0]),'utf8');
const db=await openDb(true);
try {
 await db.exec('BEGIN TRANSACTION READ ONLY');
 const results=await db.exec(sql);
 for(const result of results) if(result.fields.length) console.log(stringify(result.rows));
 await db.exec('ROLLBACK');
} finally {await db.close();}
