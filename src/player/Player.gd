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
## Two-slot loadout: SLOT1/SLOT2 select the equipped weapons, PREV/NEXT are the mouse wheel (SLOT3/SLOT4 are unused).
const BTN_PREV := 8192
const BTN_NEXT := 16384
const BTN_DROP := 32768           # G: the Core carrier puts the Core down
const BTN_SABOTAGE := 65536       # F: defenders fire the selected sabotage
const BTN_SABO_SEL := 786432      # defenders: selected sabotage kind in two bits (18-19), sent every frame

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
## Seconds of protection after a respawn: the single source for every mode and every check below.
const RESPAWN_PROTECT := 3.0
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
var ladder_t := 0.0                 # > 0 while inside a ladder volume (set by Features.Ladder)
var interact_buffer_t := 0.0         # a tap of E stays 'held' for a moment so a short press still attaches (zipline)
var ladder_ignore_t := 0.0            # > 0 right after stepping off a ladder's foot (the volume cannot re-grab)
var ladder_base_y := 0.0           # floor height at the foot of the ladder the player is on
var ladder_out := Vector3.FORWARD
var ladder_top := 0.0
const CLIMB_SPEED := 4.2
var launch_t := 0.0
var rewind_t := 0.0
var rewind_total := 6.0
var rewind_start := 0.0
var body_yaw := 0.0
var re_spent := false
var ff_spent := false
var sabo_spent := false       # defender sabotage charge, reset every round (server)
var jam_until := 0.0          # Reverse Entropy is jammed until this match time (server)
var sabo_sel := 0             # defenders: selected sabotage kind, cycled with V (client), sent with every input
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
## Two equipped weapons (distinct ids from Weapons.ARMORY) and the active slot index; weapon_id == loadout[slot].
var loadout: Array = ["rifle", "deagle"]
var slot := 0
var cd_store: Dictionary = {}     # weapon id -> fire cooldown left while it is holstered (no swap-cancel of rate of fire)
var _wheel_hold := 0              # physics frames the wheel button bit stays set (survives a dropped unreliable input packet)
var _wheel_bit := 0
var _built := false
var viewmodels: Dictionary = {}
var _fov_target := 86.0
var brain = null
var shield: MeshInstance3D          # translucent teal respawn shield, other players' view only
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
var rig: TacticalRig
var fp_arms: FPArms
var _was_alive := true
var _death_vis_t := 0.0
var _was_reloading := false
var _sway := Vector2.ZERO
var _bob_t := 0.0
var _vm_base := Vector3(0.21, -0.19, -0.4)
const FP_BODY_OFFSET := Vector3(0.04, -1.56, 0.14)
const FP_GRIP_OFFSET := Vector3(-0.035, -0.015, 0.0)
var _step_dist := 0.0
var _was_floor := true
var _fall_speed := 0.0


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
	shield = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.05
	sm.height = 2.3
	sm.radial_segments = 28
	sm.rings = 14
	shield.mesh = sm
	var shm := ShaderMaterial.new()
	shm.shader = load("res://src/shaders/fx_bubble.gdshader")
	shm.set_shader_parameter("tint", Color("48E0C1"))
	shm.set_shader_parameter("fade", 0.55)
	shm.set_shader_parameter("body", 0.04)
	shield.material_override = shm
	shield.position = Vector3(0, 0.95, 0)
	shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shield.visible = false
	add_child(shield)
	rig = TacticalRig.new()
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
	viewmodel.position = _vm_base
	viewmodel.scale = Vector3.ONE
	viewmodel.visible = false
	cam.add_child(viewmodel)
	_build_viewmodel()
	_built = true
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
	# preferred: full first-person body from the character asset, weapons in the right hand
	fp_arms = FPArms.new()
	viewmodel.add_child(fp_arms)
	fp_arms.build(Color(0.42, 0.45, 0.52))
	if fp_arms.ok:
		fp_arms.position = FP_BODY_OFFSET
		_vm_base = Vector3.ZERO
		for wid in loadout:
			_ensure_viewmodel(wid)
		return
	fp_arms.queue_free()
	fp_arms = null
	for wid in loadout:
		_ensure_viewmodel(wid)


## Builds the first-person model for one weapon once (never duplicated); only equipped weapons are built.
func _ensure_viewmodel(wid: String) -> void:
	if viewmodels.has(wid) and is_instance_valid(viewmodels[wid]):
		return
	if _built and not _local:
		return   # other players never show a first-person model: their weapon is drawn on the rig
	if fp_arms != null and fp_arms.ok:
		var w := WeaponModels.build(wid)
		if w == null:
			return
		w.name = wid
		w.scale = Vector3.ONE * 0.32
		w.position = FP_GRIP_OFFSET
		w.visible = wid == weapon_id
		fp_arms.weapon_root.add_child(w)
		viewmodels[wid] = w
		return
	var sleeve := Style.surface("cloth", Color("3A4150"))
	var cuff := Style.surface("gear", Color("2B2E2B"))
	var glove := Style.surface("gear", Color("50473C"))
	var root := Node3D.new()
	root.name = wid
	var w2 := WeaponModels.build(wid)
	if w2 == null:
		return
	w2.scale = Vector3.ONE * 0.42
	root.add_child(w2)
	var length: float = float(w2.get_meta("length", 0.8)) * 0.42
	# right hand on the grip, forearm running back and down out of frame
	var grip := Vector3(0.0, -0.075, 0.06)
	_limb(root, grip + Vector3(0.0, -0.01, 0.02), grip + Vector3(0.12, -0.2, 0.42), 0.042, sleeve)
	_limb(root, grip + Vector3(0.0, -0.005, 0.02), grip + Vector3(0.02, -0.03, 0.1), 0.046, cuff)
	_hand(root, grip, glove)
	# support hand on the fore-end, forearm crossing in from the lower left
	var fore := Vector3(0.0, -0.05, -length * 0.38)
	_limb(root, fore + Vector3(-0.01, -0.02, 0.03), fore + Vector3(-0.24, -0.26, 0.4), 0.04, sleeve)
	_hand(root, fore, glove)
	root.visible = wid == weapon_id
	viewmodel.add_child(root)
	viewmodels[wid] = root


## Cylinder limb between two points in viewmodel space.
func _limb(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = a.distance_to(b) + radius * 2.0
	mi.mesh = cm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = (a + b) * 0.5
	var dir := (b - a).normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	mi.basis = Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, PI * 0.5)
	return mi


## Gloved hand wrapped around a grip: palm block, finger wrap and thumb.
func _hand(parent: Node3D, at: Vector3, mat: Material) -> void:
	var palm := _vm_box(parent, Vector3(0.05, 0.075, 0.07), at + Vector3(0.028, 0.0, 0.0), mat)
	palm.rotation_degrees.z = -8
	_vm_box(parent, Vector3(0.062, 0.05, 0.032), at + Vector3(-0.004, -0.012, -0.034), mat)
	_vm_box(parent, Vector3(0.02, 0.02, 0.06), at + Vector3(-0.028, 0.022, -0.012), mat)


## Full ammunition for every weapon and the primary slot selected. Called on every (re)spawn:
## a respawn or round start always refills both magazines and reserves and equips slot 1.
func _reset_ammo() -> void:
	ammo_state.clear()
	for wid in Weapons.ORDER:
		var w := Weapons.get_data(wid)
		ammo_state[wid] = {"mag": int(w["mag"]), "reserve": int(w["reserve"])}
	cd_store.clear()
	slot = 0
	weapon_id = str(loadout[0])
	ammo = int(ammo_state[weapon_id]["mag"])
	reserve = int(ammo_state[weapon_id]["reserve"])
	spray = 0.0


## Stores the active weapon's live counters and returns the full per-weapon table (current slot included).
func ammo_of(wid: String) -> Dictionary:
	if wid == weapon_id:
		return {"mag": ammo, "reserve": reserve}
	return ammo_state.get(wid, {"mag": 0, "reserve": 0})


## Server (and local bookkeeping): equip two distinct weapons. Invalid or duplicate picks are replaced by the
## default loadout. The weapon in hand stays in hand if it is still equipped; otherwise slot 1 is drawn.
## Magazines and reserves are untouched (a newly equipped weapon starts with whatever its table holds).
func set_loadout(picks: Array) -> void:
	var clean := Loadout.sanitize(picks)
	ammo_state[weapon_id] = {"mag": ammo, "reserve": reserve}
	var keep := weapon_id if clean.has(weapon_id) else str(clean[0])
	loadout = clean
	for wid in loadout:
		_ensure_viewmodel(wid)
	if keep != weapon_id:
		reload_t = 0.0
		weapon_id = keep
		ammo = int(ammo_state[keep]["mag"])
		reserve = int(ammo_state[keep]["reserve"])
		spray = 0.0
		fire_cd = 0.0
		switch_t = 0.0
	slot = loadout.find(weapon_id)
	_update_viewmodel()


## Slot index 0/1. Returns true if a switch started.
func switch_slot(i: int) -> bool:
	if i < 0 or i >= loadout.size():
		return false
	return _switch_weapon(str(loadout[i]))


func _switch_weapon(wid: String) -> bool:
	if wid == weapon_id or not Weapons.DATA.has(wid) or not loadout.has(wid):
		return false
	# the outgoing weapon keeps its magazine and reserve; an unfinished reload is cancelled, not completed
	ammo_state[weapon_id] = {"mag": ammo, "reserve": reserve}
	cd_store[weapon_id] = fire_cd
	weapon_id = wid
	slot = loadout.find(wid)
	ammo = int(ammo_state[wid]["mag"])
	reserve = int(ammo_state[wid]["reserve"])
	reload_t = 0.0
	_was_reloading = false
	if fp_arms != null:
		fp_arms.cancel_reload()
	spray = 0.0
	spray_t = 0.0
	ads = false
	switch_t = float(Weapons.get_data(wid)["switch"])
	fire_cd = maxf(float(cd_store.get(wid, 0.0)), switch_t)
	cd_store.erase(wid)
	_ensure_viewmodel(wid)
	_update_viewmodel()
	Game.rpc_fx.rpc("switch", id, global_position)
	return true


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
	if not _local or Game.paused_local or Game.armory_open:
		return
	if _wheel_hold <= 0 and event is InputEventMouseButton and event.pressed and _mouse_ok():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			wheel_input(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			wheel_input(1)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := Settings.mouse_sensitivity * (Player.ff_sens_mult() if ff_until > 0.0 else 1.0)
		yaw -= event.relative.x * sens
		pitch = clampf(pitch - event.relative.y * sens * (-1.0 if Settings.invert_y else 1.0), -1.45, 1.45)
		yaw = wrapf(yaw, -PI, PI)


## Mouse wheel: -1 (up) selects the previous slot, +1 (down) the next; with two slots both cycle to the other weapon.
## The request travels as a button bit that is held a few physics frames so one dropped packet cannot lose it.
func wheel_input(dir: int) -> void:
	_wheel_bit = BTN_NEXT if dir > 0 else BTN_PREV
	_wheel_hold = 4


## Mouse captured (headless peers have no mouse and are treated as captured so scripted tests drive the real path).
func _mouse_ok() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless"


func gather_input() -> Array:
	if Game.autopilot != null:
		return Game.autopilot.produce(self)
	if Game.paused_local or Game.armory_open or not _mouse_ok():
		_wheel_hold = 0
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
	if _wheel_hold > 0:
		_wheel_hold -= 1
		b |= _wheel_bit
	if Input.is_action_pressed("drop_core"):
		b |= BTN_DROP
	if Input.is_action_just_pressed("sabo_cycle"):
		sabo_sel = SabotageRules.next_kind(sabo_sel)
	if Input.is_action_pressed("sabotage"):
		b |= BTN_SABOTAGE
	b |= sabo_sel << 18
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
	if (pressed & BTN_INTERACT) != 0:
		interact_buffer_t = 0.35
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
	if ladder_t > 0.0 and not carrying_core:
		_step_ladder(delta, pressed)
		return
	if has_meta("ladder_topped"):
		remove_meta("ladder_topped")
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
	if (pressed & BTN_DROP) != 0 and carrying_core and Game.match_server != null and Game.match_server.rules != null and Game.match_server.rules.has_method("request_drop"):
		Game.match_server.rules.request_drop(self)
	if (pressed & BTN_SABOTAGE) != 0 and Game.match_server != null:
		Game.match_server.request_sabotage(self, (inp_buttons & BTN_SABO_SEL) >> 18)
	recorder.push(_now(), global_position, yaw, pitch)
	if Game.map_def != null and global_position.y < Game.map_def.kill_y and Game.match_server != null:
		Game.match_server.on_out_of_bounds(self)


## Ladder climbing: forward (toward the wall) climbs, backward descends, sideways shuffles, jump
## pushes off. Near the top the climber is pushed over the lip onto the platform. Carrying the Core
## disables climbing (two hands on the Core), which keeps carrier routes on stairs and ramps.
func _step_ladder(delta: float, pressed: int) -> void:
	ladder_t -= delta
	var wish := Basis(Vector3.UP, yaw) * Vector3(inp_move.x, 0.0, inp_move.y)
	var toward := wish.dot(-ladder_out)
	if toward < -0.25 and is_on_floor() and global_position.y < ladder_base_y + 0.45:
		# at the foot and still walking away: step off instead of being held on the ladder volume
		ladder_t = 0.0
		ladder_ignore_t = 0.5
		return
	if (pressed & BTN_JUMP) != 0:
		velocity = ladder_out * 5.0 + Vector3.UP * 3.5
		ladder_t = 0.0
		move_and_slide()
		return
	if toward > 0.25:
		velocity.y = CLIMB_SPEED
	elif toward < -0.25:
		velocity.y = -CLIMB_SPEED
	else:
		velocity.y = 0.0
	var side := wish - (-ladder_out) * toward
	velocity.x = side.x * 2.0
	velocity.z = side.z * 2.0
	if global_position.y > ladder_top - 0.15 and toward > 0.25:
		if velocity.y > 0.0 and not has_meta("ladder_topped"):
			set_meta("ladder_topped", true)
			Game.log_ev("Feature", "ladder_top", {"id": id, "y": snappedf(global_position.y, 0.1)})
		velocity += -ladder_out * 3.5
		velocity.y = 1.5   # assigned, not max'd: the 4.2 climb speed used to carry the climber 2.4 m above the platform
	move_and_slide()
	_weapon_logic(pressed, false)
	interact_held = (inp_buttons & BTN_INTERACT) != 0
	recorder.push(_now(), global_position, yaw, pitch)


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
	ladder_ignore_t = maxf(0.0, ladder_ignore_t - delta)
	interact_buffer_t = maxf(0.0, interact_buffer_t - delta)
	launch_t = maxf(0.0, launch_t - delta)
	switch_t = maxf(0.0, switch_t - delta)
	for k in cd_store.keys():
		cd_store[k] = maxf(0.0, float(cd_store[k]) - delta)
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
	if (pressed & BTN_SLOT1) != 0:
		switch_slot(0)
	elif (pressed & BTN_SLOT2) != 0:
		switch_slot(1)
	elif (pressed & BTN_PREV) != 0:
		switch_slot(posmod(slot - 1, loadout.size()))
	elif (pressed & BTN_NEXT) != 0:
		switch_slot(posmod(slot + 1, loadout.size()))
	ads = (inp_buttons & BTN_ADS) != 0 and switch_t <= 0.0
	var w := Weapons.get_data(weapon_id)
	if reload_t > 0.0 or switch_t > 0.0:
		return
	if (pressed & BTN_RELOAD) != 0 and ammo < int(w["mag"]) and reserve > 0:
		_start_reload()
		return
	var want_fire := (inp_buttons & BTN_FIRE) != 0 if bool(w["auto"]) else (pressed & BTN_FIRE) != 0
	if want_fire and fire_cd <= 0.0 and not staggered and can_deal_damage():
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
## Central protection rules (respawn shield). Every damage, weapon and objective path asks these.
func is_protected() -> bool:
	return alive and spawn_protect_t > 0.0


func can_deal_damage() -> bool:
	return alive and not is_protected()


func can_progress_objective() -> bool:
	return alive and not frozen and not is_protected()


func apply_damage(amount: float, from_id: int, cause: String, min_hp: float) -> bool:
	if not alive or is_protected() or frozen:
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
	spawn_protect_t = 0.0
	recorder.clear()
	Game.rpc_fx.rpc("death", id, global_position)
	if Game.match_server != null:
		Game.match_server.on_player_died(self, killer_id, cause)


func respawn(pos: Vector3, yaw_: float, protect: float) -> void:
	hp = MAX_HP
	alive = true
	_reset_ammo()   # keeps the loadout, refills both weapons, equips slot 1
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
	if brain != null and brain.has_method("on_respawn"):
		brain.on_respawn()
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
	return [id, global_position, yaw, pitch, hp, ammo, f, reload_t, dash_cd, echo_cd, stagger_t, spawn_protect_t, velocity, Weapons.ORDER.find(weapon_id), reserve,
		Weapons.ORDER.find(str(loadout[0])), Weapons.ORDER.find(str(loadout[1])), int(ammo_of(str(loadout[1 - slot]))["mag"]), int(ammo_of(str(loadout[1 - slot]))["reserve"])]


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
		if s.size() > 18:
			var l0: String = Weapons.ORDER[clampi(int(s[15]), 0, Weapons.ORDER.size() - 1)]
			var l1: String = Weapons.ORDER[clampi(int(s[16]), 0, Weapons.ORDER.size() - 1)]
			if str(loadout[0]) != l0 or str(loadout[1]) != l1:
				loadout = [l0, l1]
				for lw in loadout:
					_ensure_viewmodel(lw)
				if Game.args.has("log-snap"):
					Game.log_ev("Armory", "loadout_seen", {"id": id, "loadout": loadout})
		if wid != weapon_id:
			weapon_id = wid
			_ensure_viewmodel(wid)
			_update_viewmodel()
		slot = maxi(0, loadout.find(weapon_id))
		reserve = int(s[14])
		if s.size() > 18:
			ammo_state[str(loadout[1 - slot])] = {"mag": int(s[17]), "reserve": int(s[18])}
	if (old_flags & F_ALIVE) != (flags & F_ALIVE):
		_apply_flags_visual()
	if _net_prev.distance_to(_net_pos) > 6.0:
		_net_prev = _net_pos
		global_position = _net_pos


func _apply_flags_visual() -> void:
	body_mesh.visible = false
	rig.visible = (alive or _death_vis_t > 0.0) and not _local and not _spectated
	tag.visible = alive and not _local and not _spectated
	shape.disabled = not alive


func _process(delta: float) -> void:
	_view_kick = lerpf(_view_kick, 0.0, 14.0 * delta)
	_animate_rig(delta)
	if _local:
		var local_ads := ads if multiplayer.is_server() else (Input.is_action_pressed("ads") and Game.autopilot == null and not Game.paused_local)
		_fov_target = float(Weapons.get_data(weapon_id)["ads_fov"]) if local_ads and alive else Settings.fov
		cam.fov = lerpf(cam.fov, _fov_target, minf(1.0, 12.0 * delta))
		# camera shake: a small jitter that follows the firing kick, scaled by the CAMERA SHAKE setting
		var shake_amt := _view_kick * Settings.shake * (0.35 if local_ads else 1.0) if alive else 0.0
		cam.h_offset = randf_range(-1.0, 1.0) * 0.012 * shake_amt
		cam.v_offset = randf_range(-1.0, 1.0) * 0.012 * shake_amt
	_update_life_visuals(delta)
	_update_footsteps(delta)
	if viewmodel.visible:
		_animate_viewmodel(delta)
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


## Death clip, revive, reload and weapon visuals for the third-person rig (server and clients alike).
func _update_life_visuals(delta: float) -> void:
	if not multiplayer.is_server() and spawn_protect_t > 0.0:
		spawn_protect_t = maxf(0.0, spawn_protect_t - delta)   # smooth countdown between snapshots
	shield.visible = is_protected() and not _local and not _spectated
	if alive != _was_alive:
		_was_alive = alive
		if not alive:
			rig.die()
			_death_vis_t = 1.8
		else:
			rig.revive()
			_death_vis_t = 0.0
		_apply_flags_visual()
	if _death_vis_t > 0.0:
		_death_vis_t -= delta
		if _death_vis_t <= 0.0:
			_apply_flags_visual()
	var reloading := reload_t > 0.0
	if reloading and not _was_reloading:
		rig.reload()
		if fp_arms != null and _local:
			fp_arms.play_reload()
	_was_reloading = reloading
	rig.set_weapon(weapon_id)


## First-person weapon motion: mouse sway, walk/run bob, fire kick, reload dip with magazine drop.
func _animate_viewmodel(delta: float) -> void:
	var cur_vm: Node3D = viewmodels.get(weapon_id)
	if cur_vm != null and not cur_vm.visible:
		_update_viewmodel()
	var hspeed := Vector3(velocity.x, 0.0, velocity.z).length()
	var on_ground := is_on_floor() if multiplayer.is_server() else (flags & F_FLOOR) != 0
	var bob_amt := clampf(hspeed / 8.6, 0.0, 1.0) * (1.0 if on_ground else 0.2) * (0.35 if ads else 1.0)
	_bob_t += delta * (6.0 + hspeed * 0.9)
	var bob := Vector3(sin(_bob_t) * 0.012, -absf(cos(_bob_t)) * 0.014, 0.0) * bob_amt * (1.0 if Settings.head_bob else 0.0)
	var look := Vector2(yaw, pitch)
	var dl := look - _sway
	dl.x = wrapf(dl.x, -PI, PI)
	_sway = _sway.lerp(look, minf(1.0, delta * 10.0))
	var sway := Vector3(clampf(-dl.x * 0.25, -0.04, 0.04), clampf(dl.y * 0.25, -0.03, 0.03), 0.0)
	var idle := Vector3(0.0, sin(Time.get_ticks_msec() * 0.0015) * 0.003, 0.0)
	var base := (Vector3(0.0, -0.13, -0.3) if fp_arms == null else Vector3(-0.07, 0.03, 0.04)) if ads else _vm_base
	var rl := 0.0
	var rtime := float(Weapons.get_data(weapon_id)["reload"])
	if reload_t > 0.0 and rtime > 0.0:
		var f := 1.0 - reload_t / rtime
		rl = sin(clampf(f, 0.0, 1.0) * PI)
	var target := base + bob + sway + idle + Vector3(0, -_view_kick * 0.02 - rl * 0.08, _view_kick * 0.05)
	viewmodel.position = viewmodel.position.lerp(target, minf(1.0, delta * 18.0))
	viewmodel.rotation = Vector3(_view_kick * 0.1 + rl * 0.35, sway.x * 2.0, rl * 0.5 + sway.x * 1.5)
	var cur: Node3D = viewmodels.get(weapon_id)
	if cur != null:
		var mag := cur.find_child("Mag", true, false) as Node3D
		if mag != null:
			if not mag.has_meta("rest"):
				mag.set_meta("rest", mag.position)
			mag.position = (mag.get_meta("rest") as Vector3) + Vector3(0, -0.25 * rl, 0)
	if switch_t > 0.0:
		viewmodel.position.y -= switch_t * 0.4


## Footsteps by surface, landing thuds. Runs on every peer for every visible player.
func _update_footsteps(delta: float) -> void:
	if not alive or DisplayServer.get_name() == "headless":
		return
	var on_ground := is_on_floor() if multiplayer.is_server() else (flags & F_FLOOR) != 0
	var hv := Vector3(velocity.x, 0.0, velocity.z).length()
	if on_ground and not _was_floor and _fall_speed > 6.0:
		Sfx.play_at("land", global_position, -6.0 if _local else -2.0)
	_was_floor = on_ground
	_fall_speed = maxf(0.0, -velocity.y) if not on_ground else 0.0
	if not on_ground or hv < 1.0 or crouching:
		return
	_step_dist += hv * delta
	var stride := 2.6 if hv > 7.0 else 2.1
	if _step_dist >= stride:
		_step_dist = 0.0
		Sfx.play_at(surface_sound(), global_position, (-14.0 if _local else -4.0) + (2.0 if hv > 7.0 else 0.0))


## Surface family under the player: metal on raised decks and gantries of the industrial maps,
## stone everywhere on Oracle Gardens, concrete otherwise.
func surface_sound() -> String:
	var fam: String = Game.map_def.family if Game.map_def != null else "oracle"
	if fam != "oracle" and global_position.y > 2.0:
		return "step_metal"
	return "step_stone"


## Brass case ejected from the first-person weapon: short arc to the right, spinning, then freed.
func eject_shell() -> void:
	if not _local or not viewmodel.visible or weapon_id == "shotgun":
		return
	var shell := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.006
	cm.bottom_radius = 0.006
	cm.height = 0.024
	cm.radial_segments = 6
	shell.mesh = cm
	shell.material_override = Style.surface("metal", Palette.BRASS)
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cam.add_child(shell)
	var start := viewmodel.position + Vector3(0.02, 0.06, -0.12)
	shell.position = start
	shell.rotation = Vector3(randf() * TAU, 0, PI * 0.5)
	var tw := create_tween()
	tw.set_parallel(true)
	var side := Vector3(randf_range(0.18, 0.26), 0.0, randf_range(0.02, 0.08))
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(shell):
			shell.position = start + side * t + Vector3(0, 0.14 * t - 0.5 * t * t, 0)
			shell.rotate_x(0.5), 0.0, 1.0, 0.5)
	tw.chain().tween_callback(shell.queue_free)


## World-space muzzle position for flashes: the real barrel tip for the local viewmodel.
func muzzle_position() -> Vector3:
	if _local and viewmodel.visible:
		var cur: Node3D = viewmodels.get(weapon_id)
		if cur != null:
			var m := cur.find_child("Muzzle", true, false) as Node3D
			if m != null:
				return m.global_position
	return eye_position() + aim_dir() * 0.8


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
