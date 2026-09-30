param(
    [Parameter(Mandatory=$true)][string]$XrayRoot
)

$ErrorActionPreference = "Stop"
$XrayRoot = (Resolve-Path $XrayRoot).Path
$rendererDir = Join-Path $XrayRoot "src\Layers\xrRenderPC_R4"
$nl = [Environment]::NewLine

# Public renderer/runtime contract.
$header = Join-Path $rendererDir "OptiBridgeRuntime.h"
$text = Get-Content $header -Raw
$old = @'
// Replaces the stock SSFX TAA resolve when enabled. Returns true only when
// the temporal dispatch completed and rt_Generic_0 now contains the result.
bool OptiBridge_Dispatch(CRenderTarget* target);
'@
$new = @'
// Replaces the stock SSFX TAA resolve when enabled. Returns true only when
// the temporal dispatch completed.
bool OptiBridge_Dispatch(CRenderTarget* target);

// Action #17: real low-resolution R4 scene targets with native presentation.
bool OptiBridge_GetSceneRenderSize(u32 displayWidth, u32 displayHeight, u32& renderWidth, u32& renderHeight);
bool OptiBridge_BeginSceneScale();
void OptiBridge_RestoreDisplayResolution();
bool OptiBridge_IsSceneScaleActive();
bool OptiBridge_FrameUsesNativeSceneScale();
ID3D11DepthStencilView* OptiBridge_GetSceneDepthView();
ID3D11Texture2D* OptiBridge_GetUpscaledOutput();
'@
if (-not $text.Contains($old.Trim())) { throw "Action17 header seam not found" }
$text = $text.Replace($old.Trim(), $new.Trim())
Set-Content $header $text -NoNewline

# Shared render phases can call the R4 depth helper; non-R4 projects fall back
# to their normal base depth view.
$hw = Join-Path $XrayRoot "src\Layers\xrRender\HW.h"
$text = Get-Content $hw -Raw
$needle = 'extern ECORE_API CHW HW;'
$replacement = @'
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
if (-not $text.Contains($needle)) { throw "Action17 HW helper seam not found" }
$text = $text.Replace($needle, $replacement.Trim())
Set-Content $hw $text -NoNewline

# Runtime state/config.
$runtime = Join-Path $rendererDir "OptiBridgeRuntime.cpp"
$text = Get-Content $runtime -Raw
$old = @'
    bool loggedMissingDepth = false;
    float renderScale = 1.0f;
    u32 displayWidth = 0;
'@
$new = @'
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
if (-not $text.Contains($old.Trim())) { throw "Action17 state seam not found" }
$text = $text.Replace($old.Trim(), $new.Trim())

$old = @'
    ID3D11Resource* sourceDepth = nullptr;
    ID3D11ShaderResourceView* colorSourceSrv = nullptr;
'@
$new = @'
    ID3D11Texture2D* sceneDepth = nullptr;
    ID3D11DepthStencilView* sceneDepthDsv = nullptr;
    ID3D11Resource* sourceDepth = nullptr;
    ID3D11ShaderResourceView* colorSourceSrv = nullptr;
'@
if (-not $text.Contains($old.Trim())) { throw "Action17 depth-state seam not found" }
$text = $text.Replace($old.Trim(), $new.Trim())

$old = @'
        g_bridge.enabled = GetPrivateProfileIntA("OptiBridge", "Enabled", 0, path) != 0;
        g_bridge.jitterEnabled = GetPrivateProfileIntA("OptiBridge", "Jitter", 1, path) != 0;

        char scaleText[32] = {};
'@
$new = @'
        g_bridge.enabled = GetPrivateProfileIntA("OptiBridge", "Enabled", 0, path) != 0;
        g_bridge.jitterEnabled = GetPrivateProfileIntA("OptiBridge", "Jitter", 1, path) != 0;
        g_bridge.nativeSceneScaleEnabled = GetPrivateProfileIntA("OptiBridge", "NativeSceneScale", 0, path) != 0;

        char scaleText[32] = {};
'@
if (-not $text.Contains($old.Trim())) { throw "Action17 config seam not found" }
$text = $text.Replace($old.Trim(), $new.Trim())

$old = @'
        Msg("* [OptiBridge] runtime v0.3.2-alpha");
        Msg("* [OptiBridge] %s (%s), render scale %.4f, jitter %s",
            g_bridge.enabled ? "enabled" : "disabled", path, g_bridge.renderScale,
            g_bridge.jitterEnabled ? "on" : "off");
'@
$new = @'
        Msg("* [OptiBridge] runtime v0.3.9-alpha Action17");
        Msg("* [OptiBridge] %s (%s), render scale %.4f, jitter %s, native scene scale %s",
            g_bridge.enabled ? "enabled" : "disabled", path, g_bridge.renderScale,
            g_bridge.jitterEnabled ? "on" : "off",
            g_bridge.nativeSceneScaleEnabled ? "on" : "off");
'@
if (-not $text.Contains($old.Trim())) { throw "Action17 log seam not found" }
$text = $text.Replace($old.Trim(), $new.Trim())

# Low-resolution typeless depth buffer, readable by FSR2 and writable by R4.
$needle = 'bool CreateContext(u32 renderWidth, u32 renderHeight, u32 displayWidth, u32 displayHeight)'
$helpers = @'
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
if (-not $text.Contains($needle)) { throw "Action17 depth helper insertion seam not found" }
$text = $text.Replace($needle, $helpers + $needle)

$old = @'
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
$new = @'
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
if (-not $text.Contains($old.Trim())) { throw "Action17 EnsureResources depth seam not found" }
$text = $text.Replace($old.Trim(), $new.Trim())

$old = @'
    const u32 displayWidth = colorDesc.Width;
    const u32 displayHeight = colorDesc.Height;
    const u32 renderWidth = _max(1u, (u32)floorf(float(displayWidth) * g_bridge.renderScale + 0.5f));
    const u32 renderHeight = _max(1u, (u32)floorf(float(displayHeight) * g_bridge.renderScale + 0.5f));
'@
$new = @'
    const bool nativeScene = g_bridge.frameNativeSceneScale && g_bridge.savedDisplayWidth && g_bridge.savedDisplayHeight;
    const u32 displayWidth = nativeScene ? g_bridge.savedDisplayWidth : colorDesc.Width;
    const u32 displayHeight = nativeScene ? g_bridge.savedDisplayHeight : colorDesc.Height;
    const u32 renderWidth = nativeScene ? colorDesc.Width :
        _max(1u, (u32)floorf(float(displayWidth) * g_bridge.renderScale + 0.5f));
    const u32 renderHeight = nativeScene ? colorDesc.Height :
        _max(1u, (u32)floorf(float(displayHeight) * g_bridge.renderScale + 0.5f));
'@
if (-not $text.Contains($old.Trim())) { throw "Action17 resource size seam not found" }
$text = $text.Replace($old.Trim(), $new.Trim())

$old = @'
void GetConfiguredRenderSize(u32& width, u32& height)
{
    width = _max(1u, (u32)floorf(float(Device.dwWidth) * g_bridge.renderScale + 0.5f));
    height = _max(1u, (u32)floorf(float(Device.dwHeight) * g_bridge.renderScale + 0.5f));
}
'@
$new = @'
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
if (-not $text.Contains($old.Trim())) { throw "Action17 jitter render size seam not found" }
$text = $text.Replace($old.Trim(), $new.Trim())

$old = 'const int phaseCount = _max(1, ffxFsr2GetJitterPhaseCount((int)renderWidth, (int)Device.dwWidth));'
$new = 'const u32 jitterDisplayWidth = g_bridge.sceneScaleActive && g_bridge.savedDisplayWidth ? g_bridge.savedDisplayWidth : Device.dwWidth;' + $nl +
       '    const int phaseCount = _max(1, ffxFsr2GetJitterPhaseCount((int)renderWidth, (int)jitterDisplayWidth));'
if (-not $text.Contains($old)) { throw "Action17 jitter phase seam not found" }
$text = $text.Replace($old, $new)

$old = @'
    HW.pContext->CopyResource(target->rt_Generic_0->pSurface, g_bridge.output);
    RememberCamera();
'@
$new = @'
    // Native-scene mode keeps Generic_0 low resolution. The final combine
    // samples g_bridge.output through the Action17 texture alias instead.
    if (!g_bridge.frameNativeSceneScale)
        HW.pContext->CopyResource(target->rt_Generic_0->pSurface, g_bridge.output);
    RememberCamera();
'@
if (-not $text.Contains($old.Trim())) { throw "Action17 copy-back seam not found" }
$text = $text.Replace($old.Trim(), $new.Trim())

$needle = @'
bool OptiBridge_Enabled()
{
    return ReadEnabled();
}
'@
$public = @'
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
        Msg("! [OptiBridge] Action17 could not create %ux%u scene depth; native scene scale disabled for this frame", renderWidth, renderHeight);
        return false;
    }

    g_bridge.savedDisplayWidth = displayWidth;
    g_bridge.savedDisplayHeight = displayHeight;
    g_bridge.sceneScaleActive = true;
    g_bridge.frameNativeSceneScale = true;
    Device.dwWidth = renderWidth;
    Device.dwHeight = renderHeight;

    D3D11_VIEWPORT vp = {};
    vp.Width = (float)renderWidth;
    vp.Height = (float)renderHeight;
    vp.MinDepth = 0.f;
    vp.MaxDepth = 1.f;
    HW.pContext->RSSetViewports(1, &vp);

    if (!g_bridge.loggedNativeSceneScale)
    {
        Msg("* [OptiBridge] Action17 native scene scale ACTIVE: %ux%u scene -> %ux%u display", renderWidth, renderHeight, displayWidth, displayHeight);
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
if (-not $text.Contains($needle.Trim())) { throw "Action17 public API seam not found" }
$text = $text.Replace($needle.Trim(), $public + $needle.Trim())
Set-Content $runtime $text -NoNewline

# R4 target allocation. Most scene/post targets use w/h; native final/PDA/SVP
# targets explicitly use displayW/displayH.
$targetCpp = Join-Path $rendererDir "r4_rendertarget.cpp"
$text = Get-Content $targetCpp -Raw
if (-not $text.Contains('#include "stdafx.h"')) { throw "R4 target include seam not found" }
$text = $text.Replace('#include "stdafx.h"', '#include "stdafx.h"' + $nl + '#include "OptiBridgeRuntime.h"')
$old = 'u32 w = Device.dwWidth, h = Device.dwHeight;'
$new = @'
u32 displayW = Device.dwWidth, displayH = Device.dwHeight;
		u32 w = displayW, h = displayH;
		const bool optiNativeSceneScale = OptiBridge_GetSceneRenderSize(displayW, displayH, w, h);
		if (optiNativeSceneScale)
			Msg("* [OptiBridge] Action17 allocating scaled R4 scene targets: %ux%u (display %ux%u)", w, h, displayW, displayH);
'@
if (-not $text.Contains($old)) { throw "Action17 R4 target-size seam not found" }
$text = $text.Replace($old, $new.Trim())
$text = $text.Replace('rt_Generic.create(r2_RT_generic, w, h', 'rt_Generic.create(r2_RT_generic, displayW, displayH')
$text = $text.Replace('rt_secondVP.create(r2_RT_secondVP, w, h', 'rt_secondVP.create(r2_RT_secondVP, displayW, displayH')
$text = $text.Replace('rt_ui_pda.create(r2_RT_ui, w, h', 'rt_ui_pda.create(r2_RT_ui, displayW, displayH')
$aliasNeedle = 'rt_fakescope.create(r2_RT_scopert, w, h, D3DFMT_A8R8G8B8, 1); //crookr fakescope'
if (-not $text.Contains($aliasNeedle)) { throw "Action17 alias create seam not found" }
$aliasLine = ([char]9).ToString() + ([char]9).ToString() + 't_OptiBridgeUpscaled.create("$user$optibridge_upscaled");'
$text = $text.Replace($aliasNeedle, $aliasNeedle + $nl + $aliasLine)
Set-Content $targetCpp $text -NoNewline

$targetHeader = Join-Path $rendererDir "r4_rendertarget.h"
$text = Get-Content $targetHeader -Raw
$needleField = 'ref_texture t_LUM_dest; // destination & usage for current frame'
if (-not $text.Contains($needleField)) { throw "Action17 alias field seam not found" }
$text = $text.Replace($needleField, $needleField + $nl + ([char]9) + 'ref_texture t_OptiBridgeUpscaled; // Action17 native temporal result')
Set-Content $targetHeader $text -NoNewline

# Dynamic native temporal texture alias for final combine. R4 defines the four
# normal and four MSAA variants in the same blender source, so all eight must
# bind the dynamic alias even though the Action17 prototype itself rejects MSAA.
$blender = Join-Path $rendererDir "blender_combine.cpp"
$text = Get-Content $blender -Raw
$binding = 'C.r_dx10Texture("s_image", r2_RT_generic0);'
$count = ([regex]::Matches($text, [regex]::Escape($binding))).Count
if ($count -ne 8) { throw "Expected 8 final-combine image bindings, got $count" }
$text = $text.Replace($binding, 'C.r_dx10Texture("s_image", "$user$optibridge_upscaled");')
Set-Content $blender $text -NoNewline

# Temporarily expose low scene dimensions through Device during the world render.
$render = Join-Path $rendererDir "r4_R_render.cpp"
$text = Get-Content $render -Raw
$text = $text.Replace('#include "stdafx.h"', '#include "stdafx.h"' + $nl + '#include "OptiBridgeRuntime.h"')
$old = @'
	if (m_bFirstFrameAfterReset)
	{
		m_bFirstFrameAfterReset = false;
		return;
	}

	//.	VERIFY
'@
$new = @'
	if (m_bFirstFrameAfterReset)
	{
		m_bFirstFrameAfterReset = false;
		return;
	}

	// Action17: all scene-space code now sees the configured low resolution.
	OptiBridge_BeginSceneScale();

	//.	VERIFY
'@
if (-not $text.Contains($old.Trim())) { throw "Action17 render begin seam not found" }
$text = $text.Replace($old.Trim(), $new.Trim())
Set-Content $render $text -NoNewline

# Late temporal handoff: bind FSR2/DLSS native output, then restore native Device
# dimensions before combine_2 and phase_pp.
$combine = Join-Path $rendererDir "r4_rendertarget_phase_combine.cpp"
$text = Get-Content $combine -Raw
$old = @'
	const bool optiBridgeResolved = OptiBridge_Dispatch(this);
	if (!optiBridgeResolved && RImplementation.o.ssfx_taa && ps_ssfx_taa.x > 0)
	{
		phase_ssfx_taa();
	}
'@
$new = @'
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

	OptiBridge_RestoreDisplayResolution();
'@
if (-not $text.Contains($old.Trim())) { throw "Action17 temporal seam not found" }
$text = $text.Replace($old.Trim(), $new.Trim())

$old = @'
	else
	{
		if (PP_Complex) u_setrt(rt_Color, 0, 0, HW.pBaseZB); // LDR RT
		else u_setrt(Device.dwWidth, Device.dwHeight, HW.pBaseRT,NULL,NULL, HW.pBaseZB);
	}
'@
$new = @'
	else
	{
		if (PP_Complex)
		{
			if (OptiBridge_FrameUsesNativeSceneScale())
				u_setrt(rt_Generic, 0, 0, nullptr); // native Action17 final-combine target
			else
				u_setrt(rt_Color, 0, 0, HW.pBaseZB); // stock LDR target
		}
		else u_setrt(Device.dwWidth, Device.dwHeight, HW.pBaseRT,NULL,NULL, HW.pBaseZB);
	}
'@
if (-not $text.Contains($old.Trim())) { throw "Action17 final combine target seam not found" }
$text = $text.Replace($old.Trim(), $new.Trim())
Set-Content $combine $text -NoNewline

# Scene and shared post phases use the low-resolution DSV only while Action17 is
# active. OptiBridgeRuntime.cpp itself is excluded so its native fallback remains
# explicit and easy to audit.
$files = @()
$files += Get-ChildItem $rendererDir -Recurse -Filter '*.cpp' | Where-Object { $_.Name -ne 'OptiBridgeRuntime.cpp' }
$shared = Join-Path $XrayRoot 'src\Layers\xrRender'
$files += Get-ChildItem $shared -Filter 'rendertarget_*.cpp'
foreach ($file in $files | Sort-Object FullName -Unique)
{
    $src = Get-Content $file.FullName -Raw
    if ($src.Contains('HW.pBaseZB'))
    {
        $src = $src.Replace('HW.pBaseZB', 'OptiBridge_GetSceneDepthView()')
        Set-Content $file.FullName $src -NoNewline
    }
}

# OCCQ writes no color. Never pair the native swapchain RT with the scaled DSV.
$occq = Join-Path $rendererDir 'r4_rendertarget_phase_occq.cpp'
$text = Get-Content $occq -Raw
$needle = 'u_setrt(Device.dwWidth, Device.dwHeight, HW.pBaseRT,NULL,NULL, OptiBridge_GetSceneDepthView());'
$replacement = @'
if (OptiBridge_FrameUsesNativeSceneScale())
		u_setrt(Device.dwWidth, Device.dwHeight, NULL,NULL,NULL, OptiBridge_GetSceneDepthView());
	else
		u_setrt(Device.dwWidth, Device.dwHeight, HW.pBaseRT,NULL,NULL, OptiBridge_GetSceneDepthView());
'@
if (-not $text.Contains($needle)) { throw "Action17 OCCQ seam not found" }
$text = $text.Replace($needle, $replacement.Trim())
Set-Content $occq $text -NoNewline

Write-Host "OptiBridge Action17 native scene scale v2 patch applied successfully."
