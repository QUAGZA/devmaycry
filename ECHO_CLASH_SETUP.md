# ECHO CLASH: THE ARENA REMEMBERS — Setup and Run Guide (v2, Hot Return)

Engine: **Godot 4.7.2 stable** (standard build, GDScript only). Project root: `D:\devmaycry` (this repository).
Verified on Windows 11, RTX 4060 Laptop GPU, D3D12 Forward+. Default window 1920x1080 (fullscreen and other
resolutions in Settings; the saved preference wins on later launches).

## Open and run

1. Launch `Godot_v4.7.2-stable_win64.exe`, **Import** `D:\devmaycry\project.godot`, **Open**, press **F5**.
2. Or run the packaged build: `build\EchoClash.exe` (export it with `powershell -File tools\package.ps1`).

No third-party assets: geometry, materials, shaders, sounds, player figures and UI are generated in code
(`tools/gen_sfx.py` produced the 28 WAV cues under `assets/sfx`).

## Controls

| Key | Action |
|---|---|
| W A S D / Mouse | Move / aim |
| Left mouse / Right mouse | Fire / aim down sights (sniper scope) |
| 1 2 3 4 | Rifle / Shotgun / Sniper / Machine gun |
| R / Shift / Space / C / Ctrl | Reload / sprint / jump / crouch / dash |
| Q | Entropy ability: attackers **Reverse Entropy**, defenders **Fast-Forward**. Once per round, no cooldown |
| E | Hold at a zipline anchor to ride; the Core is picked up by walking over it |
| Caps Lock | Tactical map (north-up); Esc or Caps Lock closes it |
| Tab / Esc | Scoreboard / pause (local only) |

## Modes

**HOT RETURN** (primary, 2 teams). The Causal Core starts in the defenders' vault. Attackers steal it and carry
it to their home Stabilizer on the opposite side. Carrying speed 4.2 m/s. Volatility rises 100/26 per second
while the Core is carried or dropped; at 100 % it detonates and the defenders win the round. Two Stability
Fields (15 m zones off the direct route) each pause volatility for up to 7 s per round. Reverse Entropy drops
the Core at the activation point, rewinds its volatility to the value 6 s earlier and freezes it until an
attacker picks it up again, while the attacker's body re-traverses its last 6 s backwards (look and fire stay
free). Fast-Forward is an 8 m, 3 s field that multiplies the ticking rate by 1.75, speeds projectiles 1.5x and
raises the activator's sensitivity 1.15x. Rounds last 120 s; sides swap after two rounds; first to 3; 2-2 goes
to overtime pairs. Tagged temporal barricades restore for 2 s as a rewinding player passes them.

**RELIC RUSH** (secondary, free-for-all). 5 minutes, first to 25. Elimination 2, Memory Shard 1, Relay Beacon
1 per 4 s of sole control (relocates every 45 s). Reverse Entropy once per match. Tie → sudden death.

## Offline practice / host / join

- **PRACTICE** or **PLAY**: choose mode, map (Oracle Gardens, Tideline Exchange, Vector Foundry), team size or
  player count, bot fill and difficulty (Easy / Medium / Hard), then open the lobby and **START MATCH**.
- **LAN ROOMS → HOST**: the lobby shows a 6-character room code and your IP. The first host triggers the Windows
  Firewall prompt: click **Allow** (UDP 24642 game, 24643 beacon).
- **LAN ROOMS → JOIN**: enter the code (6 s LAN discovery) or the host IP. Same network only; there is no
  internet matchmaking.

## Automated checks

```
powershell -File tools\godot.ps1 --headless --import                          # after adding scripts
powershell -File tools\godot.ps1 --headless --script res://tests/run_tests.gd   # 75 unit checks
powershell -File tools\net_test.ps1 -Clients 2 -Bots -Mode hot_return -Port 25000
powershell -File tools\godot.ps1 --headless -- --role=host --practice --mode=hot_return --map=oracle_gardens --routeprobe --quit-after-sec=5
powershell -File tools\screenshot.ps1 -Map tideline_exchange -Mode hot_return -Bots
powershell -File tools\package.ps1
```

Headless user arguments (after `--`): `--role=host|join|code`, `--ip`, `--port`, `--code`, `--practice`,
`--autostart=<s>`, `--min_players`, `--mode=hot_return|relic_rush`, `--map`, `--bots=true|false`, `--team_size`,
`--ffa_size`, `--bot_difficulty`, `--auto=<pattern|seq:...>`, `--log-snap`, `--quit-after-sec`, `--screenshot-at`,
`--screenshot-title`, `--force-windowed`, `--routeprobe`, `--navprobe`, `--kill-local-at`, `--open-map-at`,
`--allow-empty-team`, `--settings-test=write|read`, `--winprobe`.
