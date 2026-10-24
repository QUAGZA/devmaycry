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
## Reverse Entropy shot retrieval (server): bounded per-owner history of fired projectiles.
## record = {id, owner, weapon, origin, vel, t, samples, damaged, done, retrieved, replay}
const HISTORY_MAX := 12
const HISTORY_SAMPLES := 40
const RETRIEVE_WINDOW := 8.0
const RETRIEVE_TIME := 0.8
const RETRIEVABLE := ["rifle", "sniper", "mg"]
var history: Dictionary = {}    # owner -> Array[record]
var records: Dictionary = {}    # projectile id -> record (same dicts as in history)
var pending_replays: Array = [] # [{owner, record, at}]
var retrievals: Array = []      # client visuals: [{node, line, mesh, pts, t, dur, owner}]
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
	var shooter = Game.players.get(owner_id)
	if shooter != null and is_instance_valid(shooter) and not shooter.can_deal_damage():
		return 0   # a protected player deals no damage by any weapon path
	var id := next_id
	next_id += 1
	var t: float = Game.match_server.match_time if Game.match_server != null else 0.0
	live[id] = {"id": id, "owner": owner_id, "weapon": weapon, "pos": origin, "origin": origin, "vel": velocity, "damage": damage, "life": MAX_LIFE, "t": t, "accelerated": false, "exclude": exclude, "replay": false, "tick": 0}
	Game.rpc_projectile_spawn.rpc(id, origin, velocity, weapon)
	_make_visual(id, origin, velocity, weapon)
	if RETRIEVABLE.has(weapon):
		var rec := {"id": id, "owner": owner_id, "weapon": weapon, "origin": origin, "vel": velocity, "t": t, "samples": PackedVector3Array([origin]), "damaged": false, "done": false, "retrieved": false}
		records[id] = rec
		var h: Array = history.get(owner_id, [])
		h.append(rec)
		while h.size() > HISTORY_MAX:
			records.erase(int(h[0]["id"]))
			h.pop_front()
		history[owner_id] = h
	return id


## Reverse Entropy: pick the owner's most recent eligible shot (own, missed, finished, recent, not yet
## retrieved), animate it back to the muzzle on every peer, then re-fire it once from the muzzle along
## its recorded direction. Returns the retrieved shot id or 0.
func retrieve_for(p: Player) -> int:
	if not multiplayer.is_server() or p == null:
		return 0
	var now: float = Game.match_server.match_time if Game.match_server != null else 0.0
	var h: Array = history.get(p.id, [])
	for i in range(h.size() - 1, -1, -1):
		var rec: Dictionary = h[i]
		if rec["retrieved"] or rec["damaged"] or not rec["done"] or now - float(rec["t"]) > RETRIEVE_WINDOW:
			continue
		rec["retrieved"] = true
		var pts: PackedVector3Array = rec["samples"]
		var back := PackedVector3Array()
		for k in range(pts.size() - 1, -1, -1):
			back.append(pts[k])
		Game.rpc_shot_retrieve.rpc(p.id, back, RETRIEVE_TIME)
		pending_replays.append({"owner": p.id, "record": rec, "at": now + RETRIEVE_TIME})
		Game.log_ev("Weapon", "shot_retrieved", {"shot": rec["id"], "owner": p.id, "weapon": rec["weapon"], "age": snappedf(now - float(rec["t"]), 0.01), "samples": pts.size()})
		return int(rec["id"])
	Game.log_ev("Weapon", "shot_retrieve_none", {"owner": p.id, "history": h.size()})
	return 0


func _server_replays() -> void:
	var now: float = Game.match_server.match_time if Game.match_server != null else 0.0
	for r in pending_replays.duplicate():
		if now < float(r["at"]):
			continue
		pending_replays.erase(r)
		var owner: Player = Game.players.get(int(r["owner"]))
		if owner == null or not is_instance_valid(owner) or not owner.can_deal_damage():
			Game.log_ev("Weapon", "replay_cancelled", {"shot": r["record"]["id"], "owner": r["owner"]})
			continue
		var rec: Dictionary = r["record"]
		var vel: Vector3 = rec["vel"]
		var muzzle := owner.eye_position() + vel.normalized() * 0.6
		var dmg := float(Weapons.get_data(str(rec["weapon"]))["damage"])
		var id := next_id
		next_id += 1
		live[id] = {"id": id, "owner": owner.id, "weapon": rec["weapon"], "pos": muzzle, "origin": muzzle, "vel": vel, "damage": dmg, "life": MAX_LIFE, "t": now, "accelerated": false, "exclude": owner.get_rid(), "replay": true, "replay_of": rec["id"], "tick": 0}
		Game.rpc_projectile_spawn.rpc(id, muzzle, vel, "replay")
		_make_visual(id, muzzle, vel, "replay")
		Game.log_ev("Weapon", "replay_fire", {"id": id, "shot": rec["id"], "owner": owner.id, "weapon": rec["weapon"]})


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
	if not pending_replays.is_empty():
		_server_replays()
	for id in live.keys():
		var p: Dictionary = live[id]
		p["tick"] = int(p.get("tick", 0)) + 1
		if records.has(id) and int(p["tick"]) % 3 == 0:
			var smp: PackedVector3Array = records[id]["samples"]
			if smp.size() < HISTORY_SAMPLES:
				smp.append(p["pos"])
				records[id]["samples"] = smp
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
			if col is Player and int(col.id) == int(p["owner"]):
				pass  # a projectile never damages its own owner (replays included)
			elif col is Player:
				hit_id = col.id
				if col.apply_damage(dmg, p["owner"], p["weapon"], 0.0):
					if records.has(id):
						records[id]["damaged"] = true
					Game.log_ev("Weapon", "hit", {"id": id, "owner": p["owner"], "victim": col.id, "weapon": p["weapon"], "dmg": snappedf(dmg, 0.1), "accel": p["accelerated"], "dist": snappedf(dist, 0.1), "replay": bool(p.get("replay", false)), "replay_of": p.get("replay_of", 0)})
			elif col != null:
				var target = col if col.has_method("hit_by_shot") else col.get_parent()
				if target != null and target.has_method("apply_damage") and not (target is Player):
					target.apply_damage(dmg)
				elif target != null and target.has_method("hit_by_shot"):
					target.hit_by_shot(p["owner"])
					hit_id = -9999
			if records.has(id):
				var smp2: PackedVector3Array = records[id]["samples"]
				smp2.append(hit["position"])
				records[id]["samples"] = smp2
				records[id]["done"] = true
			Game.rpc_projectile_hit.rpc(id, hit["position"], hit_id)
			_remove(id)
			continue
		vel.y -= GRAVITY * delta
		p["vel"] = vel
		p["pos"] = to
		p["life"] = float(p["life"]) - delta
		_move_visual(id, to, vel)
		if float(p["life"]) <= 0.0 or to.y < -30.0:
			if records.has(id):
				records[id]["done"] = true
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
		var fam: String = Game.map_def.family if Game.map_def != null else "oracle"
		Sfx.play_at("impact_flesh" if hit_id != 0 else ("impact_metal" if fam != "oracle" and randf() < 0.5 else "impact_stone"), pos, -6.0)
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
	var col := Palette.MINT if weapon == "replay" else Color(str(Weapons.get_data(weapon)["color"]))
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



# ---------------------------------------------------------------- retrieval presentation (all peers)
## A small temporal mote travels back along the recorded path to the owner's muzzle, joined to the
## muzzle by a thin low-opacity tether. Purely visual; the replay is spawned by the server.
func on_retrieve(owner_id: int, pts: PackedVector3Array, dur: float) -> void:
	if DisplayServer.get_name() == "headless" or Game.world == null or pts.size() < 1:
		return
	var holder: Node = Game.world.get_node_or_null("Fx")
	if holder == null:
		holder = Game.world
	var mote := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	sm.radial_segments = 8
	sm.rings = 4
	mote.mesh = sm
	mote.material_override = Features.glow_mat(Palette.MINT, 2.2, 0.9)
	holder.add_child(mote)
	mote.global_position = pts[0]
	var line := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	line.mesh = im
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lm.albedo_color = Color(Palette.MINT, 0.32)
	line.material_override = lm
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(line)
	retrievals.append({"node": mote, "line": line, "mesh": im, "pts": pts, "t": 0.0, "dur": dur, "owner": owner_id})
	Sfx.play_at("rewind", pts[0], -10.0, 1.6)


func _process(delta: float) -> void:
	if retrievals.is_empty():
		return
	for r in retrievals.duplicate():
		r["t"] = float(r["t"]) + delta
		var k := clampf(float(r["t"]) / float(r["dur"]), 0.0, 1.0)
		var owner = Game.players.get(int(r["owner"]))
		var muzzle: Vector3 = owner.muzzle_position() if owner != null and is_instance_valid(owner) else Vector3(r["pts"][r["pts"].size() - 1])
		var pts: PackedVector3Array = r["pts"]
		var pos: Vector3
		if k < 0.75 and pts.size() > 1:
			var f := k / 0.75 * float(pts.size() - 1)
			var i0 := int(floor(f))
			var i1 := mini(i0 + 1, pts.size() - 1)
			pos = pts[i0].lerp(pts[i1], f - float(i0))
		else:
			var start: Vector3 = pts[pts.size() - 1]
			pos = start.lerp(muzzle, clampf((k - 0.75) / 0.25, 0.0, 1.0))
		var mote: MeshInstance3D = r["node"]
		if is_instance_valid(mote):
			mote.global_position = pos
		var im: ImmediateMesh = r["mesh"]
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		im.surface_add_vertex(muzzle)
		im.surface_add_vertex(pos)
		im.surface_end()
		if k >= 1.0:
			if is_instance_valid(mote):
				mote.queue_free()
			if is_instance_valid(r["line"]):
				r["line"].queue_free()
			retrievals.erase(r)
