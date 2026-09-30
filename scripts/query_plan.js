// Compare the same date filter before and after adding an index.
import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { projectFolder } from './database.js';

export async function comparePlans(db) {
    const dateFilter = "SELECT COUNT(*) FROM core.orders WHERE purchased_at::date = DATE '2018-01-15'";
    const rangeFilter = `
        SELECT COUNT(*) FROM core.orders
        WHERE purchased_at >= TIMESTAMP '2018-01-15'
          AND purchased_at < TIMESTAMP '2018-01-16'
    `;
    const results = [];

    async function measure(name, query) {
        const count = (await db.query(query)).rows[0].count;
        const plans = [];
        for (let run = 0; run < 3; run++) {
            const result = await db.query('EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) ' + query);
            plans.push(result.rows[0]['QUERY PLAN'][0]);
        }
        const times = plans.map(plan => plan['Execution Time']).sort((a, b) => a - b);
        results.push({ name, count, median_ms: times[1], plans });
    }

    await measure('date_cast', dateFilter);
    await measure('date_range', rangeFilter);
    await db.exec(await readFile(path.join(projectFolder, 'sql/indexes.sql'), 'utf8'));
    await measure('date_range_with_index', rangeFilter);

    if (!results.every(result => String(result.count) === String(results[0].count))) {
        throw new Error('The date filters returned different counts');
    }
    await writeFile(path.join(projectFolder, 'results/query_plans.json'), JSON.stringify(results, null, 2));
}
