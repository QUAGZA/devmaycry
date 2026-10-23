class_name HumanoidRig
extends Node3D
## Original articulated tactical figure built from parts (no external assets, no DCC tool on this
## machine): helmet with visor strip, vest over torso, shoulder pads, arms holding the weapon, gloves,
## thighs, shins, boots, backpack with antenna. Procedural idle / walk / sprint / crouch / jump / aim /
## rewind poses. Team identity through accent panels, a back glyph and the helmet stripe, not colour alone.

var team_color := Color.WHITE
var glyph := "▲"
var parts: Dictionary = {}
var mats: Dictionary = {}
var phase := 0.0
var _rewind_mat: ShaderMaterial = null
var _rewinding := false
var pelvis: Node3D
var torso: Node3D
var arms: Node3D
var legs: Dictionary = {}


func _mat(color: Color, rough: float = 0.75, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


func _box(parent: Node3D, key: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	parts[key] = mi
	return mi


func build(color: Color, glyph_text: String) -> void:
	team_color = color
	glyph = glyph_text
	var gear := _mat(Color("2B2E2B"), 0.8)
	var cloth := _mat(Color("4A4D47"), 0.95)
	var accent := _mat(color, 0.55)
	var porcelain := _mat(Palette.PORCELAIN, 0.5)
	var brass := _mat(Palette.BRASS, 0.3, 0.8)
	var visor := _mat(Palette.INK, 0.2, 0.6)
	mats = {"gear": gear, "cloth": cloth, "accent": accent, "porcelain": porcelain, "brass": brass, "visor": visor}
	pelvis = Node3D.new()
	pelvis.name = "Pelvis"
	pelvis.position = Vector3(0, 0.95, 0)
	add_child(pelvis)
	_box(pelvis, "hips", Vector3(0.36, 0.18, 0.24), Vector3(0, 0, 0), cloth)
	torso = Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0, 0.1, 0)
	pelvis.add_child(torso)
	_box(torso, "torso", Vector3(0.40, 0.48, 0.24), Vector3(0, 0.26, 0), cloth)
	_box(torso, "vest", Vector3(0.44, 0.34, 0.30), Vector3(0, 0.24, 0), gear)
	_box(torso, "vest_panel", Vector3(0.20, 0.16, 0.02), Vector3(0, 0.30, -0.16), accent)
	_box(torso, "shoulder_l", Vector3(0.16, 0.12, 0.2), Vector3(-0.29, 0.46, 0), accent)
	_box(torso, "shoulder_r", Vector3(0.16, 0.12, 0.2), Vector3(0.29, 0.46, 0), accent)
	_box(torso, "backpack", Vector3(0.30, 0.34, 0.14), Vector3(0, 0.22, 0.20), gear)
	_box(torso, "back_glyph", Vector3(0.14, 0.14, 0.01), Vector3(0, 0.26, 0.275), accent)
	var antenna := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = 0.01
	am.bottom_radius = 0.015
	am.height = 0.4
	antenna.mesh = am
	antenna.position = Vector3(0.1, 0.55, 0.22)
	antenna.material_override = brass
	torso.add_child(antenna)
	parts["antenna"] = antenna
	# head and helmet
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.56, 0)
	torso.add_child(head)
	parts["head_node"] = head
	_box(head, "head", Vector3(0.22, 0.24, 0.22), Vector3(0, 0.12, 0), porcelain)
	_box(head, "helmet", Vector3(0.28, 0.16, 0.30), Vector3(0, 0.22, 0.01), gear)
	_box(head, "helmet_stripe", Vector3(0.06, 0.02, 0.30), Vector3(0, 0.305, 0.01), accent)
	_box(head, "visor", Vector3(0.24, 0.06, 0.02), Vector3(0, 0.13, -0.12), visor)
	# arms as one aiming group holding the weapon
	arms = Node3D.new()
	arms.name = "Arms"
	arms.position = Vector3(0, 0.42, 0)
	torso.add_child(arms)
	_box(arms, "upper_l", Vector3(0.10, 0.28, 0.10), Vector3(-0.27, -0.10, -0.06), cloth)
	_box(arms, "upper_r", Vector3(0.10, 0.28, 0.10), Vector3(0.27, -0.10, -0.06), cloth)
	_box(arms, "fore_l", Vector3(0.09, 0.09, 0.30), Vector3(-0.20, -0.18, -0.28), cloth)
	_box(arms, "fore_r", Vector3(0.09, 0.09, 0.30), Vector3(0.20, -0.14, -0.26), cloth)
	_box(arms, "glove_l", Vector3(0.09, 0.09, 0.09), Vector3(-0.12, -0.18, -0.44), porcelain)
	_box(arms, "glove_r", Vector3(0.09, 0.09, 0.09), Vector3(0.16, -0.14, -0.40), porcelain)
	_box(arms, "weapon", Vector3(0.07, 0.09, 0.56), Vector3(0.10, -0.12, -0.42), _mat(Palette.INK, 0.35, 0.5))
	_box(arms, "weapon_tip", Vector3(0.03, 0.03, 0.08), Vector3(0.10, -0.09, -0.72), brass)
	# legs
	for side in ["l", "r"]:
		var sx := -0.11 if side == "l" else 0.11
		var thigh := Node3D.new()
		thigh.position = Vector3(sx, -0.08, 0)
		pelvis.add_child(thigh)
		_box(thigh, "thigh_" + side, Vector3(0.15, 0.42, 0.16), Vector3(0, -0.2, 0), cloth)
		var shin := Node3D.new()
		shin.position = Vector3(0, -0.42, 0)
		thigh.add_child(shin)
		_box(shin, "shin_" + side, Vector3(0.13, 0.42, 0.14), Vector3(0, -0.21, 0), gear)
		_box(shin, "boot_" + side, Vector3(0.15, 0.10, 0.27), Vector3(0, -0.45, -0.04), gear)
		legs[side] = {"thigh": thigh, "shin": shin}
	_rewind_mat = ShaderMaterial.new()
	_rewind_mat.shader = load("res://src/shaders/rewind.gdshader")
	_rewind_mat.set_shader_parameter("tint", Color(Palette.MINT, 0.6))
	_rewind_mat.set_shader_parameter("edge", Color(Palette.VERMILION, 1.0))


func set_rewinding(on: bool) -> void:
	if on == _rewinding:
		return
	_rewinding = on
	for key in parts:
		var mi: MeshInstance3D = parts[key]
		if on:
			mi.set_meta("mat", mi.material_override)
			mi.material_override = _rewind_mat
		elif mi.has_meta("mat"):
			mi.material_override = mi.get_meta("mat")


## Called every frame by the owning Player with its replicated motion state.
func animate(delta: float, speed: float, on_floor: bool, crouching: bool, pitch: float, rewinding: bool) -> void:
	set_rewinding(rewinding)
	var moving := speed > 0.4
	var rate := clampf(speed / 6.0, 0.0, 1.6)
	if moving and on_floor:
		phase += delta * 7.5 * maxf(rate, 0.5)
	else:
		phase = lerpf(phase, round(phase / PI) * PI, 6.0 * delta)
	var swing := sin(phase) * 0.55 * (rate if moving else 0.0)
	if not on_floor:
		swing = 0.35
	for side in legs:
		var s := 1.0 if side == "l" else -1.0
		var thigh: Node3D = legs[side]["thigh"]
		var shin: Node3D = legs[side]["shin"]
		if not on_floor:
			thigh.rotation.x = -0.6
			shin.rotation.x = 1.1
		elif crouching:
			thigh.rotation.x = -0.9 + swing * 0.3 * s
			shin.rotation.x = 1.3
		else:
			thigh.rotation.x = swing * s
			shin.rotation.x = maxf(0.0, -swing * s) * 1.1
	var crouch_drop := 0.32 if crouching else 0.0
	pelvis.position.y = lerpf(pelvis.position.y, 0.95 - crouch_drop + (absf(sin(phase * 2.0)) * 0.03 if moving and on_floor else 0.0), 10.0 * delta)
	torso.rotation.x = lerpf(torso.rotation.x, 0.25 if crouching else (0.08 if moving else 0.0), 8.0 * delta)
	arms.rotation.x = lerpf(arms.rotation.x, pitch * 0.85, 12.0 * delta)
	var head: Node3D = parts["head_node"]
	head.rotation.x = lerpf(head.rotation.x, pitch * 0.5, 10.0 * delta)
