extends Node
## Match scene root: builds the selected arena into World, then reports readiness.


## Map signage keeps a constant on-screen size: readable at range, never a wall of text up close.
static func _fix_label(l: Label3D) -> void:
	l.fixed_size = true
	l.pixel_size = 0.0003 * clampf(float(l.font_size) / 40.0, 0.6, 1.3)
	l.outline_size = maxi(l.outline_size, 8)


## Looping map ambience on the Ambience bus (procedural beds from tools/gen_ambience.py).
func _start_ambience(def: MapDef) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var path := "res://assets/sfx/amb_%s.wav" % {"oracle": "oracle", "tideline": "tideline", "foundry": "foundry"}.get(def.family, "oracle")
	if not ResourceLoader.exists(path):
		return
	var st := load(path) as AudioStreamWAV
	if st == null:
		return
	var pl := AudioStreamPlayer.new()
	pl.stream = st
	pl.bus = "Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else "Master"
	pl.volume_db = -14.0
	add_child(pl)
	pl.play()
	Game.log_ev("Audio", "ambience", {"map": def.id, "stream": path, "loop_mode": st.loop_mode, "length_s": snappedf(st.get_length(), 0.1)})


func _ready() -> void:
	var world := $World as Node3D
	var def := Maps.make(Game.map_id)
	def.build(world)
	def.bake_nav()
	if DisplayServer.get_name() != "headless":
		Settings.apply_graphics()
		for l in world.find_children("*", "Label3D", true, false):
			_fix_label(l as Label3D)
	var objectives := Node.new()
	objectives.name = "Objectives"
	objectives.set_script(load("res://src/match/Objectives.gd"))
	add_child(objectives)
	Game.on_match_scene_ready(world, def)
	if DisplayServer.get_name() != "headless":
		# graphics toggles that target the match environment need Game.world, which is set just above
		Settings.apply_graphics()
		get_tree().create_timer(2.5).timeout.connect(func() -> void: Diag.apply(world))
	_start_ambience(def)
	if DisplayServer.get_name() != "headless":
		get_tree().create_timer(0.8).timeout.connect(func() -> void:
			for l in world.find_children("*", "Label3D", true, false):
				if not (l.get_parent() is Player):
					_fix_label(l as Label3D))


var spec_cam: Camera3D = null
var spec_target: Player = null
var spec_index := 0


func _process(_delta: float) -> void:
	var lp := Game.local_player
	if lp == null or not is_instance_valid(lp):
		return
	if lp.alive or Game.mode_id == "relic_rush":
		if not lp.cam.current:
			lp.cam.current = true
		_release_spectate()
		return
	var candidates: Array = []
	for other: Player in Game.players.values():
		if is_instance_valid(other) and other != lp and other.alive and (lp.team == 0 or other.team == lp.team):
			candidates.append(other)
	if candidates.is_empty():
		_release_spectate()
		return
	if Game.autopilot == null and Input.is_action_just_pressed("fire") and candidates.size() > 1:
		spec_index += 1
	var target: Player = candidates[posmod(spec_index, candidates.size())]
	if target != spec_target:
		_release_spectate()
		spec_target = target
		spec_target.set_spectated(true)
	if spec_cam == null:
		spec_cam = Camera3D.new()
		spec_cam.fov = 86.0
		spec_cam.near = 0.05
		$World.add_child(spec_cam)
		Style.add_outline(spec_cam)
	spec_cam.global_position = target.eye_position()
	spec_cam.global_rotation = Vector3(target.head.rotation.x, target.rotation.y, 0.0)
	if not spec_cam.current:
		spec_cam.current = true
	Game.spectating = target.pname


func _release_spectate() -> void:
	Game.spectating = ""
	if spec_target != null and is_instance_valid(spec_target):
		spec_target.set_spectated(false)
	spec_target = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map") and Game.results.is_empty() and not Game.paused_local:
		Game.map_open = not Game.map_open
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and Game.results.is_empty():
		if Game.map_open:
			Game.map_open = false
		else:
			Game.set_paused(not Game.paused_local)
		get_viewport().set_input_as_handled()
