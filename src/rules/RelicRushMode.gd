class_name RelicRushMode
extends RefCounted
## Server-only Relic Rush orchestration: 5-minute free-for-all, shards, rotating Relay Beacon,
## respawns with spawn protection, first to 25, sudden death on a tie.

const PRE_ROUND_TIME := 5.0
const MATCH_TIME := 300.0
const SHARD_RESPAWN := 20.0
const SHARD_RADIUS := 1.9
const BEACON_RADIUS := 5.5
const BEACON_TICK := 4.0
const BEACON_ROTATE := 45.0
const RESPAWN_DELAY := 3.0
const PROTECT := 2.0

var ms: MatchServer
var s: Dictionary
var phase := "pre_round"
var phase_t := PRE_ROUND_TIME
var time_left := MATCH_TIME
var shards: Array = []
var beacon_idx := 0
var beacon_rotate_t := BEACON_ROTATE
var beacon_tick_t := BEACON_TICK
var beacon_owner := 0
var beacon_contested := false
var _state_dirty_t := 0.0


func _init(server: MatchServer) -> void:
	ms = server
	s = RelicRules.new_state(Net.players.keys())


func begin() -> void:
	phase = "pre_round"
	ms.phase = phase
	phase_t = PRE_ROUND_TIME
	time_left = MATCH_TIME
	for pos in ms.def.shard_points:
		shards.append({"pos": pos, "active": true, "t": 0.0})
	beacon_idx = 0
	for p: Player in Game.players.values():
		if is_instance_valid(p):
			p.frozen = true
			p.re_spent = false
			p.ff_spent = true
	ms.push_state()
	Game.rpc_notice.rpc("RELIC RUSH\nEliminate (2) · collect Memory Shards (1) · hold the Relay Beacon (1 per 4 s) · first to %d" % RelicRules.TARGET, PRE_ROUND_TIME)
	Game.log_ev("Round", "start", {"mode": "relic_rush", "shards": shards.size(), "beacons": ms.def.beacon_points.size()})


func spawn_protection() -> float:
	return PROTECT


## Relic Rush: every player may Reverse Entropy once per MATCH (no Fast-Forward in free-for-all).
func request_ability(p: Player) -> void:
	if phase != "live" and phase != "sudden_death":
		return
	if not p.alive or p.frozen or p.rewind_t > 0.0:
		return
	if p.re_spent:
		if p.id > 0:
			Game.rpc_notice.rpc_id(p.id, "REVERSE ENTROPY / SPENT THIS MATCH", 1.5)
		return
	if not p.recorder.has_span(HotReturnRules.REWIND_SECONDS - 0.15):
		if p.id > 0:
			Game.rpc_notice.rpc_id(p.id, "REVERSE ENTROPY / NOT ENOUGH HISTORY", 1.5)
		return
	p.re_spent = true
	p.set_meta("restores", 0)
	p.set_meta("restored_ids", [])
	p.start_rewind(ms.match_time, HotReturnRules.REWIND_SECONDS)
	Game.rpc_fx.rpc("rewind_start", p.id, p.global_position)
	Game.log_ev("Ability", "reverse_entropy", {"id": p.id, "mode": "relic_rush"})
	Game.projectiles.retrieve_for(p)


func role_of(_team: int) -> String:
	return "ffa"


func beacon_pos() -> Vector3:
	if ms.def.beacon_points.is_empty():
		return Vector3.ZERO
	return ms.def.beacon_points[beacon_idx % ms.def.beacon_points.size()]


func beacon_info() -> Dictionary:
	return {"pos": beacon_pos(), "owner": beacon_owner, "contested": beacon_contested}


func active_shards() -> Array:
	var out := []
	for sh in shards:
		if sh["active"]:
			out.append(sh["pos"])
	return out


func step(delta: float) -> void:
	match phase:
		"pre_round":
			phase_t -= delta
			time_left = ceilf(maxf(phase_t, 0.0))
			if phase_t <= 0.0:
				phase = "live"
				ms.phase = phase
				time_left = MATCH_TIME
				for p in Game.players.values():
					if is_instance_valid(p):
						p.frozen = false
				ms.push_state()
				Game.rpc_notice.rpc("LIVE", 2.0)
				Game.log_ev("Round", "live", {"mode": "relic_rush"})
		"live", "sudden_death":
			if phase == "live":
				time_left = maxf(0.0, time_left - delta)
			_step_shards(delta)
			_step_beacon(delta)
			_check_end()
		"match_end":
			pass


func _step_shards(delta: float) -> void:
	for i in shards.size():
		var sh: Dictionary = shards[i]
		if not sh["active"]:
			sh["t"] -= delta
			if sh["t"] <= 0.0:
				sh["active"] = true
				_dirty()
			continue
		var pos: Vector3 = sh["pos"]
		for p in Game.players.values():
			if not is_instance_valid(p) or not p.alive or p.frozen:
				continue
			if Vector2(p.global_position.x - pos.x, p.global_position.z - pos.z).length() <= SHARD_RADIUS and absf(p.global_position.y - pos.y) < 3.0:
				sh["active"] = false
				sh["t"] = SHARD_RESPAWN
				_award(p.id, RelicRules.SHARD_POINTS, "shard")
				Game.rpc_fx.rpc("teleport", p.id, pos)
				if p.id > 0:
					Game.rpc_notice.rpc_id(p.id, "+1 MEMORY SHARD", 1.2)
				break


func _step_beacon(delta: float) -> void:
	var bp := beacon_pos()
	var occupants := {}
	for p in Game.players.values():
		if not is_instance_valid(p) or not p.alive or p.frozen:
			continue
		var inside := Vector2(p.global_position.x - bp.x, p.global_position.z - bp.z).length() <= BEACON_RADIUS and absf(p.global_position.y - bp.y) < 4.0
		if inside:
			occupants[p.id] = true
	var owner := RelicRules.beacon_owner(occupants)
	var contested := occupants.size() > 1
	if owner != beacon_owner or contested != beacon_contested:
		beacon_owner = owner
		beacon_contested = contested
		beacon_tick_t = BEACON_TICK
		_dirty()
	if owner != 0:
		beacon_tick_t -= delta
		if beacon_tick_t <= 0.0:
			beacon_tick_t = BEACON_TICK
			_award(owner, RelicRules.BEACON_POINTS, "beacon")
			if owner > 0:
				Game.rpc_notice.rpc_id(owner, "+1 BEACON CONTROL", 1.0)
	beacon_rotate_t -= delta
	if beacon_rotate_t <= 3.0 and beacon_rotate_t + delta > 3.0:
		Game.rpc_notice.rpc("BEACON RELOCATING IN 3", 2.5)
	if beacon_rotate_t <= 0.0:
		beacon_rotate_t = BEACON_ROTATE
		beacon_idx = (beacon_idx + 1) % maxi(1, ms.def.beacon_points.size())
		beacon_owner = 0
		beacon_contested = false
		beacon_tick_t = BEACON_TICK
		Game.rpc_notice.rpc("THE RELAY BEACON MOVED", 2.0)
		Game.log_ev("Objective", "beacon_rotate", {"idx": beacon_idx})
		_dirty()


func _award(id: int, n: int, why: String) -> void:
	RelicRules.add_points(s, id, n)
	if Net.players.has(id):
		Net.players[id]["points"] = int(s["points"][id])
	Game.log_ev("Objective", "points", {"id": id, "n": n, "why": why, "total": s["points"][id]})
	_dirty()


func _dirty() -> void:
	Net.broadcast_players()
	ms.push_state()


func _check_end() -> void:
	var w := RelicRules.winner(s, time_left)
	if w != 0:
		_end_match(w)
		return
	if phase == "live" and RelicRules.needs_sudden_death(s, time_left):
		phase = "sudden_death"
		ms.phase = phase
		s["sudden_death"] = true
		ms.push_state()
		Game.rpc_notice.rpc("SUDDEN DEATH\nFIRST POINT WINS", 4.0)
		Game.log_ev("Round", "sudden_death", {})


func _end_match(w: int) -> void:
	phase = "match_end"
	ms.phase = phase
	ms.cancel_respawns()
	ms.clear_echoes("match_end")
	for p in Game.players.values():
		if is_instance_valid(p):
			p.frozen = true
	var rows := []
	for id in Net.players:
		var i: Dictionary = Net.players[id]
		rows.append({"name": i["name"], "team": "SOLO", "kills": int(i["kills"]), "deaths": int(i["deaths"]), "points": int(s["points"].get(id, 0))})
	rows.sort_custom(func(a, b) -> bool: return a["points"] > b["points"])
	var wname := Game.player_name(w)
	Game.rpc_results.rpc({
		"mode": "relic_rush", "map": Game.map_id,
		"winner_text": "%s WINS / %d POINTS" % [wname, int(s["points"][w])],
		"reason": "Target reached." if int(s["points"][w]) >= RelicRules.TARGET else ("Sudden death decided it." if bool(s["sudden_death"]) else "Highest score when the clock ran out."),
		"rows": rows, "winner_id": w,
	})
	Game.log_ev("Match", "end", {"winner": w, "points": s["points"]})


# ---------------------------------------------------------------- hooks
func on_player_died(victim: Player, killer_id: int, _cause: String) -> void:
	if killer_id != victim.id and Game.players.has(killer_id):
		_award(killer_id, RelicRules.KILL_POINTS, "elimination")
	if phase == "live" or phase == "sudden_death":
		ms.queue_respawn(victim.id, RESPAWN_DELAY)
	_check_end()


func on_damaged(_victim: Player, _from_id: int, _cause: String) -> void:
	pass


func on_player_left(id: int) -> void:
	s["points"].erase(id)
	_dirty()


func on_out_of_bounds(_p: Player) -> void:
	pass


func state_dict() -> Dictionary:
	return {
		"mode": "relic_rush", "phase": phase, "target": RelicRules.TARGET,
		"points": s["points"],
		"beacon": {"owner_name": Game.player_name(beacon_owner) if beacon_owner != 0 else "", "contested": beacon_contested, "rotate_in": int(ceil(beacon_rotate_t))},
		"objective": "Eliminate (2) · Memory Shards (1) · hold the Relay Beacon (1 per 4 s) · first to %d" % RelicRules.TARGET,
	}


func live_dict() -> Dictionary:
	var sh := {}
	for i in shards.size():
		sh[i] = {"pos": shards[i]["pos"], "active": shards[i]["active"]}
	return {
		"shards": sh,
		"beacon": {"pos": beacon_pos(), "owner": beacon_owner, "owner_name": Game.player_name(beacon_owner) if beacon_owner != 0 else "", "contested": beacon_contested, "rotate_in": int(ceil(beacon_rotate_t))},
	}
