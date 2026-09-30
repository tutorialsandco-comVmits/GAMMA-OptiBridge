param(
    [Parameter(Mandatory=$true)][string]$XrayRoot
)

$ErrorActionPreference = "Stop"
$XrayRoot = (Resolve-Path $XrayRoot).Path
$rendererDir = Join-Path $XrayRoot "src\Layers\xrRenderPC_R4"

function Replace-ExactlyOnce([string]$source, [string]$from, [string]$to, [string]$label)
{
    $needle = $from.Trim()
    $count = ([regex]::Matches($source, [regex]::Escape($needle))).Count
    if ($count -ne 1) { throw "$label expected exactly once, got $count" }
    return $source.Replace($needle, $to.Trim())
}

$runtime = Join-Path $rendererDir "OptiBridgeRuntime.cpp"
$text = Get-Content $runtime -Raw

# Action19 exposes the temporal assumptions independently so one binary can
# diagnose jitter amplitude, metadata, MV scale/sign, and MV-jitter cancellation.
$old = @'
    float previousJitterNdcX = 0.f;
    float previousJitterNdcY = 0.f;
    Fmatrix savedProject = {};
'@
$new = @'
    float previousJitterNdcX = 0.f;
    float previousJitterNdcY = 0.f;
    float jitterScale = 1.0f;
    float dispatchJitterScale = 1.0f;
    float motionVectorScaleFactor = 1.0f;
    bool mvJitterCancellationEnabled = true;
    Fmatrix savedProject = {};
'@
$text = Replace-ExactlyOnce $text $old $new "Action19 diagnostic-state seam"

$old = @'
        g_bridge.nativeSceneScaleEnabled = GetPrivateProfileIntA("OptiBridge", "NativeSceneScale", 0, path) != 0;
        g_bridge.projectionJitterEnabled = GetPrivateProfileIntA("OptiBridge", "ProjectionJitter", 1, path) != 0;

        char scaleText[32] = {};
        GetPrivateProfileStringA("OptiBridge", "RenderScale", "1.0", scaleText, sizeof(scaleText), path);
        g_bridge.renderScale = (float)atof(scaleText);
        g_bridge.renderScale = _max(0.5f, _min(1.0f, g_bridge.renderScale));
'@
$new = @'
        g_bridge.nativeSceneScaleEnabled = GetPrivateProfileIntA("OptiBridge", "NativeSceneScale", 0, path) != 0;
        g_bridge.projectionJitterEnabled = GetPrivateProfileIntA("OptiBridge", "ProjectionJitter", 1, path) != 0;
        g_bridge.mvJitterCancellationEnabled = GetPrivateProfileIntA("OptiBridge", "MVJitterCancellation", 1, path) != 0;

        char scaleText[32] = {};
        GetPrivateProfileStringA("OptiBridge", "RenderScale", "1.0", scaleText, sizeof(scaleText), path);
        g_bridge.renderScale = (float)atof(scaleText);
        g_bridge.renderScale = _max(0.5f, _min(1.0f, g_bridge.renderScale));

        char jitterScaleText[32] = {};
        GetPrivateProfileStringA("OptiBridge", "JitterScale", "1.0", jitterScaleText, sizeof(jitterScaleText), path);
        g_bridge.jitterScale = (float)atof(jitterScaleText);
        g_bridge.jitterScale = _max(0.0f, _min(2.0f, g_bridge.jitterScale));

        char dispatchJitterScaleText[32] = {};
        GetPrivateProfileStringA("OptiBridge", "DispatchJitterScale", "1.0", dispatchJitterScaleText, sizeof(dispatchJitterScaleText), path);
        g_bridge.dispatchJitterScale = (float)atof(dispatchJitterScaleText);
        g_bridge.dispatchJitterScale = _max(-2.0f, _min(2.0f, g_bridge.dispatchJitterScale));

        char mvScaleText[32] = {};
        GetPrivateProfileStringA("OptiBridge", "MotionVectorScaleFactor", "1.0", mvScaleText, sizeof(mvScaleText), path);
        g_bridge.motionVectorScaleFactor = (float)atof(mvScaleText);
        g_bridge.motionVectorScaleFactor = _max(-2.0f, _min(2.0f, g_bridge.motionVectorScaleFactor));
'@
$text = Replace-ExactlyOnce $text $old $new "Action19 config seam"

$old = @'
        Msg("* [OptiBridge] runtime v0.4.0-alpha Action18");
        Msg("* [OptiBridge] %s (%s), render scale %.4f, jitter %s, native scene scale %s, projection jitter %s",
            g_bridge.enabled ? "enabled" : "disabled", path, g_bridge.renderScale,
            g_bridge.jitterEnabled ? "on" : "off",
            g_bridge.nativeSceneScaleEnabled ? "on" : "off",
            g_bridge.projectionJitterEnabled ? "on" : "off");
'@
$new = @'
        Msg("* [OptiBridge] runtime v0.4.1-alpha Action19 temporal diagnostics");
        Msg("* [OptiBridge] %s (%s), render scale %.4f, jitter %s, native scene scale %s, projection jitter %s",
            g_bridge.enabled ? "enabled" : "disabled", path, g_bridge.renderScale,
            g_bridge.jitterEnabled ? "on" : "off",
            g_bridge.nativeSceneScaleEnabled ? "on" : "off",
            g_bridge.projectionJitterEnabled ? "on" : "off");
        Msg("* [OptiBridge] Action19 diagnostics: jitter scale %.3f, dispatch jitter scale %.3f, MV scale factor %.3f, MV jitter cancellation %s",
            g_bridge.jitterScale, g_bridge.dispatchJitterScale, g_bridge.motionVectorScaleFactor,
            g_bridge.mvJitterCancellationEnabled ? "on" : "off");
'@
$text = Replace-ExactlyOnce $text $old $new "Action19 runtime log seam"

$old = @'
    if (action18ProjectionJitter)
        desc.flags |= FFX_FSR2_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION;
'@
$new = @'
    if (action18ProjectionJitter && g_bridge.mvJitterCancellationEnabled)
        desc.flags |= FFX_FSR2_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION;
'@
$text = Replace-ExactlyOnce $text $old $new "Action19 MV-jitter flag seam"

$old = @'
    if (action18ProjectionJitter)
        Msg("* [OptiBridge] Action18: projection jitter path enabled; motion-vector jitter cancellation enabled");
    else
        Msg("* [OptiBridge] Action15: motion-vector jitter cancellation disabled");
'@
$new = @'
    if (action18ProjectionJitter)
        Msg("* [OptiBridge] Action19: projection jitter path enabled; motion-vector jitter cancellation %s",
            g_bridge.mvJitterCancellationEnabled ? "enabled" : "disabled");
    else
        Msg("* [OptiBridge] Action15: motion-vector jitter cancellation disabled");
'@
$text = Replace-ExactlyOnce $text $old $new "Action19 MV-jitter log seam"

# Scale the actual scene jitter and keep its default at the exact Action18 value.
$old = @'
    CurrentJitter(jitterPxX, jitterPxY);

    const float renderWidth = float(_max(1u, Device.dwWidth));
'@
$new = @'
    CurrentJitter(jitterPxX, jitterPxY);
    jitterPxX *= g_bridge.jitterScale;
    jitterPxY *= g_bridge.jitterScale;

    const float renderWidth = float(_max(1u, Device.dwWidth));
'@
$text = Replace-ExactlyOnce $text $old $new "Action19 scene-jitter scale seam"

# Independently scale the metadata sent to FSR2/OptiScaler. This is diagnostic:
# default 1.0 preserves exact matching with the scene jitter.
$old = @'
    float jitterX = 0.f, jitterY = 0.f;
    CurrentJitter(jitterX, jitterY);
    dispatch.jitterOffset = { jitterX, jitterY };

    // SSFX stores texture-space current-minus-previous motion. FSR2 wants current-to-previous.
    dispatch.motionVectorScale = { -float(g_bridge.renderWidth), -float(g_bridge.renderHeight) };
'@
$new = @'
    float jitterX = 0.f, jitterY = 0.f;
    CurrentJitter(jitterX, jitterY);
    jitterX *= g_bridge.jitterScale * g_bridge.dispatchJitterScale;
    jitterY *= g_bridge.jitterScale * g_bridge.dispatchJitterScale;
    dispatch.jitterOffset = { jitterX, jitterY };

    // SSFX stores current-minus-previous UV motion. Factor 1.0 preserves the
    // validated conversion to previous-minus-current pixel motion. 0.0 is a
    // stationary-scene diagnostic; -1.0 flips the assumed direction.
    dispatch.motionVectorScale = {
        -float(g_bridge.renderWidth) * g_bridge.motionVectorScaleFactor,
        -float(g_bridge.renderHeight) * g_bridge.motionVectorScaleFactor };
'@
$text = Replace-ExactlyOnce $text $old $new "Action19 dispatch diagnostic seam"

Set-Content $runtime $text -NoNewline
Write-Host "OptiBridge Action19 temporal diagnostics patch applied successfully."
