# LM Studio GPU check for /errors/lm-studio-gpu-not-detected-fix/ (2026-11-11).
# Read-only: it does NOT download, load, unload or delete models or runtimes, and changes no settings.
# Model names are never written to the log (counts only), except a model you pass with -Model.
# Optional: .\run-lmstudio-gpu-check.ps1 -Model "<model key>"  adds memory estimates (--estimate-only, no load).
# Log: lmstudio-gpu-check.log next to this script.
param([string]$Model = "")
$ErrorActionPreference = "Continue"
$here = $PSScriptRoot
$log = Join-Path $here "lmstudio-gpu-check.log"
Set-Content -Path $log -Value "" -Encoding utf8
function W($m) { Add-Content -Path $log -Value $m -Encoding utf8; Write-Host $m }
function Run([string]$exe, [string[]]$a) { $o = & $exe @a 2>&1 | Out-String; return $o.Trim() }

W ("=== run " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"))
W ("OS: " + (Get-CimInstance Win32_OperatingSystem).Caption + " build " + [Environment]::OSVersion.Version.Build)

W "`n=== 1. GPU and driver (name, driver, memory only; no process list)"
$smi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
if ($smi) { W (Run "nvidia-smi" @("--query-gpu=name,driver_version,memory.total", "--format=csv,noheader")) } else { W "nvidia-smi not found" }
Get-CimInstance Win32_VideoController | ForEach-Object { W ("display adapter: " + $_.Name + " | driver " + $_.DriverVersion) }

W "`n=== 2. Is lms available?"
$lms = (Get-Command lms -ErrorAction SilentlyContinue).Source
if (-not $lms) { $c = Join-Path $env:USERPROFILE ".lmstudio\bin\lms.exe"; if (Test-Path $c) { $lms = $c; W "lms not on PATH; found in .lmstudio\bin" } }
if (-not $lms) { W "lms not found: LM Studio is not installed for this user, or has never been opened."; W "`n=== done"; exit }
W ("lms found: " + (Split-Path $lms -Leaf))
W ("lms version: " + (Run $lms @("version")))

W "`n=== 3. LM Studio app / daemon status"
W (Run $lms @("status"))
W ("server status: " + (Run $lms @("server", "status")))

W "`n=== 4. Installed runtimes (lms runtime ls)"
W (Run $lms @("runtime", "ls"))

W "`n=== 5. Models on disk and loaded (counts only)"
$ls = Run $lms @("ls", "--json")
try { $j = $ls | ConvertFrom-Json; W ("models on disk: " + @($j).Count) } catch { W "could not parse lms ls --json (count skipped)" }
$ps = Run $lms @("ps", "--json")
try { $p = $ps | ConvertFrom-Json; W ("models loaded now: " + @($p).Count) } catch { W "could not parse lms ps --json (count skipped)" }

W "`n=== 6. lms load flags as documented by this build"
$h = Run $lms @("load", "--help")
($h -split "`n") | Where-Object { $_ -match "gpu|estimate|context" } | ForEach-Object { W $_.TrimEnd() }

if ($Model) {
  W "`n=== 7. Memory estimates for the model you passed (no load)"
  foreach ($g in @("max", "0.5", "off")) {
    W ("--gpu " + $g + ":")
    W (Run $lms @("load", $Model, "--estimate-only", "--gpu", $g))
  }
} else { W "`n=== 7. skipped (no -Model given)" }

W "`n=== done"
