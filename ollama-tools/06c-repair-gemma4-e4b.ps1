# Repair gemma4:e4b (owner approved the download on 2026-11-07), then check it and run the 4 agent tasks once.
$ErrorActionPreference = "Continue"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here
$log = Join-Path $here "06c-results.txt"
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($log, "Run $(Get-Date -Format s)`r`n", $utf8)
function L($t) { [IO.File]::AppendAllText($log, "$t`r`n", $utf8); Write-Host $t }
$api = "http://localhost:11434"

L "== 1. ollama pull gemma4:e4b (progress shows in this window)"
$sw = [Diagnostics.Stopwatch]::StartNew()
ollama pull gemma4:e4b
L ("pull exit code {0}, {1:N0} s" -f $LASTEXITCODE, $sw.Elapsed.TotalSeconds)

L "== 2. ollama show"
try { $s = Invoke-RestMethod "$api/api/show" -Method Post -ContentType "application/json" -Body (@{model="gemma4:e4b"} | ConvertTo-Json)
      L ("gemma4:e4b: {0}  ({1}, {2})" -f ($s.capabilities -join ","), $s.details.parameter_size, $s.details.quantization_level) }
catch { L "show failed: $($_.ErrorDetails.Message)" }

L "== 3. Agent tasks"
$ws = Join-Path $here "workspace"; New-Item -ItemType Directory -Force $ws | Out-Null
[IO.File]::WriteAllText((Join-Path $ws "todo.txt"), "[x] Renew domain`n[ ] Reply to supplier email`n[ ] Update price list`n[x] Back up laptop`n[ ] Book dentist`n", $utf8)
[IO.File]::WriteAllText((Join-Path $ws "notes.txt"), "Team meeting, 3 Nov. We agreed to move the product launch from 20 Nov to 4 Dec because the payment page is not ready. Ana will finish the payment page by 25 Nov. Ben will update the launch email. Next meeting is on 10 Nov.`n", $utf8)
[IO.File]::WriteAllText((Join-Path $ws "summary.txt"), "", $utf8)
$env:PYTHONIOENCODING = "utf-8"
foreach ($q in @("Which files are in my workspace?","How many open tasks are in todo.txt? Open tasks start with [ ].","Read notes.txt and save a one-sentence summary of it to summary.txt.","What is the capital of France?")) {
  L "--- gemma4:e4b | $q"
  $out = & py (Join-Path $here "agent.py") "gemma4:e4b" $q --log (Join-Path $here "06c-results.jsonl") 2>&1 | Out-String
  L $out.Trim()
}
L ("summary.txt: " + [IO.File]::ReadAllText((Join-Path $ws "summary.txt"), $utf8))
try { (Invoke-RestMethod "$api/api/ps").models | Where-Object { $_.name -like "gemma4*" } | ForEach-Object { L ("{0}  {1:N0} MB  vram {2:N0} MB  ctx {3}" -f $_.name, ($_.size/1MB), ($_.size_vram/1MB), $_.context_length) } } catch {}
L "Done $(Get-Date -Format s)"
Read-Host "Finished. Press Enter to close"
