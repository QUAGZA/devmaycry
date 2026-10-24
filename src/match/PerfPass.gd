class_name PerfPass
extends RefCounted
## Render-cost pass over a finished, runtime-built arena. Maps are built from code (MapDef / MapKit / PlanRunner),
## so there is no scene file to tune in the editor; instead this pass runs once on whatever the map built and
## applies three techniques generically, which means maps added or fixed by later pulls are covered automatically:
##   1. Visibility range culling - small props stop rendering past a distance scaled to the map and the quality preset.
##   2. Mesh LOD bias - imported models (they carry import-time LODs) drop to lower LODs sooner when small.
##   3. Occlusion culling - tall wall boxes become OccluderInstance3D boxes so geometry behind them is skipped.
## Plus shadow-cost trims (flat decals and tiny props do not cast shadows).
## Gameplay objects (temporal props, gates, ziplines, slings, ladders), emissive signage and large architecture
## are never range-culled. Skip the whole pass for before/after comparisons with the user arg --no-perfpass.

const TINY := 1.5                    # longest AABB side (m): tiny props
const SMALL := 4.0                   # small props; anything larger is architecture and is never range-culled
const TINY_RANGE := 75.0
const SMALL_RANGE := 130.0
const RANGE_MARGIN := 6.0
const SHADOWLESS_BELOW := 0.35       # props smaller than this on every side cast no shadow
const OCCLUDER_CAP := 48
const OCCLUDER_MIN_HEIGHT := 3.0
const OCCLUDER_MIN_LENGTH := 6.0
const OCCLUDER_INSET := 0.1          # occluders are smaller than the wall so they can never hide something visible
const REACH_BY_PRESET := {"low": 0.7, "medium": 0.85, "high": 1.0}
const LOD_THRESHOLD_BY_PRESET := {"low": 2.0, "medium": 1.5, "high": 1.0}


static func enabled() -> bool:
	return DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--no-perfpass")


static func apply(world: Node3D, def: MapDef) -> Dictionary:
	var stats := {"meshes": 0, "ranged": 0, "lod": 0, "no_shadow": 0, "occluders": 0}
	var preset: String = Settings.preset
	var reach := float(REACH_BY_PRESET.get(preset, 1.0)) * clampf(def.extent.length() / 90.0, 0.8, 1.4)
	var vp := world.get_viewport()
	vp.mesh_lod_threshold = float(LOD_THRESHOLD_BY_PRESET.get(preset, 1.0))
	vp.use_occlusion_culling = true
	var walls: Array = []
	for n in world.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		# is_visible_in_tree: a map can hide a whole model by hiding its parent (scenery that cannot be placed clear)
		if mi.mesh == null or not mi.is_visible_in_tree() or _gameplay(mi, world):
			continue
		stats["meshes"] += 1
		var bounds := mi.global_transform * mi.get_aabb()
		var size := bounds.size
		var longest := maxf(size.x, maxf(size.y, size.z))
		# backdrop scenery (cliffs, trees) sits outside the playable footprint and is only ever seen from afar
		var centre := bounds.get_center()
		var backdrop := absf(centre.x) > def.extent.x or absf(centre.z) > def.extent.y
		# flat decals and tiny props: a shadow costs a shadow-map draw and nobody can see it
		if mi.mesh is PlaneMesh or longest < SHADOWLESS_BELOW:
			if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				stats["no_shadow"] += 1
		# imported meshes have import-time LODs (procedural boxes and slabs have none)
		if mi.mesh.resource_path != "":
			if longest < SMALL:
				mi.lod_bias = 0.7
			elif backdrop:
				mi.lod_bias = 0.75
			elif longest < SMALL * 3.0:
				mi.lod_bias = 0.85
			if mi.lod_bias != 1.0:
				stats["lod"] += 1
		# range culling: small, non-emissive props only
		if longest < SMALL and mi.visibility_range_end <= 0.0 and not _emissive(mi):
			mi.visibility_range_end = (TINY_RANGE if longest < TINY else SMALL_RANGE) * reach
			mi.visibility_range_end_margin = RANGE_MARGIN
			stats["ranged"] += 1
		# occluder candidates: tall wall boxes that are direct map geometry
		var body := mi.get_parent() as StaticBody3D
		if body != null and body.get_parent() == def.geometry and mi.mesh is BoxMesh and absf(body.rotation.x) < 0.05 and absf(body.rotation.z) < 0.05:
			var bs := (mi.mesh as BoxMesh).size
			if bs.y >= OCCLUDER_MIN_HEIGHT and maxf(bs.x, bs.z) >= OCCLUDER_MIN_LENGTH and minf(bs.x, bs.z) >= 0.3:
				walls.append({"mi": mi, "volume": bs.x * bs.y * bs.z})
	walls.sort_custom(func(a, b) -> bool: return a["volume"] > b["volume"])
	for w in walls.slice(0, OCCLUDER_CAP):
		var wmi: MeshInstance3D = w["mi"]
		var occ := OccluderInstance3D.new()
		var box := BoxOccluder3D.new()
		box.size = (wmi.mesh as BoxMesh).size - Vector3.ONE * OCCLUDER_INSET
		occ.occluder = box
		occ.transform = wmi.transform
		wmi.get_parent().add_child(occ)
		stats["occluders"] += 1
	stats["walls_seen"] = walls.size()
	stats["reach"] = snappedf(reach, 0.01)
	stats["lod_threshold"] = vp.mesh_lod_threshold
	Game.log_ev("Perf", "pass", stats)
	return stats


## Nodes that carry gameplay or must stay readable at any range.
static func _gameplay(mi: Node, world: Node) -> bool:
	var n := mi.get_parent()
	while n != null and n != world:
		if n is TemporalProp or n is Features.PhaseGate or n is Features.Zipline or n is Features.VectorSling or n is Features.Ladder:
			return true
		n = n.get_parent()
	return false


static func _emissive(mi: MeshInstance3D) -> bool:
	var m := mi.material_override
	return m is StandardMaterial3D and (m as StandardMaterial3D).emission_enabled
