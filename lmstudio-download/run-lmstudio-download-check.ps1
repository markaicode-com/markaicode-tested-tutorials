# LM Studio download check for /errors/lm-studio-model-download-failed-fix/ (2026-11-12).
# Read-only: it does NOT download a model, import, delete or change any setting.
# Network test uses HEAD requests only (curl.exe -I), so no model file is downloaded.
# Model names on disk are never logged (counts and total size only). Paths are shown with %USERPROFILE%.
# Log: lmstudio-download-check.log next to this script.
$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$here = $PSScriptRoot
$log = Join-Path $here "lmstudio-download-check.log"
Set-Content -Path $log -Value "" -Encoding utf8
function W($m) { $m = [string]$m; $m = $m.Replace($env:USERPROFILE, "%USERPROFILE%"); $m = $m.Replace($env:USERPROFILE.Replace("\", "\\"), "%USERPROFILE%"); Add-Content -Path $log -Value $m -Encoding utf8; Write-Host $m }
function Run([string]$exe, [string[]]$a) { $o = (& $exe @a 2>&1 | ForEach-Object { "$_" }) -join "`n"; return ($o -replace "\x1b\[[0-9;]*m", "").Trim() }

W ("=== run " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"))
$exe = "$env:LOCALAPPDATA\Programs\LM Studio\LM Studio.exe"
if (Test-Path $exe) { W ("LM Studio.exe version: " + (Get-Item $exe).VersionInfo.ProductVersion) } else { W "LM Studio.exe not in the per-user folder" }
$lms = (Get-Command lms -ErrorAction SilentlyContinue).Source
if (-not $lms) { $lms = Join-Path $env:USERPROFILE ".lmstudio\bin\lms.exe" }

W "`n=== 1. Download and import commands in this build"
if (Test-Path $lms) {
  W (Run $lms @("get", "--help"))
  W "--- lms import --help"
  W (Run $lms @("import", "--help"))
} else { W "lms not found" }

W "`n=== 2. Where models live (counts and size only)"
foreach ($d in @("$env:USERPROFILE\.lmstudio\models", "$env:USERPROFILE\.cache\lm-studio\models")) {
  if (Test-Path $d) {
    $f = @(Get-ChildItem $d -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in ".gguf", ".safetensors" })
    $gb = [Math]::Round((($f | Measure-Object Length -Sum).Sum) / 1GB, 2)
    W ("$d : exists | model files: " + $f.Count + " | total GB: " + $gb)
  } else { W ("$d : not found") }
}

W "`n=== 3. Settings that mention proxy, Hugging Face, downloads or the models folder (keys and values)"
foreach ($s in @("$env:USERPROFILE\.lmstudio\settings.json", "$env:USERPROFILE\.lmstudio\.internal\app-settings.json")) {
  if (Test-Path $s) {
    W ("file: " + $s)
    try {
      $j = Get-Content $s -Raw | ConvertFrom-Json
      $j.PSObject.Properties | Where-Object { $_.Name -match "proxy|hugging|hf|download|model.*(dir|folder|path)|downloadsFolder" } | ForEach-Object { W ("  " + $_.Name + " = " + ($_.Value | ConvertTo-Json -Compress -Depth 3)) }
    } catch { W "  could not parse" }
  } else { W ("not found: " + $s) }
}
$hits = Get-ChildItem "$env:USERPROFILE\.lmstudio" -Filter *.json -Recurse -Depth 2 -ErrorAction SilentlyContinue | Select-String -Pattern "HfProxy|hfProxy|huggingFaceProxy|useHuggingFaceProxy" -List -ErrorAction SilentlyContinue
foreach ($h in $hits) { W ("proxy key found in: " + $h.Path + " -> " + $h.Line.Trim().Substring(0, [Math]::Min(160, $h.Line.Trim().Length))) }

W "`n=== 4. Free space on the models drive"
$drive = (Get-Item "$env:USERPROFILE").PSDrive.Name
$pd = Get-PSDrive $drive
W ("drive " + $drive + ": free GB " + [Math]::Round($pd.Free / 1GB, 1))

W "`n=== 5. Can this PC reach Hugging Face? (HEAD requests only, nothing downloaded)"
$api = "https://huggingface.co/api/models/Qwen/Qwen2.5-0.5B-Instruct-GGUF"
W ("API: " + (Run "curl.exe" @("-s", "-o", "NUL", "-I", "--max-time", "20", "-w", "HTTP %{http_code} in %{time_total}s", $api)))
$file = "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf"
$o = Run "curl.exe" @("-s", "-o", "NUL", "-I", "--max-time", "20", "-w", "%{http_code} %{redirect_url}", $file)
$code, $to = $o -split " ", 2
$toHost = ""; if ($to) { try { $toHost = ([uri]$to).Host } catch { $toHost = "?" } }
W ("file URL: HTTP " + $code + " | redirects to host: " + $toHost)
$o = Run "curl.exe" @("-s", "-o", "NUL", "-I", "-L", "--max-time", "30", "-w", "%{http_code} %{num_redirects} %{time_total} %{url_effective}", $file)
$p = $o -split " ", 4
$fh = ""; if ($p.Count -ge 4) { try { $fh = ([uri]$p[3]).Host } catch { $fh = "?" } }
W ("follow redirects: final HTTP " + $p[0] + " | redirects " + $p[1] + " | " + $p[2] + "s | final host " + $fh)
foreach ($h in @("huggingface.co", "cdn-lfs.huggingface.co", "cdn-lfs-us-1.hf.co", "cas-bridge.xethub.hf.co", "lmstudio.ai")) {
  try { $ip = (Resolve-DnsName $h -Type A -ErrorAction Stop | Where-Object { $_.Type -eq "A" } | Select-Object -First 1).IPAddress; W ("DNS " + $h + " -> resolves (" + ($(if ($ip) { "A record" } else { "CNAME only" })) + ")") } catch { W ("DNS " + $h + " -> does not resolve") }
}

W "`n=== done"
