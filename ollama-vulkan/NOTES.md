# Ollama on Vulkan, discrete and integrated GPUs (tested 2026-11-13 and 2026-11-14)

Article: https://markaicode.com/intel-arc-gpu-ollama-openvino-tutorial/

- `run-ollama-vulkan-check.ps1` and `run-ollama-vulkan-igpu.ps1` start a separate, temporary Ollama server on 127.0.0.1:11435 with different GPU settings, run one short prompt on phi4-mini (temperature 0, up to 160 tokens), record speed and GPU memory use, and stop it. The normal server on 11434 is not touched. Nothing is downloaded or deleted.
- Logs: `ollama-vulkan-check.log` (settings A-D) and `ollama-vulkan-igpu.log` (E-F). Windows 11 Pro (build 26300), Ollama 0.40.15, NVIDIA GeForce RTX 2060 SUPER 8 GB, AMD Radeon 780M (integrated), Ryzen 7 8700G, 31 GB RAM.

| Setting | tokens/s | Device used |
|---|---|---|
| A default (CUDA) | 98.2 | RTX 2060 SUPER (CUDA) |
| B Vulkan only (CUDA/ROCm hidden) | 101.6 | RTX 2060 SUPER (Vulkan) |
| C Vulkan, iGPU only, no iGPU switch | 23.4 | CPU (iGPU dropped) |
| D CPU only | 22.5 | CPU |
| E Vulkan, iGPU only, OLLAMA_IGPU_ENABLE=1 | 21.2 | Radeon 780M |
| F Vulkan, both GPUs, OLLAMA_IGPU_ENABLE=1 | 21.2 | Radeon 780M (chosen over the RTX) |

Findings:
- Ollama 0.40.15 ships `cuda_v12`, `cuda_v13`, `rocm_v7_1` and `vulkan` backends.
- Ollama drops integrated GPUs by default: "dropping integrated GPU; to enable, set OLLAMA_IGPU_ENABLE=1".
- With the switch on and both GPUs visible, Ollama chose the iGPU (15.8 GiB shared memory), raised the context to 32,768 tokens (predicted 6.3 GiB) and ran at 21.2 tokens/s instead of about 100. Pin a GPU with `GGML_VK_VISIBLE_DEVICES`.
- No Intel Arc card was available; this tests the same Vulkan path that Ollama uses for Arc.
