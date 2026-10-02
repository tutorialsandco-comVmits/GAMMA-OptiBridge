# OptiBridge v0.5.0-rc3 Regression Checklist

Use the validated RC3 presets unchanged. Change one variable only when a test explicitly calls for it.

## Test rules

- Launch GAMMA normally through MO2.
- DX11, MSAA off, Lossless Scaling off.
- Keep OptiScaler backend/settings fixed while comparing presets.
- Keep global `r__tf_mipbias 0`.
- Do not clear shader caches unless a specific failure gives evidence that the cache is stale.
- Record direct in-game observations first; video is secondary evidence for subtle temporal artifacts.
- If a regression appears, save the X-Ray log and identify the exact test before changing settings.
- If a crash occurs while RTSS, Afterburner OSD, OBS Game Capture, Game Bar, or another injected overlay is active, reproduce once with that injector disabled before classifying the crash as an OptiBridge regression.

## Locked RC3 shared settings

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

## Validated presets

- [x] Native: `RenderScale=1.00` -> 2560x1080 input.
- [x] Quality: `RenderScale=0.90` -> 2304x972 input.
- [x] Balanced: `RenderScale=0.85` -> 2176x918 input.
- [x] Performance: `RenderScale=0.75` -> 1920x810 input.

Same-scene validation checkpoint on the development system:

| Preset | Approx. FPS | Approx. frametime | Gain vs Native |
| --- | ---: | ---: | ---: |
| Native | 40.6 | 24.65 ms | reference |
| Quality | 48.2 | 20.75 ms | +18.7% |
| Balanced | 52.6 | 19.03 ms | +29.6% |
| Performance | 58.9 | 16.98 ms | +45.1% |

These measurements are a development-system checkpoint, not universal performance guarantees.

## A. Managed installation and restore

- [ ] Clean supported baseline hash is accepted.
- [ ] Unknown executable hash is rejected without modifying files.
- [ ] Timestamped original executable backup is created.
- [ ] Existing `optibridge.ini` is backed up before replacement.
- [ ] Existing OptiBridge preset files/switcher are backed up before replacement.
- [ ] Installed `AnomalyDX11.exe` matches RC3 SHA-256 `21b93e59853aad1f2c9e469876bd5126e0b1a0ece279cba445a597d674a68b54`.
- [ ] `dxgi.dll` is unchanged by install.
- [ ] `winmm.dll` is unchanged by install.
- [ ] Preset switcher changes only `optibridge.ini`.
- [ ] Managed uninstall restores original executable hash.
- [ ] Managed uninstall restores pre-existing OptiBridge config/preset files when they existed.
- [ ] Restore refuses to overwrite an executable changed after RC3 installation.

## B. Startup and save integrity

- [ ] Main menu loads normally.
- [ ] Existing old save loads without crash.
- [ ] Recent save loads without crash.
- [ ] New game starts successfully.
- [ ] Save game works.
- [ ] Reloading the new save works.
- [ ] Multiple save/load cycles work.
- [ ] Level transition works in both directions where applicable.
- [ ] Returning to main menu and loading another save works.

## C. UI and HUD

- [ ] HUD remains native-resolution and correctly aligned.
- [ ] Inventory renders correctly.
- [ ] PDA main interface renders correctly.
- [ ] PDA map renders correctly and zoom/pan work.
- [ ] Dialogue/trade UI renders correctly.
- [ ] Pause/menu overlays render correctly.
- [ ] Notifications/subtitles are sharp and correctly positioned.
- [ ] 3D PDA mode, if enabled, does not expose scaled-buffer alignment errors.

## D. Weapons and scopes

- [ ] Hip-fire rendering normal.
- [ ] Iron sights normal.
- [ ] ADS transition normal.
- [ ] 2D scope normal.
- [ ] 3D/PiP scope normal if installed.
- [ ] Scope entry/exit has no resize, jitter, black frame or stale-frame artifact.
- [ ] Repeated rapid ADS/scope entry/exit remains stable.
- [ ] Muzzle flash normal.
- [ ] Weapon motion does not leave obvious temporal trails.
- [ ] Weapon switching/reloading does not expose presentation artifacts.

## E. Outdoor image stability

Run at least Quality `0.90`; spot-check Balanced and Performance after Quality is clean.

- [ ] Stationary hard geometry stable.
- [ ] Slow camera pan stable.
- [ ] Fast pan does not produce whole-screen wobble.
- [ ] Fine fences/wires stable enough for selected preset.
- [ ] Distant tree trunks/branches stable.
- [ ] Fine leaves/twigs show no major shimmer regression.
- [ ] Foliage alpha edges show no stipple/screen-fixed hashed noise.
- [ ] Foliage is not visibly over-thickened by alpha stabilization.
- [ ] Grass is acceptable at walking speed.
- [ ] Distant terrain/roof edges are acceptable.
- [ ] Bright-sky tree silhouettes remain acceptable.

## F. Weather and lighting

- [ ] Clear bright daytime.
- [ ] Overcast.
- [ ] Rain/wet surfaces.
- [ ] Fog/heavy atmosphere.
- [ ] Dawn/dusk.
- [ ] Night.
- [ ] Dynamic lights/flashlight.
- [ ] Lightning or bright transient lighting if available.
- [ ] Weather transition does not create persistent temporal corruption.

## G. Interiors and transitions

- [ ] Dark interior.
- [ ] Bright interior.
- [ ] Doorway/window high-contrast transitions.
- [ ] Moving interior -> exterior.
- [ ] Moving exterior -> interior.
- [ ] No exposure-related temporal instability attributable to OptiBridge.
- [ ] No scaled-target resize artifact after level/interior transition.

## H. Combat and effects

- [ ] Gunfire under movement.
- [ ] Muzzle flashes.
- [ ] Smoke.
- [ ] Fire.
- [ ] Explosions.
- [ ] Blood/impact particles.
- [ ] Mutant/NPC movement.
- [ ] Fast turning during combat.
- [ ] No major ghosting or disocclusion trails.
- [ ] Combat followed by inventory/PDA open/close remains stable.

## I. Stability soak

- [ ] Play at least 30 minutes on Quality without device loss/crash.
- [ ] Play at least 15 minutes on Balanced.
- [ ] Play at least 15 minutes on Performance.
- [ ] Multiple save/load cycles during soak.
- [ ] At least two level transitions during Quality soak.
- [ ] No progressive visual corruption.
- [ ] No runaway VRAM/RAM symptom observed.
- [ ] Frame pacing remains normal for the system.
- [ ] Alt-tab out/in at least three times without renderer corruption.

## J. External injector isolation

These tools are not part of OptiBridge, but they may hook the same DX11 presentation path.

- [ ] Normal gameplay tested with RTSS/Afterburner OSD closed.
- [ ] RTSS compatibility tested separately if desired.
- [ ] A crash seen only with an external overlay/injector is documented separately from core RC3 stability.
- [ ] OptiScaler overlay can be opened/closed repeatedly without crash.

## K. DX11 AVX parity

The corrected Action24 AVX CI build compiled successfully, but runtime parity remains a release gate.

- [ ] AVX package uses the same Action24 source/config defaults as non-AVX.
- [ ] AVX executable starts through the user's normal GAMMA launch path.
- [ ] Existing save loads.
- [ ] New game starts.
- [ ] ADS/2D scope/3D scope smoke test passes.
- [ ] Quality `0.90` reports the expected 2304x972 input at 2560x1080 output.
- [ ] No AVX-only crash or visual regression.

## Release blockers

Any of the following blocks promotion beyond RC3:

- managed installer overwrites an unknown executable;
- backup/restore cannot reproduce the original executable hash;
- install/restore modifies `dxgi.dll` or `winmm.dll` unexpectedly;
- save/new-game crash reproducible without a third-party overlay injector;
- broken ADS/scope path;
- UI rendered at low resolution or misaligned;
- whole-screen jitter/wobble;
- persistent hard-geometry ghosting;
- severe foliage stipple/noise or alpha over-thickening;
- repeatable shader compile failure;
- repeatable crash during level transition;
- progressive memory/resource corruption during soak;
- AVX-only regression if AVX is included in the release package.
