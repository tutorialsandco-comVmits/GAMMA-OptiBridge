[CmdletBinding()]
param(
    [string]$GameBin,
    [ValidateSet('native','quality','balanced','performance')]
    [string]$Preset = 'quality'
)

$ErrorActionPreference = 'Stop'

$Version = '0.5.0-rc3'
$SupportedOriginalSha256 = 'd5ba2ed3307361af305270bb22f8aff1be96b3a8e8c7fad4c4cce402ff80078'
$InstalledSha256 = '21b93e59853aad1f2c9e469876bd5126e0b1a0ece279cba445a597d674a68b54'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PackageRoot = $ScriptDir
if (-not (Test-Path (Join-Path $PackageRoot 'AnomalyDX11.exe'))) {
    $PackageRoot = Split-Path -Parent $ScriptDir
}

$PayloadExe = Join-Path $PackageRoot 'AnomalyDX11.exe'
$PresetDir = Join-Path $PackageRoot 'OptiBridge_Presets'
$PresetFile = Join-Path $PresetDir ("optibridge-{0}.ini" -f $Preset)
$SwitcherSource = Join-Path $PackageRoot 'APPLY_OPTIBRIDGE_PRESET.cmd'

if (-not (Test-Path $PayloadExe)) { throw "Package payload AnomalyDX11.exe was not found." }
if (-not (Test-Path $PresetFile)) { throw "Preset file not found: $PresetFile" }
if (-not (Test-Path $SwitcherSource)) { throw "Preset switcher not found: $SwitcherSource" }

$PayloadSha = (Get-FileHash -Algorithm SHA256 $PayloadExe).Hash.ToLowerInvariant()
if ($PayloadSha -ne $InstalledSha256) {
    throw "Payload hash mismatch. Expected $InstalledSha256 but found $PayloadSha. Refusing to install."
}

if ([string]::IsNullOrWhiteSpace($GameBin)) {
    if (Test-Path 'C:\Anomaly\bin\AnomalyDX11.exe') {
        $GameBin = 'C:\Anomaly\bin'
    } else {
        $GameBin = Read-Host 'Enter the GAMMA/Anomaly bin folder containing AnomalyDX11.exe'
    }
}

$GameBin = [System.IO.Path]::GetFullPath($GameBin)
$TargetExe = Join-Path $GameBin 'AnomalyDX11.exe'
$TargetIni = Join-Path $GameBin 'optibridge.ini'
$TargetPresetDir = Join-Path $GameBin 'OptiBridge_Presets'
$TargetSwitcher = Join-Path $GameBin 'APPLY_OPTIBRIDGE_PRESET.cmd'
$ManifestPath = Join-Path $GameBin '.optibridge-install.json'
$BackupRoot = Join-Path $GameBin 'OptiBridge_Backups'

if (-not (Test-Path $TargetExe)) { throw "Target executable not found: $TargetExe" }

$CurrentSha = (Get-FileHash -Algorithm SHA256 $TargetExe).Hash.ToLowerInvariant()
$ExistingManifest = $null
if (Test-Path $ManifestPath) {
    try { $ExistingManifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json } catch { throw "Existing OptiBridge manifest is unreadable. Refusing to overwrite it." }
}

if ($CurrentSha -eq $InstalledSha256) {
    if ($null -eq $ExistingManifest) {
        throw "OptiBridge executable is already present but there is no managed-install manifest. Refusing to overwrite because the original executable cannot be restored safely."
    }
} elseif ($CurrentSha -ne $SupportedOriginalSha256) {
    throw "Unsupported AnomalyDX11.exe hash: $CurrentSha`nExpected clean baseline: $SupportedOriginalSha256`nNo files were changed."
}

$DxgiPath = Join-Path $GameBin 'dxgi.dll'
$WinmmPath = Join-Path $GameBin 'winmm.dll'
$DxgiBefore = if (Test-Path $DxgiPath) { (Get-FileHash -Algorithm SHA256 $DxgiPath).Hash.ToLowerInvariant() } else { $null }
$WinmmBefore = if (Test-Path $WinmmPath) { (Get-FileHash -Algorithm SHA256 $WinmmPath).Hash.ToLowerInvariant() } else { $null }

$BackupPath = $null
$OriginalShaForManifest = $SupportedOriginalSha256
$HadIni = $false
$HadSwitcher = $false
$HadPresetDir = $false

if ($CurrentSha -eq $SupportedOriginalSha256) {
    $Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $BackupPath = Join-Path $BackupRoot $Stamp
    New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null

    Copy-Item $TargetExe (Join-Path $BackupPath 'AnomalyDX11.exe') -Force

    if (Test-Path $TargetIni) {
        $HadIni = $true
        Copy-Item $TargetIni (Join-Path $BackupPath 'optibridge.ini') -Force
    }
    if (Test-Path $TargetSwitcher) {
        $HadSwitcher = $true
        Copy-Item $TargetSwitcher (Join-Path $BackupPath 'APPLY_OPTIBRIDGE_PRESET.cmd') -Force
    }
    if (Test-Path $TargetPresetDir) {
        $HadPresetDir = $true
        Copy-Item $TargetPresetDir (Join-Path $BackupPath 'OptiBridge_Presets') -Recurse -Force
    }
} else {
    $BackupPath = [string]$ExistingManifest.backupPath
    $OriginalShaForManifest = [string]$ExistingManifest.originalExeSha256
    $HadIni = [bool]$ExistingManifest.hadOptiBridgeIni
    $HadSwitcher = [bool]$ExistingManifest.hadSwitcher
    $HadPresetDir = [bool]$ExistingManifest.hadPresetDir
    if ([string]::IsNullOrWhiteSpace($BackupPath) -or -not (Test-Path (Join-Path $BackupPath 'AnomalyDX11.exe'))) {
        throw "Managed install manifest exists, but its original executable backup is missing. Refusing to reinstall."
    }
}

Copy-Item $PayloadExe $TargetExe -Force
Copy-Item $PresetFile $TargetIni -Force

if (Test-Path $TargetPresetDir) { Remove-Item $TargetPresetDir -Recurse -Force }
Copy-Item $PresetDir $TargetPresetDir -Recurse -Force
Copy-Item $SwitcherSource $TargetSwitcher -Force

$InstalledTargetSha = (Get-FileHash -Algorithm SHA256 $TargetExe).Hash.ToLowerInvariant()
if ($InstalledTargetSha -ne $InstalledSha256) {
    throw "Post-install executable verification failed. Expected $InstalledSha256 but found $InstalledTargetSha."
}

$DxgiAfter = if (Test-Path $DxgiPath) { (Get-FileHash -Algorithm SHA256 $DxgiPath).Hash.ToLowerInvariant() } else { $null }
$WinmmAfter = if (Test-Path $WinmmPath) { (Get-FileHash -Algorithm SHA256 $WinmmPath).Hash.ToLowerInvariant() } else { $null }
if ($DxgiBefore -ne $DxgiAfter) { throw 'dxgi.dll changed unexpectedly during install.' }
if ($WinmmBefore -ne $WinmmAfter) { throw 'winmm.dll changed unexpectedly during install.' }

$Manifest = [ordered]@{
    version = $Version
    installedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    gameBin = $GameBin
    originalExeSha256 = $OriginalShaForManifest
    installedExeSha256 = $InstalledSha256
    backupPath = $BackupPath
    hadOptiBridgeIni = $HadIni
    hadSwitcher = $HadSwitcher
    hadPresetDir = $HadPresetDir
    activePreset = $Preset
}
$Manifest | ConvertTo-Json -Depth 4 | Set-Content -Path $ManifestPath -Encoding UTF8

Write-Host ''
Write-Host "GAMMA OptiBridge $Version installed successfully." -ForegroundColor Green
Write-Host "Target: $GameBin"
Write-Host "Preset: $Preset"
Write-Host "Backup: $BackupPath"
Write-Host "AnomalyDX11.exe SHA256: $InstalledTargetSha"
Write-Host 'dxgi.dll and winmm.dll were left unchanged.'
Write-Host 'Keep r__tf_mipbias 0 and launch GAMMA normally through MO2.'
