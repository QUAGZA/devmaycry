extends Node
## Cosmetic effects driven by replicated events: tracers, impacts, dash puffs, teleports.

var _items: Array = []


func _ready() -> void:
	Game.shot_fx.connect(_on_shot)
	Game.fx.connect(_on_fx)
	Game.damage_fx.connect(_on_damage)


func _holder() -> Node3D:
	if Game.world == null:
		return null
	return Game.world.get_node_or_null("Fx")


func _on_shot(shooter_id: int, from: Vector3, to: Vector3, hit_id: int) -> void:
	var h := _holder()
	if h == null:
		return
	var shooter = Game.players.get(shooter_id)
	var start := from
	if shooter != null and is_instance_valid(shooter) and shooter.is_local():
		start = shooter.cam.global_position + shooter.cam.global_transform.basis * Vector3(0.3, -0.2, -0.6)
	var length := start.distance_to(to)
	if length > 0.2:
		var tracer := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.035, 0.035, length)
		tracer.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Palette.MINT
		m.emission_enabled = true
		m.emission = Palette.MINT
		m.emission_energy_multiplier = 4.0
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tracer.material_override = m
		h.add_child(tracer)
		tracer.global_position = (start + to) * 0.5
		if (to - start).length() > 0.001:
			tracer.look_at(to, Vector3.UP if absf((to - start).normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT)
		_items.append({"node": tracer, "t": 0.09, "life": 0.09, "mat": m})
	var color := Palette.VERMILION if hit_id != 0 else Palette.BRASS
	_spark(to, color, 0.16 if hit_id != 0 else 0.1, 0.12)


func _on_fx(kind: String, _id: int, pos: Vector3) -> void:
	match kind:
		"dash":
			_spark(pos + Vector3(0, 0.6, 0), Palette.PORCELAIN, 0.25, 0.5)
			Sfx.play("dash", -10.0)
		"teleport":
			_spark(pos + Vector3(0, 1.0, 0), Palette.MINT, 0.5, 1.2)
			Sfx.play("warp", -8.0)
		"echo_hit":
			_spark(pos + Vector3(0, 1.2, 0), Palette.VERMILION, 0.3, 0.5)
		"echo_damaged":
			_spark(pos + Vector3(0, 1.2, 0), Palette.MINT, 0.3, 0.6)
		"echo_shot":
			_spark(pos, Palette.VERMILION, 0.15, 0.25)
		"reload":
			if _id == Game.local_id():
				Sfx.play("reload", -6.0)
		"zip":
			_spark(pos + Vector3(0, 1.5, 0), Palette.BRASS, 0.4, 0.8)
		"sling":
			_spark(pos + Vector3(0, 0.5, 0), Palette.VERMILION, 0.5, 1.4)
			Sfx.play("warp", -8.0, 0.8)


func _on_damage(victim_id: int, _attacker_id: int, _amount: float, _hp_after: float, _cause: String) -> void:
	var v = Game.players.get(victim_id)
	if v != null and is_instance_valid(v) and not v.is_local():
		_spark(v.global_position + Vector3(0, 1.3, 0), Palette.VERMILION, 0.2, 0.35)


func _spark(pos: Vector3, color: Color, life: float, size: float) -> void:
	var h := _holder()
	if h == null:
		return
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = size * 0.5
	sm.height = size
	sm.radial_segments = 10
	sm.rings = 5
	s.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 3.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s.material_override = m
	h.add_child(s)
	s.global_position = pos
	_items.append({"node": s, "t": life, "life": life, "mat": m})


func _process(delta: float) -> void:
	var keep: Array = []
	for it in _items:
		it["t"] -= delta
		var n: Node3D = it["node"]
		if it["t"] <= 0.0 or not is_instance_valid(n):
			if is_instance_valid(n):
				n.queue_free()
			continue
		var a: float = clampf(it["t"] / it["life"], 0.0, 1.0)
		var m: StandardMaterial3D = it["mat"]
		m.albedo_color.a = a
		keep.append(it)
	_items = keep
