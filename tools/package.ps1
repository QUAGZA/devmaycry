# Installs the 4.7.2 export templates (from a downloaded .tpz or by downloading) and exports build\EchoClash.exe.
# Usage: powershell -File tools\package.ps1 [-Tpz "path\to\Godot_v4.7.2-stable_export_templates.tpz"]
param([string]$Tpz = "")
$exe = $env:GODOT
if (-not $exe) { $exe = "C:\Users\risha\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" }
$proj = Split-Path -Parent $PSScriptRoot
$tplRoot = Join-Path $env:APPDATA "Godot\export_templates"
$tplDir = Join-Path $tplRoot "4.7.2.stable"
if (-not (Test-Path (Join-Path $tplDir "windows_release_x86_64.exe"))) {
  if ($Tpz -eq "") { $Tpz = Join-Path $tplRoot "4.7.2.tpz" }
  if (-not (Test-Path $Tpz)) {
    Write-Host "Downloading export templates (about 1.1 GB)..."
    New-Item -ItemType Directory -Force $tplRoot | Out-Null
    Invoke-WebRequest -Uri "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz" -OutFile $Tpz
  }
  Write-Host "Extracting templates to $tplDir"
  $tmp = Join-Path $tplRoot "_extract"
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
  Copy-Item $Tpz "$Tpz.zip" -Force
  Expand-Archive -Path "$Tpz.zip" -DestinationPath $tmp -Force
  Remove-Item "$Tpz.zip" -Force
  New-Item -ItemType Directory -Force $tplDir | Out-Null
  Copy-Item (Join-Path $tmp "templates\*") $tplDir -Recurse -Force
  Remove-Item -Recurse -Force $tmp
}
New-Item -ItemType Directory -Force (Join-Path $proj "build") | Out-Null
& $exe --headless --path $proj --import
& $exe --headless --path $proj --export-release "Windows Desktop" (Join-Path $proj "build\EchoClash.exe")
if ($LASTEXITCODE -ne 0) { Write-Host "EXPORT FAILED ($LASTEXITCODE)"; exit 1 }
Get-ChildItem (Join-Path $proj "build") -Filter "EchoClash*"
Write-Host "Exported build\EchoClash.exe"
