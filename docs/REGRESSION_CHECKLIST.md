# OptiBridge v0.5.0-rc1 Regression Checklist

Use `config/optibridge-quality.ini` unchanged for this pass. Change one variable only when a test explicitly calls for it.

## Test rules

- Launch GAMMA normally through MO2.
- DX11, MSAA off, Lossless Scaling off.
- Keep OptiScaler on the same backend/settings used for the validated Action23 test.
- Do not clear shader caches unless a specific failure gives evidence that the cache is stale.
- Record direct in-game observations first; video is secondary evidence for subtle temporal artifacts.
- If a regression appears, save the log and identify the exact test before changing any settings.

## A. Startup and save integrity

- [ ] Main menu loads normally.
- [ ] Existing old save loads without crash.
- [ ] Recent save loads without crash.
- [ ] New game starts successfully.
- [ ] Save game works.
- [ ] Reloading the new save works.
- [ ] Level transition works.

## B. UI and HUD

- [ ] HUD remains native-resolution and correctly aligned.
- [ ] Inventory/PDA renders correctly.
- [ ] Map renders correctly.
- [ ] Dialogue/trade UI renders correctly.
- [ ] Pause/menu overlays render correctly.
- [ ] Notifications/subtitles are sharp and correctly positioned.

## C. Weapons and scopes

- [ ] Hip-fire rendering normal.
- [ ] Iron sights normal.
- [ ] ADS transition normal.
- [ ] 2D scope normal.
- [ ] 3D scope / PiP scope normal if installed.
- [ ] Scope entry/exit has no resize, jitter or stale-frame artifact.
- [ ] Muzzle flash normal.
- [ ] Weapon motion does not leave obvious temporal trails.

## D. Outdoor image stability

- [ ] Stationary hard geometry stable.
- [ ] Slow camera pan stable.
- [ ] Fine fences/wires stable.
- [ ] Distant tree trunks/branches stable.
- [ ] Fine leaves/twigs show no major shimmer regression.
- [ ] Action23 hashed coverage shows no visible stipple or screen-fixed noise.
- [ ] Foliage is not visibly over-thickened.
- [ ] Grass is acceptable at walking speed.
- [ ] Distant terrain/roof edges are acceptable.

## E. Weather and lighting

- [ ] Clear daytime.
- [ ] Overcast.
- [ ] Rain/wet surfaces.
- [ ] Fog/heavy atmosphere.
- [ ] Dawn/dusk.
- [ ] Night.
- [ ] Dynamic lights/flashlight.
- [ ] Lightning or bright transient lighting if available.

## F. Interiors and transitions

- [ ] Dark interior.
- [ ] Bright interior.
- [ ] Doorway/window high-contrast transitions.
- [ ] Moving from interior to exterior.
- [ ] Moving from exterior to interior.
- [ ] No exposure-related temporal instability attributable to OptiBridge.

## G. Combat and effects

- [ ] Gunfire under movement.
- [ ] Muzzle flashes.
- [ ] Smoke.
- [ ] Fire.
- [ ] Explosions.
- [ ] Blood/impact particles.
- [ ] Mutant/NPC movement.
- [ ] Fast turning during combat.
- [ ] No major ghosting or disocclusion trails.

## H. Performance/stability soak

- [ ] Play at least 30 minutes without device loss/crash.
- [ ] Multiple save/load cycles.
- [ ] At least one level transition.
- [ ] No progressive visual corruption.
- [ ] No runaway VRAM/RAM symptom observed.
- [ ] Frame pacing remains normal for the system.

## I. Performance capture

Capture the same scene and camera position for each case. Record average FPS plus GPU utilization if available.

- [ ] Native reference: `RenderScale=1.00`.
- [ ] Quality checkpoint: `RenderScale=0.85`.
- [ ] Experimental lower scale: `RenderScale=0.75` only after the RC quality pass is clean.

Do not change `JitterScale`, flora settings, OptiScaler backend, graphics settings, weather, or camera position while comparing render scales.

## Release blockers

Any of the following blocks RC promotion:

- save/new-game crash;
- broken ADS/scope path;
- UI rendered at low resolution or misaligned;
- whole-screen jitter/wobble;
- persistent geometry ghosting;
- severe foliage stipple/noise introduced by Action23;
- repeatable shader compile failure;
- repeatable crash during level transition;
- material performance regression relative to Action23 at the same settings.
