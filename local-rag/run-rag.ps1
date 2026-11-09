# Local RAG test for the "local RAG with Ollama and LangChain" tutorial.
# Downloads (approved by the owner): Python packages into a private .venv in this folder
# (langchain, langchain-community, langchain-ollama, langchain-text-splitters, faiss-cpu, pypdf, fpdf2),
# and the Ollama embedding model nomic-embed-text (about 274 MB). Generation uses gemma4:e4b, already installed.
# Uses a temporary Ollama server on port 11500; your normal Ollama on 11434 is not changed.
$here = $PSScriptRoot; Set-Location $here
$txt = Join-Path $here "run.log"; Set-Content -Path $txt -Value "" -Encoding utf8
function L($m) { Write-Host $m; Add-Content -Path $txt -Value $m -Encoding utf8 }
function RunLog($exe, $argv) { $out = & $exe @argv 2>&1 | Out-String; foreach ($l in ($out -split "`r?`n")) { if ($l.Trim()) { L ("  " + $l) } } }
$py = $null
foreach ($c in @("py", "python", "python3")) { try { $v = & $c --version 2>&1 | Out-String } catch { $v = $null }; if ($LASTEXITCODE -eq 0 -and $v -match "Python 3") { $py = $c; break } }
if (-not $py) { L "python 3 not found"; Read-Host "Enter to close"; exit 1 }
$env:PYTHONIOENCODING = "utf-8"
L ("date: " + (Get-Date -Format "yyyy-MM-dd HH:mm")); L ("python: " + ((& $py --version 2>&1) -join " ")); L ("ollama: " + ((& ollama --version 2>&1) -join " "))
L "`n== 1. Python packages into .venv"
if (-not (Test-Path ".venv")) { & $py -m venv .venv }
$vpy = Join-Path $here ".venv\Scripts\python.exe"
RunLog $vpy @("-m", "pip", "install", "--quiet", "--upgrade", "pip")
RunLog $vpy @("-m", "pip", "install", "--quiet", "langchain", "langchain-community", "langchain-ollama", "langchain-text-splitters", "faiss-cpu", "pypdf", "fpdf2")
(& $vpy -m pip list --format=freeze 2>&1) | Where-Object { $_ -match "^(langchain|langchain-core|langchain-community|langchain-ollama|langchain-text-splitters|langchain-classic|faiss-cpu|pypdf|fpdf2)==" } | ForEach-Object { L ("  " + $_) }
L "`n== 2. Temporary Ollama server and the embedding model"
$env:OLLAMA_HOST = "127.0.0.1:11500"; $env:OLLAMA_CONTEXT_LENGTH = "8192"
$p = Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden -PassThru -RedirectStandardError (Join-Path $here "server.log") -RedirectStandardOutput (Join-Path $here "server.out")
Start-Sleep 6
& ollama pull nomic-embed-text 2>&1 | Select-Object -Last 2 | ForEach-Object { L ("  " + $_) }
(& ollama list 2>&1) | Where-Object { $_ -match "NAME|nomic|gemma4:e4b" } | ForEach-Object { L ("  " + $_) }
L "`n== 3. Old imports"
RunLog $vpy @("check_legacy.py")
L "`n== 4. Sample PDF"
New-Item -ItemType Directory -Force -Path docs | Out-Null
RunLog $vpy @("make_pdf.py")
L "`n== 5. Ingest"
RunLog $vpy @("ingest.py")
Get-ChildItem faiss_index | ForEach-Object { L ("  " + $_.Name + "  " + $_.Length + " bytes") }
L "`n== 6. Questions (gemma4:e4b)"
RunLog $vpy @("query.py", "gemma4:e4b")
L "`n== 7. ollama ps"
(& ollama ps 2>&1) | ForEach-Object { L ("  " + $_) }
& taskkill /PID $p.Id /T /F | Out-Null
L "`nDone. Temporary server stopped; your normal Ollama on port 11434 was not changed."
Read-Host "Press Enter to close"
