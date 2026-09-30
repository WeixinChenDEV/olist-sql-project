import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
export const root = fileURLToPath(new URL('../', import.meta.url));
export async function openDb(saved=false) {
  let module;
  try { module = await import('@electric-sql/pglite'); }
  catch (e) {
    if(e.code !== 'ERR_MODULE_NOT_FOUND') throw e;
    module = await import('../vendor/pglite/package/dist/index.js');
  }
  // Source timestamps have no declared timezone; do not invent UTC via JS Date.
  const opts = {parsers:{1082:v=>v,1114:v=>v}};
  if(saved) opts.loadDataDir=new Blob([await readFile(path.join(root,'data/local-db.tar.gz'))]);
  return module.PGlite.create(opts);
}
export const readSql = name => readFile(path.join(root,'sql',name),'utf8');
export const stringify = value => JSON.stringify(value,(_key,v)=>typeof v==='bigint'?v.toString():v,2);
export function toCsv(rows,fields) {
  const quote = value => {
    if(value===null || value===undefined) return '';
    const s=value instanceof Date?value.toISOString():String(value);
    return /[",\r\n]/.test(s)?'"'+s.replaceAll('"','""')+'"':s;
  };
  return [fields.map(quote).join(','),...rows.map(r=>fields.map(f=>quote(r[f])).join(','))].join('\n')+'\n';
}
