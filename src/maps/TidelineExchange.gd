class_name TidelineExchange
extends MapDef
## MAP 2 - TIDELINE EXCHANGE. A salt-worn aerial port: pale stone decks, weathered brass, indigo
## canvas, a high route of suspended platforms, a low route of water channels, and ZIPLINES.


func _init() -> void:
	family = "tideline"
	id = "tideline_exchange"
	display_name = "TIDELINE EXCHANGE"
	mechanic = "ZIPLINES"
	blurb = "Suspended maritime archive with a high route, a low route and cable crossings."
	kill_y = -14.0


func _build_layout() -> void:
	var stone := mat(Color("C4BCAB"), 0.95)
	var pale := mat(Color("DED6C4"), 0.85)
	var brass := mat(Palette.BRASS, 0.35, 0.8)
	var indigo := mat(Palette.INDIGO, 0.9)
	var canvas := mat(Color("3C4C86"), 0.95)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("2F5A78")
	water.roughness = 0.05
	water.metallic = 0.45
	water.rim_enabled = true
	var ink := mat(Palette.INK, 0.6, 0.3)
	var vermilion_glow := mat(Palette.VERMILION, 0.5, 0.0, Palette.VERMILION, 2.5)
	var cobalt_glow := mat(Palette.COBALT, 0.5, 0.0, Palette.COBALT, 2.0)
	light_env(Vector3(0.35, -0.7, -0.5), Color("FFF4E4"), Color("8FA9C4"), Color("DCE3E6"), Color("4E5660"), Color("C9D3D8"), 0.0022)

	# Main deck 120 x 90 with water channels carved as decals
	box(Vector3(0, -0.5, 0), Vector3(150, 1, 90), Style.surface("concrete", Color("8F8A80")), "Deck")
	for z in [-45.5, 45.5]:
		box(Vector3(0, 3.0, z), Vector3(152, 6, 1), indigo, "", false)
	for x in [-75.5, 75.5]:
		box(Vector3(x, 3.0, 0), Vector3(1, 6, 92), indigo, "", false)
	for z in [-18.0, 0.0, 18.0]:
		decal(Vector3(0, 0.02, z), Vector2(140, 2.2), water)

	# Spawn quays
	for i in 4:
		spawn_point("attack", Vector3(-68, 1.0, -9 + i * 6), -90)
		spawn_point("defend", Vector3(68, 1.0, -9 + i * 6), 90)
	core_spawn = Vector3(-44, 0.6, 0)
	hot_return_layout(Vector3(-56, 0, 0), Vector3(56, 0, 0), Vector3(-66, 0, 0), Vector3(66, 0, 0), Vector3(-30, 3.0, 30), Vector3(26, 0, 30), 15.0)
	for sx in [-1.0, 1.0]:
		box(Vector3(sx * 60, 1.2, 0), Vector3(1.0, 2.4, 10), canvas)
		box(Vector3(sx * 60, 1.2, 16), Vector3(1.0, 2.4, 6), canvas)
		box(Vector3(sx * 60, 1.2, -16), Vector3(1.0, 2.4, 6), canvas)
		box(Vector3(sx * 50, 0.7, -6), Vector3(2.4, 1.4, 2.4), brass)
		box(Vector3(sx * 50, 0.7, 6), Vector3(2.4, 1.4, 2.4), brass)
		box(Vector3(sx * 54, 1.3, 12), Vector3(6, 2.6, 2.4), canvas)
		box(Vector3(sx * 54, 1.3, -12), Vector3(6, 2.6, 2.4), canvas)

	# HIGH ROUTE (north, y = 6): suspended platforms with ramps up at both ends
	var high_y := 6.0
	var plat_h := 0.6
	box(Vector3(-36, high_y - plat_h / 2, 30), Vector3(14, plat_h, 14), pale, "HighWest")
	box(Vector3(0, high_y - plat_h / 2, 32), Vector3(18, plat_h, 12), pale, "HighMid")
	box(Vector3(36, high_y - plat_h / 2, 30), Vector3(14, plat_h, 14), pale, "HighEast")
	# bridges between high platforms
	box(Vector3(-18, high_y - plat_h / 2, 31), Vector3(22, plat_h, 3), brass, "BridgeW")
	box(Vector3(18, high_y - plat_h / 2, 31), Vector3(22, plat_h, 3), brass, "BridgeE")
	# ramps up to the high route (long, gentle)
	slope(Vector3(-36, 0, 6.0), Vector3(-36, high_y + 0.05, 23.3), 5.0, 0.5, stone)
	slope(Vector3(36, 0, 6.0), Vector3(36, high_y + 0.05, 23.3), 5.0, 0.5, stone)
	# railings (cover) on the high platforms
	for x in [-36.0, 36.0]:
		box(Vector3(x, high_y + 0.6, 37.2), Vector3(14, 1.2, 0.4), indigo)
		box(Vector3(x + 6.0, high_y + 0.6, 23.0), Vector3(2.0, 1.2, 0.4), indigo)
	box(Vector3(0, high_y + 0.6, 38.2), Vector3(18, 1.2, 0.4), indigo)
	box(Vector3(0, high_y + 0.6, 26.2), Vector3(6, 1.2, 0.4), indigo)

	# CENTRAL EXCHANGE HALL: tower with a lift ramp and crates
	cylinder(Vector3(0, 1.5, 0), 9.0, 3.0, pale)
	cylinder(Vector3(0, 9.0, 0), 1.2, 12.0, ink, false)
	slope(Vector3(-17.5, 0, 0), Vector3(-8.0, 3.0, 0), 5.0, 0.4, stone)
	slope(Vector3(17.5, 0, 0), Vector3(8.0, 3.0, 0), 5.0, 0.4, stone)
	for a in 6:
		var ang := a * 60.0 + 30.0
		var dir := Vector3(cos(deg_to_rad(ang)), 0, sin(deg_to_rad(ang)))
		var crate := box(dir * 7.0 + Vector3(0, 3.6, 0), Vector3(1.8, 1.2, 1.8), canvas)
		crate.rotation_degrees.y = -ang

	# LOW ROUTE (south): freight containers and loading platforms
	for i in 5:
		var x := -40.0 + i * 20.0
		box(Vector3(x, 1.3, -30), Vector3(6, 2.6, 2.4), canvas)
		box(Vector3(x + 9, 0.7, -36), Vector3(2.4, 1.4, 2.4), brass)
		box(Vector3(x - 7, 0.7, -24), Vector3(2.4, 1.4, 2.4), brass)
	# mid-lane crates between quays and the hall
	for x in [-30.0, -22.0, 22.0, 30.0]:
		for z in [-8.0, 8.0]:
			box(Vector3(x, 0.75, z), Vector3(2.6, 1.5, 1.6), canvas)

	# Sites: A on the high east platform, B on the low south-east loading platform
	site_platform("A", Vector3(36, high_y, 30), vermilion_glow, 6.0)
	box(Vector3(38, 0.15, -24), Vector3(16, 0.3, 14), pale, "LowSitePlatform")
	site_platform("B", Vector3(38, 0.3, -24), cobalt_glow, 6.0)
	box(Vector3(31, 1.4, -17), Vector3(1.0, 2.8, 6), canvas)
	box(Vector3(45, 1.4, -31), Vector3(1.0, 2.8, 6), canvas)

	# Temporal destructibles: brittle crates and shutters
	var crate := Color("8E7D64")
	add_temporal_prop(Vector3(-30, 0, 2), Vector3(2.2, 1.5, 0.6), 0, crate)
	add_temporal_prop(Vector3(30, 0, -2), Vector3(2.2, 1.5, 0.6), 0, crate)
	add_temporal_prop(Vector3(0, 0, -16), Vector3(2.6, 1.6, 0.5), 90, Palette.INDIGO)
	add_temporal_prop(Vector3(-36, high_y, 26), Vector3(2.4, 1.4, 0.5), 0, crate)
	add_temporal_prop(Vector3(36, high_y, 26), Vector3(2.4, 1.4, 0.5), 0, crate)

	# ZIPLINES: north express along the high route, hall top down to site B, west low to hall top
	add_zipline(Vector3(-36, high_y, 34), Vector3(36, high_y, 34), "NORTH")
	add_zipline(Vector3(4, 3.0, -6), Vector3(34, 0.3, -24), "SOUTH")
	add_zipline(Vector3(-44, 0.0, -34), Vector3(-6, 3.0, -4), "WEST")

	# Signal lights and canvas sails (decor)
	for p in [Vector3(-36, high_y + 3, 30), Vector3(36, high_y + 3, 30), Vector3(0, 15.3, 0)]:
		box(p, Vector3(0.5, 0.5, 0.5), vermilion_glow, "", false)

	# FFA spawns, shards, beacons
	ffa_spawn(Vector3(-50, 1, 36), 45)
	ffa_spawn(Vector3(50, 1, -36), -135)
	ffa_spawn(Vector3(-50, 1, -36), -45)
	ffa_spawn(Vector3(50, 1, 36), 135)
	ffa_spawn(Vector3(0, high_y + 1, 32), 180)
	ffa_spawn(Vector3(0, 1, -40), 0)
	ffa_spawn(Vector3(-28, 1, 0), 90)
	ffa_spawn(Vector3(28, 1, 0), -90)
	shard_points = [Vector3(-36, high_y + 0.5, 30), Vector3(36, high_y + 0.5, 30), Vector3(0, 3.5, 0), Vector3(-40, 1, -36), Vector3(40, 1, -36), Vector3(0, high_y + 0.5, 32), Vector3(0, 1, -20)]
	beacon_points = [Vector3(0, 3.0, 0), Vector3(0, high_y, 32), Vector3(38, 0.3, -24), Vector3(-36, 0, -30)]
	_art_pass()


## Visual production pass: sea, piles, crane landmark, seawall bastions, catwalk rails and pipes.
## Collision is only added for the corner bastions, which sit outside every route, spawn and zipline.
func _art_pass() -> void:
	var steel := Style.surface("rust", Color("6E5A4A"))
	var paint := Style.surface("ceramic", Color("C8622F"))
	var brass_m := Style.surface("metal", Palette.BRASS)
	var seawall := Style.surface("concrete", Color("8E8A80"))
	var deco := features
	MapDecor.sea(self, -9.0, Vector2(520, 380))
	for zs in [-1.0, 1.0]:
		MapDecor.piles(deco, Vector3(-72, -1.0, zs * 46.5), Vector3(72, -1.0, zs * 46.5), 13, 10.0, steel)
	for xs in [-1.0, 1.0]:
		MapDecor.piles(deco, Vector3(xs * 76.5, -1.0, -40), Vector3(xs * 76.5, -1.0, 40), 7, 10.0, steel)
	# crane rising through the exchange tower: the landmark visible from every deck
	MapDecor.crane(deco, Vector3(0, 3.0, 0), 20.0, 30.0, 35.0, steel, paint)
	# broken seawall bastions across the four corners
	for c in [[Vector3(75, 0, 45), 59.0], [Vector3(75, 0, -45), -59.0], [Vector3(-75, 0, 45), -59.0], [Vector3(-75, 0, -45), 59.0]]:
		var cp: Vector3 = c[0]
		MapDecor.bastion(self, cp, c[1], 34.0, 14.0, 7.0, seawall)
	# distant cranes and a second dock on the horizon
	MapDecor.crane(deco, Vector3(-120, -9.0, 70), 34.0, 40.0, -20.0, steel, paint)
	MapDecor.crane(deco, Vector3(130, -9.0, -60), 30.0, 36.0, 160.0, steel, paint)
	for i in 6:
		MapDecor._mesh(deco, MapDecor._boxm(Vector3(26, 6 + i % 3 * 3.0, 14)), Vector3(-150 + i * 60, -6.0, 120 + (i % 2) * 15.0), seawall)
	# catwalk rails along the high route edges and pipes along the inner walls
	for x in [-36.0, 0.0, 36.0]:
		MapDecor.strut(deco, Vector3(x - 7.0, 7.1, 24.6), Vector3(x + 7.0, 7.1, 24.6), 0.04, brass_m)
	for zs in [-1.0, 1.0]:
		MapDecor.strut(deco, Vector3(-70, 4.6, zs * 44.6), Vector3(70, 4.6, zs * 44.6), 0.22, steel)
		MapDecor.strut(deco, Vector3(-70, 5.2, zs * 44.6), Vector3(70, 5.2, zs * 44.6), 0.14, paint)
	# zipline anchor masts: lattice towers with hazard bands at both ends of every cable
	var hazard := Style.surface("ceramic", Color("D99A2B"))
	for z in [[Vector3(-36, 6.0, 34), Vector3(36, 6.0, 34)], [Vector3(4, 3.0, -6), Vector3(34, 0.3, -24)], [Vector3(-44, 0.0, -34), Vector3(-6, 3.0, -4)]]:
		for end in z:
			var e: Vector3 = end
			var other: Vector3 = z[1] if end == z[0] else z[0]
			var back := (e - other)
			back.y = 0.0
			back = back.normalized() * 1.4
			var base := e + back
			for o in [Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5), Vector3(0.5, 0, -0.5), Vector3(-0.5, 0, -0.5)]:
				MapDecor.strut(deco, base + o, base + o * 0.4 + Vector3(0, 5.2, 0), 0.07, steel)
			MapDecor._mesh(deco, MapDecor._boxm(Vector3(1.3, 0.25, 1.3)), base + Vector3(0, 1.2, 0), hazard)
			MapDecor._mesh(deco, MapDecor._boxm(Vector3(0.9, 0.5, 0.9)), base + Vector3(0, 5.3, 0), paint)
	MapDecor.dress_boxes(self)


func site_platform(site_id: String, center: Vector3, glow: Material, radius: float) -> void:
	ring(center + Vector3(0, 0.36, 0), radius - 0.2, 0.3, glow)
	site(site_id, center, radius)
