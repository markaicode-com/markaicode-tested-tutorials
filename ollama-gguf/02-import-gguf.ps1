# Markaicode tutorial run, step 2: import a GGUF file into Ollama with a Modelfile.
# DOWNLOADS about 0.4 GB from Hugging Face (Qwen/Qwen2.5-0.5B-Instruct-GGUF, file qwen2.5-0.5b-instruct-q4_k_m.gguf)
# into this folder, then creates the Ollama model "qwen25-05b-local". Run only after you agreed to the download.
$log = Join-Path $PSScriptRoot "02-import-gguf.log"
Start-Transcript -Path $log -Force | Out-Null
$gguf = Join-Path $PSScriptRoot "qwen2.5-0.5b-instruct-q4_k_m.gguf"
$url  = "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf"
if (-not (Test-Path $gguf)) { Write-Host "== Downloading $url" ; Invoke-WebRequest -Uri $url -OutFile $gguf }
Write-Host ("== GGUF file: {0} ({1:N0} MB)" -f (Split-Path $gguf -Leaf), ((Get-Item $gguf).Length/1MB))
$mf = Join-Path $PSScriptRoot "Modelfile"
@"
FROM ./qwen2.5-0.5b-instruct-q4_k_m.gguf
PARAMETER temperature 0.7
PARAMETER num_ctx 4096
"@ | Set-Content -Path $mf -Encoding ascii
Write-Host "`n== Modelfile" ; Get-Content $mf
Set-Location $PSScriptRoot
Write-Host "`n== ollama create qwen25-05b-local -f Modelfile" ; ollama create qwen25-05b-local -f Modelfile
Write-Host "`n== ollama list" ; ollama list
Write-Host "`n== ollama show qwen25-05b-local" ; ollama show qwen25-05b-local
Write-Host "`n== ollama run qwen25-05b-local" ; ollama run qwen25-05b-local "In one sentence, what is a GGUF file?"
Write-Host "`n== ollama ps" ; ollama ps
Stop-Transcript | Out-Null
Write-Host "`nDone. Leave this window open for the screenshot." -ForegroundColor Green
Read-Host "Press Enter to close"
