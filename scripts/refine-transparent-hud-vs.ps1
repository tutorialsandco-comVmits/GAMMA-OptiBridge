param(
    [Parameter(Mandatory=$true)][string]$XrayRoot
)

$ErrorActionPreference = "Stop"
$rm = Join-Path (Resolve-Path $XrayRoot).Path "src\Layers\xrRenderDX10\dx10ResourceManager_Resources.cpp"
$text = Get-Content $rm -Raw

$old = @'
#if defined(USE_DX11)
		if (0 == xr_strcmp(c_target, "vs_2_0"))
		{
			Msg("* [OptiBridge] promoting legacy vertex shader '%s' entry '%s' from vs_2_0 to vs_5_0", name, c_entry);
			c_target = "vs_5_0";
		}
#endif
'@

$new = @'
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

if (-not $text.Contains($old.Trim())) { throw "Broad legacy vertex promotion block not found" }
$text = $text.Replace($old.Trim(), $new.Trim())
Set-Content $rm $text -NoNewline
Write-Host "OptiBridge targeted transparent-HUD vertex policy applied successfully."
