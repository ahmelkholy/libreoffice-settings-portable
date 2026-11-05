param(
    [switch]$Replace,
    [switch]$Merge,
    [switch]$WindowsNoLogo
)
$ErrorActionPreference = 'Stop'
if ($Replace -and $Merge) { throw 'Choose either -Replace or -Merge, not both.' }
$repo = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$isWindowsHost = $env:OS -eq 'Windows_NT'
if ($WindowsNoLogo -and -not $isWindowsHost) { throw '-WindowsNoLogo is Windows-only.' }
$names = if ($isWindowsHost) { @('py', 'python', 'python3') } else { @('python3', 'python') }
$python = $null
foreach ($name in $names) {
    $candidate = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($candidate) { $python = $candidate; break }
}
if (-not $python) { throw 'Python 3.9 or newer is required. Install Python, then rerun this script.' }
$arguments = @()
if ($python.Name -match '^py(\.exe)?$') { $arguments += '-3' }
$arguments += @((Join-Path $repo 'scripts/lo-settings.py'), 'apply')
if ($Replace) { $arguments += '--replace' }
& $python.Source @arguments
if ($LASTEXITCODE -ne 0) { throw "Settings apply failed (exit $LASTEXITCODE)." }
if ($WindowsNoLogo) { & (Join-Path $repo 'scripts/apply-windows-nologo-associations.ps1') }
