# Tutorial pilot 6, run 2: gemma4:26b (already installed) + qwen25-05b-local again, files written without BOM.
# Creates files only inside this folder. Nothing is downloaded or installed.
$ErrorActionPreference = "Continue"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here
$log = Join-Path $here "06b-results.txt"; $jsonl = Join-Path $here "06b-results.jsonl"
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($log, "Run $(Get-Date -Format s)`r`n", $utf8); [IO.File]::WriteAllText($jsonl, "", $utf8)
function L($t) { [IO.File]::AppendAllText($log, "$t`r`n", $utf8); Write-Host $t }
$api = "http://localhost:11434"

L "== A. Installed models (gemma4, phi4, qwen25 only)"
(Invoke-RestMethod "$api/api/tags").models | Where-Object { $_.name -match '^(gemma4|phi4|qwen25)' } |
  ForEach-Object { L ("{0}  {1:N0} MB  {2}" -f $_.name, ($_.size/1MB), $_.details.parameter_size) }
foreach ($m in @("gemma4:26b","gemma4:e4b")) {
  try { $s = Invoke-RestMethod "$api/api/show" -Method Post -ContentType "application/json" -Body (@{model=$m} | ConvertTo-Json)
        L ("{0}: {1}  ({2}, {3})" -f $m, ($s.capabilities -join ","), $s.details.parameter_size, $s.details.quantization_level) }
  catch { L "${m}: show failed: $($_.ErrorDetails.Message)" }
}

$ws = Join-Path $here "workspace"; New-Item -ItemType Directory -Force $ws | Out-Null
function Reset-Workspace {
  [IO.File]::WriteAllText((Join-Path $ws "todo.txt"), "[x] Renew domain`n[ ] Reply to supplier email`n[ ] Update price list`n[x] Back up laptop`n[ ] Book dentist`n", $utf8)
  [IO.File]::WriteAllText((Join-Path $ws "notes.txt"), "Team meeting, 3 Nov. We agreed to move the product launch from 20 Nov to 4 Dec because the payment page is not ready. Ana will finish the payment page by 25 Nov. Ben will update the launch email. Next meeting is on 10 Nov.`n", $utf8)
  [IO.File]::WriteAllText((Join-Path $ws "summary.txt"), "", $utf8)
}
$questions = @(
  "Which files are in my workspace?",
  "How many open tasks are in todo.txt? Open tasks start with [ ].",
  "Read notes.txt and save a one-sentence summary of it to summary.txt.",
  "What is the capital of France?"
)
$env:PYTHONIOENCODING = "utf-8"
$runs = @(@("gemma4:26b",1),@("gemma4:26b",2),@("qwen25-05b-local",1))
foreach ($r in $runs) {
  $m = $r[0]; Reset-Workspace
  L "===== $m, round $($r[1])"
  foreach ($q in $questions) {
    L "--- $m | $q"
    $out = & py (Join-Path $here "agent.py") $m $q --log $jsonl 2>&1 | Out-String
    L $out.Trim()
  }
  L ("summary.txt: " + [IO.File]::ReadAllText((Join-Path $ws "summary.txt"), $utf8))
}
L "== Loaded models now"
(Invoke-RestMethod "$api/api/ps").models | Where-Object { $_.name -match '^(gemma4|phi4|qwen25)' } |
  ForEach-Object { L ("{0}  {1:N0} MB  vram {2:N0} MB  ctx {3}" -f $_.name, ($_.size/1MB), ($_.size_vram/1MB), $_.context_length) }
L "Done $(Get-Date -Format s)"
Read-Host "Finished. Press Enter to close"
