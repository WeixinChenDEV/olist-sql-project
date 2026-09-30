// Local read-only SQL lab. Only fixed project assets are exposed, no directory browsing.
import http from 'node:http';
import {readFile} from 'node:fs/promises';
import {randomBytes} from 'node:crypto';
import path from 'node:path';
import {openDb,root,stringify} from './db.mjs';
const db=await openDb(true);
const token=randomBytes(24).toString('hex');
const port=Number(process.env.OLIST_PORT||8765);
let queue=Promise.resolve();
const assets={'/':'index.html','/index.html':'index.html','/report-data.js':'report-data.js'};
const server=http.createServer(async(req,res)=>{
 const send=(status,body,type='application/json')=>{res.writeHead(status,{'Content-Type':type+'; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(body);};
 try {
  if(req.method==='GET' && assets[req.url]) {
   const content=(await readFile(path.join(root,'docs',assets[req.url]),'utf8')).replace('__SESSION_TOKEN__',token);
   return send(200,content,req.url.endsWith('.js')?'text/javascript':'text/html');
  }
  if(req.method!=='POST'||req.url!=='/api/query') return send(404,stringify({error:'Not found'}));
  if(req.headers['x-olist-token']!==token) return send(403,stringify({error:'Invalid session token'}));
  let body='';
  for await(const chunk of req) {body+=chunk;if(body.length>20000) return send(413,stringify({error:'Query too long'}));}
  const {sql}=JSON.parse(body);
  if(typeof sql!=='string'||!/^\s*(?:(?:--[^\n]*\n)|\s)*(SELECT|WITH|EXPLAIN)\b/i.test(sql))
   return send(400,stringify({error:'Use one SELECT, WITH or EXPLAIN statement.'}));
  const run=async()=>{
   const started=performance.now();
   const result=await db.transaction(async tx=>{
    await tx.exec("SET TRANSACTION READ ONLY; SET LOCAL statement_timeout='10s';");
    return tx.query(sql);
   });
   return {fields:result.fields.map(f=>f.name),rows:result.rows.slice(0,500),
    total_rows:result.rows.length,elapsed_ms:Math.round(performance.now()-started)};
  };
  const task=queue.then(run); queue=task.catch(()=>{});
  return send(200,stringify(await task));
 } catch(error) {return send(400,stringify({error:error.message}));}
});
server.listen(port,'127.0.0.1',()=>console.log(`Olist SQL lab: http://127.0.0.1:${port} (Ctrl+C to stop)`));
server.on('error',async error=>{console.error(error.message);await db.close();process.exitCode=1;});
process.on('SIGINT',()=>server.close(async()=>{await db.close();process.exit(0);}));
