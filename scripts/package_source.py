"""Build a shareable source ZIP without raw data, database or dependencies."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
output = root.parent / 'olist-sql-analytics-source.zip'
files = [p for p in root.iterdir() if p.is_file() and p.name != '.DS_Store']
files += [root / 'data' / 'manifest.json']
for folder in ('sql', 'scripts', 'docs', 'results'):
    files += [p for p in (root / folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts]
with ZipFile(output, 'w', ZIP_DEFLATED) as archive:
    for file in sorted(files):
        archive.write(file, str(Path(root.name) / file.relative_to(root)))
with ZipFile(output) as archive:
    names = archive.namelist()
    assert not any('/data/raw/' in n or '/vendor/' in n or 'local-db.tar.gz' in n for n in names)
    assert archive.testzip() is None
print(f'Created {output.name}: {len(names)} files, {output.stat().st_size:,} bytes')
