# GAMMA OptiBridge

Experimental DirectX 11 temporal-upscaling bridge for **S.T.A.L.K.E.R. Anomaly / GAMMA**.

## Locked target

This repository currently targets:

- X-Ray Monolith / Modded Exes **2026.7.22**
- upstream source commit `7beaeb8e2b51e700ae6ee47d82bff7c997467f87`
- DirectX 11: `AnomalyDX11.exe`
- DirectX 11 AVX: `AnomalyDX11AVX.exe`
- FidelityFX FSR 2.2.1 DX11 interface
- OptiScaler DX11 FSR2 input interception
- NVIDIA RTX target: DLSS through OptiScaler
- Existing ReShade `dxgi.dll` is intentionally left untouched

## Architecture

```text
X-Ray R4 renderer
  -> reduced-resolution scene colour
  -> depth
  -> SSFX motion vectors
  -> projection-space temporal jitter
  -> FSR2 DX11 API exported by AnomalyDX11.exe
  -> OptiScaler intercepts the FSR2 dispatch
  -> DLSS / XeSS / FSR backend
  -> X-Ray post-processing / native-resolution UI and presentation
```

OptiScaler's DX11 FSR2 input path searches for exported `ffxFsr2...` functions in the game executable. The build therefore links the DX11 FSR2 API directly into the executable and exports those entry points.

## Status

**v0.5.0-rc3 finalization branch. Not yet a general public release.**

The core path is functional. RC3 promotes the corrected Action24 alpha-only foliage mip-bias path after bright-weather testing showed it reaches the same practical stability range as the global `r__tf_mipbias 0.25` diagnostic without globally softening scene textures.

The validated Quality preset is stored in:

- `config/optibridge-quality.ini`

The release-candidate test plan is stored in:

- `docs/REGRESSION_CHECKLIST.md`
- `docs/RC3_NOTES.md`

The repository-safe `config/optibridge.ini` remains conservative and opt-in features remain disabled there.

## Current Quality checkpoint

```ini
RenderScale=0.90
NativeSceneScale=1
ProjectionJitter=1
JitterScale=0.35
DispatchJitterScale=1.0
MotionVectorScaleFactor=1.0
MVJitterCancellation=1
FloraReactiveMask=1
FloraReactiveStrength=0.50
FloraReactiveRadius=1
FloraAlphaStabilization=1
FloraAlphaWidthScale=0.10
FloraAlphaMipBias=0.25
FloraHashedCoverage=0
FloraHashedCoverageScale=0.05
```

Global game setting for RC3 validation:

```text
r__tf_mipbias 0
```

## Release gates

Before promotion beyond RC3:

1. complete the regression checklist with the Quality preset unchanged;
2. capture same-scene native `1.00` versus Quality `0.90` performance;
3. test lower render scales only as separate single-variable experiments;
4. derive Balanced/Performance presets only from validated lower-scale results;
5. validate backup/install/restore behavior before distributing an installer.

## Safety

The eventual installer must:

1. verify the user's original executable hash,
2. back up the original executable,
3. preserve the existing ReShade `dxgi.dll`,
4. install OptiScaler through a non-conflicting proxy,
5. provide an uninstall/restore path.

## Upstream projects

- xray-monolith / Modded Exes: https://github.com/themrdemonized/xray-monolith
- OptiScaler: https://github.com/optiscaler/OptiScaler
- FSR2 DX11 fork used by OptiScaler: https://github.com/optiscaler/FidelityFX-FSR2-DX11

This project is not affiliated with the GAMMA, Anomaly, OptiScaler, AMD, NVIDIA, or xray-monolith maintainers.
