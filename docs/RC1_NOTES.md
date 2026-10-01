# GAMMA OptiBridge v0.5.0-rc1

## Status

This branch is the first release-candidate finalization branch. It is based on the successful Action23 hashed-flora-coverage build and does not change renderer code relative to that image-quality checkpoint.

## Validated Quality checkpoint

```ini
[OptiBridge]
Enabled=1
Jitter=1
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

## What is already validated

- true reduced-resolution scene rendering through the R4 path;
- OptiScaler interception through the exported FSR2 DX11 API;
- DLSS backend operation through OptiScaler;
- MT executable compatibility for the tested 2026.7.22 source family;
- old-save and new-game loading in prior Action17+ testing;
- ADS/scope rendering in prior regression tests;
- native-resolution UI/backbuffer behavior;
- elimination of the original whole-scene jitter/wobble;
- functional motion-vector/projection-jitter path;
- foliage reactive-mask stabilization;
- tree alpha-test stabilization at `FloraAlphaWidthScale=0.10`;
- hashed foliage coverage at `0.05` without obvious stipple, haloing or major ghost trails in the reference scene.

## RC1 purpose

RC1 is for broad regression, stability and performance validation. Do not tune foliage parameters during the regression pass. If a problem appears, preserve the exact Quality preset and isolate the failing scene/path first.

## Next gates

1. Complete `REGRESSION_CHECKLIST.md` using the unchanged Quality preset.
2. Capture native (`1.00`) versus Quality (`0.85`) performance in the same scene.
3. If RC quality is clean, test `RenderScale=0.75` as a single-variable experiment.
4. Only create Balanced/Performance presets after those lower-scale results are validated.
5. After regression and performance gates pass, prepare the installer/backup/restore path and promote to a public release candidate or v1.0 candidate.
