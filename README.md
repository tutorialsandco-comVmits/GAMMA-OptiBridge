# GAMMA OptiBridge

Experimental DirectX 11 temporal-upscaling bridge for **S.T.A.L.K.E.R. Anomaly / GAMMA**.

## Locked target

This repository currently targets:

- X-Ray Monolith / Modded Exes **2026.7.22** source baseline
- upstream source commit `7beaeb8e2b51e700ae6ee47d82bff7c997467f87`
- DirectX 11: `AnomalyDX11.exe`
- DirectX 11 AVX: `AnomalyDX11AVX.exe`
- FidelityFX FSR 2.2.1 DX11 interface
- OptiScaler DX11 FSR2 input interception
- NVIDIA RTX target: DLSS through OptiScaler
- existing ReShade `dxgi.dll` is intentionally left untouched

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

**v0.5.0-rc3 release-hardening branch. Not yet a general public release.**

The corrected Action24 renderer path is locked for RC3. The remaining work is release hardening and broad regression, not additional foliage micro-tuning unless a new reproducible rendering defect appears.

RC3 uses alpha-only foliage mip bias to stabilize minified leaves/twigs without globally biasing scene texture LOD. Action23 hashed coverage remains compiled as an experimental path but is disabled because bright-weather testing made high-contrast foliage flicker worse.

## Validated presets

All presets use the same corrected Action24 executable and shared temporal/flora settings. Only `RenderScale` changes.

| Preset | RenderScale | Input at 2560x1080 | Development-system checkpoint |
| --- | ---: | ---: | ---: |
| Native | 1.00 | 2560x1080 | ~40.6 FPS |
| Quality | 0.90 | 2304x972 | ~48.2 FPS |
| Balanced | 0.85 | 2176x918 | ~52.6 FPS |
| Performance | 0.75 | 1920x810 | ~58.9 FPS |

Quality `0.90` is the preferred default. The performance numbers above are same-scene development-system measurements, not universal guarantees.

Tracked preset files:

- `config/optibridge-native.ini`
- `config/optibridge-quality.ini`
- `config/optibridge-balanced.ini`
- `config/optibridge-performance.ini`

## Locked shared RC3 settings

```ini
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

## Build hashes

Validated non-AVX RC3 binary:

```text
AnomalyDX11.exe
21b93e59853aad1f2c9e469876bd5126e0b1a0ece279cba445a597d674a68b54
```

Corrected Action24 AVX CI binary:

```text
AnomalyDX11AVX.exe
d0404a340c62a84309b1c32623206996961ada58d47a88a0dde002060a2424b3
```

The AVX build compiled successfully but still requires runtime parity validation before it is included in a release package.

## Managed install / restore

RC3 now includes hash-aware scripts:

- `scripts/install-rc3.ps1`
- `scripts/uninstall-rc3.ps1`
- `scripts/verify-rc3.ps1`
- `scripts/apply-preset.cmd`

The installer:

- verifies the payload hash;
- accepts only the known validated clean non-AVX baseline or an existing managed RC3 install;
- creates a timestamped backup before replacing the clean baseline;
- preserves prior OptiBridge config/preset files;
- leaves `dxgi.dll` and `winmm.dll` unchanged and verifies that they stayed unchanged;
- writes a managed-install manifest used by restore.

The restore script verifies the original backup hash and refuses to overwrite a current executable that has been changed since RC3 was installed.

See `docs/INSTALLATION.md` for details.

## Regression / release gates

The current checklist is `docs/REGRESSION_CHECKLIST.md`.

Major remaining gates include:

1. exercise clean install -> verify -> managed restore against the validated clean baseline and confirm the original SHA-256 is reproduced;
2. complete old-save/new-save/new-game and repeated save/load regression;
3. complete scope/ADS/PDA/UI/map-transition/weather/combat tests;
4. complete the Quality/Balanced/Performance stability soak;
5. isolate third-party overlay/injector crashes from core OptiBridge stability;
6. runtime-test the corrected Action24 AVX executable before including AVX in the release package.

## Safety

The release path must never silently overwrite an unknown Modded Exes build. Unknown executable hashes are a hard stop until explicitly validated.

The OptiBridge installer does not install, replace or delete ReShade or OptiScaler proxy DLLs.

## Upstream projects

- xray-monolith / Modded Exes: https://github.com/themrdemonized/xray-monolith
- OptiScaler: https://github.com/optiscaler/OptiScaler
- FSR2 DX11 fork used by OptiScaler: https://github.com/optiscaler/FidelityFX-FSR2-DX11

This project is not affiliated with the GAMMA, Anomaly, OptiScaler, AMD, NVIDIA, or xray-monolith maintainers.
