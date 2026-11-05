$ErrorActionPreference = 'Stop'
$python = Get-Command py -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($python) {
    & $python.Source -3 (Join-Path $PSScriptRoot 'scripts/setup.py')
} else {
    $python = Get-Command python -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $python) { throw 'Install Python 3.9 or newer, then rerun Setup.ps1.' }
    & $python.Source (Join-Path $PSScriptRoot 'scripts/setup.py')
}
if ($LASTEXITCODE -ne 0) { throw "LibreOffice setup failed (exit $LASTEXITCODE)." }
