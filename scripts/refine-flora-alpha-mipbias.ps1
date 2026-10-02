param(
    [Parameter(Mandatory=$true)][string]$XrayRoot
)

$ErrorActionPreference = "Stop"
$XrayRoot = (Resolve-Path $XrayRoot).Path
$r4 = Join-Path $XrayRoot "src\Layers\xrRenderPC_R4\r4.cpp"
$text = Get-Content $r4 -Raw

function Replace-ExactlyOnce([string]$source, [string]$from, [string]$to, [string]$label)
{
    $needle = $from.Trim()
    $count = ([regex]::Matches($source, [regex]::Escape($needle))).Count
    if ($count -ne 1) { throw "$label expected exactly once, got $count" }
    return $source.Replace($needle, $to.Trim())
}

# Action24 builds on Action23 but keeps hashed coverage disabled for the release
# path. The new control applies a positive mip bias only to the alpha sample used
# by dedicated tree-branch cutout shaders. RGB/detail/bump sampling remains on
# the game's normal sampler state, so the diagnostic benefit of r__tf_mipbias
# can be isolated to foliage coverage without globally softening textures.
$old = @'
    bool logged = false;
    bool hashedCoverage = false;
    float widthScale = 0.25f;
    float hashedCoverageScale = 0.05f;
'@
$new = @'
    bool logged = false;
    bool hashedCoverage = false;
    float widthScale = 0.25f;
    float hashedCoverageScale = 0.05f;
    float alphaMipBias = 0.0f;
'@
$text = Replace-ExactlyOnce $text $old $new "Action24 state fields"

$old = @'
    g_optibridgeFloraAlpha.hashedCoverageScale =
        _max(0.0f, _min(0.5f, g_optibridgeFloraAlpha.hashedCoverageScale));

    g_optibridgeFloraAlpha.loaded = true;

    Msg("* [OptiBridge] Action23 flora alpha bias %s %.3f, hashed coverage %s %.3f",
        g_optibridgeFloraAlpha.enabled ? "on" : "off",
        g_optibridgeFloraAlpha.widthScale,
        g_optibridgeFloraAlpha.hashedCoverage ? "on" : "off",
        g_optibridgeFloraAlpha.hashedCoverageScale);
'@
$new = @'
    g_optibridgeFloraAlpha.hashedCoverageScale =
        _max(0.0f, _min(0.5f, g_optibridgeFloraAlpha.hashedCoverageScale));

    char alphaMipBiasText[32] = {};
    GetPrivateProfileStringA("OptiBridge", "FloraAlphaMipBias", "0.0",
        alphaMipBiasText, sizeof(alphaMipBiasText), path);
    g_optibridgeFloraAlpha.alphaMipBias = (float)atof(alphaMipBiasText);
    g_optibridgeFloraAlpha.alphaMipBias =
        _max(0.0f, _min(2.0f, g_optibridgeFloraAlpha.alphaMipBias));

    g_optibridgeFloraAlpha.loaded = true;

    Msg("* [OptiBridge] Action24 flora alpha bias %s %.3f, alpha mip bias %.3f, hashed coverage %s %.3f",
        g_optibridgeFloraAlpha.enabled ? "on" : "off",
        g_optibridgeFloraAlpha.widthScale,
        g_optibridgeFloraAlpha.alphaMipBias,
        g_optibridgeFloraAlpha.hashedCoverage ? "on" : "off",
        g_optibridgeFloraAlpha.hashedCoverageScale);
'@
$text = Replace-ExactlyOnce $text $old $new "Action24 config load"

$old = @'
    if ((!g_optibridgeFloraAlpha.enabled && !g_optibridgeFloraAlpha.hashedCoverage) ||
        !name || !target || target[0] != 'p')
        return false;
'@
$new = @'
    if ((!g_optibridgeFloraAlpha.enabled && !g_optibridgeFloraAlpha.hashedCoverage &&
         g_optibridgeFloraAlpha.alphaMipBias <= 0.0f) ||
        !name || !target || target[0] != 'p')
        return false;
'@
$text = Replace-ExactlyOnce $text $old $new "Action24 shader enable gate"

$old = @'
    else
    {
        xr_sprintf(prefix,
            "// OptiBridge Action22 tree alpha stabilization\n"
            "#define OPTIBRIDGE_FLORA_ALPHA_WIDTH_SCALE %.8ff\n"
            "#define clip(x) clip((x) + OPTIBRIDGE_FLORA_ALPHA_WIDTH_SCALE * fwidth(x))\n",
            g_optibridgeFloraAlpha.widthScale);
    }
'@
$new = @'
    else if (g_optibridgeFloraAlpha.alphaMipBias > 0.0f)
    {
        const float alphaBias = g_optibridgeFloraAlpha.enabled ? g_optibridgeFloraAlpha.widthScale : 0.0f;
        xr_sprintf(prefix,
            "// OptiBridge Action24 alpha-only foliage mip bias\n"
            "#define OPTIBRIDGE_FLORA_ALPHA_WIDTH_SCALE %.8ff\n"
            "#define OPTIBRIDGE_FLORA_ALPHA_MIP_BIAS %.8ff\n"
            "#define OPTIBRIDGE_FLORA_ALPHA_EXPR (s_base.SampleBias(smp_base, I.tcdh.xy, OPTIBRIDGE_FLORA_ALPHA_MIP_BIAS).a - def_aref)\n"
            "#define clip(x) clip(OPTIBRIDGE_FLORA_ALPHA_EXPR + OPTIBRIDGE_FLORA_ALPHA_WIDTH_SCALE * fwidth(OPTIBRIDGE_FLORA_ALPHA_EXPR))\n",
            alphaBias,
            g_optibridgeFloraAlpha.alphaMipBias);
    }
    else
    {
        xr_sprintf(prefix,
            "// OptiBridge Action22 tree alpha stabilization\n"
            "#define OPTIBRIDGE_FLORA_ALPHA_WIDTH_SCALE %.8ff\n"
            "#define clip(x) clip((x) + OPTIBRIDGE_FLORA_ALPHA_WIDTH_SCALE * fwidth(x))\n",
            g_optibridgeFloraAlpha.widthScale);
    }
'@
$text = Replace-ExactlyOnce $text $old $new "Action24 HLSL prefix"

$old = @'
        Msg("* [OptiBridge] Action23 patching tree alpha shader source: %s", name);
'@
$new = @'
        Msg("* [OptiBridge] Action24 patching tree alpha shader source: %s", name);
'@
$text = Replace-ExactlyOnce $text $old $new "Action24 source log"

Set-Content $r4 $text -NoNewline
Write-Host "OptiBridge Action24 alpha-only foliage mip-bias patch applied successfully."
