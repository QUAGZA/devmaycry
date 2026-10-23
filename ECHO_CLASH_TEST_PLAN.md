# ECHO CLASH — Test Plan and Results (v2, 2026-10-24)

PASS = run and observed in a log or screenshot under `build/`. NOT RUN = needs a human or a second machine.

## Automated (all PASS unless stated)

| ID | Test | Evidence |
|---|---|---|
| U | 75 unit checks: EchoBuffer (6 s window, absolute sampling), Corebreak match structure (side swap, first to 3, overtime pairs), Hot Return resolve priority and volatility math (field allowance, exhaustion mid-tick, Fast-Forward only outside fields, history interpolation, route exposure), Relic rules, weapon recoil bounds / spread / falloff | `tests/run_tests.gd` |
| M1 | Spectator obstruction reproduced then fixed; settings round-trip across two launches; window probe | `build/shots/spectator_before_1_09.png`, `spectator_after_1_09.png`, `settings_w.log`, `settings_r.log` |
| M2 | Host + 2 clients + bots, snapshots agree, no script errors | `tools/net_test.ps1` PASS (`net_*.log`) |
| M3a | Direct carry detonates 26 s after pickup short of the Stabilizer | `hr_direct_host.log` |
| M3b | Field route stabilizes (97.4 % old layout, 75.8 % final layout) | `hr_fields_host.log`, `reg_hr_host.log` |
| M3c | Reverse Entropy: Core dropped at activation, volatility 36.2 → 13.1 (value 6 s earlier), frozen during and after the rewind, body re-traversed 26 m, pickup resumed ticking from 13.1 | `hr_rewind_host.log` |
| M3d | Fast-Forward: second defender refused while one is active (charge kept); spent charges denied; field expires after 3 s | `hr_bots.log` |
| M4 | Temporal prop destroyed (versioned event), restored as cover only for historical moments before destruction, cover expired after 2 s, replicated to the client, once per prop per activation | `prop_host.log`, `prop_client.log` |
| M5 | Four weapons: rifle 30-round auto burst, shotgun 8 pellets, sniper 92 dmg elimination, MG switch delay; 8 projectiles accelerated by Fast-Forward, accelerated hits single-damage | `wpn_host.log` |
| M6 | Route probe per map: direct 124–133 m (29–32 s > 26 s fuse), both-field route 145–152 m (20–22 s exposure) | `route_*.log` |
| M6b | Hard bots on all three maps: attackers rush the vault, defenders guard it, eliminations | `hrbots_*.log` |
| M7 | Shaders compile and render (core, field, portal, surface, rewind, fast-forward, minimap mask); rigs visible | `look_*.png`, `hud_1_07.png` |
| M7b | In-game captures: Core carried through Stability Field B (allowance 7.0 → 0.0 s), Reverse Entropy drop at 40.3 % rewound to 27.3 % and frozen with lock countdown, PICK UP state after the lock, Fast-Forward ring around the defender with the notice | `hr_play_1_32/41/47/53/59.png`, `hr_ff_1_28.png`, `shot_hr_play.log`, `shot_hr_ff.log` |
| M8 | Minimap with LOS-only enemies, Caps Lock map, settings persistence, 1920x1080 windowed | `hud_1_13.png`, `menu_1_00.png`, `winprobe2.log` |
| M9 | Room code discovery on the current LAN address, exported exe as host + client with bots | `reg_code_client.log`, `exe2_host.log`, `exe2_client.log` |
| M10 | Relic Rush bots: points, beacon rotation, once-per-match rewinds | `reg_relic.log`, `reg_relic2.log` |
| V1 | Route probes after the art pass, all maps: direct 120.3 / 132.4 / 124.9 m, both-field route 144.5 / 152.2 / 150.1 m, all reachable, direct carry still detonates | `route_*_v3.log`, `route_*_v4.log` |
| V2 | New spaces reachable: Oracle alcoves and Foundry lobes (nav probes), Tideline pier (player walked onto it) | `route_oracle_alcove.log`, `pier.log`, `lobe.log` |
| V3 | Reverse Entropy loop on the new build: drop at 34.2 %, rewound to 11.1 % and frozen, re-pickup at 11.1 % | `reg2_rewind_host.log` |
| V4 | Restoration safety: nobody inside, collision restored; defender inside, visual-only restore with logged blocker | `prop_safety2_host.log`, `prop_safety_host.log` |
| V5 | Settings v2 round trip (preset, window mode, AA, shadows, textures, effects) in an isolated file; player file checksum unchanged by test runs | session log |
| V6 | Performance at 1080p High with bots on all maps (214-279 FPS) | `final_*.log`, `perf_*.log` |
| V7 | Exported exe (141 MB) host + client with bots, no script errors | `exe3_host.log`, `exe4_host.log`, `exe4_client.log` |

## Manual checklist (NOT RUN by the agent)

0. Visual pass: walk each map and look for floating or clipping props; visit the alcoves, piers and lobes; look down
   at the first-person body; switch 1-4 and aim down sights with each weapon; watch a bot run, aim, reload and die up close;
   listen for footsteps on stone and metal decks.

1. Practice, Hot Return, Oracle Gardens, 2v2 Medium: countdown, LIVE, bots contest the vault, round result named.
2. Steal the Core, run direct: detonation around the plaza. Run via both fields: stabilization with ~20 % margin.
3. While carrying, press Q: Core drops and freezes with the 6-second-earlier value; your body walks back along your route while you can still aim and shoot; the Core cannot be picked up for 6 s.
4. As defender near a ticking Core press Q: orange ring, faster ticking, faster bullets, slightly faster mouse for 3 s; a second press is refused.
5. Shoot a barricade, then rewind past it: it reassembles for 2 s and blocks bullets.
6. Weapons 1–4 feel distinct; recoil climbs and can be pulled down; right mouse on the sniper scopes.
7. Caps Lock opens the tactical map; Esc closes it without pausing.
8. Settings: change resolution / preset / frame cap / volumes, Apply, restart: values persist.
9. Host on one laptop, join by code from another on the same Wi-Fi (allow the firewall prompt).
10. Relic Rush with 3 bots to the end of a 5-minute match or 25 points.

## Known limitations

- Clients run one physics tick plus interpolation behind the server (fine on LAN).
- Bots use ramps and launch pads they step on; they do not plan through gates or ziplines.
- Two-machine LAN and human playtests were not possible from this session.
