[CmdletBinding()]
param([string]$GameBin)

$ErrorActionPreference = 'Stop'
$InstalledSha256 = '21b93e59853aad1f2c9e469876bd5126e0b1a0ece279cba445a597d674a68b54'

if ([string]::IsNullOrWhiteSpace($GameBin)) {
    if (Test-Path 'C:\Anomaly\bin\.optibridge-install.json') {
        $GameBin = 'C:\Anomaly\bin'
    } else {
        $GameBin = Read-Host 'Enter the GAMMA/Anomaly bin folder'
    }
}

$GameBin = [System.IO.Path]::GetFullPath($GameBin)
$ManifestPath = Join-Path $GameBin '.optibridge-install.json'
$TargetExe = Join-Path $GameBin 'AnomalyDX11.exe'
$TargetIni = Join-Path $GameBin 'optibridge.ini'
$TargetPresetDir = Join-Path $GameBin 'OptiBridge_Presets'
$TargetSwitcher = Join-Path $GameBin 'APPLY_OPTIBRIDGE_PRESET.cmd'

if (-not (Test-Path $ManifestPath)) {
    throw "Managed-install manifest not found: $ManifestPath`nNothing was changed."
}

try { $Manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json } catch { throw 'Install manifest is unreadable. Nothing was changed.' }
$BackupPath = [string]$Manifest.backupPath
$BackupExe = Join-Path $BackupPath 'AnomalyDX11.exe'
if ([string]::IsNullOrWhiteSpace($BackupPath) -or -not (Test-Path $BackupExe)) {
    throw "Original executable backup is missing. Refusing to uninstall: $BackupExe"
}

$BackupSha = (Get-FileHash -Algorithm SHA256 $BackupExe).Hash.ToLowerInvariant()
$ExpectedOriginalSha = ([string]$Manifest.originalExeSha256).ToLowerInvariant()
if ($BackupSha -ne $ExpectedOriginalSha) {
    throw "Backup hash mismatch. Expected $ExpectedOriginalSha but found $BackupSha. Refusing to restore."
}

if (Test-Path $TargetExe) {
    $CurrentSha = (Get-FileHash -Algorithm SHA256 $TargetExe).Hash.ToLowerInvariant()
    if ($CurrentSha -ne $InstalledSha256) {
        throw "Current AnomalyDX11.exe is no longer the managed RC3 binary ($CurrentSha). Refusing to overwrite a potentially newer/manual executable."
    }
}

$DxgiPath = Join-Path $GameBin 'dxgi.dll'
$WinmmPath = Join-Path $GameBin 'winmm.dll'
$DxgiBefore = if (Test-Path $DxgiPath) { (Get-FileHash -Algorithm SHA256 $DxgiPath).Hash.ToLowerInvariant() } else { $null }
$WinmmBefore = if (Test-Path $WinmmPath) { (Get-FileHash -Algorithm SHA256 $WinmmPath).Hash.ToLowerInvariant() } else { $null }

Copy-Item $BackupExe $TargetExe -Force

if ([bool]$Manifest.hadOptiBridgeIni) {
    Copy-Item (Join-Path $BackupPath 'optibridge.ini') $TargetIni -Force
} elseif (Test-Path $TargetIni) {
    Remove-Item $TargetIni -Force
}

if ([bool]$Manifest.hadSwitcher) {
    Copy-Item (Join-Path $BackupPath 'APPLY_OPTIBRIDGE_PRESET.cmd') $TargetSwitcher -Force
} elseif (Test-Path $TargetSwitcher) {
    Remove-Item $TargetSwitcher -Force
}

if (Test-Path $TargetPresetDir) { Remove-Item $TargetPresetDir -Recurse -Force }
if ([bool]$Manifest.hadPresetDir) {
    Copy-Item (Join-Path $BackupPath 'OptiBridge_Presets') $TargetPresetDir -Recurse -Force
}

$RestoredSha = (Get-FileHash -Algorithm SHA256 $TargetExe).Hash.ToLowerInvariant()
if ($RestoredSha -ne $ExpectedOriginalSha) { throw 'Restored executable failed SHA256 verification.' }

$DxgiAfter = if (Test-Path $DxgiPath) { (Get-FileHash -Algorithm SHA256 $DxgiPath).Hash.ToLowerInvariant() } else { $null }
$WinmmAfter = if (Test-Path $WinmmPath) { (Get-FileHash -Algorithm SHA256 $WinmmPath).Hash.ToLowerInvariant() } else { $null }
if ($DxgiBefore -ne $DxgiAfter) { throw 'dxgi.dll changed unexpectedly during uninstall.' }
if ($WinmmBefore -ne $WinmmAfter) { throw 'winmm.dll changed unexpectedly during uninstall.' }

Remove-Item $ManifestPath -Force

Write-Host ''
Write-Host 'OptiBridge managed install restored successfully.' -ForegroundColor Green
Write-Host "Restored AnomalyDX11.exe SHA256: $RestoredSha"
Write-Host "Backup retained at: $BackupPath"
Write-Host 'dxgi.dll and winmm.dll were left unchanged.'
