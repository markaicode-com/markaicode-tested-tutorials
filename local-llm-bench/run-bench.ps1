# Local LLM concurrency test for the "best local LLM inference tools" guide.
# Starts a temporary second Ollama server on port 11500 twice (OLLAMA_NUM_PARALLEL=1, then 4), sends 1, 2, 4 and 8
# requests at once to each, and logs tokens per second. Your normal Ollama on port 11434 is not changed; its loaded
# models are unloaded first so the GPU is free. Takes about 10 minutes. Uses models you already have: phi4-mini, gemma4:e4b.
$here = $PSScriptRoot
$log = Join-Path $here "results.jsonl"; $txt = Join-Path $here "run.log"
Set-Content -Path $log -Value "" -Encoding utf8; Set-Content -Path $txt -Value "" -Encoding utf8
function L($m) { Write-Host $m; Add-Content -Path $txt -Value $m -Encoding utf8 }
$py = $null
foreach ($c in @("py", "python", "python3")) { try { $v = & $c --version 2>&1 | Out-String } catch { $v = $null }; if ($LASTEXITCODE -eq 0 -and $v -match "Python 3") { $py = $c; break } }
if (-not $py) { L "python 3 not found"; Read-Host "Enter to close"; exit 1 }
L ("date: " + (Get-Date -Format "yyyy-MM-dd HH:mm"))
L ("ollama: " + ((& ollama --version 2>&1) -join " "))
L ("gpu: " + ((& nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>&1) -join " "))
# free the GPU: unload whatever the normal server has loaded
try { (Invoke-RestMethod http://127.0.0.1:11434/api/ps).models | ForEach-Object {
  $b = @{ model = $_.name; keep_alive = 0 } | ConvertTo-Json; Invoke-RestMethod -Uri http://127.0.0.1:11434/api/generate -Method Post -ContentType "application/json" -Body $b | Out-Null
  L ("unloaded from the normal server: " + $_.name) } } catch { L "normal server not reachable (fine)" }
foreach ($par in @(1, 4)) {
  $env:OLLAMA_HOST = "127.0.0.1:11500"; $env:OLLAMA_NUM_PARALLEL = "$par"; $env:OLLAMA_CONTEXT_LENGTH = "4096"; $env:OLLAMA_KEEP_ALIVE = "2m"; $env:OLLAMA_MAX_LOADED_MODELS = "1"
  $errlog = Join-Path $here "server-par$par.log"
  $p = Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden -PassThru -RedirectStandardError $errlog -RedirectStandardOutput (Join-Path $here "server-par$par.out")
  Start-Sleep 6
  L "`n== temporary server, OLLAMA_NUM_PARALLEL=$par, OLLAMA_CONTEXT_LENGTH=4096"
  foreach ($m in @("phi4-mini", "gemma4:e4b")) {
    $out = & $py (Join-Path $here "bench.py") --port 11500 --model $m --tokens 256 --conc 1 2 4 8 --label "parallel=$par" 2>&1
    foreach ($line in $out) { L ("  " + $line); if ("$line".StartsWith("{")) { Add-Content -Path $log -Value $line -Encoding utf8 } }
    $ps = (Invoke-RestMethod http://127.0.0.1:11500/api/ps).models | Select-Object -First 1
    if ($ps) { L ("  loaded: {0}  size {1:N0} MB, on GPU {2:N0} MB, context {3}" -f $ps.name, ($ps.size/1MB), ($ps.size_vram/1MB), $ps.context_length) }
    L ("  nvidia-smi used: " + ((& nvidia-smi --query-gpu=memory.used --format=csv,noheader 2>&1) -join " "))
  }
  & taskkill /PID $p.Id /T /F | Out-Null
  Start-Sleep 3
}
L "`nDone. Temporary servers stopped; your normal Ollama on port 11434 was not changed."
Read-Host "Press Enter to close"
