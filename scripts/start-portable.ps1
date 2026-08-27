param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$LibreOfficeArgs,
    [switch]$ResetProfile,
    [switch]$PrintCommand
)

$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    Split-Path -Parent (Split-Path -Parent $PSCommandPath)
}

function Get-LibreOfficeProgram {
    if ($env:LIBREOFFICE_PROGRAM -and (Test-Path -LiteralPath $env:LIBREOFFICE_PROGRAM)) {
        return (Resolve-Path -LiteralPath $env:LIBREOFFICE_PROGRAM).ProviderPath
    }

    $candidates = @()
    if ($env:ProgramFiles) {
        $candidates += Join-Path $env:ProgramFiles 'LibreOffice\program\soffice.exe'
    }
    $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    if ($programFilesX86) {
        $candidates += Join-Path $programFilesX86 'LibreOffice\program\soffice.exe'
    }

    $command = Get-Command soffice.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        $candidates += $command.Source
    }

    foreach ($candidate in $candidates | Where-Object { $_ } | Select-Object -Unique) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).ProviderPath
        }
    }

    throw 'LibreOffice soffice.exe was not found. Install LibreOffice or set LIBREOFFICE_PROGRAM.'
}

function Get-LibreOfficeUnopkg {
    param(
        [string]$SofficePath
    )

    $programDir = Split-Path -Parent $SofficePath
    $candidates = @(
        (Join-Path $programDir 'unopkg.com'),
        (Join-Path $programDir 'unopkg.exe')
    )

    if ($env:LIBREOFFICE_UNOPKG) {
        $candidates = @($env:LIBREOFFICE_UNOPKG) + $candidates
    }

    foreach ($candidate in $candidates | Where-Object { $_ } | Select-Object -Unique) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).ProviderPath
        }
    }

    throw "LibreOffice's unopkg tool was not found beside soffice.exe."
}

function Convert-PathArgument {
    param(
        [string]$Value
    )

    if (-not $Value) {
        return $Value
    }

    if ($Value -match '^[A-Za-z][A-Za-z0-9+.-]*://') {
        return $Value
    }

    if (Test-Path -LiteralPath $Value) {
        return ([Uri](Resolve-Path -LiteralPath $Value).ProviderPath).AbsoluteUri
    }

    return $Value
}

function Assert-ProfileInsideRepository {
    param(
        [string]$RepoRoot,
        [string]$ProfileRoot
    )

    $repoFull = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')
    $profileFull = [IO.Path]::GetFullPath($ProfileRoot).TrimEnd('\')
    if (-not $profileFull.StartsWith($repoFull + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to modify a portable profile outside the repository: $profileFull"
    }
}

function Sync-PortableProfile {
    param(
        [string]$RepoRoot,
        [string]$ProfileRoot,
        [string]$UnopkgPath,
        [switch]$Reset
    )

    $source = Join-Path $RepoRoot 'settings\registrymodifications.portable.xcu'
    $policy = Join-Path $RepoRoot 'dist\portable-clean-libreoffice.oxt'
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Portable settings file not found: $source"
    }
    if (-not (Test-Path -LiteralPath $policy -PathType Leaf)) {
        throw "Clean-interface policy extension not found: $policy"
    }

    Assert-ProfileInsideRepository -RepoRoot $RepoRoot -ProfileRoot $ProfileRoot
    $lock = Join-Path $ProfileRoot '.lock'
    if ($Reset -and (Test-Path -LiteralPath $lock)) {
        throw 'Close the portable LibreOffice instance before using -ResetProfile.'
    }
    if ($Reset -and (Test-Path -LiteralPath $ProfileRoot)) {
        Remove-Item -LiteralPath $ProfileRoot -Recurse -Force
    }

    $userDir = Join-Path $ProfileRoot 'user'
    New-Item -ItemType Directory -Path $userDir -Force | Out-Null
    $target = Join-Path $userDir 'registrymodifications.xcu'

    if (Test-Path -LiteralPath $lock) {
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
            throw 'The portable profile is locked but has no settings file. Close LibreOffice and retry.'
        }
        return
    }

    $profileUri = ([Uri](Resolve-Path -LiteralPath $ProfileRoot).ProviderPath).AbsoluteUri
    & $UnopkgPath "-env:UserInstallation=$profileUri" add --force --suppress-license $policy | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install the clean-interface policy (exit code $LASTEXITCODE)."
    }

    & $UnopkgPath "-env:UserInstallation=$profileUri" validate org.ahmelkholy.libreoffice.cleanui | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'The clean-interface policy did not register in the portable profile.'
    }

    # unopkg can normalize registrymodifications.xcu, so the canonical file is
    # copied after policy installation on every cold launch.
    Copy-Item -LiteralPath $source -Destination $target -Force
}

$repo = Get-RepoRoot
$profileRoot = Join-Path $repo 'portable-profile'
$soffice = Get-LibreOfficeProgram
$unopkg = Get-LibreOfficeUnopkg -SofficePath $soffice

Sync-PortableProfile `
    -RepoRoot $repo `
    -ProfileRoot $profileRoot `
    -UnopkgPath $unopkg `
    -Reset:$ResetProfile

$profileUri = ([Uri](Resolve-Path -LiteralPath $profileRoot).ProviderPath).AbsoluteUri
$launchArgs = @(
    "-env:UserInstallation=$profileUri",
    '--nologo',
    '--nofirststartwizard'
)

foreach ($arg in $LibreOfficeArgs) {
    $launchArgs += Convert-PathArgument -Value $arg
}

if ($PrintCommand) {
    Write-Host $soffice
    foreach ($arg in $launchArgs) {
        Write-Host $arg
    }
    exit
}

Start-Process -FilePath $soffice -ArgumentList $launchArgs -WindowStyle Normal
