# Ollama Vulkan check for /intel-arc-gpu-ollama-openvino-tutorial/ (2026-11-13).
# Starts a SEPARATE, temporary Ollama server on 127.0.0.1:11435 several times with different GPU settings,
# runs one short prompt on phi4-mini (already installed), records speed and GPU use, then stops it.
# Your normal Ollama on port 11434 is not stopped or changed. Nothing is downloaded or deleted.
# Model names other than phi4-mini are never logged. User paths are replaced with %USERPROFILE%.
# Log: ollama-vulkan-check.log next to this script.
$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$here = $PSScriptRoot
$log = Join-Path $here "ollama-vulkan-check.log"
Set-Content -Path $log -Value "" -Encoding utf8
$up = $env:USERPROFILE
function Scrub([string]$m) { $m = $m.Replace($up, "%USERPROFILE%"); $m = $m.Replace($up.Replace("\", "\\"), "%USERPROFILE%"); $m = $m.Replace($up.Replace("\", "/"), "%USERPROFILE%"); return $m }
function W($m) { $m = Scrub ([string]$m); Add-Content -Path $log -Value $m -Encoding utf8; Write-Host $m }
function CurlExe([string[]]$a) { $o = (& curl.exe @a 2>&1 | ForEach-Object { "$_" }) -join "`n"; return $o.Trim() }

$model = "phi4-mini"
$port = "127.0.0.1:11435"
$ollama = (Get-Command ollama -ErrorAction SilentlyContinue).Source
if (-not $ollama) { W "ollama not found on PATH"; exit }

W ("=== run " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"))
W ("ollama: " + ((& ollama --version 2>&1) | Out-String).Trim())
$lib = Join-Path (Split-Path $ollama) "lib\ollama"
if (Test-Path $lib) { W ("GPU backends shipped (folders in lib\ollama): " + ((Get-ChildItem $lib -Directory | ForEach-Object { $_.Name }) -join ", ")) } else { W "lib\ollama folder not found next to ollama.exe" }
Get-CimInstance Win32_VideoController | ForEach-Object { W ("display adapter: " + $_.Name + " | driver " + $_.DriverVersion) }
$vi = Get-Command vulkaninfo -ErrorAction SilentlyContinue
if ($vi) { (& vulkaninfo --summary 2>&1 | Select-String -Pattern "deviceName|driverName|apiVersion" | ForEach-Object { W ("vulkaninfo: " + $_.Line.Trim()) }) } else { W "vulkaninfo not installed (optional)" }

$probe = CurlExe @("-s", "--max-time", "2", "http://$port/api/version")
if ($probe -match "version") { W "Port 11435 is already in use. Stop whatever is using it and run again."; exit }

$body = Join-Path $here "b-vk.json"
[System.IO.File]::WriteAllText($body, '{"model":"' + $model + '","prompt":"Write five sentences about the ocean.","stream":false,"keep_alive":"15s","options":{"temperature":0,"seed":1,"num_predict":160}}')

function RunVariant([string]$label, [hashtable]$envs) {
  W "`n=== $label"
  W ("settings: " + (($envs.GetEnumerator() | Sort-Object Name | ForEach-Object { $_.Name + "=" + $_.Value }) -join " "))
  $saved = @{}
  $all = @{ "OLLAMA_HOST" = $port } + $envs
  foreach ($k in $all.Keys) { $saved[$k] = [Environment]::GetEnvironmentVariable($k, "Process"); [Environment]::SetEnvironmentVariable($k, $all[$k], "Process") }
  $errf = Join-Path $here ("srv-" + ($label -replace "[^a-zA-Z0-9]", "") + ".err.txt")
  $outf = Join-Path $here ("srv-" + ($label -replace "[^a-zA-Z0-9]", "") + ".out.txt")
  $p = Start-Process -FilePath $ollama -ArgumentList "serve" -RedirectStandardError $errf -RedirectStandardOutput $outf -WindowStyle Hidden -PassThru
  foreach ($k in $all.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k], "Process") }
  $ok = $false
  for ($i = 0; $i -lt 30; $i++) { Start-Sleep -Seconds 1; if ((CurlExe @("-s", "--max-time", "2", "http://$port/api/version")) -match "version") { $ok = $true; break } }
  if (-not $ok) { W "server did not start"; Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; return $null }
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $r = CurlExe @("-s", "--max-time", "300", "-X", "POST", "http://$port/api/generate", "--data-binary", "@$body")
  $sw.Stop()
  $res = $null
  try {
    $j = $r | ConvertFrom-Json
    $tps = if ($j.eval_duration -gt 0) { [Math]::Round($j.eval_count / ($j.eval_duration / 1e9), 1) } else { 0 }
    $ps = (CurlExe @("-s", "http://$port/api/ps")) | ConvertFrom-Json
    $m = @($ps.models)[0]
    $pct = if ($m -and $m.size -gt 0) { [Math]::Round(100 * $m.size_vram / $m.size) } else { -1 }
    $sz = if ($m) { [Math]::Round($m.size / 1GB, 2) } else { 0 }
    W ("result: " + $j.eval_count + " tokens | " + $tps + " tok/s | load " + [Math]::Round($j.load_duration / 1e9, 1) + " s | wall " + [Math]::Round($sw.Elapsed.TotalSeconds, 1) + " s | in GPU memory: " + $pct + "% of " + $sz + " GB")
    $res = @{ tps = $tps; pct = $pct }
  } catch { W ("generate failed: " + $r.Substring(0, [Math]::Min(300, $r.Length))) }
  Get-CimInstance Win32_Process -Filter ("ParentProcessId=" + $p.Id) -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2
  $lines = @()
  if (Test-Path $errf) { $lines += Get-Content $errf -ErrorAction SilentlyContinue }
  if (Test-Path $outf) { $lines += Get-Content $outf -ErrorAction SilentlyContinue }
  $keep = $lines | Where-Object { $_ -match "inference compute|library=|ggml_vulkan|Vulkan[0-9]|offload|offloaded|layers|no compatible GPUs|error" -and $_ -notmatch "Users[\\/]" }
  W ("server log lines kept: " + @($keep).Count)
  $keep | Select-Object -First 25 | ForEach-Object { W ("  " + $_) }
  $script:lastlog = $lines -join "`n"
  Remove-Item $errf, $outf -ErrorAction SilentlyContinue
  return $res
}

# A: the normal setup Ollama picks by itself (CUDA available), for reference
RunVariant "A default (CUDA available)" @{} | Out-Null
# B: hide CUDA and ROCm so only Vulkan can use a GPU
RunVariant "B Vulkan only (CUDA and ROCm hidden)" @{ "CUDA_VISIBLE_DEVICES" = "-1"; "HIP_VISIBLE_DEVICES" = "-1" } | Out-Null
$vkLog = $script:lastlog
# C: Vulkan restricted to the integrated GPU, if we can find its Vulkan index in B's log
$idx = $null
foreach ($mm in [regex]::Matches($vkLog, 'Vulkan(\d+)[^\r\n]*?(Radeon|AMD|Intel)')) { $idx = $mm.Groups[1].Value; break }
if ($idx -ne $null) {
  RunVariant ("C Vulkan, integrated GPU only (Vulkan" + $idx + ")") @{ "CUDA_VISIBLE_DEVICES" = "-1"; "HIP_VISIBLE_DEVICES" = "-1"; "GGML_VK_VISIBLE_DEVICES" = $idx } | Out-Null
} else {
  W "`n=== C skipped: could not find the integrated GPU's Vulkan index in B's log; trying index 0 and 1"
  RunVariant "C0 Vulkan device 0 only" @{ "CUDA_VISIBLE_DEVICES" = "-1"; "HIP_VISIBLE_DEVICES" = "-1"; "GGML_VK_VISIBLE_DEVICES" = "0" } | Out-Null
  RunVariant "C1 Vulkan device 1 only" @{ "CUDA_VISIBLE_DEVICES" = "-1"; "HIP_VISIBLE_DEVICES" = "-1"; "GGML_VK_VISIBLE_DEVICES" = "1" } | Out-Null
}
# D: CPU only
RunVariant "D CPU only (Vulkan off, CUDA and ROCm hidden)" @{ "CUDA_VISIBLE_DEVICES" = "-1"; "HIP_VISIBLE_DEVICES" = "-1"; "OLLAMA_VULKAN" = "0" } | Out-Null

Remove-Item $body -ErrorAction SilentlyContinue
W "`n=== done"
