extends SceneTree
func _aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	var t := xf
	if n is Node3D: t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var a := t * (n as MeshInstance3D).mesh.get_aabb()
		acc[0] = a if acc[0] == null else (acc[0] as AABB).merge(a)
	for c in n.get_children(): _aabb(c, t, acc)
func _init() -> void:
	var ual: Node = (load("res://assets/models/anim/UAL1_Standard.glb") as PackedScene).instantiate()
	var ap: AnimationPlayer = ual.find_child("AnimationPlayer", true, false)
	print("UAL anims: ", ap.get_animation_list())
	var sk: Skeleton3D = ual.find_child("*", true, false) as Skeleton3D
	for c in ual.find_children("*", "Skeleton3D", true, false): print("UAL skel path: ", ual.get_path_to(c), " bones ", (c as Skeleton3D).get_bone_count())
	print("UAL tree: ", ual.get_child(0).name, " ap root ", ap.root_node, " sample track ", ap.get_animation(ap.get_animation_list()[0]).track_get_path(0))
	var ch: Node = (load("res://assets/models/characters/Superhero_Male_FullBody.gltf") as PackedScene).instantiate()
	for c in ch.find_children("*", "Skeleton3D", true, false): print("CHAR skel path: ", ch.get_path_to(c), " bones ", (c as Skeleton3D).get_bone_count())
	for c in ch.find_children("*", "MeshInstance3D", true, false): print("CHAR mesh: ", ch.get_path_to(c))
	var acc := [null]; _aabb(ch, Transform3D.IDENTITY, acc); print("CHAR aabb ", acc[0])
	for f in DirAccess.get_files_at("res://assets/models/weapons"):
		if f.ends_with(".glb"):
			var w: Node = (load("res://assets/models/weapons/" + f) as PackedScene).instantiate()
			var a2 := [null]; _aabb(w, Transform3D.IDENTITY, a2); print(f, " ", a2[0])
	quit()
