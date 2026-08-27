param(
    [switch]$Replace,
    [switch]$Merge,
    [switch]$WindowsNoLogo
)

$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    Split-Path -Parent (Split-Path -Parent $PSCommandPath)
}

function Get-LibreOfficeProfile {
    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        return Join-Path $env:APPDATA 'LibreOffice\4\user'
    }

    if ($IsMacOS) {
        return Join-Path $HOME 'Library/Application Support/LibreOffice/4/user'
    }

    $configHome = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME '.config' }
    return Join-Path $configHome 'libreoffice/4/user'
}

function Assert-LibreOfficeClosed {
    $running = Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -match '^(soffice|soffice\.bin|libreoffice)$' }

    if ($running) {
        $names = ($running | ForEach-Object { "$($_.ProcessName)[$($_.Id)]" }) -join ', '
        throw "Close LibreOffice before restoring settings. Running process(es): $names"
    }
}

function Get-LibreOfficeUnopkg {
    $candidates = [System.Collections.Generic.List[string]]::new()

    if ($env:LIBREOFFICE_UNOPKG) {
        $candidates.Add($env:LIBREOFFICE_UNOPKG)
    }

    foreach ($commandName in @('unopkg.com', 'unopkg.exe', 'unopkg')) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($command) {
            $candidates.Add($command.Source)
        }
    }

    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA)) {
            if ($base) {
                $candidates.Add((Join-Path $base 'LibreOffice\program\unopkg.com'))
                $candidates.Add((Join-Path $base 'LibreOffice\program\unopkg.exe'))
            }
        }
    } elseif ($IsMacOS) {
        $candidates.Add('/Applications/LibreOffice.app/Contents/MacOS/unopkg')
        $candidates.Add((Join-Path $HOME 'Applications/LibreOffice.app/Contents/MacOS/unopkg'))
    } else {
        $candidates.Add('/usr/lib/libreoffice/program/unopkg')
        $candidates.Add('/usr/lib64/libreoffice/program/unopkg')
        $candidates.Add('/opt/libreoffice/program/unopkg')
    }

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }

    throw "LibreOffice's unopkg tool was not found. Set LIBREOFFICE_UNOPKG to its full path."
}

function New-EmptyXcuDocument {
    $doc = New-Object System.Xml.XmlDocument
    $decl = $doc.CreateXmlDeclaration('1.0', 'UTF-8', $null)
    [void]$doc.AppendChild($decl)
    $root = $doc.CreateElement('oor', 'items', 'http://openoffice.org/2001/registry')
    [void]$root.SetAttribute('xmlns:xs', 'http://www.w3.org/2001/XMLSchema')
    [void]$root.SetAttribute('xmlns:xsi', 'http://www.w3.org/2001/XMLSchema-instance')
    [void]$doc.AppendChild($root)
    return $doc
}

function Get-XcuItemKey {
    param(
        [System.Xml.XmlElement]$Item
    )

    $oor = 'http://openoffice.org/2001/registry'
    $path = $Item.GetAttribute('path', $oor)
    $children = @(
        foreach ($child in $Item.ChildNodes) {
            if ($child.NodeType -eq [System.Xml.XmlNodeType]::Element) {
                "$($child.LocalName):$($child.GetAttribute('name', $oor))"
            }
        }
    )

    return "$path|$($children -join ',')"
}

Assert-LibreOfficeClosed

if ($Replace -and $Merge) {
    throw 'Choose either -Replace or -Merge, not both.'
}

$repo = Get-RepoRoot
$source = Join-Path $repo 'settings/registrymodifications.portable.xcu'
if (-not (Test-Path -LiteralPath $source)) {
    throw "Portable settings file not found: $source"
}
$policy = Join-Path $repo 'dist/portable-clean-libreoffice.oxt'
if (-not (Test-Path -LiteralPath $policy)) {
    throw "Clean-interface policy extension not found: $policy"
}

$profile = Get-LibreOfficeProfile
New-Item -ItemType Directory -Path $profile -Force | Out-Null

$target = Join-Path $profile 'registrymodifications.xcu'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
if (Test-Path -LiteralPath $target) {
    $backup = "$target.restore-backup-$timestamp"
    Copy-Item -LiteralPath $target -Destination $backup -Force
    Write-Host "Backup: $backup"
}

$unopkg = Get-LibreOfficeUnopkg
& $unopkg add --force --suppress-license $policy
if ($LASTEXITCODE -ne 0) {
    throw "Failed to install the clean-interface policy extension (exit code $LASTEXITCODE)."
}

& $unopkg validate org.ahmelkholy.libreoffice.cleanui
if ($LASTEXITCODE -ne 0) {
    throw 'The clean-interface policy extension did not register correctly.'
}
Write-Host 'Installed immutable clean-interface policy.'

if (-not $Merge -or -not (Test-Path -LiteralPath $target)) {
    Copy-Item -LiteralPath $source -Destination $target -Force
    Write-Host "Replaced LibreOffice settings: $target"
} else {
    [xml]$src = Get-Content -LiteralPath $source -Raw
    [xml]$dst = Get-Content -LiteralPath $target -Raw

    $srcNs = New-Object System.Xml.XmlNamespaceManager($src.NameTable)
    $srcNs.AddNamespace('oor', 'http://openoffice.org/2001/registry')

    $portableItems = @($src.SelectNodes('/oor:items/item', $srcNs))
    $portableKeys = @{}
    foreach ($item in $portableItems) {
        $portableKeys[(Get-XcuItemKey -Item $item)] = $true
    }

    foreach ($item in @($dst.DocumentElement.ChildNodes)) {
        if ($item.NodeType -eq [System.Xml.XmlNodeType]::Element -and $portableKeys.ContainsKey((Get-XcuItemKey -Item $item))) {
            [void]$dst.DocumentElement.RemoveChild($item)
        }
    }

    foreach ($item in $portableItems) {
        $imported = $dst.ImportNode($item, $true)
        [void]$dst.DocumentElement.AppendChild($imported)
    }

    $dst.Save($target)
    Write-Host "Merged portable settings into: $target"
}

if ($WindowsNoLogo) {
    if (-not ($IsWindows -or $env:OS -eq 'Windows_NT')) {
        Write-Warning '-WindowsNoLogo applies only on Windows.'
    } else {
        & (Join-Path $repo 'scripts/apply-windows-nologo-associations.ps1')
    }
}

Write-Host 'Done. Start LibreOffice to load the restored settings.'
