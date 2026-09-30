#include "stdafx.h"
#include "OptiBridgeRuntime.h"
#include "r4_rendertarget.h"
#include "../xrRender/HW.h"
#include "../xrRender/R_Backend.h"
#include "../xrRenderDX10/StateManager/dx10ShaderResourceStateCache.h"

#include "ffx_fsr2.h"
#include "dx11/ffx_fsr2_dx11.h"

#include <d3dcompiler.h>
#include <vector>
#include <cmath>

#pragma comment(lib, "d3dcompiler.lib")

namespace
{
struct OptiBridgeState
{
    bool configLoaded = false;
    bool enabled = false;
    bool contextValid = false;
    bool resourcesValid = false;
    bool firstDispatch = true;
    bool loggedDispatchEntry = false;
    bool loggedSvpSkip = false;
    bool loggedMissingTarget = false;
    bool loggedMissingDepth = false;
    float renderScale = 1.0f;
    u32 displayWidth = 0;
    u32 displayHeight = 0;
    u32 renderWidth = 0;
    u32 renderHeight = 0;
    u32 lastFrame = u32(-1);
    Fvector lastPosition = { 0.f, 0.f, 0.f };
    Fvector lastDirection = { 0.f, 0.f, 1.f };

    FfxFsr2Context context = {};
    std::vector<unsigned char> scratch;

    ID3D11Resource* sourceDepth = nullptr;
    ID3D11ShaderResourceView* colorSourceSrv = nullptr;
    ID3D11ShaderResourceView* depthSourceSrv = nullptr;
    ID3D11ShaderResourceView* motionSourceSrv = nullptr;

    ID3D11Texture2D* colorLow = nullptr;
    ID3D11UnorderedAccessView* colorLowUav = nullptr;
    ID3D11Texture2D* depthFloat = nullptr;
    ID3D11UnorderedAccessView* depthFloatUav = nullptr;
    ID3D11Texture2D* motionRg = nullptr;
    ID3D11UnorderedAccessView* motionRgUav = nullptr;
    ID3D11Texture2D* output = nullptr;

    ID3D11ComputeShader* prepareShader = nullptr;
    DXGI_FORMAT colorFormat = DXGI_FORMAT_UNKNOWN;
};

OptiBridgeState g_bridge;

void SafeRelease(IUnknown*& p)
{
    if (p)
    {
        p->Release();
        p = nullptr;
    }
}

template <typename T>
void ReleasePtr(T*& p)
{
    if (p)
    {
        p->Release();
        p = nullptr;
    }
}

void BuildIniPath(char (&path)[MAX_PATH])
{
    path[0] = 0;
    GetModuleFileNameA(nullptr, path, MAX_PATH);
    char* slashA = strrchr(path, '\\');
    char* slashB = strrchr(path, '/');
    char* slash = slashA > slashB ? slashA : slashB;
    if (slash)
        *(slash + 1) = 0;
    strcat_s(path, "optibridge.ini");
}

bool ReadEnabled()
{
    if (!g_bridge.configLoaded)
    {
        char path[MAX_PATH];
        BuildIniPath(path);
        g_bridge.enabled = GetPrivateProfileIntA("OptiBridge", "Enabled", 0, path) != 0;

        char scaleText[32] = {};
        GetPrivateProfileStringA("OptiBridge", "RenderScale", "1.0", scaleText, sizeof(scaleText), path);
        g_bridge.renderScale = (float)atof(scaleText);
        g_bridge.renderScale = _max(0.5f, _min(1.0f, g_bridge.renderScale));

        g_bridge.configLoaded = true;
        Msg("* [OptiBridge] %s (%s), render scale %.4f", g_bridge.enabled ? "enabled" : "disabled", path,
            g_bridge.renderScale);
    }
    return g_bridge.enabled;
}

void DestroyContext()
{
    if (g_bridge.contextValid)
    {
        ffxFsr2ContextDestroy(&g_bridge.context);
        g_bridge.contextValid = false;
    }
}

void DestroyResources()
{
    DestroyContext();
    ReleasePtr(g_bridge.prepareShader);
    ReleasePtr(g_bridge.output);
    ReleasePtr(g_bridge.motionRgUav);
    ReleasePtr(g_bridge.motionRg);
    ReleasePtr(g_bridge.depthFloatUav);
    ReleasePtr(g_bridge.depthFloat);
    ReleasePtr(g_bridge.colorLowUav);
    ReleasePtr(g_bridge.colorLow);
    ReleasePtr(g_bridge.motionSourceSrv);
    ReleasePtr(g_bridge.depthSourceSrv);
    ReleasePtr(g_bridge.colorSourceSrv);
    ReleasePtr(g_bridge.sourceDepth);
    g_bridge.resourcesValid = false;
    g_bridge.displayWidth = 0;
    g_bridge.displayHeight = 0;
    g_bridge.renderWidth = 0;
    g_bridge.renderHeight = 0;
    g_bridge.colorFormat = DXGI_FORMAT_UNKNOWN;
    g_bridge.firstDispatch = true;
    g_bridge.loggedMissingTarget = false;
    g_bridge.loggedMissingDepth = false;
}

bool CompilePrepareShader()
{
    static const char* source =
        "Texture2D<float4> SrcColor : register(t0);\n"
        "Texture2D<float> SrcDepth : register(t1);\n"
        "Texture2D<float4> SrcMotion : register(t2);\n"
        "RWTexture2D<float4> OutColor : register(u0);\n"
        "RWTexture2D<float> OutDepth : register(u1);\n"
        "RWTexture2D<float2> OutMotion : register(u2);\n"
        "[numthreads(8,8,1)]\n"
        "void main(uint3 id : SV_DispatchThreadID)\n"
        "{\n"
        "  uint w,h; OutColor.GetDimensions(w,h);\n"
        "  if (id.x >= w || id.y >= h) return;\n"
        "  uint sw,sh; SrcColor.GetDimensions(sw,sh);\n"
        "  uint2 src = min(uint2((float2(id.xy) + 0.5) * float2(sw,sh) / float2(w,h)), uint2(sw-1,sh-1));\n"
        "  OutColor[id.xy] = SrcColor.Load(int3(src,0));\n"
        "  OutDepth[id.xy] = SrcDepth.Load(int3(src,0));\n"
        "  OutMotion[id.xy] = SrcMotion.Load(int3(src,0)).xy;\n"
        "}\n";

    ID3DBlob* code = nullptr;
    ID3DBlob* errors = nullptr;
    const HRESULT hr = D3DCompile(source, strlen(source), "OptiBridgePrepare", nullptr, nullptr,
        "main", "cs_5_0", D3DCOMPILE_OPTIMIZATION_LEVEL3, 0, &code, &errors);
    if (FAILED(hr))
    {
        if (errors)
            Msg("! [OptiBridge] prepare shader compile failed: %s", (const char*)errors->GetBufferPointer());
        ReleasePtr(errors);
        ReleasePtr(code);
        return false;
    }

    const HRESULT createHr = HW.pDevice->CreateComputeShader(code->GetBufferPointer(), code->GetBufferSize(), nullptr,
        &g_bridge.prepareShader);
    ReleasePtr(errors);
    ReleasePtr(code);
    if (FAILED(createHr))
    {
        Msg("! [OptiBridge] CreateComputeShader failed: 0x%08X", createHr);
        return false;
    }
    return true;
}

bool CreateTexture2D(u32 width, u32 height, DXGI_FORMAT format, UINT bindFlags, ID3D11Texture2D** outTex)
{
    D3D11_TEXTURE2D_DESC desc = {};
    desc.Width = width;
    desc.Height = height;
    desc.MipLevels = 1;
    desc.ArraySize = 1;
    desc.Format = format;
    desc.SampleDesc.Count = 1;
    desc.Usage = D3D11_USAGE_DEFAULT;
    desc.BindFlags = bindFlags;
    return SUCCEEDED(HW.pDevice->CreateTexture2D(&desc, nullptr, outTex));
}

bool CreateContext(u32 renderWidth, u32 renderHeight, u32 displayWidth, u32 displayHeight)
{
    const size_t scratchSize = ffxFsr2GetScratchMemorySizeDX11();
    g_bridge.scratch.resize(scratchSize);

    FfxFsr2ContextDescription desc = {};
    desc.flags = FFX_FSR2_ENABLE_AUTO_EXPOSURE | FFX_FSR2_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION;
    desc.maxRenderSize = { renderWidth, renderHeight };
    desc.displaySize = { displayWidth, displayHeight };
    desc.device = ffxGetDeviceDX11(HW.pDevice);

    FfxErrorCode ec = ffxFsr2GetInterfaceDX11(&desc.callbacks, HW.pDevice, g_bridge.scratch.data(), g_bridge.scratch.size());
    if (ec != FFX_OK)
    {
        Msg("! [OptiBridge] ffxFsr2GetInterfaceDX11 failed: %d", (int)ec);
        return false;
    }

    ec = ffxFsr2ContextCreate(&g_bridge.context, &desc);
    if (ec != FFX_OK)
    {
        Msg("! [OptiBridge] ffxFsr2ContextCreate failed: %d", (int)ec);
        return false;
    }

    g_bridge.contextValid = true;
    g_bridge.firstDispatch = true;
    Msg("* [OptiBridge] FSR2 input context created: %ux%u -> %ux%u", renderWidth, renderHeight, displayWidth,
        displayHeight);
    return true;
}

bool EnsureResources(CRenderTarget* target)
{
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
    if (!depthResource)
    {
        if (!g_bridge.loggedMissingDepth)
        {
            Msg("! [OptiBridge] base depth view returned no backing resource");
            g_bridge.loggedMissingDepth = true;
        }
        return false;
    }

    D3D11_TEXTURE2D_DESC colorDesc = {};
    target->rt_Generic_0->pSurface->GetDesc(&colorDesc);

    const u32 displayWidth = colorDesc.Width;
    const u32 displayHeight = colorDesc.Height;
    const u32 renderWidth = _max(1u, (u32)floorf(float(displayWidth) * g_bridge.renderScale + 0.5f));
    const u32 renderHeight = _max(1u, (u32)floorf(float(displayHeight) * g_bridge.renderScale + 0.5f));

    const bool same = g_bridge.resourcesValid && g_bridge.sourceDepth == depthResource &&
        g_bridge.displayWidth == displayWidth && g_bridge.displayHeight == displayHeight &&
        g_bridge.renderWidth == renderWidth && g_bridge.renderHeight == renderHeight &&
        g_bridge.colorFormat == colorDesc.Format;
    if (same)
    {
        depthResource->Release();
        return true;
    }

    DestroyResources();
    g_bridge.sourceDepth = depthResource;
    g_bridge.displayWidth = displayWidth;
    g_bridge.displayHeight = displayHeight;
    g_bridge.renderWidth = renderWidth;
    g_bridge.renderHeight = renderHeight;
    g_bridge.colorFormat = colorDesc.Format;

    if (FAILED(HW.pDevice->CreateShaderResourceView(target->rt_Generic_0->pSurface, nullptr,
        &g_bridge.colorSourceSrv)))
    {
        Msg("! [OptiBridge] could not create scene-color SRV");
        DestroyResources();
        return false;
    }

    D3D11_SHADER_RESOURCE_VIEW_DESC depthSrvDesc = {};
    depthSrvDesc.Format = DXGI_FORMAT_R24_UNORM_X8_TYPELESS;
    depthSrvDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
    depthSrvDesc.Texture2D.MostDetailedMip = 0;
    depthSrvDesc.Texture2D.MipLevels = 1;
    if (FAILED(HW.pDevice->CreateShaderResourceView(g_bridge.sourceDepth, &depthSrvDesc, &g_bridge.depthSourceSrv)))
    {
        Msg("! [OptiBridge] could not create readable base-depth SRV");
        DestroyResources();
        return false;
    }

    D3D11_SHADER_RESOURCE_VIEW_DESC mvSrvDesc = {};
    mvSrvDesc.Format = DXGI_FORMAT_R16G16B16A16_FLOAT;
    mvSrvDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
    mvSrvDesc.Texture2D.MipLevels = 1;
    if (FAILED(HW.pDevice->CreateShaderResourceView(target->rt_ssfx_motion_vectors->pSurface, &mvSrvDesc,
        &g_bridge.motionSourceSrv)))
    {
        Msg("! [OptiBridge] could not create motion-vector SRV");
        DestroyResources();
        return false;
    }

    if (!CreateTexture2D(g_bridge.renderWidth, g_bridge.renderHeight, g_bridge.colorFormat,
            D3D11_BIND_SHADER_RESOURCE | D3D11_BIND_UNORDERED_ACCESS, &g_bridge.colorLow) ||
        !CreateTexture2D(g_bridge.renderWidth, g_bridge.renderHeight, DXGI_FORMAT_R32_FLOAT,
            D3D11_BIND_SHADER_RESOURCE | D3D11_BIND_UNORDERED_ACCESS, &g_bridge.depthFloat) ||
        !CreateTexture2D(g_bridge.renderWidth, g_bridge.renderHeight, DXGI_FORMAT_R16G16_FLOAT,
            D3D11_BIND_SHADER_RESOURCE | D3D11_BIND_UNORDERED_ACCESS, &g_bridge.motionRg) ||
        !CreateTexture2D(g_bridge.displayWidth, g_bridge.displayHeight, g_bridge.colorFormat,
            D3D11_BIND_SHADER_RESOURCE | D3D11_BIND_UNORDERED_ACCESS, &g_bridge.output))
    {
        Msg("! [OptiBridge] failed to allocate temporal resources");
        DestroyResources();
        return false;
    }

    if (FAILED(HW.pDevice->CreateUnorderedAccessView(g_bridge.colorLow, nullptr, &g_bridge.colorLowUav)) ||
        FAILED(HW.pDevice->CreateUnorderedAccessView(g_bridge.depthFloat, nullptr, &g_bridge.depthFloatUav)) ||
        FAILED(HW.pDevice->CreateUnorderedAccessView(g_bridge.motionRg, nullptr, &g_bridge.motionRgUav)) ||
        !CompilePrepareShader() ||
        !CreateContext(g_bridge.renderWidth, g_bridge.renderHeight, g_bridge.displayWidth, g_bridge.displayHeight))
    {
        DestroyResources();
        return false;
    }

    g_bridge.resourcesValid = true;
    return true;
}

void ClearExternalComputeBindings()
{
    ID3D11ShaderResourceView* nullSrvs[16] = {};
    ID3D11UnorderedAccessView* nullUavs[8] = {};
    HW.pContext->CSSetShaderResources(0, 16, nullSrvs);
    HW.pContext->CSSetUnorderedAccessViews(0, 8, nullUavs, nullptr);
    HW.pContext->CSSetShader(nullptr, nullptr, 0);
}

bool PrepareInputs()
{
    // Synchronize X-Ray's cache with the empty CS state before using the native API directly.
    for (u32 i = 0; i < CBackend::mtMaxComputeShaderTextures; ++i)
        SRVSManager.SetCSResource(i, nullptr);
    SRVSManager.Apply();
    RCache.set_CS(nullptr);

    HW.pContext->OMSetRenderTargets(0, nullptr, nullptr);

    ID3D11ShaderResourceView* srvs[3] =
        { g_bridge.colorSourceSrv, g_bridge.depthSourceSrv, g_bridge.motionSourceSrv };
    ID3D11UnorderedAccessView* uavs[3] =
        { g_bridge.colorLowUav, g_bridge.depthFloatUav, g_bridge.motionRgUav };
    HW.pContext->CSSetShader(g_bridge.prepareShader, nullptr, 0);
    HW.pContext->CSSetShaderResources(0, 3, srvs);
    HW.pContext->CSSetUnorderedAccessViews(0, 3, uavs, nullptr);
    HW.pContext->Dispatch((g_bridge.renderWidth + 7) / 8, (g_bridge.renderHeight + 7) / 8, 1);
    ClearExternalComputeBindings();
    return true;
}

void GetConfiguredRenderSize(u32& width, u32& height)
{
    width = _max(1u, (u32)floorf(float(Device.dwWidth) * g_bridge.renderScale + 0.5f));
    height = _max(1u, (u32)floorf(float(Device.dwHeight) * g_bridge.renderScale + 0.5f));
}

void CurrentJitter(float& px, float& py)
{
    px = py = 0.f;
    if (Device.dwWidth == 0)
        return;

    u32 renderWidth = 0, renderHeight = 0;
    GetConfiguredRenderSize(renderWidth, renderHeight);
    const int phaseCount = _max(1, ffxFsr2GetJitterPhaseCount((int)renderWidth, (int)Device.dwWidth));
    ffxFsr2GetJitterOffset(&px, &py, (int)(Device.dwFrame % (u32)phaseCount), phaseCount);
}

bool NeedResetHistory()
{
    if (g_bridge.firstDispatch || g_bridge.lastFrame == u32(-1) || Device.dwFrame != g_bridge.lastFrame + 1)
        return true;

    Fvector delta;
    delta.sub(Device.vCameraPosition, g_bridge.lastPosition);
    if (delta.square_magnitude() > 144.f)
        return true;

    Fvector now = Device.vCameraDirection;
    now.normalize_safe();
    Fvector prev = g_bridge.lastDirection;
    prev.normalize_safe();
    return now.dotproduct(prev) < 0.60f;
}

void RememberCamera()
{
    g_bridge.lastFrame = Device.dwFrame;
    g_bridge.lastPosition = Device.vCameraPosition;
    g_bridge.lastDirection = Device.vCameraDirection;
    g_bridge.firstDispatch = false;
}
} // namespace

bool OptiBridge_Enabled()
{
    return ReadEnabled();
}

bool OptiBridge_GetJitterNdc(float& x, float& y)
{
    x = y = 0.f;
    if (!ReadEnabled() || Device.dwWidth == 0 || Device.dwHeight == 0)
        return false;

    float px = 0.f, py = 0.f;
    CurrentJitter(px, py);
    u32 renderWidth = 0, renderHeight = 0;
    GetConfiguredRenderSize(renderWidth, renderHeight);
    x = 2.f * px / float(renderWidth);
    y = -2.f * py / float(renderHeight);
    return true;
}

bool OptiBridge_Dispatch(CRenderTarget* target)
{
    if (!ReadEnabled())
        return false;

    if (!g_bridge.loggedDispatchEntry)
    {
        Msg("* [OptiBridge] temporal dispatch hook reached");
        g_bridge.loggedDispatchEntry = true;
    }

    if (!target)
    {
        if (!g_bridge.loggedMissingTarget)
        {
            Msg("! [OptiBridge] temporal dispatch received null render target");
            g_bridge.loggedMissingTarget = true;
        }
        return false;
    }

    if (Device.m_SecondViewport.IsSVPFrame())
    {
        if (!g_bridge.loggedSvpSkip)
        {
            Msg("* [OptiBridge] skipping SecondViewport frame");
            g_bridge.loggedSvpSkip = true;
        }
        return false;
    }

    if (RImplementation.o.dx10_msaa)
    {
        static bool warnedMsaa = false;
        if (!warnedMsaa)
        {
            Msg("! [OptiBridge] MSAA is not supported by the alpha runtime; falling back to stock TAA");
            warnedMsaa = true;
        }
        return false;
    }

    if (!RImplementation.o.ssfx_motionvectors)
    {
        static bool warnedMv = false;
        if (!warnedMv)
        {
            Msg("! [OptiBridge] SSFX motion vectors are disabled; falling back to stock TAA");
            warnedMv = true;
        }
        return false;
    }

    if (!EnsureResources(target) || !g_bridge.contextValid || !PrepareInputs())
        return false;

    FfxFsr2DispatchDescription dispatch = {};
    dispatch.commandList = reinterpret_cast<FfxCommandList>(HW.pContext);
    dispatch.color = ffxGetResourceDX11(&g_bridge.context, g_bridge.colorLow, L"OptiBridge.Color",
        FFX_RESOURCE_STATE_COMPUTE_READ);
    dispatch.depth = ffxGetResourceDX11(&g_bridge.context, g_bridge.depthFloat, L"OptiBridge.Depth",
        FFX_RESOURCE_STATE_COMPUTE_READ);
    dispatch.motionVectors = ffxGetResourceDX11(&g_bridge.context, g_bridge.motionRg, L"OptiBridge.Motion",
        FFX_RESOURCE_STATE_COMPUTE_READ);
    dispatch.output = ffxGetResourceDX11(&g_bridge.context, g_bridge.output, L"OptiBridge.Output",
        FFX_RESOURCE_STATE_UNORDERED_ACCESS);

    float jitterX = 0.f, jitterY = 0.f;
    CurrentJitter(jitterX, jitterY);
    dispatch.jitterOffset = { jitterX, jitterY };

    // SSFX stores texture-space current-minus-previous motion. FSR2 wants current-to-previous.
    dispatch.motionVectorScale = { -float(g_bridge.renderWidth), -float(g_bridge.renderHeight) };
    dispatch.renderSize = { g_bridge.renderWidth, g_bridge.renderHeight };
    dispatch.enableSharpening = false;
    dispatch.sharpness = 0.f;
    dispatch.frameTimeDelta = _max(Device.fTimeDelta * 1000.f, 0.01f);
    dispatch.preExposure = 1.f;
    dispatch.reset = NeedResetHistory();

    const Fmatrix& p = Device.mProject;
    const float q = p._33;
    dispatch.cameraNear = _abs(q) > EPS_S ? p._43 / -q : VIEWPORT_NEAR;
    dispatch.cameraFar = _abs(q - 1.f) > EPS_S ? (dispatch.cameraNear * q) / (q - 1.f) : 1000.f;
    dispatch.cameraFovAngleVertical = 2.f * atanf(1.f / p._22);
    dispatch.viewSpaceToMetersFactor = 1.f;

    // Keep the D3D11 state-cache view of CS slots empty while OptiScaler/FSR2 uses native D3D calls.
    RCache.set_CS(nullptr);
    const FfxErrorCode result = ffxFsr2ContextDispatch(&g_bridge.context, &dispatch);
    ClearExternalComputeBindings();

    if (result != FFX_OK)
    {
        Msg("! [OptiBridge] temporal dispatch failed: %d", (int)result);
        g_bridge.firstDispatch = true;
        return false;
    }

    HW.pContext->CopyResource(target->rt_Generic_0->pSurface, g_bridge.output);
    RememberCamera();
    return true;
}