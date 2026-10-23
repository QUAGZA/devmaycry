# Runs a windowed practice match with an autopilot and saves screenshots under build\shots.
# Usage: powershell -File tools\screenshot.ps1 [-Map oracle_gardens] [-Mode corebreak] [-At "3,6"] [-Auto circle] [-Bots]
param([string]$Map = "oracle_gardens", [string]$Mode = "corebreak", [string]$At = "3,6", [string]$Auto = "circle", [switch]$Bots, [int]$Seconds = 9)
$exe = $env:GODOT_GUI
if (-not $exe) { $exe = "C:\Users\risha\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" }
$proj = Split-Path -Parent $PSScriptRoot
$botFlag = if ($Bots) { "true" } else { "false" }
& $exe --path "$proj" --resolution 1280x720 --position 60,60 -- --role=host --practice --autostart=1 "--auto=$Auto" "--screenshot-at=$At" "--quit-after-sec=$Seconds" "--map=$Map" "--mode=$Mode" "--bots=$botFlag" --name=VIEWER
Get-ChildItem "$proj\build\shots"
