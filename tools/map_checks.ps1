# Engine-side map verification on the real colliders and navmesh, for every selectable map.
#   route    : carry routes (direct / both Stability Fields) as measured by the navmesh
#   reach    : every gameplay point, ladder top, gate and cable anchor reachable from both teams' spawns
#   feature  : every zipline swept with the player capsule, every gate exit has room
#   sight    : sightline statistics from random navmesh points (physics rays at eye height)
# Usage: powershell -File tools\map_checks.ps1 [-Maps oracle_gardens,tideline_exchange] [-Port 24990]
param([string[]]$Maps = @("oracle_gardens", "tideline_exchange", "vector_foundry", "dev_test_arena"), [int]$Port = 24990)
$exe = $env:GODOT
if (-not $exe) { $exe = "C:\Users\risha\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" }
$proj = Split-Path -Parent $PSScriptRoot
$logs = Join-Path $proj "build\logs"
New-Item -ItemType Directory -Force $logs | Out-Null
$fail = 0
foreach ($m in $Maps) {
  foreach ($probe in @("routeprobe=all", "reachprobe", "featureprobe", "perimeterprobe", "sightprobe")) {
    $name = $probe.Split("=")[0]
    $log = Join-Path $logs ("check_{0}_{1}.log" -f $m, $name)
    $args2 = @("--headless", "--path", "`"$proj`"", "--", "--role=host", "--port=$Port", "--practice", "--autostart=1", "--map=$m", "--mode=hot_return", "--bots=false", "--$probe", "--quit-after-sec=8", "--name=CHECK")
    $p = Start-Process $exe -ArgumentList $args2 -RedirectStandardOutput $log -RedirectStandardError (Join-Path $logs "check_err.log") -PassThru -NoNewWindow
    $p.WaitForExit()
    $txt = Get-Content $log -Raw
    $errs = ([regex]::Matches($txt, 'SCRIPT ERROR')).Count
    $line = ""
    switch ($name) {
      "routeprobe" {
        $d = [regex]::Match($txt, '"ev":"direct"[^}]*"metres":([0-9.]+)').Groups[1].Value
        $d2 = [regex]::Match($txt, '"ev":"direct"[^}]*').Value
        $b = [regex]::Match($txt, '"exposure_s":([0-9.]+)[^}]*"ev":"via_B_then_A"[^}]*"metres":([0-9.]+)[^}]*"volatility":([0-9.]+)')
        $both = [regex]::Match($txt, '\{[^}]*"ev":"via_B_then_A"[^}]*\}').Value
        $bm = [regex]::Match($both, '"metres":([0-9.]+)').Groups[1].Value
        $bv = [regex]::Match($both, '"volatility":([0-9.]+)').Groups[1].Value
        $line = "direct $d m, both fields $bm m (volatility at arrival $bv %)"
        if ($bm -eq "" -or [double]$bv -ge 100.0) { $fail++ }
      }
      "reachprobe" {
        $u = [regex]::Match($txt, '"unreachable":(\d+)').Groups[1].Value
        $c = [regex]::Match($txt, '"checked":(\d+)').Groups[1].Value
        $line = "$c queries, unreachable $u"
        if ($u -ne "0") { $fail++ }
      }
      "featureprobe" {
        $f = [regex]::Match($txt, '"failed":(\d+)').Groups[1].Value
        $c = [regex]::Match($txt, '"checked":(\d+)').Groups[1].Value
        $ctl = [regex]::Match($txt, '"control_centre_blocked":(\w+)').Groups[1].Value
        $line = "$c features checked, failed $f, negative control blocked=$ctl"
        if ($f -ne "0") { $fail++ }
      }
      "perimeterprobe" {
        $r = [regex]::Match($txt, '"rays":(\d+)').Groups[1].Value
        $m2 = [regex]::Match($txt, '"misses":(\d+)').Groups[1].Value
        $line = "$r rays across the outline, $m2 gaps"
        if ($m2 -ne "0") { $fail++ }
      }
      "sightprobe" {
        $g = [regex]::Match($txt, '"ground":\{[^}]*\}').Value
        $line = $g
      }
    }
    if ($errs -gt 0) { $fail++; $line += "  SCRIPT ERRORS: $errs" }
    Write-Host ("{0,-18} {1,-12} {2}" -f $m, $name, $line)
  }
}
if ($fail -gt 0) { Write-Host "MAP CHECKS: $fail problem(s)"; exit 1 } else { Write-Host "MAP CHECKS PASSED"; exit 0 }
