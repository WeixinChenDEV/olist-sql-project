import {readFile,writeFile,readdir} from 'node:fs/promises';
import path from 'node:path';
import {root,stringify} from './db.mjs';
const results=JSON.parse(await readFile(path.join(root,'results/analysis_bundle.json'),'utf8'));
const validation=JSON.parse(await readFile(path.join(root,'results/validation.json'),'utf8'));
const optimization=JSON.parse(await readFile(path.join(root,'results/query_optimization.json'),'utf8'));
const queries=[];
for(const file of (await readdir(path.join(root,'sql/analysis'))).filter(f=>f.endsWith('.sql')).sort())
 queries.push({name:file,sql:await readFile(path.join(root,'sql/analysis',file),'utf8')});
await writeFile(path.join(root,'docs/report-data.js'),'const REPORT_DATA = '+stringify({results,validation,optimization,queries})+';\n');
console.log('Updated offline report and SQL examples.');
