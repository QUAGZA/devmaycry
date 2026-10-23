class_name TidelineHall
extends MapDef
## MAP B - TIDELINE EXCHANGE (final). Covered industrial exchange above the sea, mirror-symmetric
## about x = 0. Plan (west half; east is the mirror):
##   outer dock spawn (x -86..-74) -> roofed LOADING BAY with the vault (x -65..-47)
##   DIRECT : through the tall central CARGO HALL (60 x 40, roof at 14 m, trusses, offset cargo stacks)
##   UPPER  : north CATWALK at y 5 outside the hall, reached by LADDERS at its ends and stairs near the
##            middle; ZIPLINES drop from each catwalk end to the far north dock (fast, exposed)
##   LOWER  : sunken south LOADING CHANNEL (y -2.4) entered at both ends and from the hall's south door;
##            both Stability Fields sit in the channel (long, covered, safe-field route)

const CATWALK_Y := 5.0
const CHANNEL_Y := -2.4
const HALL_H := 14.0


func _init() -> void:
	family = "tideline"
	id = "tideline_exchange"
	display_name = "TIDELINE EXCHANGE"
	mechanic = "ZIPLINES + LADDERS"
	blurb = "Covered cargo exchange over the sea: catwalks, loading channels and cable crossings."
	kill_y = -14.0


func _build_layout() -> void:
	var deck := Style.surface("concrete", Color("8F8A80"))
	var indigo := Style.surface("plaster", Color("2E3A63"))
	var steel := Style.surface("metal", Color("4A505A"))
	var rust := Style.surface("rust", Color("6E5A4A"))
	var paint := Style.surface("ceramic", Color("C8622F"))
	var hazard := Style.surface("ceramic", Color("D99A2B"))
	var canvas := Style.surface("cloth", Color("3C4C86"))
	var brass := Style.surface("metal", Palette.BRASS)
	var roof_m := Style.surface("metal", Color("3A4150"))
	light_env(Vector3(0.35, -0.7, -0.5), Color("FFF4E4"), Color("6E8DB0"), Color("D2DCE0"), Color("4E5660"), Color("BFCBD2"), 0.003)
	extent = Vector2(90, 52)

	var west := [Vector2(0, -46), Vector2(-26, -46), Vector2(-34, -51), Vector2(-50, -51), Vector2(-58, -45), Vector2(-72, -45),
		Vector2(-84, -34), Vector2(-87, -14), Vector2(-81, -8), Vector2(-81, 8), Vector2(-87, 14), Vector2(-87, 30), Vector2(-75, 42),
		Vector2(-57, 42), Vector2(-49, 48), Vector2(-30, 48), Vector2(-22, 42), Vector2(0, 42)]
	var outline := PackedVector2Array()
	for p in west:
		outline.append(p)
	for i in range(west.size() - 2, 0, -1):
		outline.append(Vector2(-west[i].x, west[i].y))
	var channel := MapKit.rect(0, 28, 84, 8)
	MapKit.floor_with_holes(self, outline, [channel], 0.0, 3.0, deck)
	MapKit.slab(self, MapKit.rect(0, 28, 85, 9), CHANNEL_Y, 1.0, rust)
	# perimeter: low sea wall with railing height (open-sided docks), the sea is visible beyond
	var loop: Array = []
	for p in outline:
		loop.append(p)
	MapKit.walls(self, loop, 1.3, 0.6, indigo, true)
	MapKit.walls(self, loop, 0.12, 0.25, hazard, true, [], 1.3)

	for sx in [-1.0, 1.0]:
		_half(sx, deck, indigo, steel, rust, paint, hazard, canvas, roof_m)

	# ---------------------------------------------------------------- central cargo hall
	MapKit.room(self, 0, 0, 60, 40, HALL_H, indigo, {"w": [[-10.0, 5.0], [10.0, 5.0]], "e": [[-10.0, 5.0], [10.0, 5.0]], "s": [[0.0, 7.0]], "n": [[-20.0, 5.0], [20.0, 5.0]]}, roof_m)
	for x in range(-24, 25, 12):
		MapDecor.strut(features, Vector3(x, HALL_H - 0.6, -19.5), Vector3(x, HALL_H - 0.6, 19.5), 0.25, steel)
		MapDecor.strut(features, Vector3(x, HALL_H - 0.6, -19.5), Vector3(x, HALL_H - 3.2, 0), 0.12, steel)
		MapDecor.strut(features, Vector3(x, HALL_H - 0.6, 19.5), Vector3(x, HALL_H - 3.2, 0), 0.12, steel)
	for x in [-18.0, 0.0, 18.0]:
		MapDecor.solid_column(self, Vector3(x, 0, -10.0), HALL_H - 0.6, 0.5, steel)
		MapDecor.solid_column(self, Vector3(x, 0, 10.0), HALL_H - 0.6, 0.5, steel)
	# cargo stacks in offset groups: no straight lane through the hall
	for c in [[Vector3(-9, 0, -3), Vector3(5, 2.6, 2.6)], [Vector3(9, 0, 3), Vector3(5, 2.6, 2.6)], [Vector3(-2, 0, 13), Vector3(2.6, 2.6, 5)], [Vector3(2, 0, -13), Vector3(2.6, 2.6, 5)],
			[Vector3(-22, 0, 4), Vector3(2.6, 1.4, 2.6)], [Vector3(22, 0, -4), Vector3(2.6, 1.4, 2.6)], [Vector3(-14, 0, -15), Vector3(4, 4.2, 2.6)], [Vector3(14, 0, 15), Vector3(4, 4.2, 2.6)]]:
		var cp: Vector3 = c[0]
		var cs: Vector3 = c[1]
		box(cp + Vector3(0, cs.y * 0.5, 0), cs, canvas if cs.y > 2.0 else paint)
	add_temporal_prop(Vector3(0, 0, 4.5), Vector3(2.6, 1.6, 0.5), 0, Palette.INDIGO)
	# south door stairs into the channel
	MapKit.stairs(self, Vector3(0, 0, 24.0), Vector3(0, CHANNEL_Y, 31.5), 6.0, deck, steel)
	# north catwalk (upper route) with railings, posts and mid stairs
	MapKit.slab(self, MapKit.rect(0, -26.0, 98.0, 5.0), CATWALK_Y, 0.5, steel)
	MapKit.wall(self, Vector2(-49, -28.6), Vector2(49, -28.6), 1.0, 0.25, hazard, CATWALK_Y, false)
	for x in range(-44, 45, 11):
		MapDecor.solid_column(self, Vector3(x, 0, -23.8), CATWALK_Y - 0.5, 0.3, steel)
		MapDecor.solid_column(self, Vector3(x, 0, -28.2), CATWALK_Y - 0.5, 0.3, steel)

	# ---------------------------------------------------------------- objectives and spawns
	hot_return_layout(Vector3(-52, 0, 0), Vector3(52, 0, 0), Vector3(-72, 0, 12), Vector3(72, 0, 12), Vector3(-20, CHANNEL_Y, 28), Vector3(20, CHANNEL_Y, 28), 10.0)
	core_spawn = Vector3(-52, 0.6, 0)
	for i in 4:
		spawn_point("attack", Vector3(-80, 0.5, -6 + i * 4), -90)
		spawn_point("defend", Vector3(80, 0.5, -6 + i * 4), 90)
	for p in [Vector3(-40, 0.5, -36), Vector3(40, 0.5, -36), Vector3(-10, CATWALK_Y + 0.5, -26), Vector3(10, CATWALK_Y + 0.5, -26), Vector3(0, 0.5, 6), Vector3(0, CHANNEL_Y + 0.5, 28), Vector3(-36, 0.5, 36), Vector3(36, 0.5, 36)]:
		ffa_spawn(p, 0)
	shard_points = [Vector3(0, CATWALK_Y + 0.5, -26), Vector3(-30, CHANNEL_Y + 0.5, 28), Vector3(30, CHANNEL_Y + 0.5, 28), Vector3(0, 0.5, 0), Vector3(-40, 0.5, -38), Vector3(40, 0.5, -38), Vector3(0, 0.5, 38)]
	beacon_points = [Vector3(0, 0.5, -1), Vector3(0, CATWALK_Y, -26), Vector3(0, CHANNEL_Y, 28), Vector3(-40, 0, -38)]
	# ziplines: catwalk ends down to the far north dock (offset so the cables do not cross)
	add_zipline(Vector3(-46, CATWALK_Y, -26), Vector3(30, 0.0, -40), "EAST")
	add_zipline(Vector3(46, CATWALK_Y, -27), Vector3(-30, 0.0, -42), "WEST")
	_scenery(steel, rust, paint)
	MapDecor.dress_boxes(self)


func _half(sx: float, deck: Material, indigo: Material, steel: Material, rust: Material, paint: Material, hazard: Material, canvas: Material, roof_m: Material) -> void:
	# loading bay holding the vault: roofed, doors toward spawn, hall, north dock and south dock
	MapKit.room(self, sx * 56.0, 0.0, 18.0, 22.0, 7.0, indigo, {"w" if sx < 0 else "e": [[0.0, 5.0]], "e" if sx < 0 else "w": [[0.0, 6.0]], "n": [[0.0, 5.0]], "s": [[sx * -3.0, 5.0]]}, roof_m)
	box(Vector3(sx * 60.0, 0.7, -6.0), Vector3(2.6, 1.4, 2.6), paint)
	box(Vector3(sx * 51.0, 1.3, 6.0), Vector3(1.4, 2.6, 4.0), canvas)
	# yard between bay and hall: offset container + low barrier
	box(Vector3(sx * 40.0, 1.3, -8.0), Vector3(6.0, 2.6, 2.6), canvas)
	box(Vector3(sx * 38.0, 0.6, 9.0), Vector3(2.6, 1.2, 1.2), paint)
	add_temporal_prop(Vector3(sx * 42.0, 0, 3.0), Vector3(2.6, 1.6, 0.5), 90, Palette.INDIGO)
	# ladder at the catwalk end and stairs near the middle (bots and carriers use the stairs)
	MapKit.ladder(self, Vector3(sx * 49.6, 0, -26.0), CATWALK_Y, Vector3(sx, 0, 0), "W" if sx < 0 else "E")
	MapKit.stairs(self, Vector3(sx * 30.0, 0, -38.0), Vector3(sx * 30.0, CATWALK_Y, -28.6), 4.0, deck, steel)
	# north dock: cargo groups and bollards
	box(Vector3(sx * 52.0, 1.3, -36.0), Vector3(6.0, 2.6, 2.6), canvas)
	box(Vector3(sx * 16.0, 0.6, -38.0), Vector3(2.6, 1.2, 1.2), paint)
	box(Vector3(sx * 66.0, 0.6, -30.0), Vector3(1.2, 1.2, 3.0), paint)
	# channel: ramps at the ends, cover inside
	MapKit.stairs(self, Vector3(sx * 42.0, 0, 28.0), Vector3(sx * 34.0, CHANNEL_Y, 28.0), 5.0, deck, steel)
	box(Vector3(sx * 28.0, CHANNEL_Y + 0.6, 26.0), Vector3(2.6, 1.2, 1.2), paint)
	box(Vector3(sx * 12.0, CHANNEL_Y + 0.6, 29.5), Vector3(1.2, 1.2, 2.6), paint)
	# south dock above the channel: crates and the crane foot
	box(Vector3(sx * 30.0, 1.3, 38.0), Vector3(5.0, 2.6, 2.6), canvas)
	box(Vector3(sx * 52.0, 0.6, 36.0), Vector3(2.6, 1.2, 1.2), paint)
	box(Vector3(sx * 78.0, 0.8, 20.0), Vector3(1.2, 1.6, 3.0), paint)
	box(Vector3(sx * 76.0, 0.8, -16.0), Vector3(1.2, 1.6, 3.0), paint)


func _scenery(steel: Material, rust: Material, paint: Material) -> void:
	MapDecor.sea(self, -9.0, Vector2(520, 380))
	for zs in [-1.0, 1.0]:
		MapDecor.piles(features, Vector3(-70, -1.0, zs * 44.0), Vector3(70, -1.0, zs * 44.0), 12, 9.0, rust)
	MapDecor.crane(features, Vector3(0, 0, 40.0), 22.0, 26.0, -60.0, steel, paint)
	MapDecor.crane(features, Vector3(-125, -9.0, 75), 34.0, 40.0, -20.0, steel, paint)
	MapDecor.crane(features, Vector3(130, -9.0, -65), 30.0, 36.0, 160.0, steel, paint)
	var far := Style.surface("concrete", Color("6A6E74"))
	for i in 6:
		MapDecor._mesh(features, MapDecor._boxm(Vector3(26, 6 + i % 3 * 3.0, 14)), Vector3(-150 + i * 60, -6.0, 120 + (i % 2) * 15.0), far)
