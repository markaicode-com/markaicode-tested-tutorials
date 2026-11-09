# Markaicode tutorial run: Ollama environment variables (Windows). Changes NO settings on this PC.
# Part A reads what is set. Part B starts a temporary second Ollama server on port 11500 with test variables
# (only for this script's process), shows that they take effect, then stops it. No downloads.
$ErrorActionPreference = "Continue"
$out = Join-Path $PSScriptRoot "04-results.txt"; "" | Set-Content $out -Encoding utf8
function Log($t) { Write-Host $t; Add-Content -Path $out -Value $t -Encoding utf8 }
Log ("== Date: " + (Get-Date -Format "yyyy-MM-dd HH:mm zzz"))
Log ("== " + ((& ollama --version 2>&1) -join " "))

Log "`n== A1. Variables this Ollama version knows (ollama serve --help)"
Log ((& ollama serve --help 2>&1) -join "`n")

Log "`n== A2. OLLAMA_* variables currently set on this PC"
foreach ($scope in "User","Machine") {
  $vars = [Environment]::GetEnvironmentVariables($scope)
  $hit = $vars.Keys | Where-Object { $_ -like "OLLAMA_*" -or $_ -eq "CUDA_VISIBLE_DEVICES" } | Sort-Object
  if ($hit) { foreach ($k in $hit) { Log ("{0,-8} {1} = {2}" -f $scope, $k, $vars[$k]) } } else { Log ("{0,-8} (none)" -f $scope) }
}

Log "`n== A3. Which address is Ollama listening on?"
Get-NetTCPConnection -State Listen -LocalPort 11434 -ErrorAction SilentlyContinue | ForEach-Object { Log ("listening on {0}:{1}  (process {2})" -f $_.LocalAddress, $_.LocalPort, (Get-Process -Id $_.OwningProcess).ProcessName) }

Log "`n== A4. Where are the models stored, and how big?"
$mdir = [Environment]::GetEnvironmentVariable("OLLAMA_MODELS","User"); if (-not $mdir) { $mdir = [Environment]::GetEnvironmentVariable("OLLAMA_MODELS","Machine") }
if (-not $mdir) { $mdir = Join-Path $env:USERPROFILE ".ollama\models"; Log "OLLAMA_MODELS not set, default folder used" }
$size = (Get-ChildItem $mdir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
Log ("{0}  ->  {1:N1} GB" -f ($mdir -replace [regex]::Escape($env:USERNAME), "<user>"), ($size / 1GB))

Log "`n== B. Temporary second server on port 11500 with test variables"
$env:OLLAMA_HOST = "127.0.0.1:11500"; $env:OLLAMA_KEEP_ALIVE = "20s"; $env:OLLAMA_CONTEXT_LENGTH = "16384"; $env:OLLAMA_NUM_PARALLEL = "2"
Log "OLLAMA_HOST=127.0.0.1:11500  OLLAMA_KEEP_ALIVE=20s  OLLAMA_CONTEXT_LENGTH=16384  OLLAMA_NUM_PARALLEL=2"
$errlog = Join-Path $PSScriptRoot "04-temp-server.log"
$p = Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden -PassThru -RedirectStandardError $errlog -RedirectStandardOutput (Join-Path $PSScriptRoot "04-temp-server.out")
Start-Sleep 6
Log ("server version on :11500 -> " + (Invoke-RestMethod http://127.0.0.1:11500/api/version).version)
Log "`nserver config line the temporary server printed at start-up:"
Log ((Select-String -Path $errlog -Pattern "server config|Listening on" | ForEach-Object { $_.Line -replace [regex]::Escape($env:USERNAME), "<user>" }) -join "`n")

function Run($port, $label) {
  $b = @{ model = "phi4-mini"; prompt = "Say hi in five words."; stream = $false; options = @{ num_predict = 20 } } | ConvertTo-Json -Depth 4
  Invoke-RestMethod -Uri "http://127.0.0.1:$port/api/generate" -Method Post -ContentType "application/json" -Body $b | Out-Null
  $m = (Invoke-RestMethod "http://127.0.0.1:$port/api/ps").models | Where-Object { $_.name -like "phi4-mini*" } | Select-Object -First 1
  $left = [math]::Round(([datetime]$m.expires_at - (Get-Date)).TotalSeconds)
  Log ("{0,-34} context {1,6}   unloads in about {2} s   ({3:N0} MB, {4:N0} MB on GPU)" -f $label, $m.context_length, $left, ($m.size/1MB), ($m.size_vram/1MB))
}
Log "`n== Same model, two servers"
Run 11434 "normal server (your settings)"
$u = @{ model = "phi4-mini"; keep_alive = 0 } | ConvertTo-Json; Invoke-RestMethod -Uri http://127.0.0.1:11434/api/generate -Method Post -ContentType "application/json" -Body $u | Out-Null
Run 11500 "temporary server (test variables)"
Log "`nwaiting 25 s for OLLAMA_KEEP_ALIVE=20s ..."
Start-Sleep 25
$left = (Invoke-RestMethod http://127.0.0.1:11500/api/ps).models
Log ("loaded models on :11500 after 25 s: " + ($(if ($left) { ($left | ForEach-Object name) -join ", " } else { "none (unloaded as configured)" })))

Log "`n== Is the temporary server reachable only from this PC?"
Get-NetTCPConnection -State Listen -LocalPort 11500 -ErrorAction SilentlyContinue | ForEach-Object { Log ("listening on {0}:{1}" -f $_.LocalAddress, $_.LocalPort) }

& taskkill /PID $p.Id /T /F | Out-Null
Log "`nTemporary server stopped. Your normal Ollama on port 11434 was not changed."
Log "Done. Leave this window open for the screenshot."
Read-Host "Press Enter to close"
