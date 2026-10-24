# ECHO CLASH: THE ARENA REMEMBERS — Setup and Run Guide (v2, Hot Return)

Engine: **Godot 4.7.2 stable** (standard build, GDScript only). Project root: `D:\devmaycry` (this repository).
Verified on Windows 11, RTX 4060 Laptop GPU, D3D12 Forward+. Default window 1920x1080 (fullscreen and other
resolutions in Settings; the saved preference wins on later launches).

## Open and run

1. Launch `Godot_v4.7.2-stable_win64.exe`, **Import** `D:\devmaycry\project.godot`, **Open**, press **F5**.
2. Or run the packaged build: `build\EchoClash.exe` (export it with `powershell -File tools\package.ps1`).

Third-party assets are CC0 only (Quaternius characters and animations, Kenney kits and impact sounds, Poly Haven
detail textures); see `ASSET_REGISTER.md`. Raw downloads stay in `assets/_source/` (git-ignored); processed files
live in `assets/models`, `assets/textures` and `assets/sfx/kenney`. Shaders, maps, UI and the 28 procedural cues
(`tools/gen_sfx.py`) are original.

Material preview / style check scene:

```
Godot_v4.7.2-stable_win64_console.exe --path . res://src/style/MaterialPreview.tscn -- --shot=build/shots/material_preview.png
```

Display: Settings > WINDOW MODE (windowed / borderless / fullscreen), resolution, preset, shadows, anti-aliasing
(FXAA default; MSAA shows edge dots with the toon shader), texture and effects quality. If a mode leaves the window
unusable, start with `-- --force-windowed`, or delete `%APPDATA%\Godot\app_userdata\Echo Clash\settings.cfg`.

## Controls

| Key | Action |
|---|---|
| W A S D / Mouse | Move / aim |
| Left mouse / Right mouse | Fire / aim down sights (sniper scope) |
| 1 2 3 4 | Rifle / Shotgun / Sniper / Machine gun |
| R / Shift / Space / C / Ctrl | Reload / sprint / jump / crouch / dash |
| Q | Entropy ability: attackers **Reverse Entropy**, defenders **Fast-Forward**. Once per round, no cooldown |
| E | Hold at a zipline anchor to ride; the Core is picked up by walking over it |
| Ladders | Walk into a ladder and keep moving forward to climb, backward to descend, jump to push off (not while carrying the Core) |
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

- **PLAY** (offline) or **HOST LAN GAME**: choose mode, map (Oracle Gardens, Tideline Exchange, Vector Foundry, or the
  Developer Test Arena marked as a test map), team size or player count, bot fill and difficulty, and ROLE SWITCH
  (every round by default, or after two rounds), then open the lobby and **START MATCH**.
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
powershell -File tools\map_checks.ps1 -Maps oracle_gardens   # route, reach, feature, perimeter and sight probes (engine side)
powershell -File tools\retrieve_test.ps1                       # Reverse Entropy retrieval scenarios on the three maps
powershell -File tools\bot_soak.ps1 -Seconds 120               # bot matches on the three maps, event summary
python tools\mapproto\oracle.py [gen]                          # offline plan analysis; `gen` rewrites src/maps/plans/ and the setup-screen preview
python tools\speck_check.py build\shots\*.png                  # black-speckle detector for screenshots
```

Headless user arguments (after `--`): `--role=host|join|code`, `--ip`, `--port`, `--code`, `--practice`,
`--autostart=<s>`, `--min_players`, `--mode=hot_return|relic_rush`, `--map`, `--bots=true|false`, `--team_size`,
`--ffa_size`, `--bot_difficulty`, `--auto=<pattern|seq:...>`, `--log-snap`, `--quit-after-sec`, `--screenshot-at`,
`--screenshot-title`, `--force-windowed`, `--routeprobe`, `--navprobe`, `--kill-local-at`, `--open-map-at`,
`--allow-empty-team`, `--settings-test=write|read`, `--settings-path=user://<file>`, `--open-settings`, `--perf`, `--winprobe`,
`--switch_policy=every_round|halves`, `--diag=<flags>` (rendering isolation), `--bot-trace`, `--bot-goal=x,y,z` (every bot walks there), `--reachprobe`, `--featureprobe`, `--perimeterprobe`, `--sightprobe`, `--navlayers=<mask>` (with `--navprobe`), `--cam="x,y,z,yaw,pitch[,fov[,ortho_height]];..."` with `--roofs=off` and `--hide-ui` (review cameras, one per screenshot), `--open-screen=setup|host|join|settings|controls|credits`, `--skip-intro`, `--intro-skip-at=<s>`, `--return-menu-at=<s>`, `--pause-at=<s>`. Map ids: `oracle_gardens`, `tideline_exchange`,
`vector_foundry`, `dev_test_arena` (and `legacy_tideline`, `legacy_foundry`).
