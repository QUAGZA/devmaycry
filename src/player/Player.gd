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
const BTN_ADS := 256
const BTN_SLOT1 := 512
const BTN_SLOT2 := 1024
const BTN_SLOT3 := 2048
const BTN_SLOT4 := 4096

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
const STEP_HEIGHT := 0.55
const CROUCH_HEIGHT := 1.05
const MASK_SHOT := 1 | 2 | 4 | 32
const TEMPORAL_LAYER := 32
const F_ALIVE := 1
const F_CROUCH := 2
const F_SPRINT := 4
const F_DASH := 8
const F_CARRY := 16
const F_FLOOR := 32
const F_PROTECT := 64
const F_STAGGER := 128
const F_ZIP := 256
const F_RE_SPENT := 512
const F_FF_SPENT := 1024
const F_REWIND := 2048
const F_FF := 4096
const F_ADS := 8192
const CARRY_SPEED := 4.2

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
var launch_t := 0.0
var rewind_t := 0.0
var rewind_total := 6.0
var rewind_start := 0.0
var body_yaw := 0.0
var re_spent := false
var ff_spent := false
var ff_until := 0.0
var last_attacker := 0
var inp_move := Vector2.ZERO
var inp_buttons := 0
var inp_seq := 0
var _prev_buttons := 0
var recorder: EchoBuffer = EchoBuffer.new()
var weapon_id := "rifle"
var ammo_state: Dictionary = {}
var reserve := 90
var spray := 0.0
var spray_t := 0.0
var ads := false
var switch_t := 0.0
var viewmodels: Dictionary = {}
var _fov_target := 86.0
var brain = null
var _local := false
var _net_pos := Vector3.ZERO
var _net_prev := Vector3.ZERO
var _net_yaw := 0.0
var _net_pitch := 0.0
var _net_t := 0.0
var _net_dt := 1.0 / 30.0
var _view_kick := 0.0
var _floor_t := 0.0
var _spectated := false
var flags := F_ALIVE

var head: Node3D
var cam: Camera3D
var body_mesh: MeshInstance3D
var body_mat: StandardMaterial3D
var shape: CollisionShape3D
var viewmodel: Node3D
var tag: Label3D
var vm_mat: StandardMaterial3D
var rig: HumanoidRig


func _init() -> void:
	collision_layer = 2
	collision_mask = 1 | 2 | TEMPORAL_LAYER
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
	body_mesh.visible = false
	add_child(body_mesh)
	rig = HumanoidRig.new()
	rig.name = "Rig"
	add_child(rig)
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
	viewmodel.position = Vector3(0.27, -0.23, -0.5)
	viewmodel.scale = Vector3(0.58, 0.58, 0.58)
	viewmodel.visible = false
	cam.add_child(viewmodel)
	_build_viewmodel()
	_reset_ammo()
	tag = Label3D.new()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0, 2.25, 0)
	tag.font_size = 48
	tag.pixel_size = 0.006
	tag.outline_size = 10
	add_child(tag)


func _vm_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _vm_cyl(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material, along_z: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.position = pos
	if along_z:
		mi.rotation_degrees = Vector3(90, 0, 0)
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## Four original first-person weapon models built from parts (ink body, porcelain grips, brass/mint accents).
func _build_viewmodel() -> void:
	vm_mat = StandardMaterial3D.new()
	vm_mat.albedo_color = Palette.INK
	vm_mat.roughness = 0.35
	vm_mat.metallic = 0.5
	var porcelain := StandardMaterial3D.new()
	porcelain.albedo_color = Palette.PORCELAIN
	porcelain.roughness = 0.5
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Palette.BRASS
	brass.metallic = 0.8
	brass.roughness = 0.3
	for wid in Weapons.ORDER:
		var root := Node3D.new()
		root.name = wid
		var col := Color(str(Weapons.get_data(wid)["color"]))
		var glow := StandardMaterial3D.new()
		glow.albedo_color = col
		glow.emission_enabled = true
		glow.emission = col
		glow.emission_energy_multiplier = 2.0
		match wid:
			"rifle":
				_vm_box(root, Vector3(0.06, 0.08, 0.42), Vector3(0, 0, -0.02), vm_mat)
				_vm_box(root, Vector3(0.05, 0.12, 0.06), Vector3(0, -0.09, 0.1), porcelain)
				_vm_box(root, Vector3(0.04, 0.14, 0.05), Vector3(0, -0.1, -0.06), vm_mat)
				_vm_cyl(root, 0.014, 0.2, Vector3(0, 0.02, -0.3), brass)
				_vm_box(root, Vector3(0.02, 0.02, 0.05), Vector3(0, 0.06, -0.12), glow)
			"shotgun":
				_vm_cyl(root, 0.03, 0.46, Vector3(0, 0.0, -0.08), vm_mat)
				_vm_cyl(root, 0.022, 0.3, Vector3(0, -0.045, -0.12), porcelain)
				_vm_box(root, Vector3(0.07, 0.11, 0.1), Vector3(0, -0.07, 0.14), porcelain)
				_vm_box(root, Vector3(0.05, 0.05, 0.1), Vector3(0, -0.04, -0.18), brass)
				_vm_box(root, Vector3(0.02, 0.02, 0.03), Vector3(0, 0.04, -0.3), glow)
			"sniper":
				_vm_box(root, Vector3(0.05, 0.07, 0.6), Vector3(0, 0, -0.1), vm_mat)
				_vm_cyl(root, 0.012, 0.36, Vector3(0, 0.0, -0.5), brass)
				_vm_cyl(root, 0.035, 0.18, Vector3(0, 0.085, -0.08), vm_mat)
				_vm_cyl(root, 0.03, 0.01, Vector3(0, 0.085, -0.17), glow)
				_vm_box(root, Vector3(0.05, 0.12, 0.06), Vector3(0, -0.09, 0.12), porcelain)
			"mg":
				_vm_box(root, Vector3(0.09, 0.11, 0.46), Vector3(0, 0, -0.02), vm_mat)
				_vm_box(root, Vector3(0.1, 0.09, 0.14), Vector3(-0.07, -0.03, 0.02), porcelain)
				_vm_cyl(root, 0.02, 0.22, Vector3(0, 0.02, -0.34), brass)
				_vm_box(root, Vector3(0.05, 0.13, 0.06), Vector3(0, -0.1, 0.12), porcelain)
				_vm_box(root, Vector3(0.025, 0.025, 0.08), Vector3(0.04, 0.06, -0.1), glow)
		root.visible = wid == weapon_id
		viewmodel.add_child(root)
		viewmodels[wid] = root


func _reset_ammo() -> void:
	ammo_state.clear()
	for wid in Weapons.ORDER:
		var w := Weapons.get_data(wid)
		ammo_state[wid] = {"mag": int(w["mag"]), "reserve": int(w["reserve"])}
	ammo = int(ammo_state[weapon_id]["mag"])
	reserve = int(ammo_state[weapon_id]["reserve"])
	spray = 0.0


func _switch_weapon(wid: String) -> void:
	if wid == weapon_id or not Weapons.DATA.has(wid):
		return
	ammo_state[weapon_id] = {"mag": ammo, "reserve": reserve}
	weapon_id = wid
	ammo = int(ammo_state[wid]["mag"])
	reserve = int(ammo_state[wid]["reserve"])
	reload_t = 0.0
	spray = 0.0
	switch_t = float(Weapons.get_data(wid)["switch"])
	fire_cd = maxf(fire_cd, switch_t)
	Game.rpc_fx.rpc("switch", id, global_position)


func _update_viewmodel() -> void:
	for wid in viewmodels:
		viewmodels[wid].visible = wid == weapon_id


func setup(id_: int, info: Dictionary) -> void:
	id = id_
	pname = str(info.get("name", "P%d" % id))
	team = int(info.get("team", 0))
	is_bot = bool(info.get("is_bot", false))
	glyph_index = int(info.get("glyph", 0))
	color = Palette.player_color(info)
	body_mat.albedo_color = color
	rig.build(color, Palette.glyph(glyph_index))
	tag.text = "%s %s" % [Palette.glyph(glyph_index), pname]
	tag.modulate = color
	name = "P%d" % id


func make_local() -> void:
	_local = true
	cam.current = true
	Style.add_outline(cam)
	body_mesh.visible = false
	rig.visible = false
	tag.visible = false
	viewmodel.visible = true
	if DisplayServer.get_name() != "headless" and Game.autopilot == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_local() -> bool:
	return _local


## While a dead teammate looks through this player's eyes, hide its own model and tag.
func set_spectated(on: bool) -> void:
	_spectated = on
	_apply_flags_visual()


func aim_dir() -> Vector3:
	return -(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)).z


func eye_position() -> Vector3:
	return global_position + Vector3(0, head.position.y, 0)


# ---------------------------------------------------------------- input (local)
func _unhandled_input(event: InputEvent) -> void:
	if not _local or Game.paused_local:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := Settings.mouse_sensitivity * (Player.ff_sens_mult() if ff_until > 0.0 else 1.0)
		yaw -= event.relative.x * sens
		pitch = clampf(pitch - event.relative.y * sens * (-1.0 if Settings.invert_y else 1.0), -1.45, 1.45)
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
	if Input.is_action_pressed("ads"):
		b |= BTN_ADS
	if Input.is_action_just_pressed("slot1"):
		b |= BTN_SLOT1
	if Input.is_action_just_pressed("slot2"):
		b |= BTN_SLOT2
	if Input.is_action_just_pressed("slot3"):
		b |= BTN_SLOT3
	if Input.is_action_just_pressed("slot4"):
		b |= BTN_SLOT4
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
	if rewind_t > 0.0:
		_step_rewind(delta, pressed)
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
	speed *= float(Weapons.get_data(weapon_id)["move_mult"])
	if carrying_core:
		speed = CARRY_SPEED
		sprinting = false
	var wish := Vector3(inp_move.x, 0.0, inp_move.y)
	if wish.length() > 1.0:
		wish = wish.normalized()
	wish = Basis(Vector3.UP, yaw) * wish
	var on_floor := is_on_floor()
	if on_floor and launch_t > 0.0 and velocity.y <= 0.0:
		launch_t = 0.0
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
	if launch_t > 0.0 and not on_floor:
		pass
	elif dash_t > 0.0:
		velocity.x = dash_dir.x * DASH_SPEED
		velocity.z = dash_dir.z * DASH_SPEED
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.x = move_toward(velocity.x, target.x, accel * delta)
		velocity.z = move_toward(velocity.z, target.z, accel * delta)
	_step_up(delta)
	move_and_slide()
	_weapon_logic(pressed, staggered)
	interact_held = (inp_buttons & BTN_INTERACT) != 0
	if (pressed & BTN_ECHO) != 0 and Game.match_server != null:
		Game.match_server.request_ability(self)
	recorder.push(_now(), global_position, yaw, pitch)
	if Game.map_def != null and global_position.y < Game.map_def.kill_y and Game.match_server != null:
		Game.match_server.on_out_of_bounds(self)


## Classic stair stepping: if the horizontal move is blocked, try the same move from up to
## STEP_HEIGHT higher and settle back onto the ledge.
func _step_up(delta: float) -> void:
	if is_on_floor():
		_floor_t = 0.0
	else:
		_floor_t += delta
		if _floor_t > 0.3 or velocity.y > 1.0:
			return
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	if horiz.length() < 0.5:
		return
	var motion := horiz * delta + horiz.normalized() * 0.05
	if not test_move(global_transform, motion):
		return
	var up := Vector3.UP * STEP_HEIGHT
	if test_move(global_transform, up):
		return
	var raised := global_transform.translated(up)
	if test_move(raised, motion):
		return
	var params := PhysicsTestMotionParameters3D.new()
	params.from = raised.translated(motion)
	params.motion = -up
	var res := PhysicsTestMotionResult3D.new()
	if PhysicsServer3D.body_test_motion(get_rid(), params, res):
		var step_h := STEP_HEIGHT - res.get_travel().length()
		if step_h > 0.02 and step_h <= STEP_HEIGHT:
			global_position.y += step_h + 0.02
			if velocity.y < 0.0:
				velocity.y = 0.0


## Reverse Entropy: the body re-traverses its recorded route backwards; look and fire stay free.
func start_rewind(now: float, seconds: float) -> void:
	rewind_total = seconds
	rewind_t = seconds
	rewind_start = now
	velocity = Vector3.ZERO
	dash_t = 0.0
	interact_held = false
	collision_mask = 1 | 2


func _step_rewind(delta: float, pressed: int) -> void:
	var elapsed := rewind_total - rewind_t
	var target_t := rewind_start - elapsed
	var s := recorder.sample_abs(target_t)
	global_position = s["pos"]
	body_yaw = s["yaw"]
	velocity = Vector3.ZERO
	rewind_t = maxf(0.0, rewind_t - delta)
	if Game.match_server != null:
		Game.match_server.on_rewind_pass(self, target_t)
	_weapon_logic(pressed, false)
	if rewind_t <= 0.0:
		collision_mask = 1 | 2 | TEMPORAL_LAYER
		_settle_after_rewind()
		if Game.match_server != null:
			Game.log_ev("Ability", "rewind_done", {"id": id, "pos": [snappedf(global_position.x, 0.1), snappedf(global_position.y, 0.1), snappedf(global_position.z, 0.1)]})


## If the historical point now intersects geometry, nudge upward so the body is never stuck.
func _settle_after_rewind() -> void:
	for i in 8:
		if not test_move(global_transform, Vector3(0, 0.01, 0)):
			return
		global_position.y += 0.3


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
	launch_t = maxf(0.0, launch_t - delta)
	switch_t = maxf(0.0, switch_t - delta)
	if spray_t > 0.0:
		spray_t -= delta
	else:
		spray = maxf(0.0, spray - delta * float(Weapons.get_data(weapon_id)["recover"]))
	if reload_t > 0.0:
		reload_t = maxf(0.0, reload_t - delta)
		if reload_t <= 0.0:
			var need := int(Weapons.get_data(weapon_id)["mag"]) - ammo
			var take := mini(need, reserve)
			ammo += take
			reserve -= take


func _start_reload() -> void:
	if reserve <= 0 or ammo >= int(Weapons.get_data(weapon_id)["mag"]):
		return
	reload_t = float(Weapons.get_data(weapon_id)["reload"])
	Game.rpc_fx.rpc("reload", id, global_position)


func _weapon_logic(pressed: int, staggered: bool) -> void:
	ads = (inp_buttons & BTN_ADS) != 0
	if (pressed & BTN_SLOT1) != 0:
		_switch_weapon("rifle")
	elif (pressed & BTN_SLOT2) != 0:
		_switch_weapon("shotgun")
	elif (pressed & BTN_SLOT3) != 0:
		_switch_weapon("sniper")
	elif (pressed & BTN_SLOT4) != 0:
		_switch_weapon("mg")
	var w := Weapons.get_data(weapon_id)
	if reload_t > 0.0 or switch_t > 0.0:
		return
	if (pressed & BTN_RELOAD) != 0 and ammo < int(w["mag"]) and reserve > 0:
		_start_reload()
		return
	var want_fire := (inp_buttons & BTN_FIRE) != 0 if bool(w["auto"]) else (pressed & BTN_FIRE) != 0
	if want_fire and fire_cd <= 0.0 and not staggered:
		if ammo > 0:
			_shoot()
		else:
			_start_reload()


func _cone(base: Vector3, half_angle: float) -> Vector3:
	if half_angle <= 0.0:
		return base
	var helper := Vector3.RIGHT if absf(base.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var up := base.cross(helper).normalized()
	var right := base.cross(up).normalized()
	var phi := randf() * TAU
	var r := half_angle * sqrt(randf())
	return (base + up * r * sin(phi) + right * r * cos(phi)).normalized()


func _shoot() -> void:
	var w := Weapons.get_data(weapon_id)
	ammo -= 1
	fire_cd = float(w["rof"])
	spawn_protect_t = 0.0
	var moving := Vector3(velocity.x, 0.0, velocity.z).length() > 1.0
	var sp := Weapons.spread(weapon_id, spray, moving, not is_on_floor(), crouching, ads)
	var kick := Weapons.recoil(weapon_id, int(spray))
	var from := eye_position()
	var base := aim_dir()
	for i in int(w["pellets"]):
		var dir := _cone(base, sp)
		Game.projectiles.fire(id, weapon_id, from + dir * 0.45, dir * float(w["velocity"]), float(w["damage"]), get_rid())
	spray += 1.0
	spray_t = 0.3
	pitch = clampf(pitch + kick.y, -1.45, 1.45)
	yaw = wrapf(yaw - kick.x, -PI, PI)
	if id > 1 and not is_bot:
		Game.rpc_recoil.rpc_id(id, -kick.x, kick.y)
	recorder.push_event(_now(), EchoBuffer.EVT_FIRE, yaw, pitch)
	Game.rpc_muzzle.rpc(id, weapon_id)
	Game.log_ev("Weapon", "fire", {"id": id, "weapon": weapon_id, "pellets": int(w["pellets"]), "spray": int(spray), "ads": ads})


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
	collision_mask = 1 | 2 | TEMPORAL_LAYER
	carrying_core = false
	interact_held = false
	zip_t = 0.0
	launch_t = 0.0
	rewind_t = 0.0
	recorder.clear()
	if Game.match_server != null:
		Game.match_server.on_player_died(self, killer_id, cause)


func respawn(pos: Vector3, yaw_: float, protect: float) -> void:
	hp = MAX_HP
	alive = true
	weapon_id = "rifle"
	_reset_ammo()
	_update_viewmodel()
	reload_t = 0.0
	switch_t = 0.0
	fire_cd = 0.0
	dash_cd = 0.0
	dash_t = 0.0
	stagger_t = 0.0
	zip_t = 0.0
	spawn_protect_t = protect
	frozen = false
	carrying_core = false
	rewind_t = 0.0
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
	if re_spent:
		f |= F_RE_SPENT
	if ff_spent:
		f |= F_FF_SPENT
	if rewind_t > 0.0:
		f |= F_REWIND
	if ff_until > 0.0 and Game.match_server != null and Game.match_server.match_time < ff_until:
		f |= F_FF
	if ads:
		f |= F_ADS
	flags = f
	return [id, global_position, yaw, pitch, hp, ammo, f, reload_t, dash_cd, echo_cd, stagger_t, spawn_protect_t, velocity, Weapons.ORDER.find(weapon_id), reserve]


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
	re_spent = (flags & F_RE_SPENT) != 0
	ff_spent = (flags & F_FF_SPENT) != 0
	rewind_t = 1.0 if (flags & F_REWIND) != 0 else 0.0
	ff_until = 1.0 if (flags & F_FF) != 0 else 0.0
	ads = (flags & F_ADS) != 0
	if s.size() > 14:
		var wid: String = Weapons.ORDER[clampi(int(s[13]), 0, Weapons.ORDER.size() - 1)]
		if wid != weapon_id:
			weapon_id = wid
			_update_viewmodel()
		reserve = int(s[14])
	if (old_flags & F_ALIVE) != (flags & F_ALIVE):
		_apply_flags_visual()
	if _net_prev.distance_to(_net_pos) > 6.0:
		_net_prev = _net_pos
		global_position = _net_pos


func _apply_flags_visual() -> void:
	body_mesh.visible = false
	rig.visible = alive and not _local and not _spectated
	tag.visible = alive and not _local and not _spectated
	shape.disabled = not alive


func _process(delta: float) -> void:
	_view_kick = lerpf(_view_kick, 0.0, 14.0 * delta)
	_animate_rig(delta)
	if _local:
		var local_ads := ads if multiplayer.is_server() else (Input.is_action_pressed("ads") and Game.autopilot == null and not Game.paused_local)
		_fov_target = float(Weapons.get_data(weapon_id)["ads_fov"]) if local_ads and alive else Settings.fov
		cam.fov = lerpf(cam.fov, _fov_target, minf(1.0, 12.0 * delta))
	if viewmodel.visible:
		viewmodel.position = Vector3(0.27, -0.23 - _view_kick * 0.02, -0.5 + _view_kick * 0.06)
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


func _animate_rig(delta: float) -> void:
	if rig == null or not rig.visible:
		return
	var hspeed := Vector3(velocity.x, 0.0, velocity.z).length()
	var floor_now := (flags & F_FLOOR) != 0 if not multiplayer.is_server() else is_on_floor()
	rig.animate(delta, hspeed, floor_now, crouching, head.rotation.x, rewind_t > 0.0)


func kick_view() -> void:
	_view_kick = 1.0


func apply_recoil(dyaw: float, dpitch: float) -> void:
	yaw = wrapf(yaw + dyaw, -PI, PI)
	pitch = clampf(pitch + dpitch, -1.45, 1.45)


static func ff_sens_mult() -> float:
	return 1.15
