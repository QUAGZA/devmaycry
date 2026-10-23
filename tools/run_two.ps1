# Launches a windowed HOST and a windowed CLIENT on this machine (localhost) for manual play.
# Usage: powershell -File tools\run_two.ps1 [-Mode corebreak|relic_rush] [-Map oracle_gardens] [-Bots] [-TeamSize 2]
param([string]$Mode = "corebreak", [string]$Map = "oracle_gardens", [switch]$Bots, [int]$TeamSize = 2, [string]$Difficulty = "medium")
$exe = $env:GODOT_GUI
if (-not $exe) { $exe = "C:\Users\risha\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" }
$proj = Split-Path -Parent $PSScriptRoot
$botFlag = if ($Bots) { "true" } else { "false" }
Start-Process $exe -ArgumentList @("--path", "`"$proj`"", "--resolution", "1280x720", "--position", "40,60", "--", "--role=host", "--mode=$Mode", "--map=$Map", "--bots=$botFlag", "--team_size=$TeamSize", "--bot_difficulty=$Difficulty", "--name=HOST")
Start-Sleep -Seconds 3
Start-Process $exe -ArgumentList @("--path", "`"$proj`"", "--resolution", "1280x720", "--position", "700,120", "--", "--role=join", "--ip=127.0.0.1", "--name=GUEST")
Write-Host "Host and client windows launched. In the HOST window press START MATCH when the guest appears in the roster."
