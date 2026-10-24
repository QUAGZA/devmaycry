# ECHO CLASH — Judging Requirements Checklist (final upgrade, 2026-10-24)

PASS = verified in a run whose log or screenshot is under `build/`. PARTIAL = works, with a stated gap.
Two-machine LAN and human playtests were not possible from this session (single PC); the LAN evidence comes
from two separate game instances on one machine connected through the real room-code discovery.

| Requirement | Status | Evidence / notes |
|---|---|---|
| Innovative multiplayer design | PASS | Hot Return: steal a volatile Core and carry it home before its 26 s fuse; Stability Fields pause the fuse; Reverse Entropy rewinds your route, drops and freezes the Core at its 6-s-earlier volatility and retrieves one missed shot for a replay; Fast-Forward accelerates the fuse and projectiles. |
| Asymmetric gameplay | PASS | Attackers carry/rewind, defenders guard/accelerate; different abilities per role (`HotReturnMode._reverse_entropy` / `_fast_forward`). |
| Strategic thinking and balancing | PASS | Every map measured with the route probe: direct route always detonates, only the two-field detour survives (see table below). |
| Interactive environments | PASS | Phase gates (Oracle, Foundry), ziplines (Tideline), ladders (all three), launch pads (Foundry), Stability Fields (all), restorable temporal barricades (all); every cable swept and every gate exit validated by `--featureprobe`. |
| Smooth controls / engagement | PARTIAL | Server-authoritative movement, stair stepping, ladders, ziplines, pads; 205-269 FPS in the packaged build. Feel not judged by a human here. |
| Minimum two active players | PASS | `lan_full_host.log` + `lan_full_client.log`: second instance joined by room code ECHO42 via LAN beacon (172.20.10.2), received 469 snapshots across the whole match. |
| At least three arenas | PASS | Oracle Gardens, Tideline Exchange, Vector Foundry (new authored layouts) + Developer Test Arena (marked as test). |
| At least three interactive elements | PASS | Gates, ziplines, ladders, launch pads, fields, temporal barricades: `tB.log` (ladder_enter/ladder_top, zip_attach), `fC.log` (sling), `prop_safety*_host.log`. |
| Functional role switching | PASS | Default policy alternates roles every round (attackers 1,2,1,2 in `lan_full_host.log`, `roles.log`); "halves" policy kept as an option; unit tests for both. |
| Limited sabotage / ability use | PASS | Each ability once per round per player, no cooldown; Fast-Forward reject-and-not-consume; retrieval single use per shot (unit + scenario logs). |
| Timer- or points-based scoring | PASS | 120 s rounds, first to 3 round wins (Hot Return); points to 25 / 5 min (Relic Rush). |
| Clear win/loss, round restart, results | PASS | `lan_full_host.log`: rounds end by elimination/timer, restart, match end 3-1; results screen RPC. |
| No fake match on failed join | PASS | `lan_badcode.log`: unknown code -> search, no match/spawn; failure now logged (`code_not_found`). |

## Final map numbers (engine route probe on the redesigned street maps, carry speed 4.2 m/s, fuse 26 s, 7 s per field)

| Map | Direct route | Single field | Both fields (arrival volatility) | Signature mechanics |
|---|---|---|---|---|
| Oracle Gardens | 126.8 m (30 s, detonates) | 144.9 / 146.4 m (27.5 / 27.9 s, detonates) | 145.1 m, 79 % | phase gates, terraces + S-bend arcades, sunken basin, octagonal court |
| Tideline Exchange | 122.4 m (29 s, detonates) | 140.1 m (26.4 s, detonates) | 140.3 m, 75 % | exchange hall with galleries and crossing cables, gantry quay, ladders, sunken channel |
| Vector Foundry | 121.9 m (29 s, detonates) | 144.8 m (27.5 s, detonates) | 145.1 m, 79 % | ring street + reactor, watchtower walkways, launch pads, portals, service tunnel |

Walking (6 m/s) spawn-to-centre is about 14 s on each map; a hall zipline ride is 2.6 s; a ladder climb to 5 m is 1.5 s.
