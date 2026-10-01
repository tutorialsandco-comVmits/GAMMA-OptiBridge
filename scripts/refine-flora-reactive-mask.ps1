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

# Action20 uses GAMMA's packed G-buffer material ID to synthesize a flora-only
# reactive/current-color-bias mask. This leaves the global projection jitter
# coherent and asks the temporal upscaler to trust unstable alpha-tested flora
# more strongly at the current frame.
$old = @'
    float jitterScale = 1.0f;
    float dispatchJitterScale = 1.0f;
    float motionVectorScaleFactor = 1.0f;
    bool mvJitterCancellationEnabled = true;
    Fmatrix savedProject = {};
'@
$new = @'
    float jitterScale = 1.0f;
    float dispatchJitterScale = 1.0f;
    float motionVectorScaleFactor = 1.0f;
    bool mvJitterCancellationEnabled = true;
    bool floraReactiveMaskEnabled = false;
    float floraReactiveStrength = 1.0f;
    bool loggedFloraReactive = false;
    Fmatrix savedProject = {};
'@
$text = Replace-ExactlyOnce $text $old $new "Action20 state/config seam"

$old = @'
    ID3D11ShaderResourceView* colorSourceSrv = nullptr;
    ID3D11ShaderResourceView* depthSourceSrv = nullptr;
    ID3D11ShaderResourceView* motionSourceSrv = nullptr;

    ID3D11Texture2D* colorLow = nullptr;
'@
$new = @'
    ID3D11ShaderResourceView* colorSourceSrv = nullptr;
    ID3D11ShaderResourceView* depthSourceSrv = nullptr;
    ID3D11ShaderResourceView* motionSourceSrv = nullptr;
    ID3D11ShaderResourceView* positionSourceSrv = nullptr;

    ID3D11Texture2D* colorLow = nullptr;
'@
$text = Replace-ExactlyOnce $text $old $new "Action20 position SRV state seam"

$old = @'
    ID3D11Texture2D* motionRg = nullptr;
    ID3D11UnorderedAccessView* motionRgUav = nullptr;
    ID3D11Texture2D* output = nullptr;

    ID3D11ComputeShader* prepareShader = nullptr;
'@
$new = @'
    ID3D11Texture2D* motionRg = nullptr;
    ID3D11UnorderedAccessView* motionRgUav = nullptr;
    ID3D11Texture2D* floraReactive = nullptr;
    ID3D11UnorderedAccessView* floraReactiveUav = nullptr;
    ID3D11Texture2D* output = nullptr;

    ID3D11ComputeShader* prepareShader = nullptr;
    ID3D11Buffer* prepareConstants = nullptr;
'@
$text = Replace-ExactlyOnce $text $old $new "Action20 reactive resource state seam"

# Config controls. Safe repository default remains OFF; the test package can
# opt in without requiring another executable build.
$old = @'
        g_bridge.projectionJitterEnabled = GetPrivateProfileIntA("OptiBridge", "ProjectionJitter", 1, path) != 0;
        g_bridge.mvJitterCancellationEnabled = GetPrivateProfileIntA("OptiBridge", "MVJitterCancellation", 1, path) != 0;

        char scaleText[32] = {};
'@
$new = @'
        g_bridge.projectionJitterEnabled = GetPrivateProfileIntA("OptiBridge", "ProjectionJitter", 1, path) != 0;
        g_bridge.mvJitterCancellationEnabled = GetPrivateProfileIntA("OptiBridge", "MVJitterCancellation", 1, path) != 0;
        g_bridge.floraReactiveMaskEnabled = GetPrivateProfileIntA("OptiBridge", "FloraReactiveMask", 0, path) != 0;

        char scaleText[32] = {};
'@
$text = Replace-ExactlyOnce $text $old $new "Action20 config boolean seam"

$old = @'
        char mvScaleText[32] = {};
        GetPrivateProfileStringA("OptiBridge", "MotionVectorScaleFactor", "1.0", mvScaleText, sizeof(mvScaleText), path);
        g_bridge.motionVectorScaleFactor = (float)atof(mvScaleText);
        g_bridge.motionVectorScaleFactor = _max(-2.0f, _min(2.0f, g_bridge.motionVectorScaleFactor));
'@
$new = @'
        char mvScaleText[32] = {};
        GetPrivateProfileStringA("OptiBridge", "MotionVectorScaleFactor", "1.0", mvScaleText, sizeof(mvScaleText), path);
        g_bridge.motionVectorScaleFactor = (float)atof(mvScaleText);
        g_bridge.motionVectorScaleFactor = _max(-2.0f, _min(2.0f, g_bridge.motionVectorScaleFactor));

        char floraStrengthText[32] = {};
        GetPrivateProfileStringA("OptiBridge", "FloraReactiveStrength", "1.0", floraStrengthText, sizeof(floraStrengthText), path);
        g_bridge.floraReactiveStrength = (float)atof(floraStrengthText);
        g_bridge.floraReactiveStrength = _max(0.0f, _min(1.0f, g_bridge.floraReactiveStrength));
'@
$text = Replace-ExactlyOnce $text $old $new "Action20 strength config seam"

$old = @'
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
$new = @'
        Msg("* [OptiBridge] runtime v0.4.2-alpha Action20 flora reactive mask");
        Msg("* [OptiBridge] %s (%s), render scale %.4f, jitter %s, native scene scale %s, projection jitter %s",
            g_bridge.enabled ? "enabled" : "disabled", path, g_bridge.renderScale,
            g_bridge.jitterEnabled ? "on" : "off",
            g_bridge.nativeSceneScaleEnabled ? "on" : "off",
            g_bridge.projectionJitterEnabled ? "on" : "off");
        Msg("* [OptiBridge] Action19 diagnostics: jitter scale %.3f, dispatch jitter scale %.3f, MV scale factor %.3f, MV jitter cancellation %s",
            g_bridge.jitterScale, g_bridge.dispatchJitterScale, g_bridge.motionVectorScaleFactor,
            g_bridge.mvJitterCancellationEnabled ? "on" : "off");
        Msg("* [OptiBridge] Action20 flora reactive mask %s, strength %.3f",
            g_bridge.floraReactiveMaskEnabled ? "on" : "off", g_bridge.floraReactiveStrength);
'@
$text = Replace-ExactlyOnce $text $old $new "Action20 runtime log seam"

# Release the extra resources with the rest of the temporal set.
$old = @'
    DestroyContext();
    ReleasePtr(g_bridge.prepareShader);
    ReleasePtr(g_bridge.output);
    ReleasePtr(g_bridge.motionRgUav);
    ReleasePtr(g_bridge.motionRg);
'@
$new = @'
    DestroyContext();
    ReleasePtr(g_bridge.prepareConstants);
    ReleasePtr(g_bridge.prepareShader);
    ReleasePtr(g_bridge.output);
    ReleasePtr(g_bridge.floraReactiveUav);
    ReleasePtr(g_bridge.floraReactive);
    ReleasePtr(g_bridge.motionRgUav);
    ReleasePtr(g_bridge.motionRg);
'@
$text = Replace-ExactlyOnce $text $old $new "Action20 destroy reactive seam"

$old = @'
    ReleasePtr(g_bridge.motionSourceSrv);
    ReleasePtr(g_bridge.depthSourceSrv);
    ReleasePtr(g_bridge.colorSourceSrv);
'@
$new = @'
    ReleasePtr(g_bridge.positionSourceSrv);
    ReleasePtr(g_bridge.motionSourceSrv);
    ReleasePtr(g_bridge.depthSourceSrv);
    ReleasePtr(g_bridge.colorSourceSrv);
'@
$text = Replace-ExactlyOnce $text $old $new "Action20 destroy position SRV seam"

# Extend the prepare compute pass. rt_Position.w carries X-Ray's packed
# material+hemi value. GAMMA defines MAT_FLORA as 0.47451 and uses a tolerance
# around that value. A one-pixel dilation also marks the immediately adjacent
# silhouette/background pixels that alternate coverage under subpixel jitter.
$old = @'
        "Texture2D<float4> SrcMotion : register(t2);\n"
        "RWTexture2D<float4> OutColor : register(u0);\n"
        "RWTexture2D<float> OutDepth : register(u1);\n"
        "RWTexture2D<float2> OutMotion : register(u2);\n"
        "[numthreads(8,8,1)]\n"
'@
$new = @'
        "Texture2D<float4> SrcMotion : register(t2);\n"
        "Texture2D<float4> SrcPosition : register(t3);\n"
        "RWTexture2D<float4> OutColor : register(u0);\n"
        "RWTexture2D<float> OutDepth : register(u1);\n"
        "RWTexture2D<float2> OutMotion : register(u2);\n"
        "RWTexture2D<float> OutReactive : register(u3);\n"
        "cbuffer OptiBridgePrepareConstants : register(b0) { float FloraReactiveStrength; float3 PreparePad; };\n"
        "float UnpackMaterial(float packedValue)\n"
        "{\n"
        "  uint packed = asuint(packedValue);\n"
        "  uint material = ((packed >> 21u) & 15u) + (((packed & 0x80000000u) == 0u) ? 0u : 16u);\n"
        "  return float(material) * (1.0 / 31.0) * 1.333333333;\n"
        "}\n"
        "[numthreads(8,8,1)]\n"
'@
$text = Replace-ExactlyOnce $text $old $new "Action20 prepare declarations seam"

$old = @'
        "  OutColor[id.xy] = SrcColor.Load(int3(src,0));\n"
        "  OutDepth[id.xy] = SrcDepth.Load(int3(src,0));\n"
        "  OutMotion[id.xy] = SrcMotion.Load(int3(src,0)).xy;\n"
        "}\n";
'@
$new = @'
        "  OutColor[id.xy] = SrcColor.Load(int3(src,0));\n"
        "  OutDepth[id.xy] = SrcDepth.Load(int3(src,0));\n"
        "  OutMotion[id.xy] = SrcMotion.Load(int3(src,0)).xy;\n"
        "  float reactive = 0.0;\n"
        "  int2 center = int2(src);\n"
        "  [unroll] for (int oy = -1; oy <= 1; ++oy)\n"
        "  {\n"
        "    [unroll] for (int ox = -1; ox <= 1; ++ox)\n"
        "    {\n"
        "      int2 q = clamp(center + int2(ox,oy), int2(0,0), int2(int(sw)-1,int(sh)-1));\n"
        "      float mtl = UnpackMaterial(SrcPosition.Load(int3(q,0)).w);\n"
        "      if (abs(mtl - 0.47451) <= 0.05) reactive = FloraReactiveStrength;\n"
        "    }\n"
        "  }\n"
        "  OutReactive[id.xy] = saturate(reactive);\n"
        "}\n";
'@
$text = Replace-ExactlyOnce $text $old $new "Action20 prepare body seam"

# Small dynamic constant buffer for mask strength.
$needle = 'bool EnsureResources(CRenderTarget* target)'
$helper = @'
bool CreatePrepareConstants()
{
    if (g_bridge.prepareConstants)
        return true;

    D3D11_BUFFER_DESC desc = {};
    desc.ByteWidth = 16;
    desc.Usage = D3D11_USAGE_DYNAMIC;
    desc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
    desc.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
    return SUCCEEDED(HW.pDevice->CreateBuffer(&desc, nullptr, &g_bridge.prepareConstants));
}

'@
$count = ([regex]::Matches($text, [regex]::Escape($needle))).Count
if ($count -ne 1) { throw "Action20 constant helper insertion expected exactly once, got $count" }
$text = $text.Replace($needle, $helper + $needle)

# Require the position/material buffer only while the new mask is enabled.
$old = @'
    if (!target || !target->rt_Generic_0 || !target->rt_ssfx_motion_vectors || !depthView)
'@
$new = @'
    if (!target || !target->rt_Generic_0 || !target->rt_ssfx_motion_vectors || !depthView ||
        (g_bridge.floraReactiveMaskEnabled && !target->rt_Position))
'@
$text = Replace-ExactlyOnce $text $old $new "Action20 target requirement seam"

# Build an SRV over rt_Position so the prepare pass can classify flora.
$old = @'
    if (FAILED(HW.pDevice->CreateShaderResourceView(target->rt_ssfx_motion_vectors->pSurface, &mvSrvDesc,
        &g_bridge.motionSourceSrv)))
    {
        Msg("! [OptiBridge] could not create motion-vector SRV");
        DestroyResources();
        return false;
    }

    if (!CreateTexture2D(g_bridge.renderWidth, g_bridge.renderHeight, g_bridge.colorFormat,
'@
$new = @'
    if (FAILED(HW.pDevice->CreateShaderResourceView(target->rt_ssfx_motion_vectors->pSurface, &mvSrvDesc,
        &g_bridge.motionSourceSrv)))
    {
        Msg("! [OptiBridge] could not create motion-vector SRV");
        DestroyResources();
        return false;
    }

    if (g_bridge.floraReactiveMaskEnabled && FAILED(HW.pDevice->CreateShaderResourceView(
        target->rt_Position->pSurface, nullptr, &g_bridge.positionSourceSrv)))
    {
        Msg("! [OptiBridge] Action20 could not create rt_Position material SRV");
        DestroyResources();
        return false;
    }

    if (!CreateTexture2D(g_bridge.renderWidth, g_bridge.renderHeight, g_bridge.colorFormat,
'@
$text = Replace-ExactlyOnce $text $old $new "Action20 position SRV creation seam"

$old = @'
        !CreateTexture2D(g_bridge.renderWidth, g_bridge.renderHeight, DXGI_FORMAT_R16G16_FLOAT,
            D3D11_BIND_SHADER_RESOURCE | D3D11_BIND_UNORDERED_ACCESS, &g_bridge.motionRg) ||
        !CreateTexture2D(g_bridge.displayWidth, g_bridge.displayHeight, g_bridge.colorFormat,
'@
$new = @'
        !CreateTexture2D(g_bridge.renderWidth, g_bridge.renderHeight, DXGI_FORMAT_R16G16_FLOAT,
            D3D11_BIND_SHADER_RESOURCE | D3D11_BIND_UNORDERED_ACCESS, &g_bridge.motionRg) ||
        !CreateTexture2D(g_bridge.renderWidth, g_bridge.renderHeight, DXGI_FORMAT_R16_FLOAT,
            D3D11_BIND_SHADER_RESOURCE | D3D11_BIND_UNORDERED_ACCESS, &g_bridge.floraReactive) ||
        !CreateTexture2D(g_bridge.displayWidth, g_bridge.displayHeight, g_bridge.colorFormat,
'@
$text = Replace-ExactlyOnce $text $old $new "Action20 reactive texture seam"

$old = @'
    if (FAILED(HW.pDevice->CreateUnorderedAccessView(g_bridge.colorLow, nullptr, &g_bridge.colorLowUav)) ||
        FAILED(HW.pDevice->CreateUnorderedAccessView(g_bridge.depthFloat, nullptr, &g_bridge.depthFloatUav)) ||
        FAILED(HW.pDevice->CreateUnorderedAccessView(g_bridge.motionRg, nullptr, &g_bridge.motionRgUav)) ||
        !CompilePrepareShader() ||
'@
$new = @'
    if (FAILED(HW.pDevice->CreateUnorderedAccessView(g_bridge.colorLow, nullptr, &g_bridge.colorLowUav)) ||
        FAILED(HW.pDevice->CreateUnorderedAccessView(g_bridge.depthFloat, nullptr, &g_bridge.depthFloatUav)) ||
        FAILED(HW.pDevice->CreateUnorderedAccessView(g_bridge.motionRg, nullptr, &g_bridge.motionRgUav)) ||
        FAILED(HW.pDevice->CreateUnorderedAccessView(g_bridge.floraReactive, nullptr, &g_bridge.floraReactiveUav)) ||
        !CreatePrepareConstants() ||
        !CompilePrepareShader() ||
'@
$text = Replace-ExactlyOnce $text $old $new "Action20 reactive UAV seam"

# Native D3D compute state must also release our constant-buffer slot.
$old = @'
    HW.pContext->CSSetUnorderedAccessViews(0, 8, nullUavs, nullptr);
    HW.pContext->CSSetShader(nullptr, nullptr, 0);
'@
$new = @'
    HW.pContext->CSSetUnorderedAccessViews(0, 8, nullUavs, nullptr);
    ID3D11Buffer* nullCbs[1] = {};
    HW.pContext->CSSetConstantBuffers(0, 1, nullCbs);
    HW.pContext->CSSetShader(nullptr, nullptr, 0);
'@
$text = Replace-ExactlyOnce $text $old $new "Action20 clear constant-buffer seam"

# Bind the position/material source, reactive UAV, and strength constant.
$old = @'
    ID3D11ShaderResourceView* srvs[3] =
        { g_bridge.colorSourceSrv, g_bridge.depthSourceSrv, g_bridge.motionSourceSrv };
    ID3D11UnorderedAccessView* uavs[3] =
        { g_bridge.colorLowUav, g_bridge.depthFloatUav, g_bridge.motionRgUav };
    HW.pContext->CSSetShader(g_bridge.prepareShader, nullptr, 0);
    HW.pContext->CSSetShaderResources(0, 3, srvs);
    HW.pContext->CSSetUnorderedAccessViews(0, 3, uavs, nullptr);
'@
$new = @'
    D3D11_MAPPED_SUBRESOURCE mapped = {};
    if (FAILED(HW.pContext->Map(g_bridge.prepareConstants, 0, D3D11_MAP_WRITE_DISCARD, 0, &mapped)))
        return false;
    float* constants = reinterpret_cast<float*>(mapped.pData);
    constants[0] = g_bridge.floraReactiveMaskEnabled ? g_bridge.floraReactiveStrength : 0.f;
    constants[1] = constants[2] = constants[3] = 0.f;
    HW.pContext->Unmap(g_bridge.prepareConstants, 0);

    ID3D11ShaderResourceView* srvs[4] =
        { g_bridge.colorSourceSrv, g_bridge.depthSourceSrv, g_bridge.motionSourceSrv, g_bridge.positionSourceSrv };
    ID3D11UnorderedAccessView* uavs[4] =
        { g_bridge.colorLowUav, g_bridge.depthFloatUav, g_bridge.motionRgUav, g_bridge.floraReactiveUav };
    ID3D11Buffer* cbs[1] = { g_bridge.prepareConstants };
    HW.pContext->CSSetShader(g_bridge.prepareShader, nullptr, 0);
    HW.pContext->CSSetShaderResources(0, 4, srvs);
    HW.pContext->CSSetUnorderedAccessViews(0, 4, uavs, nullptr);
    HW.pContext->CSSetConstantBuffers(0, 1, cbs);
'@
$text = Replace-ExactlyOnce $text $old $new "Action20 prepare binding seam"

# Feed the generated mask into FSR2. OptiScaler's FSR2 input bridge forwards
# this resource to DLSS as the current-color-bias/reactive input.
$old = @'
    dispatch.motionVectors = ffxGetResourceDX11(&g_bridge.context, g_bridge.motionRg, L"OptiBridge.Motion",
        FFX_RESOURCE_STATE_COMPUTE_READ);
    dispatch.output = ffxGetResourceDX11(&g_bridge.context, g_bridge.output, L"OptiBridge.Output",
'@
$new = @'
    dispatch.motionVectors = ffxGetResourceDX11(&g_bridge.context, g_bridge.motionRg, L"OptiBridge.Motion",
        FFX_RESOURCE_STATE_COMPUTE_READ);
    if (g_bridge.floraReactiveMaskEnabled)
    {
        dispatch.reactive = ffxGetResourceDX11(&g_bridge.context, g_bridge.floraReactive, L"OptiBridge.FloraReactive",
            FFX_RESOURCE_STATE_COMPUTE_READ);
        if (!g_bridge.loggedFloraReactive)
        {
            Msg("* [OptiBridge] Action20 flora reactive mask ACTIVE: MAT_FLORA 0.47451, strength %.3f, 1px dilation",
                g_bridge.floraReactiveStrength);
            g_bridge.loggedFloraReactive = true;
        }
    }
    dispatch.output = ffxGetResourceDX11(&g_bridge.context, g_bridge.output, L"OptiBridge.Output",
'@
$text = Replace-ExactlyOnce $text $old $new "Action20 dispatch reactive seam"

Set-Content $runtime $text -NoNewline
Write-Host "OptiBridge Action20 flora reactive-mask patch applied successfully."
