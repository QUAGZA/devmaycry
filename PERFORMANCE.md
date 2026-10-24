# Render performance pass

Maps are built from code (`MapDef`, `MapKit`, `PlanRunner`), so there are no scene files to tune in the editor.
[src/match/PerfPass.gd](src/match/PerfPass.gd) runs once per match on the finished arena (called from
`Match._ready`, right after `bake_nav`) and applies the optimizations generically. Maps added or fixed by later
pulls are covered without any per-map change; the only shared-file edit is the two-line call in `Match.gd`.

| Technique | What the pass does | Where |
|---|---|---|
| Visibility range culling | Props under 4 m stop rendering past 75 m (under 1.5 m) or 130 m (1.5-4 m), scaled by map size and graphics preset (Low x0.7, Medium x0.85, High x1.0), 6 m hysteresis margin. Architecture, emissive signage, temporal props, gates, ziplines, slings and ladders are never culled. | `PerfPass.apply` |
| LOD | Imported models (they carry import-time LODs) get `lod_bias` 0.7 (under 4 m), 0.75 (backdrop scenery outside the playable footprint, any size) or 0.85 (under 12 m); other large and procedural meshes stay at 1.0. `Viewport.mesh_lod_threshold` is 1.0 on High, 1.5 on Medium, 2.0 on Low. | `PerfPass.apply` |
| Occlusion culling | `rendering/occlusion_culling/use_occlusion_culling` is on, and the 48 largest tall wall boxes (height >= 3 m, length >= 6 m) get a `BoxOccluder3D` 0.1 m smaller than the wall. | `PerfPass.apply`, `project.godot` |
| Shadow cost | Flat decals and props under 0.35 m cast no shadow. | `PerfPass.apply` |

## Lightmap GI: not applied

LightmapGI bakes in the editor against meshes with UV2 on a saved scene. These arenas are generated at runtime, so
there is nothing to bake and no lightmap could be shipped. The sun keeps its real-time shadows. Instead the
Low and Medium presets already shrink shadow atlas size and filter quality (`Settings.apply_graphics`).
If a map is ever turned into a saved scene, set the Sun to `Bake Mode: Static`, the static meshes to
`GI Mode: Static`, add a `LightmapGI` with Texel Scale 0.2 and bake.

## Measuring before and after

* `--no-perfpass` skips the whole pass, so the same run can be repeated without it.
* `--perf` (see `Game._perf`) logs average FPS, worst frame, draw calls, objects and VRAM every 5 s.
* Each match logs one `Perf / pass` event with the counts the pass touched (`ranged`, `lod`, `no_shadow`,
  `occluders`, `walls_seen`).

Example: `tools\godot.ps1 -- --perf --quit-after-sec=60` against the same map with and without `--no-perfpass`.

## After pulling map changes

Nothing to merge in the maps: re-run a match and check the `Perf / pass` log line. If a new map adds gameplay
objects that must never be culled, add their class to `PerfPass._gameplay`.
