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
			Sfx.play("portal", -6.0)
		"echo_hit":
			_spark(pos + Vector3(0, 1.2, 0), Palette.VERMILION, 0.3, 0.5)
		"echo_damaged":
			_spark(pos + Vector3(0, 1.2, 0), Palette.MINT, 0.3, 0.6)
		"echo_shot":
			_spark(pos, Palette.VERMILION, 0.15, 0.25)
		"muzzle":
			var sh = Game.players.get(_id)
			if sh == null or not is_instance_valid(sh) or not sh.is_local():
				_spark(pos, Palette.BRASS, 0.06, 0.3)
		"warn":
			Sfx.play("warn", -6.0)
		"field_enter":
			Sfx.play("field_enter", -8.0)
		"field_exit":
			Sfx.play("field_exit", -8.0)
		"impact_player":
			_spark(pos, Palette.VERMILION, 0.2, 0.4)
		"switch":
			if _id == Game.local_id():
				Sfx.play("reload", -10.0, 1.4)
		"restore":
			_spark(pos + Vector3(0, 1.0, 0), Palette.MINT, 0.5, 1.6)
			Sfx.play("restore", -4.0)
		"impact":
			_spark(pos + Vector3(0, 0.8, 0), Palette.PORCELAIN, 0.15, 0.35)
		"detonate":
			_spark(pos + Vector3(0, 1.5, 0), Palette.VERMILION, 1.2, 9.0)
			Sfx.play("detonate", 0.0)
		"core_pickup":
			_spark(pos + Vector3(0, 1.5, 0), Palette.BRASS, 0.4, 1.2)
			Sfx.play("capture", -6.0)
		"core_drop":
			_spark(pos + Vector3(0, 1.0, 0), Palette.BRASS, 0.4, 1.0)
			Sfx.play("core_drop", -4.0)
		"stabilize":
			_spark(pos + Vector3(0, 1.5, 0), Palette.MINT, 1.0, 4.0)
			Sfx.play("sting", -4.0)
		"rewind_start":
			_spark(pos + Vector3(0, 1.2, 0), Palette.COBALT, 0.45, 1.6)
			Sfx.play("rewind", -2.0)
		"ff_start":
			_spark(pos + Vector3(0, 0.3, 0), Palette.VERMILION, 0.6, 3.0)
			Sfx.play("ff", -3.0)
		"reload":
			if _id == Game.local_id():
				Sfx.play("reload", -6.0)
		"zip":
			_spark(pos + Vector3(0, 1.5, 0), Palette.BRASS, 0.4, 0.8)
			Sfx.play("zip", -8.0)
		"sling":
			_spark(pos + Vector3(0, 0.5, 0), Palette.VERMILION, 0.5, 1.4)
			Sfx.play("pad", -6.0)


func _on_damage(victim_id: int, _attacker_id: int, _amount: float, _hp_after: float, _cause: String) -> void:
	var v = Game.players.get(victim_id)
	if v != null and is_instance_valid(v) and not v.is_local():
		_spark(v.global_position + Vector3(0, 1.3, 0), Palette.VERMILION, 0.2, 0.35)


const BUBBLE := preload("res://src/shaders/fx_bubble.gdshader")


## Short light burst. Small bursts (impacts, muzzle) are tiny unshaded spheres; large ones (teleport, rewind,
## stabilize, detonation) are soft additive bubbles that swell while they fade, never a hard faceted ball.
func _spark(pos: Vector3, color: Color, life: float, size: float) -> void:
	var h := _holder()
	if h == null:
		return
	var soft := size >= 1.0
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = size * 0.5
	sm.height = size
	sm.radial_segments = 28 if soft else 8
	sm.rings = 14 if soft else 4
	s.mesh = sm
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m: Material
	if soft:
		var sh := ShaderMaterial.new()
		sh.shader = BUBBLE
		sh.set_shader_parameter("tint", color)
		m = sh
	else:
		var sm2 := StandardMaterial3D.new()
		sm2.albedo_color = color
		sm2.emission_enabled = true
		sm2.emission = color
		sm2.emission_energy_multiplier = 3.0
		sm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m = sm2
	s.material_override = m
	h.add_child(s)
	s.global_position = pos
	_items.append({"node": s, "t": life, "life": life, "mat": m, "soft": soft})


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
		if bool(it.get("soft", false)):
			(it["mat"] as ShaderMaterial).set_shader_parameter("fade", a)
			n.scale = Vector3.ONE * lerpf(1.25, 0.55, a)
		else:
			(it["mat"] as StandardMaterial3D).albedo_color.a = a
		keep.append(it)
	_items = keep
