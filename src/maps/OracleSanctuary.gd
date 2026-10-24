class_name OracleSanctuary
extends MapDef
## MAP A - ORACLE GARDENS (final street plan). The layout is authored as a street network with
## tools/mapproto/oracle.py and executed by PlanRunner from plans/oracle_plan.gd (mirror-symmetric about
## x = 0 so the side swap is fair). West half:
##   spawn court -> jogged alleys -> reliquary yard (home stabilizer) and the vault TEMPLE (roofed, doors N/S/E)
##   MID   : gate approach -> cistern plaza (well monument) -> narrow neck -> octagonal Oracle Court (plinth
##           ring, diagonal walls) - short, hard-cornered, the risky direct route
##   NORTH : raised garden TERRACES (y 3) joined by roofed S-bend arcades, carrying both Stability Fields; the
##           long safe route. Carriers use the stairs at the far ends only; everyone else can use the ladders.
##   SOUTH : alleys -> chapel interior -> lane -> sunken BASIN (y -1.6) -> flank; PHASE GATES link the gate
##           court and the reliquary yard (home-side rotation; gates refuse the Core).

const PLAN := preload("res://src/maps/plans/oracle_plan.gd")


func _init() -> void:
	family = "oracle"
	id = "oracle_gardens"
	display_name = "ORACLE GARDENS"
	mechanic = "PHASE GATES"
	blurb = "Ancient-future sanctuary: narrow streets, temples, garden terraces, a sunken basin and paired gates."
	kill_y = -12.0


func _materials() -> Dictionary:
	return {
		"wall_a": Style.surface("stone", Color("E4D8BE")),
		"wall_b": Style.surface("plaster", Color("D4B98F")),
		"wall_c": Style.surface("stone", Color("B9A688")),
		"floor": Style.surface("floor", Color("CFC1A2")),
		"floor_hi": Style.surface("stone", Color("D8CAAA")),
		"floor_lo": Style.surface("floor", Color("B4A486")),
		"roof": Style.surface("plaster", Color("8E7F6A")),
		"stairs": Style.surface("floor", Color("B4A486")),
		"stairs_step": Style.surface("stone", Color("E4D8BE")),
		"cover_stone": Style.surface("stone", Color("CDB894")),
		"cover_glaze": Style.surface("ceramic", Color("2F6B66")),
		"cover_dark": Style.surface("gear", Palette.INK),
		"column": Style.surface("stone", Color("E4D8BE")),
	}


func _build_layout() -> void:
	light_env(Vector3(-0.5, -0.62, 0.42), Color("FFE2BE"), Color("6F95C2"), Color("EAD9B8"), Color("6E685C"), Color("DCCFB4"), 0.0018)
	var stats := PlanRunner.run(self, PLAN.OPS, PLAN.LAYOUT, PLAN.EXTENT, _materials())
	Game.log_ev("Map", "plan_built", {"map": id, "stats": stats})
	_backdrop()
	MapDecor.dress_boxes(self)


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
		var p := Vector3(cos(t) * rng.randf_range(84.0, 98.0), -2.0, sin(t) * rng.randf_range(54.0, 66.0))
		var pick: String = ["cliff_large_stone.glb", "cliff_block_stone.glb", "cliff_corner_stone.glb", "cliff_half_stone.glb"][i % 4]
		MapDecor.place(features, MapDecor.NATURE + pick, p, rng.randf_range(10.0, 24.0), rad_to_deg(-t) + 90.0, "cliff", Color(0.62, 0.57, 0.5))
		if i % 2 == 0:
			MapDecor.place(features, MapDecor.NATURE + ["tree_oak.glb", "tree_default.glb", "tree_cone.glb"][i % 3], p * 0.9, rng.randf_range(8.0, 13.0), rng.randf() * 360.0, "foliage", Color(0.5, 0.66, 0.46))
