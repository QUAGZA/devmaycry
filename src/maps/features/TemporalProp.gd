class_name TemporalProp
extends StaticBody3D
## Tagged breakable prop (porcelain barricade, brittle crate, shutter panel). Keeps versioned state events so
## a Reverse Entropy player passing its historical moment can restore it as short-lived temporal cover.
## The server owns state; every peer mirrors it through Game.rpc_prop_state.

const HP_MAX := 60.0
const COVER_SECONDS := 2.0
const TEMPORAL_LAYER := 32

var prop_id := 0
var hp := HP_MAX
var state := "intact"
var version := 0
var destroyed_at := -1.0
var restored_until := 0.0
var size := Vector3(2.4, 1.6, 0.6)
var color := Palette.PORCELAIN
var mesh: MeshInstance3D
var shape: CollisionShape3D
var fragments: Array = []
var mat: StandardMaterial3D
var temporal_mat: StandardMaterial3D
var _anim_t := 0.0
var _anim_dir := 0


func setup(id: int, pos: Vector3, size_: Vector3, yaw_deg: float, color_: Color) -> void:
	prop_id = id
	size = size_
	color = color_
	name = "TemporalProp%d" % id
	position = pos + Vector3(0, size.y * 0.5, 0)
	rotation_degrees.y = yaw_deg
	collision_layer = 1
	collision_mask = 0
	add_to_group("navgeo")
	shape = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	add_child(shape)
	mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mesh.material_override = mat
	add_child(mesh)
	temporal_mat = StandardMaterial3D.new()
	temporal_mat.albedo_color = Color(Palette.COBALT, 0.55)
	temporal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	temporal_mat.emission_enabled = true
	temporal_mat.emission = Palette.MINT
	temporal_mat.emission_energy_multiplier = 1.6
	# fragments: eight shards that fly apart on destruction and travel back on restoration
	var rng := RandomNumberGenerator.new()
	rng.seed = id * 7919
	for i in 8:
		var f := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(size.x * 0.28, size.y * 0.3, size.z * 0.9)
		f.mesh = fm
		f.material_override = mat
		var home := Vector3(-size.x * 0.36 + (i % 4) * size.x * 0.24, -size.y * 0.2 + (i / 4) * size.y * 0.45, 0)
		f.position = home
		f.visible = false
		add_child(f)
		var out := home + Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(0.2, 1.2), rng.randf_range(-1.6, 1.6))
		out.y = maxf(out.y, -size.y * 0.5 + 0.12)
		fragments.append({"node": f, "home": home, "out": out, "spin": Vector3(rng.randf_range(-3, 3), rng.randf_range(-3, 3), rng.randf_range(-3, 3))})
	var tag := Label3D.new()
	tag.text = "TEMPORAL"
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0, size.y * 0.5 + 0.5, 0)
	tag.font_size = 28
	tag.pixel_size = 0.006
	tag.outline_size = 6
	tag.modulate = Palette.MINT
	add_child(tag)


# ---------------------------------------------------------------- server
func hit_by_shot(_shooter_id: int) -> void:
	apply_damage(32.0)


func apply_damage(amount: float) -> void:
	if not multiplayer.is_server() or state != "intact":
		return
	hp -= amount
	Game.rpc_fx.rpc("impact", prop_id, global_position)
	if hp <= 0.0:
		destroy()


func destroy() -> void:
	if not multiplayer.is_server():
		return
	var now: float = Game.match_server.match_time if Game.match_server != null else 0.0
	version += 1
	Game.rpc_prop_state.rpc(prop_id, "destroyed", version, now)
	Game.log_ev("Prop", "destroyed", {"id": prop_id, "mt": snappedf(now, 0.01), "version": version})


## Called by the server when a rewinding player's historical moment predates this prop's destruction.
func restore_temporal(now: float) -> bool:
	if not multiplayer.is_server() or state != "destroyed":
		return false
	version += 1
	Game.rpc_prop_state.rpc(prop_id, "restored", version, now + COVER_SECONDS)
	Game.log_ev("Prop", "restored", {"id": prop_id, "mt": snappedf(now, 0.01), "version": version, "until": snappedf(now + COVER_SECONDS, 0.01)})
	return true


func _physics_process(delta: float) -> void:
	_animate(delta)
	if not multiplayer.is_server() or state != "restored":
		return
	var now: float = Game.match_server.match_time if Game.match_server != null else 0.0
	if now >= restored_until:
		version += 1
		Game.rpc_prop_state.rpc(prop_id, "destroyed", version, now)
		Game.log_ev("Prop", "cover_expired", {"id": prop_id, "version": version})


func reset_round() -> void:
	if not multiplayer.is_server():
		return
	hp = HP_MAX
	version += 1
	Game.rpc_prop_state.rpc(prop_id, "intact", version, 0.0)


# ---------------------------------------------------------------- every peer
func apply_state(new_state: String, new_version: int, t: float) -> void:
	if new_version < version and new_state != "intact":
		return
	version = new_version
	var old := state
	state = new_state
	match state:
		"intact":
			hp = HP_MAX
			destroyed_at = -1.0
			collision_layer = 1
			mesh.visible = true
			mesh.material_override = mat
			for f in fragments:
				f["node"].visible = false
				f["node"].position = f["home"]
			_anim_dir = 0
		"destroyed":
			if old == "intact":
				destroyed_at = t
			collision_layer = 0
			mesh.visible = false
			for f in fragments:
				f["node"].visible = true
			_anim_dir = 1
			_anim_t = 0.0 if old != "restored" else 0.0
			Sfx.play("elim", -12.0, 1.4)
		"restored":
			restored_until = t
			collision_layer = TEMPORAL_LAYER
			mesh.visible = true
			mesh.material_override = temporal_mat
			for f in fragments:
				f["node"].visible = true
			_anim_dir = -1
			_anim_t = 0.0
			Sfx.play("echo_materialize", -6.0)
			Game.fx.emit("restore", prop_id, global_position)


func _animate(delta: float) -> void:
	if _anim_dir == 0:
		return
	_anim_t = minf(1.0, _anim_t + delta / 0.55)
	var k := _anim_t if _anim_dir > 0 else 1.0 - _anim_t
	k = k * k * (3.0 - 2.0 * k)
	for f in fragments:
		var n: MeshInstance3D = f["node"]
		n.position = Vector3(f["home"]).lerp(f["out"], k)
		n.rotation = Vector3(f["spin"]) * k
	if _anim_t >= 1.0:
		if _anim_dir < 0:
			for f in fragments:
				f["node"].visible = false
			mesh.scale = Vector3.ONE * 1.04
		_anim_dir = 0
	if state == "restored":
		mesh.scale = mesh.scale.lerp(Vector3.ONE, 6.0 * delta)
