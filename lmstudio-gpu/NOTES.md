# LM Studio GPU detection (tested 2026-11-11)

Article: https://markaicode.com/errors/lm-studio-gpu-not-detected-fix/

- `run-lmstudio-gpu-check.ps1` and `run-lmstudio-gpu-check-2.ps1` are read-only: they list and survey, and do not download, load, unload or delete models or runtimes, or change settings. Model names are never logged.
- `lmstudio-gpu-check.log` and `lmstudio-gpu-check-2.log` are the raw output. Windows 11 Pro (build 26300), LM Studio 0.4.28 (per-user install), NVIDIA GeForce RTX 2060 SUPER 8 GB (driver 610.88) plus AMD Radeon 780M integrated graphics, Ryzen 7 8700G, 31 GB RAM.

Findings:
- `lms runtime survey` lists the GPUs the selected runtime can use. With the CUDA 12 runtime (llama.cpp-win-x86_64-nvidia-cuda12-avx2 2.72.0) it listed only the RTX 2060 SUPER (8.00 GiB), not the integrated Radeon 780M.
- `lms` was not on PATH even though LM Studio had been used; it was at `%USERPROFILE%\.lmstudio\bin\lms.exe`.
- No per-app Windows GPU preference was set for LM Studio, and the NVIDIA card was still found.
- `lms load --estimate-only` on a small embedding model gave the same 112.29 MiB for `--gpu max`, `0.5` and `off` (Confidence: LOW), so the estimate says nothing about offload for such models.
- The `RemoteException` lines in the second log are PowerShell 5.1 wrapping an empty stderr line from lms; they are not lms errors.
