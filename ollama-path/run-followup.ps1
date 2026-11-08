# Follow-up tests (2026-11-09), about 2 minutes. Temporary Ollama server on port 11500 only; a test model "phi4-cpu-test"
# is created from phi4-mini and removed at the end. Log: part4-followup.log
$ErrorActionPreference = "Continue"
$here = $PSScriptRoot
$log = Join-Path $here "part4-followup.log"; Set-Content -Path $log -Value "" -Encoding utf8
function W($m) { $m = [string]$m; Write-Host $m; Add-Content -Path $log -Value $m -Encoding utf8 }
W ("date: " + (Get-Date -Format "yyyy-MM-dd HH:mm"))

W "== PATH demo in a child PowerShell (Ollama folder removed from PATH)"
$def = Join-Path $env:LOCALAPPDATA "Programs\Ollama"
$env:STRIPPED = (($env:PATH -split ';') | Where-Object { $_.TrimEnd('\') -ine $def.TrimEnd('\') }) -join ';'
$demo = @'
$env:PATH = $env:STRIPPED
try { ollama --version } catch { "ERROR: " + $_.Exception.Message }
'-- after: $env:PATH += ";$env:LOCALAPPDATA\Programs\Ollama"'
$env:PATH += ";$env:LOCALAPPDATA\Programs\Ollama"
ollama --version
'@
$enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($demo))
(& powershell -NoProfile -EncodedCommand $enc 2>&1) | ForEach-Object { W ("  " + ($_ -replace [regex]::Escape($env:USERPROFILE), '%USERPROFILE%')) }
Remove-Item Env:\STRIPPED

$prompt = "Write exactly 120 words about why the sky is blue."
function Gen($model, $opts) {
  $body = @{ model = $model; prompt = $prompt; stream = $false; options = (@{ seed = 1; temperature = 0; num_predict = 160; num_ctx = 4096 } + $opts) } | ConvertTo-Json -Depth 4
  $r = Invoke-RestMethod -Uri "http://127.0.0.1:11500/api/generate" -Method Post -ContentType "application/json" -Body $body -TimeoutSec 600
  return "tok/s=" + [math]::Round($r.eval_count / ($r.eval_duration / 1e9), 1)
}
function Ps { (& ollama ps 2>&1) | Select-Object -Skip 1 | ForEach-Object { W ("    ollama ps: " + $_) } }
function StartServer($name) { $p = Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden -PassThru -RedirectStandardError (Join-Path $here "$name.log") -RedirectStandardOutput (Join-Path $here "$name.out"); Start-Sleep 7; return $p }
function Stop($p) { & taskkill /PID $p.Id /T /F | Out-Null; Start-Sleep 3 }
$env:OLLAMA_HOST = "127.0.0.1:11500"

W "`n== E. CUDA_VISIBLE_DEVICES=-1 and GGML_VK_VISIBLE_DEVICES=-1 (hide CUDA and Vulkan)"
$env:CUDA_VISIBLE_DEVICES = "-1"; $env:GGML_VK_VISIBLE_DEVICES = "-1"; $p = StartServer "srv-e"
W ("  [phi4-mini] " + (Gen "phi4-mini" @{})); Ps; Stop $p
Remove-Item Env:\CUDA_VISIBLE_DEVICES, Env:\GGML_VK_VISIBLE_DEVICES

W "`n== F. OLLAMA_LLM_LIBRARY=cpu"
$env:OLLAMA_LLM_LIBRARY = "cpu"; $p = StartServer "srv-f"
W ("  [phi4-mini] " + (Gen "phi4-mini" @{})); Ps; Stop $p
Remove-Item Env:\OLLAMA_LLM_LIBRARY

W "`n== G. Modelfile with PARAMETER num_gpu 0"
$p = StartServer "srv-g"
$mf = Join-Path $here "Modelfile.cpu"; Set-Content -Path $mf -Value "FROM phi4-mini`nPARAMETER num_gpu 0" -Encoding ascii
(& ollama create phi4-cpu-test -f $mf 2>&1) | Select-Object -Last 1 | ForEach-Object { W ("  " + $_) }
W ("  [phi4-cpu-test] " + (Gen "phi4-cpu-test" @{})); Ps
(& ollama rm phi4-cpu-test 2>&1) | Select-Object -Last 1 | ForEach-Object { W ("  " + $_) }
Stop $p
W "`n== GPU lines from the temporary server logs"
foreach ($n in @("srv-e", "srv-f", "srv-g")) { $f = Join-Path $here "$n.log"; if (Test-Path $f) { Select-String -Path $f -Pattern "inference compute|offloaded|no compatible|entering low vram|library=cpu" | Select-Object -First 4 | ForEach-Object { W ("  [$n] " + ($_.Line -replace '^.*?level=', 'level=')) } } }
Remove-Item Env:\OLLAMA_HOST
W "`nDone. Temporary server stopped; test model removed."
Read-Host "Press Enter to close"
