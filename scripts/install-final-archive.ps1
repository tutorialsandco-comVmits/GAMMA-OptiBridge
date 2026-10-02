[CmdletBinding()]
param(
    [string]$GameBin,
    [ValidateSet('native','quality','balanced','performance')]
    [string]$Preset = 'quality'
)

$ErrorActionPreference = 'Stop'
$InstalledSha256 = '21b93e59853aad1f2c9e469876bd5126e0b1a0ece279cba445a597d674a68b54'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PackageRoot = Split-Path -Parent $ScriptDir
if (Test-Path (Join-Path $ScriptDir 'AnomalyDX11.exe')) { $PackageRoot = $ScriptDir }

$PayloadExe = Join-Path $PackageRoot 'AnomalyDX11.exe'
$PresetDir = Join-Path $PackageRoot 'OptiBridge_Presets'
$PresetFile = Join-Path $PresetDir ("optibridge-{0}.ini" -f $Preset)
$SwitcherSource = Join-Path $PackageRoot 'APPLY_OPTIBRIDGE_PRESET.cmd'

if (-not (Test-Path $PayloadExe)) { throw "Package is missing AnomalyDX11.exe." }
if (-not (Test-Path $PresetFile)) { throw "Package is missing preset: $PresetFile" }
if (-not (Test-Path $SwitcherSource)) { throw "Package is missing APPLY_OPTIBRIDGE_PRESET.cmd." }

$PayloadSha = (Get-FileHash -Algorithm SHA256 $PayloadExe).Hash.ToLowerInvariant()
if ($PayloadSha -ne $InstalledSha256) {
    throw "Payload hash mismatch. Expected validated RC3 $InstalledSha256 but found $PayloadSha. Nothing was changed."
}

if ([string]::IsNullOrWhiteSpace($GameBin)) {
    if (Test-Path 'C:\Anomaly\bin\AnomalyDX11.exe') { $GameBin = 'C:\Anomaly\bin' }
    else { $GameBin = Read-Host 'Enter the GAMMA/Anomaly bin folder containing AnomalyDX11.exe' }
}
$GameBin = [System.IO.Path]::GetFullPath($GameBin)

$TargetExe = Join-Path $GameBin 'AnomalyDX11.exe'
$TargetIni = Join-Path $GameBin 'optibridge.ini'
$TargetPresetDir = Join-Path $GameBin 'OptiBridge_Presets'
$TargetSwitcher = Join-Path $GameBin 'APPLY_OPTIBRIDGE_PRESET.cmd'
$ManifestPath = Join-Path $GameBin '.optibridge-final-install.json'
$BackupRoot = Join-Path $GameBin 'OptiBridge_Backups'

if (-not (Test-Path $TargetExe)) { throw "Target executable not found: $TargetExe" }
if (Test-Path $ManifestPath) { throw "A managed final OptiBridge install already exists. Uninstall it first or use the preset switcher." }

$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupPath = Join-Path $BackupRoot $Stamp
New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null

$OriginalExeSha = (Get-FileHash -Algorithm SHA256 $TargetExe).Hash.ToLowerInvariant()
Copy-Item $TargetExe (Join-Path $BackupPath 'AnomalyDX11.exe') -Force

$HadIni = Test-Path $TargetIni
$HadPresetDir = Test-Path $TargetPresetDir
$HadSwitcher = Test-Path $TargetSwitcher
if ($HadIni) { Copy-Item $TargetIni (Join-Path $BackupPath 'optibridge.ini') -Force }
if ($HadPresetDir) { Copy-Item $TargetPresetDir (Join-Path $BackupPath 'OptiBridge_Presets') -Recurse -Force }
if ($HadSwitcher) { Copy-Item $TargetSwitcher (Join-Path $BackupPath 'APPLY_OPTIBRIDGE_PRESET.cmd') -Force }

Copy-Item $PayloadExe $TargetExe -Force
Copy-Item $PresetFile $TargetIni -Force
if (Test-Path $TargetPresetDir) { Remove-Item $TargetPresetDir -Recurse -Force }
Copy-Item $PresetDir $TargetPresetDir -Recurse -Force
Copy-Item $SwitcherSource $TargetSwitcher -Force

$InstalledTargetSha = (Get-FileHash -Algorithm SHA256 $TargetExe).Hash.ToLowerInvariant()
if ($InstalledTargetSha -ne $InstalledSha256) { throw 'Post-install executable verification failed.' }

[ordered]@{
    version = '0.5.0-rc3-abandoned'
    installedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    gameBin = $GameBin
    backupPath = $BackupPath
    originalExeSha256 = $OriginalExeSha
    installedExeSha256 = $InstalledSha256
    hadOptiBridgeIni = $HadIni
    hadPresetDir = $HadPresetDir
    hadSwitcher = $HadSwitcher
    activePreset = $Preset
} | ConvertTo-Json -Depth 4 | Set-Content -Path $ManifestPath -Encoding UTF8

Write-Host ''
Write-Host 'OptiBridge v0.5.0-rc3 abandoned archive installed.' -ForegroundColor Green
Write-Host "Preset: $Preset"
Write-Host "Backup: $BackupPath"
Write-Host 'This installer does NOT install OptiScaler, DLSS DLLs, ReShade, dxgi.dll or winmm.dll.'
Write-Host 'Install/configure OptiScaler separately if you intend to run the bridge.'
