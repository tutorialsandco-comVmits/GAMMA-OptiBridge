[CmdletBinding()]
param([string]$GameBin)

$ErrorActionPreference = 'Stop'
$InstalledSha256 = '21b93e59853aad1f2c9e469876bd5126e0b1a0ece279cba445a597d674a68b54'

if ([string]::IsNullOrWhiteSpace($GameBin)) {
    if (Test-Path 'C:\Anomaly\bin\AnomalyDX11.exe') { $GameBin = 'C:\Anomaly\bin' }
    else { $GameBin = Read-Host 'Enter the GAMMA/Anomaly bin folder' }
}

$GameBin = [System.IO.Path]::GetFullPath($GameBin)
$Exe = Join-Path $GameBin 'AnomalyDX11.exe'
$Ini = Join-Path $GameBin 'optibridge.ini'
$Manifest = Join-Path $GameBin '.optibridge-install.json'

$Failures = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path $Exe)) {
    $Failures.Add('AnomalyDX11.exe is missing.')
} else {
    $ExeSha = (Get-FileHash -Algorithm SHA256 $Exe).Hash.ToLowerInvariant()
    Write-Host "AnomalyDX11.exe SHA256: $ExeSha"
    if ($ExeSha -ne $InstalledSha256) { $Failures.Add("Unexpected executable hash: $ExeSha") }
}

if (-not (Test-Path $Ini)) {
    $Failures.Add('optibridge.ini is missing.')
} else {
    $Config = Get-Content $Ini -Raw
    $Required = @(
        'Enabled=1',
        'NativeSceneScale=1',
        'ProjectionJitter=1',
        'JitterScale=0.35',
        'DispatchJitterScale=1.0',
        'MotionVectorScaleFactor=1.0',
        'MVJitterCancellation=1',
        'FloraReactiveMask=1',
        'FloraReactiveStrength=0.50',
        'FloraReactiveRadius=1',
        'FloraAlphaStabilization=1',
        'FloraAlphaWidthScale=0.10',
        'FloraAlphaMipBias=0.25',
        'FloraHashedCoverage=0'
    )
    foreach ($Line in $Required) {
        if ($Config -notmatch [regex]::Escape($Line)) { $Failures.Add("Missing/changed config value: $Line") }
    }

    $ScaleMatch = [regex]::Match($Config, '(?m)^RenderScale\s*=\s*([0-9.]+)\s*$')
    if ($ScaleMatch.Success) { Write-Host "RenderScale: $($ScaleMatch.Groups[1].Value)" }
    else { $Failures.Add('RenderScale is missing from optibridge.ini.') }
}

Write-Host ("Managed manifest: {0}" -f $(if (Test-Path $Manifest) { 'present' } else { 'not present' }))
Write-Host ("dxgi.dll: {0}" -f $(if (Test-Path (Join-Path $GameBin 'dxgi.dll')) { 'present (untouched by OptiBridge installer)' } else { 'not present' }))
Write-Host ("winmm.dll: {0}" -f $(if (Test-Path (Join-Path $GameBin 'winmm.dll')) { 'present (untouched by OptiBridge installer)' } else { 'not present' }))

$AnomalyRoot = Split-Path -Parent $GameBin
$UserLtx = Join-Path $AnomalyRoot 'appdata\user.ltx'
if (Test-Path $UserLtx) {
    $MipLine = Select-String -Path $UserLtx -Pattern '^r__tf_mipbias\s+' | Select-Object -Last 1
    if ($null -ne $MipLine) {
        Write-Host "user.ltx: $($MipLine.Line.Trim())"
        if ($MipLine.Line -notmatch '^r__tf_mipbias\s+0(?:\.0*)?\s*$') {
            Write-Warning 'RC3 validation expects global r__tf_mipbias 0.'
        }
    }
}

if ($Failures.Count -gt 0) {
    Write-Host ''
    Write-Host 'Verification FAILED:' -ForegroundColor Red
    foreach ($Failure in $Failures) { Write-Host " - $Failure" -ForegroundColor Red }
    exit 1
}

Write-Host ''
Write-Host 'OptiBridge RC3 verification PASSED.' -ForegroundColor Green
