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

# MT Action17 staging adapter normalizes the extracted patch to LF while it
# rewrites the render-entry seam. Restore Windows CRLF before Action17 executes,
# because its guarded multiline here-string comparisons intentionally match the
# checked-out X-Ray source files byte-for-byte apart from surrounding Trim().
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$action17Patch = Join-Path $repoRoot ".ci\refine-native-scene-scale-v2.ps1"
if (Test-Path $action17Patch)
{
    $patchText = (Get-Content $action17Patch -Raw).Replace("`r`n", "`n").Replace("`n", "`r`n")
    Set-Content -Encoding utf8 $action17Patch $patchText -NoNewline
    Write-Host "OptiBridge MT Action17 patch line endings restored to CRLF."
}

Write-Host "OptiBridge Action #15 motion-vector jitter-cancellation diagnostic applied successfully."