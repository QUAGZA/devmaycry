class_name ProjectileManager
extends Node
## Unified authoritative shot model. Every projectile has an id, owner, origin, timestamp, velocity,
## damage, lifetime and an acceleration flag. The server sweeps each projectile with a ray every physics
## tick (continuous collision, no tunnelling) and resolves damage exactly once. Clients mirror the
## kinematics for presentation and remove projectiles on the replicated hit/expire events.

const GRAVITY := 3.5
const MAX_LIFE := 2.2
const MASK := 1 | 2 | 4 | 32

var next_id := 1
var live: Dictionary = {}       # id -> projectile dict (server: authoritative; clients: visuals)
var visuals: Dictionary = {}    # id -> MeshInstance3D
var _mats: Dictionary = {}


func clear() -> void:
	for id in visuals.keys():
		if is_instance_valid(visuals[id]):
			visuals[id].queue_free()
	visuals.clear()
	live.clear()


## Server: spawn one projectile. Returns its id.
func fire(owner_id: int, weapon: String, origin: Vector3, velocity: Vector3, damage: float, exclude: RID) -> int:
	var id := next_id
	next_id += 1
	var t: float = Game.match_server.match_time if Game.match_server != null else 0.0
	live[id] = {"id": id, "owner": owner_id, "weapon": weapon, "pos": origin, "origin": origin, "vel": velocity, "damage": damage, "life": MAX_LIFE, "t": t, "accelerated": false, "exclude": exclude}
	Game.rpc_projectile_spawn.rpc(id, origin, velocity, weapon)
	_make_visual(id, origin, velocity, weapon)
	return id


func _physics_process(delta: float) -> void:
	if Game.world == null:
		return
	if multiplayer.is_server():
		_server_step(delta)
	else:
		_client_step(delta)


func _ff_covers(pos: Vector3) -> bool:
	if Game.match_server != null and Game.match_server.rules != null and Game.match_server.rules.has_method("ff_covers"):
		return Game.match_server.rules.ff_covers(pos)
	var ff: Dictionary = Game.live.get("ff", {})
	return bool(ff.get("active", false)) and pos.distance_to(ff.get("pos", Vector3.ZERO)) <= 8.0


func _server_step(delta: float) -> void:
	var space := Game.world.get_world_3d().direct_space_state
	for id in live.keys():
		var p: Dictionary = live[id]
		if not p["accelerated"] and _ff_covers(p["pos"]):
			p["vel"] = Vector3(p["vel"]) * HotReturnRules.FF_PROJECTILE_MULT
			p["accelerated"] = true
			Game.rpc_projectile_accel.rpc(id, HotReturnRules.FF_PROJECTILE_MULT)
			Game.log_ev("Weapon", "accelerated", {"id": id, "owner": p["owner"]})
		var from: Vector3 = p["pos"]
		var vel: Vector3 = p["vel"]
		var to := from + vel * delta
		var q := PhysicsRayQueryParameters3D.create(from, to, MASK, [p["exclude"]])
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			var col = hit["collider"]
			var hit_id := 0
			var dist: float = Vector3(p["origin"]).distance_to(hit["position"])
			var dmg: float = Weapons.damage_at(p["weapon"], dist)
			if col is Player:
				hit_id = col.id
				if col.apply_damage(dmg, p["owner"], p["weapon"], 0.0):
					Game.log_ev("Weapon", "hit", {"id": id, "owner": p["owner"], "victim": col.id, "weapon": p["weapon"], "dmg": snappedf(dmg, 0.1), "accel": p["accelerated"], "dist": snappedf(dist, 0.1)})
			elif col != null:
				var target = col if col.has_method("hit_by_shot") else col.get_parent()
				if target != null and target.has_method("apply_damage") and not (target is Player):
					target.apply_damage(dmg)
				elif target != null and target.has_method("hit_by_shot"):
					target.hit_by_shot(p["owner"])
					hit_id = -9999
			Game.rpc_projectile_hit.rpc(id, hit["position"], hit_id)
			_remove(id)
			continue
		vel.y -= GRAVITY * delta
		p["vel"] = vel
		p["pos"] = to
		p["life"] = float(p["life"]) - delta
		_move_visual(id, to, vel)
		if float(p["life"]) <= 0.0 or to.y < -30.0:
			Game.rpc_projectile_hit.rpc(id, to, 0)
			_remove(id)


func _client_step(delta: float) -> void:
	for id in live.keys():
		var p: Dictionary = live[id]
		if not p["accelerated"] and _ff_covers(p["pos"]):
			p["vel"] = Vector3(p["vel"]) * HotReturnRules.FF_PROJECTILE_MULT
			p["accelerated"] = true
		var vel: Vector3 = p["vel"]
		var to: Vector3 = Vector3(p["pos"]) + vel * delta
		vel.y -= GRAVITY * delta
		p["vel"] = vel
		p["pos"] = to
		p["life"] = float(p["life"]) - delta
		_move_visual(id, to, vel)
		if float(p["life"]) <= 0.0:
			_remove(id)


# ---------------------------------------------------------------- replicated events (all peers)
func on_spawn(id: int, origin: Vector3, velocity: Vector3, weapon: String) -> void:
	if multiplayer.is_server():
		return
	live[id] = {"id": id, "owner": 0, "weapon": weapon, "pos": origin, "origin": origin, "vel": velocity, "damage": 0.0, "life": MAX_LIFE, "accelerated": false}
	_make_visual(id, origin, velocity, weapon)


func on_accel(id: int, factor: float) -> void:
	if multiplayer.is_server():
		return
	if live.has(id) and not live[id]["accelerated"]:
		live[id]["vel"] = Vector3(live[id]["vel"]) * factor
		live[id]["accelerated"] = true


func on_hit(id: int, pos: Vector3, hit_id: int) -> void:
	if live.has(id):
		var w: String = live[id]["weapon"]
		Game.shot_fx.emit(0, pos, pos, hit_id)
		if hit_id != 0:
			Game.fx.emit("impact_player" if hit_id > -9999 else "impact", 0, pos)
		else:
			Game.fx.emit("impact", 0, pos)
	if not multiplayer.is_server():
		_remove(id)
	elif visuals.has(id):
		_remove_visual(id)


# ---------------------------------------------------------------- visuals
func _mat(weapon: String) -> StandardMaterial3D:
	if _mats.has(weapon):
		return _mats[weapon]
	var col := Color(str(Weapons.get_data(weapon)["color"]))
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 3.5
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[weapon] = m
	return m


func _make_visual(id: int, origin: Vector3, velocity: Vector3, weapon: String) -> void:
	if DisplayServer.get_name() == "headless" or Game.world == null:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var len := 0.9 if weapon == "sniper" else (0.35 if weapon == "shotgun" else 0.6)
	bm.size = Vector3(0.05, 0.05, len)
	mi.mesh = bm
	mi.material_override = _mat(weapon)
	Game.world.get_node("Fx").add_child(mi)
	mi.global_position = origin
	if velocity.length() > 0.01:
		mi.look_at(origin + velocity, Vector3.UP if absf(velocity.normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT)
	visuals[id] = mi


func _move_visual(id: int, pos: Vector3, vel: Vector3) -> void:
	var mi = visuals.get(id)
	if mi == null or not is_instance_valid(mi):
		return
	mi.global_position = pos
	if vel.length() > 0.01:
		mi.look_at(pos + vel, Vector3.UP if absf(vel.normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT)


func _remove_visual(id: int) -> void:
	var mi = visuals.get(id)
	if mi != null and is_instance_valid(mi):
		mi.queue_free()
	visuals.erase(id)


func _remove(id: int) -> void:
	live.erase(id)
	_remove_visual(id)
