# GAMMA OptiBridge — complete installation tutorial

> [!WARNING]
> **This project is abandoned and unmaintained.** It was almost entirely vibe-coded with OpenAI GPT-5.6 Sol by an owner with no programming background, and it has not received independent professional code or security review. Read `AI_GENERATION_DISCLOSURE.md` before relying on it.

This guide documents the **exact stack that was validated during development**. It is intentionally conservative: use the pinned versions first, confirm that the bridge works, and only then experiment with newer components.

## What OptiBridge actually is

OptiBridge is not a standalone DLSS mod. It is a patched X-Ray/Anomaly DX11 executable that:

1. renders the 3D scene below native resolution;
2. provides temporal jitter, depth and motion-vector information;
3. exposes an FSR2-compatible DX11 interface;
4. lets **OptiScaler** intercept that interface;
5. lets OptiScaler run DLSS / XeSS / FSR as the reconstruction backend;
6. keeps UI/presentation at native resolution.

The tested path was:

```text
GAMMA / Anomaly
  -> Modded Exes MT base
  -> OptiBridge AnomalyDX11.exe
  -> FSR2.X interface
  -> OptiScaler 0.9.4
  -> DLSS 310.9.1
  -> native-resolution presentation
```

---

# 1. Required downloads

## 1.1 Modded Exes MT-TEST 2026.7.22

OptiBridge was developed against **themrdemonized/xray-monolith MT-TEST 2026.7.22**.

Official release page:

https://github.com/themrdemonized/xray-monolith/releases/tag/2026.7.22

Direct MT-TEST archive:

https://github.com/themrdemonized/xray-monolith/releases/download/2026.7.22/STALKER-Anomaly-modded-exes-MT-TEST_2026.7.22.zip

Expected archive SHA-256:

```text
18823c9c0e050384f8a1aba079dc9bc7264abb69aae5a7c023f54f80f5d3cd9a
```

If your GAMMA setup already uses **Modded Exes MT-TEST 2026.7.22** — for example through the Eroktic setup used during development — you do not need to install it again.

> [!IMPORTANT]
> Do not substitute a different Modded Exes release for the first test. Newer or older engine builds were not validated with the archived RC3 binary.

## 1.2 OptiBridge v0.5.0-rc3 abandoned archive

Final GitHub release:

https://github.com/tutorialsandco-comVmits/GAMMA-OptiBridge/releases/tag/v0.5.0-rc3-abandoned

Direct package:

https://github.com/tutorialsandco-comVmits/GAMMA-OptiBridge/releases/download/v0.5.0-rc3-abandoned/GAMMA_OptiBridge_v0.5.0-rc3_abandoned.zip

Expected package SHA-256:

```text
655df4a97d0537ffd7d84ce7af1871ac5712adc152894e0ff54ed4e708a241e4
```

Validated OptiBridge executable SHA-256:

```text
AnomalyDX11.exe
21b93e59853aad1f2c9e469876bd5126e0b1a0ece279cba445a597d674a68b54
```

Use the **Release asset above**, not GitHub's green **Code -> Download ZIP** button. The green button downloads source code only and does not contain the compiled OptiBridge executable.

## 1.3 OptiScaler 0.9.4 stable

OptiScaler releases:

https://github.com/optiscaler/OptiScaler/releases

Validated version:

```text
OptiScaler 0.9.4-final
```

OptiScaler's official manual-install documentation:

https://github.com/optiscaler/OptiScaler/wiki/Manual-Installation

OptiScaler's official automated-install documentation:

https://github.com/optiscaler/OptiScaler/wiki/Automated-Installation

For reproducing the OptiBridge test environment, prefer **stable v0.9.4**, not a nightly build.

## 1.4 NVIDIA DLSS Super Resolution DLL

GAMMA does not normally ship DLSS, so OptiScaler needs an `nvngx_dlss.dll` if you want DLSS as the backend.

Validated development version:

```text
nvngx_dlss.dll
DLSS 310.9.1
```

OptiScaler's own manual-install guide recommends obtaining the DLSS DLL from a trusted source such as TechPowerUp or NVIDIA's Streamline SDK/releases.

TechPowerUp DLSS DLL page:

https://www.techpowerup.com/download/nvidia-dlss-dll/

NVIDIA Streamline repository/releases:

https://github.com/NVIDIA-RTX/Streamline/releases

A newer DLSS DLL may work, but it was not part of the final validated OptiBridge checkpoint. If troubleshooting, return to the validated 310.9.1 DLL first.

---

# 2. Before changing anything

Fully close:

- GAMMA / Anomaly;
- Mod Organizer 2;
- RTSS / RivaTuner Statistics Server;
- MSI Afterburner;
- Lossless Scaling;
- any other tool injecting into the game.

Back up your entire Anomaly `bin` folder before experimenting.

A typical path is similar to:

```text
C:\Anomaly\bin\
```

Your actual GAMMA path may differ.

The folder we care about is the one containing:

```text
AnomalyDX11.exe
```

---

# 3. Install the required Modded Exes base

Skip this section if your current installation already uses **MT-TEST 2026.7.22**.

1. Download `STALKER-Anomaly-modded-exes-MT-TEST_2026.7.22.zip` from the official release linked above.
2. Optionally verify its SHA-256:

```powershell
Get-FileHash .\STALKER-Anomaly-modded-exes-MT-TEST_2026.7.22.zip -Algorithm SHA256
```

3. Confirm the result is:

```text
18823c9c0e050384f8a1aba079dc9bc7264abb69aae5a7c023f54f80f5d3cd9a
```

4. Install the MT-TEST package into your Anomaly/GAMMA installation according to its upstream layout.
5. Confirm your `bin` folder contains the Modded Exes DX11 executables before proceeding.

OptiBridge's final release only replaces the validated **non-AVX `AnomalyDX11.exe`** path. The archived AVX OptiBridge build was never runtime-parity validated and is intentionally not distributed as the final package.

---

# 4. Install OptiBridge

1. Download the final OptiBridge release asset.
2. Extract it to a temporary folder.
3. Read `README_FIRST.txt` and the AI-generation disclosure.
4. Run:

```text
INSTALL_OPTIBRIDGE.cmd
```

5. When prompted, point it at the Anomaly `bin` directory containing `AnomalyDX11.exe`.

The final archived installer is designed to:

- back up the executable/config it finds before replacing them;
- install the exact validated RC3 `AnomalyDX11.exe`;
- install Quality `0.90` as the default OptiBridge preset;
- install the preset-switching files;
- leave unrelated proxy DLLs such as ReShade alone.

After installation you should have, among other files:

```text
AnomalyDX11.exe
optibridge.ini
APPLY_OPTIBRIDGE_PRESET.cmd
OptiBridge_Presets\
```

Do **not** launch the game yet. OptiScaler still needs to be installed.

---

# 5. Install OptiScaler for GAMMA

This is the GAMMA-specific part that differs from OptiScaler's generic instructions.

## 5.1 Extract OptiScaler beside AnomalyDX11.exe

Extract all files from **OptiScaler v0.9.4** into the same `bin` folder as:

```text
AnomalyDX11.exe
```

Keep:

```text
OptiScaler.ini
```

with exactly that filename.

## 5.2 Use `winmm.dll`, not `dxgi.dll`

OptiScaler supports several proxy filenames, including `dxgi.dll` and `winmm.dll`.

For the GAMMA configuration used during OptiBridge development, **ReShade already owns `dxgi.dll`**.

Therefore:

```text
OptiScaler.dll
      ↓ rename
winmm.dll
```

Do **not** replace the existing ReShade `dxgi.dll` with OptiScaler.

The expected arrangement is:

```text
AnomalyDX11.exe       <- OptiBridge RC3
optibridge.ini

winmm.dll             <- OptiScaler.dll renamed to winmm.dll
OptiScaler.ini
nvngx_dlss.dll        <- DLSS Super Resolution

dxgi.dll              <- existing ReShade proxy; leave it alone
```

If you do not use ReShade, other OptiScaler proxy names may work, but `winmm.dll` is the configuration that was actually validated for this project.

## 5.3 Install the DLSS DLL

Place:

```text
nvngx_dlss.dll
```

beside `AnomalyDX11.exe` / `winmm.dll`.

For the closest reproduction of the validated environment, use DLSS **310.9.1**.

Do not rename `nvngx_dlss.dll`.

---

# 6. First launch

Before launching:

```text
Lossless Scaling: OFF
RTSS:             OFF for the first validation launch
MSAA:             OFF
```

The development environment used DX11 and did not combine OptiBridge with Lossless Scaling.

Launch GAMMA normally through **MO2**, using the non-AVX DX11 executable path that resolves to the installed OptiBridge `AnomalyDX11.exe`.

Do not open `AnomalyDX11.exe` directly outside your normal GAMMA/MO2 workflow unless your installation is specifically designed that way.

---

# 7. Configure OptiScaler

In game, press:

```text
Insert
```

to open the OptiScaler overlay.

If `Insert` immediately closes or does not display correctly, OptiScaler's documentation suggests trying:

```text
Alt + Insert
```

For the NVIDIA / RTX configuration validated during development, use:

```text
API:                  D3D11
Upscaler backend:     DLSS
Input:                FSR2.X
Spoof:                Off
Frame Generation:     Off
Auto Exposure:        On
```

The overlay should identify the DLSS DLL, for example:

```text
D3D11 | DLSS 310.9.1 | Input: FSR2.X | Spoof: Off
```

## Reactive-mask option being disabled is expected

OptiScaler may show the Reactive Mask control as disabled/greyed out and say the game does not provide a Reactive mask.

For OptiBridge RC3, that is expected. OptiBridge's foliage path creates/passes its own programmatic reactive information internally; you do not need to force-enable the OptiScaler UI option.

---

# 8. Select an OptiBridge preset

The release contains four validated presets.

Run:

```text
APPLY_OPTIBRIDGE_PRESET.cmd
```

and choose:

```text
1. Native       RenderScale 1.00
2. Quality      RenderScale 0.90
3. Balanced     RenderScale 0.85
4. Performance  RenderScale 0.75
```

Fully exit and relaunch GAMMA after switching presets.

At an output resolution of **2560x1080**, the expected internal resolutions are:

| Preset | RenderScale | Expected OptiScaler input |
| --- | ---: | ---: |
| Native | 1.00 | 2560x1080 |
| Quality | 0.90 | 2304x972 |
| Balanced | 0.85 | 2176x918 |
| Performance | 0.75 | 1920x810 |

Quality `0.90` is the archived default.

---

# 9. Required GAMMA setting

The final RC3 validation used:

```text
r__tf_mipbias 0
```

Set that in the GAMMA/X-Ray console if necessary.

Do not use a global positive mip bias as part of the normal RC3 configuration. The final Action24 renderer uses a targeted foliage-alpha mip bias internally instead.

---

# 10. Verify that OptiBridge is really working

Do not judge the installation only by whether the game launches.

## 10.1 Check the OptiScaler overlay

For Quality at 2560x1080, it should report approximately:

```text
2304x972 -> 2560x1080
```

Balanced should show:

```text
2176x918 -> 2560x1080
```

Performance should show:

```text
1920x810 -> 2560x1080
```

If the input remains 2560x1080 while Quality/Balanced/Performance is selected, native scene scaling is not active as intended.

## 10.2 Check the X-Ray log

The X-Ray log should contain OptiBridge initialization/config lines.

If there are no `[OptiBridge]` entries at all, you may be launching a different executable than the one the installer replaced.

## 10.3 Smoke-test gameplay

Before committing to a playthrough, test:

1. main menu;
2. an existing save;
3. a new game;
4. walking/running;
5. combat;
6. ADS;
7. normal scopes;
8. 3D/PiP scopes if installed;
9. PDA/inventory/UI;
10. save -> exit -> reload;
11. at least one map transition;
12. bright-sky foliage, where temporal instability is easiest to see.

---

# 11. Optional OptiScaler performance overlay

OptiScaler's current documentation uses:

```text
Page Up
```

to show its performance stats overlay.

`Page Down` cycles display modes.

This can be useful for comparing presets without installing RTSS.

---

# 12. Troubleshooting

## Game crashes before reaching the menu

First close all third-party overlays/injectors:

- RTSS;
- MSI Afterburner OSD;
- Discord overlay;
- GeForce overlay;
- other hook/injection tools.

During OptiBridge development, RTSS/Afterburner injection appeared capable of causing an abrupt process exit in at least one configuration, with no normal X-Ray fatal block.

Then retry with only:

```text
GAMMA + ReShade + OptiBridge + OptiScaler
```

## OptiScaler overlay does not open

Try:

```text
Insert
```

then:

```text
Alt + Insert
```

Confirm `winmm.dll` is in the same folder as `AnomalyDX11.exe`.

Confirm `OptiScaler.ini` was not renamed.

## DLSS is not listed

Confirm:

```text
nvngx_dlss.dll
```

is beside the executable.

If you are troubleshooting version compatibility, use the validated DLSS 310.9.1 DLL before testing newer versions.

## OptiScaler says the input is not FSR2.X

You are probably not running the OptiBridge executable, or OptiScaler did not intercept the exported FSR2 path.

Verify the installed `AnomalyDX11.exe` SHA-256:

```powershell
Get-FileHash .\AnomalyDX11.exe -Algorithm SHA256
```

Expected:

```text
21b93e59853aad1f2c9e469876bd5126e0b1a0ece279cba445a597d674a68b54
```

## ReShade stopped working

Check whether your original `dxgi.dll` was overwritten.

For the validated configuration:

```text
dxgi.dll  = ReShade
winmm.dll = OptiScaler
```

Do not use OptiScaler as `dxgi.dll` if ReShade already occupies that filename.

## Image is shimmering / fine foliage looks unstable

Verify:

```text
r__tf_mipbias 0
FloraHashedCoverage=0
FloraAlphaWidthScale=0.10
FloraAlphaMipBias=0.25
JitterScale=0.35
```

Those are the final accepted RC3 settings.

Very fine foliage and distant geometry still lose quality below native resolution. This is a known limitation and one of the reasons development stopped.

## Performance barely improves at lower RenderScale

Check GPU utilization. If the GPU is no longer heavily loaded while FPS stops increasing, the game may have become CPU-bound.

## Lossless Scaling is also enabled

Disable it while testing OptiBridge. Combining both makes performance/latency/image-quality diagnosis ambiguous and was not part of the validated configuration.

---

# 13. Updating OptiScaler or DLSS

The archived reproducible baseline is:

```text
OptiScaler 0.9.4-final
DLSS       310.9.1
```

Newer versions may work, but treat each update as a separate experiment.

If something breaks after an update:

1. restore OptiScaler 0.9.4 stable;
2. restore DLSS 310.9.1;
3. keep the same OptiBridge executable/config;
4. retest before changing anything else.

---

# 14. Uninstall OptiBridge

Run:

```text
UNINSTALL_OPTIBRIDGE.cmd
```

from the final release package.

The archived final installer/uninstaller uses the backup it created during installation to restore the previous executable/config state.

Keep its backup until you have confirmed that your original GAMMA setup works normally again.

For the deeper/manual recovery procedure, see:

`UNINSTALL_AND_RESTORE.md`

---

# 15. Remove OptiScaler separately

OptiBridge's own uninstaller does not pretend to own unrelated OptiScaler/ReShade files.

Use OptiScaler's own removal utility if present, or follow the official OptiScaler uninstall instructions.

For the configuration described in this guide, the OptiScaler proxy is:

```text
winmm.dll
```

Do **not** delete `dxgi.dll` if it belongs to ReShade.

If you manually added `nvngx_dlss.dll` only for OptiBridge/OptiScaler and no other mod needs it, it can also be removed after you have backed it up.

---

# 16. Known-good reference configuration

The final project-owner test system was:

```text
GPU:        NVIDIA RTX 3060
CPU:        Intel i7-6700K
Resolution: 2560x1080
API:        DirectX 11
OptiScaler: 0.9.4-final
DLSS:       310.9.1
Input:      FSR2.X
Proxy:      winmm.dll
ReShade:    dxgi.dll
FG:         Off
Lossless Scaling: Off during OptiBridge testing
r__tf_mipbias: 0
```

Final Quality preset:

```ini
[OptiBridge]
Enabled=1
Jitter=1
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

---

# 17. Important final warning

A successful installation does not mean the project is production-ready.

This repository is an abandoned experimental renderer investigation. If you are an experienced X-Ray/DirectX developer interested in continuing it, start with:

- `PROJECT_HANDOFF.md`
- `AI_GENERATION_DISCLOSURE.md`
- `REGRESSION_CHECKLIST.md`
- the `mt-action17-*` through `mt-action24-*` branches

The final accepted renderer path is **Action24 / v0.5.0-rc3**. Action23 hashed foliage coverage was deliberately rejected and should not be restored as a default.