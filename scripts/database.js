import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

export const projectFolder = fileURLToPath(new URL('../', import.meta.url));

export async function openDatabase(useSavedData = false) {
    let PGlite;
    try {
        ({ PGlite } = await import('@electric-sql/pglite'));
    } catch (error) {
        if (error.code !== 'ERR_MODULE_NOT_FOUND') throw error;
        ({ PGlite } = await import('../vendor/pglite/package/dist/index.js'));
    }

    // Keep dates as strings: the source does not specify a time zone.
    const options = { parsers: { 1082: value => value, 1114: value => value } };
    if (useSavedData) {
        const savedData = await readFile(path.join(projectFolder, 'data/local-db.tar.gz'));
        options.loadDataDir = new Blob([savedData]);
    }
    return PGlite.create(options);
}

export function csvText(result) {
    const columns = result.fields.map(field => field.name);
    function cell(value) {
        if (value === null || value === undefined) return '';
        const text = String(value);
        return /[",\r\n]/.test(text) ? '"' + text.replaceAll('"', '""') + '"' : text;
    }
    const rows = result.rows.map(row => columns.map(column => cell(row[column])).join(','));
    return [columns.join(','), ...rows].join('\n') + '\n';
}
