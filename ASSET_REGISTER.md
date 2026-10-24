# ECHO CLASH — External Asset Register

Every third-party file in the game, where it came from, its licence and what was done to it.
Raw downloads are kept locally in `assets/_source/` (git-ignored, not redistributed as packs).
Processed files used by the game live under `assets/models`, `assets/textures` and `assets/sfx/kenney`.
All licences were read on the source page and in the files shipped with each pack on 2026-10-24.

| Asset | Source URL | Author | Licence | Attribution | Downloaded to | Used as / modifications |
|---|---|---|---|---|---|---|
| Universal Base Characters [Standard] | https://quaternius.itch.io/universal-base-characters (linked from https://quaternius.com/packs/universalbasecharacters.html) | Quaternius | CC0 1.0 (`License_Standard.txt` in the zip; pack page says CC0) | Not required (credited in-game) | `assets/_source/quaternius_ubc/` | `Superhero_Male_FullBody.gltf` + textures copied to `assets/models/characters/`. Restyled through the toon shader (desaturated, darkened). Tactical gear (helmet, plate carrier, pouches, pads, boots, gloves, backpack) is original geometry attached to its bones in `src/player/TacticalRig.gd`. |
| Universal Animation Library [Standard] | https://quaternius.itch.io/universal-animation-library | Quaternius | CC0 1.0 (txt in zip) | Not required | `assets/_source/quaternius_ual/` | `UAL1_Standard.glb` (Unreal-Godot skeleton) copied to `assets/models/anim/`. Clips Idle, Walk, Jog_Fwd, Sprint, Crouch_Idle, Crouch_Fwd, Jump, Pistol_Aim_Neutral, Pistol_Shoot, Pistol_Reload, Death01 drive an AnimationTree with an upper-body aim layer. |
| Blaster Kit 2.1 | https://kenney.nl/assets/blaster-kit | Kenney | CC0 1.0 (asset page + License.txt) | Not required | `assets/_source/kenney/kenney_blaster-kit_2.1.zip` | blaster-a/d/e/l + scope/clip parts copied to `assets/models/weapons/`. Rotated, desaturated to graphite, accent stripe per weapon, combined with attachments in `src/weapons/WeaponModels.gd`. |
| Nature Kit | https://kenney.nl/assets/nature-kit | Kenney | CC0 1.0 | Not required | `assets/_source/kenney/kenney_nature-kit.zip` | 33 models (cliffs, rocks, trees, bushes, grass, statues) copied to `assets/models/nature/`, scaled and re-tinted through the toon shader for Oracle Gardens planting and backdrop. |
| Space Station Kit | https://kenney.nl/assets/space-station-kit | Kenney | CC0 1.0 | Not required | `assets/_source/kenney/kenney_space-station-kit.zip` | Copied to `assets/models/station/`; available to the industrial maps (current industrial dressing is mostly procedural). |
| Impact Sounds 1.0 | https://kenney.nl/assets/impact-sounds | Kenney | CC0 1.0 (License.txt) | Not required | `assets/_source/kenney/kenney_impact-sounds.zip` | 40 OGG files copied to `assets/sfx/kenney/`: footsteps (concrete, grass), metal plate steps, landing, shell casings, stone/metal/flesh bullet impacts, played positionally via `Sfx.play_at`. |
| sandstone_cracks, painted_plaster_wall, worn_tile_floor, metal_plate, rusty_metal_02, castle_wall_slates, concrete_floor_worn_001 (1K JPG: diffuse + OpenGL normal) | https://polyhaven.com/a/<id> (via https://api.polyhaven.com/files/<id>) | Poly Haven contributors | CC0 1.0 | Not required | `assets/_source/polyhaven/` | Copied to `assets/textures/detail/` as `<id>_col.jpg` / `<id>_nrm.jpg`. Sampled triplanar as luminance and normal detail beneath the palette colour in `palimpsest_toon.gdshader`; never shown as raw photo albedo. `plastered_stone_wall` was downloaded but not used. |

## Attempted but not used

| Asset | Reason |
|---|---|
| Quaternius Toon Shooter Game Kit, Sci-Fi Modular Guns, Ultimate Modular Ruins (CC0) | Hosted on Google Drive; every file request returned "Google Drive – Quota exceeded". The quota was not bypassed. |
| Quaternius Sci-Fi Essentials Kit (CC0, itch.io, 159 MB) | Download stalled twice on this connection; dropped in favour of the Kenney kits. |

## Supplied by the project owner

| Asset | Use |
|---|---|
| `assets/sfx/bg_soundtrack/theplan.wav` (PCM WAV, 186 s, 71 MB) | Main-menu / startup soundtrack, used unmodified; looped at the last audible sample by its `.import` settings and played through the `Music` autoload. |

## Original (made for this project)

Shaders `palimpsest_toon`, `ink_outline`, `sea`, `core`, `rewind`, `fastforward_ring`, `stability_field`, `portal_ring`,
`minimap_mask`, `surface`; all map layouts and procedural architecture (`MapDecor.gd`); the 28 procedural WAV cues
from `tools/gen_sfx.py`; UI, HUD, fonts styling and logo treatment.
