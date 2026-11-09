# Markaicode tutorial run: Ollama on an NVIDIA GPU (Windows). Reads hardware info, checks whether the CUDA Toolkit
# is installed, and measures generation speed on GPU vs CPU with models that are ALREADY installed (no downloads).
# Takes a few minutes. Results: 03-results.txt and 03-results.json next to this file.
$ErrorActionPreference = "Continue"
$out = Join-Path $PSScriptRoot "03-results.txt"; $json = Join-Path $PSScriptRoot "03-results.json"
"" | Set-Content $out -Encoding utf8
function Log($t) { Write-Host $t; Add-Content -Path $out -Value $t -Encoding utf8 }
$api = "http://localhost:11434"
Log ("== Date: " + (Get-Date -Format "yyyy-MM-dd HH:mm zzz"))
Log "`n== nvidia-smi --query-gpu"
Log ((nvidia-smi --query-gpu=name,driver_version,memory.total,compute_cap --format=csv) -join "`n")
Log "`n== nvidia-smi (header only)"
Log ((nvidia-smi | Select-Object -First 12) -join "`n")
Log "`n== CUDA Toolkit (nvcc) installed?"
$nvcc = Get-Command nvcc -ErrorAction SilentlyContinue
if ($nvcc) { Log ("yes: " + $nvcc.Source); Log ((& nvcc --version) -join "`n") } else { Log "no: nvcc is not on PATH" }
Log ("CUDA_PATH = " + $env:CUDA_PATH)
Log "`n== ollama --version"
Log ((& ollama --version 2>&1) -join "`n")
Log "`n== Ollama server log: GPU detection lines"
$sl = Join-Path $env:LOCALAPPDATA "Ollama\server.log"
if (Test-Path $sl) { Log ((Select-String -Path $sl -Pattern "inference compute|library=cuda|total vram|no compatible GPUs" | Select-Object -Last 6 | ForEach-Object { $_.Line }) -join "`n") } else { Log "server.log not found at $sl" }

function Gen($model, $opts, $label) {
  $body = @{ model = $model; prompt = "Explain in about 150 words why a GPU speeds up large language model inference."; stream = $false; keep_alive = "5m"; options = $opts } | ConvertTo-Json -Depth 5
  $r = Invoke-RestMethod -Uri "$api/api/generate" -Method Post -ContentType "application/json" -Body $body -TimeoutSec 900
  $ps = (Invoke-RestMethod -Uri "$api/api/ps").models | Where-Object { $_.name -like "$model*" } | Select-Object -First 1
  $vram = (nvidia-smi --query-gpu=memory.used --format=csv,noheader) -join ""
  $row = [ordered]@{
    label = $label; model = $model; num_gpu = $opts.num_gpu
    tokens = $r.eval_count; tok_per_s = [math]::Round($r.eval_count / ($r.eval_duration / 1e9), 1)
    prompt_tok_per_s = if ($r.prompt_eval_duration) { [math]::Round($r.prompt_eval_count / ($r.prompt_eval_duration / 1e9), 1) } else { $null }
    load_s = [math]::Round($r.load_duration / 1e9, 1); total_s = [math]::Round($r.total_duration / 1e9, 1)
    size_mb = [math]::Round($ps.size / 1MB); vram_mb = [math]::Round($ps.size_vram / 1MB)
    gpu_share = if ($ps.size) { [math]::Round(100 * $ps.size_vram / $ps.size) } else { $null }; nvidia_smi_used = $vram
  }
  Log ("{0,-22} {1,-12} {2,6} tok/s  load {3,5}s  on GPU {4,3}%  ({5} of {6} MB)  nvidia-smi used: {7}" -f $label, $model, $row.tok_per_s, $row.load_s, $row.gpu_share, $row.vram_mb, $row.size_mb, $vram)
  return $row
}
function Unload($model) { $b = @{ model = $model; keep_alive = 0 } | ConvertTo-Json; Invoke-RestMethod -Uri "$api/api/generate" -Method Post -ContentType "application/json" -Body $b | Out-Null; Start-Sleep 3 }

$rows = @()
Log "`n== Speed test (same prompt, temperature 0, 200 tokens max)"
$base = @{ temperature = 0; seed = 42; num_predict = 200 }
foreach ($m in @("phi4-mini")) {
  $rows += Gen $m ($base + @{}) "warm-up (GPU)"
  foreach ($i in 1..3) { $rows += Gen $m ($base + @{}) "GPU run $i" }
  Log "`n== ollama ps while the GPU run is loaded"; Log ((& ollama ps 2>&1) -join "`n")
  Unload $m
  foreach ($i in 1..2) { $rows += Gen $m ($base + @{ num_gpu = 0 }) "CPU only run $i (num_gpu 0)" }
  Log "`n== ollama ps while the CPU-only run is loaded"; Log ((& ollama ps 2>&1) -join "`n")
  Unload $m
}
Log "`n== A model bigger than the 8 GB card: gemma4:26b (partly on GPU, partly on CPU)"
$rows += Gen "gemma4:26b" (@{ temperature = 0; seed = 42; num_predict = 100 }) "gemma4:26b auto split"
Log ((& ollama ps 2>&1) -join "`n")
Unload "gemma4:26b"
$rows | ConvertTo-Json -Depth 4 | Set-Content $json -Encoding utf8
Log "`nDone. Leave this window open for the screenshot."
Read-Host "Press Enter to close"
