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
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).ProviderPath
        }
    }

    throw 'LibreOffice soffice.exe was not found. Install LibreOffice or set LIBREOFFICE_PROGRAM to the soffice.exe path.'
}

function Convert-PathArgument {
    param(
        [string]$Value
    )

    if (-not $Value) {
        return $Value
    }

    if ($Value -match '^[A-Za-z]:[\\/]' -or $Value -match '^\\\\') {
        if (Test-Path -LiteralPath $Value) {
            return ([Uri](Resolve-Path -LiteralPath $Value).ProviderPath).AbsoluteUri
        }
    }

    if ($Value -match '^[A-Za-z][A-Za-z0-9+.-]*://') {
        return $Value
    }

    if (Test-Path -LiteralPath $Value) {
        return ([Uri](Resolve-Path -LiteralPath $Value).ProviderPath).AbsoluteUri
    }

    return $Value
}

function Initialize-PortableProfile {
    param(
        [string]$RepoRoot,
        [string]$ProfileRoot,
        [switch]$Reset
    )

    $source = Join-Path $RepoRoot 'settings\registrymodifications.portable.xcu'
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Portable settings file not found: $source"
    }

    if ($Reset -and (Test-Path -LiteralPath $ProfileRoot)) {
        $repoFull = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')
        $profileFull = [IO.Path]::GetFullPath($ProfileRoot).TrimEnd('\')
        if (-not $profileFull.StartsWith($repoFull + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to reset profile outside the repository: $profileFull"
        }
        Remove-Item -LiteralPath $ProfileRoot -Recurse -Force
    }

    $userDir = Join-Path $ProfileRoot 'user'
    New-Item -ItemType Directory -Path $userDir -Force | Out-Null

    $target = Join-Path $userDir 'registrymodifications.xcu'
    if (-not (Test-Path -LiteralPath $target)) {
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
}

$repo = Get-RepoRoot
$profileRoot = Join-Path $repo 'portable-profile'
Initialize-PortableProfile -RepoRoot $repo -ProfileRoot $profileRoot -Reset:$ResetProfile

$profileUri = ([Uri](Resolve-Path -LiteralPath $profileRoot).ProviderPath).AbsoluteUri
$soffice = Get-LibreOfficeProgram
$launchArgs = @(
    "-env:UserInstallation=$profileUri",
    '--nologo',
    '--nolockcheck',
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
