param(
    [Parameter(Mandatory=$true)][string]$XrayRoot
)

$ErrorActionPreference = "Stop"
$rm = Join-Path (Resolve-Path $XrayRoot).Path "src\Layers\xrRenderDX10\dx10ResourceManager_Resources.cpp"
$text = Get-Content $rm -Raw

$old = @'
#if defined(USE_DX11)
		// models_transparent_hud.vs contains a legacy main_vs_2_0 entry that the
		// generic loader prefers over main. Compiling that legacy body as SM5 avoids
		// CreateVertexShader(E_INVALIDARG), but it is not the intended R4/DX11 HUD
		// path and can render scopes incorrectly. Use the shader's normal main entry
		// for this one HUD shader; leave all other vertex shaders on stock policy.
		if (0 == xr_strcmp(shName, "models_transparent_hud") && 0 != xr_strcmp(c_entry, "main"))
		{
			Msg("* [OptiBridge] selecting DX11 vertex entry 'main' for '%s' instead of legacy '%s'", name, c_entry);
			c_entry = "main";
			c_target = "vs_5_0";
		}
#endif
'@

$new = @'
#if defined(USE_DX11)
		// Action #16: R4/DX11 shader sources can carry legacy main_vs_1_1/main_vs_2_0
		// compatibility bodies. The generic loader prefers those legacy entries and
		// profiles when it sees them, which is invalid for uncached D3D11 vertex
		// shaders and can also select the wrong rendering path when merely promoted
		// to SM5. For DX11, use the shader's modern main entry with an SM5 profile
		// whenever the loader would otherwise use a VS1/VS2 target.
		if (0 == xr_strcmp(c_target, "vs_2_0") || 0 == xr_strcmp(c_target, "vs_1_1"))
		{
			Msg("* [OptiBridge] Action16: selecting DX11 vertex entry 'main' for '%s' instead of legacy entry '%s' target '%s'", name, c_entry, c_target);
			c_entry = "main";
			c_target = "vs_5_0";
		}
#endif
'@

if (-not $text.Contains($old.Trim())) { throw "Action13 targeted transparent-HUD vertex policy block not found" }
$text = $text.Replace($old.Trim(), $new.Trim())
Set-Content $rm $text -NoNewline
Write-Host "OptiBridge Action16 generalized DX11 vertex-entry policy applied successfully."
