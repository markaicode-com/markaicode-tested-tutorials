# Copilot agent mode tutorial, step 1: check VS Code, the Copilot extension, Node and Git, and make a test folder.
# Read-only except for creating the folder agent-test next to this script. Prints no tokens or account details.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$log = Join-Path $here "01-check-vscode.log"
function L($m) { Write-Host $m; Add-Content -Path $log -Value $m -Encoding utf8 }
Set-Content -Path $log -Value "" -Encoding utf8
L ("date: " + (Get-Date -Format "yyyy-MM-dd HH:mm"))
L ("windows: " + (Get-CimInstance Win32_OperatingSystem).Caption + " build " + [Environment]::OSVersion.Version.Build)
# Look for VS Code itself first: on this PC the "code" command on PATH may open Cursor instead.
$code = $null
foreach ($p in @("$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd", "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd", "${env:ProgramFiles(x86)}\Microsoft VS Code\bin\code.cmd")) { if (Test-Path $p) { $code = Get-Item $p; break } }
$onPath = Get-Command code -ErrorAction SilentlyContinue
if ($onPath) { L ("'code' on PATH points to: " + $onPath.Source) }
if ($code) {
  $c = if ($code.Source) { $code.Source } else { $code.FullName }
  L ("vscode path: " + $c)
  L "vscode --version:"; (& $c --version 2>&1) | ForEach-Object { L ("  " + $_) }
  L "copilot / chat extensions:"; (& $c --list-extensions --show-versions 2>&1) | Where-Object { $_ -match "copilot|chat" } | ForEach-Object { L ("  " + $_) }
} else { L "vscode: not found (install from https://code.visualstudio.com/)" }
foreach ($t in @("node", "npm", "git")) {
  $g = Get-Command $t -ErrorAction SilentlyContinue
  if ($g) { L ($t + " " + ((& $t --version 2>&1) | Select-Object -First 1)) } else { L ("" + $t + ": not found") }
}
$settings = Join-Path $env:APPDATA "Code\User\settings.json"
if (Test-Path $settings) {
  L "user settings with chat.* or copilot keys:"
  Get-Content $settings | Where-Object { $_ -match '"(chat\.|github\.copilot)' } | ForEach-Object { L ("  " + $_.Trim()) }
} else { L "user settings.json: not found" }
$t = Join-Path $here "agent-test"
New-Item -ItemType Directory -Force -Path $t | Out-Null
L ("test folder: " + $t)
L "done"
Write-Host "Finished. Log: $log"
Read-Host "Press Enter to close"
