param([switch]$Query,[switch]$Serve,[string]$SqlFile='sql/analysis/02_monthly_growth.sql')
$ErrorActionPreference = 'Stop'
$nodeCommand = Get-Command node -ErrorAction SilentlyContinue
$nodePath = if ($nodeCommand) { $nodeCommand.Source } else {
    Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe'
}
if (-not (Test-Path -LiteralPath $nodePath)) { throw 'Node.js 20+ is required. Install Node.js, then rerun this script.' }
if ($Serve) { & $nodePath (Join-Path $PSScriptRoot 'scripts/serve.mjs') }
elseif ($Query) { & $nodePath (Join-Path $PSScriptRoot 'scripts/query.mjs') $SqlFile }
else {
    & (Join-Path $PSScriptRoot 'scripts/bootstrap.ps1')
    & $nodePath (Join-Path $PSScriptRoot 'scripts/run.mjs')
    if ($LASTEXITCODE -ne 0) { throw "Build failed (exit $LASTEXITCODE)" }
    & $nodePath (Join-Path $PSScriptRoot 'scripts/generate-report.mjs')
}
if ($LASTEXITCODE -ne 0) { throw "Project command failed (exit $LASTEXITCODE)" }
