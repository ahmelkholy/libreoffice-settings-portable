param(
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'

if (-not ($IsWindows -or $env:OS -eq 'Windows_NT')) {
    throw 'This script applies only on Windows.'
}

$repo = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$launcher = Join-Path $repo 'scripts\start-portable.vbs'
if (-not (Test-Path -LiteralPath $launcher)) {
    throw "Portable launcher not found: $launcher"
}

$backupDir = Join-Path $repo 'windows'
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupPath = Join-Path $backupDir "backup-file-associations-portable-$timestamp.json"

$knownClasses = @(
    'LibreOffice.CalcDocument.1',
    'LibreOffice.CalcTemplate.1',
    'LibreOffice.DatabaseDocument.1',
    'LibreOffice.DrawDocument.1',
    'LibreOffice.DrawTemplate.1',
    'LibreOffice.ImpressDocument.1',
    'LibreOffice.ImpressTemplate.1',
    'LibreOffice.MathDocument.1',
    'LibreOffice.WriterDocument.1',
    'LibreOffice.WriterGlobalDocument.1',
    'LibreOffice.WriterTemplate.1',
    'LibreOffice.WriterWebDocument.1',
    'LibreOffice.WriterWebTemplate.1',
    'LibreOffice.Doc',
    'LibreOffice.Docm',
    'LibreOffice.Docx',
    'LibreOffice.Dot',
    'LibreOffice.Dotm',
    'LibreOffice.Dotx',
    'LibreOffice.Odb',
    'LibreOffice.Odf',
    'LibreOffice.Odg',
    'LibreOffice.Odp',
    'LibreOffice.Ods',
    'LibreOffice.Odt',
    'LibreOffice.Otg',
    'LibreOffice.Otp',
    'LibreOffice.Ots',
    'LibreOffice.Ott',
    'LibreOffice.Pot',
    'LibreOffice.Potm',
    'LibreOffice.Potx',
    'LibreOffice.Ppt',
    'LibreOffice.Pptm',
    'LibreOffice.Pptx',
    'LibreOffice.Rtf',
    'LibreOffice.Xls',
    'LibreOffice.Xlsm',
    'LibreOffice.Xlsx',
    'LibreOffice.Xlt',
    'LibreOffice.Xltm',
    'LibreOffice.Xltx'
)

$extensions = @(
    '.doc',
    '.docm',
    '.docx',
    '.dot',
    '.dotm',
    '.dotx',
    '.odb',
    '.odf',
    '.odg',
    '.odp',
    '.ods',
    '.odt',
    '.otg',
    '.otp',
    '.ots',
    '.ott',
    '.pot',
    '.potm',
    '.potx',
    '.ppt',
    '.pptm',
    '.pptx',
    '.rtf',
    '.xls',
    '.xlsm',
    '.xlsx',
    '.xlt',
    '.xltm',
    '.xltx'
)

$userChoiceClasses = foreach ($extension in $extensions) {
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$extension\UserChoice"
    if (Test-Path -LiteralPath $path) {
        $progId = (Get-ItemProperty -LiteralPath $path).ProgId
        if ($progId -like 'LibreOffice.*') {
            $progId
        }
    }
}

$classes = @($knownClasses + $userChoiceClasses) |
    Where-Object { $_ } |
    Sort-Object -Unique |
    Where-Object {
        (Test-Path -LiteralPath "HKCU:\Software\Classes\$_\shell\open\command") -or
        (Test-Path -LiteralPath "Registry::HKEY_CLASSES_ROOT\$_\shell\open\command")
    }

$backup = foreach ($class in $classes) {
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

$wscript = Join-Path $env:SystemRoot 'System32\wscript.exe'
$command = '"{0}" //nologo "{1}" "%1"' -f $wscript, $launcher

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

    New-Item -Path $hkcu -Force | Out-Null
    Set-Item -LiteralPath $hkcu -Value $command
    Write-Host "Set: $class => $command"
}

Write-Host 'Done. LibreOffice-owned files now open through the portable profile launcher.'
