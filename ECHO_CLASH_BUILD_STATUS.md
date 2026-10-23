# ECHO CLASH — Build Status (v2 Hot Return + visual production pass, 2026-10-24)

Engine: **Godot 4.7.2.stable.official**, standard build. Project `D:\devmaycry`. Packaged `build/EchoClash.exe`.
Every "tested" claim points to a log or screenshot under `build/` produced by the commands in `ECHO_CLASH_SETUP.md`.

## Visual production pass (2026-10-24, after the Hot Return rebuild)

| Area | What changed | Evidence |
|---|---|---|
| Style system | `palimpsest_toon.gdshader`: stepped light bands with soft edges, cobalt shade tint, restrained screen-space halftone in shade, rim light, stepped specular for metals, triplanar CC0 detail (luminance + normal) under the palette colour, distance quality cut. `ink_outline.gdshader`: depth-only screen-space ink that fades near (viewmodel stays clean) and far. `Style.gd` material library (stone, plaster, ceramic, floor, cliff, concrete, metal, rust, cloth, gear, skin, foliage) used by every map surface and imported model | `material_preview.png`, `material_preview2.png`, `rig_close4.png` |
| External assets | Quaternius Universal Base Characters + Universal Animation Library, Kenney Blaster / Nature / Space Station kits and Impact Sounds, 7 Poly Haven texture sets (all CC0). Register with URLs, licences and modifications: `ASSET_REGISTER.md` | imports clean (`import_assets.log`) |
| Characters | `TacticalRig.gd`: rigged human body driven by an AnimationTree (idle/walk/jog/sprint, crouch, jump, upper-body aim, shoot and reload one-shots, death clip), helmet + visor, plate carrier, pouches, pads, boots, gloves, backpack; team accents; weapon in the right hand; rewind shader as overlay | `rig_close6.png`, `og_art_1_09.png` |
| First person | `FPArms.gd`: the same character in first person with the head bone collapsed; real hands in the aim pose, weapon in the right hand locked to the camera, sway, bob, kick, reload dip, magazine drop, shell ejection, switch dip. Capsule arms remain as a fallback | `fp2_1_12.png`, `wpn_v4_1_15.png` |
| Weapons | Rifle / shotgun / sniper / machine gun built from Kenney Blaster Kit bodies + scopes/magazines, desaturated to graphite with a per-weapon accent; muzzle flashes at the real barrel tip | `wpn_v4_*.png` |
| Oracle Gardens | Worn-tile floor and paving bands, buttressed perimeter with broken crowns, four corner bastions, two point-symmetric garden alcoves through the north/south walls (curved walls, basin, statue, trees), columned sanctuary on the upper terrace, arches over the four ramps, fractured obelisk with mint/orange faults, arches around the phase gates, hedges and trees, cliff and forest backdrop | `og_art_*.png`, `v6_play_1_20.png`, `alcove2_1_26.png`, `final_oracle_gardens_*.png` |
| Tideline Exchange | Animated toon sea, pier piles, crane landmark through the exchange tower, two projecting piers with rails and cargo cover, seawall bastions, distant cranes and docks, zipline masts with hazard bands, pipes and rails | `art_tideline_exchange_*.png`, `pier_1_30.png`, `exe3_1_14.png` |
| Vector Foundry | Rotating reactor rings, spindle struts, gantries, kiln stacks on the horizon, corner bastions, two machinery lobes with a press housing | `art_vector_foundry_*.png`, `lobe_fxaa_1_30.png`, `final_vector_foundry_*.png` |
| Traversal / ambience | Vector slings: octagonal steel housing, four charge coils with signal bands, dotted trajectory arc from the real launch maths, landing ring. Per-map procedural ambience loops (garden wind and chimes, sea swell and wind, machine hum and press pulse) from `tools/gen_ambience.py` on the Ambience bus | `sling_1_14.png`, `"Audio","ambience"` log lines (20 s loops) |
| Core / props | Causal Core containment device (glass shell, brass ribs, end caps, gyroscope band) with stable / unstable / critical / locked / stabilized colours; temporal barricades intact, damaged (fault glow), destroyed, restored, expired | `reg2_rewind_host.log`, `prop_safety2_host.log` |
| Audio | Positional 3D one-shots: footsteps by surface (stone/concrete, metal on raised industrial decks), landing, shell casings, stone/metal/flesh impacts (Kenney CC0), on top of the 28 procedural cues | code path `Sfx.play_at` (audibility not verifiable headlessly) |
| HUD / UI | Health and ammo panels anchored to the corners (no clipping), magazine/reserve split, compact ability chips, smaller notices, constant-size world labels; main menu renders the real Oracle Gardens with a cinematic orbit and the Core; PLAY / HOST LAN GAME / JOIN LAN GAME / SETTINGS / CREDITS / EXIT; two-column settings | `menu_v3_1_00.png`, `settings_v4_1_00.png`, `v5_play_1_30.png` |
| Settings | Window mode (windowed / borderless / fullscreen), preset, shadow quality, anti-aliasing (off / FXAA / MSAA 2x / 4x / TAA), texture quality, effects quality, frame cap, VSync; applied to the renderer; persisted; v2 migration; automated runs never touch the player file | `graphics_applied` log lines, isolated `settings_test.cfg` round trip |

### Safety rule added (Reverse Entropy restoration)
A barricade restored by a rewind never re-enables collision inside a living player: the server checks the
footprint, restores visually without collision and logs `collision:false, blocked_by:<id>` (`prop_safety_host.log`).

### Performance (measured with `--perf`, 1920x1080 window, High, FXAA, 6-8 players with bots)
Oracle Gardens 217-239 FPS, Tideline Exchange 214-279 FPS, Vector Foundry 215-259 FPS on an RTX 4060 Laptop GPU
(`final_*.log`). First-use shader compilation causes one-off 100-150 ms hitches in the first seconds of a match.

### Not done in the visual pass
- The maps keep their measured Hot Return collision layouts (routes 120-152 m). Outer silhouettes are broken by
  bastions, alcoves, piers and lobes, but the core route networks were not redrawn from scratch.
- The first-person weapon follows the hand bone with camera-locked orientation, not IK; the left hand does not grip
  each fore-end exactly, and ADS is an approximate offset rather than a sight-aligned pose.
- Character clips come from a pistol aim set (the free animation library has no rifle set).
- MSAA shows edge-dot artifacts with the toon shader on this renderer; FXAA is the default for that reason.

## Implemented and tested (Hot Return rebuild)

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
