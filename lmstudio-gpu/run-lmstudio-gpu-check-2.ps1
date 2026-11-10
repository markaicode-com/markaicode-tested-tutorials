# LM Studio GPU check, part 2 (2026-11-11). Read-only: no download, load, unload or delete; no settings changed.
# Adds: LM Studio app version, runtime help/survey (GPU detection), and memory estimates (--estimate-only, does NOT load).
# The model name is never logged: lines starting with "Model:" are replaced with "Model: (name withheld)".
# Log: lmstudio-gpu-check-2.log next to this script.
$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$here = $PSScriptRoot
$log = Join-Path $here "lmstudio-gpu-check-2.log"
Set-Content -Path $log -Value "" -Encoding utf8
function W($m) { Add-Content -Path $log -Value $m -Encoding utf8; Write-Host $m }
function Run([string]$exe, [string[]]$a) { $o = (& $exe @a 2>&1 | ForEach-Object { "$_" }) -join "`n"; return ($o -replace "\x1b\[[0-9;]*m", "").Trim() }
function Hide($t) { $r = (($t -split "`n") | ForEach-Object { if ($_ -match '^\s*Model:') { "Model: (name withheld)" } else { $_.TrimEnd() } }) -join "`n"; if ($script:key) { $r = $r.Replace($script:key, "(model)"); $leaf = ($script:key -split '[\\/]')[-1]; if ($leaf) { $r = $r.Replace($leaf, "(model)") } }; return $r }

W ("=== run " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"))
$lms = (Get-Command lms -ErrorAction SilentlyContinue).Source
if (-not $lms) { $lms = Join-Path $env:USERPROFILE ".lmstudio\bin\lms.exe" }
if (-not (Test-Path $lms)) { W "lms not found"; exit }

W "`n=== 1. LM Studio app version"
$cands = @("$env:LOCALAPPDATA\Programs\LM Studio\LM Studio.exe", "$env:ProgramFiles\LM Studio\LM Studio.exe")
$found = $false
foreach ($c in $cands) { if (Test-Path $c) { $v = (Get-Item $c).VersionInfo; W ("LM Studio.exe product version: " + $v.ProductVersion + " | install: " + ($(if ($c -like "$env:LOCALAPPDATA*") { "per-user" } else { "all users" }))); $found = $true } }
if (-not $found) { W "LM Studio.exe not found in the usual folders" }
W ("lms on PATH: " + [bool](Get-Command lms -ErrorAction SilentlyContinue))

W "`n=== 2. Runtime commands this build offers"
W (Run $lms @("runtime", "--help"))

W "`n=== 3. Runtime GPU survey (if supported)"
W (Run $lms @("runtime", "survey"))

W "`n=== 4. Selected runtime"
W (Run $lms @("runtime", "ls"))

W "`n=== 5. The model on disk: size and type only"
try { $j = (Run $lms @("ls", "--json")) | ConvertFrom-Json; $m = @($j)[0]
  W ("type: " + $m.type + " | format: " + $m.format + " | params: " + $m.paramsString + " | arch: " + $m.architecture + " | size GB: " + [Math]::Round($m.sizeBytes/1GB, 2))
  $key = $m.modelKey; if (-not $key) { $key = $m.path }
} catch { W "could not read lms ls --json"; $key = "" }

if ($key) {
  W "`n=== 6. Memory estimates, no load (default context, then 16384 tokens)"
  foreach ($g in @("max", "0.5", "off")) {
    W ("--- --gpu " + $g)
    W (Hide (Run $lms @("load", $key, "--estimate-only", "--gpu", $g)))
  }
  W "--- --gpu max --context-length 16384"
  W (Hide (Run $lms @("load", $key, "--estimate-only", "--gpu", "max", "--context-length", "16384")))
}

W "`n=== 7. Windows per-app GPU preference for LM Studio (read only)"
$k = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"
if (Test-Path $k) { $p = Get-ItemProperty $k; $hit = $p.PSObject.Properties | Where-Object { $_.Name -like "*LM Studio*" }; if ($hit) { $hit | ForEach-Object { W ("preference: " + $_.Value) } } else { W "no per-app GPU preference set for LM Studio (Windows default)" } } else { W "no per-app GPU preferences on this account" }

W "`n=== done"
