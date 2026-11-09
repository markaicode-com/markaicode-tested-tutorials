# Ollama API + curl test run for /curl-commands-ollama-api-testing-tutorial/ (2026-11-10).
# Read-only against your normal Ollama server on port 11434: it lists, shows and chats with phi4-mini.
# It does NOT pull, copy, delete or unload models and does not change any setting.
# Model names other than phi4-mini are never written to the log (only a count).
# Log: curl-tests.log next to this script.
# Note: the helper is not called "Curl" because in Windows PowerShell 5 "curl" is an alias for Invoke-WebRequest, and aliases win over functions.
$ErrorActionPreference = "Continue"
$here = $PSScriptRoot
$log = Join-Path $here "curl-tests.log"
Set-Content -Path $log -Value "" -Encoding utf8
function W($m) { Add-Content -Path $log -Value $m -Encoding utf8; Write-Host $m }
function Body($name, $json) { $p = Join-Path $here $name; [System.IO.File]::WriteAllText($p, $json); return $p }
function Invoke-CurlExe([string[]]$a) { $out = & curl.exe @a 2>&1 | Out-String; return $out.Trim() }
$base = "http://localhost:11434"
$model = "phi4-mini"

W ("=== run " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"))
W ("PowerShell " + $PSVersionTable.PSVersion.ToString())
W ("curl.exe: " + ((& curl.exe --version 2>&1 | Select-Object -First 1) | Out-String).Trim())
W ("ollama: " + ((& ollama --version 2>&1) | Out-String).Trim())

W "`n=== 1. version"
$ver = Invoke-CurlExe @("-s", "$base/api/version")
if (-not $ver) { W "Ollama is not answering on $base. Start the Ollama app (or run: ollama serve) and run this script again."; exit 1 }
W $ver

W "`n=== 2. tags (installed models: count only, plus whether phi4-mini is present)"
$tags = Invoke-CurlExe @("-s", "$base/api/tags")
try { $t = $tags | ConvertFrom-Json; $names = @($t.models | ForEach-Object { $_.name }); W ("models installed: " + $names.Count); W ("phi4-mini present: " + [bool]($names -match '^phi4-mini')); W ("fields on one model: " + (($t.models[0].PSObject.Properties.Name) -join ", ")) } catch { W ("could not parse tags: " + $tags.Substring(0, [Math]::Min(200, $tags.Length))) }

W "`n=== 3. ps (loaded models: count only)"
$ps = Invoke-CurlExe @("-s", "$base/api/ps")
try { $p = $ps | ConvertFrom-Json; W ("loaded models: " + @($p.models).Count) } catch { W "could not parse ps" }

W "`n=== 4. show phi4-mini (top-level keys, details, capabilities)"
$b = Body "b-show.json" ('{"model":"' + $model + '"}')
$show = Invoke-CurlExe @("-s", "-X", "POST", "$base/api/show", "--data-binary", "@$b")
try { $s = $show | ConvertFrom-Json; W ("keys: " + (($s.PSObject.Properties.Name) -join ", ")); W ("details: " + ($s.details | ConvertTo-Json -Compress)); W ("capabilities: " + (($s.capabilities) -join ", ")) } catch { W ("show raw: " + $show.Substring(0, [Math]::Min(300, $show.Length))) }

W "`n=== 5. chat, non-streaming, temperature 0 (run twice: first may include load time)"
$b = Body "b-chat.json" ('{"model":"' + $model + '","messages":[{"role":"user","content":"Reply with exactly: OK"}],"stream":false,"options":{"temperature":0}}')
foreach ($i in 1..2) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $r = Invoke-CurlExe @("-s", "-X", "POST", "$base/api/chat", "--data-binary", "@$b")
  $sw.Stop()
  try { $j = $r | ConvertFrom-Json
    $tps = if ($j.eval_duration -gt 0) { [Math]::Round($j.eval_count / ($j.eval_duration / 1e9), 1) } else { 0 }
    W ("run $i wall " + $sw.ElapsedMilliseconds + " ms | answer: " + $j.message.content.Trim() + " | done_reason " + $j.done_reason + " | load " + [Math]::Round($j.load_duration/1e6) + " ms | prompt_eval_count " + $j.prompt_eval_count + " | eval_count " + $j.eval_count + " | " + $tps + " tok/s")
    if ($i -eq 1) { W ("response keys: " + (($j.PSObject.Properties.Name) -join ", ")) }
  } catch { W ("chat raw: " + $r.Substring(0, [Math]::Min(300, $r.Length))) }
}

W "`n=== 6. chat, streaming (default): count lines, show first and last"
$b = Body "b-stream.json" ('{"model":"' + $model + '","messages":[{"role":"user","content":"Count from 1 to 5, separated by spaces."}],"options":{"temperature":0}}')
$raw = & curl.exe -s -N -X POST "$base/api/chat" --data-binary "@$b" 2>&1
$lines = @($raw | Where-Object { $_ -and $_.Trim() })
W ("stream lines: " + $lines.Count)
if ($lines.Count -gt 0) { W ("first: " + $lines[0]); W ("last: " + $lines[-1].Substring(0, [Math]::Min(400, $lines[-1].Length))) }

W "`n=== 7. generate endpoint, non-streaming"
$b = Body "b-gen.json" ('{"model":"' + $model + '","prompt":"Reply with exactly: OK","stream":false,"options":{"temperature":0}}')
$r = Invoke-CurlExe @("-s", "-X", "POST", "$base/api/generate", "--data-binary", "@$b")
try { $j = $r | ConvertFrom-Json; W ("response: " + $j.response.Trim() + " | keys: " + (($j.PSObject.Properties.Name) -join ", ")) } catch { W ("generate raw: " + $r.Substring(0, [Math]::Min(300, $r.Length))) }

W "`n=== 8. OpenAI-compatible endpoints"
$m = Invoke-CurlExe @("-s", "$base/v1/models")
try { $mm = $m | ConvertFrom-Json; W ("/v1/models object=" + $mm.object + " count=" + @($mm.data).Count) } catch { W ("/v1/models raw: " + $m.Substring(0, [Math]::Min(200, $m.Length))) }
$b = Body "b-oai.json" ('{"model":"' + $model + '","messages":[{"role":"user","content":"Reply with exactly: OK"}],"temperature":0}')
$r = Invoke-CurlExe @("-s", "-X", "POST", "$base/v1/chat/completions", "-H", "Content-Type: application/json", "--data-binary", "@$b")
try { $j = $r | ConvertFrom-Json; W ("/v1/chat/completions object=" + $j.object + " | answer: " + $j.choices[0].message.content.Trim() + " | usage: " + ($j.usage | ConvertTo-Json -Compress)) } catch { W ("oai raw: " + $r.Substring(0, [Math]::Min(300, $r.Length))) }

W "`n=== 9. errors: status code and body"
$b = Body "b-missing.json" '{"model":"no-such-model-xyz","messages":[{"role":"user","content":"hi"}],"stream":false}'
W ("missing model: " + (Invoke-CurlExe @("-s", "-w", "  [HTTP %{http_code}]", "-X", "POST", "$base/api/chat", "--data-binary", "@$b")))
$b = Body "b-bad.json" '{"model":"phi4-mini","messages":[{"role":"user","content":"hi"}'
W ("broken JSON: " + (Invoke-CurlExe @("-s", "-w", "  [HTTP %{http_code}]", "-X", "POST", "$base/api/chat", "--data-binary", "@$b")))
W ("GET on /api/chat: " + (Invoke-CurlExe @("-s", "-w", "  [HTTP %{http_code}]", "$base/api/chat")))
W ("wrong port 11435: " + (Invoke-CurlExe @("-s", "-w", "  [HTTP %{http_code} exit]", "--max-time", "5", "http://localhost:11435/api/tags")) + " | curl exit code " + $LASTEXITCODE)

W "`n=== 10. PowerShell quoting pitfall: inline JSON with -d"
$inline = & curl.exe -s -w "  [HTTP %{http_code}]" -X POST "$base/api/chat" -d '{"model":"phi4-mini","messages":[{"role":"user","content":"hi"}],"stream":false}' 2>&1 | Out-String
W ("inline -d in PowerShell " + $PSVersionTable.PSVersion.Major + ": " + $inline.Trim().Substring(0, [Math]::Min(300, $inline.Trim().Length)))
W "Invoke-RestMethod equivalent:"
try { $irm = Invoke-RestMethod -Method Post -Uri "$base/api/chat" -ContentType "application/json" -Body (@{ model = $model; messages = @(@{ role = "user"; content = "Reply with exactly: OK" }); stream = $false; options = @{ temperature = 0 } } | ConvertTo-Json -Depth 5); W ("Invoke-RestMethod answer: " + $irm.message.content.Trim()) } catch { W ("Invoke-RestMethod error: " + $_.Exception.Message) }

W "`n=== 11. timing with curl -w"
$b = Join-Path $here "b-chat.json"
W (Invoke-CurlExe @("-s", "-o", "NUL", "-w", "connect %{time_connect}s | first byte %{time_starttransfer}s | total %{time_total}s | HTTP %{http_code}", "-X", "POST", "$base/api/chat", "--data-binary", "@$b"))

Get-ChildItem $here -Filter "b-*.json" | Remove-Item -ErrorAction SilentlyContinue
W "`n=== done"
