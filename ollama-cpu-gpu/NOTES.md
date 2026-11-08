# Force Ollama onto the CPU or the GPU (tested 2026-11-09)

Article: https://markaicode.com/switch-cpu-gpu-inference-ollama/

- `run-tests.ps1` runs all three 2026-11-09 tests (CPU/GPU, PATH, cache). Part 1 is the CPU/GPU test; its log is `part1-cpu-gpu.log`.
- `run-followup.ps1` adds tests E–G (hide CUDA and Vulkan, `OLLAMA_LLM_LIBRARY=cpu`, Modelfile `num_gpu 0`); log `part4-followup.log`.
- Both use a temporary second Ollama server on port 11500. Ollama 0.40.15, RTX 2060 SUPER 8 GB, models phi4-mini and gemma4:e4b.

Main finding: `CUDA_VISIBLE_DEVICES=-1` on its own did not force the CPU. Ollama fell back to Vulkan and stayed on the GPU.
Hiding both CUDA and Vulkan, `OLLAMA_LLM_LIBRARY=cpu`, or `num_gpu 0` did force the CPU.
