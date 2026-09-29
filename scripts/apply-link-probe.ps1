param(
    [Parameter(Mandatory=$true)][string]$XrayRoot,
    [Parameter(Mandatory=$true)][string]$Fsr2Root
)

$ErrorActionPreference = "Stop"

$XrayRoot = (Resolve-Path $XrayRoot).Path
$Fsr2Root = (Resolve-Path $Fsr2Root).Path
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

$rendererDir = Join-Path $XrayRoot "src\Layers\xrRenderPC_R4"
$rendererCpp = Join-Path $rendererDir "r4_rendertarget.cpp"
$rendererProj = Join-Path $rendererDir "xrRender_R4.vcxproj"
$engineProj = Join-Path $XrayRoot "src\xrEngine\xrEngine.vcxproj"

Copy-Item (Join-Path $repoRoot "src\OptiBridgeFsr2Link.h") (Join-Path $rendererDir "OptiBridgeFsr2Link.h") -Force

# Wire the harmless link probe into CRenderTarget construction.
$text = Get-Content $rendererCpp -Raw
if ($text -notmatch '#include "OptiBridgeFsr2Link.h"') {
    $needle = '#include "blender_lut.h"'
    if (-not $text.Contains($needle)) { throw "Could not find include insertion point in r4_rendertarget.cpp" }
    $text = $text.Replace($needle, $needle + [Environment]::NewLine + '#include "OptiBridgeFsr2Link.h"')
}
if ($text -notmatch 'OptiBridgeFsr2LinkProbe\(\);') {
    $rx = [regex]::new('CRenderTarget::CRenderTarget\(\)\s*\{')
    $text = $rx.Replace($text, '$0' + [Environment]::NewLine + "`tOptiBridgeFsr2LinkProbe();", 1)
    if ($text -notmatch 'OptiBridgeFsr2LinkProbe\(\);') { throw "Could not insert link probe call" }
}
Set-Content $rendererCpp $text -NoNewline

# Add FSR2 headers to the two R4 configurations.
[xml]$rp = Get-Content $rendererProj
$ns = New-Object System.Xml.XmlNamespaceManager($rp.NameTable)
$ns.AddNamespace("m", "http://schemas.microsoft.com/developer/msbuild/2003")
$inc = '$(SolutionDir)..\external\fsr2dx11\src\ffx-fsr2-api;$(SolutionDir)..\external\fsr2dx11\src\ffx-fsr2-api\dx11;'
foreach ($cfg in @("Release", "Release-AVX")) {
    $cond = "'`$(Configuration)|`$(Platform)'=='$cfg|x64'"
    $node = $rp.SelectSingleNode("//m:ItemDefinitionGroup[@Condition=`"$cond`"]//m:ClCompile/m:AdditionalIncludeDirectories", $ns)
    if (-not $node) { throw "Renderer include node missing for $cfg" }
    if (-not $node.InnerText.Contains("external\fsr2dx11")) {
        $node.InnerText = $inc + $node.InnerText
    }
}
$rp.Save($rendererProj)

# Link the two static FSR2 libraries into the final DX11 executables.
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
    if (-not $deps.InnerText.Contains("ffx_fsr2_api_x64.lib")) {
        $deps.InnerText = $libs + $deps.InnerText
    }
    if (-not $dirs.InnerText.Contains("external\fsr2dx11")) {
        $dirs.InnerText = $libDir + $dirs.InnerText
    }
}
$ep.Save($engineProj)

Write-Host "OptiBridge FSR2 link/export probe applied successfully."