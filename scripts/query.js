import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { openDatabase, projectFolder } from './database.js';

const file = process.argv[2];
if (!file) {
    console.error('Usage: node scripts/query.js sql/02_monthly_sales.sql');
    process.exit(1);
}

const sql = await readFile(path.resolve(projectFolder, file), 'utf8');
const db = await openDatabase(true);
try {
    await db.exec('BEGIN READ ONLY');
    const result = await db.query(sql);
    console.table(result.rows);
    await db.exec('ROLLBACK');
} finally {
    await db.close();
}
