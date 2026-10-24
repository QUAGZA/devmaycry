class_name MatchServer
extends Node
## Server-only match orchestration: timers, spawns, respawns, kills, echoes and state broadcasts.
## Mode rules (Corebreak / Relic Rush) are plugged in as rule objects.

const RESPAWN_DELAY := 3.0
const WARMUP_LENGTH := 300.0

var mode := "corebreak"
var def: MapDef
var match_time := 0.0
var time_left := WARMUP_LENGTH
var phase := "live"
var rules = null
var next_echo_id := 1
var _respawn: Dictionary = {}
var _spawn_counter := 0


func setup(mode_id: String, mapdef: MapDef) -> void:
	mode = mode_id
	def = mapdef
	var path := "res://src/rules/RelicRushMode.gd"
	if mode == "corebreak":
		path = "res://src/rules/CorebreakMode.gd"
	elif mode == "hot_return":
		path = "res://src/rules/HotReturnMode.gd"
	if ResourceLoader.exists(path):
		rules = load(path).new(self)


func begin() -> void:
	if rules != null:
		rules.begin()
	else:
		push_state()
		Game.rpc_notice.rpc("WARMUP / FREE FIRE", 3.0)
	Game.log_ev("Round", "begin", {"mode": mode})


func role_of(team: int) -> String:
	if rules != null and rules.has_method("role_of"):
		return rules.role_of(team)
	return "attack" if team == 1 else "defend"


func spawn_for(info: Dictionary, index: int) -> Dictionary:
	var team := int(info.get("team", 0))
	if mode == "hot_return" and team != 0:
		return def.pick_spawn("attack" if team == 1 else "defend", index)
	if mode == "corebreak" and team != 0:
		return def.pick_spawn(role_of(team), index)
	return def.pick_spawn("ffa", index)


## Respawn point farthest from living enemies.
func respawn_point(p: Player) -> Dictionary:
	var candidates: Array = []
	if mode == "hot_return" and p.team != 0:
		candidates = def.role_spawns.get("attack" if p.team == 1 else "defend", [])
	elif mode == "corebreak" and p.team != 0:
		candidates = def.role_spawns.get(role_of(p.team), [])
	else:
		candidates = def.ffa_spawns
	if candidates.is_empty():
		return def.pick_spawn("ffa", _spawn_counter)
	var best: Dictionary = candidates[0]
	var best_d := -1.0
	var world: World3D = Game.world.get_world_3d() if Game.world != null else null
	for c in candidates:
		# a point inside geometry or on top of a living player is never used while a free one exists
		var penalty := 0.0
		if world != null and Features.blocked(world, c["position"]):
			penalty = 1000.0
		for other2: Player in Game.players.values():
			if is_instance_valid(other2) and other2 != p and other2.alive and other2.global_position.distance_to(c["position"]) < 1.2:
				penalty = maxf(penalty, 500.0)
		var dmin := 1e9
		for other: Player in Game.players.values():
			if not is_instance_valid(other) or other == p or not other.alive:
				continue
			if p.team != 0 and other.team == p.team:
				continue
			dmin = minf(dmin, other.global_position.distance_to(c["position"]))
		dmin += randf() * 2.0 - penalty
		if dmin > best_d:
			best_d = dmin
			best = c
	_spawn_counter += 1
	return best


func step(delta: float) -> void:
	match_time += delta
	if rules != null:
		rules.step(delta)
		time_left = rules.time_left
	else:
		time_left = maxf(0.0, time_left - delta)
	for id in _respawn.keys():
		_respawn[id] -= delta
		if _respawn[id] <= 0.0:
			_respawn.erase(id)
			_do_respawn(id)


func can_damage(from_id: int, victim: Player) -> bool:
	if phase != "live" and phase != "planted" and phase != "sudden_death":
		return false
	if from_id == victim.id:
		return false
	var fp = Game.players.get(from_id)
	if fp != null and is_instance_valid(fp) and fp.team != 0 and fp.team == victim.team:
		return false
	return true


func on_damaged(victim: Player, from_id: int, cause: String) -> void:
	if rules != null and rules.has_method("on_damaged"):
		rules.on_damaged(victim, from_id, cause)


func on_player_died(victim: Player, killer_id: int, cause: String) -> void:
	var kname := Game.player_name(killer_id)
	if Net.players.has(killer_id) and killer_id != victim.id:
		Net.players[killer_id]["kills"] = int(Net.players[killer_id]["kills"]) + 1
	if Net.players.has(victim.id):
		Net.players[victim.id]["deaths"] = int(Net.players[victim.id]["deaths"]) + 1
	Game.rpc_kill.rpc(kname, victim.pname, cause, killer_id, victim.id)
	Game.log_ev("Round", "kill", {"killer": killer_id, "victim": victim.id, "cause": cause})
	if rules != null:
		rules.on_player_died(victim, killer_id, cause)
	else:
		_respawn[victim.id] = RESPAWN_DELAY
	Net.broadcast_players()


func queue_respawn(id: int, delay: float) -> void:
	_respawn[id] = delay


func cancel_respawns() -> void:
	_respawn.clear()


func _do_respawn(id: int) -> void:
	var p = Game.players.get(id)
	if p == null or not is_instance_valid(p) or p.alive:
		return   # removed, or already alive: one death never produces two respawns
	if phase != "live" and phase != "planted" and phase != "sudden_death":
		return   # the next round start respawns everyone
	var sp := respawn_point(p)
	var protect := Player.RESPAWN_PROTECT
	if rules != null and rules.has_method("spawn_protection"):
		protect = rules.spawn_protection()
	Game.rpc_respawn.rpc(id, sp["position"], sp["yaw"], protect)
	Game.log_ev("Round", "respawn", {"id": id, "team": p.team, "pos": [snappedf(sp["position"].x, 0.1), snappedf(sp["position"].y, 0.1), snappedf(sp["position"].z, 0.1)], "protect": protect})


func on_out_of_bounds(p: Player) -> void:
	if not p.alive:
		return
	var sp := respawn_point(p)
	Game.rpc_teleport.rpc(p.id, sp["position"], sp["yaw"])
	Game.rpc_notice.rpc_id(p.id, "RETURNED TO THE ARENA", 2.0) if p.id > 0 else null
	Game.log_ev("Round", "out_of_bounds", {"id": p.id})
	if rules != null and rules.has_method("on_out_of_bounds"):
		rules.on_out_of_bounds(p)


func on_player_left(id: int) -> void:
	_respawn.erase(id)
	if rules != null and rules.has_method("on_player_left"):
		rules.on_player_left(id)


## A rewinding player re-traverses history: restore nearby tagged props destroyed after that moment.
func on_rewind_pass(p: Player, historical_t: float) -> void:
	if def == null:
		return
	if not p.has_meta("restores"):
		p.set_meta("restores", 0)
	if not p.has_meta("restored_ids"):
		p.set_meta("restored_ids", [])
	if int(p.get_meta("restores")) >= 3:
		return
	for tp in def.temporal_props:
		if not is_instance_valid(tp) or tp.state != "destroyed":
			continue
		if tp.destroyed_at <= historical_t:
			continue
		var flat := Vector2(tp.global_position.x - p.global_position.x, tp.global_position.z - p.global_position.z).length()
		if flat > 5.0 or absf(tp.global_position.y - p.global_position.y) > 3.0:
			continue
		if tp.prop_id in p.get_meta("restored_ids"):
			continue
		if tp.restore_temporal(match_time):
			p.set_meta("restores", int(p.get_meta("restores")) + 1)
			p.get_meta("restored_ids").append(tp.prop_id)


func request_ability(p: Player) -> void:
	if p.is_protected():
		if p.id > 0:
			Game.rpc_notice.rpc_id(p.id, "PROTECTED  /  ABILITIES UNLOCK WHEN THE SHIELD ENDS", 1.2)
		return
	if rules != null and rules.has_method("request_ability"):
		rules.request_ability(p)
	else:
		request_echo(p)


func request_echo(p: Player) -> void:
	if not p.alive or p.echo_cd > 0.0 or phase == "pre_round" or phase == "round_end" or phase == "match_end":
		return
	if p.recorder.sample_count() < 2:
		return
	if not ResourceLoader.exists("res://src/echo/Echo.gd"):
		return
	for eid in Game.echoes.keys():
		var e = Game.echoes[eid]
		if is_instance_valid(e) and e.owner_id == p.id:
			Game.rpc_echo_end.rpc(eid, "recast")
	var payload := p.recorder.payload()
	var eid := next_echo_id
	next_echo_id += 1
	p.echo_cd = 18.0
	Game.rpc_echo_spawn.rpc(eid, p.id, payload)
	Game.log_ev("Echo", "cast", {"owner": p.id, "echo": eid, "samples": payload["t"].size(), "events": payload["events"].size()})


func clear_echoes(reason: String) -> void:
	for eid in Game.echoes.keys():
		Game.rpc_echo_end.rpc(eid, reason)


func live_dict() -> Dictionary:
	if rules != null and rules.has_method("live_dict"):
		return rules.live_dict()
	return {}


func push_state() -> void:
	if rules != null:
		Game.rpc_state.rpc(rules.state_dict())
		return
	Game.rpc_state.rpc({
		"mode": mode, "phase": phase, "round": 1, "scores": {1: 0, 2: 0},
		"roles": {1: "ATTACK", 2: "DEFEND"}, "objective": "WARMUP / FREE FIRE", "overtime": false,
	})
