param(
    [string]$IniPath = 'C:\Program Files\LibreOffice\program\soffice.ini',
    [switch]$NoSelfElevate
)

$ErrorActionPreference = 'Stop'

if (-not ($IsWindows -or $env:OS -eq 'Windows_NT')) {
    throw 'This script applies only on Windows.'
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    if ($NoSelfElevate) {
        throw 'Administrator rights are required to edit LibreOffice soffice.ini.'
    }

    $argLine = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -IniPath "{1}" -NoSelfElevate' -f $PSCommandPath, $IniPath
    Start-Process -FilePath 'powershell.exe' -ArgumentList $argLine -Verb RunAs -Wait -WindowStyle Hidden
    exit
}

if (-not (Test-Path -LiteralPath $IniPath)) {
    throw "LibreOffice soffice.ini not found: $IniPath"
}

$repo = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$backupDir = Join-Path $repo 'windows/soffice.ini-backups'
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $backupDir "soffice.ini.$timestamp.bak"
Copy-Item -LiteralPath $IniPath -Destination $backup -Force

$content = Get-Content -LiteralPath $IniPath
if ($content -match '^Logo=') {
    $content = $content -replace '^Logo=.*', 'Logo=0'
} else {
    $content += 'Logo=0'
}

Set-Content -LiteralPath $IniPath -Value $content -Encoding ASCII
Write-Host "Set Logo=0 in: $IniPath"
Write-Host "Backup: $backup"
Write-Host 'Done. No shortcuts were created.'
