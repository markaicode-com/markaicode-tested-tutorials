# curl and the Ollama API (tested 2026-11-10)

Article: https://markaicode.com/curl-commands-ollama-api-testing-tutorial/

- `run-curl-tests.ps1` calls the normal Ollama server on port 11434 with `curl.exe`: version, tags, ps, show, chat (non-streaming and streaming), generate, the OpenAI-compatible `/v1` endpoints, four error cases, the PowerShell inline-JSON problem and `curl -w` timing. It does not pull, delete or unload models. Model names other than phi4-mini are not logged.
- `curl-tests.log` is the raw output. Windows 11, Windows PowerShell 5.1, curl 8.21.0, Ollama 0.40.15, RTX 2060 SUPER, phi4-mini.

Findings: in Windows PowerShell 5.1 `curl` is an alias for `Invoke-WebRequest` (the helper in the script is named `Invoke-CurlExe` for that reason), and inline `-d '{...}'` JSON loses its quotes, giving `HTTP 400 invalid character 'm' looking for beginning of object key string`.
