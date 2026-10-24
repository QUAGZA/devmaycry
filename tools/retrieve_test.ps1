# Reverse Entropy shot-retrieval scenarios on the street maps (host = attacker ATK, client = defender DEF).
# ATK walks to a firing point, fires one shot at an empty spot, waits, then uses Reverse Entropy: the missed shot is
# retrieved and replayed from the muzzle along its recorded direction. DEF arrives on the line AFTER the shot was fired.
#   expect hit : DEF stands on the line in the open        -> exactly one replay hit
#   expect none: DEF stands on the line BEHIND a wall      -> the replay is stopped by the wall, no damage
# Usage: powershell -File tools\retrieve_test.ps1 [-Only oracle_hit]
param([string]$Only = "", [int]$PortBase = 25900)
$exe = $env:GODOT
if (-not $exe) { $exe = "C:\Users\risha\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" }
$proj = Split-Path -Parent $PSScriptRoot
$logs = Join-Path $proj "build\logs"
New-Item -ItemType Directory -Force $logs | Out-Null

# name, map, atk nav (x,z), aim point (x,y,z), def nav (x,z), def wait (s) before walking, expect
$scenarios = @(
  @{ n = "oracle_hit";    map = "oracle_gardens";    atk = "-48,-11"; aim = "-48,1.5,-22"; def = "-48,-21"; dw = 1.5;  expect = "hit" },
  @{ n = "oracle_wall";   map = "oracle_gardens";    atk = "-48,-11"; aim = "-48,1.5,0";   def = "-48,2";   dw = 1.5;  expect = "none" },
  @{ n = "tideline_hit";  map = "tideline_exchange"; atk = "-33,-1";  aim = "-16,1.5,-1";  def = "-20,-1";  dw = 10;  expect = "hit" },
  @{ n = "tideline_wall"; map = "tideline_exchange"; atk = "-33,0.5"; aim = "-44,1.5,0.5"; def = "-44,2";   dw = 2.5;  expect = "none" },
  @{ n = "foundry_hit";   map = "vector_foundry";    atk = "-36,0";   aim = "-26,1.5,0";   def = "-28,0";   dw = 12;  expect = "hit" },
  @{ n = "foundry_wall";  map = "vector_foundry";    atk = "-30,0";   aim = "-30,1.5,-9";  def = "-30,-8";  dw = 4;  expect = "none" }
)
$port = $PortBase
$fail = 0
foreach ($s in $scenarios) {
  if ($Only -ne "" -and $s.n -ne $Only) { continue }
  $port++
  $hostLog = Join-Path $logs ("retr_{0}_host.log" -f $s.n)
  $cliLog = Join-Path $logs ("retr_{0}_client.log" -f $s.n)
  $a = $s.atk.Split(","); $p = $s.aim.Split(","); $d = $s.def.Split(",")
  $atkSeq = "seq:nav,$($a[0]),$($a[1])+aim,$($p[0]),$($p[1]),$($p[2])+wait,12+fire,0.03+wait,6+ability+wait,12"
  $defSeq = "seq:wait,$($s.dw)+nav,$($d[0]),$($d[1])+wait,60"
  $hostArgs = @("--headless", "--path", "`"$proj`"", "--", "--role=host", "--port=$port", "--autostart=2", "--min_players=2", "--auto=$atkSeq", "--allow-empty-team", "--log-snap", "--quit-after-sec=52", "--mode=hot_return", "--map=$($s.map)", "--bots=false", "--team_size=1", "--name=ATK")
  $hp = Start-Process $exe -ArgumentList $hostArgs -RedirectStandardOutput $hostLog -RedirectStandardError (Join-Path $logs "retr_err.log") -PassThru -NoNewWindow
  Start-Sleep -Seconds 2
  $cliArgs = @("--headless", "--path", "`"$proj`"", "--", "--role=join", "--ip=127.0.0.1", "--port=$port", "--auto=$defSeq", "--quit-after-sec=50", "--name=DEF")
  $cp = Start-Process $exe -ArgumentList $cliArgs -RedirectStandardOutput $cliLog -RedirectStandardError (Join-Path $logs "retr_err2.log") -PassThru -NoNewWindow
  $hp.WaitForExit(); $cp.WaitForExit()
  $txt = Get-Content $hostLog -Raw
  $retrieved = ([regex]::Matches($txt, '"ev":"shot_retrieved"')).Count
  $replays = ([regex]::Matches($txt, '"ev":"replay_fire"')).Count
  $hits = ([regex]::Matches($txt, '"replay":true')).Count
  $errs = ([regex]::Matches($txt, 'SCRIPT ERROR')).Count
  $ok = ($errs -eq 0) -and ($retrieved -ge 1) -and ($replays -ge 1)
  if ($s.expect -eq "hit") { $ok = $ok -and ($hits -eq 1) } else { $ok = $ok -and ($hits -eq 0) }
  $status = if ($ok) { "PASS" } else { "FAIL"; $fail++ }
  Write-Host ("{0,-5} {1,-14} expect={2,-4} retrieved={3} replay_fire={4} replay_hits={5} script_errors={6}" -f $status, $s.n, $s.expect, $retrieved, $replays, $hits, $errs)
}
if ($fail -gt 0) { Write-Host "RETRIEVE SCENARIOS FAILED ($fail)"; exit 1 } else { Write-Host "RETRIEVE SCENARIOS PASSED"; exit 0 }






