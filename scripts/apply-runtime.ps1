param(
    [Parameter(Mandatory=$true)][string]$XrayRoot,
    [Parameter(Mandatory=$true)][string]$Fsr2Root
)

$ErrorActionPreference = "Stop"
$XrayRoot = (Resolve-Path $XrayRoot).Path
$Fsr2Root = (Resolve-Path $Fsr2Root).Path
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

$rendererDir = Join-Path $XrayRoot "src\Layers\xrRenderPC_R4"
$rendererProj = Join-Path $rendererDir "xrRender_R4.vcxproj"
$engineProj = Join-Path $XrayRoot "src\xrEngine\xrEngine.vcxproj"

Copy-Item (Join-Path $repoRoot "src\OptiBridgeRuntime.h") (Join-Path $rendererDir "OptiBridgeRuntime.h") -Force
Copy-Item (Join-Path $repoRoot "src\OptiBridgeRuntime.cpp") (Join-Path $rendererDir "OptiBridgeRuntime.cpp") -Force

# Renderer project: include FSR2 headers and compile the bridge source.
[xml]$rp = Get-Content $rendererProj
$ns = New-Object System.Xml.XmlNamespaceManager($rp.NameTable)
$ns.AddNamespace("m", "http://schemas.microsoft.com/developer/msbuild/2003")
$inc = '$(SolutionDir)..\external\fsr2dx11\src\ffx-fsr2-api;$(SolutionDir)..\external\fsr2dx11\src\ffx-fsr2-api\dx11;'
foreach ($cfg in @("Release", "Release-AVX")) {
    $cond = "'`$(Configuration)|`$(Platform)'=='$cfg|x64'"
    $node = $rp.SelectSingleNode("//m:ItemDefinitionGroup[@Condition=`"$cond`"]//m:ClCompile/m:AdditionalIncludeDirectories", $ns)
    if (-not $node) { throw "Renderer include node missing for $cfg" }
    if (-not $node.InnerText.Contains("external\fsr2dx11")) { $node.InnerText = $inc + $node.InnerText }
}
$compileGroup = $rp.SelectNodes("//m:ItemGroup[m:ClCompile]", $ns) | Select-Object -Last 1
if (-not $compileGroup) { throw "Renderer compile ItemGroup missing" }
if (-not $rp.SelectSingleNode("//m:ClCompile[@Include='OptiBridgeRuntime.cpp']", $ns)) {
    $item = $rp.CreateElement("ClCompile", $rp.DocumentElement.NamespaceURI)
    $item.SetAttribute("Include", "OptiBridgeRuntime.cpp")
    [void]$compileGroup.AppendChild($item)
}
$rp.Save($rendererProj)

# Final EXE: link the static FSR2 core + DX11 backend.
[xml]$ep = Get-Content $engineProj
$ns2 = New-Object System.Xml.XmlNamespaceManager($ep.NameTable)
$ns2.AddNamespace("m", "http://schemas.microsoft.com/developer/msbuild/2003")
$libDir = '$(SolutionDir)..\external\fsr2dx11\bin\ffx_fsr2_api;'
$libs = 'ffx_fsr2_api_x64.lib;ffx_fsr2_api_dx11_x64.lib;'
foreach ($cfg in @("ReleaseR4", "ReleaseR4-AVX")) {
    $cond = "'`$(Configuration)|`$(Platform)'=='$cfg|x64'"
    $deps = $ep.SelectSingleNode("//m:ItemDefinitionGroup[@Condition=`"$cond`"]//m:Link/m:AdditionalDependencies", $ns2)
    $dirs = $ep.SelectSingleNode("//m:ItemDefinitionGroup[@Condition=`"$cond`"]//m:Link/m:AdditionalLibraryDirectories", $ns2)
    if (-not $deps -or -not $dirs) { throw "Engine link nodes missing for $cfg" }
    if (-not $deps.InnerText.Contains("ffx_fsr2_api_x64.lib")) { $deps.InnerText = $libs + $deps.InnerText }
    if (-not $dirs.InnerText.Contains("external\fsr2dx11")) { $dirs.InnerText = $libDir + $dirs.InnerText }
}
$ep.Save($engineProj)

# DX11 base depth: make the backing resource typeless + shader-readable while keeping a D24S8 DSV.
$hw = Join-Path $XrayRoot "src\Layers\xrRenderDX10\dx10HW.cpp"
$text = Get-Content $hw -Raw
$oldFormat = 'descDepth.Format             = DXGI_FORMAT_D24_UNORM_S8_UINT;'
$newFormat = @'
#if defined(USE_DX11)
	descDepth.Format             = DXGI_FORMAT_R24G8_TYPELESS;
#else
	descDepth.Format             = DXGI_FORMAT_D24_UNORM_S8_UINT;
#endif
'@
if (-not $text.Contains($oldFormat)) { throw "Depth format insertion point not found" }
$text = $text.Replace($oldFormat, $newFormat.Trim())
$oldBind = 'descDepth.BindFlags          = D3D_BIND_DEPTH_STENCIL;'
$newBind = @'
#if defined(USE_DX11)
	descDepth.BindFlags          = D3D11_BIND_DEPTH_STENCIL | D3D11_BIND_SHADER_RESOURCE;
#else
	descDepth.BindFlags          = D3D10_BIND_DEPTH_STENCIL;
#endif
'@
if (-not $text.Contains($oldBind)) { throw "Depth bind insertion point not found" }
$text = $text.Replace($oldBind, $newBind.Trim())
$oldDsv = 'R = pDevice->CreateDepthStencilView(pDepthStencil, NULL, &pBaseZB);'
$newDsv = @'
#if defined(USE_DX11)
	D3D11_DEPTH_STENCIL_VIEW_DESC optiDepthView = {};
	optiDepthView.Format = DXGI_FORMAT_D24_UNORM_S8_UINT;
	optiDepthView.ViewDimension = D3D11_DSV_DIMENSION_TEXTURE2D;
	optiDepthView.Texture2D.MipSlice = 0;
	R = pDevice->CreateDepthStencilView(pDepthStencil, &optiDepthView, &pBaseZB);
#else
	R = pDevice->CreateDepthStencilView(pDepthStencil, NULL, &pBaseZB);
#endif
'@
if (-not $text.Contains($oldDsv)) { throw "Depth DSV insertion point not found" }
$text = $text.Replace($oldDsv, $newDsv.Trim())
Set-Content $hw $text -NoNewline

# R4/DX11 transparent HUD compile policy: GAMMA's transparent_hud can select a
# legacy-named pixel entrypoint while using DX11-only semantics (FOG/SV_Position).
# Force that shader to SM5 BEFORE its first compile attempt. This is intentionally
# narrow: other legacy-profile shaders keep the stock loader behavior.
$rm = Join-Path $XrayRoot "src\Layers\xrRenderDX10\dx10ResourceManager_Resources.cpp"
$text = Get-Content $rm -Raw
$oldPsCompile = @'
		HRESULT const _hr = ::Render->shader_compile(name, (DWORD const*)data, size, c_entry, c_target,
		                                             D3D10_SHADER_PACK_MATRIX_ROW_MAJOR, (void*&)_ps);

		VERIFY(SUCCEEDED(_hr));

		CHECK_OR_EXIT(
			!FAILED(_hr),
'@
$newPsCompile = @'
#if defined(USE_DX11)
		if (0 == xr_strcmp(shName, "transparent_hud"))
		{
			if (0 != xr_strcmp(c_target, "ps_5_0"))
				Msg("* [OptiBridge] forcing pixel shader '%s' entry '%s' to ps_5_0", name, c_entry);
			c_target = "ps_5_0";
		}
#endif

		HRESULT const _hr = ::Render->shader_compile(name, (DWORD const*)data, size, c_entry, c_target,
		                                             D3D10_SHADER_PACK_MATRIX_ROW_MAJOR, (void*&)_ps);

		VERIFY(SUCCEEDED(_hr));

		CHECK_OR_EXIT(
			!FAILED(_hr),
'@
if (-not $text.Contains($oldPsCompile.Trim())) { throw "DX11 pixel shader compile block not found" }
$text = $text.Replace($oldPsCompile.Trim(), $newPsCompile.Trim())
Set-Content $rm $text -NoNewline

# Replace stock 4-tap jitter with FSR2 Halton jitter only while OptiBridge is active.
$binder = Join-Path $XrayRoot "src\Layers\xrRender\Blender_Recorder_StandartBinding.cpp"
$text = Get-Content $binder -Raw
$needle = 'static class ssfx_jitter : public R_constant_setup'
if (-not $text.Contains($needle)) { throw "SSFX jitter class not found" }
$decl = "#if defined(USE_DX11)`r`nextern bool OptiBridge_GetJitterNdc(float& x, float& y);`r`n#endif`r`n`r`n"
$text = $text.Replace($needle, $decl + $needle)
$old = @'
#if defined(USE_DX11)
		if (ps_ssfx_taa.x > 0 && RImplementation.o.ssfx_taa)
		{
			static Fvector2 TAA_Offset[4] = 
			{
				{  0.0f, -1.0f },
				{ -1.0f,  0.0f },
				{  1.0f,  0.0f },
				{  0.0f,  1.0f }
			};

			JitterX = TAA_Offset[ Device.dwFrame % 4 ].x / Device.dwWidth;
			JitterY = TAA_Offset[ Device.dwFrame % 4 ].y / Device.dwHeight;
		}
#endif

		RCache.set_c(C, JitterX * ps_ssfx_taa.y, JitterY * ps_ssfx_taa.y, ps_ssfx_taa.x, ps_ssfx_taa.w);
'@
$new = @'
#if defined(USE_DX11)
		const bool optiJitter = OptiBridge_GetJitterNdc(JitterX, JitterY);
		if (!optiJitter && ps_ssfx_taa.x > 0 && RImplementation.o.ssfx_taa)
		{
			static Fvector2 TAA_Offset[4] = 
			{
				{  0.0f, -1.0f },
				{ -1.0f,  0.0f },
				{  1.0f,  0.0f },
				{  0.0f,  1.0f }
			};

			JitterX = TAA_Offset[ Device.dwFrame % 4 ].x / Device.dwWidth;
			JitterY = TAA_Offset[ Device.dwFrame % 4 ].y / Device.dwHeight;
		}
		if (optiJitter)
			RCache.set_c(C, JitterX, JitterY, 1.0f, ps_ssfx_taa.w);
		else
			RCache.set_c(C, JitterX * ps_ssfx_taa.y, JitterY * ps_ssfx_taa.y, ps_ssfx_taa.x, ps_ssfx_taa.w);
#else
		RCache.set_c(C, JitterX, JitterY, ps_ssfx_taa.x, ps_ssfx_taa.w);
#endif
'@
if (-not $text.Contains($old.Trim())) { throw "Stock SSFX jitter body not found" }
$text = $text.Replace($old.Trim(), $new.Trim())
Set-Content $binder $text -NoNewline

# Insert bridge at the same late-frame seam where stock SSFX TAA normally runs.
$combine = Join-Path $rendererDir "r4_rendertarget_phase_combine.cpp"
$text = Get-Content $combine -Raw
$includeNeedle = '#include "../../xrEngine/environment.h"'
$text = $text.Replace($includeNeedle, $includeNeedle + [Environment]::NewLine + '#include "OptiBridgeRuntime.h"')
$oldTaa = @'
	if (RImplementation.o.ssfx_taa && ps_ssfx_taa.x > 0)
	{
		phase_ssfx_taa();
	}
'@
$newTaa = @'
	const bool optiBridgeResolved = OptiBridge_Dispatch(this);
	if (!optiBridgeResolved && RImplementation.o.ssfx_taa && ps_ssfx_taa.x > 0)
	{
		phase_ssfx_taa();
	}
'@
if (-not $text.Contains($oldTaa.Trim())) { throw "Stock TAA seam not found" }
$text = $text.Replace($oldTaa.Trim(), $newTaa.Trim())
Set-Content $combine $text -NoNewline

Write-Host "OptiBridge native-resolution runtime patch applied successfully."