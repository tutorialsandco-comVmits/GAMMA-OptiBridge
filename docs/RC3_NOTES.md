# GAMMA OptiBridge v0.5.0-rc3

RC3 promotes the corrected Action24 foliage path and now includes a validated four-mode preset matrix: Native reference, Quality, Balanced, and Performance.

## Why RC3 exists

Bright clear-weather testing at RenderScale 0.90 showed that the remaining shimmer was concentrated on alpha-tested leaves and thin twigs against bright sky. A global `r__tf_mipbias 0.25` diagnostic reduced the artifact, proving that foliage minification was a major contributor.

The first alpha-only implementation did not fully reproduce the global result because the alpha cutoff used the biased sample while the derivative stabilization still used the original un-biased alpha expression.

The corrected Action24 implementation uses the same biased alpha sample for both the cutoff value and its `fwidth()` derivative.

## Shared temporal / foliage settings

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

The game-wide mip-bias setting remains:

```text
r__tf_mipbias 0
```

Only `RenderScale` changes between the validated presets.

## Validated preset matrix

Validation system: 2560x1080 DX11 MT, OptiScaler FSR2.X input -> DLSS on RTX 3060.

| Preset | RenderScale | Scene resolution | Checkpoint FPS | Checkpoint frametime | FPS vs native |
| --- | ---: | ---: | ---: | ---: | ---: |
| Native reference | 1.00 | 2560x1080 | ~40.6 | ~24.65 ms | reference |
| Quality | 0.90 | 2304x972 | ~48.2 | ~20.75 ms | ~+18.7% |
| Balanced | 0.85 | 2176x918 | ~52.6 | ~19.03 ms | ~+29.6% |
| Performance | 0.75 | 1920x810 | ~58.9 | ~16.98 ms | ~+45.1% |

These values are same-scene checkpoints from the validation system and should not be treated as universal performance guarantees.

## Visual interpretation

- **Native 1.00** remains the image-quality reference.
- **Quality 0.90** is the preferred default. It remains extremely close to native while producing a meaningful performance gain.
- **Balanced 0.85** shows a small but visible reduction in fine foliage and distant/ground detail while delivering a larger performance improvement.
- **Performance 0.75** is visibly softer and reconstructs more aggressively, especially on thin foliage and distant detail, but remains usable and delivers the largest tested gain.

The corrected alpha-only bias remains in the same practical foliage-stability range as the global +0.25 diagnostic while normal scene texture sampling stays at global mip bias 0. Action23 hashed coverage remains disabled because bright-weather testing made high-contrast foliage flicker worse.

## Preset files

- `config/optibridge-native.ini`
- `config/optibridge-quality.ini`
- `config/optibridge-balanced.ini`
- `config/optibridge-performance.ini`

## Current release interpretation

The image-quality tuning phase is considered complete unless a new reproducible regression appears on another map, weather condition, scope path, or renderer state. Further work should focus on broad regression, packaging/install/restore, DX11/AVX parity, and external overlay-hook compatibility rather than more render-scale or foliage micro-tuning.
