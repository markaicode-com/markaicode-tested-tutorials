# "ollama: command not found" and PATH on Windows 11 (tested 2026-11-09)

Article: https://markaicode.com/fix-ollama-command-not-found-path-configuration/

- `run-tests.ps1` part 2 only READS your user and machine PATH; log `part2-path.log`.
- `run-followup.ps1` shows the exact error in a child PowerShell with the Ollama folder removed from PATH, and the fix; log `part4-followup.log` (first block).
- Lengths and entry counts are from the test PC; the folder list itself is not published.
