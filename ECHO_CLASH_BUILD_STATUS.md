# ECHO CLASH — Build Status (v2 Hot Return + visual production pass, 2026-10-24)

Engine: **Godot 4.7.2.stable.official**, standard build. Project `D:\devmaycry`. Packaged `build/EchoClash.exe`.
Every "tested" claim points to a log or screenshot under `build/` produced by the commands in `ECHO_CLASH_SETUP.md`.

## Map redesign, front end and traversal hardening (2026-10-24, branch `final-upgrade`)

| Area | Result | Evidence |
|---|---|---|
| Three maps rebuilt in place | Oracle Gardens, Tideline Exchange, Vector Foundry are now authored street networks (`tools/mapproto/*.py` -> `src/maps/plans/*_plan.gd` -> `PlanRunner`), not scattered cover in an open arena. Walkable ground is 27-33 % of each outline; the rest is buildings, rooms, walls and stacks. The old open plaza stays as the Developer Test Arena (marked TEST MAP, still open on purpose); legacy Tideline/Foundry remain CLI-only. | `build/maps/*_plan.png`, `build/shots/vis_*.png` |
| Distinct identities | Oracle: irregular sanctuary streets, octagonal court, roofed temples, terraces joined by S-bend arcades, sunken basin, home-side phase gates. Tideline: 14 m exchange hall with galleries and crossing cables, gantry quay with ladders and cable, warehouse passage, sunken channel with weirs and both fields. Foundry: roofed reactor with offset doors inside a walled ring street, watchtower with elevated walkways, launch pads, roofed service tunnel with bulkheads, home-side portals. | `build/shots/vis_*`, `tools/mapproto/*.py` headers |
| Carry routes (engine navmesh) | Direct always detonates; only the both-field route survives. Oracle 126.8 / 145.1 m, Tideline 122.4 / 140.3 m, Foundry 121.9 / 145.1 m (arrival volatility 79 / 75 / 79 %). Single-field routes (27.5 / 26.4 / 27.5 s exposure) still detonate. | `check_*_routeprobe.log` |
| Sightlines (engine rays, ground level, 800+ navmesh points x 48 rays at eye height) | share of rays beyond 25 m: 2.6-3.3 %; beyond 35 m: 0.5-0.6 %; per-point longest ray p50 27-28 m, p90 39-41 m, p99 50-56 m; no unobstructed 80 m ground ray on any of the three maps. Elevated levels see further by nature (galleries, gantry, walkway). | `check_*_sightprobe.log` |
| Reachability | Every gameplay point, ladder top, gate and cable anchor reachable from both teams' spawns (134-154 queries per map, 0 unreachable); the Core route needs no ladder. | `check_*_reachprobe.log` |
| Perimeter | 1650 rays per map fired outward at four heights through every stretch of the outline: 0 gaps (walls, rails and an invisible barrier above the sea rails). Thin unintended slits between terraces/streets and building masses are filled by the plan tool (`fill_slivers`). | `check_*_perimeterprobe.log` |
| Ziplines | Cable path swept with the player capsule at map load (an obstructed cable is disabled, not ridden); rider is blended onto the cable, swept every tick (stops and drops at the last free point if something solid appears) and set down on a verified standing spot; a tap of E is buffered, anchor volume is larger, a prompt shows "HOLD E / RIDE THE ZIPLINE". All 4 Tideline cables clear; a rider rode HALL A four times in a row, each landing clear. The two obstructed legacy_tideline cables are detected and disabled by the guard. | `check_*_featureprobe.log`, `zip_ride.log` |
| Phase gates | Exit is validated with the capsule and nudged to a clear standing spot or the teleport is cancelled with a notice; entry and exit areas probed; the Core carrier is refused with a prompt. Six consecutive teleports (3 round trips both ways) on the Oracle pair, exits clear, input recovered. | `gate_pingpong.log` |
| Core carriers | Gates, ziplines and launch pads refuse the Core (ladders already did) so the measured carry routes cannot be shortcut; refusals verified in a run. | `gate_oracle2.log` |
| Ladders | Foot exit fixed (a player leaving the foot is no longer held by the ladder volume); bots path over ladder links (navigation layer 2) unless carrying. Oracle ladder climbed and descended by the autopilot; Tideline hall ladders used repeatedly. | `ladder_oracle2.log`, `zip_ride.log` |
| Reverse Entropy retrieval | On all three new maps: a missed shot is retrieved, replayed from the muzzle, hits an exposed defender exactly once and is stopped by a wall when the defender stands behind one (6 scenarios). | `retr_*_host.log`, `retrieve_final.txt` |
| Black artifact | 0 isolated near-black pixels in 15 eye-level captures across the three maps (detector verified: 379 of 400 injected specks found). | `tools/speck_check.py` |
| Startup sequence | New dark real-time intro (fade in, converging teal motes, geometric traces, Core materialises, energy arcs, light sweep, tagline, title, menu) 6.7 s on the first launch, 1.3 s afterwards, skippable by any key or click, never replayed after a match. | `intro_full.log`, `intro_fast.log`, `intro_skip.log`, `build/shots/menu_*` |
| Main menu | Dark presentation scene (small real-time 3D Core, lattice, rings, motes; no map, no video) with the six original entries, hover/focus/press animation and keyboard navigation. | `menu_main_1_00.png` |
| Match setup | Sectioned form (player / match / bots / rules), selected-map card with preview, name, mechanic and description, team size and player count enabled by mode, same options and same lobby flow. | `menu_setup_1_00.png` |
| Settings / pause | Same options and persistence, restyled; value read-outs on sliders; Esc/Back handled per screen; pause panel uses the same look. | `menu_settings_1_00.png`, `hud_pause_1_10.png` |
| Music | `theplan.wav` plays from the start of the intro, continues through menus, fades out when a match loads, resumes from where it stopped when the player returns; one player only; follows the Master and Music sliders. | `music_flow.log`, `tests/music_test.gd` |
| Performance (windowed 1920x1080, High, FXAA, 6 players) | While the window had focus: Oracle 239-333 FPS, Tideline 237-325, Foundry 291-324. Windows throttles an unfocused window to exactly 30 FPS (the log records `focused:false` at every 30 FPS sample), so sustained numbers need the window to stay in the foreground. | `perf_*.log`, `perf6.log` |
| Unit / LAN / soak | 78/78 unit checks, 11 music checks, LAN smoke test (host + 2 clients + bots) passes on Tideline and Oracle with the new front end; 130 s bot soaks: no script errors, no bot stuck recoveries on any map. | `unit2.log`, `net_*.log`, `bot_soak.txt` |

### Known gaps after the map redesign
- The skip key press itself (as opposed to the skip logic) and every visual judgment (look, feel, readability of the new maps) were not exercised by a human; the intro was verified by logs and captured frames.
- Two machines were not available: LAN was verified with separate instances on one PC.
- Medium bots rarely complete a carry on Foundry (two bay doors guard a 16 m straight spoke); no stuck or script problems, but their objective play is not tuned.
- `legacy_tideline` still ships two obstructed cables (disabled at load by the guard); the legacy maps and the Developer Test Arena (open plaza, 56 % of rays beyond 25 m) are test content and are not part of the redesign.
- The 30 FPS plateau seen when the window is not focused is Windows behaviour, not a game cap.

## Final upgrade (2026-10-24, branch `final-upgrade`, checkpoint tag `pre-final-upgrade`)

| Area | Result | Evidence |
|---|---|---|
| Black stippling (root cause) | Fixed. Isolation harness (`--diag=...`) showed the artifact appears only with SSAO under MSAA (14.3 % near-black pixels vs 0.07 %); swapping in standard materials removed it; shader bisection pinned it to `palimpsest_toon` writing a perturbed triplanar detail normal into NORMAL, i.e. into the normal buffer SSAO reads (back-facing normals -> full occlusion). Detail now feeds lighting through a varying; the buffer keeps the geometric normal. MSAA + SSAO + outline: 0.37 %. | `build/shots/diag/compare_grid.png`, `before_after_msaa.png`, `diag_*.log` |
| Graphics apply order | Effects toggles (SSAO/glow/fog) were applied before the match world existed; now re-applied after scene ready. | `Match.gd` |
| Bot tower loop | Reproduced (old code: 52 stuck jumps in 80 s, 51 within 14 m of the tower). Root cause: unprojected goals inside colliders + arrival measured to the unreachable point + jump every 1.4 s. Fixed: goals snapped to the navmesh, arrival at the reachable path end, staged recovery (replan, sidestep, one jump, abandon + blacklist). New code: 0 stuck jumps on all maps. | `botcmp_old_*.log`, `botcmp_new_*.log`, `botnew2_*.log` |
| Three new maps | Oracle Gardens (`OracleSanctuary.gd`), Tideline Exchange (`TidelineHall.gd`), Vector Foundry (`FoundryLoop.gd`), built with `MapKit` (walls, concave slabs, floors with sunken holes, stairs, roofed rooms, ladders). Original Oracle plaza kept as **Developer Test Arena**; old Tideline/Foundry kept as `legacy_*` (CLI only). | `oA_grid.png`, `tB_grid.png`, `fC_grid.png`, `fullmaps.png`, `route_*` |
| Ladders | New feature: server-authoritative climbing, navigation links for bots, minimap icon. | `tB.log`, `fC.log` |
| Shot retrieval | Reverse Entropy retrieves the owner's latest missed shot (<= 8 s, rifle/sniper/mg), shows a mote + thin tether returning to the muzzle, replays it once from the muzzle along the recorded direction with normal collision. Host + client test: replay hit the defender once (24 dmg). | `retrieve_host.log`, `retrieve3_zoom.png` |
| Temporal props | Intact / damaged / destroyed / restored / expired; never restores collision inside a living player. | `prop_safety*_host.log` |
| Role switching | Every round by default, halves optional (lobby option, `--switch_policy`), tests for both. | `roles.log`, `lan_full_host.log`, `tests/run_tests.gd` |
| Menu / settings | Centred bordered menu panel over the live map; map selector lists the three maps + the test arena (marked); two-column settings. | `menu_v4_1_00.png`, `settings_v5_1_00.png` |
| LAN | Second instance joined by room code over the LAN beacon and stayed connected for a full 4-round match. | `lan_full_*.log` |
| Performance (packaged exe) | 1080p, High, 8 players: Oracle 206-224 FPS, Tideline 224-237, Foundry 249-269. Intermittent 30 FPS samples seen only while the Godot editor was open and reimporting changed files. | `exeperf_*.log` |

### Known gaps after the final upgrade
- Bots navigate all maps but are not tuned for objective play against full defending teams; in 4v4 tests attackers rarely reach the Core on Oracle/Foundry (they did on Tideline: 7 pickups, 2 detonations) and carriers do not yet path through Stability Fields reliably.
- Two physical machines and human playtesting were not available; LAN was verified with two instances on one PC.
- Map art on the three new layouts is the shared toolkit look (toon materials, columns, trims); less bespoke dressing than the earlier plaza art pass.
- The first-person weapon follows the hand bone without IK; ADS is an offset.

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
