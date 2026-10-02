# GAMMA OptiBridge v0.5.0-rc2

RC2 is the current release-candidate Quality checkpoint.

## Change from RC1

RC1 enabled Action23 UV-anchored hashed flora coverage at scale `0.05`. In darker/cloudier foliage testing it produced a small short-term reduction in leaf-edge variation, but clear/bright-weather testing exposed a regression: high-contrast leaves and thin twigs against bright sky flickered more visibly.

A same-scene one-variable test with `FloraHashedCoverage=0` materially reduced high-contrast foliage variation. The two recordings used different capture resolutions, so whole-frame direct pixel comparison was intentionally avoided; normalized foliage/sky edge regions were compared during stationary opening sections.

Observed normalized edge metrics from that comparison:

- Hashed coverage ON: mean sampled edge absolute difference ~15.47; temporal standard deviation ~20.19.
- Hashed coverage OFF: mean sampled edge absolute difference ~10.63; temporal standard deviation ~14.99.

These numbers are diagnostic rather than laboratory measurements, but the magnitude and visual result point in the same direction.

## RC2 Quality preset

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
FloraHashedCoverage=0
FloraHashedCoverageScale=0.05
```

Action23 remains present in source/history for future research but is not part of the RC2 Quality preset.

## Next gates

1. Broad RC2 regression under multiple weather/lighting conditions.
2. Same-scene performance reference at RenderScale 1.00 and Quality 0.85.
3. Separate RenderScale 0.75 experiment for a possible Balanced preset.
4. Installer/backup/restore validation before public release.
