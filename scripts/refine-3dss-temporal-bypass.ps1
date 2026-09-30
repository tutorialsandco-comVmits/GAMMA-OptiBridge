param(
    [Parameter(Mandatory=$true)][string]$XrayRoot
)

$ErrorActionPreference = "Stop"
$runtime = Join-Path (Resolve-Path $XrayRoot).Path "src\Layers\xrRenderPC_R4\OptiBridgeRuntime.cpp"
$text = Get-Content $runtime -Raw

$includeOld = '#include "../xrRender/R_Backend.h"'
$includeNew = @'
#include "../xrRender/R_Backend.h"
#include "../xrRender/xrRender_console.h"
'@
if (-not $text.Contains($includeOld)) { throw "OptiBridge runtime include insertion point not found" }
$text = $text.Replace($includeOld, $includeNew.Trim())

$stateOld = '    bool loggedSvpSkip = false;'
$stateNew = @'
    bool loggedSvpSkip = false;
    bool logged3DssBypass = false;
'@
if (-not $text.Contains($stateOld)) { throw "OptiBridge diagnostic state insertion point not found" }
$text = $text.Replace($stateOld, $stateNew.TrimEnd())

$svpOld = @'
    if (Device.m_SecondViewport.IsSVPFrame())
    {
        if (!g_bridge.loggedSvpSkip)
        {
            Msg("* [OptiBridge] skipping SecondViewport frame");
            g_bridge.loggedSvpSkip = true;
        }
        return false;
    }
'@
$svpNew = @'
    // Action #14 diagnostic: 3D Shader-Based Scopes are composited before the
    // temporal seam. Bypass OptiBridge only while that scope path is active so
    // stock SSFX TAA can render the optic. This cleanly separates an FSR2
    // reconstruction/composition issue from the shader-compatibility fixes.
    if (scope_3D_fake_enabled)
    {
        if (!g_bridge.logged3DssBypass)
        {
            Msg("* [OptiBridge] Action14: bypassing FSR2 for active 3DSS scope; using stock SSFX TAA");
            g_bridge.logged3DssBypass = true;
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
'@
if (-not $text.Contains($svpOld.Trim())) { throw "OptiBridge SecondViewport dispatch block not found" }
$text = $text.Replace($svpOld.Trim(), $svpNew.Trim())

Set-Content $runtime $text -NoNewline
Write-Host "OptiBridge Action #14 3DSS temporal-bypass diagnostic applied successfully."
