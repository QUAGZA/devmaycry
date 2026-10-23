# ECHO CLASH — Build Status (v2 Hot Return rebuild, 2026-10-24)

Engine: **Godot 4.7.2.stable.official**, standard build. Project `D:\devmaycry`. Packaged `build/EchoClash.exe`.
Every "tested" claim points to a log or screenshot under `build/` produced by the commands in `ECHO_CLASH_SETUP.md`.

## Implemented and tested

| Area | What exists |
|---|---|
| Hot Return | Vault cradle, Core pickup/carry/drop, 26 s fuse (100/26 per s), 10 Hz volatility history, two 15 m Stability Fields with a 7 s allowance each per round (not refreshable), home Stabilizer extraction, detonation, deterministic result priority, 120 s rounds, side swap after 2, first to 3, 2-2 overtime pairs, results screen, rematch |
| Reverse Entropy | Attackers, once per round, needs 6 s of history. Drops the Core at the activation point, sets its volatility to the recorded value 6 s earlier (history lookup, pauses included), temporal lock (no pickup for 6 s, frozen until attacker pickup), body re-traverses the route backwards for 6 s with free look and fire, damageable, charge spent on activation and never refreshed by death |
| Fast-Forward | Defenders, once per round, 8 m / 3 s: ×1.75 Core rate (only outside fields, never on a locked Core), ×1.5 live projectile velocity (flagged, applied once), ×1.15 activator look sensitivity, single active field (a second activation is refused and keeps its charge), ground ring shader |
| Temporal props | Tagged barricades (5–6 per map) with HP, versioned destroy/restore events, restoration along a rewinding player's path for moments before destruction, 2 s temporal cover (layer 32) that blocks others and bullets while the rewinder phases through, replicated |
| Weapons | Rifle, shotgun (8 pellets), sniper (scope), machine gun with original recoil tables, spread model (first-shot, spray growth, movement/jump penalties, ADS), reload/reserves, slots 1–4, switch delay, projectile manager with per-tick ray sweeps (no tunnelling), unique ids, single damage per projectile, Fast-Forward acceleration, four viewmodels |
| Player model | Articulated humanoid rig built in code (helmet/visor, vest, shoulders, arms with weapon, gloves, legs, boots, backpack), team accents and back glyph, procedural locomotion/crouch/jump/aim, rewind shader swap |
| Maps | Oracle Gardens 160x100 (phase gates with portal shader), Tideline Exchange 150x90 (ziplines), Vector Foundry 150x100 (vector slings); vault/Stabilizer pairs mirrored per side; fields on flanks; props placed; route probe tool |
| Visual | Surface shader family on all map materials, Core shader with volatility, field glyph shader, FF ring shader, portal shader, rewind silhouette shader, 3D main-menu hero, graphics presets Low/Medium/High (shadow atlas, MSAA/FXAA, 3D scale, glow/fog) |
| HUD | Top bar (score, round, phase, timer, Core volatility bar + state), role stamp and objective, field allowances, ability chips AVAILABLE/SPENT, health, weapon/ammo/reserve, kill feed, contextual notices, circular minimap (heading-up, LOS-only enemies), Caps Lock tactical map, spectator with teammate cycling (visor obstruction fixed), scoreboard, pause |
| Settings | Resolution list + native, fullscreen, preset, frame cap, VSync, sensitivity, FOV, invert Y, reticle, shake, head bob, six audio buses, Apply / Revert / Reset, persisted in `user://settings.cfg` |
| LAN | ENet listen server, room code via UDP beacon, join by code or IP, refusal when locked/full, host-leave handling, exported exe verified as host and client |
| Bots | Easy/Medium/Hard: LOS perception, reaction, aim error, cadence; Hot Return behaviours (fetch/escort/carry, field detour when projected volatility is too high, Reverse Entropy when hurt while carrying, vault guard, chase, Fast-Forward near a ticking Core); Relic behaviours |
| Relic Rush | Kept: shards, rotating beacon, respawns, first to 25, sudden death, Reverse Entropy once per match, all weapons |
| Audio | 28 procedural cues on Master/Music/Weapons/Effects/Ambience/UI buses: per-weapon shots, rewind, fast-forward, Core pickup/drop/detonation/stabilization, field enter/exit, warnings, restoration, portal/zipline/pad, UI |

## Partially implemented

- Player animation is procedural (no mocap); death pose is "hidden model" rather than a ragdoll.
- Head bob and camera-shake settings are stored and exposed but only weapon kick uses them.
- Ambience bus exists; no ambient loop asset is generated yet.
- Bots do not use Stability Fields as cover and do not plan routes through gates or ziplines.
- Portal destination preview is an animated surface with the destination gate label, not a live camera view (as allowed by the brief).

## Not implemented

- Host migration (host leaving ends the session for everyone, cleanly).
- Controller support, subtitles, voice cues.
- Internet matchmaking (out of scope by design).

## Known issues

- The saved `fullscreen=true` preference (set from the in-game settings screen) overrides the 1920x1080 window; Settings → FULLSCREEN off → APPLY restores the window.
- After adding `class_name` scripts, run the editor once or `tools\godot.ps1 --headless --import` before headless runs.
- Hard bots are lethal at close range; human balance pass pending.

## Next three priorities

1. Two-laptop LAN session with the packaged build and a human feel pass on recoil, sensitivity and rewind readability.
2. Ragdoll/death pose and an ambience loop.
3. Bot routing through gates and ziplines.
