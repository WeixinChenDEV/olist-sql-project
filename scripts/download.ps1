$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$rawDir = Join-Path $projectRoot 'data/raw'
$vendorDir = Join-Path $projectRoot 'vendor'
New-Item -ItemType Directory -Force -Path $rawDir,$vendorDir | Out-Null
$manifest = Get-Content -LiteralPath (Join-Path $projectRoot 'data/files.json') -Raw | ConvertFrom-Json
$archivePath = Join-Path $rawDir 'olist.zip'
if (-not (Test-Path -LiteralPath $archivePath)) {
    Invoke-WebRequest -Uri $manifest.download_url -OutFile $archivePath
}
if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest.archive_sha256) {
    throw 'The Olist download does not match the pinned source snapshot. Check the source before updating files.json.'
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    foreach ($file in $manifest.files) {
        $entry = $zip.GetEntry($file.file)
        if ($null -eq $entry) { throw "Missing archive entry: $($file.file)" }
        # Only exact, manifest-listed basenames are written inside data/raw.
        if ([System.IO.Path]::GetFileName($file.file) -ne $file.file) { throw 'Unsafe manifest path' }
        $csvPath = Join-Path $rawDir $file.file
        if (-not (Test-Path -LiteralPath $csvPath)) {
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$csvPath,$false)
        }
        if ((Get-FileHash -LiteralPath $csvPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $file.sha256) {
            throw "Source hash mismatch: $($file.file)"
        }
    }
} finally { $zip.Dispose() }

$runtimePath = Join-Path $vendorDir 'pglite/package/dist/index.js'
if (-not (Test-Path -LiteralPath $runtimePath)) {
    $packagePath = Join-Path $vendorDir 'pglite-0.5.8.tgz'
    if (-not (Test-Path -LiteralPath $packagePath)) {
        Invoke-WebRequest -Uri 'https://registry.npmjs.org/@electric-sql/pglite/-/pglite-0.5.8.tgz' -OutFile $packagePath
    }
    $sha = [System.Security.Cryptography.SHA512]::Create()
    try { $actual = [Convert]::ToBase64String($sha.ComputeHash([IO.File]::ReadAllBytes($packagePath))) }
    finally { $sha.Dispose() }
    if ($actual -ne 'n9tsbUOhwx2epK1V0ZG9Ar4SHWUju04dhmzZXiSBXwBoleOvIfals33NAaWgagQVAL4Rbvx/Ptsu3P+pA09f6Q==') {
        throw 'PGlite package integrity mismatch'
    }
    $members = & tar -tzf $packagePath
    if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect runtime package' }
    foreach ($member in $members) {
        if (-not $member.StartsWith('package/') -or $member.Split('/') -contains '..') { throw 'Unsafe runtime archive path' }
    }
    $extractDir = Join-Path $vendorDir 'pglite'
    New-Item -ItemType Directory -Force -Path $extractDir | Out-Null
    & tar -xzf $packagePath -C $extractDir
    if ($LASTEXITCODE -ne 0) { throw 'Runtime extraction failed' }
}
Write-Host 'Data files are ready.'
