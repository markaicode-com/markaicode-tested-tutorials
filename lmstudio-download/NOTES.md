# LM Studio model downloads (tested 2026-11-12)

Article: https://markaicode.com/errors/lm-studio-model-download-failed-fix/

- `run-lmstudio-download-check.ps1` is read-only. It prints `lms get --help` and `lms import --help`, checks the models folders (counts and size only), lists LM Studio settings about proxies, downloads and the models folder, checks free disk space, and sends header-only (HEAD) requests to Hugging Face. Nothing is downloaded, imported, deleted or changed. User paths are shown as %USERPROFILE%.
- `lmstudio-download-check.log` is the output. Windows 11 Pro (build 26300), LM Studio 0.4.28.

Findings:
- Models live in `%USERPROFILE%\.lmstudio\models` (`downloadsFolder` in settings.json); the old `.cache\lm-studio\models` folder does not exist on this install.
- The Hugging Face proxy option is stored as `"useHFProxy": true` in `%USERPROFILE%\.lmstudio\settings.json`.
- A Hugging Face `resolve/main/<file>.gguf` URL returned HTTP 302 to `us.aws.cdn.hf.co`, then HTTP 200 after one redirect, so firewalls need `*.hf.co` as well as `huggingface.co`.
- In 0.4.28, `lms get` accepts a full Hugging Face URL, `name@quantization`, `--select` and `-y`; `lms import` moves by default and supports `--copy`, `--hard-link`, `--symbolic-link`, `--user-repo` and `--dry-run`.
