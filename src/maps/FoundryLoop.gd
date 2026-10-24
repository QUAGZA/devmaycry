class_name FoundryLoop
extends MapDef
## MAP C - VECTOR FOUNDRY (final street plan). Ring-and-spoke foundry authored with tools/mapproto/foundry.py and
## executed by PlanRunner from plans/foundry_plan.gd (mirror-symmetric about x = 0). West half:
##   spawn yard -> jogged exits -> home berth (stabilizer) / north-west yard; roofed assembly BAY with the vault
##   MID    : west spoke -> RING STREET (walled, opens on the four axes) around the roofed REACTOR (doors face the
##            diagonals, so no street runs through the middle)
##   NORTH  : north street under a WALKWAY (y 6) that joins a landing deck to the generator-house TOWER; stairs for
##            carriers, a LAUNCH PAD and the tower LADDERS for everyone else
##   SOUTH  : roofed SERVICE TUNNEL (y -3.2) under the south block, entered by pit stairs at both ends, staggered
##            bulkheads, both Stability Fields inside (the long protected route)
##   GATES  : home-side rotation pairs (they refuse the Core, like the launch pads, ladders and cables)

const PLAN := preload("res://src/maps/plans/foundry_plan.gd")
const TOWER_Y := 6.0
const TUNNEL_Y := -3.2

const STYLE := {"seed": 31, "rows": [3.2, 6.4], "window": Vector2(0.8, 1.9), "pier_gap": 4.5, "lit": 0.28, "skip": 0.12,
	"hazard_band": "hazard", "hazard_chance": 0.3, "pipe": "pipe", "pipe_chance": 0.45, "pipe_y": 4.2}

func _init() -> void:
	family = "foundry"
	id = "vector_foundry"
	display_name = "VECTOR FOUNDRY"
	mechanic = "LAUNCH PADS + PORTALS"
	blurb = "Ring-and-spoke foundry: a roofed reactor, a walled ring street, a watchtower with walkways and a service tunnel."
	kill_y = -14.0


func _materials() -> Dictionary:
	return {
		"wall_a": Style.surface("plaster", Color("B5643C")),
		"wall_b": Style.surface("plaster", Color("3E4C7C")),
		"wall_c": Style.surface("concrete", Color("CBBFA6")),
		"floor": Style.surface("concrete", Color("A39079")),
		"floor_hi": Style.surface("concrete", Color("A39079")),
		"floor_lo": Style.surface("metal", Color("4A505A")),
		"roof": Style.surface("metal", Color("3A3F48")),
		"stairs": Style.surface("concrete", Color("A39079")),
		"stairs_step": Style.surface("metal", Color("4A505A")),
		"steel": Style.surface("metal", Color("4A505A")),
		"column": Style.surface("metal", Color("4A505A")),
		"hazard": Style.surface("ceramic", Color("D99A2B")),
		"rail": Style.surface("metal", Color("4A505A")),
		"cover_machine": Style.surface("plaster", Color("B5643C")),
		"cover_stone": Style.surface("concrete", Color("CBBFA6")),
		"cover_glaze": Style.surface("ceramic", Color("E2683A")),
		"cover_dark": Style.surface("metal", Color("2A2F38")),
	}


func _facade_materials() -> Dictionary:
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("FF9A4D")
	glow.emission_enabled = true
	glow.emission = Color("FF7A2E")
	glow.emission_energy_multiplier = 1.6
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("20262E")
	glass.roughness = 0.3
	glass.metallic = 0.25
	return {
		"plinth": Style.surface("metal", Color("2A2F38")),
		"trim": Style.surface("concrete", Color("E8D9C0")),
		"band": Style.surface("ceramic", Color("E2683A")),
		"hazard": Style.surface("ceramic", Color("D99A2B")),
		"pipe": Style.surface("metal", Color("5A5F68")),
		"glass": glass,
		"glass_lit": glow,
	}

func _build_layout() -> void:
	light_env(Vector3(-0.2, -0.85, -0.45), Color("FFE2C4"), Color("B8A89C"), Color("E9D9C6"), Color("4A3A33"), Color("D7C4B2"), 0.0025)
	var stats := PlanRunner.run(self, PLAN.OPS, PLAN.LAYOUT, PLAN.EXTENT, _materials())
	Game.log_ev("Map", "plan_built", {"map": id, "stats": stats})
	var fm := _materials().duplicate()
	fm.merge(_facade_materials())
	var fs := Facades.build(self, PLAN.OPS, PLAN.EXTENT, fm, STYLE)
	Game.log_ev("Map", "facades", {"map": id, "stats": fs})
	_reactor_machinery()
	_scenery()
	MapDecor.dress_boxes(self)


## Spinning rings and a glowing floor mark around the reactor core (visual only; the core itself is solid cover).
func _reactor_machinery() -> void:
	var steel := Style.surface("metal", Color("4A505A"))
	var orange_e := Style.surface("ceramic", Color("E2683A"), Color("E2683A"), 1.6)
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
	var mark := MeshInstance3D.new()
	var tm2 := TorusMesh.new()
	tm2.inner_radius = 4.6
	tm2.outer_radius = 5.0
	tm2.rings = 64
	mark.mesh = tm2
	mark.scale = Vector3(1, 0.05, 1)
	mark.position = Vector3(0, 0.04, 0)
	mark.material_override = orange_e
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	features.add_child(mark)
	# hazard band where the ring street meets each spoke
	var hz := Style.surface("ceramic", Color("D99A2B"))
	for k in 4:
		var a := PI * 0.5 * float(k)
		var m := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(5.0, 0.6)
		m.mesh = pm
		m.position = Vector3(cos(a) * 21.0, 0.03, sin(a) * 21.0)
		m.rotation.y = -a + PI * 0.5
		m.material_override = hz
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		features.add_child(m)


func _scenery() -> void:
	var steel := Style.surface("metal", Color("4A505A"))
	var terracotta := Style.surface("plaster", Color("B5643C"))
	var cobalt := Style.surface("plaster", Color("34436E"))
	var orange_e := Style.surface("ceramic", Color("E2683A"), Color("E2683A"), 1.6)
	var ground := MeshInstance3D.new()
	var gp := PlaneMesh.new()
	gp.size = Vector2(440, 320)
	ground.mesh = gp
	ground.position = Vector3(0, -3.6, 0)
	ground.material_override = Style.surface("concrete", Color("6A5A50"))
	features.add_child(ground)
	for i in 8:
		var t := float(i) / 8.0 * TAU + 0.3
		var p := Vector3(cos(t) * 96.0, -3.6, sin(t) * 64.0)
		var cm := CylinderMesh.new()
		cm.top_radius = 3.5
		cm.bottom_radius = 5.5
		cm.height = 30.0 + (i % 3) * 10.0
		MapDecor._mesh(features, cm, p + Vector3(0, cm.height * 0.5, 0), terracotta if i % 2 == 0 else cobalt)
		MapDecor._mesh(features, MapDecor._boxm(Vector3(8.0, 1.0, 8.0)), p + Vector3(0, cm.height, 0), orange_e)
	for zs in [-1.0, 1.0]:
		MapDecor.strut(features, Vector3(-60, 14.0, zs * 52.0), Vector3(60, 14.0, zs * 52.0), 0.5, steel)
