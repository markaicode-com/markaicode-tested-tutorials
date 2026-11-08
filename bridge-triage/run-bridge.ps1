# Bridge triage tutorial test: runs the article's unit tests, then asks local models to narrate two synthetic reports.
# No downloads: uses the Python environment from the RAG test (plans\tutorial-runs\local-rag\.venv, it has requests)
# and models you already have (gemma4:e4b, phi4-mini). Temporary Ollama server on port 11500. About 3 minutes.
$here = $PSScriptRoot; Set-Location $here
$txt = Join-Path $here "run.log"; Set-Content -Path $txt -Value "" -Encoding utf8
function L($m) { Write-Host $m; Add-Content -Path $txt -Value $m -Encoding utf8 }
function RunLog($exe, $argv) { $out = & $exe @argv 2>&1 | Out-String; foreach ($l in ($out -split "`r?`n")) { if ($l.Trim()) { L ("  " + $l) } } }
$vpy = Join-Path $here "..\local-rag\.venv\Scripts\python.exe"
if (-not (Test-Path $vpy)) { L "missing ..\local-rag\.venv"; Read-Host "Enter"; exit 1 }
$env:PYTHONIOENCODING = "utf-8"
L ("date: " + (Get-Date -Format "yyyy-MM-dd HH:mm")); L ("python: " + ((& $vpy --version 2>&1) -join " ")); L ("ollama: " + ((& ollama --version 2>&1) -join " "))
L ("requests: " + ((& $vpy -c "import requests;print(requests.__version__)" 2>&1) -join " "))
L "`n== 1. Unit tests (test_triage.py)"
RunLog $vpy @("test_triage.py")
L "`n== 2. Narration by local models"
$env:OLLAMA_HOST = "127.0.0.1:11500"; $env:OLLAMA_CONTEXT_LENGTH = "4096"
$p = Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden -PassThru -RedirectStandardError (Join-Path $here "server.log") -RedirectStandardOutput (Join-Path $here "server.out")
Start-Sleep 6
RunLog $vpy @("narrate_test.py", "gemma4:e4b", "phi4-mini")
& taskkill /PID $p.Id /T /F | Out-Null
L "`nDone. Temporary server stopped."
Read-Host "Press Enter to close"
