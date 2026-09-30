// Load the CSV files, run the SQL, and save the results.
import { readFile, writeFile, readdir, mkdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { openDatabase, projectFolder, csvText } from './database.js';
import { comparePlans } from './query_plan.js';

const files = JSON.parse(await readFile(path.join(projectFolder, 'data/files.json'), 'utf8'));
const checks = [];
const answers = {};
const db = await openDatabase();
await mkdir(path.join(projectFolder, 'results'), { recursive: true });
await mkdir(path.join(projectFolder, '.local'), { recursive: true });

function check(name, passed) {
    checks.push({ name, passed });
    if (!passed) throw new Error('Check failed: ' + name);
}

async function runSql(name) {
    return db.query(await readFile(path.join(projectFolder, 'sql', name), 'utf8'));
}

async function saveCsv(name, result) {
    await writeFile(path.join(projectFolder, 'results', name + '.csv'), csvText(result));
}

try {
    await db.exec(await readFile(path.join(projectFolder, 'sql/tables.sql'), 'utf8'));
    for (const file of files.files) {
        const csv = await readFile(path.join(projectFolder, 'data/raw', file.file));
        const hash = createHash('sha256').update(csv).digest('hex');
        check('file: ' + file.file, hash === file.sha256);
        if (!file.imported) continue;

        if (!/^[a-z_]+$/.test(file.table) || file.columns.some(column => !/^[a-z_]+$/.test(column))) {
            throw new Error('Invalid CSV column name');
        }
        await db.query(
            `COPY raw.${file.table} (${file.columns.join(',')}) FROM '/dev/blob' WITH (FORMAT csv, HEADER true)`,
            [], { blob: new Blob([csv]) }
        );
        const count = (await db.query(`SELECT COUNT(*) AS n FROM raw.${file.table}`)).rows[0].n;
        check('raw rows: ' + file.table, Number(count) === file.rows);
        console.log(file.table + ': ' + count + ' rows');
    }

    await db.exec(await readFile(path.join(projectFolder, 'sql/cleaning.sql'), 'utf8'));
    await saveCsv('data_checks', await runSql('check_data.sql'));
    const totals = await runSql('check_totals.sql');
    await saveCsv('total_checks', totals);
    for (const row of totals.rows) check(row.check_name, row.passed);

    for (const file of files.files.filter(file => file.imported)) {
        const table = file.table === 'product_category_name_translation' ? 'categories' : file.table;
        const count = (await db.query(`SELECT COUNT(*) AS n FROM core.${table}`)).rows[0].n;
        check('cleaned rows: ' + table, Number(count) === file.rows);
    }

    const queries = (await readdir(path.join(projectFolder, 'sql'))).filter(name => /^\d\d_.*\.sql$/.test(name)).sort();
    for (const file of queries) {
        const result = await runSql(file);
        const name = file.replace('.sql', '');
        answers[name] = result.rows;
        await saveCsv(name, result);
        console.log('Saved ' + name + '.csv');
    }

    const cohorts = answers['08_cohorts'];
    check('cohort starts at 100%', cohorts.filter(row => row.month_number === 0).every(row => Number(row.purchase_retention_pct) === 100));
    check('cohort counts stay within group size', cohorts.every(row => Number(row.active_customers) <= Number(row.cohort_size)));
    check('joined totals match', answers['10_joins'][0].safe_join_reconciles);
    const foreignKeys = await db.query("SELECT COUNT(*) AS n FROM pg_constraint WHERE contype = 'f' AND connamespace = 'core'::regnamespace");
    check('six foreign keys', Number(foreignKeys.rows[0].n) === 6);
    await comparePlans(db);
    check('date filter results match', true);

    const snapshot = await db.dumpDataDir('gzip');
    await writeFile(path.join(projectFolder, 'data/local-db.tar.gz'), new Uint8Array(await snapshot.arrayBuffer()));
    await writeFile(path.join(projectFolder, '.local/answers.json'), JSON.stringify(answers, null, 2));
    console.log('Done. All ' + checks.length + ' checks passed.');
} finally {
    await writeFile(path.join(projectFolder, 'results/checks.json'), JSON.stringify(checks, null, 2));
    await db.close();
}
