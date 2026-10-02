[CmdletBinding()]
param([string]$GameBin)

$ErrorActionPreference = 'Stop'
$InstalledSha256 = '21b93e59853aad1f2c9e469876bd5126e0b1a0ece279cba445a597d674a68b54'

if ([string]::IsNullOrWhiteSpace($GameBin)) {
    if (Test-Path 'C:\Anomaly\bin\.optibridge-final-install.json') { $GameBin = 'C:\Anomaly\bin' }
    else { $GameBin = Read-Host 'Enter the GAMMA/Anomaly bin folder' }
}
$GameBin = [System.IO.Path]::GetFullPath($GameBin)

$TargetExe = Join-Path $GameBin 'AnomalyDX11.exe'
$TargetIni = Join-Path $GameBin 'optibridge.ini'
$TargetPresetDir = Join-Path $GameBin 'OptiBridge_Presets'
$TargetSwitcher = Join-Path $GameBin 'APPLY_OPTIBRIDGE_PRESET.cmd'
$ManifestPath = Join-Path $GameBin '.optibridge-final-install.json'

if (-not (Test-Path $ManifestPath)) { throw 'Managed final OptiBridge install manifest not found. Nothing was changed.' }
$Manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
$BackupPath = [string]$Manifest.backupPath
$BackupExe = Join-Path $BackupPath 'AnomalyDX11.exe'
if (-not (Test-Path $BackupExe)) { throw "Backup executable missing: $BackupExe" }

$BackupSha = (Get-FileHash -Algorithm SHA256 $BackupExe).Hash.ToLowerInvariant()
$ExpectedOriginal = ([string]$Manifest.originalExeSha256).ToLowerInvariant()
if ($BackupSha -ne $ExpectedOriginal) { throw 'Backup executable hash mismatch. Refusing to restore.' }

if (Test-Path $TargetExe) {
    $CurrentSha = (Get-FileHash -Algorithm SHA256 $TargetExe).Hash.ToLowerInvariant()
    if ($CurrentSha -ne $InstalledSha256) {
        throw "Current AnomalyDX11.exe is no longer the managed RC3 binary ($CurrentSha). Refusing to overwrite it."
    }
}

Copy-Item $BackupExe $TargetExe -Force

if ([bool]$Manifest.hadOptiBridgeIni) {
    Copy-Item (Join-Path $BackupPath 'optibridge.ini') $TargetIni -Force
} elseif (Test-Path $TargetIni) { Remove-Item $TargetIni -Force }

if (Test-Path $TargetPresetDir) { Remove-Item $TargetPresetDir -Recurse -Force }
if ([bool]$Manifest.hadPresetDir) {
    Copy-Item (Join-Path $BackupPath 'OptiBridge_Presets') $TargetPresetDir -Recurse -Force
}

if ([bool]$Manifest.hadSwitcher) {
    Copy-Item (Join-Path $BackupPath 'APPLY_OPTIBRIDGE_PRESET.cmd') $TargetSwitcher -Force
} elseif (Test-Path $TargetSwitcher) { Remove-Item $TargetSwitcher -Force }

$RestoredSha = (Get-FileHash -Algorithm SHA256 $TargetExe).Hash.ToLowerInvariant()
if ($RestoredSha -ne $ExpectedOriginal) { throw 'Restored executable failed SHA256 verification.' }
Remove-Item $ManifestPath -Force

Write-Host ''
Write-Host 'OptiBridge managed archive install removed and original executable restored.' -ForegroundColor Green
Write-Host "Restored SHA256: $RestoredSha"
Write-Host "Backup retained at: $BackupPath"
Write-Host 'OptiScaler/ReShade/proxy DLLs were not modified by this uninstaller.'
