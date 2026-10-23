extends Node
## Match scene root: builds the selected arena into World, then reports readiness.


func _ready() -> void:
	var world := $World as Node3D
	var def := Maps.make(Game.map_id)
	def.build(world)
	Game.on_match_scene_ready(world, def)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and Game.results.is_empty():
		Game.set_paused(not Game.paused_local)
		get_viewport().set_input_as_handled()
