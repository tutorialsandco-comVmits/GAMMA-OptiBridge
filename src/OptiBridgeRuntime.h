#pragma once

class CRenderTarget;

// Returns true when optibridge.ini enables the experimental bridge.
bool OptiBridge_Enabled();

// Returns the FSR2 jitter as an NDC offset for the existing SSFX vertex path.
// False means the stock SSFX jitter path should be used.
bool OptiBridge_GetJitterNdc(float& x, float& y);

// Replaces the stock SSFX TAA resolve when enabled. Returns true only when
// the temporal dispatch completed and rt_Generic_0 now contains the result.
bool OptiBridge_Dispatch(CRenderTarget* target);