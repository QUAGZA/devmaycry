class_name FPArms
extends Node3D
## First-person body: the same Quaternius character as the third-person rig, parented to the camera,
## with the Head bone collapsed so the eye sits where the head was. The Universal Animation Library
## two-handed aim pose places real hands and gloves in view; the active weapon rides the right hand
## but its orientation is locked to the camera so it always points where the player aims.

var model: Node3D
var skel: Skeleton3D
var anim: AnimationPlayer
var weapon_anchor: BoneAttachment3D
var weapon_root: Node3D
var ok := false
var _head_id := -1


class HideHead extends SkeletonModifier3D:
	## Collapses the head after the animation pose is applied, so the eye can sit inside it.
	var bone := -1

	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk != null and bone >= 0:
			sk.set_bone_pose_scale(bone, Vector3(0.001, 0.001, 0.001))


func build(sleeve: Color) -> void:
	model = Style.model(TacticalRig.CHAR_PATH)
	if model == null:
		return
	model.rotation.y = PI
	add_child(model)
	skel = model.find_child("Skeleton3D", true, false) as Skeleton3D
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		Style.restyle(mi, "cloth", sleeve, 0.15)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 2.0
	_head_id = skel.find_bone("Head")
	var hh := HideHead.new()
	hh.bone = _head_id
	skel.add_child(hh)
	# gloves and forearm guards, as on the third-person rig
	var glove := Style.surface("gear", Color("50473C"))
	var guard := Style.surface("gear", Color("33373A"))
	for side in ["l", "r"]:
		var h := BoneAttachment3D.new()
		h.bone_name = "hand_" + side
		skel.add_child(h)
		var g := MeshInstance3D.new()
		var gb := BoxMesh.new()
		gb.size = Vector3(0.09, 0.1, 0.05)
		g.mesh = gb
		g.position = Vector3(0, 0.04, 0)
		g.material_override = glove
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		h.add_child(g)
		var f := BoneAttachment3D.new()
		f.bone_name = "lowerarm_" + side
		skel.add_child(f)
		var fg := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(0.1, 0.16, 0.1)
		fg.mesh = fb
		fg.position = Vector3(0, 0.16, 0)
		fg.material_override = guard
		fg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.add_child(fg)
	weapon_anchor = BoneAttachment3D.new()
	weapon_anchor.bone_name = "hand_r"
	skel.add_child(weapon_anchor)
	weapon_root = Node3D.new()
	weapon_anchor.add_child(weapon_root)
	var lib := TacticalRig.library()
	if lib != null:
		anim = AnimationPlayer.new()
		model.add_child(anim)
		anim.root_node = NodePath("..")
		anim.add_animation_library("", lib)
		anim.play("Pistol_Aim_Neutral" if lib.has_animation("Pistol_Aim_Neutral") else "Idle")
	ok = true


func play_reload() -> void:
	if anim != null and anim.has_animation("Pistol_Reload"):
		anim.play("Pistol_Reload", 0.1)
		anim.queue("Pistol_Aim_Neutral")


## A weapon switch cancels an unfinished reload animation (the reload itself is cancelled server-side).
func cancel_reload() -> void:
	if anim != null and anim.current_animation == "Pistol_Reload" and anim.has_animation("Pistol_Aim_Neutral"):
		anim.play("Pistol_Aim_Neutral", 0.05)


func play_shoot() -> void:
	if anim != null and anim.has_animation("Pistol_Shoot") and anim.current_animation != "Pistol_Reload":
		anim.play("Pistol_Shoot", 0.03)
		anim.queue("Pistol_Aim_Neutral")


func _process(_delta: float) -> void:
	if not ok:
		return
	# lock the weapon's orientation to the camera while it follows the hand position
	var cam := get_viewport().get_camera_3d()
	if cam != null and weapon_root != null:
		weapon_root.global_basis = cam.global_basis
