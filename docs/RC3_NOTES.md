# GAMMA OptiBridge v0.5.0-rc3

RC3 promotes the corrected Action24 foliage path.

## Why RC3 exists

Bright clear-weather testing at RenderScale 0.90 showed that the remaining shimmer was concentrated on alpha-tested leaves and thin twigs against bright sky. A global `r__tf_mipbias 0.25` diagnostic reduced the artifact, proving that foliage minification was a major contributor.

The first alpha-only implementation did not fully reproduce the global result because the alpha cutoff used the biased sample while the derivative stabilization still used the original un-biased alpha expression.

The corrected Action24 implementation uses the same biased alpha sample for both the cutoff value and its `fwidth()` derivative.

## Quality preset

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

The game-wide mip-bias setting remains:

```text
r__tf_mipbias 0
```

## Current interpretation

The corrected alpha-only bias is now in the same practical stability range as the global +0.25 diagnostic while normal scene texture sampling remains unaffected. Action23 hashed coverage remains disabled because bright-weather testing made high-contrast foliage flicker worse.

RC3 should now be used for broader regression and performance validation rather than further foliage micro-tuning unless a new reproducible regression appears.
