param([string]$Node = 'node', [string]$SqlFile = '')
$ErrorActionPreference = 'Stop'

if ($SqlFile) {
    & $Node (Join-Path $PSScriptRoot 'scripts/query.js') $SqlFile
} else {
    & (Join-Path $PSScriptRoot 'scripts/download.ps1')
    & $Node (Join-Path $PSScriptRoot 'scripts/run.js')
}
if ($LASTEXITCODE -ne 0) { throw 'The project did not finish. See the error above.' }
