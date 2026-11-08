# Tests for 3 Ollama tutorials (2026-11-09). About 10 minutes. Nothing permanent is changed:
#  - GPU/CPU tests use a temporary second Ollama server on port 11500 (your normal Ollama on 11434 is not touched).
#  - PATH test only READS your PATH; a child PowerShell gets a modified copy for the "command not found" demo.
#  - Cache test copies phi4-mini to a temporary name and removes only that copy.
# Logs: part1-cpu-gpu.log, part2-path.log, part3-cache.log next to this script.
$ErrorActionPreference = "Continue"
$here = $PSScriptRoot
function NewLog($n) { $p = Join-Path $here $n; Set-Content -Path $p -Value "" -Encoding utf8; return $p }
function W($log, $m) { $m = [string]$m; Write-Host $m; Add-Content -Path $log -Value $m -Encoding utf8 }

# ---------------- Part 1: CPU vs GPU ----------------
$L1 = NewLog "part1-cpu-gpu.log"
W $L1 ("date: " + (Get-Date -Format "yyyy-MM-dd HH:mm"))
W $L1 ("ollama: " + ((& ollama --version 2>&1) -join " "))
W $L1 ("gpu: " + ((& nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>&1) -join " "))
try { (Invoke-RestMethod http://127.0.0.1:11434/api/ps).models | ForEach-Object {
  $b = @{ model = $_.name; keep_alive = 0 } | ConvertTo-Json; Invoke-RestMethod -Uri http://127.0.0.1:11434/api/generate -Method Post -ContentType "application/json" -Body $b | Out-Null
  W $L1 ("unloaded from the normal server: " + $_.name) } } catch { W $L1 "normal server not running (fine)" }

W $L1 "`n== Which GPU/CPU settings does 'ollama serve --help' list?"
(& ollama serve --help 2>&1) | ForEach-Object { W $L1 ("  " + $_) }
W $L1 "`n== Does 'ollama run' have a --gpu-layers flag?"
$rh = (& ollama run --help 2>&1) -join "`n"
W $L1 ("  --gpu-layers in 'ollama run --help': " + ($rh -match "gpu-layers"))
(& ollama run --help 2>&1) | ForEach-Object { W $L1 ("  " + $_) }
W $L1 "`n== CLI: ollama run phi4-mini --gpu-layers 0 (expect an error if the flag does not exist)"
(& ollama run phi4-mini --gpu-layers 0 "hi" 2>&1) | Select-Object -First 3 | ForEach-Object { W $L1 ("  " + $_) }

$prompt = "Write exactly 120 words about why the sky is blue."
function Gen($port, $model, $opts) {
  $body = @{ model = $model; prompt = $prompt; stream = $false; options = (@{ seed = 1; temperature = 0; num_predict = 160; num_ctx = 4096 } + $opts) } | ConvertTo-Json -Depth 4
  $r = Invoke-RestMethod -Uri "http://127.0.0.1:$port/api/generate" -Method Post -ContentType "application/json" -Body $body -TimeoutSec 600
  $tps = [math]::Round($r.eval_count / ($r.eval_duration / 1e9), 1)
  $ps = (Invoke-RestMethod "http://127.0.0.1:$port/api/ps").models | Where-Object { $_.name -like "$model*" } | Select-Object -First 1
  $vram = if ($ps) { [math]::Round($ps.size_vram / 1GB, 2) } else { -1 }; $size = if ($ps) { [math]::Round($ps.size / 1GB, 2) } else { -1 }
  return "tok/s=$tps  eval_count=$($r.eval_count)  load_s=$([math]::Round($r.load_duration/1e9,2))  size_GB=$size  vram_GB=$vram"
}
function ProcLine { (& ollama ps 2>&1) | Select-Object -Skip 1 | ForEach-Object { "    ollama ps: " + $_ } }
function Unload($port, $model) { $b = @{ model = $model; keep_alive = 0 } | ConvertTo-Json; try { Invoke-RestMethod -Uri "http://127.0.0.1:$port/api/generate" -Method Post -ContentType "application/json" -Body $b | Out-Null } catch {}; Start-Sleep 3 }
function StartServer($name) {
  $p = Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden -PassThru -RedirectStandardError (Join-Path $here "$name.log") -RedirectStandardOutput (Join-Path $here "$name.out")
  Start-Sleep 7; return $p
}
$env:OLLAMA_HOST = "127.0.0.1:11500"
foreach ($v in @("CUDA_VISIBLE_DEVICES", "OLLAMA_GPU_LAYERS", "OLLAMA_NUM_GPU")) { Remove-Item "Env:\$v" -ErrorAction SilentlyContinue }

W $L1 "`n== A. Normal temporary server: num_gpu default / 0 / partial"
$p = StartServer "srv-a"
foreach ($m in @("phi4-mini", "gemma4:e4b")) {
  W $L1 ("  [$m] warm-up: " + (Gen 11500 $m @{}))
  W $L1 ("  [$m] default (all on GPU): " + (Gen 11500 $m @{})); ProcLine | ForEach-Object { W $L1 $_ }
  Unload 11500 $m
  W $L1 ("  [$m] num_gpu=0 (CPU only): " + (Gen 11500 $m @{ num_gpu = 0 })); ProcLine | ForEach-Object { W $L1 $_ }
  Unload 11500 $m
  W $L1 ("  [$m] num_gpu=12 (part GPU): " + (Gen 11500 $m @{ num_gpu = 12 })); ProcLine | ForEach-Object { W $L1 $_ }
  Unload 11500 $m
}
& taskkill /PID $p.Id /T /F | Out-Null; Start-Sleep 3

W $L1 "`n== B. Temporary server with OLLAMA_GPU_LAYERS=0 (the variable the old article recommends)"
$env:OLLAMA_GPU_LAYERS = "0"; $p = StartServer "srv-b"
W $L1 ("  [phi4-mini] " + (Gen 11500 "phi4-mini" @{})); ProcLine | ForEach-Object { W $L1 $_ }
& taskkill /PID $p.Id /T /F | Out-Null; Start-Sleep 3; Remove-Item Env:\OLLAMA_GPU_LAYERS

W $L1 "`n== C. Temporary server with CUDA_VISIBLE_DEVICES=-1"
$env:CUDA_VISIBLE_DEVICES = "-1"; $p = StartServer "srv-c"
W $L1 ("  [phi4-mini] " + (Gen 11500 "phi4-mini" @{})); ProcLine | ForEach-Object { W $L1 $_ }
& taskkill /PID $p.Id /T /F | Out-Null; Start-Sleep 3; Remove-Item Env:\CUDA_VISIBLE_DEVICES

W $L1 ""
W $L1 '== D. Temporary server started from cmd after: set CUDA_VISIBLE_DEVICES="" (exactly as the old article)'
$p = Start-Process -FilePath "cmd.exe" -ArgumentList '/c set CUDA_VISIBLE_DEVICES=""&& ollama serve' -WindowStyle Hidden -PassThru -RedirectStandardError (Join-Path $here "srv-d.log") -RedirectStandardOutput (Join-Path $here "srv-d.out")
Start-Sleep 7
W $L1 ("  [phi4-mini] " + (Gen 11500 "phi4-mini" @{})); ProcLine | ForEach-Object { W $L1 $_ }
& taskkill /PID $p.Id /T /F | Out-Null; Start-Sleep 3
W $L1 "`n== GPU lines from the temporary server logs (inference compute / offload)"
foreach ($n in @("srv-a", "srv-b", "srv-c", "srv-d")) {
  $f = Join-Path $here "$n.log"
  if (Test-Path $f) { Select-String -Path $f -Pattern "inference compute|offloaded|no compatible GPUs|CUDA_VISIBLE|OLLAMA_GPU" | Select-Object -First 6 | ForEach-Object { W $L1 ("  [$n] " + ($_.Line -replace '^.*?level=', 'level=')) } }
}
Remove-Item Env:\OLLAMA_HOST

# ---------------- Part 2: PATH ----------------
$L2 = NewLog "part2-path.log"
W $L2 ("date: " + (Get-Date -Format "yyyy-MM-dd HH:mm"))
$cmd = Get-Command ollama -ErrorAction SilentlyContinue
W $L2 ("Get-Command ollama: " + ($(if ($cmd) { $cmd.Source -replace [regex]::Escape($env:USERPROFILE), '%USERPROFILE%' } else { "not found" })))
$wh = ("where.exe ollama: " + ((& where.exe ollama 2>&1) -join " | ")) -replace [regex]::Escape($env:USERPROFILE), '%USERPROFILE%'
W $L2 $wh
$def = Join-Path $env:LOCALAPPDATA "Programs\Ollama"
W $L2 ("default install folder %LOCALAPPDATA%\Programs\Ollama exists: " + (Test-Path $def))
W $L2 ("ollama.exe in it: " + (Test-Path (Join-Path $def "ollama.exe")))
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User"); $machPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
$inUser = ($userPath -split ';' | Where-Object { $_.TrimEnd('\') -ieq $def.TrimEnd('\') }).Count -gt 0
$inMach = ($machPath -split ';' | Where-Object { $_.TrimEnd('\') -ieq $def.TrimEnd('\') }).Count -gt 0
W $L2 "Ollama folder in the USER PATH (registry): $inUser; in the MACHINE PATH: $inMach"
W $L2 ("entries: user PATH " + ($userPath -split ';' | Where-Object { $_ }).Count + ", machine PATH " + ($machPath -split ';' | Where-Object { $_ }).Count + ", this session's PATH " + ($env:PATH -split ';' | Where-Object { $_ }).Count)
W $L2 ("characters: user PATH " + $userPath.Length + ", machine PATH " + $machPath.Length + ", session PATH " + $env:PATH.Length)
$would = $env:PATH + ";" + $def
W $L2 ("the old one-liner would write a USER PATH of " + $would.Length + " characters with " + ($would -split ';' | Where-Object { $_ }).Count + " entries (it copies the machine PATH into the user PATH)")
W $L2 "`n== Demo in a child PowerShell with the Ollama folder removed from PATH"
$stripped = (($env:PATH -split ';') | Where-Object { $_.TrimEnd('\') -ine $def.TrimEnd('\') }) -join ';'
$demo = @'
$env:PATH = $env:STRIPPED
try { ollama --version } catch { "ERROR: " + $_.Exception.Message }
'-- after adding the Ollama folder back to this session''s PATH:'
$env:PATH += ";$env:LOCALAPPDATA\Programs\Ollama"
ollama --version
'@
$env:STRIPPED = $stripped
(& powershell -NoProfile -Command $demo 2>&1) | ForEach-Object { W $L2 ("  " + ($_ -replace [regex]::Escape($env:USERPROFILE), '%USERPROFILE%')) }
Remove-Item Env:\STRIPPED
W $L2 "`n== Same demo in cmd.exe"
(& cmd /c "set PATH=C:\Windows\system32;C:\Windows && ollama --version" 2>&1) | ForEach-Object { W $L2 ("  " + $_) }

# ---------------- Part 3: cache ----------------
$L3 = NewLog "part3-cache.log"
W $L3 ("date: " + (Get-Date -Format "yyyy-MM-dd HH:mm"))
$tmp3 = $null
try { Invoke-RestMethod http://127.0.0.1:11434/api/version | Out-Null; W $L3 "using your normal Ollama (11434) for cp/rm/list" } catch { $env:OLLAMA_HOST = "127.0.0.1:11500"; $tmp3 = StartServer "srv-cache"; W $L3 "normal Ollama not running: using a temporary server on 11500 (same models folder)" }
$om = [Environment]::GetEnvironmentVariable("OLLAMA_MODELS", "User"); if (-not $om) { $om = [Environment]::GetEnvironmentVariable("OLLAMA_MODELS", "Machine") }
W $L3 ("OLLAMA_MODELS set: " + [bool]$om)
$md = if ($om) { $om } else { Join-Path $env:USERPROFILE ".ollama\models" }
W $L3 ("models folder exists: " + (Test-Path $md) + "  (default %USERPROFILE%\.ollama\models used: " + (-not $om) + ")")
W $L3 ("subfolders: " + ((Get-ChildItem $md -Directory | ForEach-Object Name) -join ", "))
function Usage { $f = Get-ChildItem (Join-Path $md "blobs") -File; return @{ n = $f.Count; gb = [math]::Round((($f | Measure-Object Length -Sum).Sum) / 1GB, 3); partial = ($f | Where-Object { $_.Name -like "*partial*" }).Count } }
$u0 = Usage; W $L3 ("blobs: " + $u0.n + " files, " + $u0.gb + " GB, partial downloads: " + $u0.partial)
W $L3 ("drive free GB: " + [math]::Round((Get-PSDrive ($md.Substring(0,1))).Free / 1GB, 2))
W $L3 "`n== commands Ollama offers ('ollama --help')"
(& ollama --help 2>&1) | ForEach-Object { W $L3 ("  " + $_) }
W $L3 "`n== 'ollama prune --help' (the old article mentions a prune command; --help only, nothing is deleted)"
(& ollama prune --help 2>&1) | Select-Object -First 4 | ForEach-Object { W $L3 ("  " + $_) }
W $L3 "`n== ollama list (phi4-mini only)"
(& ollama list 2>&1) | Where-Object { $_ -match "^NAME|^phi4-mini" } | ForEach-Object { W $L3 ("  " + $_) }
W $L3 "`n== copy phi4-mini to phi4-mini-cachetest, then remove the copy"
(& ollama cp phi4-mini phi4-mini-cachetest 2>&1) | ForEach-Object { W $L3 ("  " + $_) }
$u1 = Usage; W $L3 ("after cp:  blobs " + $u1.n + " files, " + $u1.gb + " GB")
(& ollama list 2>&1) | Where-Object { $_ -match "^NAME|^phi4-mini" } | ForEach-Object { W $L3 ("  " + $_) }
(& ollama rm phi4-mini-cachetest 2>&1) | ForEach-Object { W $L3 ("  " + $_) }
$u2 = Usage; W $L3 ("after rm of the copy: blobs " + $u2.n + " files, " + $u2.gb + " GB")
(& ollama list 2>&1) | Where-Object { $_ -match "^NAME|^phi4-mini" } | ForEach-Object { W $L3 ("  " + $_) }
W $L3 "`n== rm of a model that does not exist"
(& ollama rm no-such-model:latest 2>&1) | ForEach-Object { W $L3 ("  " + $_) }
if ($tmp3) { & taskkill /PID $tmp3.Id /T /F | Out-Null; Remove-Item Env:\OLLAMA_HOST -ErrorAction SilentlyContinue }
W $L3 "`nDone. Nothing permanent was changed."
Write-Host "`nAll done. Logs are in $here"
Read-Host "Press Enter to close"
