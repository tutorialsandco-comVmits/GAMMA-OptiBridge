# GAMMA OptiBridge

Experimental DirectX 11 temporal-upscaling bridge for **S.T.A.L.K.E.R. Anomaly / GAMMA**.

## Locked target

This repository currently targets:

- X-Ray Monolith / Modded Exes **2026.7.22**
- upstream tag: `2026.7.22`
- DirectX 11: `AnomalyDX11.exe`
- DirectX 11 AVX: `AnomalyDX11AVX.exe`
- FidelityFX FSR 2.2.1 DX11 interface
- OptiScaler DX11 FSR2 input interception
- NVIDIA RTX target: DLSS through OptiScaler
- Existing ReShade `dxgi.dll` is intentionally left untouched

## Architecture

```text
X-Ray R4 renderer
  -> scene colour
  -> depth
  -> SSFX motion vectors
  -> temporal jitter
  -> FSR2 DX11 API exported by AnomalyDX11.exe
  -> OptiScaler intercepts the FSR2 dispatch
  -> DLSS / XeSS / FSR backend
  -> X-Ray post-processing / presentation
```

OptiScaler's DX11 FSR2 input path searches for exported `ffxFsr2...` functions in the game executable. The build therefore links the DX11 FSR2 API directly into the executable and exports those entry points.

## Status

**Development alpha. Do not install into a live GAMMA setup unless a release artifact is explicitly marked installable.**

The GitHub Actions workflow builds against the exact 2026.7.22 upstream source and packages only the DX11 and DX11-AVX executables.

The first validation milestone is a native-resolution temporal path. Reduced internal rendering resolution is enabled only after the temporal inputs and resource formats are verified in-game; this avoids shipping a fake or unsafe "upscaler" that merely stretches the final image.

## Safety

The eventual installer must:

1. verify the user's original executable hash,
2. back up the original executable,
3. preserve the existing ReShade `dxgi.dll`,
4. install OptiScaler through a non-conflicting proxy,
5. provide an uninstall/restore path.

## Upstream projects

- xray-monolith / Modded Exes: https://github.com/themrdemonized/xray-monolith
- OptiScaler: https://github.com/optiscaler/OptiScaler
- FSR2 DX11 fork used by OptiScaler: https://github.com/optiscaler/FidelityFX-FSR2-DX11

This project is not affiliated with the GAMMA, Anomaly, OptiScaler, AMD, NVIDIA, or xray-monolith maintainers.
