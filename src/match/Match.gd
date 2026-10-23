extends Node
## Match scene root: builds the selected arena into World, then reports readiness.


func _ready() -> void:
	var world := $World as Node3D
	var def := Maps.make(Game.map_id)
	def.build(world)
	def.bake_nav()
	var objectives := Node.new()
	objectives.name = "Objectives"
	objectives.set_script(load("res://src/match/Objectives.gd"))
	add_child(objectives)
	Game.on_match_scene_ready(world, def)


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
	if event.is_action_pressed("pause") and Game.results.is_empty():
		Game.set_paused(not Game.paused_local)
		get_viewport().set_input_as_handled()
