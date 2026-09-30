param(
    [Parameter(Mandatory=$true)][string]$XrayRoot
)

$ErrorActionPreference = "Stop"
$runtime = Join-Path (Resolve-Path $XrayRoot).Path "src\Layers\xrRenderPC_R4\OptiBridgeRuntime.cpp"
$text = Get-Content $runtime -Raw

$flagsOld = '    desc.flags = FFX_FSR2_ENABLE_AUTO_EXPOSURE | FFX_FSR2_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION;'
$flagsNew = @'
    // Action #15 diagnostic: SSFX supplies its motion-vector target directly.
    // Test FSR2 without assuming those vectors already contain camera jitter.
    desc.flags = FFX_FSR2_ENABLE_AUTO_EXPOSURE;
'@
if (-not $text.Contains($flagsOld)) { throw "FSR2 context flag insertion point not found" }
$text = $text.Replace($flagsOld, $flagsNew.TrimEnd())

$logOld = '    g_bridge.contextValid = true;'
$logNew = @'
    g_bridge.contextValid = true;
    Msg("* [OptiBridge] Action15: motion-vector jitter cancellation disabled");
'@
if (-not $text.Contains($logOld)) { throw "FSR2 context success insertion point not found" }
$text = $text.Replace($logOld, $logNew.TrimEnd())

Set-Content $runtime $text -NoNewline
Write-Host "OptiBridge Action #15 motion-vector jitter-cancellation diagnostic applied successfully."
