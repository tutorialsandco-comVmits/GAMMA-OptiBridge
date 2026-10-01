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

**v0.5.0-rc1 finalization branch. Not yet a general public release.**

The core path is functional and the current Quality checkpoint is based on the successful Action23 build. Development has moved from foliage/image-quality experimentation into broad regression, stability, performance and packaging validation.

The validated Quality preset is stored in:

- `config/optibridge-quality.ini`

The release-candidate test plan is stored in:

- `docs/REGRESSION_CHECKLIST.md`
- `docs/RC1_NOTES.md`

The repository-safe `config/optibridge.ini` remains conservative and opt-in features remain disabled there. This prevents an experimental branch checkout from silently enabling reduced-resolution rendering for an unvalidated setup.

## Current Quality checkpoint

```ini
RenderScale=0.85
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
FloraHashedCoverage=1
FloraHashedCoverageScale=0.05
```

## Release gates

Before promotion beyond RC1:

1. complete the regression checklist with the Quality preset unchanged;
2. capture same-scene native `1.00` versus Quality `0.85` performance;
3. test `RenderScale=0.75` only as a separate single-variable experiment after Quality regression is clean;
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
