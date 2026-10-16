<#
.SYNOPSIS
    Builds SensorDataGenerator as a self-contained single-file executable.

.DESCRIPTION
    Publishes the SensorDataGenerator console project in Release configuration
    for a target Linux runtime (Debian). The result is a self-contained,
    single-file binary with compression, so the target machine does not need
    the .NET runtime installed.

    The project is located by a path relative to this script, so the script can
    be run from any working directory.

.PARAMETER Runtime
    Target runtime identifier. Default: linux-x64.

.PARAMETER Configuration
    Build configuration. Default: Release.

.PARAMETER OutputDir
    Output directory. Default: <repo root>/release/<Runtime>.

.PARAMETER ZipPath
    Path of the produced archive. Default: <repo root>/release/timescaledb_test.zip.
    The archive contains the executable and appsettings.json.

.PARAMETER AppZipPath
    Path of the distribution archive. Default: <repo root>/release/app.zip.
    The archive bundles timescaledb_test.zip together with the database
    scripts (install_postgres_and_extension.sh, create_simple_db.sh,
    create_timescale_db.sh) and the schema files (sensor_db.sql,
    sensor_timescale_db.sql).

.EXAMPLE
    ./build_sensor_data_generator.ps1

.EXAMPLE
    ./build_sensor_data_generator.ps1 -Runtime linux-arm64
#>
[CmdletBinding()]
param(
    [string]$Runtime = 'linux-x64',
    [string]$Configuration = 'Release',
    [string]$OutputDir,
    [string]$ZipPath,
    [string]$AppZipPath
)

$ErrorActionPreference = 'Stop'

# Resolve the repository root (parent of the scripts directory).
$repoRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repoRoot 'SensorDataGenerator/SensorDataGenerator.csproj'

if (-not (Test-Path $project)) {
    throw "Project file not found: $project"
}

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $repoRoot "release/$Runtime"
}

if ([string]::IsNullOrWhiteSpace($ZipPath)) {
    $ZipPath = Join-Path $repoRoot 'release/timescaledb_test.zip'
}

if ([string]::IsNullOrWhiteSpace($AppZipPath)) {
    $AppZipPath = Join-Path $repoRoot 'release/app.zip'
}

Write-Host "[+] Project:       $project"
Write-Host "[+] Configuration: $Configuration"
Write-Host "[+] Runtime:       $Runtime"
Write-Host "[+] Output:        $OutputDir"

# Clean the output directory to avoid stale artifacts.
if (Test-Path $OutputDir) {
    Write-Host "[+] Cleaning output directory..."
    Remove-Item -Recurse -Force $OutputDir
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

dotnet publish $project `
    -c $Configuration `
    -r $Runtime `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:EnableCompressionInSingleFile=true `
    -p:DebugType=none `
    -o $OutputDir

if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish failed with exit code $LASTEXITCODE."
}

Write-Host ""
Write-Host "[+] Build complete."
Write-Host "[+] Artifacts in: $OutputDir"
Get-ChildItem $OutputDir | Format-Table Name, Length -AutoSize

# ------------------------------------------------------------------------------
# Package the executable and its config into a zip archive.
# ------------------------------------------------------------------------------
$exe = Join-Path $OutputDir 'SensorDataGenerator'
$config = Join-Path $OutputDir 'appsettings.json'

if (-not (Test-Path $exe)) {
    throw "Expected executable not found: $exe"
}
if (-not (Test-Path $config)) {
    throw "Expected config not found: $config"
}

$zipDir = Split-Path -Parent $ZipPath
if (-not [string]::IsNullOrWhiteSpace($zipDir)) {
    New-Item -ItemType Directory -Force -Path $zipDir | Out-Null
}
if (Test-Path $ZipPath) {
    Remove-Item -Force $ZipPath
}

Write-Host ""
Write-Host "[+] Creating archive: $ZipPath"
Compress-Archive -Path $exe, $config -DestinationPath $ZipPath -Force

Write-Host "[+] Archive contents:"
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::OpenRead($ZipPath).Entries |
    Select-Object Name, Length | Format-Table -AutoSize

# ------------------------------------------------------------------------------
# Bundle the build archive, the database scripts and the schema files into app.zip.
# ------------------------------------------------------------------------------
$extraFiles = @(
    (Join-Path $PSScriptRoot 'install_postgres_and_extension.sh'),
    (Join-Path $PSScriptRoot 'create_simple_db.sh'),
    (Join-Path $PSScriptRoot 'create_timescale_db.sh'),
    (Join-Path $repoRoot 'simple_db/sensor_db.sql'),
    (Join-Path $repoRoot 'timescale_db/sensor_timescale_db.sql')
)

foreach ($file in $extraFiles) {
    if (-not (Test-Path $file)) {
        throw "Expected file not found: $file"
    }
}

$appZipDir = Split-Path -Parent $AppZipPath
if (-not [string]::IsNullOrWhiteSpace($appZipDir)) {
    New-Item -ItemType Directory -Force -Path $appZipDir | Out-Null
}
if (Test-Path $AppZipPath) {
    Remove-Item -Force $AppZipPath
}

Write-Host ""
Write-Host "[+] Creating distribution archive: $AppZipPath"
Compress-Archive -Path ($ZipPath + $extraFiles) -DestinationPath $AppZipPath -Force

Write-Host "[+] Distribution archive contents:"
[System.IO.Compression.ZipFile]::OpenRead($AppZipPath).Entries |
    Select-Object Name, Length | Format-Table -AutoSize

Write-Host ""
Write-Host "Deploy to Debian (example):"
Write-Host "  scp '$AppZipPath' user@host:/opt/"
Write-Host "  ssh user@host 'cd /opt && unzip -o app.zip && chmod +x *.sh'"
Write-Host "  ssh user@host 'cd /opt && unzip -o timescaledb_test.zip -d SensorDataGenerator && chmod +x SensorDataGenerator/SensorDataGenerator'"
