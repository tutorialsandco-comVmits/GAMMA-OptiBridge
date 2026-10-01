param(
    [Parameter(Mandatory=$true)][string]$XrayRoot
)

$ErrorActionPreference = "Stop"
$XrayRoot = (Resolve-Path $XrayRoot).Path
$runtime = Join-Path $XrayRoot "src\Layers\xrRenderPC_R4\OptiBridgeRuntime.cpp"
$text = Get-Content $runtime -Raw

function Replace-ExactlyOnce([string]$source, [string]$from, [string]$to, [string]$label)
{
    $needle = $from.Trim()
    $count = ([regex]::Matches($source, [regex]::Escape($needle))).Count
    if ($count -ne 1) { throw "$label expected exactly once, got $count" }
    return $source.Replace($needle, $to.Trim())
}

# Runtime state: keep Action20's strength control and add an independent
# source-pixel dilation radius. Radius 1 exactly reproduces Action20.
$old = @'
    bool floraReactiveMaskEnabled = false;
    float floraReactiveStrength = 1.0f;
    bool loggedFloraReactive = false;
'@
$new = @'
    bool floraReactiveMaskEnabled = false;
    float floraReactiveStrength = 1.0f;
    int floraReactiveRadius = 1;
    bool loggedFloraReactive = false;
'@
$text = Replace-ExactlyOnce $text $old $new "Action21 state seam"

# Read and clamp the new INI control. 0 = no dilation, 1 = Action20 behavior,
# 2+ = progressively wider source-pixel coverage around flora silhouettes.
$old = @'
        g_bridge.floraReactiveStrength = (float)atof(floraStrengthText);
        g_bridge.floraReactiveStrength = _max(0.0f, _min(1.0f, g_bridge.floraReactiveStrength));
'@
$new = @'
        g_bridge.floraReactiveStrength = (float)atof(floraStrengthText);
        g_bridge.floraReactiveStrength = _max(0.0f, _min(1.0f, g_bridge.floraReactiveStrength));
        g_bridge.floraReactiveRadius = GetPrivateProfileIntA("OptiBridge", "FloraReactiveRadius", 1, path);
        g_bridge.floraReactiveRadius = _max(0, _min(4, g_bridge.floraReactiveRadius));
'@
$text = Replace-ExactlyOnce $text $old $new "Action21 radius config seam"

$old = @'
        Msg("* [OptiBridge] runtime v0.4.2-alpha Action20 flora reactive mask");
'@
$new = @'
        Msg("* [OptiBridge] runtime v0.4.3-alpha Action21 flora mask radius");
'@
$text = Replace-ExactlyOnce $text $old $new "Action21 version seam"

$old = @'
        Msg("* [OptiBridge] Action20 flora reactive mask %s, strength %.3f",
            g_bridge.floraReactiveMaskEnabled ? "on" : "off", g_bridge.floraReactiveStrength);
'@
$new = @'
        Msg("* [OptiBridge] Action21 flora reactive mask %s, strength %.3f, radius %dpx",
            g_bridge.floraReactiveMaskEnabled ? "on" : "off", g_bridge.floraReactiveStrength,
            g_bridge.floraReactiveRadius);
'@
$text = Replace-ExactlyOnce $text $old $new "Action21 config log seam"

# Reuse the same 16-byte constant buffer: strength, radius-as-float, 2 pads.
$old = '        "cbuffer OptiBridgePrepareConstants : register(b0) { float FloraReactiveStrength; float3 PreparePad; };\n"'
$new = '        "cbuffer OptiBridgePrepareConstants : register(b0) { float FloraReactiveStrength; float FloraReactiveRadius; float2 PreparePad; };\n"'
$text = Replace-ExactlyOnce $text $old $new "Action21 shader constant seam"

# Replace Action20's fixed 3x3 lookup with a bounded dynamic radius. A runtime
# [loop] is preferable to unrolling the maximum 9x9 footprint on every build.
$old = @'
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
'@
$new = @'
        "  float reactive = 0.0;\n"
        "  int2 center = int2(src);\n"
        "  int radius = clamp((int)(FloraReactiveRadius + 0.5), 0, 4);\n"
        "  [loop] for (int oy = -radius; oy <= radius; ++oy)\n"
        "  {\n"
        "    [loop] for (int ox = -radius; ox <= radius; ++ox)\n"
        "    {\n"
        "      int2 q = clamp(center + int2(ox,oy), int2(0,0), int2(int(sw)-1,int(sh)-1));\n"
        "      float mtl = UnpackMaterial(SrcPosition.Load(int3(q,0)).w);\n"
        "      if (abs(mtl - 0.47451) <= 0.05) reactive = FloraReactiveStrength;\n"
        "    }\n"
        "  }\n"
        "  OutReactive[id.xy] = saturate(reactive);\n"
'@
$text = Replace-ExactlyOnce $text $old $new "Action21 dilation loop seam"

# Supply radius in the existing dynamic CB.
$old = @'
    constants[0] = g_bridge.floraReactiveMaskEnabled ? g_bridge.floraReactiveStrength : 0.f;
    constants[1] = constants[2] = constants[3] = 0.f;
'@
$new = @'
    constants[0] = g_bridge.floraReactiveMaskEnabled ? g_bridge.floraReactiveStrength : 0.f;
    constants[1] = (float)g_bridge.floraReactiveRadius;
    constants[2] = constants[3] = 0.f;
'@
$text = Replace-ExactlyOnce $text $old $new "Action21 constant upload seam"

$old = @'
            Msg("* [OptiBridge] Action20 flora reactive mask ACTIVE: MAT_FLORA 0.47451, strength %.3f, 1px dilation",
                g_bridge.floraReactiveStrength);
'@
$new = @'
            Msg("* [OptiBridge] Action21 flora reactive mask ACTIVE: MAT_FLORA 0.47451, strength %.3f, radius %dpx",
                g_bridge.floraReactiveStrength, g_bridge.floraReactiveRadius);
'@
$text = Replace-ExactlyOnce $text $old $new "Action21 active log seam"

Set-Content $runtime $text -NoNewline
Write-Host "OptiBridge Action21 configurable flora-mask radius patch applied successfully."
