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

# Action23 builds on Action22. It keeps the validated derivative alpha bias
# available, but can add a zero-mean UV-anchored hashed term inside the same
# derivative-width edge band. The hash is quantized in UV space so the pattern
# follows the foliage texture rather than sticking to screen pixels.
$old = @'
    bool logged = false;
    float widthScale = 0.25f;
'@
$new = @'
    bool logged = false;
    bool hashedCoverage = false;
    float widthScale = 0.25f;
    float hashedCoverageScale = 0.05f;
'@
$text = Replace-ExactlyOnce $text $old $new "Action23 state fields"

$old = @'
    g_optibridgeFloraAlpha.widthScale =
        _max(0.0f, _min(1.0f, g_optibridgeFloraAlpha.widthScale));
    g_optibridgeFloraAlpha.loaded = true;

    Msg("* [OptiBridge] Action22 flora alpha stabilization %s, derivative width scale %.3f",
        g_optibridgeFloraAlpha.enabled ? "on" : "off",
        g_optibridgeFloraAlpha.widthScale);
'@
$new = @'
    g_optibridgeFloraAlpha.widthScale =
        _max(0.0f, _min(1.0f, g_optibridgeFloraAlpha.widthScale));

    g_optibridgeFloraAlpha.hashedCoverage =
        GetPrivateProfileIntA("OptiBridge", "FloraHashedCoverage", 0, path) != 0;

    char hashedScaleText[32] = {};
    GetPrivateProfileStringA("OptiBridge", "FloraHashedCoverageScale", "0.05",
        hashedScaleText, sizeof(hashedScaleText), path);
    g_optibridgeFloraAlpha.hashedCoverageScale = (float)atof(hashedScaleText);
    g_optibridgeFloraAlpha.hashedCoverageScale =
        _max(0.0f, _min(0.5f, g_optibridgeFloraAlpha.hashedCoverageScale));

    g_optibridgeFloraAlpha.loaded = true;

    Msg("* [OptiBridge] Action23 flora alpha bias %s %.3f, hashed coverage %s %.3f",
        g_optibridgeFloraAlpha.enabled ? "on" : "off",
        g_optibridgeFloraAlpha.widthScale,
        g_optibridgeFloraAlpha.hashedCoverage ? "on" : "off",
        g_optibridgeFloraAlpha.hashedCoverageScale);
'@
$text = Replace-ExactlyOnce $text $old $new "Action23 config load"

$old = @'
    if (!g_optibridgeFloraAlpha.enabled || !name || !target || target[0] != 'p')
        return false;
'@
$new = @'
    if ((!g_optibridgeFloraAlpha.enabled && !g_optibridgeFloraAlpha.hashedCoverage) ||
        !name || !target || target[0] != 'p')
        return false;
'@
$text = Replace-ExactlyOnce $text $old $new "Action23 shader enable gate"

$old = @'
    char prefix[512] = {};
    xr_sprintf(prefix,
        "// OptiBridge Action22 tree alpha stabilization\n"
        "#define OPTIBRIDGE_FLORA_ALPHA_WIDTH_SCALE %.8ff\n"
        "#define clip(x) clip((x) + OPTIBRIDGE_FLORA_ALPHA_WIDTH_SCALE * fwidth(x))\n",
        g_optibridgeFloraAlpha.widthScale);

    storage.assign(prefix);
'@
$new = @'
    char prefix[2048] = {};
    if (g_optibridgeFloraAlpha.hashedCoverage)
    {
        const float alphaBias = g_optibridgeFloraAlpha.enabled ? g_optibridgeFloraAlpha.widthScale : 0.0f;
        xr_sprintf(prefix,
            "// OptiBridge Action23 UV-anchored hashed flora coverage\n"
            "#define OPTIBRIDGE_FLORA_ALPHA_WIDTH_SCALE %.8ff\n"
            "#define OPTIBRIDGE_FLORA_HASHED_SCALE %.8ff\n"
            "float OptiBridgeFloraHash(float2 uv)\n"
            "{\n"
            "    float2 p = floor(uv * 128.0f);\n"
            "    return frac(52.9829189f * frac(dot(p, float2(0.06711056f, 0.00583715f))));\n"
            "}\n"
            "#define clip(x) clip((x) + OPTIBRIDGE_FLORA_ALPHA_WIDTH_SCALE * fwidth(x) + ((OptiBridgeFloraHash(I.tcdh.xy) * 2.0f) - 1.0f) * OPTIBRIDGE_FLORA_HASHED_SCALE * fwidth(x))\n",
            alphaBias,
            g_optibridgeFloraAlpha.hashedCoverageScale);
    }
    else
    {
        xr_sprintf(prefix,
            "// OptiBridge Action22 tree alpha stabilization\n"
            "#define OPTIBRIDGE_FLORA_ALPHA_WIDTH_SCALE %.8ff\n"
            "#define clip(x) clip((x) + OPTIBRIDGE_FLORA_ALPHA_WIDTH_SCALE * fwidth(x))\n",
            g_optibridgeFloraAlpha.widthScale);
    }

    storage.assign(prefix);
'@
$text = Replace-ExactlyOnce $text $old $new "Action23 HLSL prefix"

$old = @'
        Msg("* [OptiBridge] Action22 patching tree alpha shader source: %s", name);
'@
$new = @'
        Msg("* [OptiBridge] Action23 patching tree alpha shader source: %s", name);
'@
$text = Replace-ExactlyOnce $text $old $new "Action23 source log"

Set-Content $r4 $text -NoNewline
Write-Host "OptiBridge Action23 hashed flora-coverage patch applied successfully."
