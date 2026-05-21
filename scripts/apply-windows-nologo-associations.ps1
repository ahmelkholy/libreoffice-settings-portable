param(
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'

if (-not ($IsWindows -or $env:OS -eq 'Windows_NT')) {
    throw 'This script applies only on Windows.'
}

$repo = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$backupDir = Join-Path $repo 'windows'
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupPath = Join-Path $backupDir "backup-file-associations-$timestamp.json"

$classes = Get-ChildItem Registry::HKEY_CLASSES_ROOT -ErrorAction SilentlyContinue |
    Where-Object { $_.PSChildName -like 'LibreOffice.*.1' } |
    Sort-Object PSChildName

$backup = foreach ($classKey in $classes) {
    $class = $classKey.PSChildName
    $hkcu = "HKCU:\Software\Classes\$class\shell\open\command"
    $hkcr = "Registry::HKEY_CLASSES_ROOT\$class\shell\open\command"

    $current = $null
    if (Test-Path -LiteralPath $hkcu) {
        $current = (Get-Item -LiteralPath $hkcu).GetValue('')
    } elseif (Test-Path -LiteralPath $hkcr) {
        $current = (Get-Item -LiteralPath $hkcr).GetValue('')
    }

    if ($current) {
        [pscustomobject]@{
            class = $class
            commandBefore = $current
        }
    }
}

$backup | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $backupPath -Encoding UTF8
Write-Host "Backup: $backupPath"

foreach ($entry in $backup) {
    $class = $entry.class
    $hkcu = "HKCU:\Software\Classes\$class\shell\open\command"

    if ($Remove) {
        if (Test-Path -LiteralPath $hkcu) {
            Remove-Item -LiteralPath $hkcu -Force
            Write-Host "Removed user override: $class"
        }
        continue
    }

    $command = [string]$entry.commandBefore
    if ($command -notmatch '(?i)(^|\s)--nologo(\s|$)') {
        $command = $command -replace '^\s*("[^"]+"|\S+)\s*', '$1 --nologo '
    }

    New-Item -Path $hkcu -Force | Out-Null
    Set-Item -LiteralPath $hkcu -Value $command
    Write-Host "Set: $class => $command"
}

Write-Host 'Done. No shortcuts were created.'

