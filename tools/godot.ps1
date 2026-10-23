# Wrapper: runs the Godot 4.7.2 console binary against this project.
# Usage: powershell -File tools\godot.ps1 <godot args...>
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest)
$exe = $env:GODOT
if (-not $exe) { $exe = "C:\Users\risha\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" }
if (-not (Test-Path $exe)) { Write-Error "Godot not found at $exe. Set the GODOT environment variable."; exit 2 }
$proj = Split-Path -Parent $PSScriptRoot
& $exe --path $proj @Rest
exit $LASTEXITCODE
