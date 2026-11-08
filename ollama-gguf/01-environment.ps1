# Markaicode tutorial run, step 1: read-only environment check (changes nothing).
# Run: right-click > Run with PowerShell. Output is also saved to 01-environment.log next to this file.
$log = Join-Path $PSScriptRoot "01-environment.log"
Start-Transcript -Path $log -Force | Out-Null
Write-Host "== Date" ; Get-Date -Format "yyyy-MM-dd HH:mm zzz"
Write-Host "`n== Windows" ; (Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version | Format-List | Out-String).Trim()
Write-Host "`n== CPU and RAM" ; (Get-CimInstance Win32_Processor).Name ; "{0:N0} GB RAM" -f ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB)
Write-Host "`n== GPU" ; (Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion | Format-Table -AutoSize | Out-String).Trim()
if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) { Write-Host "`n== nvidia-smi" ; nvidia-smi }
Write-Host "`n== ollama --version" ; ollama --version
Write-Host "`n== ollama list" ; ollama list
Write-Host "`n== ollama ps" ; ollama ps
Stop-Transcript | Out-Null
Write-Host "`nDone. Leave this window open for the screenshot." -ForegroundColor Green
Read-Host "Press Enter to close"
