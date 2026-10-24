# Bot soak: a headless practice match with bots on each map, then a summary of what happened (rounds, kills,
# Core pickups/drops/detonations/stabilizations, ladder and cable use, bot stuck recoveries, script errors).
# Usage: powershell -File tools\bot_soak.ps1 [-Seconds 120] [-Difficulty medium]
param([int]$Seconds = 120, [string]$Difficulty = "medium", [int]$Port = 25100, [string[]]$Maps = @("oracle_gardens", "tideline_exchange", "vector_foundry"))
$exe = $env:GODOT
if (-not $exe) { $exe = "C:\Users\risha\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" }
$proj = Split-Path -Parent $PSScriptRoot
$logs = Join-Path $proj "build\logs"
New-Item -ItemType Directory -Force $logs | Out-Null
$fail = 0
$i = 0
foreach ($m in $Maps) {
  $i++
  $log = Join-Path $logs "soak_$m.log"
  $a = @("--headless", "--path", "`"$proj`"", "--", "--role=host", "--port=$($Port + $i)", "--practice", "--autostart=1", "--map=$m", "--mode=hot_return", "--bots=true", "--bot_difficulty=$Difficulty", "--team_size=3", "--auto=idle", "--quit-after-sec=$Seconds", "--name=SOAK")
  $p = Start-Process $exe -ArgumentList $a -RedirectStandardOutput $log -RedirectStandardError (Join-Path $logs "soak_err.log") -PassThru -NoNewWindow
  $p.WaitForExit()
  $t = Get-Content $log -Raw
  function Count($pat) { ([regex]::Matches($t, $pat)).Count }
  $errs = Count 'SCRIPT ERROR'
  $row = [ordered]@{
    rounds_started = Count '"cat":"Round","ev":"start"'
    kills = Count '"cat":"Round","cause"'
    pickups = Count '"cat":"Objective","ev":"pickup"'
    detonations = Count '"cat":"Objective","ev":"detonation"'
    stabilized = Count '"ev":"stabilized"|"reason":"stabilized"'
    ladder_use = Count '"ev":"ladder_enter"'
    zip_rides = Count '"ev":"zip_attach"'
    pad_launches = Count '"ev":"sling"'
    gate_uses = Count '"ev":"gate"'
    bot_stuck = Count '"cat":"Bot","ev":"stuck_jump"'
    goals_abandoned = Count '"ev":"goal_abandoned"'
    script_errors = $errs
  }
  Write-Host ("{0,-18} {1}" -f $m, (($row.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "  "))
  if ($errs -gt 0) { $fail++ }
}
if ($fail -gt 0) { Write-Host "BOT SOAK: script errors"; exit 1 } else { Write-Host "BOT SOAK COMPLETED"; exit 0 }
