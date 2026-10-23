class_name OracleSanctuary
extends MapDef
## MAP A - ORACLE GARDENS (final). Original layout, mirror-symmetric about x = 0 so the side swap is
## fair. Plan (west half; east is the mirror):
##   spawn court (x -86..-72) -> roofed TEMPLE holding the vault (x -70..-50), doors W / E / N / S
##   MID   : dog-legged colonnade lane (z -7..7) into the central octagonal COURTYARD (r 19) with a
##           raised dais, obelisk and colonnade; risky, short, broken sightlines.
##   NORTH : raised garden TERRACE (y 2.2) carrying a Stability Field, stairs on three sides, and the
##           colonnade walk behind the courtyard; the long safe-field route.
##   SOUTH : roofed CHAPEL interior, the SUNKEN BASIN (y -1.6) reached by stairs, and a PHASE GATE in
##           the south-west corner pairing with the north-east corner (flank / rotation).
##   LOOPS : cut-throughs from the mid lane to the terrace stairs (north) and to the chapel (south).

const H_TEMPLE := 6.5
const TERRACE_Y := 3.0
const BASIN_Y := -1.6


func _init() -> void:
	family = "oracle"
	id = "oracle_gardens"
	display_name = "ORACLE GARDENS"
	mechanic = "PHASE GATES"
	blurb = "Ancient-future sanctuary: temples, terraces, a sunken basin and paired gates."
	kill_y = -12.0


func _side(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p)
	return out


func _build_layout() -> void:
	var ivory := Style.surface("stone", Color("E4D8BE"))
	var sand := Style.surface("stone", Color("CDB894"))
	var floor_m := Style.surface("floor", Color("CFC1A2"))
	var pave := Style.surface("floor", Color("B4A486"))
	var roof_m := Style.surface("plaster", Color("8E7F6A"))
	var glaze := Style.surface("ceramic", Color("2F6B66"))
	var cobalt := Style.surface("plaster", Color("3D4C7A"))
	var brass := Style.surface("metal", Palette.BRASS)
	var ink := Style.surface("gear", Palette.INK)
	light_env(Vector3(-0.5, -0.62, 0.42), Color("FFE2BE"), Color("6F95C2"), Color("EAD9B8"), Color("6E685C"), Color("DCCFB4"), 0.0018)
	extent = Vector2(90, 52)

	# ---------------------------------------------------------------- outline and floors
	var west := [Vector2(0, -50), Vector2(-24, -50), Vector2(-34, -47), Vector2(-56, -47), Vector2(-64, -40), Vector2(-76, -31),
		Vector2(-86, -18), Vector2(-89, -6), Vector2(-89, 8), Vector2(-83, 20), Vector2(-71, 31), Vector2(-57, 43), Vector2(-40, 47),
		Vector2(-18, 47), Vector2(-8, 45), Vector2(0, 45)]
	var outline := PackedVector2Array()
	for p in west:
		outline.append(p)
	for i in range(west.size() - 2, 0, -1):
		outline.append(Vector2(-west[i].x, west[i].y))
	var basin := MapKit.rect(0, 30, 24, 15)
	MapKit.floor_with_holes(self, outline, [basin], 0.0, 2.0, floor_m)
	MapKit.slab(self, MapKit.rect(0, 30, 25, 16), BASIN_Y, 1.0, pave)
	# perimeter wall following the irregular outline
	var loop: Array = []
	for p in outline:
		loop.append(p)
	MapKit.walls(self, loop, 7.0, 1.2, sand, true)

	# ---------------------------------------------------------------- mirrored halves
	for sx in [-1.0, 1.0]:
		_half(sx, ivory, sand, roof_m, glaze, pave, brass)

	# ---------------------------------------------------------------- centre: octagonal courtyard
	var octo := MapKit.ngon(0, 0, 19.0, 8, PI / 8.0)
	var oct_pts: Array = []
	for p in octo:
		oct_pts.append(p)
	MapKit.walls(self, oct_pts, 5.0, 1.0, ivory, true, [1, 3, 5, 7])
	MapKit.slab(self, MapKit.ngon(0, 0, 7.5, 12), 0.5, 0.5, pave)
	cylinder(Vector3(0, 5.0, 0), 1.5, 9.0, ink, true)
	for k in 6:
		var a := TAU * float(k) / 6.0 + 0.3
		MapDecor.solid_column(self, Vector3(cos(a) * 5.6, 0.5, sin(a) * 5.6), 4.6, 0.38, ivory, 0.45 if k % 3 == 1 else 0.0)
	for k in 4:
		var a2 := PI * 0.5 * float(k) + PI * 0.25
		var cp := Vector3(cos(a2) * 13.0, 0, sin(a2) * 13.0)
		box(cp + Vector3(0, 0.6, 0), Vector3(3.2, 1.2, 1.2), glaze).rotation.y = -a2
	# arches framing the four courtyard openings (visual lintels over solid columns)
	for k in 4:
		var ang := PI * 0.5 * float(k)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-dir.z, 0, dir.x)
		var c := dir * 17.6
		MapDecor.solid_column(self, c + side * 6.2, 6.0, 0.55, ivory)
		MapDecor.solid_column(self, c - side * 6.2, 6.0, 0.55, ivory)
		MapDecor._mesh(features, MapDecor._boxm(Vector3(14.0, 0.8, 1.4)), c + Vector3(0, 6.4, 0), ivory, Vector3(0, -ang + PI * 0.5, 0))
	# north colonnade walk (behind the courtyard, joins both terraces)
	for i in range(-3, 4):
		if i == 0:
			continue
		MapDecor.solid_column(self, Vector3(i * 6.0, 0, -38.0), 5.0, 0.45, ivory, 0.5 if absi(i) == 2 else 0.0)
	box(Vector3(0, 0.75, -41.0), Vector3(6.0, 1.5, 1.2), glaze)
	# elevated bridge joining the two terraces over the colonnade walk (2.6 m clearance underneath)
	MapKit.slab(self, MapKit.rect(0, -30.0, 49.0, 5.0), TERRACE_Y, 0.4, pave)
	for zz in [-32.4, -27.6]:
		MapKit.wall(self, Vector2(-23.5, zz), Vector2(23.5, zz), 1.0, 0.3, ivory, TERRACE_Y, false)
	for xx in [-12.0, 0.0, 12.0]:
		MapDecor.solid_column(self, Vector3(xx, 0, -30.0), TERRACE_Y - 0.4, 0.35, ivory)
	# sunken basin: stairs from the courtyard and from both chapels, pool, cover
	MapKit.stairs(self, Vector3(0, 0, 19.5), Vector3(0, BASIN_Y, 23.5), 6.0, pave, ivory)
	for sx2 in [-1.0, 1.0]:
		MapKit.stairs(self, Vector3(sx2 * 17.5, 0, 31.0), Vector3(sx2 * 12.5, BASIN_Y, 31.0), 5.0, pave, ivory)
		box(Vector3(sx2 * 5.0, BASIN_Y + 0.7, 33.0), Vector3(2.6, 1.4, 1.2), glaze)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("3F6E86")
	water.roughness = 0.04
	water.metallic = 0.4
	water.rim_enabled = true
	decal(Vector3(0, BASIN_Y + 0.03, 34.0), Vector2(8, 4), water)
	box(Vector3(0, BASIN_Y + 0.6, 28.0), Vector3(1.4, 1.2, 3.0), ivory)

	# ---------------------------------------------------------------- objectives and spawns
	hot_return_layout(Vector3(-55, 0, 0), Vector3(55, 0, 0), Vector3(-66, 0, -22), Vector3(66, 0, -22), Vector3(-30, TERRACE_Y, -27), Vector3(30, TERRACE_Y, -27), 12.0)
	core_spawn = Vector3(-55, 0.6, 0)
	for i in 4:
		spawn_point("attack", Vector3(-82, 0.5, -6 + i * 4), -90)
		spawn_point("defend", Vector3(82, 0.5, -6 + i * 4), 90)
	for p in [Vector3(-60, 0.5, 24), Vector3(60, 0.5, -24), Vector3(-40, TERRACE_Y + 0.5, -36), Vector3(40, TERRACE_Y + 0.5, -36), Vector3(0, 0.5, -44), Vector3(0, BASIN_Y + 0.5, 30), Vector3(-30, 0.5, 0), Vector3(30, 0.5, 0)]:
		ffa_spawn(p, 0)
	shard_points = [Vector3(0, 1.0, 9.5), Vector3(-40, TERRACE_Y + 0.5, -40), Vector3(40, TERRACE_Y + 0.5, -40), Vector3(0, BASIN_Y + 0.5, 26), Vector3(-39, 0.5, 26), Vector3(39, 0.5, 26), Vector3(0, 0.5, -44)]
	beacon_points = [Vector3(0, 0.5, 9.0), Vector3(-40, TERRACE_Y, -30), Vector3(40, TERRACE_Y, -30), Vector3(0, BASIN_Y, 30)]
	# phase gates: SW <-> NE and SE <-> NW corners (mirror pair)
	add_gate_pair(Vector3(-66, 0, 30), -45, Vector3(66, 0, -27), 135, "I")
	add_gate_pair(Vector3(66, 0, 30), 45, Vector3(-66, 0, -27), -135, "II")
	_backdrop()
	MapDecor.dress_boxes(self)


## One half of the map (sx = -1 west, +1 east). Everything here is mirrored exactly.
func _half(sx: float, ivory: Material, sand: Material, roof_m: Material, glaze: Material, pave: Material, brass: Material) -> void:
	# temple holding the vault: roofed interior with doorways on all four sides
	var west_door := [[0.0, 4.0]]
	MapKit.room(self, sx * 60.0, 0.0, 20.0, 20.0, H_TEMPLE, ivory, {"w" if sx < 0 else "e": west_door, "e" if sx < 0 else "w": [[0.0, 6.0]], "n": [[-sx * 2.0, 4.0]], "s": [[-sx * 2.0, 4.0]]}, roof_m)
	for zz in [-5.0, 5.0]:
		MapDecor.solid_column(self, Vector3(sx * 62.0, 0, zz), H_TEMPLE - 0.4, 0.42, ivory)
	box(Vector3(sx * 66.0, 0.7, -6.0), Vector3(1.4, 1.4, 3.0), glaze)
	box(Vector3(sx * 66.0, 0.7, 6.0), Vector3(1.4, 1.4, 3.0), glaze)
	# mid lane: dog-leg walls, colonnade and an offset half wall that breaks the long sightline
	MapKit.wall(self, Vector2(sx * 50.0, -7.0), Vector2(sx * 38.5, -7.0), 4.5, 1.0, sand)
	MapKit.wall(self, Vector2(sx * 33.5, -7.0), Vector2(sx * 19.0, -7.0), 4.5, 1.0, sand)
	MapKit.wall(self, Vector2(sx * 50.0, 7.0), Vector2(sx * 28.5, 7.0), 4.5, 1.0, sand)
	MapKit.wall(self, Vector2(sx * 23.5, 7.0), Vector2(sx * 19.0, 7.0), 4.5, 1.0, sand)
	box(Vector3(sx * 42.0, 0.85, -1.5), Vector3(1.2, 1.7, 7.0), ivory)
	box(Vector3(sx * 29.0, 0.6, 2.5), Vector3(2.4, 1.2, 1.2), glaze)
	for xx in [46.0, 36.0, 26.0]:
		MapDecor.solid_column(self, Vector3(sx * xx, 0, -5.4), 4.4, 0.4, ivory, 0.4 if xx == 36.0 else 0.0)
	add_temporal_prop(Vector3(sx * 34.0, 0, 3.5), Vector3(2.6, 1.6, 0.5), 90, Palette.PORCELAIN.darkened(0.05))
	# north: raised garden terrace with stairs on three sides (Stability Field route)
	var terrace := PackedVector2Array([Vector2(-54, -44), Vector2(-30, -44), Vector2(-24, -38), Vector2(-24, -26), Vector2(-32, -22), Vector2(-50, -24), Vector2(-56, -30)])
	if sx > 0:
		terrace = MapKit.mirror_x(terrace)
	MapKit.slab(self, terrace, TERRACE_Y, TERRACE_Y + 0.1, Style.surface("stone", Color("D8CAAA")))
	MapKit.stairs(self, Vector3(sx * 36.0, 0, -15.5), Vector3(sx * 36.0, TERRACE_Y, -23.0), 4.5, pave, ivory)
	MapKit.stairs(self, Vector3(sx * 16.0, 0, -33.0), Vector3(sx * 23.5, TERRACE_Y, -33.0), 4.5, pave, ivory)
	MapKit.stairs(self, Vector3(sx * 63.5, 0, -33.0), Vector3(sx * 55.5, TERRACE_Y, -33.0), 4.5, pave, ivory)
	box(Vector3(sx * 44.0, TERRACE_Y + 0.6, -40.0), Vector3(3.0, 1.2, 1.2), glaze)
	box(Vector3(sx * 33.0, TERRACE_Y + 0.6, -30.0), Vector3(1.2, 1.2, 3.0), glaze)
	MapDecor.place(features, MapDecor.NATURE + "tree_default.glb", Vector3(sx * 50.0, TERRACE_Y, -40.0), 5.0, 30.0, "foliage", Color(0.5, 0.66, 0.46))
	MapDecor.place(features, MapDecor.NATURE + "tree_oak.glb", Vector3(sx * 28.0, TERRACE_Y, -41.0), 5.5, 80.0, "foliage", Color(0.5, 0.66, 0.46))
	# south: roofed chapel interior with three doorways, then the basin stairs
	MapKit.room(self, sx * 39.0, 26.0, 18.0, 14.0, 5.5, ivory, {"n": [[0.0, 4.0]], "e" if sx < 0 else "w": [[5.0, 4.0]], "w" if sx < 0 else "e": [[-2.0, 4.0]]}, roof_m)
	box(Vector3(sx * 39.0, 0.6, 26.0), Vector3(4.0, 1.2, 1.2), glaze)
	MapDecor.solid_column(self, Vector3(sx * 34.0, 0, 22.0), 5.1, 0.4, ivory)
	MapDecor.solid_column(self, Vector3(sx * 44.0, 0, 30.0), 5.1, 0.4, ivory)
	add_temporal_prop(Vector3(sx * 39.0, 0, 16.5), Vector3(2.6, 1.6, 0.5), 0, Palette.PORCELAIN.darkened(0.05))
	# south-west yard between spawn, temple and chapel: low cover
	box(Vector3(sx * 58.0, 0.6, 18.0), Vector3(3.0, 1.2, 1.2), glaze)
	box(Vector3(sx * 52.0, 0.8, 34.0), Vector3(1.2, 1.6, 3.4), ivory)
	box(Vector3(sx * 74.0, 0.8, 10.0), Vector3(3.0, 1.6, 1.2), ivory)
	box(Vector3(sx * 74.0, 0.8, -10.0), Vector3(3.0, 1.6, 1.2), ivory)
	# north yard near the stabilizer: offset cover
	box(Vector3(sx * 62.0, 0.6, -18.0), Vector3(1.2, 1.2, 3.0), glaze)
	box(Vector3(sx * 78.0, 0.8, -24.0), Vector3(3.0, 1.6, 1.2), ivory)


func _backdrop() -> void:
	var ground := MeshInstance3D.new()
	var gp := PlaneMesh.new()
	gp.size = Vector2(440, 320)
	ground.mesh = gp
	ground.position = Vector3(0, -2.0, 0)
	ground.material_override = Style.surface("foliage", Color("6F7F57"))
	features.add_child(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9181
	for i in 30:
		var t := float(i) / 30.0 * TAU
		var p := Vector3(cos(t) * rng.randf_range(108.0, 122.0), -2.0, sin(t) * rng.randf_range(66.0, 80.0))
		var pick: String = ["cliff_large_stone.glb", "cliff_block_stone.glb", "cliff_corner_stone.glb", "cliff_half_stone.glb"][i % 4]
		MapDecor.place(features, MapDecor.NATURE + pick, p, rng.randf_range(10.0, 24.0), rad_to_deg(-t) + 90.0, "cliff", Color(0.62, 0.57, 0.5))
		if i % 2 == 0:
			MapDecor.place(features, MapDecor.NATURE + ["tree_oak.glb", "tree_default.glb", "tree_cone.glb"][i % 3], p * 0.9 + Vector3(0, 0, 0), rng.randf_range(8.0, 13.0), rng.randf() * 360.0, "foliage", Color(0.5, 0.66, 0.46))
