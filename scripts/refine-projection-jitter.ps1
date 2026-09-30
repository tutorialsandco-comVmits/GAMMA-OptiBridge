param(
    [Parameter(Mandatory=$true)][string]$XrayRoot
)

$ErrorActionPreference = "Stop"
$XrayRoot = (Resolve-Path $XrayRoot).Path
$rendererDir = Join-Path $XrayRoot "src\Layers\xrRenderPC_R4"
$nl = [Environment]::NewLine

function Replace-ExactlyOnce([string]$source, [string]$from, [string]$to, [string]$label)
{
    $needle = $from.Trim()
    $count = ([regex]::Matches($source, [regex]::Escape($needle))).Count
    if ($count -ne 1) { throw "$label expected exactly once, got $count" }
    return $source.Replace($needle, $to.Trim())
}

# Public contract: Action18 applies FSR2 jitter to the actual scene projection.
$header = Join-Path $rendererDir "OptiBridgeRuntime.h"
$text = Get-Content $header -Raw
$old = @'
bool OptiBridge_BeginSceneScale();
void OptiBridge_RestoreDisplayResolution();
'@
$new = @'
bool OptiBridge_BeginSceneScale();
bool OptiBridge_ApplyProjectionJitter();
void OptiBridge_RestoreDisplayResolution();
'@
$text = Replace-ExactlyOnce $text $old $new "Action18 header seam"
Set-Content $header $text -NoNewline

$runtime = Join-Path $rendererDir "OptiBridgeRuntime.cpp"
$text = Get-Content $runtime -Raw

# Runtime state. Keep Action17 state untouched and add an isolated projection-jitter layer.
$old = @'
    bool nativeSceneScaleEnabled = false;
    bool sceneScaleActive = false;
    bool frameNativeSceneScale = false;
    bool loggedNativeSceneScale = false;
    float renderScale = 1.0f;
'@
$new = @'
    bool nativeSceneScaleEnabled = false;
    bool sceneScaleActive = false;
    bool frameNativeSceneScale = false;
    bool loggedNativeSceneScale = false;
    bool projectionJitterEnabled = true;
    bool projectionJitterActive = false;
    bool previousProjectionJitterValid = false;
    bool loggedProjectionJitter = false;
    float currentJitterNdcX = 0.f;
    float currentJitterNdcY = 0.f;
    float previousJitterNdcX = 0.f;
    float previousJitterNdcY = 0.f;
    Fmatrix savedProject = {};
    Fmatrix savedProjectPrev = {};
    Fmatrix savedFullTransform = {};
    Fmatrix savedFullTransformPrev = {};
    Fmatrix savedInvFullTransform = {};
    float renderScale = 1.0f;
'@
$text = Replace-ExactlyOnce $text $old $new "Action18 state seam"

# Config switch is intentionally independent so the new path can be A/B tested
# without changing NativeSceneScale or the validated Action15/16 baseline.
$old = @'
        g_bridge.jitterEnabled = GetPrivateProfileIntA("OptiBridge", "Jitter", 1, path) != 0;
        g_bridge.nativeSceneScaleEnabled = GetPrivateProfileIntA("OptiBridge", "NativeSceneScale", 0, path) != 0;

        char scaleText[32] = {};
'@
$new = @'
        g_bridge.jitterEnabled = GetPrivateProfileIntA("OptiBridge", "Jitter", 1, path) != 0;
        g_bridge.nativeSceneScaleEnabled = GetPrivateProfileIntA("OptiBridge", "NativeSceneScale", 0, path) != 0;
        g_bridge.projectionJitterEnabled = GetPrivateProfileIntA("OptiBridge", "ProjectionJitter", 1, path) != 0;

        char scaleText[32] = {};
'@
$text = Replace-ExactlyOnce $text $old $new "Action18 config seam"

$old = @'
        Msg("* [OptiBridge] runtime v0.3.9-alpha Action17");
        Msg("* [OptiBridge] %s (%s), render scale %.4f, jitter %s, native scene scale %s",
            g_bridge.enabled ? "enabled" : "disabled", path, g_bridge.renderScale,
            g_bridge.jitterEnabled ? "on" : "off",
            g_bridge.nativeSceneScaleEnabled ? "on" : "off");
'@
$new = @'
        Msg("* [OptiBridge] runtime v0.4.0-alpha Action18");
        Msg("* [OptiBridge] %s (%s), render scale %.4f, jitter %s, native scene scale %s, projection jitter %s",
            g_bridge.enabled ? "enabled" : "disabled", path, g_bridge.renderScale,
            g_bridge.jitterEnabled ? "on" : "off",
            g_bridge.nativeSceneScaleEnabled ? "on" : "off",
            g_bridge.projectionJitterEnabled ? "on" : "off");
'@
$text = Replace-ExactlyOnce $text $old $new "Action18 runtime log seam"

# Action15 correctly disabled MV jitter cancellation while jitter was injected only
# through selected SSFX shaders. Action18 moves jitter into the actual projection, so
# native-scene motion vectors now carry the current/previous projection-jitter delta.
$old = @'
    // Action #15 diagnostic: SSFX supplies its motion-vector target directly.
    // Test FSR2 without assuming those vectors already contain camera jitter.
    desc.flags = FFX_FSR2_ENABLE_AUTO_EXPOSURE;
'@
$new = @'
    desc.flags = FFX_FSR2_ENABLE_AUTO_EXPOSURE;
    const bool action18ProjectionJitter = g_bridge.nativeSceneScaleEnabled &&
        g_bridge.projectionJitterEnabled && g_bridge.jitterEnabled && g_bridge.renderScale < 0.999f;
    if (action18ProjectionJitter)
        desc.flags |= FFX_FSR2_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION;
'@
$text = Replace-ExactlyOnce $text $old $new "Action18 FSR2 flag seam"

$old = @'
    g_bridge.contextValid = true;
    Msg("* [OptiBridge] Action15: motion-vector jitter cancellation disabled");
'@
$new = @'
    g_bridge.contextValid = true;
    if (action18ProjectionJitter)
        Msg("* [OptiBridge] Action18: projection jitter path enabled; motion-vector jitter cancellation enabled");
    else
        Msg("* [OptiBridge] Action15: motion-vector jitter cancellation disabled");
'@
$text = Replace-ExactlyOnce $text $old $new "Action18 context log seam"

# Once the projection is jittered globally, the old SSFX helper must return a zero
# XY offset so shaders that call ssfx_taa_jitter() do not apply the same jitter twice.
$old = @'
bool OptiBridge_GetJitterNdc(float& x, float& y)
{
    x = y = 0.f;
    if (!ReadEnabled() || Device.dwWidth == 0 || Device.dwHeight == 0)
        return false;
'@
$new = @'
bool OptiBridge_GetJitterNdc(float& x, float& y)
{
    x = y = 0.f;
    if (!ReadEnabled() || Device.dwWidth == 0 || Device.dwHeight == 0)
        return false;

    // Action18: scene projection already contains the FSR2 jitter. Keep the
    // SSFX constant active-but-zero to prevent the stock/per-shader path from
    // adding a second offset.
    if (g_bridge.projectionJitterActive)
        return true;
'@
$text = Replace-ExactlyOnce $text $old $new "Action18 SSFX double-jitter guard"

# Insert the projection-space path immediately before Action17 starts the scene.
$needle = 'bool OptiBridge_BeginSceneScale()'
$insert = @'
bool OptiBridge_ApplyProjectionJitter()
{
    if (!ReadEnabled() || !g_bridge.nativeSceneScaleEnabled || !g_bridge.projectionJitterEnabled ||
        !g_bridge.jitterEnabled || !g_bridge.frameNativeSceneScale || !g_bridge.sceneScaleActive ||
        Device.m_SecondViewport.IsSVPFrame())
        return false;

    if (g_bridge.projectionJitterActive)
        return true;

    float jitterPxX = 0.f;
    float jitterPxY = 0.f;
    CurrentJitter(jitterPxX, jitterPxY);

    const float renderWidth = float(_max(1u, Device.dwWidth));
    const float renderHeight = float(_max(1u, Device.dwHeight));
    const float jitterNdcX = 2.f * jitterPxX / renderWidth;
    const float jitterNdcY = -2.f * jitterPxY / renderHeight;

    g_bridge.savedProject.set(Device.mProject);
    g_bridge.savedProjectPrev.set(Device.mProject_prev);
    g_bridge.savedFullTransform.set(Device.mFullTransform);
    g_bridge.savedFullTransformPrev.set(Device.mFullTransform_prev);
    g_bridge.savedInvFullTransform.set(Device.mInvFullTransform);

    Device.mProject._31 += jitterNdcX;
    Device.mProject._32 += jitterNdcY;

    // The engine keeps an unjittered previous projection. Reconstruct the
    // previous jittered projection explicitly so SSFX velocity contains the
    // same camera-jitter delta that FSR2 is told about.
    const float previousX = g_bridge.previousProjectionJitterValid ? g_bridge.previousJitterNdcX : jitterNdcX;
    const float previousY = g_bridge.previousProjectionJitterValid ? g_bridge.previousJitterNdcY : jitterNdcY;
    Device.mProject_prev._31 += previousX;
    Device.mProject_prev._32 += previousY;

    Device.mFullTransform.mul(Device.mProject, Device.mView);
    Device.mFullTransform_prev.mul(Device.mProject_prev, Device.mView_prev);
    D3DXMatrixInverse((D3DXMATRIX*)&Device.mInvFullTransform, nullptr, (D3DXMATRIX*)&Device.mFullTransform);

    RCache.set_xform_project(Device.mProject);
    RCache.set_xform_project_prev(Device.mProject_prev);

    g_bridge.currentJitterNdcX = jitterNdcX;
    g_bridge.currentJitterNdcY = jitterNdcY;
    g_bridge.projectionJitterActive = true;

    if (!g_bridge.loggedProjectionJitter)
    {
        Msg("* [OptiBridge] Action18 global projection jitter ACTIVE: %.6f, %.6f NDC at %ux%u",
            jitterNdcX, jitterNdcY, Device.dwWidth, Device.dwHeight);
        g_bridge.loggedProjectionJitter = true;
    }

    return true;
}

'@
$count = ([regex]::Matches($text, [regex]::Escape($needle))).Count
if ($count -ne 1) { throw "Action18 projection helper insertion expected exactly once, got $count" }
$text = $text.Replace($needle, $insert + $needle)

# Restore native, unjittered matrices at the same late seam where Action17 restores
# display dimensions, after the temporal dispatch has consumed the jittered scene.
$old = @'
void OptiBridge_RestoreDisplayResolution()
{
    if (!g_bridge.sceneScaleActive)
        return;
    Device.dwWidth = g_bridge.savedDisplayWidth;
'@
$new = @'
void OptiBridge_RestoreDisplayResolution()
{
    if (!g_bridge.sceneScaleActive)
        return;

    if (g_bridge.projectionJitterActive)
    {
        Device.mProject.set(g_bridge.savedProject);
        Device.mProject_prev.set(g_bridge.savedProjectPrev);
        Device.mFullTransform.set(g_bridge.savedFullTransform);
        Device.mFullTransform_prev.set(g_bridge.savedFullTransformPrev);
        Device.mInvFullTransform.set(g_bridge.savedInvFullTransform);
        RCache.set_xform_project(Device.mProject);
        RCache.set_xform_project_prev(Device.mProject_prev);

        g_bridge.previousJitterNdcX = g_bridge.currentJitterNdcX;
        g_bridge.previousJitterNdcY = g_bridge.currentJitterNdcY;
        g_bridge.previousProjectionJitterValid = true;
        g_bridge.projectionJitterActive = false;
    }

    Device.dwWidth = g_bridge.savedDisplayWidth;
'@
$text = Replace-ExactlyOnce $text $old $new "Action18 restore seam"

Set-Content $runtime $text -NoNewline

# Apply global projection jitter after Action17 exposes low scene dimensions and
# before ViewBase/HOM/scene traversal consume Device.mFullTransform.
$render = Join-Path $rendererDir "r4_R_render.cpp"
$text = Get-Content $render -Raw
$old = @'
	// Action17: all scene-space code now sees the configured low resolution.
	OptiBridge_BeginSceneScale();

	//.	VERIFY
'@
$new = @'
	// Action17: all scene-space code now sees the configured low resolution.
	OptiBridge_BeginSceneScale();

	// Action18: FSR2 jitter belongs in the scene projection so every world pass
	// sees the same sample position. The SSFX shader helper is zeroed while active.
	OptiBridge_ApplyProjectionJitter();

	//.	VERIFY
'@
$text = Replace-ExactlyOnce $text $old $new "Action18 render-entry seam"
Set-Content $render $text -NoNewline

Write-Host "OptiBridge Action18 projection-space jitter patch applied successfully."
