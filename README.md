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

RC3 uses the corrected Action24 alpha-only foliage mip-bias path. Bright-weather testing showed it reaches the same practical foliage-stability range as the global `r__tf_mipbias 0.25` diagnostic without globally biasing scene textures.

The RC3 preset set is now validated at 2560x1080:

| Preset | RenderScale | Scene resolution | Observed checkpoint |
| --- | ---: | ---: | ---: |
| Native reference | 1.00 | 2560x1080 | ~40.6 FPS / 24.65 ms |
| Quality | 0.90 | 2304x972 | ~48.2 FPS / 20.75 ms |
| Balanced | 0.85 | 2176x918 | ~52.6 FPS / 19.03 ms |
| Performance | 0.75 | 1920x810 | ~58.9 FPS / 16.98 ms |

The benchmark scene showed approximately +18.7% FPS for Quality, +29.6% for Balanced, and +45.1% for Performance versus the 1.00 native reference. These are scene/system-specific checkpoints, not universal performance guarantees.

Preset files:

- `config/optibridge-native.ini`
- `config/optibridge-quality.ini`
- `config/optibridge-balanced.ini`
- `config/optibridge-performance.ini`

The release-candidate test plan is stored in:

- `docs/REGRESSION_CHECKLIST.md`
- `docs/RC3_NOTES.md`

The repository-safe `config/optibridge.ini` remains conservative and opt-in features remain disabled there.

## Shared RC3 temporal / foliage settings

Only `RenderScale` changes between the four validated presets.

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

## Preset intent

- **Native 1.00**: reference / Ultra comparison mode; no scene-resolution reduction.
- **Quality 0.90**: preferred default. Very close to native image quality with a meaningful performance gain.
- **Balanced 0.85**: larger gain with a small but visible reduction in fine foliage and distant detail.
- **Performance 0.75**: substantial gain; softer fine foliage and distant detail are expected.

## Remaining release gates

Before promotion beyond RC3:

1. complete broad regression across maps, weather, scopes/ADS, PDA/UI, saves, loading transitions, and combat;
2. validate installation, backup, replacement and restore behavior;
3. verify both regular DX11 and AVX package paths;
4. keep RTSS/third-party overlay hook compatibility separate from renderer correctness if external injection conflicts appear.

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
