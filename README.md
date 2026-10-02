# GAMMA OptiBridge

> [!WARNING]
> **ABANDONED / UNMAINTAINED — 2026-10-02**  
> Active development has ended. No further fixes, releases or support are planned by the original project owner. The repository and all experimental branches are intentionally preserved so anyone interested can continue the work.

Experimental DirectX 11 temporal-upscaling bridge for **S.T.A.L.K.E.R. Anomaly / GAMMA**.

## Continue this project

Start here:

- **`docs/PROJECT_HANDOFF.md`** — full technical state, experiment history, hashes, unresolved work and recommended continuation points.
- **`docs/UNINSTALL_AND_RESTORE.md`** — how to remove OptiBridge and return GAMMA to the original Modded Exes setup.
- **`docs/RC3_NOTES.md`** — final renderer checkpoint.
- **`docs/REGRESSION_CHECKLIST.md`** — unfinished release-validation work.

The final development state is on `main` and is identical in lineage to `release-candidate-v0.5.0-rc3` plus the abandonment/handoff documentation.

## Why development stopped

OptiBridge became functional, but on the reference system the project owner preferred native GAMMA rendering combined with Lossless Scaling. Sub-native OptiBridge improved real rendered FPS, but the remaining reduction in fine-detail image quality was not worth that gain for this particular setup.

The owner's final reference experience was roughly:

```text
Native GAMMA:                  ~30–40 FPS
Native + Lossless Scaling:     ~60–70 displayed FPS
```

Lossless Scaling preserved the native source image better but introduced some noticeable input latency. This is a subjective project-owner tradeoff, not a universal performance or image-quality conclusion.

## Last validated renderer state

Final renderer: **v0.5.0-rc3 / corrected Action24**.

Validated non-AVX executable:

```text
AnomalyDX11.exe
SHA-256: 21b93e59853aad1f2c9e469876bd5126e0b1a0ece279cba445a597d674a68b54
```

Corrected Action24 AVX CI executable:

```text
AnomalyDX11AVX.exe
SHA-256: d0404a340c62a84309b1c32623206996961ada58d47a88a0dde002060a2424b3
```

The AVX build compiled successfully but was **not runtime-parity validated** before abandonment.

Source provenance:

```text
X-Ray MT source: 7beaeb8e2b51e700ae6ee47d82bff7c997467f87
FSR2 DX11:        f2e3f86390746eb3f0bd1b28e91ea3cbc790ee76
OptiScaler used:  v0.9.4-final
```

## Architecture

```text
X-Ray R4 renderer
  -> reduced-resolution 3D scene colour
  -> depth
  -> SSFX motion vectors
  -> projection-space temporal jitter
  -> FSR2 DX11 API exported by AnomalyDX11.exe
  -> OptiScaler intercepts FSR2.X
  -> DLSS / XeSS / FSR backend
  -> native-resolution post-processing / UI / presentation
```

## Final validated presets

All presets use the same corrected Action24 executable. Only `RenderScale` changes.

| Preset | RenderScale | Input at 2560x1080 | Reference checkpoint |
| --- | ---: | ---: | ---: |
| Native | 1.00 | 2560x1080 | ~40.6 FPS |
| Quality | 0.90 | 2304x972 | ~48.2 FPS |
| Balanced | 0.85 | 2176x918 | ~52.6 FPS |
| Performance | 0.75 | 1920x810 | ~58.9 FPS |

These are same-scene development measurements, not universal guarantees.

Final shared configuration:

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

Validation used:

```text
r__tf_mipbias 0
```

## Important continuation notes

- **Action23 hashed foliage coverage was rejected** for release: it increased high-contrast foliage flicker in bright weather.
- **Action24 alpha-only foliage mip bias is the final accepted path** and should be the starting point for continuation.
- The main unresolved visual limitation is inherent sub-native reconstruction of very fine foliage, distant geometry and texture detail.
- AVX runtime parity and clean installer/restore validation were not completed.
- RTSS/Afterburner injection appeared to conflict with the game/renderer stack in at least one test configuration; treat overlays as separate compatibility variables.

See `docs/PROJECT_HANDOFF.md` before changing the renderer.

## Branch history

The experimental branches are intentionally retained as bisect/checkpoint history, including:

- `mt-baseline-2026.7.22`
- `mt-action17-native-scene-scale`
- `mt-action18-projection-jitter`
- `mt-action19-temporal-diagnostics`
- `mt-action20-foliage-stability`
- `mt-action21-flora-mask-radius`
- `mt-action22-flora-alpha-stability`
- `mt-action23-hashed-flora-coverage`
- `mt-action24-flora-alpha-mipbias`
- `release-candidate-v0.5.0-rc1`
- `release-candidate-v0.5.0-rc2`
- `release-candidate-v0.5.0-rc3`

Do not squash these branches if preserving the investigation history matters.

## Upstream projects

- xray-monolith / Modded Exes: https://github.com/themrdemonized/xray-monolith
- OptiScaler: https://github.com/optiscaler/OptiScaler
- FSR2 DX11 fork used by OptiScaler: https://github.com/optiscaler/FidelityFX-FSR2-DX11

This project is not affiliated with the GAMMA, Anomaly, OptiScaler, AMD, NVIDIA, or xray-monolith maintainers.

## Maintenance status

**Abandoned. Forks and continuation are welcome.**