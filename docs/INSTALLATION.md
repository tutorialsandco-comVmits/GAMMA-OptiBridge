# OptiBridge installation

> [!WARNING]
> **Abandoned / unmaintained experimental project.** The code was almost entirely generated with OpenAI GPT-5.6 Sol under user direction/testing and has not received independent professional code or security review.

For a complete from-zero tutorial, including the required Modded Exes build, OptiScaler, DLSS DLL, ReShade coexistence, presets, verification, troubleshooting and uninstall steps, use:

## **[FULL INSTALLATION TUTORIAL](FULL_INSTALLATION_TUTORIAL.md)**

That document is the canonical installation guide for the archived RC3 release.

## Required stack

The validated development stack was:

```text
S.T.A.L.K.E.R. GAMMA / Anomaly
Modded Exes MT-TEST 2026.7.22
OptiBridge v0.5.0-rc3 corrected Action24
OptiScaler 0.9.4-final
DLSS Super Resolution 310.9.1
DirectX 11
```

### Modded Exes MT-TEST 2026.7.22

Official release:

https://github.com/themrdemonized/xray-monolith/releases/tag/2026.7.22

Direct archive:

https://github.com/themrdemonized/xray-monolith/releases/download/2026.7.22/STALKER-Anomaly-modded-exes-MT-TEST_2026.7.22.zip

Expected archive SHA-256:

```text
18823c9c0e050384f8a1aba079dc9bc7264abb69aae5a7c023f54f80f5d3cd9a
```

### Final OptiBridge package

Release page:

https://github.com/tutorialsandco-comVmits/GAMMA-OptiBridge/releases/tag/v0.5.0-rc3-abandoned

Direct archive:

https://github.com/tutorialsandco-comVmits/GAMMA-OptiBridge/releases/download/v0.5.0-rc3-abandoned/GAMMA_OptiBridge_v0.5.0-rc3_abandoned.zip

Expected archive SHA-256:

```text
655df4a97d0537ffd7d84ce7af1871ac5712adc152894e0ff54ed4e708a241e4
```

Validated non-AVX OptiBridge executable:

```text
AnomalyDX11.exe
SHA-256: 21b93e59853aad1f2c9e469876bd5126e0b1a0ece279cba445a597d674a68b54
```

> [!IMPORTANT]
> GitHub's green **Code -> Download ZIP** button downloads source code only. Use the **Release asset** above if you want the compiled OptiBridge executable.

## Install / uninstall

The final archive contains:

```text
INSTALL_OPTIBRIDGE.cmd
UNINSTALL_OPTIBRIDGE.cmd
APPLY_OPTIBRIDGE_PRESET.cmd
```

The final archived installer backs up the current executable/config state before installing RC3. The corresponding uninstaller restores that backup.

OptiScaler is intentionally **not redistributed** inside the OptiBridge archive and must be installed separately. The complete tutorial explains the exact `winmm.dll` configuration used to coexist with GAMMA/ReShade.

## Presets

| Preset | RenderScale | Input at 2560x1080 |
| --- | ---: | ---: |
| Native | 1.00 | 2560x1080 |
| Quality | 0.90 | 2304x972 |
| Balanced | 0.85 | 2176x918 |
| Performance | 0.75 | 1920x810 |

Quality `0.90` is the archived default.

RC3 validation expects:

```text
r__tf_mipbias 0
```

## Recovery

For deeper/manual recovery instructions, see:

**[UNINSTALL_AND_RESTORE.md](UNINSTALL_AND_RESTORE.md)**

The AVX OptiBridge executable is deliberately excluded from the final package because runtime parity validation was not completed before abandonment.