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
	light_env(Vector3(-0.45, -0.8, 0.35), Color("FFE9CC"), Color("B9C9DA"), Color("E6DCC8"), Color("6E685C"), Color("D9D0BE"), 0.0015)

	# Floor plates (140 x 100) and perimeter
	box(Vector3(0, -0.5, 0), Vector3(140, 1, 100), chalk, "Floor")
	for z in [-50.5, 50.5]:
		box(Vector3(0, 2.5, z), Vector3(142, 5, 1), stone, "", false)
	for x in [-70.5, 70.5]:
		box(Vector3(x, 2.5, 0), Vector3(1, 5, 102), stone, "", false)
	# Floor plate seams (decor)
	var seam := mat(Palette.STONE.darkened(0.25), 1.0)
	for i in range(-6, 7):
		decal(Vector3(i * 10.0, 0.02, 0), Vector2(0.25, 100), seam)
	for j in range(-4, 5):
		decal(Vector3(0, 0.02, j * 10.0), Vector2(140, 0.25), seam)

	# Spawn courts: attackers west (x<0), defenders east (x>0)
	box(Vector3(-56, 1.0, 0), Vector3(1.2, 2.0, 16), mint, "AttackCourtWall")
	box(Vector3(-56, 1.0, -22), Vector3(1.2, 2.0, 10), mint)
	box(Vector3(-56, 1.0, 22), Vector3(1.2, 2.0, 10), mint)
	box(Vector3(56, 1.0, 0), Vector3(1.2, 2.0, 16), mint, "DefendCourtWall")
	box(Vector3(56, 1.0, -22), Vector3(1.2, 2.0, 10), mint)
	box(Vector3(56, 1.0, 22), Vector3(1.2, 2.0, 10), mint)
	for i in 4:
		spawn_point("attack", Vector3(-63, 1.0, -12 + i * 8), -90)
		spawn_point("defend", Vector3(63, 1.0, -12 + i * 8), 90)
	core_spawn = Vector3(-50, 0.6, 0)
	hot_return_layout(Vector3(-50, 0, 0), Vector3(50, 0, 0), Vector3(-63, 0, 0), Vector3(63, 0, 0), Vector3(-22, 2.0, 22), Vector3(22, 2.0, -22))

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
	for p in [Vector3(-28, 0.05, 30), Vector3(28, 0.05, -30)]:
		decal(p, Vector2(10, 7), pool)
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
