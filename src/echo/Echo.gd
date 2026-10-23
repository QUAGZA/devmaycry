class_name Echo
extends Node3D
## Temporal duplicate. Replays a recorded 2.5 s path once after a 0.6 s telegraph.
## Exists on every peer for presentation; only the server resolves spectral shots and destruction.

const TELEGRAPH := 0.6
const DAMAGE := 16.0
const MIN_HP := 1.0
const MAX_HITS := 2
const FADE := 0.45
const SHOT_RANGE := 80.0

var eid := 0
var owner_id := 0
var payload: Dictionary = {}
var duration := 0.0
var owner_team := 0
var owner_color := Color.WHITE
var t := -TELEGRAPH
var hits_taken := 0
var damaged: Dictionary = {}
var finished := false
var _fade_t := 0.0
var _next_event := 0
var ghost: Node3D
var head: Node3D
var body: StaticBody3D
var markers: Node3D = null
var sigil: MeshInstance3D
var label: Label3D
var _layers: Array = []
var _tracers: Array = []


func setup(eid_: int, owner_id_: int, payload_: Dictionary) -> void:
	eid = eid_
	owner_id = owner_id_
	payload = payload_
	duration = float(payload.get("duration", 0.0))
	name = "Echo%d" % eid
	var info: Dictionary = Net.players.get(owner_id, {})
	owner_team = int(info.get("team", 0))
	owner_color = Palette.player_color(info) if not info.is_empty() else Palette.MINT


func _ready() -> void:
	_build_visuals()
	var s := EchoBuffer.sample_at(payload, 0.0)
	global_position = s["pos"]
	rotation.y = s["yaw"]
	ghost.visible = false
	Sfx.play("echo_cast", -4.0)


func _build_visuals() -> void:
	ghost = Node3D.new()
	add_child(ghost)
	var specs := [[Vector3.ZERO, owner_color, 0.5], [Vector3(0.06, 0, 0), Palette.VERMILION, 0.32], [Vector3(-0.06, 0, 0), Palette.MINT, 0.32]]
	for spec in specs:
		var mi := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.42
		cm.height = 1.85
		mi.mesh = cm
		mi.position = Vector3(0, 0.92, 0) + spec[0]
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(spec[1], spec[2])
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.emission_enabled = true
		m.emission = spec[1]
		m.emission_energy_multiplier = 1.1
		mi.material_override = m
		ghost.add_child(mi)
		_layers.append(mi)
	var outline := MeshInstance3D.new()
	var om := CapsuleMesh.new()
	om.radius = 0.48
	om.height = 1.97
	outline.mesh = om
	outline.position = Vector3(0, 0.92, 0)
	var omat := StandardMaterial3D.new()
	omat.albedo_color = Palette.INK
	omat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	omat.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.material_override = omat
	ghost.add_child(outline)
	head = Node3D.new()
	head.position = Vector3(0, 1.6, 0)
	ghost.add_child(head)
	label = Label3D.new()
	label.text = "MEMORY CAST"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 2.45, 0)
	label.font_size = 40
	label.pixel_size = 0.006
	label.outline_size = 8
	label.modulate = owner_color
	add_child(label)
	body = StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.9
	cs.shape = cap
	cs.position = Vector3(0, 0.95, 0)
	body.add_child(cs)
	add_child(body)
	# Stamped route in world space
	markers = Node3D.new()
	markers.name = "EchoPath%d" % eid
	var holder := Game.world.get_node("Echoes")
	holder.add_child(markers)
	var pos: PackedVector3Array = payload["pos"]
	var yaws: PackedFloat32Array = payload["yaw"]
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(owner_color, 0.85)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.emission_enabled = true
	mm.emission = owner_color
	mm.emission_energy_multiplier = 1.5
	for i in pos.size():
		var q := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(0.5, 0.28)
		q.mesh = pm
		q.material_override = mm
		q.position = pos[i] + Vector3(0, 0.05, 0)
		q.rotation.y = yaws[i]
		markers.add_child(q)
	sigil = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.0
	tm.outer_radius = 1.15
	sigil.mesh = tm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Palette.VERMILION
	sm.emission_enabled = true
	sm.emission = Palette.VERMILION
	sm.emission_energy_multiplier = 2.5
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sigil.material_override = sm
	sigil.position = pos[0] + Vector3(0, 0.08, 0)
	markers.add_child(sigil)


func _physics_process(delta: float) -> void:
	_tick_tracers(delta)
	if finished:
		_fade_t -= delta
		var a := clampf(_fade_t / FADE, 0.0, 1.0)
		ghost.scale = Vector3(1.0 + (1.0 - a) * 0.3, maxf(a, 0.05), 1.0 + (1.0 - a) * 0.3)
		label.visible = false
		if _fade_t <= 0.0:
			queue_free()
		return
	t += delta
	if t < 0.0:
		var k := 1.0 - (-t / TELEGRAPH)
		if sigil != null and is_instance_valid(sigil):
			sigil.scale = Vector3.ONE * (0.6 + 0.9 * k)
		label.text = "MEMORY CAST / T-%0.1f" % (-t)
		return
	if not ghost.visible:
		ghost.visible = true
		Sfx.play("echo_materialize", -4.0)
	var s := EchoBuffer.sample_at(payload, t)
	global_position = s["pos"]
	rotation.y = s["yaw"]
	head.rotation.x = s["pitch"]
	label.text = "PLAYBACK / F-%03d" % int(t * 10.0)
	var drift := 0.04 + 0.14 * clampf(t / maxf(duration, 0.1), 0.0, 1.0)
	if _layers.size() >= 3:
		_layers[1].position.x = drift
		_layers[2].position.x = -drift
	var events: Array = payload.get("events", [])
	while _next_event < events.size() and float(events[_next_event][0]) <= t:
		_play_event(events[_next_event])
		_next_event += 1
	if multiplayer.is_server():
		if t >= duration + 0.35:
			Game.rpc_echo_end.rpc(eid, "expired")
	elif t >= duration + 2.5:
		finish("expired")


func _play_event(e: Array) -> void:
	var kind := int(e[1])
	var yaw := float(e[2])
	var pitch := float(e[3])
	if kind == EchoBuffer.EVT_FIRE:
		var from := global_position + Vector3(0, 1.6, 0)
		var dir := -(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)).z
		var to := from + dir * SHOT_RANGE
		var hit_pos := to
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2, [body.get_rid()])
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			hit_pos = hit["position"]
			if multiplayer.is_server():
				var col = hit["collider"]
				if col is Player and col.id != owner_id and not damaged.has(col.id):
					if Game.match_server != null and Game.match_server.can_damage(owner_id, col):
						if col.apply_damage(DAMAGE, owner_id, "echo", MIN_HP):
							damaged[col.id] = true
							col.stagger(0.5)
							Game.rpc_fx.rpc("echo_hit", col.id, col.global_position)
							Game.log_ev("Echo", "hit", {"echo": eid, "owner": owner_id, "victim": col.id})
		_tracer(from + dir * 0.6, hit_pos)
		Sfx.play("echo_shot", -10.0, 0.8)
	elif kind == EchoBuffer.EVT_DASH:
		Game.fx.emit("dash", owner_id, global_position)


func _tracer(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.3 or Game.world == null:
		return
	var tr := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, length)
	tr.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(Palette.VERMILION, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = Palette.VERMILION
	m.emission_energy_multiplier = 3.0
	tr.material_override = m
	Game.world.get_node("Fx").add_child(tr)
	tr.global_position = (from + to) * 0.5
	var d := (to - from).normalized()
	tr.look_at(to, Vector3.UP if absf(d.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT)
	_tracers.append({"node": tr, "t": 0.14, "mat": m})


func _tick_tracers(delta: float) -> void:
	var keep: Array = []
	for it in _tracers:
		it["t"] -= delta
		if it["t"] <= 0.0:
			if is_instance_valid(it["node"]):
				it["node"].queue_free()
		else:
			it["mat"].albedo_color.a = clampf(it["t"] / 0.14, 0.0, 1.0)
			keep.append(it)
	_tracers = keep


## Server only: opponents can erase an Echo with two confirmed hits.
func hit_by_shot(shooter_id: int) -> void:
	if finished or t < 0.0 or not multiplayer.is_server():
		return
	if shooter_id == owner_id:
		return
	hits_taken += 1
	Game.rpc_fx.rpc("echo_damaged", eid, global_position)
	Game.log_ev("Echo", "shot", {"echo": eid, "by": shooter_id, "hits": hits_taken})
	if hits_taken >= MAX_HITS:
		Game.rpc_echo_end.rpc(eid, "destroyed")


func finish(reason: String) -> void:
	if finished:
		return
	finished = true
	_fade_t = FADE
	body.collision_layer = 0
	if markers != null and is_instance_valid(markers):
		markers.queue_free()
	for it in _tracers:
		if is_instance_valid(it["node"]):
			it["node"].queue_free()
	_tracers.clear()
	Game.log_ev("Echo", "end", {"echo": eid, "reason": reason})
	if reason == "destroyed":
		Sfx.play("echo_break", -4.0)
