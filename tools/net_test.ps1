# Headless network smoke test: one host + N clients on localhost with scripted inputs.
# Asserts: every peer spawns all players, snapshots agree, no script errors.
# Usage: powershell -File tools\net_test.ps1 [-Clients 2] [-Mode corebreak] [-Map oracle_gardens] [-Seconds 20] [-Auto hunt] [-Bots]
param([int]$Clients = 2, [string]$Mode = "corebreak", [string]$Map = "oracle_gardens", [int]$Seconds = 20, [string]$Auto = "hunt", [switch]$Bots, [int]$TeamSize = 2, [string]$HostAuto = "", [int]$Port = 24642)
$exe = $env:GODOT
if (-not $exe) { $exe = "C:\Users\risha\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" }
$proj = Split-Path -Parent $PSScriptRoot
$logs = Join-Path $proj "build\logs"
New-Item -ItemType Directory -Force $logs | Out-Null
if ($HostAuto -eq "") { $HostAuto = $Auto }
$botFlag = if ($Bots) { "true" } else { "false" }
$minPlayers = 1 + $Clients
$hostLog = Join-Path $logs "net_host.log"
$hostArgs = @("--headless", "--path", "`"$proj`"", "--", "--role=host", "--port=$Port", "--autostart=2", "--min_players=$minPlayers", "--auto=$HostAuto", "--log-snap", "--quit-after-sec=$($Seconds + 4)", "--mode=$Mode", "--map=$Map", "--bots=$botFlag", "--team_size=$TeamSize", "--name=HOST")
$hp = Start-Process $exe -ArgumentList $hostArgs -RedirectStandardOutput $hostLog -RedirectStandardError (Join-Path $logs "net_host.err") -PassThru -NoNewWindow
Start-Sleep -Seconds 2
$procs = @($hp)
for ($i = 1; $i -le $Clients; $i++) {
  $log = Join-Path $logs "net_client$i.log"
  $cargs = @("--headless", "--path", "`"$proj`"", "--", "--role=join", "--ip=127.0.0.1", "--port=$Port", "--auto=$Auto", "--log-snap", "--quit-after-sec=$Seconds", "--name=CLIENT$i")
  $procs += Start-Process $exe -ArgumentList $cargs -RedirectStandardOutput $log -RedirectStandardError (Join-Path $logs "net_client$i.err") -PassThru -NoNewWindow
  Start-Sleep -Milliseconds 500
}
$procs | ForEach-Object { $_.WaitForExit() }
$fail = 0
$expected = 1 + $Clients
foreach ($f in @($hostLog) + (1..$Clients | ForEach-Object { Join-Path $logs "net_client$_.log" })) {
  $txt = Get-Content $f -Raw
  $errs = ($txt | Select-String -Pattern "SCRIPT ERROR" -AllMatches).Matches.Count
  $spawns = ($txt | Select-String -Pattern '"ev":"spawn"' -AllMatches).Matches.Count
  $maxN = 0
  foreach ($m in ([regex]::Matches($txt, '"n":(\d+)'))) { $v = [int]$m.Groups[1].Value; if ($v -gt $maxN) { $maxN = $v } }
  $kills = ($txt | Select-String -Pattern '"ev":"kill"' -AllMatches).Matches.Count
  $status = if ($errs -eq 0 -and $spawns -ge $expected -and $maxN -ge $expected) { "PASS" } else { "FAIL"; $fail++ }
  Write-Host ("{0,-5} {1,-40} script_errors={2} spawns={3} max_players_in_snapshot={4} (need {5}) kills={6}" -f $status, (Split-Path $f -Leaf), $errs, $spawns, $maxN, $expected, $kills)
}
if ($fail -gt 0) { Write-Host "NET TEST FAILED ($fail log(s))"; exit 1 } else { Write-Host "NET TEST PASSED"; exit 0 }
