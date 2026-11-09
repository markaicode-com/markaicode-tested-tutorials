# Ollama keep_alive tests for the keep-alive guide. Uses temporary Ollama servers on port 11500 (your normal Ollama on
# 11434 is not changed). Models you already have: phi4-mini, gemma4:e4b, gemma4:26b. Takes about 5 minutes.
$here = $PSScriptRoot
$txt = Join-Path $here "run.log"; Set-Content -Path $txt -Value "" -Encoding utf8
function L($m) { Write-Host $m; Add-Content -Path $txt -Value $m -Encoding utf8 }
$py = $null
foreach ($c in @("py", "python", "python3")) { try { $v = & $c --version 2>&1 | Out-String } catch { $v = $null }; if ($LASTEXITCODE -eq 0 -and $v -match "Python 3") { $py = $c; break } }
if (-not $py) { L "python 3 not found"; Read-Host "Enter to close"; exit 1 }
L ("date: " + (Get-Date -Format "yyyy-MM-dd HH:mm"))
L ("ollama: " + ((& ollama --version 2>&1) -join " "))
L ("gpu: " + ((& nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>&1) -join " "))
try { (Invoke-RestMethod http://127.0.0.1:11434/api/ps).models | ForEach-Object {
  $b = @{ model = $_.name; keep_alive = 0 } | ConvertTo-Json; Invoke-RestMethod -Uri http://127.0.0.1:11434/api/generate -Method Post -ContentType "application/json" -Body $b | Out-Null
  L ("unloaded from the normal server: " + $_.name) } } catch { L "normal server not running (fine)" }

function StartServer($name) {
  $p = Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden -PassThru -RedirectStandardError (Join-Path $here "$name.log") -RedirectStandardOutput (Join-Path $here "$name.out")
  Start-Sleep 6; return $p
}
Remove-Item Env:\OLLAMA_KEEP_ALIVE -ErrorAction SilentlyContinue
$env:OLLAMA_HOST = "127.0.0.1:11500"; $env:OLLAMA_CONTEXT_LENGTH = "4096"
L "`n== Part 1: temporary server with no OLLAMA_KEEP_ALIVE (Ollama's default)"
$p = StartServer "server-default"
& $py (Join-Path $here "keepalive.py") --port 11500 --part main 2>&1 | ForEach-Object { L ("  " + $_) }
L "`n== ollama ps (CLI view)"
(& ollama ps 2>&1) | ForEach-Object { L ("  " + $_) }
L "`n== ollama stop gemma4:e4b"
(& ollama stop gemma4:e4b 2>&1) | ForEach-Object { L ("  " + $_) }
(& ollama ps 2>&1) | ForEach-Object { L ("  " + $_) }
L "`n== ollama run --help (keepalive flag)"
(& ollama run --help 2>&1) | Select-String -Pattern "keepalive|keep" | ForEach-Object { L ("  " + $_.Line) }
foreach ($m in @("phi4-mini", "gemma4:26b", "gemma4:e4b")) { (& ollama stop $m 2>&1) | Out-Null }
& taskkill /PID $p.Id /T /F | Out-Null; Start-Sleep 3

L "`n== Part 2: temporary server with OLLAMA_KEEP_ALIVE=20s"
$env:OLLAMA_KEEP_ALIVE = "20s"
$p = StartServer "server-env20s"
& $py (Join-Path $here "keepalive.py") --port 11500 --part env 2>&1 | ForEach-Object { L ("  " + $_) }
& taskkill /PID $p.Id /T /F | Out-Null
Remove-Item Env:\OLLAMA_KEEP_ALIVE -ErrorAction SilentlyContinue
L "`nDone. Temporary servers stopped; your normal Ollama on port 11434 was not changed."
Read-Host "Press Enter to close"
