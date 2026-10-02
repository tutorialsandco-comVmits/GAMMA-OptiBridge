# Build status

## RC3 renderer build

Corrected Action24 was built successfully for both supported DX11 targets from commit:

```text
95cc26b66cfec7f0efbae72a8b3069df7469d304
```

GitHub Actions run:

```text
36957013701
```

Both jobs completed successfully:

- `MT Action24 DX11`
- `MT Action24 DX11-AVX`

The workflow completed the full Action patch chain through Action24, source-interception marker checks, executable build, staging and OptiScaler export checks.

## Validated non-AVX binary

```text
AnomalyDX11.exe
SHA-256: 21b93e59853aad1f2c9e469876bd5126e0b1a0ece279cba445a597d674a68b54
```

This is the binary used for the RC3 Native/Quality/Balanced/Performance visual and performance validation.

## AVX binary

```text
AnomalyDX11AVX.exe
SHA-256: d0404a340c62a84309b1c32623206996961ada58d47a88a0dde002060a2424b3
```

The AVX binary compiled successfully from the same corrected Action24 source path, but runtime parity is still pending. CI success is not being treated as proof of runtime parity.

## Baseline reference

The validated clean non-AVX Modded Exes baseline used by the managed installer allowlist is:

```text
d5ba2ed3307361af305270bb22f8aff1be96b3a8e8c7fad4c4cce402ff80078
```

Unknown executable hashes remain unsupported until explicitly validated.
