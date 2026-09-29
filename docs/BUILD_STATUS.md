# Build status

The first CI milestone is intentionally conservative:

1. clone the exact upstream `2026.7.22` tag;
2. initialize the same submodules upstream expects;
3. compile only `DX11` and `DX11-AVX`;
4. upload the resulting executables and SHA-256 hashes.

No renderer patch is applied during this baseline job.

Once the baseline is green, the OptiBridge patch will be layered on top and a second build job will compare the patched result against the baseline. This keeps build-environment failures separate from renderer-integration failures.