# Tutorial pilot 6: Ollama tool calling. Read-only for your system: it only creates files
# inside this folder (workspace\, 06-results.txt, 06-results.jsonl). Nothing is downloaded or installed.
$ErrorActionPreference = "Continue"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here
$log = Join-Path $here "06-results.txt"
$jsonl = Join-Path $here "06-results.jsonl"
Set-Content $log "Run $(Get-Date -Format s)" -Encoding UTF8
Set-Content $jsonl "" -Encoding UTF8
function L($t) { Add-Content $log $t -Encoding UTF8; Write-Host $t }
$api = "http://localhost:11434"

L "== A. Versions"
try { L ("ollama " + (Invoke-RestMethod "$api/api/version").version) } catch { L "Ollama not reachable: $_"; Read-Host "Start Ollama, then press Enter to exit"; exit }
$py = $null
foreach ($c in @("py","python","python3")) {
  if (Get-Command $c -ErrorAction SilentlyContinue) {
    $v = & $c -c "import sys;print(sys.version.split()[0])" 2>$null
    if ($LASTEXITCODE -eq 0 -and $v) { $py = $c; L "python: $c $v"; break }
  }
}
if (-not $py) { L "python: not found (using the PowerShell agent only)" }

L "== B. Which models support tools (/api/show capabilities)"
$models = @("phi4-mini","gemma4:e4b","qwen25-05b-local")
foreach ($m in $models) {
  try { $s = Invoke-RestMethod "$api/api/show" -Method Post -ContentType "application/json" -Body (@{model=$m} | ConvertTo-Json)
        L ("{0}: {1}  ({2}, {3})" -f $m, ($s.capabilities -join ","), $s.details.parameter_size, $s.details.quantization_level) }
  catch { L "${m}: show failed: $_" }
}

L "== C. Workspace"
$ws = Join-Path $here "workspace"; New-Item -ItemType Directory -Force $ws | Out-Null
Set-Content (Join-Path $ws "todo.txt") "[x] Renew domain`r`n[ ] Reply to supplier email`r`n[ ] Update price list`r`n[x] Back up laptop`r`n[ ] Book dentist" -Encoding UTF8
Set-Content (Join-Path $ws "notes.txt") "Team meeting, 3 Nov. We agreed to move the product launch from 20 Nov to 4 Dec because the payment page is not ready. Ana will finish the payment page by 25 Nov. Ben will update the launch email. Next meeting is on 10 Nov." -Encoding UTF8
Get-ChildItem $ws | ForEach-Object { L ("  {0} ({1} bytes)" -f $_.Name, $_.Length) }

$questions = @(
  "Which files are in my workspace?",
  "How many open tasks are in todo.txt? Open tasks start with [ ].",
  "Read notes.txt and save a one-sentence summary of it to summary.txt.",
  "What is the capital of France?"
)

# PowerShell version of the same agent loop (used when Python is missing, and once for comparison)
function Invoke-PsAgent($model, $question) {
  $tools = @(
    @{type="function";function=@{name="list_files";description="List the files in the user's workspace folder";parameters=@{type="object";properties=@{};required=@()}}},
    @{type="function";function=@{name="read_file";description="Read a text file from the workspace";parameters=@{type="object";properties=@{filename=@{type="string";description="File name, e.g. todo.txt"}};required=@("filename")}}},
    @{type="function";function=@{name="write_file";description="Create or overwrite a text file in the workspace";parameters=@{type="object";properties=@{filename=@{type="string";description="File name"};content=@{type="string";description="Full text to write"}};required=@("filename","content")}}}
  )
  $messages = [System.Collections.ArrayList]@(@{role="user";content=$question})
  $calls = @(); $sw = [Diagnostics.Stopwatch]::StartNew()
  for ($i = 0; $i -lt 6; $i++) {
    $body = @{model=$model;messages=$messages;tools=$tools;stream=$false;options=@{temperature=0}} | ConvertTo-Json -Depth 20
    $msg = (Invoke-RestMethod "$api/api/chat" -Method Post -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($body))).message
    [void]$messages.Add($msg)
    if (-not $msg.tool_calls) { return @{answer=$msg.content;calls=$calls;seconds=[math]::Round($sw.Elapsed.TotalSeconds,1)} }
    foreach ($tc in $msg.tool_calls) {
      $name = $tc.function.name; $a = $tc.function.arguments
      try {
        $result = switch ($name) {
          "list_files" { (Get-ChildItem $ws -File | ForEach-Object { "$($_.Name) ($($_.Length) bytes)" }) -join "`n" }
          "read_file"  { $p = [IO.Path]::GetFullPath((Join-Path $ws $a.filename)); if (-not $p.StartsWith($ws)) { throw "path outside the workspace" }; Get-Content $p -Raw }
          "write_file" { $p = [IO.Path]::GetFullPath((Join-Path $ws $a.filename)); if (-not $p.StartsWith($ws)) { throw "path outside the workspace" }; Set-Content $p $a.content -Encoding UTF8; "wrote $($a.content.Length) characters to $($a.filename)" }
          default      { "error: unknown tool $name" }
        }
      } catch { $result = "error: $_" }
      $calls += @{tool=$name;args=$a;result=("$result".Substring(0,[math]::Min(200,"$result".Length)))}
      [void]$messages.Add(@{role="tool";tool_name=$name;content="$result"})
    }
  }
  return @{answer="(stopped: too many tool rounds)";calls=$calls;seconds=[math]::Round($sw.Elapsed.TotalSeconds,1)}
}

L "== D. Runs"
$env:PYTHONIOENCODING = "utf-8"
foreach ($m in $models) {
  Set-Content (Join-Path $ws "summary.txt") "" -Encoding UTF8   # reset before each model
  foreach ($q in $questions) {
    L "--- $m | $q"
    try {
      if ($py) {
        $out = & $py (Join-Path $here "agent.py") $m $q --log $jsonl 2>&1 | Out-String
        L $out.Trim()
      } else {
        $r = Invoke-PsAgent $m $q; $r.model = $m; $r.question = $q
        $j = $r | ConvertTo-Json -Depth 10 -Compress; Add-Content $jsonl $j -Encoding UTF8; L $j
      }
    } catch { L "ERROR: $_" }
  }
  $sum = Get-Content (Join-Path $ws "summary.txt") -Raw
  L "summary.txt after ${m}: $sum"
}

L "== E. PowerShell agent, once, for comparison"
try { $r = Invoke-PsAgent "phi4-mini" $questions[1]; L ($r | ConvertTo-Json -Depth 10 -Compress) } catch { L "ERROR: $_" }

L "== F. Loaded models now"
try { (Invoke-RestMethod "$api/api/ps").models | ForEach-Object { L ("{0}  {1:N0} MB  vram {2:N0} MB  ctx {3}" -f $_.name, ($_.size/1MB), ($_.size_vram/1MB), $_.context_length) } } catch { L "ps failed: $_" }
L "Done $(Get-Date -Format s)"
Read-Host "Finished. Press Enter to close"
