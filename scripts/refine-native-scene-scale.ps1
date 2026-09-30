param(
    [Parameter(Mandatory=$true)][string]$XrayRoot
)

$ErrorActionPreference = "Stop"
$XrayRoot = (Resolve-Path $XrayRoot).Path
$rendererDir = Join-Path $XrayRoot "src\Layers\xrRenderPC_R4"

function Replace-Required([string]$Path, [string]$Old, [string]$New, [string]$Label) {
    $text = Get-Content $Path -Raw
    if (-not $text.Contains($Old)) { throw "$Label insertion point not found in $Path" }
    $text = $text.Replace($Old, $New)
    Set-Content $Path $text -NoNewline
}

# -----------------------------------------------------------------------------
# Public bridge hooks used by the R4 renderer during the scaled-scene prototype.
# -----------------------------------------------------------------------------
$header = Join-Path $rendererDir "OptiBridgeRuntime.h"
$headerText = Get-Content $header -Raw
$headerNeedle = @'
// Replaces the stock SSFX TAA resolve when enabled. Returns true only when
// the temporal dispatch completed and rt_Generic_0 now contains the result.
bool OptiBridge_Dispatch(CRenderTarget* target);
'@
$headerReplacement = @'
// Replaces the stock SSFX TAA resolve when enabled. Returns true only when
// the temporal dispatch completed.
bool OptiBridge_Dispatch(CRenderTarget* target);

// Action #17 native-scene-scale prototype. Render targets are created at the
// configured scene size while the swapchain/final presentation stay native.
bool OptiBridge_GetSceneRenderSize(u32 displayWidth, u32 displayHeight, u32& renderWidth, u32& renderHeight);
bool OptiBridge_BeginSceneScale();
void OptiBridge_RestoreDisplayResolution();
bool OptiBridge_IsSceneScaleActive();
bool OptiBridge_FrameUsesNativeSceneScale();
ID3D11DepthStencilView* OptiBridge_GetSceneDepthView();
ID3D11Texture2D* OptiBridge_GetUpscaledOutput();
'@
if (-not $headerText.Contains($headerNeedle.Trim())) { throw "OptiBridge runtime header seam not found" }
$headerText = $headerText.Replace($headerNeedle.Trim(), $headerReplacement.Trim())
Set-Content $header $headerText -NoNewline

# Make the depth helper usable from shared xrRender phase sources. Other renderer
# projects retain their stock depth view if they compile the same shared source.
$hwHeader = Join-Path $XrayRoot "src\Layers\xrRender\HW.h"
$hwText = Get-Content $hwHeader -Raw
$hwNeedle = 'extern ECORE_API CHW HW;'
$hwReplacement = @'
extern ECORE_API CHW HW;

#if defined(USE_DX11) && defined(XRRENDER_R4_EXPORTS)
ID3D11DepthStencilView* OptiBridge_GetSceneDepthView();
bool OptiBridge_FrameUsesNativeSceneScale();
#else
#if defined(USE_DX11)
IC ID3D11DepthStencilView* OptiBridge_GetSceneDepthView() { return HW.pBaseZB; }
#elif defined(USE_DX10)
IC ID3D10DepthStencilView* OptiBridge_GetSceneDepthView() { return HW.pBaseZB; }
#else
IC IDirect3DSurface9* OptiBridge_GetSceneDepthView() { return HW.pBaseZB; }
#endif
IC bool OptiBridge_FrameUsesNativeSceneScale() { return false; }
#endif
'@
if (-not $hwText.Contains($hwNeedle)) { throw "HW helper insertion point not found" }
$hwText = $hwText.Replace($hwNeedle, $hwReplacement.Trim())
Set-Content $hwHeader $hwText -NoNewline

# -----------------------------------------------------------------------------
# Extend the runtime state/config and add a low-resolution shader-readable DSV.
# -----------------------------------------------------------------------------
$runtime = Join-Path $rendererDir "OptiBridgeRuntime.cpp"
$text = Get-Content $runtime -Raw

$oldState = @'
    bool loggedMissingDepth = false;
    float renderScale = 1.0f;
    u32 displayWidth = 0;
'@
$newState = @'
    bool loggedMissingDepth = false;
    bool nativeSceneScaleEnabled = false;
    bool sceneScaleActive = false;
    bool frameNativeSceneScale = false;
    bool loggedNativeSceneScale = false;
    float renderScale = 1.0f;
    u32 savedDisplayWidth = 0;
    u32 savedDisplayHeight = 0;
    u32 sceneDepthWidth = 0;
    u32 sceneDepthHeight = 0;
    u32 displayWidth = 0;
'@
if (-not $text.Contains($oldState.Trim())) { throw "Action17 runtime state seam not found" }
$text = $text.Replace($oldState.Trim(), $newState.Trim())

$oldDepthState = @'
    ID3D11Resource* sourceDepth = nullptr;
    ID3D11ShaderResourceView* colorSourceSrv = nullptr;
'@
$newDepthState = @'
    ID3D11Texture2D* sceneDepth = nullptr;
    ID3D11DepthStencilView* sceneDepthDsv = nullptr;
    ID3D11Resource* sourceDepth = nullptr;
    ID3D11ShaderResourceView* colorSourceSrv = nullptr;
'@
if (-not $text.Contains($oldDepthState.Trim())) { throw "Action17 depth state seam not found" }
$text = $text.Replace($oldDepthState.Trim(), $newDepthState.Trim())

$oldConfig = @'
        g_bridge.enabled = GetPrivateProfileIntA("OptiBridge", "Enabled", 0, path) != 0;
        g_bridge.jitterEnabled = GetPrivateProfileIntA("OptiBridge", "Jitter", 1, path) != 0;

        char scaleText[32] = {};
'@
$newConfig = @'
        g_bridge.enabled = GetPrivateProfileIntA("OptiBridge", "Enabled", 0, path) != 0;
        g_bridge.jitterEnabled = GetPrivateProfileIntA("OptiBridge", "Jitter", 1, path) != 0;
        g_bridge.nativeSceneScaleEnabled = GetPrivateProfileIntA("OptiBridge", "NativeSceneScale", 0, path) != 0;

        char scaleText[32] = {};
'@
if (-not $text.Contains($oldConfig.Trim())) { throw "Action17 config seam not found" }
$text = $text.Replace($oldConfig.Trim(), $newConfig.Trim())

$oldLog = @'
        Msg("* [OptiBridge] runtime v0.3.2-alpha");
        Msg("* [OptiBridge] %s (%s), render scale %.4f, jitter %s",
            g_bridge.enabled ? "enabled" : "disabled", path, g_bridge.renderScale,
            g_bridge.jitterEnabled ? "on" : "off");
'@
$newLog = @'
        Msg("* [OptiBridge] runtime v0.3.9-alpha Action17");
        Msg("* [OptiBridge] %s (%s), render scale %.4f, jitter %s, native scene scale %s",
            g_bridge.enabled ? "enabled" : "disabled", path, g_bridge.renderScale,
            g_bridge.jitterEnabled ? "on" : "off",
            g_bridge.nativeSceneScaleEnabled ? "on" : "off");
'@
if (-not $text.Contains($oldLog.Trim())) { throw "Action17 runtime log seam not found" }
$text = $text.Replace($oldLog.Trim(), $newLog.Trim())

$createTextureNeedle = @'
bool CreateContext(u32 renderWidth, u32 renderHeight, u32 displayWidth, u32 displayHeight)
'@
$sceneDepthHelpers = @'
void DestroySceneDepth()
{
    ReleasePtr(g_bridge.sceneDepthDsv);
    ReleasePtr(g_bridge.sceneDepth);
    g_bridge.sceneDepthWidth = 0;
    g_bridge.sceneDepthHeight = 0;
}

bool EnsureSceneDepth(u32 width, u32 height)
{
    if (g_bridge.sceneDepth && g_bridge.sceneDepthDsv &&
        g_bridge.sceneDepthWidth == width && g_bridge.sceneDepthHeight == height)
        return true;

    DestroySceneDepth();

    D3D11_TEXTURE2D_DESC desc = {};
    desc.Width = width;
    desc.Height = height;
    desc.MipLevels = 1;
    desc.ArraySize = 1;
    desc.Format = DXGI_FORMAT_R24G8_TYPELESS;
    desc.SampleDesc.Count = 1;
    desc.Usage = D3D11_USAGE_DEFAULT;
    desc.BindFlags = D3D11_BIND_DEPTH_STENCIL | D3D11_BIND_SHADER_RESOURCE;
    if (FAILED(HW.pDevice->CreateTexture2D(&desc, nullptr, &g_bridge.sceneDepth)))
        return false;

    D3D11_DEPTH_STENCIL_VIEW_DESC dsv = {};
    dsv.Format = DXGI_FORMAT_D24_UNORM_S8_UINT;
    dsv.ViewDimension = D3D11_DSV_DIMENSION_TEXTURE2D;
    dsv.Texture2D.MipSlice = 0;
    if (FAILED(HW.pDevice->CreateDepthStencilView(g_bridge.sceneDepth, &dsv, &g_bridge.sceneDepthDsv)))
    {
        DestroySceneDepth();
        return false;
    }

    g_bridge.sceneDepthWidth = width;
    g_bridge.sceneDepthHeight = height;
    return true;
}

'@
if (-not $text.Contains($createTextureNeedle.Trim())) { throw "Action17 scene-depth insertion seam not found" }
$text = $text.Replace($createTextureNeedle.Trim(), ($sceneDepthHelpers + $createTextureNeedle.Trim()))

$oldEnsureStart = @'
    if (!target || !target->rt_Generic_0 || !target->rt_ssfx_motion_vectors || !HW.pBaseZB)
    {
        if (!g_bridge.loggedMissingTarget)
        {
            Msg("! [OptiBridge] runtime resources not ready: target=%p color=%p motion=%p depthView=%p",
                target,
                target ? &*target->rt_Generic_0 : nullptr,
                target ? &*target->rt_ssfx_motion_vectors : nullptr,
                HW.pBaseZB);
            g_bridge.loggedMissingTarget = true;
        }
        return false;
    }

    ID3D11Resource* depthResource = nullptr;
    HW.pBaseZB->GetResource(&depthResource);
'@
$newEnsureStart = @'
    ID3D11DepthStencilView* depthView = OptiBridge_GetSceneDepthView();
    if (!target || !target->rt_Generic_0 || !target->rt_ssfx_motion_vectors || !depthView)
    {
        if (!g_bridge.loggedMissingTarget)
        {
            Msg("! [OptiBridge] runtime resources not ready: target=%p color=%p motion=%p depthView=%p",
                target,
                target ? &*target->rt_Generic_0 : nullptr,
                target ? &*target->rt_ssfx_motion_vectors : nullptr,
                depthView);
            g_bridge.loggedMissingTarget = true;
        }
        return false;
    }

    ID3D11Resource* depthResource = nullptr;
    depthView->GetResource(&depthResource);
'@
if (-not $text.Contains($oldEnsureStart.Trim())) { throw "Action17 EnsureResources depth seam not found" }
$text = $text.Replace($oldEnsureStart.Trim(), $newEnsureStart.Trim())

$oldSizes = @'
    const u32 displayWidth = colorDesc.Width;
    const u32 displayHeight = colorDesc.Height;
    const u32 renderWidth = _max(1u, (u32)floorf(float(displayWidth) * g_bridge.renderScale + 0.5f));
    const u32 renderHeight = _max(1u, (u32)floorf(float(displayHeight) * g_bridge.renderScale + 0.5f));
'@
$newSizes = @'
    const bool nativeScene = g_bridge.frameNativeSceneScale && g_bridge.savedDisplayWidth && g_bridge.savedDisplayHeight;
    const u32 displayWidth = nativeScene ? g_bridge.savedDisplayWidth : colorDesc.Width;
    const u32 displayHeight = nativeScene ? g_bridge.savedDisplayHeight : colorDesc.Height;
    const u32 renderWidth = nativeScene ? colorDesc.Width :
        _max(1u, (u32)floorf(float(displayWidth) * g_bridge.renderScale + 0.5f));
    const u32 renderHeight = nativeScene ? colorDesc.Height :
        _max(1u, (u32)floorf(float(displayHeight) * g_bridge.renderScale + 0.5f));
'@
if (-not $text.Contains($oldSizes.Trim())) { throw "Action17 resource-size seam not found" }
$text = $text.Replace($oldSizes.Trim(), $newSizes.Trim())

$oldConfiguredSize = @'
void GetConfiguredRenderSize(u32& width, u32& height)
{
    width = _max(1u, (u32)floorf(float(Device.dwWidth) * g_bridge.renderScale + 0.5f));
    height = _max(1u, (u32)floorf(float(Device.dwHeight) * g_bridge.renderScale + 0.5f));
}
'@
$newConfiguredSize = @'
void GetConfiguredRenderSize(u32& width, u32& height)
{
    if (g_bridge.sceneScaleActive)
    {
        width = Device.dwWidth;
        height = Device.dwHeight;
        return;
    }
    width = _max(1u, (u32)floorf(float(Device.dwWidth) * g_bridge.renderScale + 0.5f));
    height = _max(1u, (u32)floorf(float(Device.dwHeight) * g_bridge.renderScale + 0.5f));
}
'@
if (-not $text.Contains($oldConfiguredSize.Trim())) { throw "Action17 configured render-size seam not found" }
$text = $text.Replace($oldConfiguredSize.Trim(), $newConfiguredSize.Trim())

$oldPhaseCount = 'const int phaseCount = _max(1, ffxFsr2GetJitterPhaseCount((int)renderWidth, (int)Device.dwWidth));'
$newPhaseCount = 'const u32 jitterDisplayWidth = g_bridge.sceneScaleActive && g_bridge.savedDisplayWidth ? g_bridge.savedDisplayWidth : Device.dwWidth;`r`n    const int phaseCount = _max(1, ffxFsr2GetJitterPhaseCount((int)renderWidth, (int)jitterDisplayWidth));'
if (-not $text.Contains($oldPhaseCount)) { throw "Action17 jitter phase-count seam not found" }
$text = $text.Replace($oldPhaseCount, $newPhaseCount.Replace('`r`n', [Environment]::NewLine))

$oldCopyBack = @'
    HW.pContext->CopyResource(target->rt_Generic_0->pSurface, g_bridge.output);
    RememberCamera();
'@
$newCopyBack = @'
    // Legacy scaled-input mode still writes the native result back into Generic_0.
    // In Action17 native-scene mode Generic_0 is intentionally low resolution;
    // final combine samples g_bridge.output through a dedicated texture alias.
    if (!g_bridge.frameNativeSceneScale)
        HW.pContext->CopyResource(target->rt_Generic_0->pSurface, g_bridge.output);
    RememberCamera();
'@
if (-not $text.Contains($oldCopyBack.Trim())) { throw "Action17 copy-back seam not found" }
$text = $text.Replace($oldCopyBack.Trim(), $newCopyBack.Trim())

$publicNeedle = @'
bool OptiBridge_Enabled()
{
    return ReadEnabled();
}
'@
$publicHelpers = @'
bool OptiBridge_GetSceneRenderSize(u32 displayWidth, u32 displayHeight, u32& renderWidth, u32& renderHeight)
{
    renderWidth = displayWidth;
    renderHeight = displayHeight;
    if (!ReadEnabled() || !g_bridge.nativeSceneScaleEnabled || g_bridge.renderScale >= 0.999f)
        return false;
    if (RImplementation.o.dx10_msaa || RImplementation.o.dx11_hdr10)
        return false;

    renderWidth = _max(1u, (u32)floorf(float(displayWidth) * g_bridge.renderScale + 0.5f));
    renderHeight = _max(1u, (u32)floorf(float(displayHeight) * g_bridge.renderScale + 0.5f));
    return renderWidth != displayWidth || renderHeight != displayHeight;
}

bool OptiBridge_BeginSceneScale()
{
    g_bridge.frameNativeSceneScale = false;
    g_bridge.sceneScaleActive = false;

    const u32 displayWidth = Device.dwWidth;
    const u32 displayHeight = Device.dwHeight;
    u32 renderWidth = displayWidth;
    u32 renderHeight = displayHeight;
    if (!OptiBridge_GetSceneRenderSize(displayWidth, displayHeight, renderWidth, renderHeight))
        return false;

    if (!EnsureSceneDepth(renderWidth, renderHeight))
    {
        Msg("! [OptiBridge] Action17 could not create %ux%u scene depth; using native rendering", renderWidth, renderHeight);
        return false;
    }

    g_bridge.savedDisplayWidth = displayWidth;
    g_bridge.savedDisplayHeight = displayHeight;
    g_bridge.sceneScaleActive = true;
    g_bridge.frameNativeSceneScale = true;
    Device.dwWidth = renderWidth;
    Device.dwHeight = renderHeight;

    D3D11_VIEWPORT vp = {};
    vp.TopLeftX = 0.f;
    vp.TopLeftY = 0.f;
    vp.Width = (float)renderWidth;
    vp.Height = (float)renderHeight;
    vp.MinDepth = 0.f;
    vp.MaxDepth = 1.f;
    HW.pContext->RSSetViewports(1, &vp);

    if (!g_bridge.loggedNativeSceneScale)
    {
        Msg("* [OptiBridge] Action17 native scene scale ACTIVE: %ux%u scene -> %ux%u display",
            renderWidth, renderHeight, displayWidth, displayHeight);
        g_bridge.loggedNativeSceneScale = true;
    }
    return true;
}

void OptiBridge_RestoreDisplayResolution()
{
    if (!g_bridge.sceneScaleActive)
        return;

    Device.dwWidth = g_bridge.savedDisplayWidth;
    Device.dwHeight = g_bridge.savedDisplayHeight;

    D3D11_VIEWPORT vp = {};
    vp.TopLeftX = 0.f;
    vp.TopLeftY = 0.f;
    vp.Width = (float)Device.dwWidth;
    vp.Height = (float)Device.dwHeight;
    vp.MinDepth = 0.f;
    vp.MaxDepth = 1.f;
    HW.pContext->RSSetViewports(1, &vp);

    g_bridge.sceneScaleActive = false;
}

bool OptiBridge_IsSceneScaleActive()
{
    return g_bridge.sceneScaleActive;
}

bool OptiBridge_FrameUsesNativeSceneScale()
{
    return g_bridge.frameNativeSceneScale;
}

ID3D11DepthStencilView* OptiBridge_GetSceneDepthView()
{
    if (g_bridge.sceneScaleActive && g_bridge.sceneDepthDsv)
        return g_bridge.sceneDepthDsv;
    return HW.pBaseZB;
}

ID3D11Texture2D* OptiBridge_GetUpscaledOutput()
{
    return g_bridge.output;
}

'@
if (-not $text.Contains($publicNeedle.Trim())) { throw "Action17 public helper seam not found" }
$text = $text.Replace($publicNeedle.Trim(), ($publicHelpers + $publicNeedle.Trim()))
Set-Content $runtime $text -NoNewline

# -----------------------------------------------------------------------------
# Create low-resolution scene targets but preserve native final/menu/PDA targets.
# -----------------------------------------------------------------------------
$targetCpp = Join-Path $rendererDir "r4_rendertarget.cpp"
$text = Get-Content $targetCpp -Raw
$oldWH = 'u32 w = Device.dwWidth, h = Device.dwHeight;'
$newWH = @'
u32 displayW = Device.dwWidth, displayH = Device.dwHeight;
		u32 w = displayW, h = displayH;
		const bool optiNativeSceneScale = OptiBridge_GetSceneRenderSize(displayW, displayH, w, h);
		if (optiNativeSceneScale)
			Msg("* [OptiBridge] Action17 allocating scaled R4 scene targets: %ux%u (display %ux%u)", w, h, displayW, displayH);
'@
if (-not $text.Contains($oldWH)) { throw "Action17 R4 target-size seam not found" }
$text = $text.Replace($oldWH, $newWH.Trim())

# Native output target used by phase_pp after the final combine.
$text = $text.Replace('rt_Generic.create(r2_RT_generic, w, h', 'rt_Generic.create(r2_RT_generic, displayW, displayH')
# Second viewport and PDA copies are fed directly from the native swapchain.
$text = $text.Replace('rt_secondVP.create(r2_RT_secondVP, w, h', 'rt_secondVP.create(r2_RT_secondVP, displayW, displayH')
$text = $text.Replace('rt_ui_pda.create(r2_RT_pda_ui, w, h', 'rt_ui_pda.create(r2_RT_pda_ui, displayW, displayH')

$aliasCreateNeedle = 'rt_fakescope.create(r2_RT_scopert, w, h, D3DFMT_A8R8G8B8, 1); //crookr fakescope'
$aliasCreateReplacement = $aliasCreateNeedle + [Environment]::NewLine + "`t`tt_OptiBridgeUpscaled.create(\"`$user`$optibridge_upscaled\");"
if (-not $text.Contains($aliasCreateNeedle)) { throw "Action17 texture-alias create seam not found" }
$text = $text.Replace($aliasCreateNeedle, $aliasCreateReplacement)
Set-Content $targetCpp $text -NoNewline

$targetHeader = Join-Path $rendererDir "r4_rendertarget.h"
$text = Get-Content $targetHeader -Raw
$aliasFieldNeedle = 'ref_texture t_LUM_dest; // destination & usage for current frame'
$aliasFieldReplacement = $aliasFieldNeedle + [Environment]::NewLine + "`tref_texture t_OptiBridgeUpscaled; // Action17 native FSR2/DLSS result for final combine"
if (-not $text.Contains($aliasFieldNeedle)) { throw "Action17 texture-alias header seam not found" }
$text = $text.Replace($aliasFieldNeedle, $aliasFieldReplacement)
Set-Content $targetHeader $text -NoNewline

# Final combine samples a dynamic alias: native FSR2 output on successful Action17
# frames, or Generic_0 for stock/fallback rendering.
$blender = Join-Path $rendererDir "blender_combine.cpp"
$text = Get-Content $blender -Raw
$genericBinding = 'C.r_dx10Texture("s_image", r2_RT_generic0);'
$bindingCount = ([regex]::Matches($text, [regex]::Escape($genericBinding))).Count
if ($bindingCount -ne 4) { throw "Expected 4 final-combine Generic_0 bindings, found $bindingCount" }
$text = $text.Replace($genericBinding, 'C.r_dx10Texture("s_image", "$user$optibridge_upscaled");')
Set-Content $blender $text -NoNewline

# Enter scaled Device dimensions only for the actual world render. Menus and
# early-outs stay at native display resolution.
$render = Join-Path $rendererDir "r4_R_render.cpp"
$text = Get-Content $render -Raw
$beginNeedle = @'
	if (m_bFirstFrameAfterReset)
	{
		m_bFirstFrameAfterReset = false;
		return;
	}

	//.	VERIFY
'@
$beginReplacement = @'
	if (m_bFirstFrameAfterReset)
	{
		m_bFirstFrameAfterReset = false;
		return;
	}

	// Action #17: temporarily make Device dimensions describe the low-resolution
	// R4 scene. The temporal seam restores native dimensions before final combine.
	OptiBridge_BeginSceneScale();

	//.	VERIFY
'@
if (-not $text.Contains($beginNeedle.Trim())) { throw "Action17 render begin seam not found" }
$text = $text.Replace($beginNeedle.Trim(), $beginReplacement.Trim())
Set-Content $render $text -NoNewline

# Patch the late temporal seam to expose the native FSR2 result to combine_2 and
# restore Device dimensions before native final presentation.
$combine = Join-Path $rendererDir "r4_rendertarget_phase_combine.cpp"
$text = Get-Content $combine -Raw
$taaSeam = @'
	const bool optiBridgeResolved = OptiBridge_Dispatch(this);
	if (!optiBridgeResolved && RImplementation.o.ssfx_taa && ps_ssfx_taa.x > 0)
	{
		phase_ssfx_taa();
	}
'@
$taaReplacement = @'
	const bool optiBridgeResolved = OptiBridge_Dispatch(this);
	if (!optiBridgeResolved && RImplementation.o.ssfx_taa && ps_ssfx_taa.x > 0)
	{
		phase_ssfx_taa();
	}

	ID3D11Texture2D* optiUpscaled = OptiBridge_GetUpscaledOutput();
	if (optiBridgeResolved && optiUpscaled)
		t_OptiBridgeUpscaled->surface_set(optiUpscaled);
	else
		t_OptiBridgeUpscaled->surface_set(rt_Generic_0->pSurface);

	// Everything before this point is allowed to use the scaled Device dimensions.
	// combine_2, phase_pp and the physical swapchain remain native resolution.
	OptiBridge_RestoreDisplayResolution();
'@
if (-not $text.Contains($taaSeam.Trim())) { throw "Action17 temporal handoff seam not found" }
$text = $text.Replace($taaSeam.Trim(), $taaReplacement.Trim())

$finalTargetNeedle = @'
	else
	{
		if (PP_Complex) u_setrt(rt_Color, 0, 0, HW.pBaseZB); // LDR RT
		else u_setrt(Device.dwWidth, Device.dwHeight, HW.pBaseRT,NULL,NULL, HW.pBaseZB);
	}
'@
$finalTargetReplacement = @'
	else
	{
		if (PP_Complex)
		{
			if (OptiBridge_FrameUsesNativeSceneScale())
				u_setrt(rt_Generic, 0, 0, nullptr); // native Action17 final-combine target
			else
				u_setrt(rt_Color, 0, 0, HW.pBaseZB); // stock LDR RT
		}
		else u_setrt(Device.dwWidth, Device.dwHeight, HW.pBaseRT,NULL,NULL, HW.pBaseZB);
	}
'@
if (-not $text.Contains($finalTargetNeedle.Trim())) { throw "Action17 final-combine target seam not found" }
$text = $text.Replace($finalTargetNeedle.Trim(), $finalTargetReplacement.Trim())
Set-Content $combine $text -NoNewline

# Route scene/post phases to the Action17 low-resolution DSV while scene scaling
# is active. The helper resolves to HW.pBaseZB at all other times.
$depthFiles = @()
$depthFiles += Get-ChildItem $rendererDir -Recurse -Filter '*.cpp' | Where-Object { $_.Name -ne 'OptiBridgeRuntime.cpp' }
$sharedRenderDir = Join-Path $XrayRoot 'src\Layers\xrRender'
$depthFiles += Get-ChildItem $sharedRenderDir -Filter 'rendertarget_*.cpp'
foreach ($file in $depthFiles | Sort-Object FullName -Unique)
{
    $src = Get-Content $file.FullName -Raw
    if ($src.Contains('HW.pBaseZB'))
    {
        $src = $src.Replace('HW.pBaseZB', 'OptiBridge_GetSceneDepthView()')
        Set-Content $file.FullName $src -NoNewline
    }
}

# Occlusion queries do not need a color target. Avoid binding the native
# backbuffer beside the low-resolution scene DSV during Action17 frames.
$occq = Join-Path $rendererDir 'r4_rendertarget_phase_occq.cpp'
$text = Get-Content $occq -Raw
$occqNeedle = 'u_setrt(Device.dwWidth, Device.dwHeight, HW.pBaseRT,NULL,NULL, OptiBridge_GetSceneDepthView());'
$occqReplacement = @'
if (OptiBridge_FrameUsesNativeSceneScale())
		u_setrt(Device.dwWidth, Device.dwHeight, NULL,NULL,NULL, OptiBridge_GetSceneDepthView());
	else
		u_setrt(Device.dwWidth, Device.dwHeight, HW.pBaseRT,NULL,NULL, OptiBridge_GetSceneDepthView());
'@
if (-not $text.Contains($occqNeedle)) { throw "Action17 OCCQ depth-only seam not found" }
$text = $text.Replace($occqNeedle, $occqReplacement.Trim())
Set-Content $occq $text -NoNewline

Write-Host "OptiBridge Action17 native scene scale prototype applied successfully."
