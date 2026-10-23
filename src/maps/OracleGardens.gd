class_name OracleGardens
extends MapDef
## MAP 1 - ORACLE GARDENS. Broad three-lane porcelain terrace garden with a central
## circulation plaza, curved flanks, two sites on distinct approaches, and paired PHASE GATES.


func _init() -> void:
	id = "oracle_gardens"
	display_name = "ORACLE GARDENS"
	mechanic = "PHASE GATES"
	blurb = "Three lanes around a monumental plaza. Paired gates fold the flanks together."
	kill_y = -10.0


func _build_layout() -> void:
	var chalk := mat(Color("B9AE95"), 0.95)
	var porcelain := mat(Palette.PORCELAIN, 0.8)
	var mint := mat(Palette.MINT_DARK, 0.7, 0.15)
	var stone := mat(Palette.STONE, 0.92)
	var ink := mat(Palette.INK, 0.6, 0.3)
	var brass := mat(Palette.BRASS, 0.35, 0.8)
	var vermilion_glow := mat(Palette.VERMILION, 0.5, 0.0, Palette.VERMILION, 2.5)
	var cobalt_glow := mat(Palette.COBALT, 0.5, 0.0, Palette.COBALT, 2.0)
	var pool := mat(Color("5F8FA8"), 0.1, 0.2)
	light_env(Vector3(-0.5, -0.62, 0.42), Color("FFE2BE"), Color("6F95C2"), Color("EAD9B8"), Color("6E685C"), Color("DCCFB4"), 0.0018)

	# Floor plates (140 x 100) and perimeter
	box(Vector3(0, -0.5, 0), Vector3(160, 1, 100), Style.surface("floor", Color("D3C6A8")), "Floor")
	for z in [-50.5, 50.5]:
		box(Vector3(0, 2.5, z), Vector3(162, 5, 1), stone, "", false)
	for x in [-80.5, 80.5]:
		box(Vector3(x, 2.5, 0), Vector3(1, 5, 102), stone, "", false)
	# Floor plate seams (decor)

	# Spawn courts: attackers west (x<0), defenders east (x>0)
	box(Vector3(-66, 1.0, 0), Vector3(1.2, 2.0, 16), mint, "AttackCourtWall")
	box(Vector3(-66, 1.0, -22), Vector3(1.2, 2.0, 10), mint)
	box(Vector3(-66, 1.0, 22), Vector3(1.2, 2.0, 10), mint)
	box(Vector3(66, 1.0, 0), Vector3(1.2, 2.0, 16), mint, "DefendCourtWall")
	box(Vector3(66, 1.0, -22), Vector3(1.2, 2.0, 10), mint)
	box(Vector3(66, 1.0, 22), Vector3(1.2, 2.0, 10), mint)
	# vault-side cover: low ceramic planters flanking each cradle
	for sx in [-1.0, 1.0]:
		for z in [-7.0, 7.0]:
			box(Vector3(sx * 52.0, 0.6, z), Vector3(1.4, 1.2, 3.0), mint)
		box(Vector3(sx * 60.0, 1.3, -13.0), Vector3(3.0, 2.6, 1.0), porcelain)
		box(Vector3(sx * 60.0, 1.3, 13.0), Vector3(3.0, 2.6, 1.0), porcelain)
	for i in 4:
		spawn_point("attack", Vector3(-73, 1.0, -12 + i * 8), -90)
		spawn_point("defend", Vector3(73, 1.0, -12 + i * 8), 90)
	core_spawn = Vector3(-50, 0.6, 0)
	hot_return_layout(Vector3(-58, 0, 0), Vector3(58, 0, 0), Vector3(-62, 0, 0), Vector3(62, 0, 0), Vector3(-27, 0, 29), Vector3(27, 0, 29), 15.0)

	# Central plaza: raised terrace ring with ramps and a monolith
	cylinder(Vector3(0, 0.6, 0), 14.0, 1.2, porcelain)
	cylinder(Vector3(0, 1.4, 0), 7.0, 0.5, porcelain)
	cylinder(Vector3(0, 5.0, 0), 1.6, 8.0, ink, false)
	ring(Vector3(0, 1.75, 0), 7.2, 0.25, brass)
	for a in 4:
		var ang := a * 90.0
		var dir := Vector3(cos(deg_to_rad(ang)), 0, sin(deg_to_rad(ang)))
		slope(dir * 21.5, dir * 13.2 + Vector3(0, 1.2, 0), 6.0, 0.3, chalk)
	# plaza planters (cover)
	for a in 8:
		var ang := a * 45.0 + 22.5
		var dir := Vector3(cos(deg_to_rad(ang)), 0, sin(deg_to_rad(ang)))
		var planter := box(dir * 10.5 + Vector3(0, 1.75, 0), Vector3(2.4, 1.1, 1.2), mint)
		planter.rotation_degrees.y = -ang

	# Mineral pools (visual only, walkable low rims)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("3F6E86")
	water.roughness = 0.04
	water.metallic = 0.4
	water.rim_enabled = true
	water.rim = 0.6
	for p in [Vector3(-28, 0.05, 30), Vector3(28, 0.05, -30)]:
		decal(p, Vector2(10, 7), water)
		box(p + Vector3(0, 0.15, 0), Vector3(11, 0.3, 0.6), stone)
		box(p + Vector3(0, 0.15, 0), Vector3(0.6, 0.3, 8), stone)

	# North lane (z>0): staggered walls and planters forming a curved flank
	for i in 7:
		var x := -45.0 + i * 15.0
		var z := 34.0 + sin(i * 0.9) * 5.0
		box(Vector3(x, 1.4, z), Vector3(4.5, 2.8, 1.2), porcelain)
		box(Vector3(x + 6.0, 0.55, z - 6.0), Vector3(2.2, 1.1, 2.2), mint)
	# South lane (z<0)
	for i in 7:
		var x := -45.0 + i * 15.0
		var z := -34.0 - cos(i * 0.9) * 5.0
		box(Vector3(x, 1.4, z), Vector3(4.5, 2.8, 1.2), porcelain)
		box(Vector3(x - 6.0, 0.55, z + 6.0), Vector3(2.2, 1.1, 2.2), mint)
	# Mid lane cover between spawns and plaza
	for x in [-38.0, -30.0, 30.0, 38.0]:
		for z in [-9.0, 9.0]:
			box(Vector3(x, 0.7, z), Vector3(3.0, 1.4, 1.4), stone)
	# Elevated garden terraces on the flanks (verticality)
	for sx in [-1.0, 1.0]:
		box(Vector3(sx * 22.0, 1.0, 22.0), Vector3(10, 2, 8), chalk)
		ramp(Vector3(sx * 22.0, 0.95, 15.6), Vector3(4, 0.3, 6.0), 0, -20.0, chalk)
		box(Vector3(sx * 22.0, 2.6, 25.5), Vector3(10, 1.2, 0.8), porcelain)
		box(Vector3(sx * 22.0, 1.0, -22.0), Vector3(10, 2, 8), chalk)
		ramp(Vector3(sx * 22.0, 0.95, -15.6), Vector3(4, 0.3, 6.0), 0, 20.0, chalk)
		box(Vector3(sx * 22.0, 2.6, -25.5), Vector3(10, 1.2, 0.8), porcelain)

	# Sites: A north-east, B south-east, each on its own approach angle
	_build_site("A", Vector3(40, 0, 26), vermilion_glow, porcelain, mint)
	_build_site("B", Vector3(40, 0, -26), cobalt_glow, porcelain, mint)

	# PHASE GATES: north-west flank <-> south-east flank, and south-west <-> north-east
	add_gate_pair(Vector3(-40, 0, 44), 180, Vector3(40, 0, -44), 0, "I")
	add_gate_pair(Vector3(-40, 0, -44), 0, Vector3(40, 0, 44), 180, "II")

	# Temporal destructibles: ceramic barricades on the lanes
	var ceramic := Palette.PORCELAIN.darkened(0.05)
	add_temporal_prop(Vector3(-40, 0, -4), Vector3(2.6, 1.6, 0.5), 0, ceramic)
	add_temporal_prop(Vector3(-14, 0, 24), Vector3(2.6, 1.6, 0.5), 90, ceramic)
	add_temporal_prop(Vector3(14, 0, -24), Vector3(2.6, 1.6, 0.5), 90, ceramic)
	add_temporal_prop(Vector3(40, 0, 4), Vector3(2.6, 1.6, 0.5), 0, ceramic)
	add_temporal_prop(Vector3(0, 1.2, 15), Vector3(2.2, 1.4, 0.5), 0, ceramic)
	add_temporal_prop(Vector3(0, 1.2, -15), Vector3(2.2, 1.4, 0.5), 0, ceramic)

	# Signal lights
	for p in [Vector3(-50, 3.0, 45), Vector3(50, 3.0, -45), Vector3(0, 9.3, 0)]:
		box(p, Vector3(0.5, 0.5, 0.5), vermilion_glow, "", false)

	# FFA spawns around the perimeter
	ffa_spawn(Vector3(-60, 1, 40), 45)
	ffa_spawn(Vector3(60, 1, -40), -135)
	ffa_spawn(Vector3(-60, 1, -40), -45)
	ffa_spawn(Vector3(60, 1, 40), 135)
	ffa_spawn(Vector3(0, 1, 44), 180)
	ffa_spawn(Vector3(0, 1, -44), 0)
	ffa_spawn(Vector3(-30, 1, 0), 90)
	ffa_spawn(Vector3(30, 1, 0), -90)
	shard_points = [Vector3(-40, 1, 40), Vector3(40, 1, 40), Vector3(-40, 1, -40), Vector3(40, 1, -40), Vector3(0, 2.2, 0), Vector3(-22, 2.6, 22), Vector3(22, 2.6, -22)]
	beacon_points = [Vector3(0, 1.2, 0), Vector3(40, 0, 26), Vector3(40, 0, -26), Vector3(-40, 0, 0)]
	_art_pass()


## Visual production pass: ceremonial architecture, planting, paving, boundary and backdrop.
## Collision added here is limited to slim columns, buttresses and corner bastions, placed off every
## route, spawn, gate and objective so the measured Hot Return distances stay valid.
func _art_pass() -> void:
	var ivory := Style.surface("stone", Color("E4D8BE"))
	var sand := Style.surface("stone", Color("CDB894"))
	var glaze := Style.surface("ceramic", Color("2F6B66"))
	var cobalt := Style.surface("plaster", Color("3D4C7A"))
	var cliff := Style.surface("cliff", Color("A39783"))
	var mint_e := Style.surface("ceramic", Palette.MINT, Palette.MINT, 1.6)
	var orange_e := Style.surface("ceramic", Color("E2683A"), Color("E2683A"), 1.4)
	var deco := features
	var rng := RandomNumberGenerator.new()
	rng.seed = 7041
	# Paving: promenade bands and diagonal paths in a darker worn tile.
	var pave := Style.surface("floor", Color("B9A88A"))
	decal(Vector3(0, 0.025, 0), Vector2(150, 5.0), pave)
	for z in [-34.0, 34.0]:
		decal(Vector3(0, 0.025, z), Vector2(110, 3.0), pave)
	for a in 4:
		var ang := 45.0 + a * 90.0
		var dir := Vector3(cos(deg_to_rad(ang)), 0, sin(deg_to_rad(ang)))
		decal(dir * 30.0 + Vector3(0, 0.026, 0), Vector2(3.0, 34.0), pave, -ang + 90.0)
	var bed := Style.surface("foliage", Color("5E7A4C"))
	var beds := [Vector3(-12, 0.03, 44), Vector3(12, 0.03, -44), Vector3(-56, 0.03, -36), Vector3(56, 0.03, 36), Vector3(-10, 0.03, -44), Vector3(10, 0.03, 44)]
	for p in beds:
		decal(p, Vector2(9, 3.2), bed)
	# Perimeter: buttressed retaining walls with broken crowns; corner bastions break the rectangle.
	for x in range(-72, 73, 12):
		for zs in [-1.0, 1.0]:
			box(Vector3(x, 2.6, zs * 49.4), Vector3(1.6, 5.2, 1.2), sand, "", false)
			MapDecor._mesh(deco, MapDecor._boxm(Vector3(9.0, 0.6 + absf(sin(x * 0.37)) * 1.6, 1.4)), Vector3(x + 6.0, 5.3, zs * 50.5), ivory)
	for z in range(-36, 37, 12):
		if absf(z) < 20:
			continue
		for xs in [-1.0, 1.0]:
			box(Vector3(xs * 79.4, 2.6, z), Vector3(1.2, 5.2, 1.6), sand, "", false)
	for c in [[Vector3(80, 0, 50), 58.0], [Vector3(80, 0, -50), -58.0], [Vector3(-80, 0, 50), -58.0], [Vector3(-80, 0, -50), 58.0]]:
		var cp: Vector3 = c[0]
		var cy: float = c[1]
		MapDecor.bastion(self, cp, cy, 40.0, 18.0, 6.5, cliff)
		MapDecor.place(deco, MapDecor.NATURE + "cliff_large_stone.glb", cp * 0.97 + Vector3(0, 6.4, 0), 6.0, cy, "cliff", Color(0.66, 0.6, 0.52))
		MapDecor.place(deco, MapDecor.NATURE + "tree_oak.glb", cp * 0.94 + Vector3(0, 6.4, 0), 7.5, rng.randf() * 360.0, "foliage", Color(0.5, 0.66, 0.46))
	# Backdrop beyond the walls: lowland, cliffs and trees closing the world irregularly.
	var ground := MeshInstance3D.new()
	var gp := PlaneMesh.new()
	gp.size = Vector2(420, 320)
	ground.mesh = gp
	ground.position = Vector3(0, -1.2, 0)
	ground.material_override = Style.surface("foliage", Color("6F7F57"))
	deco.add_child(ground)
	for i in 34:
		var t := float(i) / 34.0 * TAU
		var rx := 104.0 + rng.randf_range(-6.0, 14.0)
		var rz := 72.0 + rng.randf_range(-4.0, 12.0)
		var p := Vector3(cos(t) * rx, -1.2, sin(t) * rz)
		var pick: String = ["cliff_large_stone.glb", "cliff_block_stone.glb", "cliff_corner_stone.glb", "cliff_half_stone.glb"][i % 4]
		MapDecor.place(deco, MapDecor.NATURE + pick, p, rng.randf_range(9.0, 22.0), rad_to_deg(-t) + 90.0, "cliff", Color(0.62, 0.57, 0.5))
		if i % 2 == 0:
			var tp := Vector3(cos(t) * (rx - 12.0), -1.2, sin(t) * (rz - 9.0))
			var tree: String = ["tree_oak.glb", "tree_default.glb", "tree_cone.glb"][i % 3]
			MapDecor.place(deco, MapDecor.NATURE + tree, tp, rng.randf_range(8.0, 13.0), rng.randf() * 360.0, "foliage", Color(0.5, 0.66, 0.46))
	# Central fractured sanctuary: colonnade on the upper terrace, arches over the four ramps,
	# and the obelisk wrapped in mint and signal-orange fault lines.
	for a in 8:
		var ang := deg_to_rad(22.5 + a * 45.0)
		MapDecor.solid_column(self, Vector3(cos(ang) * 6.0, 1.65, sin(ang) * 6.0), 4.6, 0.36, ivory, 0.45 if a % 3 == 1 else 0.0)
	for a in 4:
		var ang := a * 90.0
		var dir := Vector3(cos(deg_to_rad(ang)), 0, sin(deg_to_rad(ang)))
		var side := Vector3(-dir.z, 0, dir.x)
		MapDecor.solid_column(self, dir * 23.5 + side * 4.4, 6.0, 0.48, ivory)
		MapDecor.solid_column(self, dir * 23.5 - side * 4.4, 6.0, 0.48, ivory)
		var yaw := -deg_to_rad(ang) + PI * 0.5
		MapDecor._mesh(deco, MapDecor._boxm(Vector3(10.6, 0.7, 1.3)), dir * 23.5 + Vector3(0, 6.35, 0), ivory, Vector3(0, yaw, 0))
		MapDecor._mesh(deco, MapDecor._boxm(Vector3(0.8, 0.9, 1.4)), dir * 23.5 + Vector3(0, 6.6, 0), glaze, Vector3(0, yaw, 0))
	for k in 5:
		var ang := deg_to_rad(k * 72.0 + 10.0)
		MapDecor._mesh(deco, MapDecor._boxm(Vector3(0.08, 6.5, 0.05)), Vector3(cos(ang) * 1.62, 5.0, sin(ang) * 1.62), mint_e if k % 2 == 0 else orange_e, Vector3(0, -ang, 0.06 * (k - 2)))
	MapDecor._mesh(deco, MapDecor._boxm(Vector3(2.6, 0.5, 2.6)), Vector3(0, 9.2, 0), cobalt, Vector3(0.12, 0.4, 0.08))
	# Planting: low hedges on planter cover (under 0.5 m so they never hide a head), trees and
	# obelisks on the elevated terraces, flowers in the beds.
	for body in geometry.get_children():
		if body is StaticBody3D:
			for c in body.get_children():
				if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
					var sz: Vector3 = ((c as MeshInstance3D).mesh as BoxMesh).size
					if absf(sz.y - 1.1) < 0.05 or absf(sz.y - 1.2) < 0.05:
						MapDecor.place(deco, MapDecor.NATURE + "plant_bush.glb", (body as StaticBody3D).position + Vector3(0, sz.y * 0.5 + 0.05, 0), 0.45, rng.randf() * 360.0, "foliage", Color(0.5, 0.66, 0.46))
	for sx in [-1.0, 1.0]:
		for sz2 in [-1.0, 1.0]:
			MapDecor.place(deco, MapDecor.NATURE + "tree_default.glb", Vector3(sx * 26.5, 2.0, sz2 * 18.6), 4.5, rng.randf() * 360.0, "foliage", Color(0.5, 0.66, 0.46))
			MapDecor.place(deco, MapDecor.NATURE + "statue_obelisk.glb", Vector3(sx * 17.6, 2.0, sz2 * 18.6), 2.6, 0.0, "stone", Color(1.0, 0.97, 0.9))
	for p in beds:
		for k in 5:
			var f: String = ["flower_redA.glb", "flower_yellowA.glb", "grass_large.glb"][k % 3]
			if not ResourceLoader.exists(MapDecor.NATURE + f):
				f = "grass_large.glb"
			MapDecor.place(deco, MapDecor.NATURE + f, Vector3(p.x - 3.5 + k * 1.7, 0.0, p.z + rng.randf_range(-0.8, 0.8)), 0.35, rng.randf() * 360.0, "foliage", Color(0.5, 0.66, 0.46))
	# phase gates framed as ceremonial landmarks (visual only, wider than the portal ring)
	for g in [[Vector3(-40, 0, 44), 0.0], [Vector3(40, 0, -44), 0.0], [Vector3(-40, 0, -44), 0.0], [Vector3(40, 0, 44), 0.0]]:
		MapDecor.arch(deco, g[0], g[1], 6.4, 5.6, ivory, glaze)
	MapDecor.dress_boxes(self)


func _build_site(site_id: String, center: Vector3, glow: Material, floor_mat: Material, wall_mat: Material) -> void:
	cylinder(center + Vector3(0, 0.15, 0), 6.5, 0.3, floor_mat)
	ring(center + Vector3(0, 0.36, 0), 6.3, 0.3, glow)
	var sign := 1.0 if center.z > 0 else -1.0
	for a in 3:
		var ang := 120.0 + a * 40.0 * sign
		var dir := Vector3(cos(deg_to_rad(ang)), 0, sin(deg_to_rad(ang)))
		var wall := box(center + dir * 9.0 + Vector3(0, 1.3, 0), Vector3(4.0, 2.6, 1.0), wall_mat)
		wall.rotation_degrees.y = -ang + 90.0
	box(center + Vector3(3.5, 0.6, 0), Vector3(1.2, 1.2, 3.0), wall_mat)
	site(site_id, center, 6.5)
