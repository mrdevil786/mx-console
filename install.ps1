#requires -Version 5.1
<#
.SYNOPSIS
    Install mx (MX Console) on Windows.

.DESCRIPTION
    Installs mx into %LOCALAPPDATA%\matrix-stack and adds it to your user PATH.
    Re-running the script upgrades an existing install.

    mx controls Apache and MySQL only on macOS and Ubuntu. On Windows the app
    installs and opens, but reports that the platform is not supported yet.

.EXAMPLE
    irm https://raw.githubusercontent.com/mrdevil786/mx-console/main/install.ps1 | iex

.EXAMPLE
    .\install.ps1 -Uninstall
#>
param(
    [switch]$Uninstall,
    [string]$AssetUrl = "",
    [string]$WheelUrl = "",
    [string]$InstallDir = "$env:LOCALAPPDATA\matrix-stack"
)

$ErrorActionPreference = "Stop"
$Bin = Join-Path $InstallDir "mx.exe"
$LinkDir = $InstallDir

function Write-Step([string]$Message) { Write-Host $Message }

if ($Uninstall) {
    if (Test-Path $Bin) { Remove-Item -Force $Bin }
    Write-Step "mx removed."
    Write-Step "Your settings and logs were kept."
    return
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$asset = "mx-windows-x64.exe"
if (-not $AssetUrl) {
    if ($WheelUrl) { $AssetUrl = $WheelUrl }
    else { $AssetUrl = "https://github.com/mrdevil786/mx-console/releases/latest/download/$asset" }
}

$tmp = Join-Path $env:TEMP ("mx-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp | Out-Null

try {
    $download = Join-Path $tmp $asset
    Write-Step "Downloading mx ($asset)..."
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $AssetUrl -OutFile $download
    }
    catch {
        throw "Could not download $AssetUrl. Check your internet connection, or pass -AssetUrl with a binary you built."
    }

    # sanity check
    & $download --version *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "the downloaded file is not a working mx binary."
    }

    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Copy-Item -Force $download $Bin

    $version = (& $Bin --version 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "mx was installed but did not start: $version"
    }

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $parts = @()
    if ($userPath) { $parts = $userPath.Split(";") | Where-Object { $_ } }
    if (-not ($parts | Where-Object { $_.TrimEnd("\") -ieq $InstallDir.TrimEnd("\") })) {
        $newPath = (@($parts) + $InstallDir) -join ";"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Step "Added $InstallDir to your user PATH. Open a new terminal before using mx."
    }
    $env:Path = "$env:Path;$InstallDir"

    Write-Step ""
    Write-Step "mx $version is installed."
    Write-Step ""
    Write-Step "Note: mx controls Apache and MySQL only on macOS and Ubuntu."
    Write-Step "On Windows the app opens and says the platform is not supported yet."
    Write-Step "Upgrade later by running this script again."
}
finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
