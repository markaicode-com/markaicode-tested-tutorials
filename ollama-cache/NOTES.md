# Ollama model cache and disk space (tested 2026-11-09)

Article: https://markaicode.com/clear-ollama-model-cache-storage-guide/

- `run-tests.ps1` part 3 inspects the models folder, lists `ollama --help`, then copies phi4-mini to a temporary name and removes only that copy; log `part3-cache.log`.
- Findings: Ollama 0.40.15 has no `ollama prune` command; `ollama cp` added one small blob file and no measurable space (41.732 GB before and after), because the copy shares the model's blobs; `ollama rm` of the copy freed nothing measurable either.
