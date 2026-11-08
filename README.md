# Markaicode tested tutorials

The scripts, test files and raw results behind the tested tutorials on [markaicode.com](https://markaicode.com).
Every tutorial in this repository was run on a real PC before it was published, and the article shows the
numbers from these runs. If a step stops working for you, the run log here shows exactly what we saw and when.

**Test machine (all folders unless the log says otherwise):** Windows 11 Pro (build 26300), AMD Ryzen 7 8700G,
31 GB RAM, NVIDIA GeForce RTX 2060 SUPER (8 GB). Ollama 0.40.x, Python 3.14, Node 24.

| Folder | Article | What was tested | Tested |
|---|---|---|---|
| [ollama-cuda](ollama-cuda/) | [Use your NVIDIA GPU with Ollama](https://markaicode.com/install-ollama-nvidia-gpu-cuda-support/) | GPU detection, CPU vs GPU speed | 2026-11-07 |
| [ollama-env](ollama-env/) | [Ollama environment variables](https://markaicode.com/ollama-environment-variables-configuration-guide/) | Which variables a server really picks up | 2026-11-07 |
| [ollama-gguf](ollama-gguf/) | [Import a GGUF model into Ollama](https://markaicode.com/import-gguf-models-ollama-guide/) | Modelfile import of a small GGUF | 2026-11-07 |
| [ollama-tools](ollama-tools/) | [Build a tool-calling agent with Ollama](https://markaicode.com/build-ai-agents-ollama-tool-calling-guide/) | Tool calls across several local models, and a repair loop | 2026-11-07 |
| [ollama-keepalive](ollama-keepalive/) | [Ollama keep_alive](https://markaicode.com/ollama-keep-alive-memory-management/) | Load times, `keep_alive`, `OLLAMA_KEEP_ALIVE`, what a pin survives | 2026-11-08 |
| [local-llm-bench](local-llm-bench/) | [Best local LLM inference tools](https://markaicode.com/best/best-local-llm-inference-tools-production-2026/) | `OLLAMA_NUM_PARALLEL` 1 vs 4: throughput, latency, memory | 2026-11-08 |
| [local-rag](local-rag/) | [Local RAG with Ollama and LangChain 1.x](https://markaicode.com/build-local-rag-pipeline-ollama-langchain/) | Ingest, answers checked against a known document, old imports that fail | 2026-11-08 |
| [copilot-agent](copilot-agent/) | [GitHub Copilot agent mode in VS Code](https://markaicode.com/vs/enable-github-copilot-agent-mode-in-vs-code-in-5-minutes/) | The task given to the agent and the test project it worked on | 2026-11-08 |
| [bridge-triage](bridge-triage/) | [Cross-chain bridge monitoring with Ollama](https://markaicode.com/cross-chain-bridge-analysis-ollama-multi-blockchain-tracking/) | Alert rules with unit tests, and how two local models narrate an alert | 2026-11-08 |

## How the runs work

Most folders have a PowerShell script (`*.ps1`) that checks the environment, runs the test and writes a log next
to itself. Ollama tests start a **temporary second Ollama server on port 11500** and stop it afterwards, so the
normal Ollama on port 11434 and its settings are not touched. Python tests use their own virtual environment.

```powershell
# example: re-run the keep_alive test (needs Ollama and phi4-mini)
cd ollama-keepalive
powershell -ExecutionPolicy Bypass -File .\run-keepalive.ps1
```

## What was removed before publishing

Ollama's own server logs, PowerShell transcript headers, the `nvidia-smi` process list, the FAISS index files
and the Python virtual environments are not included. Local paths are shown as `C:\Users\<you>` and `<repo>`.
Model files are not included; each script names the model it pulls.

## Licence

- Code and scripts: [MIT](LICENSE).
- Run logs and results (`*.log`, `*.txt`, `*.json`, `*.jsonl`): [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), credit "Markaicode" with a link to the article.
- The RAG test document is a fictional company handbook. Create it by running `python make_pdf.py` inside `local-rag` (needs `fpdf2`); it is written to `docs/northwind-handbook.pdf`.

Not affiliated with Ollama, GitHub, Microsoft, LangChain or any vendor named here. The crypto examples are
monitoring code, not financial advice.

Found a step that no longer works? Open an issue with your versions and the error.
