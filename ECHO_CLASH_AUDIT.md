# ECHO CLASH — Project Audit (v2 rebuild start, 2026-10-23 22:40 IST)

## Environment
- Godot **4.7.2.stable.official.ed1daf0bf**, standard build (GDScript only). Editor and console binaries under
  `C:\Users\risha\Downloads\Godot_v4.7.2-stable_win64.exe\`. Editor currently open on this project.
- Display 2560x1600 physical (150 % scaling). GPU RTX 4060 Laptop, D3D12 Forward+ confirmed in the editor log.
- No Blender or other DCC tool installed. Python 3.14 (stdlib) is used for the procedural sound generator.
- Export templates 4.7.2 installed; `build/EchoClash.exe` exported and smoke-tested before this rebuild.

## Project structure (entry and layers)
- Entry scene: `res://src/ui/Title.tscn` → `src/ui/Title.gd` (menus, lobby, CLI test roles).
- Match scene: `res://src/match/Match.tscn` (World, Fx, HUD) built at runtime by `src/maps/MapDef.gd` subclasses.
- Autoloads: `Palette`, `Settings`, `Net` (ENet session, room codes), `Game` (RPC hub, snapshots), `Sfx`.
- Gameplay: `src/player/Player.gd` (server-simulated FPS body), `src/player/BotBrain.gd`, `src/echo/Echo.gd`,
  `src/rules/*` (EchoBuffer, CorebreakRules/Mode, RelicRules/RelicRushMode), `src/match/MatchServer.gd`,
  `src/match/Objectives.gd`, `src/maps/{OracleGardens,TidelineExchange,VectorFoundry}.gd`, `src/maps/features/Features.gd`.
- Tests and tools: `tests/run_tests.gd` (34 unit checks), `tools/*.ps1`, `tools/gen_sfx.py`.
- Run commands: see `ECHO_CLASH_SETUP.md` (headless roles, screenshots, net test, package).

## Issues reproduced before changing anything
1. **Spectator obstruction.** Reproduced with `--kill-local-at=6` + screenshot `build/shots/spectator_before_1_09.png`:
   a large yellow slab fills the view. Source: the spectated teammate's emissive brass visor
   (`Player._init`, child of `body_mesh`) sits 0.34 m in front of the borrowed camera placed at that player's
   eye position in `Match._process`. Fix: `Player.set_spectated()` hides the spectated model and tag; spectator
   can cycle living teammates with the fire key; state restored on respawn / round reset.
2. **HUD overlap.** The top-left card could overlap the timer card in Relic Rush at 1280x720. Card width is now
   capped at 400 px; re-verified at 1920x1080 in Milestone 8 screenshots.
3. **Window resolution.** The project started at 1280x720 and Windows opened it screen-sized; now 1920x1080 by
   default with an explicit `Settings.apply_window()` (fallback to the largest preset that fits the display).
4. **Blockout look.** Every surface is a flat `StandardMaterial3D` from `MapDef.mat()`; no shaders are attached.
   Addressed in Milestone 7 (surface shader families, Core/rewind/field/portal shaders).
5. **Geometry overlaps.** Several decorative boxes intersect (planters in walls on the north/south lanes of Oracle
   Gardens, site crescents overlapping the site cylinder). Addressed during the Milestone 6 map rework.

## Baseline state (all verified by logs/screenshots before the rebuild)
- LAN host/join, room codes, snapshots, eliminations: PASS. Corebreak and Relic Rush loops: PASS.
- Bots on all maps: PASS. Gates/ziplines/slings: PASS. Package: PASS.

## Rebuild checklist (brief order)
- [x] M1 Audit, baseline, spectator fix, 1080p, settings persistence
- [x] M2 LAN smoke on baseline
- [x] M3 Hot Return slice: Core volatility/history/lock, fields, Reverse Entropy, Fast-Forward, rounds/match
- [x] M4 Temporal destructibles with restoration and temporary cover
- [x] M5 Four projectile weapons, recoil, reload, switching, FF acceleration
- [x] M6 Map rework: size, vault/stabilizer pairs, fields off-route, route probe, props, portal markers
- [x] M7 Shaders, surface materials, humanoid rigs, audio buses and cues
- [x] M8 Compact HUD, circular minimap, Caps Lock map, main menu hero, settings
- [x] M9 LAN re-verify, bot fill, disconnects, exported exe
- [x] M10 Relic Rush adaptation, regression, docs, package
