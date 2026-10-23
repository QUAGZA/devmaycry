class_name Player
extends CharacterBody3D
## First-person combatant. The server simulates every Player from its latest input;
## clients render snapshots. Only the server decides hits, damage and deaths.

const BTN_FIRE := 1
const BTN_JUMP := 2
const BTN_SPRINT := 4
const BTN_CROUCH := 8
const BTN_DASH := 16
const BTN_ECHO := 32
const BTN_INTERACT := 64
const BTN_RELOAD := 128

const WALK_SPEED := 6.0
const SPRINT_SPEED := 8.6
const CROUCH_SPEED := 3.2
const JUMP_VELOCITY := 6.4
const GRAVITY := 18.0
const GROUND_ACCEL := 42.0
const AIR_ACCEL := 9.0
const DASH_SPEED := 17.0
const DASH_TIME := 0.17
const DASH_COOLDOWN := 4.0
const MAX_HP := 100.0
const MAG_SIZE := 8
const DAMAGE := 32.0
const FIRE_COOLDOWN := 0.17
const RELOAD_TIME := 1.4
const WEAPON_RANGE := 120.0
const STAND_HEIGHT := 1.6
const CROUCH_HEIGHT := 1.05
const MASK_SHOT := 1 | 2 | 4
const F_ALIVE := 1
const F_CROUCH := 2
const F_SPRINT := 4
const F_DASH := 8
const F_CARRY := 16
const F_FLOOR := 32
const F_PROTECT := 64
const F_STAGGER := 128
const F_ZIP := 256

var id := 0
var pname := ""
var team := 0
var is_bot := false
var glyph_index := 0
var color := Color.WHITE
var hp := MAX_HP
var alive := true
var ammo := MAG_SIZE
var reload_t := 0.0
var fire_cd := 0.0
var dash_cd := 0.0
var dash_t := 0.0
var dash_dir := Vector3.ZERO
var echo_cd := 0.0
var stagger_t := 0.0
var spawn_protect_t := 0.0
var yaw := 0.0
var pitch := 0.0
var crouching := false
var sprinting := false
var interact_held := false
var carrying_core := false
var frozen := false
var zip_t := 0.0
var last_attacker := 0
var inp_move := Vector2.ZERO
var inp_buttons := 0
var inp_seq := 0
var _prev_buttons := 0
var recorder: EchoBuffer = EchoBuffer.new()
var brain = null
var _local := false
var _net_pos := Vector3.ZERO
var _net_prev := Vector3.ZERO
var _net_yaw := 0.0
var _net_pitch := 0.0
var _net_t := 0.0
var _net_dt := 1.0 / 30.0
var _view_kick := 0.0
var flags := F_ALIVE

var head: Node3D
var cam: Camera3D
var body_mesh: MeshInstance3D
var body_mat: StandardMaterial3D
var shape: CollisionShape3D
var viewmodel: Node3D
var tag: Label3D
var vm_mat: StandardMaterial3D


func _init() -> void:
	collision_layer = 2
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(50.0)
	shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	shape.shape = cap
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)
	body_mesh = MeshInstance3D.new()
	var m := CapsuleMesh.new()
	m.radius = 0.4
	m.height = 1.8
	body_mesh.mesh = m
	body_mesh.position = Vector3(0, 0.9, 0)
	body_mat = StandardMaterial3D.new()
	body_mat.roughness = 0.55
	body_mesh.material_override = body_mat
	add_child(body_mesh)
	var visor := MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(0.36, 0.14, 0.2)
	visor.mesh = vm
	var visor_mat := StandardMaterial3D.new()
	visor_mat.albedo_color = Palette.INK
	visor_mat.emission_enabled = true
	visor_mat.emission = Palette.BRASS
	visor_mat.emission_energy_multiplier = 1.5
	visor.material_override = visor_mat
	body_mesh.add_child(visor)
	visor.position = Vector3(0, 0.62, -0.34)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, STAND_HEIGHT, 0)
	add_child(head)
	cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 86.0
	cam.near = 0.05
	cam.far = 400.0
	head.add_child(cam)
	viewmodel = Node3D.new()
	viewmodel.name = "Viewmodel"
	viewmodel.position = Vector3(0.3, -0.24, -0.45)
	viewmodel.visible = false
	cam.add_child(viewmodel)
	_build_viewmodel()
	tag = Label3D.new()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0, 2.25, 0)
	tag.font_size = 48
	tag.pixel_size = 0.006
	tag.outline_size = 10
	add_child(tag)


func _build_viewmodel() -> void:
	vm_mat = StandardMaterial3D.new()
	vm_mat.albedo_color = Palette.PORCELAIN
	vm_mat.roughness = 0.4
	vm_mat.metallic = 0.2
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.09, 0.11, 0.52)
	body.mesh = bm
	body.material_override = vm_mat
	viewmodel.add_child(body)
	var grip := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.07, 0.16, 0.09)
	grip.mesh = gm
	grip.position = Vector3(0, -0.12, 0.12)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Palette.INK
	grip.material_override = gmat
	viewmodel.add_child(grip)
	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.05
	rm.outer_radius = 0.085
	ring.mesh = rm
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.position = Vector3(0, 0, -0.3)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Palette.MINT
	rmat.emission_enabled = true
	rmat.emission = Palette.MINT
	rmat.emission_energy_multiplier = 2.0
	ring.material_override = rmat
	viewmodel.add_child(ring)


func setup(id_: int, info: Dictionary) -> void:
	id = id_
	pname = str(info.get("name", "P%d" % id))
	team = int(info.get("team", 0))
	is_bot = bool(info.get("is_bot", false))
	glyph_index = int(info.get("glyph", 0))
	color = Palette.player_color(info)
	body_mat.albedo_color = color
	tag.text = "%s %s" % [Palette.glyph(glyph_index), pname]
	tag.modulate = color
	name = "P%d" % id


func make_local() -> void:
	_local = true
	cam.current = true
	body_mesh.visible = false
	tag.visible = false
	viewmodel.visible = true
	if DisplayServer.get_name() != "headless" and Game.autopilot == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_local() -> bool:
	return _local


func aim_dir() -> Vector3:
	return -(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)).z


func eye_position() -> Vector3:
	return global_position + Vector3(0, head.position.y, 0)


# ---------------------------------------------------------------- input (local)
func _unhandled_input(event: InputEvent) -> void:
	if not _local or Game.paused_local:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * Settings.mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * Settings.mouse_sensitivity, -1.45, 1.45)
		yaw = wrapf(yaw, -PI, PI)


func gather_input() -> Array:
	if Game.autopilot != null:
		return Game.autopilot.produce(self)
	if Game.paused_local or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return [Vector2.ZERO, yaw, pitch, 0]
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var b := 0
	if Input.is_action_pressed("fire"):
		b |= BTN_FIRE
	if Input.is_action_pressed("jump"):
		b |= BTN_JUMP
	if Input.is_action_pressed("sprint"):
		b |= BTN_SPRINT
	if Input.is_action_pressed("crouch"):
		b |= BTN_CROUCH
	if Input.is_action_pressed("dash"):
		b |= BTN_DASH
	if Input.is_action_pressed("echo"):
		b |= BTN_ECHO
	if Input.is_action_pressed("interact"):
		b |= BTN_INTERACT
	if Input.is_action_pressed("reload"):
		b |= BTN_RELOAD
	return [move, yaw, pitch, b]


func set_input(move: Vector2, yaw_: float, pitch_: float, buttons: int, seq: int) -> void:
	if seq < inp_seq and inp_seq - seq < 1000:
		return
	inp_seq = seq
	inp_move = move.limit_length(1.0)
	yaw = wrapf(yaw_, -PI, PI)
	pitch = clampf(pitch_, -1.45, 1.45)
	inp_buttons = buttons


# ---------------------------------------------------------------- server simulation
func server_step(delta: float) -> void:
	_tick_timers(delta)
	if brain != null:
		brain.think(delta)
	rotation.y = yaw
	head.rotation.x = pitch
	var pressed := inp_buttons & ~_prev_buttons
	_prev_buttons = inp_buttons
	if not alive or frozen:
		velocity = Vector3.ZERO
		if alive and not is_on_floor():
			velocity.y -= GRAVITY * delta
			move_and_slide()
		interact_held = false
		return
	if zip_t > 0.0:
		return
	var staggered := stagger_t > 0.0
	crouching = (inp_buttons & BTN_CROUCH) != 0
	head.position.y = lerpf(head.position.y, CROUCH_HEIGHT if crouching else STAND_HEIGHT, 12.0 * delta)
	var fwd_amount := -inp_move.y
	sprinting = (inp_buttons & BTN_SPRINT) != 0 and fwd_amount > 0.3 and not crouching and not staggered and reload_t <= 0.0
	var speed := WALK_SPEED
	if sprinting:
		speed = SPRINT_SPEED
	elif crouching:
		speed = CROUCH_SPEED
	if staggered:
		speed *= 0.45
	if carrying_core:
		speed *= 0.9
	var wish := Vector3(inp_move.x, 0.0, inp_move.y)
	if wish.length() > 1.0:
		wish = wish.normalized()
	wish = Basis(Vector3.UP, yaw) * wish
	var on_floor := is_on_floor()
	if not on_floor:
		velocity.y -= GRAVITY * delta
	elif (pressed & BTN_JUMP) != 0 and not staggered:
		velocity.y = JUMP_VELOCITY
	if (pressed & BTN_DASH) != 0 and dash_cd <= 0.0 and not staggered:
		dash_cd = DASH_COOLDOWN
		dash_t = DASH_TIME
		dash_dir = wish.normalized() if wish.length() > 0.1 else (Basis(Vector3.UP, yaw) * Vector3.FORWARD)
		recorder.push_event(_now(), EchoBuffer.EVT_DASH, yaw, pitch)
		Game.rpc_fx.rpc("dash", id, global_position)
	var target := wish * speed
	var accel := GROUND_ACCEL if on_floor else AIR_ACCEL
	if dash_t > 0.0:
		velocity.x = dash_dir.x * DASH_SPEED
		velocity.z = dash_dir.z * DASH_SPEED
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.x = move_toward(velocity.x, target.x, accel * delta)
		velocity.z = move_toward(velocity.z, target.z, accel * delta)
	move_and_slide()
	if reload_t > 0.0:
		pass
	elif (pressed & BTN_RELOAD) != 0 and ammo < MAG_SIZE:
		_start_reload()
	elif (pressed & BTN_FIRE) != 0 and fire_cd <= 0.0 and not staggered:
		if ammo > 0:
			_shoot()
		else:
			_start_reload()
	interact_held = (inp_buttons & BTN_INTERACT) != 0
	if (pressed & BTN_ECHO) != 0 and Game.match_server != null:
		Game.match_server.request_echo(self)
	recorder.push(_now(), global_position, yaw, pitch)
	if Game.map_def != null and global_position.y < Game.map_def.kill_y and Game.match_server != null:
		Game.match_server.on_out_of_bounds(self)


func _now() -> float:
	return Game.match_server.match_time if Game.match_server != null else 0.0


func _tick_timers(delta: float) -> void:
	fire_cd = maxf(0.0, fire_cd - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	dash_t = maxf(0.0, dash_t - delta)
	echo_cd = maxf(0.0, echo_cd - delta)
	stagger_t = maxf(0.0, stagger_t - delta)
	spawn_protect_t = maxf(0.0, spawn_protect_t - delta)
	zip_t = maxf(0.0, zip_t - delta)
	if reload_t > 0.0:
		reload_t = maxf(0.0, reload_t - delta)
		if reload_t <= 0.0:
			ammo = MAG_SIZE


func _start_reload() -> void:
	reload_t = RELOAD_TIME
	Game.rpc_fx.rpc("reload", id, global_position)


func _shoot() -> void:
	ammo -= 1
	fire_cd = FIRE_COOLDOWN
	spawn_protect_t = 0.0
	var from := eye_position()
	var dir := aim_dir()
	var to := from + dir * WEAPON_RANGE
	var hit := trace_shot(from, to)
	var hit_id := 0
	var hit_pos := to
	if not hit.is_empty():
		hit_pos = hit["position"]
		var col = hit["collider"]
		if col is Player:
			hit_id = col.id
			col.apply_damage(DAMAGE, id, "pulse", 0.0)
		elif col != null and col.has_method("hit_by_shot"):
			col.hit_by_shot(id)
			hit_id = -9999
	recorder.push_event(_now(), EchoBuffer.EVT_FIRE, yaw, pitch)
	Game.rpc_shot.rpc(id, from, hit_pos, hit_id)


func trace_shot(from: Vector3, to: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, MASK_SHOT, [get_rid()])
	return space.intersect_ray(q)


## Returns true if damage was applied. min_hp stops Echo damage from killing.
func apply_damage(amount: float, from_id: int, cause: String, min_hp: float) -> bool:
	if not alive or spawn_protect_t > 0.0 or frozen:
		return false
	if Game.match_server != null and not Game.match_server.can_damage(from_id, self):
		return false
	var new_hp := maxf(min_hp, hp - amount)
	var dealt := hp - new_hp
	if dealt <= 0.0:
		return false
	hp = new_hp
	last_attacker = from_id
	Game.rpc_damage.rpc(id, from_id, dealt, hp, cause)
	if Game.match_server != null:
		Game.match_server.on_damaged(self, from_id, cause)
	if hp <= 0.0:
		_die(from_id, cause)
	return true


func stagger(seconds: float) -> void:
	stagger_t = maxf(stagger_t, seconds)


func _die(killer_id: int, cause: String) -> void:
	alive = false
	hp = 0.0
	velocity = Vector3.ZERO
	collision_layer = 0
	carrying_core = false
	interact_held = false
	recorder.clear()
	if Game.match_server != null:
		Game.match_server.on_player_died(self, killer_id, cause)


func respawn(pos: Vector3, yaw_: float, protect: float) -> void:
	hp = MAX_HP
	alive = true
	ammo = MAG_SIZE
	reload_t = 0.0
	fire_cd = 0.0
	dash_cd = 0.0
	dash_t = 0.0
	stagger_t = 0.0
	zip_t = 0.0
	spawn_protect_t = protect
	frozen = false
	carrying_core = false
	collision_layer = 2
	velocity = Vector3.ZERO
	global_position = pos
	yaw = yaw_
	pitch = 0.0
	rotation.y = yaw
	head.rotation.x = 0.0
	last_attacker = 0
	recorder.clear()
	_net_pos = pos
	_net_prev = pos
	_apply_flags_visual()


func teleport(pos: Vector3, yaw_: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	yaw = yaw_
	rotation.y = yaw
	_net_pos = pos
	_net_prev = pos


# ---------------------------------------------------------------- replication
func pack_state() -> Array:
	var f := 0
	if alive:
		f |= F_ALIVE
	if crouching:
		f |= F_CROUCH
	if sprinting:
		f |= F_SPRINT
	if dash_t > 0.0:
		f |= F_DASH
	if carrying_core:
		f |= F_CARRY
	if is_on_floor():
		f |= F_FLOOR
	if spawn_protect_t > 0.0:
		f |= F_PROTECT
	if stagger_t > 0.0:
		f |= F_STAGGER
	if zip_t > 0.0:
		f |= F_ZIP
	flags = f
	return [id, global_position, yaw, pitch, hp, ammo, f, reload_t, dash_cd, echo_cd, stagger_t, spawn_protect_t, velocity]


func apply_state(s: Array) -> void:
	_net_prev = global_position
	_net_pos = s[1]
	_net_t = Time.get_ticks_msec() / 1000.0
	if not _local:
		_net_yaw = s[2]
		_net_pitch = s[3]
	hp = s[4]
	ammo = s[5]
	var old_flags := flags
	flags = s[6]
	reload_t = s[7]
	dash_cd = s[8]
	echo_cd = s[9]
	stagger_t = s[10]
	spawn_protect_t = s[11]
	velocity = s[12]
	alive = (flags & F_ALIVE) != 0
	crouching = (flags & F_CROUCH) != 0
	carrying_core = (flags & F_CARRY) != 0
	if (old_flags & F_ALIVE) != (flags & F_ALIVE):
		_apply_flags_visual()
	if _net_prev.distance_to(_net_pos) > 6.0:
		_net_prev = _net_pos
		global_position = _net_pos


func _apply_flags_visual() -> void:
	body_mesh.visible = alive and not _local
	tag.visible = alive and not _local
	shape.disabled = not alive


func _process(delta: float) -> void:
	_view_kick = lerpf(_view_kick, 0.0, 14.0 * delta)
	if viewmodel.visible:
		viewmodel.position = Vector3(0.3, -0.24 - _view_kick * 0.02, -0.45 + _view_kick * 0.08)
		viewmodel.rotation.x = _view_kick * 0.12
	if multiplayer.is_server():
		if _local:
			rotation.y = yaw
			head.rotation.x = pitch
		return
	var a := clampf((Time.get_ticks_msec() / 1000.0 - _net_t) / _net_dt, 0.0, 1.0)
	global_position = _net_prev.lerp(_net_pos, a)
	if _local:
		rotation.y = yaw
		head.rotation.x = pitch
	else:
		rotation.y = lerp_angle(rotation.y, _net_yaw, 0.35)
		head.rotation.x = lerpf(head.rotation.x, _net_pitch, 0.35)
	head.position.y = lerpf(head.position.y, CROUCH_HEIGHT if crouching else STAND_HEIGHT, 12.0 * delta)


func kick_view() -> void:
	_view_kick = 1.0
