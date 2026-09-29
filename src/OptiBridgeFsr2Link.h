#pragma once

// Stage 2 link/export probe.
//
// This deliberately does NOT dispatch FSR2 yet. Its purpose is to force the
// FSR2 2.2.1 core + DX11 backend into the final Anomaly executable so CI can
// verify the ffxFsr2... entry points OptiScaler's DX11 input hook expects.

#include "ffx_fsr2.h"
#include "dx11/ffx_fsr2_dx11.h"

inline void OptiBridgeFsr2LinkProbe()
{
    static bool probed = false;
    if (probed)
        return;

    probed = true;
    const size_t scratchBytes = ffxFsr2GetScratchMemorySizeDX11();
    const int32_t phaseCount = ffxFsr2GetJitterPhaseCount(1280, 1920);
    Msg("* [OptiBridge] FSR2 2.2.1 DX11 linked (scratch=%llu bytes, jitter phases=%d)",
        static_cast<unsigned long long>(scratchBytes), static_cast<int>(phaseCount));
}