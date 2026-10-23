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


func _process(_delta: float) -> void:
	var lp := Game.local_player
	if lp == null or not is_instance_valid(lp):
		return
	if lp.alive or Game.mode_id != "corebreak":
		if not lp.cam.current:
			lp.cam.current = true
		Game.spectating = ""
		return
	var target: Player = null
	for other in Game.players.values():
		if is_instance_valid(other) and other != lp and other.alive and (lp.team == 0 or other.team == lp.team):
			target = other
			break
	if target == null:
		Game.spectating = ""
		return
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and Game.results.is_empty():
		Game.set_paused(not Game.paused_local)
		get_viewport().set_input_as_handled()
