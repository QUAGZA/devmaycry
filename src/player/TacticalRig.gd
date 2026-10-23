class_name TacticalRig
extends Node3D
## Third-person player figure: Quaternius Universal Base Character (CC0, UE-mannequin skeleton) driven by
## the Quaternius Universal Animation Library (CC0) through an AnimationTree, dressed with original
## tactical gear (helmet + visor, plate carrier, pouches, shoulder and knee pads, backpack with antenna)
## attached to bones, team accents on matching panels for both teams, and the active weapon in the
## right hand. Same public API as the older HumanoidRig so Player can swap between them.

const CHAR_PATH := "res://assets/models/characters/Superhero_Male_FullBody.gltf"
const ANIM_PATH := "res://assets/models/anim/UAL1_Standard.glb"
const LOOPED := ["Idle", "Walk", "Jog_Fwd", "Sprint", "Crouch_Idle", "Crouch_Fwd", "Pistol_Idle", "Pistol_Aim_Neutral", "Pistol_Aim_Up", "Pistol_Aim_Down"]
const UPPER_BONES := ["spine_02", "spine_03", "neck_01", "Head", "clavicle_l", "upperarm_l", "lowerarm_l", "hand_l", "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"]

static var _lib: AnimationLibrary = null

var team_color := Color.WHITE
var glyph := "▲"
var model: Node3D
var skel: Skeleton3D
var anim: AnimationPlayer
var tree: AnimationTree
var aim_mod: AimModifier
var hand_attach: BoneAttachment3D
var weapon_holder: Node3D
var weapon_id := ""
var _rewind_mat: ShaderMaterial
var _rewinding := false
var _meshes: Array = []
var _dead := false
var ok := false


class AimModifier extends SkeletonModifier3D:
	## Bends the spine and neck toward the replicated look pitch after the animation pose is applied.
	var pitch := 0.0
	var spine_ids: Array = []

	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk == null:
			return
		var share := pitch / maxf(1.0, float(spine_ids.size()))
		for id in spine_ids:
			var q: Quaternion = sk.get_bone_pose_rotation(id)
			sk.set_bone_pose_rotation(id, q * Quaternion(Vector3(1, 0, 0), share))


static func library() -> AnimationLibrary:
	if _lib != null:
		return _lib
	if not ResourceLoader.exists(ANIM_PATH):
		return null
	var src: Node = (load(ANIM_PATH) as PackedScene).instantiate()
	var ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false)
	if ap != null:
		_lib = ap.get_animation_library("")
		for n in LOOPED:
			if _lib.has_animation(n):
				_lib.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	src.free()
	return _lib


func build(color: Color, glyph_text: String) -> void:
	team_color = color
	glyph = glyph_text
	model = Style.model(CHAR_PATH)
	if model == null:
		return
	model.rotation.y = PI  # glTF characters face +Z; players face -Z
	add_child(model)
	skel = model.find_child("Skeleton3D", true, false) as Skeleton3D
	# suit: dark cloth through the toon shader, keeping the original texture as albedo
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		Style.restyle(mi, "cloth", Color(0.85, 0.88, 0.95))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_meshes.append(mi)
	_dress()
	_setup_anim()
	_rewind_mat = ShaderMaterial.new()
	_rewind_mat.shader = load("res://src/shaders/rewind.gdshader")
	_rewind_mat.set_shader_parameter("tint", Color(Palette.MINT, 0.6))
	_rewind_mat.set_shader_parameter("edge", Color(Palette.VERMILION, 1.0))
	ok = true


func _attach(bone: String) -> BoneAttachment3D:
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skel.add_child(ba)
	return ba


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, rot_deg: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)
	_meshes.append(mi)
	return mi


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _dress() -> void:
	var gear := Style.surface("gear", Color("33373A"))
	var plate := Style.surface("gear", Color("4A4F4C"))
	var accent := Style.surface("ceramic", team_color)
	var brass := Style.surface("metal", Palette.BRASS)
	var visor := Style.surface("metal", Palette.INK, team_color, 0.6)
	# The attachment nodes follow bone transforms; offsets were set by eye against the T-pose bounds
	# (bone-local axes on the UE mannequin: +Y runs along the bone).
	var chest := _attach("spine_03")
	_part(chest, _box(Vector3(0.40, 0.34, 0.30)), Vector3(0, 0.06, 0.0), Vector3.ZERO, gear)
	_part(chest, _box(Vector3(0.30, 0.20, 0.03)), Vector3(0, 0.08, 0.16), Vector3.ZERO, accent)
	for i in 3:
		_part(chest, _box(Vector3(0.09, 0.11, 0.06)), Vector3(-0.11 + i * 0.11, -0.06, 0.17), Vector3.ZERO, plate)
	_part(chest, _box(Vector3(0.32, 0.38, 0.16)), Vector3(0, 0.04, -0.22), Vector3.ZERO, gear)
	_part(chest, _box(Vector3(0.12, 0.12, 0.012)), Vector3(0, 0.1, -0.305), Vector3.ZERO, accent)
	var ant := CylinderMesh.new()
	ant.top_radius = 0.008
	ant.bottom_radius = 0.012
	ant.height = 0.36
	_part(chest, ant, Vector3(0.11, 0.36, -0.24), Vector3.ZERO, brass)
	var head := _attach("Head")
	var hm := SphereMesh.new()
	hm.radius = 0.15
	hm.height = 0.22
	hm.is_hemisphere = true
	_part(head, hm, Vector3(0, 0.08, 0.0), Vector3.ZERO, gear)
	_part(head, _box(Vector3(0.05, 0.03, 0.26)), Vector3(0, 0.17, 0.0), Vector3.ZERO, accent)
	_part(head, _box(Vector3(0.24, 0.05, 0.03)), Vector3(0, 0.06, 0.14), Vector3.ZERO, visor)
	for side in ["l", "r"]:
		var sh := _attach("upperarm_" + side)
		_part(sh, _box(Vector3(0.13, 0.16, 0.15)), Vector3(0, 0.05, 0), Vector3.ZERO, accent)
		var kn := _attach("calf_" + side)
		_part(kn, _box(Vector3(0.12, 0.10, 0.08)), Vector3(0, 0.02, 0.07), Vector3.ZERO, plate)
		var th := _attach("thigh_" + side)
		_part(th, _box(Vector3(0.08, 0.14, 0.10)), Vector3(0.09 if side == "l" else -0.09, 0.18, 0), Vector3.ZERO, gear)
	hand_attach = _attach("hand_r")
	weapon_holder = Node3D.new()
	hand_attach.add_child(weapon_holder)


func _setup_anim() -> void:
	var lib := library()
	if lib == null:
		return
	anim = AnimationPlayer.new()
	model.add_child(anim)
	anim.root_node = NodePath("..")
	anim.add_animation_library("", lib)
	tree = AnimationTree.new()
	model.add_child(tree)
	tree.anim_player = tree.get_path_to(anim)
	tree.root_node = NodePath("..")
	var bt := AnimationNodeBlendTree.new()
	var loco := AnimationNodeBlendSpace1D.new()
	for pt in [["Idle", 0.0], ["Walk", 2.5], ["Jog_Fwd", 5.5], ["Sprint", 8.5]]:
		var a := AnimationNodeAnimation.new()
		a.animation = pt[0]
		loco.add_blend_point(a, pt[1])
	loco.min_space = 0.0
	loco.max_space = 9.0
	bt.add_node("loco", loco)
	var crouch := AnimationNodeBlendSpace1D.new()
	for pt in [["Crouch_Idle", 0.0], ["Crouch_Fwd", 3.0]]:
		var a := AnimationNodeAnimation.new()
		a.animation = pt[0]
		crouch.add_blend_point(a, pt[1])
	crouch.max_space = 4.0
	bt.add_node("crouch", crouch)
	var cb := AnimationNodeBlend2.new()
	bt.add_node("crouch_blend", cb)
	var jump := AnimationNodeAnimation.new()
	jump.animation = "Jump"
	bt.add_node("jump", jump)
	var ab := AnimationNodeBlend2.new()
	bt.add_node("air_blend", ab)
	var aim := AnimationNodeAnimation.new()
	aim.animation = "Pistol_Aim_Neutral"
	bt.add_node("aim", aim)
	var ub := AnimationNodeBlend2.new()
	ub.filter_enabled = true
	bt.add_node("upper", ub)
	var shoot := AnimationNodeAnimation.new()
	shoot.animation = "Pistol_Shoot"
	bt.add_node("shoot_anim", shoot)
	var os := AnimationNodeOneShot.new()
	os.filter_enabled = true
	os.fadein_time = 0.03
	os.fadeout_time = 0.12
	bt.add_node("shoot", os)
	var rl := AnimationNodeAnimation.new()
	rl.animation = "Pistol_Reload"
	bt.add_node("reload_anim", rl)
	var ros := AnimationNodeOneShot.new()
	ros.filter_enabled = true
	ros.fadein_time = 0.1
	ros.fadeout_time = 0.2
	bt.add_node("reload", ros)
	var death := AnimationNodeAnimation.new()
	death.animation = "Death01"
	bt.add_node("death_anim", death)
	var dos := AnimationNodeOneShot.new()
	dos.fadein_time = 0.1
	dos.fadeout_time = 0.0
	bt.add_node("death", dos)
	bt.connect_node("crouch_blend", 0, "loco")
	bt.connect_node("crouch_blend", 1, "crouch")
	bt.connect_node("air_blend", 0, "crouch_blend")
	bt.connect_node("air_blend", 1, "jump")
	bt.connect_node("upper", 0, "air_blend")
	bt.connect_node("upper", 1, "aim")
	bt.connect_node("shoot", 0, "upper")
	bt.connect_node("shoot", 1, "shoot_anim")
	bt.connect_node("reload", 0, "shoot")
	bt.connect_node("reload", 1, "reload_anim")
	bt.connect_node("death", 0, "reload")
	bt.connect_node("death", 1, "death_anim")
	bt.connect_node("output", 0, "death")
	for b in UPPER_BONES:
		var path := NodePath("Armature/Skeleton3D:" + b)
		ub.set_filter_path(path, true)
		os.set_filter_path(path, true)
		ros.set_filter_path(path, true)
	for side in ["l", "r"]:
		for f in ["index", "middle", "pinky", "ring", "thumb"]:
			for i in [1, 2, 3]:
				var fp := NodePath("Armature/Skeleton3D:%s_0%d_%s" % [f, i, side])
				ub.set_filter_path(fp, true)
				os.set_filter_path(fp, true)
				ros.set_filter_path(fp, true)
	tree.tree_root = bt
	tree.active = true
	tree.set("parameters/upper/blend_amount", 1.0)
	aim_mod = AimModifier.new()
	for b in ["spine_02", "spine_03", "neck_01"]:
		var id := skel.find_bone(b)
		if id >= 0:
			aim_mod.spine_ids.append(id)
	skel.add_child(aim_mod)


## Shows the given weapon in the right hand (world model shares the viewmodel art).
func set_weapon(id: String) -> void:
	if id == weapon_id or weapon_holder == null:
		return
	weapon_id = id
	for c in weapon_holder.get_children():
		c.queue_free()
	var w := WeaponModels.build(id)
	if w == null:
		return
	weapon_holder.add_child(w)
	# hand_r local: grip at the palm, barrel along the forearm direction, tuned against the aim pose
	w.position = Vector3(0.0, 0.1, 0.05)
	w.rotation_degrees = Vector3(0, -90, -90)
	w.scale = Vector3.ONE * 1.0


func fire() -> void:
	if tree != null:
		tree.set("parameters/shoot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func reload() -> void:
	if tree != null:
		tree.set("parameters/reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func die() -> void:
	if tree != null and not _dead:
		_dead = true
		tree.set("parameters/death/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func revive() -> void:
	_dead = false
	if tree != null:
		tree.set("parameters/death/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)


func set_rewinding(on: bool) -> void:
	if on == _rewinding:
		return
	_rewinding = on
	for mi: MeshInstance3D in _meshes:
		if is_instance_valid(mi):
			mi.material_overlay = _rewind_mat if on else null


## Called every frame by the owning Player with its replicated motion state.
func animate(delta: float, speed: float, on_floor: bool, crouching: bool, pitch: float, rewinding: bool) -> void:
	if not ok:
		return
	set_rewinding(rewinding)
	if tree == null:
		return
	var sp := clampf(speed, 0.0, 9.0)
	tree.set("parameters/loco/blend_position", sp)
	tree.set("parameters/crouch/blend_position", clampf(speed, 0.0, 4.0))
	var cb: float = tree.get("parameters/crouch_blend/blend_amount")
	tree.set("parameters/crouch_blend/blend_amount", move_toward(cb, 1.0 if crouching else 0.0, delta * 6.0))
	var ab: float = tree.get("parameters/air_blend/blend_amount")
	tree.set("parameters/air_blend/blend_amount", move_toward(ab, 0.0 if on_floor else 1.0, delta * 5.0))
	if aim_mod != null:
		aim_mod.pitch = lerpf(aim_mod.pitch, -pitch * 0.8, minf(1.0, delta * 12.0))
