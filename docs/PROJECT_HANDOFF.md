# GAMMA OptiBridge — project handoff

> **Project status: ABANDONED / UNMAINTAINED**  
> Development stopped on **2026-10-02**. The repository is intentionally preserved so another developer can continue from the last validated state.

## Why development stopped

The project reached a functional release-candidate state, but on the reference system the image-quality loss from sub-native scene rendering was judged not worth the performance increase. Native rendering combined with Lossless Scaling was preferred subjectively because it retained the original image quality while producing a larger apparent frame-rate increase, at the cost of some additional input latency.

This is a project-owner preference, not a claim that OptiBridge is universally inferior. The renderer integration itself works and the repository is left in a continuation-friendly state.

## Last validated state

Final development line: `release-candidate-v0.5.0-rc3` (also fast-forwarded into `main`).

Validated non-AVX RC3 executable:

```text
AnomalyDX11.exe
SHA-256: 21b93e59853aad1f2c9e469876bd5126e0b1a0ece279cba445a597d674a68b54
```

Corrected Action24 AVX CI executable:

```text
AnomalyDX11AVX.exe
SHA-256: d0404a340c62a84309b1c32623206996961ada58d47a88a0dde002060a2424b3
```

The AVX binary compiled successfully but was not runtime-parity validated before abandonment.

Source provenance:

```text
X-Ray MT source: 7beaeb8e2b51e700ae6ee47d82bff7c997467f87
FSR2 DX11:        f2e3f86390746eb3f0bd1b28e91ea3cbc790ee76
OptiScaler used:  v0.9.4-final
```

## Final architecture

```text
X-Ray R4 renderer
  -> reduced-resolution 3D scene
  -> depth
  -> SSFX motion vectors
  -> projection-space temporal jitter
  -> FSR2 DX11 API exported by AnomalyDX11.exe
  -> OptiScaler intercepts FSR2.X
  -> DLSS / XeSS / FSR backend
  -> native-resolution post-processing / UI / presentation
```

OptiBridge links the FSR2 DX11 API directly into the game executable because OptiScaler's DX11 FSR2 path can intercept exported `ffxFsr2...` functions from the executable.

## Validated presets

All presets use the same corrected Action24 renderer and differ only by `RenderScale`.

| Preset | RenderScale | Input at 2560x1080 | Reference-system checkpoint |
| --- | ---: | ---: | ---: |
| Native | 1.00 | 2560x1080 | ~40.6 FPS |
| Quality | 0.90 | 2304x972 | ~48.2 FPS |
| Balanced | 0.85 | 2176x918 | ~52.6 FPS |
| Performance | 0.75 | 1920x810 | ~58.9 FPS |

These are same-scene development measurements, not universal performance guarantees.

Final shared settings:

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

Global game setting used for validation:

```text
r__tf_mipbias 0
```

## What was solved

- Real low-resolution R4 scene targets while keeping UI/presentation native-resolution.
- FSR2 DX11 export surface for OptiScaler interception.
- Old saves and new games loading on validated non-AVX builds.
- ADS/scopes after legacy DX11 shader-entry fixes.
- Earlier whole-scene jitter/wobble.
- Empirical temporal jitter compromise at `JitterScale=0.35`.
- Programmatic foliage reactive mask because the game does not provide OptiScaler's UI reactive-mask input.
- Foliage alpha-test stabilization with derivative bias.
- Action24 alpha-only positive mip bias so cutout alpha can use a softer mip without globally softening normal scene textures.

## Important experiment history

### Action17 — native scene scaling

Introduced true sub-native R4 scene targets. This is the core performance feature.

### Action18/19 — temporal integration

Projection-space jitter alone did not eliminate shimmer. Diagnostics established that reducing the effective jitter amplitude was the largest global improvement; `0.35` became the reference compromise.

### Action20/21 — foliage reactive mask

A programmatic flora mask helped, with strength `0.50` and radius `1` retained.

### Action22 — alpha-test stabilization

Targeted dedicated tree alpha-test shaders. `FloraAlphaWidthScale=0.10` was the best tested value.

### Action23 — hashed foliage coverage

**Rejected.** It could look acceptable in darker scenes but increased high-contrast leaf/twig flicker against bright sky. Keep disabled for any continuation baseline.

### Action24 — alpha-only foliage mip bias

Final accepted foliage path. The first implementation mixed a biased alpha cutoff with an unbiased derivative; the corrected version uses the same biased alpha sample for both the cutoff and `fwidth()` term. Final value: `FloraAlphaMipBias=0.25`.

## Known limitations / unfinished work

1. **Sub-native image quality remains the fundamental tradeoff.** Fine foliage, distant texture detail and small geometry are visibly reconstructed below native resolution. Action24 improves stability but cannot make 0.75/0.85/0.90 identical to native.
2. **AVX runtime parity was not completed.** The corrected AVX executable compiled successfully but should be treated as unvalidated until tested in-game.
3. **Managed install -> restore was not exercised end-to-end against a pristine user installation.** The scripts are defensive and hash-aware, but this remained a release gate.
4. **RTSS/Afterburner overlay injection appeared capable of causing abrupt process termination** in at least one test configuration. The X-Ray log ended without a normal fatal block; treat third-party overlays/injectors as separate compatibility variables.
5. **No true alpha-coverage-preserving foliage mipmap generation was implemented.** That would be a deeper asset-side solution to alpha-test minification instability.
6. **No public general-release installer was declared production-ready.**

## Branch map

Preserve these branches; they are useful bisect/checkpoint references:

- `mt-baseline-2026.7.22` — MT source baseline
- `mt-action17-native-scene-scale` — true low-res scene targets
- `mt-action18-projection-jitter`
- `mt-action19-temporal-diagnostics`
- `mt-action20-foliage-stability`
- `mt-action21-flora-mask-radius`
- `mt-action22-flora-alpha-stability`
- `mt-action23-hashed-flora-coverage` — experimental/rejected for release
- `mt-action24-flora-alpha-mipbias` — final renderer refinement
- `release-candidate-v0.5.0-rc1`
- `release-candidate-v0.5.0-rc2`
- `release-candidate-v0.5.0-rc3` — final project state before abandonment

Do not rewrite or squash these branches if the goal is to preserve the investigation history.

## Best continuation points

A new maintainer should start from `main` / `release-candidate-v0.5.0-rc3`, not from Action23.

Highest-value next investigations would be:

1. validate AVX runtime parity;
2. test true alpha-coverage-preserving foliage mipmaps or mip-aware alpha thresholds;
3. investigate whether foliage-only whole-material LOD bias gives better stability than alpha-only bias without global softness;
4. profile GPU cost by pass to identify where native-resolution retention matters most;
5. explore hybrid scaling where only selected expensive passes or geometry classes are reduced rather than the entire 3D scene;
6. test newer OptiScaler / DLSS releases only as isolated compatibility changes;
7. complete clean install/uninstall validation before distributing binaries broadly.

## Testing rules that saved time

- Change one variable at a time.
- Do not clear shader caches without evidence that the cache is stale.
- Stationary bright-sky foliage is the fastest shimmer diagnostic.
- Direct in-game observation is more trustworthy than compressed video for very fine temporal artifacts.
- Keep Lossless Scaling disabled while evaluating OptiBridge itself.
- Keep global `r__tf_mipbias 0`; use targeted runtime bias instead.
- Do not re-enable Action23 hashed coverage as a default.

## Personal reference outcome

On the original reference system (RTX 3060, i7-6700K, 2560x1080), the project owner ultimately preferred native GAMMA rendering combined with Lossless Scaling. The observed experience was roughly 30–40 native FPS becoming roughly 60–70 displayed FPS, with visibly better source image quality than sub-native OptiBridge, but with noticeable extra input latency.

That result is included so a future maintainer understands why development stopped even though the renderer bridge was functional.

## Related documentation

- `README.md`
- `docs/RC3_NOTES.md`
- `docs/REGRESSION_CHECKLIST.md`
- `docs/INSTALLATION.md`
- `docs/UNINSTALL_AND_RESTORE.md`

## Maintenance status

No further fixes, releases or support are planned by the original project owner. Forking and continuation are welcome.