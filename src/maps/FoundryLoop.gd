class_name FoundryLoop
extends MapDef
## MAP C - VECTOR FOUNDRY (final). Kinetic engineering complex, mirror-symmetric about x = 0.
## Plan (west half; east is the mirror):
##   spawn yard (x -86..-74) -> roofed ASSEMBLY CHAMBER with the vault (x -69..-51)
##   CENTRE : circular REACTOR HALL (r 17, roofed at 11 m) inside a curved RING LOOP (r 17..27) whose outer
##            wall opens at eight points; the main contested route bends around the reactor.
##   NORTH  : WATCHTOWER (platform y 6) with LADDERS on its west and east faces, joined to two narrow
##            elevated WALKWAYS; VECTOR LAUNCH PADS throw players from the yard onto the walkway ends.
##            The tower sees the north yard but the ring and reactor hall block it from the centre.
##   SOUTH  : covered SERVICE TUNNEL (floor y -3.2) under the south deck, ramps at both ends; both
##            Stability Fields are inside the tunnel (long, protected, safe-field route).
##   PORTALS: paired gates north-west <-> south-east and north-east <-> south-west (corner rotations).

const TOWER_Y := 6.0
const TUNNEL_Y := -3.2


func _init() -> void:
	family = "foundry"
	id = "vector_foundry"
	display_name = "VECTOR FOUNDRY"
	mechanic = "LAUNCH PADS + PORTALS"
	blurb = "Looping kinetic facility around a reactor, with a watchtower and a service tunnel."
	kill_y = -14.0


func _build_layout() -> void:
	var floor_m := Style.surface("concrete", Color("A39079"))
	var terracotta := Style.surface("plaster", Color("B5643C"))
	var cobalt := Style.surface("plaster", Color("34436E"))
	var steel := Style.surface("metal", Color("4A505A"))
	var ivory := Style.surface("concrete", Color("D8CDB5"))
	var roof_m := Style.surface("metal", Color("3A3F48"))
	var orange_e := Style.surface("ceramic", Color("E2683A"), Color("E2683A"), 1.6)
	var hazard := Style.surface("ceramic", Color("D99A2B"))
	light_env(Vector3(-0.2, -0.85, -0.45), Color("FFE2C4"), Color("B8A89C"), Color("E9D9C6"), Color("4A3A33"), Color("D7C4B2"), 0.0025)
	extent = Vector2(90, 52)

	var west := [Vector2(0, -48), Vector2(-20, -48), Vector2(-30, -42), Vector2(-44, -47), Vector2(-58, -41), Vector2(-70, -31),
		Vector2(-84, -23), Vector2(-88, -8), Vector2(-88, 8), Vector2(-84, 23), Vector2(-72, 33), Vector2(-58, 43), Vector2(-42, 47),
		Vector2(-28, 41), Vector2(-16, 47), Vector2(0, 47)]
	var outline := PackedVector2Array()
	for p in west:
		outline.append(p)
	for i in range(west.size() - 2, 0, -1):
		outline.append(Vector2(-west[i].x, west[i].y))
	# deck is thin so the service tunnel fits underneath; holes only where the ramps descend
	var ramp_w := MapKit.rect(-39, 34, 8, 6)
	var ramp_e := MapKit.rect(39, 34, 8, 6)
	MapKit.floor_with_holes(self, outline, [ramp_w, ramp_e], 0.0, 0.5, floor_m)
	MapKit.slab(self, MapKit.rect(0, 34, 87, 7), TUNNEL_Y, 1.0, steel)
	MapKit.walls(self, [Vector2(-43.5, 30.5), Vector2(43.5, 30.5)], 2.7, 0.5, cobalt, false, [], TUNNEL_Y)
	MapKit.walls(self, [Vector2(-43.5, 37.5), Vector2(43.5, 37.5)], 2.7, 0.5, cobalt, false, [], TUNNEL_Y)
	MapKit.wall(self, Vector2(-43.5, 30.5), Vector2(-43.5, 37.5), 3.2, 0.5, cobalt, TUNNEL_Y)
	MapKit.wall(self, Vector2(43.5, 30.5), Vector2(43.5, 37.5), 3.2, 0.5, cobalt, TUNNEL_Y)
	for sx in [-1.0, 1.0]:
		MapKit.stairs(self, Vector3(sx * 43.0, 0, 34.0), Vector3(sx * 35.0, TUNNEL_Y, 34.0), 5.0, floor_m, steel)
		for x in [12.0, 26.0]:
			var lamp := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(1.6, 0.08, 0.3)
			lamp.mesh = lm
			lamp.material_override = orange_e
			lamp.position = Vector3(sx * x, -0.6, 34.0)
			features.add_child(lamp)
		box(Vector3(sx * 22.0, TUNNEL_Y + 0.6, 33.0), Vector3(1.2, 1.2, 2.4), terracotta)
	var loop: Array = []
	for p in outline:
		loop.append(p)
	MapKit.walls(self, loop, 8.0, 1.2, terracotta, true)

	# ---------------------------------------------------------------- reactor hall and ring loop
	var hall := MapKit.ngon(0, 0, 17.0, 16, PI / 16.0)
	var hall_pts: Array = []
	for p in hall:
		hall_pts.append(p)
	# openings W, E, N, S (sides centred on the axes)
	MapKit.walls(self, hall_pts, 11.0, 1.0, cobalt, true, [3, 7, 11, 15])
	MapKit.roof(self, MapKit.ngon(0, 0, 17.6, 16, PI / 16.0), 11.0, roof_m)
	cylinder(Vector3(0, 4.5, 0), 2.2, 9.0, steel, true)
	for k in 3:
		var r := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 3.4 + k * 1.2
		tm.outer_radius = 3.8 + k * 1.2
		tm.rings = 48
		r.mesh = tm
		r.material_override = orange_e if k == 1 else steel
		r.rotation_degrees = Vector3(18.0 * (k - 1), k * 40.0, 10.0 * k)
		var sp := MapDecor.Spinner.new()
		sp.speed = 0.2 + k * 0.1
		sp.position = Vector3(0, 6.0 + k * 1.2, 0)
		sp.add_child(r)
		features.add_child(sp)
	for k in 4:
		var a := PI * 0.5 * float(k) + PI * 0.25
		box(Vector3(cos(a) * 9.0, 0.7, sin(a) * 9.0), Vector3(3.0, 1.4, 1.4), terracotta).rotation.y = -a
	var ring := MapKit.ngon(0, 0, 27.0, 16, PI / 16.0)
	var ring_pts: Array = []
	for p in ring:
		ring_pts.append(p)
	# outer ring wall: open on the axes and the diagonals => 8 entries into the loop
	MapKit.walls(self, ring_pts, 5.0, 1.0, terracotta, true, [1, 3, 5, 7, 9, 11, 13, 15])
	for k in 8:
		var a2 := TAU * float(k) / 8.0 + PI / 8.0
		box(Vector3(cos(a2) * 22.0, 0.75, sin(a2) * 22.0), Vector3(1.4, 1.5, 3.0), steel).rotation.y = -a2

	# ---------------------------------------------------------------- watchtower (north centre)
	MapKit.slab(self, MapKit.ngon(0, -38.0, 4.5, 8, PI / 8.0), TOWER_Y, 0.6, steel)
	for k in 4:
		var a3 := PI * 0.5 * float(k) + PI * 0.25
		MapDecor.solid_column(self, Vector3(cos(a3) * 3.6, 0, -38.0 + sin(a3) * 3.6), TOWER_Y - 0.6, 0.4, steel)
	# parapet with gaps where the walkways and ladders arrive
	var par := MapKit.ngon(0, -38.0, 4.4, 8, PI / 8.0)
	var par_pts: Array = []
	for p in par:
		par_pts.append(p)
	MapKit.walls(self, par_pts, 1.1, 0.3, hazard, true, [3, 7], TOWER_Y)
	var mast := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.15
	mm.bottom_radius = 0.25
	mm.height = 6.0
	mast.mesh = mm
	mast.material_override = steel
	mast.position = Vector3(0, TOWER_Y + 3.0, -38.0)
	features.add_child(mast)
	box(Vector3(0, TOWER_Y + 6.2, -38.0), Vector3(1.0, 0.6, 1.0), orange_e, "", false)

	# ---------------------------------------------------------------- mirrored halves
	for sx in [-1.0, 1.0]:
		_half(sx, floor_m, terracotta, cobalt, steel, ivory, roof_m, hazard)

	# ---------------------------------------------------------------- objectives and spawns
	hot_return_layout(Vector3(-56, 0, 0), Vector3(56, 0, 0), Vector3(-60, 0, 28), Vector3(60, 0, 28), Vector3(-20, TUNNEL_Y, 34), Vector3(20, TUNNEL_Y, 34), 9.0, 1.6)
	core_spawn = Vector3(-56, 0.6, 0)
	for i in 4:
		spawn_point("attack", Vector3(-82, 0.5, -6 + i * 4), -90)
		spawn_point("defend", Vector3(82, 0.5, -6 + i * 4), 90)
	for p in [Vector3(-40, 0.5, -30), Vector3(40, 0.5, -30), Vector3(0, TOWER_Y + 0.5, -38), Vector3(-22, 0.5, 0), Vector3(22, 0.5, 0), Vector3(0, TUNNEL_Y + 0.5, 34), Vector3(-30, 0.5, 26), Vector3(30, 0.5, 26)]:
		ffa_spawn(p, 0)
	shard_points = [Vector3(0, 0.5, 12), Vector3(0, TOWER_Y + 0.5, -38), Vector3(-30, TUNNEL_Y + 0.5, 34), Vector3(30, TUNNEL_Y + 0.5, 34), Vector3(-40, 0.5, -36), Vector3(40, 0.5, -36), Vector3(0, 0.5, -22)]
	beacon_points = [Vector3(0, 0.5, 12), Vector3(0, TOWER_Y, -38), Vector3(0, TUNNEL_Y, 34), Vector3(-22, 0, 0)]
	add_gate_pair(Vector3(-62, 0, -26), -135, Vector3(62, 0, 28), 45, "I")
	add_gate_pair(Vector3(62, 0, -26), 135, Vector3(-62, 0, 28), -45, "II")
	_scenery(steel, terracotta, cobalt, orange_e)
	MapDecor.dress_boxes(self)


func _half(sx: float, floor_m: Material, terracotta: Material, cobalt: Material, steel: Material, ivory: Material, roof_m: Material, hazard: Material) -> void:
	# assembly chamber holding the vault
	MapKit.room(self, sx * 60.0, 0.0, 18.0, 20.0, 8.0, cobalt, {"w" if sx < 0 else "e": [[0.0, 5.0]], "e" if sx < 0 else "w": [[0.0, 6.0]], "n": [[0.0, 5.0]], "s": [[0.0, 5.0]]}, roof_m)
	box(Vector3(sx * 64.0, 0.7, -5.0), Vector3(2.6, 1.4, 1.4), terracotta)
	box(Vector3(sx * 55.0, 1.2, 6.0), Vector3(1.4, 2.4, 3.0), steel)
	# approach lane between chamber and ring: offset machinery blocks
	box(Vector3(sx * 42.0, 1.3, -6.0), Vector3(4.0, 2.6, 2.6), steel)
	box(Vector3(sx * 36.0, 0.7, 7.0), Vector3(2.6, 1.4, 1.4), terracotta)
	add_temporal_prop(Vector3(sx * 46.0, 0, 3.0), Vector3(2.6, 1.6, 0.5), 90, Palette.TERRACOTTA)
	# north yard: walkway from its launch-pad landing platform to the watchtower (narrow, elevated)
	MapKit.slab(self, MapKit.rect(sx * 38.0, -34.0, 6.0, 6.0), TOWER_Y, 0.6, steel)
	var walk := PackedVector2Array([Vector2(sx * 35.0, -35.2), Vector2(sx * 4.0, -39.2), Vector2(sx * 4.0, -36.8), Vector2(sx * 35.0, -32.8)])
	if sx > 0:
		walk = PackedVector2Array([walk[3], walk[2], walk[1], walk[0]])
	MapKit.slab(self, walk, TOWER_Y, 0.4, steel)
	MapKit.wall(self, Vector2(sx * 35.0, -35.4), Vector2(sx * 4.2, -39.4), 1.0, 0.2, hazard, TOWER_Y, false)
	for x in [14.0, 26.0]:
		MapDecor.solid_column(self, Vector3(sx * x, 0, -37.4 + (x - 4.0) / 31.0 * 3.4 * 0.0), TOWER_Y - 0.4, 0.3, steel)
	MapKit.ladder(self, Vector3(sx * 5.3, 0, -38.0), TOWER_Y, Vector3(sx, 0, 0), "W" if sx < 0 else "E")
	MapKit.ladder(self, Vector3(sx * 41.3, 0, -34.0), TOWER_Y, Vector3(sx, 0, 0), ("W" if sx < 0 else "E") + "2")
	# vector launch pad in the yard: lands on the walkway platform (readable arc, safe landing)
	add_sling(Vector3(sx * 46.0, 0, -18.0), Vector3(sx * 38.0, TOWER_Y, -34.0), 1.3, "W" if sx < 0 else "E")
	# second pad: from the ring loop's north-west entry up into the north yard high ground
	box(Vector3(sx * 52.0, 0.6, -30.0), Vector3(2.6, 1.2, 1.2), terracotta)
	box(Vector3(sx * 24.0, 0.7, -42.0), Vector3(3.0, 1.4, 1.4), steel)
	# south yard above the tunnel: cover
	box(Vector3(sx * 50.0, 1.3, 26.0), Vector3(4.0, 2.6, 2.6), steel)
	box(Vector3(sx * 22.0, 0.6, 42.0), Vector3(2.6, 1.2, 1.2), terracotta)
	box(Vector3(sx * 78.0, 0.8, 12.0), Vector3(1.2, 1.6, 3.0), terracotta)
	box(Vector3(sx * 78.0, 0.8, -12.0), Vector3(1.2, 1.6, 3.0), terracotta)


func _scenery(steel: Material, terracotta: Material, cobalt: Material, orange_e: Material) -> void:
	var ground := MeshInstance3D.new()
	var gp := PlaneMesh.new()
	gp.size = Vector2(440, 320)
	ground.mesh = gp
	ground.position = Vector3(0, -3.6, 0)
	ground.material_override = Style.surface("concrete", Color("6A5A50"))
	features.add_child(ground)
	for i in 8:
		var t := float(i) / 8.0 * TAU + 0.3
		var p := Vector3(cos(t) * 125.0, -3.6, sin(t) * 88.0)
		var cm := CylinderMesh.new()
		cm.top_radius = 3.5
		cm.bottom_radius = 5.5
		cm.height = 30.0 + (i % 3) * 10.0
		MapDecor._mesh(features, cm, p + Vector3(0, cm.height * 0.5, 0), terracotta if i % 2 == 0 else cobalt)
		MapDecor._mesh(features, MapDecor._boxm(Vector3(8.0, 1.0, 8.0)), p + Vector3(0, cm.height, 0), orange_e)
	for zs in [-1.0, 1.0]:
		MapDecor.strut(features, Vector3(-60, 13.0, zs * 50.0), Vector3(60, 13.0, zs * 50.0), 0.5, steel)
