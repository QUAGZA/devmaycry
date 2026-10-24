class_name TidelineHall
extends MapDef
## MAP B - TIDELINE EXCHANGE (final street plan). Vertical dockyard over the sea, authored with
## tools/mapproto/tideline.py and executed by PlanRunner from plans/tideline_plan.gd (mirror-symmetric about
## x = 0). West half:
##   spawn dock -> jogged exits -> home berth (stabilizer) / quay corner; roofed vault BAY with a mezzanine (y 4)
##   MID    : yard street -> the 14 m EXCHANGE HALL (galleries at y 5, two crossing cables, stacks) -> yard street
##   NORTH  : quay under a GANTRY (y 5) with ladders and a cable; a warehouse passage links quay and yard
##   SOUTH  : lanes -> the sunken LOADING CHANNEL (y -2.4) with weirs (S-bend gaps) holding both Stability Fields
##   Ladders and cables are for everyone but the Core carrier (stairs and ramps only), so carrier routes stay
##   at the measured length.

const PLAN := preload("res://src/maps/plans/tideline_plan.gd")
const CHANNEL_Y := -2.4
const TY := 5.0


func _init() -> void:
	family = "tideline"
	id = "tideline_exchange"
	display_name = "TIDELINE EXCHANGE"
	mechanic = "ZIPLINES + LADDERS"
	blurb = "Dockyard over the sea: a 14 m exchange hall with galleries and cables, a gantry quay and a sunken loading channel."
	kill_y = -14.0


func _materials() -> Dictionary:
	return {
		"wall_a": Style.surface("concrete", Color("9A958B")),
		"wall_b": Style.surface("plaster", Color("3B4A78")),
		"wall_c": Style.surface("rust", Color("7A5B49")),
		"floor": Style.surface("concrete", Color("8F8A80")),
		"floor_hi": Style.surface("concrete", Color("8F8A80")),
		"floor_lo": Style.surface("rust", Color("6E5A4A")),
		"roof": Style.surface("metal", Color("3A4150")),
		"stairs": Style.surface("concrete", Color("8F8A80")),
		"stairs_step": Style.surface("metal", Color("4A505A")),
		"steel": Style.surface("metal", Color("4A505A")),
		"column": Style.surface("metal", Color("4A505A")),
		"rail": Style.surface("metal", Color("3B4A78")),
		"cover_crate": Style.surface("rust", Color("C8622F")),
		"cover_crate_b": Style.surface("rust", Color("3C4C86")),
		"cover_stone": Style.surface("concrete", Color("9A958B")),
		"cover_glaze": Style.surface("ceramic", Color("D99A2B")),
		"cover_dark": Style.surface("metal", Color("2A2F38")),
	}


func _build_layout() -> void:
	light_env(Vector3(0.35, -0.7, -0.5), Color("FFF4E4"), Color("6E8DB0"), Color("D2DCE0"), Color("4E5660"), Color("BFCBD2"), 0.003)
	var stats := PlanRunner.run(self, PLAN.OPS, PLAN.LAYOUT, PLAN.EXTENT, _materials())
	Game.log_ev("Map", "plan_built", {"map": id, "stats": stats})
	_hall_trusses()
	_scenery()
	MapDecor.dress_boxes(self)


## Roof trusses and tie rods inside the exchange hall (visual only).
func _hall_trusses() -> void:
	var steel := Style.surface("metal", Color("4A505A"))
	for x in range(-12, 13, 6):
		MapDecor.strut(features, Vector3(x, 13.3, -16.4), Vector3(x, 13.3, 16.4), 0.22, steel)
		MapDecor.strut(features, Vector3(x, 13.3, -16.4), Vector3(x, 10.6, 0), 0.1, steel)
		MapDecor.strut(features, Vector3(x, 13.3, 16.4), Vector3(x, 10.6, 0), 0.1, steel)
	MapDecor.strut(features, Vector3(-13.4, 13.0, 0), Vector3(13.4, 13.0, 0), 0.2, steel)


func _scenery() -> void:
	var rust := Style.surface("rust", Color("6E5A4A"))
	var steel := Style.surface("metal", Color("4A505A"))
	var paint := Style.surface("ceramic", Color("C8622F"))
	MapDecor.sea(self, -9.0, Vector2(520, 380))
	# the north and west rails look out over the water: quay wall below the deck edge, piles under the pier
	var wall_m := Style.surface("concrete", Color("5E636A"))
	MapDecor._mesh(features, MapDecor._boxm(Vector3(130, 9.0, 1.2)), Vector3(0, -4.5, -39.6), wall_m)
	MapDecor._mesh(features, MapDecor._boxm(Vector3(1.2, 9.0, 50)), Vector3(-70.6, -4.5, 0), wall_m)
	MapDecor._mesh(features, MapDecor._boxm(Vector3(1.2, 9.0, 50)), Vector3(70.6, -4.5, 0), wall_m)
	MapDecor.piles(features, Vector3(-60, -1.0, -42.0), Vector3(60, -1.0, -42.0), 14, 9.0, rust)
	MapDecor.piles(features, Vector3(-73, -1.0, -24.0), Vector3(-73, -1.0, 24.0), 8, 9.0, rust)
	MapDecor.piles(features, Vector3(73, -1.0, -24.0), Vector3(73, -1.0, 24.0), 8, 9.0, rust)
	MapDecor.crane(features, Vector3(-30, -9.0, -47), 30.0, 30.0, 90.0, steel, paint)
	MapDecor.crane(features, Vector3(34, -9.0, -49), 26.0, 28.0, 90.0, steel, paint)
	MapDecor.crane(features, Vector3(-125, -9.0, 75), 34.0, 40.0, -20.0, steel, paint)
	MapDecor.crane(features, Vector3(130, -9.0, -65), 30.0, 36.0, 160.0, steel, paint)
	var far := Style.surface("concrete", Color("6A6E74"))
	for i in 6:
		MapDecor._mesh(features, MapDecor._boxm(Vector3(26, 6 + i % 3 * 3.0, 14)), Vector3(-150 + i * 60, -6.0, 120 + (i % 2) * 15.0), far)
