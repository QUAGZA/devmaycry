extends Node3D
## Material preview / style validation scene. Shows every PALIMPSEST material kind on a bevel-free box
## and a sphere, the imported human character driven by the animation library, the weapon lineup and
## the ink outline, under the same sun and environment family as Oracle Gardens. Saves a screenshot.
## Run: Godot --path . res://src/style/MaterialPreview.tscn -- --shot=build/shots/material_preview.png

var _t := 0.0
var _shot := ""
var _saved := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot = a.substr(7)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("FFE9CC")
	sun.shadow_enabled = true
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(-0.45, -0.8, -0.35), Vector3.UP)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("B9C9DA")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8A93A8")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85
	we.environment = env
	add_child(we)
	var cam := Camera3D.new()
	cam.fov = 50
	add_child(cam)
	cam.look_at_from_position(Vector3(1.0, 2.6, -7.5), Vector3(1.0, 1.0, 0.5), Vector3.UP)
	cam.current = true
	Style.add_outline(cam)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 20)
	floor_mi.mesh = pm
	floor_mi.material_override = Style.surface("floor", Color("D9CFB8"))
	add_child(floor_mi)
	var kinds := [["stone", Color("D8CBB0")], ["plaster", Color("E8E0CF")], ["ceramic", Palette.PORCELAIN], ["cliff", Color("8F8676")], ["concrete", Color("9AA0A6")], ["metal", Color("5A6068")], ["rust", Color("8A5A3C")], ["cloth", Color("3E4A63")], ["gear", Color("2B2E2B")]]
	for i in kinds.size():
		var x := -6.0 + i * 1.5
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.0, 1.0, 1.0)
		b.mesh = bm
		b.position = Vector3(x, 0.5, -1.2)
		b.rotation_degrees.y = 25
		b.material_override = Style.surface(kinds[i][0], kinds[i][1])
		add_child(b)
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.45
		sm.height = 0.9
		s.mesh = sm
		s.position = Vector3(x, 1.5, -1.2)
		s.material_override = b.material_override
		add_child(s)
		var l := Label3D.new()
		l.text = str(kinds[i][0]).to_upper()
		l.font_size = 36
		l.pixel_size = 0.004
		l.position = Vector3(x, 0.05, -0.4)
		l.rotation_degrees = Vector3(-90, 180, 0)
		l.position.z = -2.0
		l.modulate = Palette.INK
		add_child(l)
	# temporal energy: emissive mint and signal orange
	var e := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.35
	tm.outer_radius = 0.5
	e.mesh = tm
	e.position = Vector3(7.8, 1.0, -1.2)
	e.rotation_degrees.x = 90
	e.material_override = Style.surface("ceramic", Palette.MINT, Palette.MINT, 2.5)
	add_child(e)
	# characters and weapons
	var rig := TacticalRig.new()
	add_child(rig)
	rig.build(Palette.team_color(1), "▲")
	rig.position = Vector3(-1.4, 0, 1.6)
	rig.rotation_degrees.y = 20
	var rig2 := TacticalRig.new()
	add_child(rig2)
	rig2.build(Palette.team_color(2), "■")
	rig2.position = Vector3(1.4, 0, 1.6)
	rig2.rotation_degrees.y = -30
	rig2.set_meta("pose", "run")
	rig.set_weapon("rifle")
	rig2.set_weapon("mg")
	for i in 4:
		var w := WeaponModels.build(["rifle", "shotgun", "sniper", "mg"][i])
		if w != null:
			add_child(w)
			w.position = Vector3(4.0 + i * 1.0, 0.25, 2.0)
			w.rotation_degrees = Vector3(0, 110, 0)
			w.scale = Vector3.ONE * 1.6


func _process(delta: float) -> void:
	_t += delta
	for c in get_children():
		if c is TacticalRig:
			var tr := c as TacticalRig
			tr.animate(delta, 6.0 if tr.get_meta("pose", "") == "run" else 0.0, true, false, 0.0, false)
	if _t > 2.5 and not _saved and _shot != "":
		_saved = true
		var img := get_viewport().get_texture().get_image()
		var p := ProjectSettings.globalize_path("res://" + _shot)
		DirAccess.make_dir_recursive_absolute(p.get_base_dir())
		print("[Preview] saved ", p, " err ", img.save_png(p))
		get_tree().quit()
