class_name VectorFoundry
extends MapDef
## MAP 3 - VECTOR FOUNDRY. A kinetic sculpture hall in terracotta, cobalt and bone-white stone with
## brass mechanisms, large geometric rings, offset platforms and VECTOR SLING launch pads.


func _init() -> void:
	id = "vector_foundry"
	display_name = "VECTOR FOUNDRY"
	mechanic = "VECTOR SLINGS"
	blurb = "Kinetic sculpture hall. Launch pads throw you along fixed arcs to offset platforms."
	kill_y = -14.0


func _build_layout() -> void:
	var bone := mat(Color("D8D0C0"), 0.9)
	var terracotta := mat(Palette.TERRACOTTA, 0.85)
	var cobalt := mat(Palette.COBALT_DARK, 0.7, 0.2)
	var brass := mat(Palette.BRASS, 0.3, 0.85)
	var ink := mat(Palette.INK, 0.6, 0.3)
	var vermilion_glow := mat(Palette.VERMILION, 0.5, 0.0, Palette.VERMILION, 2.5)
	var cobalt_glow := mat(Palette.COBALT, 0.5, 0.0, Palette.COBALT, 2.0)
	light_env(Vector3(-0.2, -0.85, -0.45), Color("FFE2C4"), Color("C8B9AD"), Color("E9D9C6"), Color("4A3A33"), Color("D7C4B2"), 0.002)

	box(Vector3(0, -0.5, 0), Vector3(150, 1, 100), bone, "Floor")
	for z in [-50.5, 50.5]:
		box(Vector3(0, 4.0, z), Vector3(152, 8, 1), terracotta, "", false)
	for x in [-75.5, 75.5]:
		box(Vector3(x, 4.0, 0), Vector3(1, 8, 102), terracotta, "", false)
	# floor markings: concentric rings and vectors
	var marking := mat(Color("A34F34"), 1.0)
	for r in [12.0, 24.0, 36.0]:
		ring(Vector3(0, 0.03, 0), r, 0.18, marking)
	for i in range(-6, 7):
		decal(Vector3(i * 11.0, 0.02, 0), Vector2(0.25, 100), marking)

	# Spawn bays
	for i in 4:
		spawn_point("attack", Vector3(-68, 1.0, -9 + i * 6), -90)
		spawn_point("defend", Vector3(68, 1.0, -9 + i * 6), 90)
	core_spawn = Vector3(-44, 0.6, 0)
	hot_return_layout(Vector3(-56, 0, 0), Vector3(56, 0, 0), Vector3(-66, 0, 0), Vector3(66, 0, 0), Vector3(-26, 0, -32), Vector3(26, 0, -32), 15.0)
	for sx in [-1.0, 1.0]:
		box(Vector3(sx * 60, 1.4, 0), Vector3(1.2, 2.8, 10), cobalt)
		box(Vector3(sx * 60, 1.4, 17), Vector3(1.2, 2.8, 8), cobalt)
		box(Vector3(sx * 60, 1.4, -17), Vector3(1.2, 2.8, 8), cobalt)
		cylinder(Vector3(sx * 50, 1.0, -7), 1.3, 2.0, terracotta)
		cylinder(Vector3(sx * 50, 1.0, 7), 1.3, 2.0, terracotta)
		box(Vector3(sx * 54, 1.2, 13), Vector3(5, 2.4, 1.2), bone)
		box(Vector3(sx * 54, 1.2, -13), Vector3(5, 2.4, 1.2), bone)

	# CENTRAL RING: raised annular platform (y = 4) around a sculpture well, ramps on 4 sides
	var ring_y := 4.0
	for a in 12:
		var ang := a * 30.0
		var dir := Vector3(cos(deg_to_rad(ang)), 0, sin(deg_to_rad(ang)))
		var seg := box(dir * 11.0 + Vector3(0, ring_y - 0.3, 0), Vector3(6.4, 0.6, 5.0), bone)
		seg.rotation_degrees.y = -ang
	cylinder(Vector3(0, ring_y - 0.3, 0), 8.6, 0.6, bone)
	cylinder(Vector3(0, 10.0, 0), 1.4, 12.0, ink, false)
	for k in 3:
		var big := ring(Vector3(0, 9.0 + k * 2.5, 0), 5.0 + k * 1.5, 0.35, brass)
		big.rotation_degrees = Vector3(70 + k * 15, k * 40, 0)
		big.name = "KineticRing%d" % k
	for a in 4:
		var ang := a * 90.0 + 45.0
		var dir := Vector3(cos(deg_to_rad(ang)), 0, sin(deg_to_rad(ang)))
		slope(dir * 26.5, dir * 12.6 + Vector3(0, ring_y, 0), 5.0, 0.5, terracotta)
	# ring parapets (cover)
	for a in 8:
		var ang := a * 45.0 + 10.0
		var dir := Vector3(cos(deg_to_rad(ang)), 0, sin(deg_to_rad(ang)))
		var par := box(dir * 13.0 + Vector3(0, ring_y + 0.5, 0), Vector3(2.6, 1.0, 0.5), cobalt)
		par.rotation_degrees.y = -ang + 90.0

	# OFFSET PLATFORMS (y = 3) north and south, reachable by stairs-ramps and slings
	for sz in [-1.0, 1.0]:
		box(Vector3(0, 2.7, sz * 32.0), Vector3(20, 0.6, 10), terracotta, "Offset%s" % ("N" if sz > 0 else "S"))
		slope(Vector3(-18.0, 0, sz * 32.0), Vector3(-9.0, 3.0, sz * 32.0), 5.0, 0.4, bone)
		slope(Vector3(18.0, 0, sz * 32.0), Vector3(9.0, 3.0, sz * 32.0), 5.0, 0.4, bone)
		box(Vector3(0, 3.6, sz * 36.8), Vector3(20, 1.2, 0.5), cobalt)
		box(Vector3(0, 3.6, sz * 27.2), Vector3(6, 1.2, 0.5), cobalt)

	# Lane cover: ceramic kilns and brass mechanisms
	for x in [-34.0, -26.0, 26.0, 34.0]:
		for z in [-12.0, 12.0]:
			cylinder(Vector3(x, 1.0, z), 1.3, 2.0, terracotta)
	for x in [-36.0, -18.0, 18.0, 36.0]:
		for z in [-40.0, 40.0]:
			box(Vector3(x, 1.2, z), Vector3(4.0, 2.4, 1.2), bone)
			box(Vector3(x, 0.6, z + (-6.0 if z > 0 else 6.0)), Vector3(2.0, 1.2, 2.0), brass)

	# Sites: A on a raised dais north-east, B ground level south-east
	box(Vector3(38, 0.6, 26), Vector3(16, 1.2, 14), bone, "DaisA")
	slope(Vector3(24.0, 0, 26), Vector3(31.0, 1.2, 26), 3.5, 0.4, terracotta)
	slope(Vector3(38, 0, 14.0), Vector3(38, 1.2, 20.0), 6.0, 0.4, terracotta)
	ring(Vector3(38, 1.56, 26), 5.8, 0.3, vermilion_glow)
	site("A", Vector3(38, 1.2, 26), 6.0)
	box(Vector3(38, 1.8, 33.5), Vector3(16, 1.2, 0.5), cobalt)
	ring(Vector3(38, 0.36, -26), 5.8, 0.3, cobalt_glow)
	site("B", Vector3(38, 0.0, -26), 6.0)
	box(Vector3(31, 1.3, -19), Vector3(1.0, 2.6, 6), cobalt)
	box(Vector3(45, 1.3, -33), Vector3(1.0, 2.6, 6), cobalt)

	# Temporal destructibles: terracotta barriers
	var terra := Palette.TERRACOTTA.lightened(0.15)
	add_temporal_prop(Vector3(-30, 0, 6), Vector3(2.6, 1.6, 0.5), 0, terra)
	add_temporal_prop(Vector3(30, 0, -6), Vector3(2.6, 1.6, 0.5), 0, terra)
	add_temporal_prop(Vector3(-18, 0, 30), Vector3(2.4, 1.5, 0.5), 90, terra)
	add_temporal_prop(Vector3(18, 0, -30), Vector3(2.4, 1.5, 0.5), 90, terra)
	add_temporal_prop(Vector3(0, ring_y, 6), Vector3(2.2, 1.3, 0.5), 0, terra)

	# VECTOR SLINGS: attackers' pads west, defenders' pads east, plus ring-to-dais hops
	add_sling(Vector3(-40, 0, 20), Vector3(-9.5, ring_y, 5.5), 1.5, "W1")
	add_sling(Vector3(-40, 0, -20), Vector3(0, 3.0, -32), 1.6, "W2")
	add_sling(Vector3(40, 0, 8), Vector3(10.2, ring_y, 3.6), 1.4, "E1")
	add_sling(Vector3(22, 0, 40), Vector3(38, 1.2, 26), 1.3, "E2")
	add_sling(Vector3(0, ring_y, -8), Vector3(0, 3.0, 32), 1.7, "C1")

	for p in [Vector3(-50, 5.0, 45), Vector3(50, 5.0, -45), Vector3(0, 16.3, 0)]:
		box(p, Vector3(0.5, 0.5, 0.5), vermilion_glow, "", false)

	ffa_spawn(Vector3(-50, 1, 42), 45)
	ffa_spawn(Vector3(50, 1, -42), -135)
	ffa_spawn(Vector3(-50, 1, -42), -45)
	ffa_spawn(Vector3(50, 1, 42), 135)
	ffa_spawn(Vector3(0, 4, 32), 180)
	ffa_spawn(Vector3(0, 4, -32), 0)
	ffa_spawn(Vector3(-30, 1, 0), 90)
	ffa_spawn(Vector3(30, 1, 0), -90)
	shard_points = [Vector3(0, ring_y + 0.6, 0), Vector3(0, 3.6, 32), Vector3(0, 3.6, -32), Vector3(-40, 1, 40), Vector3(40, 1, -40), Vector3(38, 1.8, 26), Vector3(-36, 1, -40)]
	beacon_points = [Vector3(0, ring_y, 0), Vector3(0, 3.0, 32), Vector3(38, 0, -26), Vector3(-36, 0, 0)]
