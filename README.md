# ECHO CLASH: THE ARENA REMEMBERS

First-person competitive tactical arcade built in **Godot 4.7.2** for a 24-hour hackathon.
Your last 2.5 seconds can be cast back into the arena as an **Echo**: a telegraphed temporal duplicate that
replays your route and shots. Two modes (Corebreak attack/defend, Relic Rush free-for-all), three arenas with
their own traversal mechanic (phase gates, ziplines, vector slings), bots at three difficulties, and LAN rooms
with 6-character codes.

- Setup, controls, hosting and joining: [ECHO_CLASH_SETUP.md](ECHO_CLASH_SETUP.md)
- What is implemented, tested, partial or missing: [ECHO_CLASH_BUILD_STATUS.md](ECHO_CLASH_BUILD_STATUS.md)
- Test plan with results and the manual checklist: [ECHO_CLASH_TEST_PLAN.md](ECHO_CLASH_TEST_PLAN.md)

## Layout

```
project.godot            Godot 4.7 project (3D, Forward+, Jolt)
src/autoload/            Net (session, room codes), Game (RPC hub, snapshots), Palette, Settings, Sfx
src/player/              Player (server-simulated FPS body), BotBrain
src/echo/                Echo actor (telegraph, replay, spectral shots)
src/rules/               EchoBuffer, CorebreakRules, CorebreakMode, RelicRules, RelicRushMode
src/match/               Match scene, MatchServer, Objectives presentation, Fx
src/maps/                MapDef builder, OracleGardens, TidelineExchange, VectorFoundry, features/
src/ui/                  Title/menus, HUD, theme, AutoPilot (scripted input for tests)
tests/run_tests.gd       headless unit tests
tools/                   godot.ps1, run_two.ps1, net_test.ps1, screenshot.ps1, gen_sfx.py
```

Visual identity: PALIMPSEST SPORT / FUTURE ARCHAEOLOGY. Ink, porcelain, signal vermilion, oxidized mint,
archival cobalt, instrument brass. No marketplace assets; everything is generated in code.
