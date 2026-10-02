# Uninstall OptiBridge and restore pre-project GAMMA

This document describes how to return a GAMMA / Anomaly installation to the state it had before OptiBridge was installed.

## Important distinction

Replacing `optibridge.ini` or setting `NativeSceneScale=0` is **not** a complete uninstall. The OptiBridge test executables contain project code and FSR2 exports.

A complete restore requires:

1. restoring the original Modded Exes executables;
2. removing OptiBridge-specific config/preset/helper files;
3. removing the OptiScaler injection that was installed only for OptiBridge;
4. preserving unrelated files such as ReShade's `dxgi.dll`.

## Original Modded Exes source used before the project

The project targeted the official MT-TEST 2026.7.22 release family from:

`themrdemonized/xray-monolith`

Official release asset:

```text
STALKER-Anomaly-modded-exes-MT-TEST_2026.7.22.zip
SHA-256: 18823c9c0e050384f8a1aba079dc9bc7264abb69aae5a7c023f54f80f5d3cd9a
```

Release page:

`https://github.com/themrdemonized/xray-monolith/releases/tag/2026.7.22`

Use that archive (or the exact original executable backup made before OptiBridge) to restore `AnomalyDX11.exe` and `AnomalyDX11AVX.exe`.

### Do not use the OptiBridge MT baseline as a clean uninstall image

The project artifact commonly referred to as the MT baseline has:

```text
AnomalyDX11.exe
SHA-256: d5ba2ed3307361af305270bb22f8aff1be96b3a8e8c7fad4c4cce402ff80078a
```

That binary still contains early OptiBridge integration (Action15/Action16). It is a useful project baseline but **not a true pre-project executable**.

## Project files that can be removed

After the original executable(s) are restored, remove these if present and if they were created by this project:

```text
Anomaly\bin\optibridge.ini
Anomaly\bin\OptiBridge_Presets\
Anomaly\bin\APPLY_OPTIBRIDGE_PRESET.cmd
Anomaly\bin\.optibridge-install.json
Anomaly\bin\INSTALL_OPTIBRIDGE.cmd
Anomaly\bin\INSTALL_OPTIBRIDGE.ps1
Anomaly\bin\UNINSTALL_OPTIBRIDGE.cmd
Anomaly\bin\UNINSTALL_OPTIBRIDGE.ps1
Anomaly\bin\VERIFY_OPTIBRIDGE.cmd
Anomaly\bin\VERIFY_OPTIBRIDGE.ps1
```

`OptiBridge_Backups` may be retained until the restored game is confirmed working, then removed manually if no longer needed.

## Remove OptiScaler

For the tested setup, OptiScaler was installed through `winmm.dll` specifically so ReShade's existing `dxgi.dll` would remain untouched.

Preferred removal method:

1. Run the OptiScaler-provided `Remove OptiScaler.bat` from the game folder if it is still present.
2. Verify that the OptiScaler proxy is gone.
3. Remove upscaler binaries that were manually added only for this project and which OptiScaler's remover intentionally leaves behind.

The OptiScaler project documents `Remove OptiScaler.bat` as its normal automatic uninstall method. Its manual instructions say to remove the renamed OptiScaler DLL and `OptiScaler.ini`, plus related OptiScaler/FakeNVAPI components where applicable.

### Tested OptiBridge setup-specific files

The project setup used:

```text
winmm.dll        <- OptiScaler proxy
nvngx_dlss.dll   <- manually added DLSS library for OptiScaler
```

If those files were added specifically during OptiBridge setup, remove them when returning to the pre-project state.

**Do not delete `dxgi.dll`.** In the reference GAMMA installation it belongs to ReShade and was intentionally never used as the OptiScaler proxy.

If you are unsure whether a DLL existed before OptiBridge, do not delete it blindly. Back it up first or inspect its file metadata. The OptiScaler proxy normally reports `OptiScaler.dll` as its original filename.

## Recommended restore procedure

1. Fully exit GAMMA, MO2, RTSS, MSI Afterburner and any overlay/injector that may have the executable loaded.
2. Copy the entire current `Anomaly\bin` folder to a temporary backup location.
3. Download the official MT-TEST 2026.7.22 archive and verify its SHA-256 against the value above.
4. Restore `AnomalyDX11.exe` and `AnomalyDX11AVX.exe` from the official archive (or use your own known pre-project backups).
5. Remove the OptiBridge-specific files listed above.
6. Run `Remove OptiScaler.bat` if present.
7. Remove `nvngx_dlss.dll` if it was added only for OptiBridge.
8. Confirm the ReShade `dxgi.dll` is still present and unchanged.
9. Launch GAMMA normally through MO2 using the restored Modded Exes executable.
10. Confirm the OptiScaler overlay no longer appears and that there are no `[OptiBridge]` lines in the X-Ray log.

## Shader cache

OptiBridge itself does not require a shader-cache deletion merely to uninstall. If you are simultaneously reinstalling/replacing broader shader or visual packages, follow the Modded Exes/GAMMA instructions for those changes separately.

## Lossless Scaling after removal

Lossless Scaling is external to the GAMMA executable and does not require OptiBridge or OptiScaler. After the original executable is restored and the OptiScaler hook is removed, Lossless Scaling can be used on native GAMMA independently.

## Final verification

A clean post-OptiBridge run should have all of the following:

- original Modded Exes DX11/AVX executable(s) restored;
- no `optibridge.ini`;
- no `OptiBridge_Presets` folder;
- no OptiScaler overlay when GAMMA starts;
- no `[OptiBridge]` log lines;
- ReShade still works through its existing `dxgi.dll` if it was installed before the project;
- Lossless Scaling can be enabled independently outside the game.