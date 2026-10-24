# Echo Clash

A fast first-person team shooter where the arena remembers the last few seconds, and you can bend time to win.

## Download

**Get the Windows game here: [Releases page](https://github.com/QUAGZA/devmaycry/releases/latest)**

Download `EchoClash.exe` (or the `.zip`), then double-click it to play. Nothing else to install.
If Windows shows a "protected your PC" warning, click **More info**, then **Run anyway**.

## How to play

There are two teams. The attackers try to steal the **Core** from the defenders' base and carry it back home
before its timer runs out and it blows up. The defenders try to stop them. First team to win 3 rounds wins the match.

Each team has one time power per round (press **Q**):
- **Attackers** rewind time: your body runs back along your path and the Core's timer goes back a few seconds.
- **Defenders** speed time up in a small area, so the Core's timer runs out faster.

There is also a free-for-all mode, **Relic Rush**. Play offline against bots, or with friends on the same Wi-Fi/LAN.

### Controls

| Key | Action |
|---|---|
| W A S D | Move |
| Mouse | Look and aim |
| Left click | Shoot |
| Right click | Aim down sights |
| R | Reload |
| Space | Jump |
| Shift | Sprint |
| C | Crouch |
| Ctrl | Dash |
| Q | Time power (once per round) |
| E | Use / ride a zipline |
| G | Drop the Core |
| 1 / 2 or mouse wheel | Switch weapon |
| B | Open the armory (pick your two weapons) |
| Caps Lock | Map |
| Tab | Scoreboard |
| Esc | Pause |

## Run from source

1. Install [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/) (the standard version, not .NET).
2. Open Godot, click **Import**, and pick `project.godot` from this folder.
3. Press **Play** (F5).

## Project files

- [ECHO_CLASH_SETUP.md](ECHO_CLASH_SETUP.md): full setup, all rules, hosting and joining LAN games
- [ECHO_CLASH_BUILD_STATUS.md](ECHO_CLASH_BUILD_STATUS.md): what is done and what is not
- [ECHO_CLASH_TEST_PLAN.md](ECHO_CLASH_TEST_PLAN.md): tests and results
- [ECHO_CLASH_AUDIT.md](ECHO_CLASH_AUDIT.md): project audit
- [ASSET_REGISTER.md](ASSET_REGISTER.md): where the art and sounds come from (all free CC0 assets)
- `src/`: game code, `assets/`: models, sounds and images
