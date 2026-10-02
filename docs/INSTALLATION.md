# OptiBridge v0.5.0-rc3 installation and restore

RC3 now has a managed DX11 installation path designed to avoid overwriting an unknown GAMMA executable or unrelated injector files.

## Supported clean baseline

The installer currently accepts this validated non-AVX `AnomalyDX11.exe` baseline:

```text
d5ba2ed3307361af305270bb22f8aff1be96b3a8e8c7fad4c4cce402ff80078
```

The validated corrected Action24 RC3 executable is:

```text
21b93e59853aad1f2c9e469876bd5126e0b1a0ece279cba445a597d674a68b54
```

An unknown executable hash is a hard stop. The installer does not guess that a different Modded Exes build is compatible.

## Install behavior

`install-rc3.ps1`:

1. locates the selected GAMMA/Anomaly `bin` folder;
2. verifies the package payload SHA-256;
3. verifies the current `AnomalyDX11.exe` SHA-256;
4. creates a timestamped backup under `bin\OptiBridge_Backups\` before replacing a clean supported baseline;
5. preserves any existing `optibridge.ini`, OptiBridge preset switcher and OptiBridge preset directory in that backup;
6. installs the selected preset, defaulting to Quality `0.90`;
7. verifies the installed executable SHA-256;
8. verifies that `dxgi.dll` and `winmm.dll`, when present, are byte-for-byte unchanged;
9. writes `.optibridge-install.json` so a later restore knows exactly which backup belongs to the managed install.

The installer intentionally does not install, replace or delete ReShade or OptiScaler proxy DLLs.

## Restore behavior

`uninstall-rc3.ps1` requires the managed-install manifest and the original backup. It verifies the backup hash before restoring it.

It also refuses to overwrite the current executable if somebody has replaced RC3 with a different executable since installation. This prevents an old restore script from silently destroying a newer/manual Modded Exes build.

The timestamped backup is retained after restore.

## Verification

`verify-rc3.ps1` checks:

- the RC3 executable hash;
- the required shared temporal/flora configuration values;
- the active `RenderScale`;
- whether the managed manifest exists;
- presence of `dxgi.dll` and `winmm.dll` without modifying them;
- `r__tf_mipbias` from `appdata\user.ltx` when available.

RC3 validation expects:

```text
r__tf_mipbias 0
```

## Presets

All four validated presets use the same corrected Action24 renderer binary and shared temporal/flora settings. Only `RenderScale` changes:

| Preset | RenderScale | 2560x1080 validation input |
| --- | ---: | ---: |
| Native | 1.00 | 2560x1080 |
| Quality | 0.90 | 2304x972 |
| Balanced | 0.85 | 2176x918 |
| Performance | 0.75 | 1920x810 |

Use `APPLY_OPTIBRIDGE_PRESET.cmd` to copy a preset into `optibridge.ini`, then fully exit and relaunch GAMMA through MO2.

## Scope

This managed installer is currently for the validated non-AVX DX11 binary only. AVX packaging/runtime parity remains a separate release gate even though the corrected Action24 AVX CI build compiled successfully.
