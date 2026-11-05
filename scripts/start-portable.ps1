# Compatibility entry point for existing Windows associations. Uses the native
# profile; launching a document never resets settings or installs extensions.
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$LibreOfficeArgs,
    [switch]$ResetProfile,
    [switch]$PrintCommand
)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Use lo-settings.py open on macOS/Linux.' }
if ($ResetProfile) { throw 'Profile deletion is no longer supported. Run restore.ps1 to merge settings safely. Existing portable-profile data was preserved.' }
$candidates = @()
if ($env:LIBREOFFICE_PROGRAM) { $candidates += $env:LIBREOFFICE_PROGRAM }
foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA)) {
    if ($base) { $candidates += Join-Path $base 'LibreOffice\program\soffice.exe' }
}
$command = Get-Command soffice.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($command) { $candidates += $command.Source }
$soffice = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $soffice) { throw 'Install LibreOffice or set LIBREOFFICE_PROGRAM to soffice.exe.' }
$launchArgs = @('--nologo')
foreach ($arg in $LibreOfficeArgs) {
    $file = $arg
    if ($arg -match '^file:') { $file = ([Uri]$arg).LocalPath }
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Document not found: $arg" }
    $launchArgs += ([Uri](Resolve-Path -LiteralPath $file).ProviderPath).AbsoluteUri
}
if ($PrintCommand) {
    Write-Output $soffice
    $launchArgs | Write-Output
    exit 0
}
# Each file is a URI, so whitespace/quotes cannot split arguments in Start-Process.
Start-Process -FilePath $soffice -ArgumentList $launchArgs
