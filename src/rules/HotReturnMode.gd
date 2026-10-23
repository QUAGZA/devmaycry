class_name HotReturnMode
extends RefCounted
## Server-only HOT RETURN orchestration: Causal Core in the defenders' vault, attackers carry it to their
## home Stabilizer before volatility reaches 100 %. Stability Fields pause the fuse for a 7 s allowance each.
## Reverse Entropy (attackers) and Fast-Forward Entropy (defenders) are once per round, no cooldown.

const PRE_ROUND_TIME := 5.0
const ROUND_END_TIME := 6.0

var ms: MatchServer
var m: Dictionary = HotReturnRules.new_match()
var phase := "pre_round"
var phase_t := PRE_ROUND_TIME
var time_left := HotReturnRules.ROUND_TIME
var core := {}
var history: Array = []
var _history_t := 0.0
var field_allowance: Array = []
var charges: Dictionary = {}          # id -> {"re": spent?, "ff": spent?}
var ff_field := {"active": false, "pos": Vector3.ZERO, "until": 0.0, "owner": 0}
var result := ""
var last_result_reason := ""


func _init(server: MatchServer) -> void:
	ms = server


func begin() -> void:
	_start_round()


func attacking_team() -> int:
	return HotReturnRules.attacking_team(m)


func defending_team() -> int:
	return 3 - attacking_team()


func role_of(team: int) -> String:
	return "attack" if attacking_team() == team else "defend"


func spawn_protection() -> float:
	return 0.0


func side_of(team: int) -> String:
	return "attack" if team == 1 else "defend"


# ---------------------------------------------------------------- round flow
func _start_round() -> void:
	phase = "pre_round"
	ms.phase = phase
	phase_t = PRE_ROUND_TIME
	time_left = HotReturnRules.ROUND_TIME
	result = ""
	last_result_reason = ""
	var vault_pos: Vector3 = ms.def.vaults.get(defending_team(), Vector3.ZERO)
	core = {"mode": "cradle", "pos": vault_pos, "carrier": 0, "v": 0.0, "lock_until": 0.0, "detonated": false, "stabilized": false, "carrier_name": ""}
	history = [[ms.match_time, 0.0]]
	_history_t = 0.0
	field_allowance = []
	for f in ms.def.fields:
		field_allowance.append(HotReturnRules.FIELD_ALLOWANCE)
	ff_field = {"active": false, "pos": Vector3.ZERO, "until": 0.0, "owner": 0}
	charges.clear()
	ms.cancel_respawns()
	ms.clear_echoes("round_reset")
	ms.def.reset_features()
	var idx := {1: 0, 2: 0, 0: 0}
	for p: Player in Game.players.values():
		if not is_instance_valid(p):
			continue
		var sp: Dictionary = ms.def.pick_spawn(side_of(p.team), idx[p.team])
		idx[p.team] += 1
		Game.rpc_respawn.rpc(p.id, sp["position"], sp["yaw"], 0.0)
		p.frozen = true
		p.re_spent = false
		p.ff_spent = false
		p.rewind_t = 0.0
		p.ff_until = 0.0
		charges[p.id] = {"re": false, "ff": false}
	ms.push_state()
	var atk := attacking_team()
	Game.rpc_notice.rpc("ROUND %d%s\n%s STEAL THE CORE  ·  %s HOLD THE VAULT" % [m["round"], " / OVERTIME" if m["overtime"] else "", Palette.team_name(atk), Palette.team_name(3 - atk)], PRE_ROUND_TIME)
	Game.log_ev("Round", "start", {"mode": "hot_return", "round": m["round"], "attack": atk, "overtime": m["overtime"], "wins": m["wins"]})


func _go_live() -> void:
	phase = "live"
	ms.phase = phase
	time_left = HotReturnRules.ROUND_TIME
	for p: Player in Game.players.values():
		if is_instance_valid(p):
			p.frozen = false
	ms.push_state()
	Game.rpc_notice.rpc("LIVE\nATTACK: steal the Causal Core and reach your Stabilizer   ·   DEFEND: hold the vault, let it detonate", 3.0)
	Game.log_ev("Round", "live", {"round": m["round"]})


func step(delta: float) -> void:
	match phase:
		"pre_round":
			phase_t -= delta
			time_left = ceilf(maxf(phase_t, 0.0))
			if phase_t <= 0.0:
				_go_live()
		"live":
			time_left = maxf(0.0, time_left - delta)
			_step_ff(delta)
			_step_core(delta)
			_check_result()
		"round_end":
			phase_t -= delta
			if phase_t <= 0.0:
				if int(m["winner"]) != 0:
					_end_match()
				else:
					_start_round()
		"match_end":
			pass


# ---------------------------------------------------------------- core
func _field_index_at(pos: Vector3) -> int:
	for i in ms.def.fields.size():
		var f: Dictionary = ms.def.fields[i]
		var fp: Vector3 = f["position"]
		if Vector2(pos.x - fp.x, pos.z - fp.z).length() <= float(f.get("radius", HotReturnRules.FIELD_RADIUS)) and absf(pos.y - fp.y) < 8.0:
			return i
	return -1


func ff_covers(pos: Vector3) -> bool:
	return bool(ff_field["active"]) and pos.distance_to(ff_field["pos"]) <= HotReturnRules.FF_RADIUS


func _step_ff(_delta: float) -> void:
	if bool(ff_field["active"]) and ms.match_time >= float(ff_field["until"]):
		ff_field["active"] = false
		Game.log_ev("Ability", "ff_end", {"owner": ff_field["owner"]})
		ms.push_state()


func _step_core(delta: float) -> void:
	var mode := str(core["mode"])
	if mode == "cradle" or mode == "dropped" or mode == "locked":
		if mode == "locked" and ms.match_time < float(core["lock_until"]):
			pass
		else:
			for p: Player in Game.players.values():
				if not is_instance_valid(p) or not p.alive or p.frozen or p.rewind_t > 0.0:
					continue
				if role_of(p.team) != "attack":
					continue
				var cp: Vector3 = core["pos"]
				if Vector2(p.global_position.x - cp.x, p.global_position.z - cp.z).length() <= HotReturnRules.PICKUP_RADIUS and absf(p.global_position.y - cp.y) < 3.0:
					_pickup(p)
					break
	mode = str(core["mode"])
	if mode == "carried":
		var c: Player = Game.players.get(int(core["carrier"]))
		if c == null or not is_instance_valid(c) or not c.alive:
			_drop_core(c, false)
		else:
			core["pos"] = c.global_position
			var st: Vector3 = ms.def.stabilizers.get(attacking_team(), Vector3(9999, 0, 9999))
			if Vector2(c.global_position.x - st.x, c.global_position.z - st.z).length() <= HotReturnRules.STABILIZE_RADIUS and absf(c.global_position.y - st.y) < 3.5:
				_stabilize(c)
				return
	mode = str(core["mode"])
	var ticking := mode == "carried" or mode == "dropped"
	if ticking:
		var pos: Vector3 = core["pos"]
		var fi := _field_index_at(pos)
		var in_field := fi >= 0
		var allowance := float(field_allowance[fi]) if in_field else 0.0
		var r := HotReturnRules.volatility_step(float(core["v"]), delta, true, in_field, allowance, ff_covers(pos))
		if in_field and float(r["used"]) > 0.0:
			field_allowance[fi] = maxf(0.0, allowance - float(r["used"]))
		var before := float(core["v"])
		core["v"] = r["v"]
		if int(before / 25.0) != int(float(core["v"]) / 25.0) and float(core["v"]) < 100.0:
			Game.rpc_notice.rpc("CORE VOLATILITY %d%%" % int(core["v"]), 1.2)
		if float(core["v"]) >= 100.0 and not bool(core["detonated"]):
			core["detonated"] = true
			core["mode"] = "detonated"
			if c_valid():
				var c: Player = Game.players.get(int(core["carrier"]))
				c.carrying_core = false
			core["carrier"] = 0
			Game.rpc_fx.rpc("detonate", 0, pos)
			Game.log_ev("Objective", "detonation", {"pos": [pos.x, pos.y, pos.z], "t": ms.match_time})
			ms.push_state()
	_history_t += delta
	if _history_t >= 0.1:
		_history_t = 0.0
		history.append([ms.match_time, float(core["v"])])
		while history.size() > 0 and float(history[0][0]) < ms.match_time - HotReturnRules.HISTORY_SECONDS:
			history.pop_front()


func c_valid() -> bool:
	var c = Game.players.get(int(core["carrier"]))
	return c != null and is_instance_valid(c)


func _pickup(p: Player) -> void:
	var was := str(core["mode"])
	core["mode"] = "carried"
	core["carrier"] = p.id
	core["carrier_name"] = p.pname
	core["pos"] = p.global_position
	p.carrying_core = true
	Game.rpc_notice.rpc("%s %s THE CAUSAL CORE" % [p.pname, "STOLE" if was == "cradle" else "RECOVERED"], 2.0)
	Game.rpc_fx.rpc("core_pickup", p.id, p.global_position)
	Game.log_ev("Objective", "pickup", {"id": p.id, "from": was, "v": snappedf(float(core["v"]), 0.1)})
	ms.push_state()


func _drop_core(c, locked: bool) -> void:
	if c != null and is_instance_valid(c):
		core["pos"] = c.global_position
		c.carrying_core = false
	var pos: Vector3 = core["pos"]
	if pos.y < ms.def.kill_y + 2.0:
		core["pos"] = ms.def.vaults.get(defending_team(), Vector3.ZERO)
	core["carrier"] = 0
	core["carrier_name"] = ""
	core["mode"] = "locked" if locked else "dropped"
	if not locked:
		Game.rpc_notice.rpc("THE CORE WAS DROPPED  ·  STILL TICKING", 2.0)
	Game.rpc_fx.rpc("core_drop", 0, core["pos"])
	Game.log_ev("Objective", "drop", {"locked": locked, "v": snappedf(float(core["v"]), 0.1)})
	ms.push_state()


func _stabilize(c: Player) -> void:
	core["mode"] = "stabilized"
	core["stabilized"] = true
	c.carrying_core = false
	core["carrier"] = 0
	Game.rpc_fx.rpc("stabilize", c.id, c.global_position)
	Game.log_ev("Objective", "stabilized", {"by": c.id, "v": snappedf(float(core["v"]), 0.1), "t": ms.match_time})
	ms.push_state()
	_check_result()


# ---------------------------------------------------------------- abilities (once per round, no cooldown)
func request_ability(p: Player) -> void:
	if phase != "live" or not p.alive or p.frozen:
		return
	if not charges.has(p.id):
		charges[p.id] = {"re": false, "ff": false}
	if role_of(p.team) == "attack":
		_reverse_entropy(p)
	else:
		_fast_forward(p)


func _reverse_entropy(p: Player) -> void:
	if bool(charges[p.id]["re"]) or p.re_spent:
		_deny(p, "REVERSE ENTROPY / SPENT THIS ROUND")
		return
	if p.rewind_t > 0.0:
		return
	if not p.recorder.has_span(HotReturnRules.REWIND_SECONDS - 0.15):
		_deny(p, "REVERSE ENTROPY / NOT ENOUGH HISTORY")
		return
	charges[p.id]["re"] = true
	p.re_spent = true
	if str(core["mode"]) == "carried" and int(core["carrier"]) == p.id:
		var rewound := HotReturnRules.history_value(history, ms.match_time - HotReturnRules.REWIND_SECONDS)
		_drop_core(p, true)
		core["v"] = rewound
		core["lock_until"] = ms.match_time + HotReturnRules.REWIND_SECONDS
		Game.rpc_notice.rpc("TEMPORAL LOCK  ·  CORE FROZEN AT %d%%" % int(rewound), 2.5)
		Game.log_ev("Ability", "reverse_entropy_core", {"id": p.id, "v": snappedf(rewound, 0.1), "lock_until": snappedf(float(core["lock_until"]), 0.1)})
	p.set_meta("restores", 0)
	p.set_meta("restored_ids", [])
	p.start_rewind(ms.match_time, HotReturnRules.REWIND_SECONDS)
	Game.rpc_fx.rpc("rewind_start", p.id, p.global_position)
	Game.log_ev("Ability", "reverse_entropy", {"id": p.id, "t": ms.match_time})
	ms.push_state()


func _fast_forward(p: Player) -> void:
	if bool(charges[p.id]["ff"]) or p.ff_spent:
		_deny(p, "FAST-FORWARD / SPENT THIS ROUND")
		return
	if bool(ff_field["active"]):
		_deny(p, "FAST-FORWARD ALREADY ACTIVE  ·  CHARGE KEPT")
		return
	charges[p.id]["ff"] = true
	p.ff_spent = true
	ff_field = {"active": true, "pos": p.global_position, "until": ms.match_time + HotReturnRules.FF_DURATION, "owner": p.id}
	p.ff_until = ms.match_time + HotReturnRules.FF_DURATION
	Game.rpc_fx.rpc("ff_start", p.id, p.global_position)
	Game.rpc_notice.rpc("%s ACCELERATED LOCAL ENTROPY" % p.pname, 1.5)
	Game.log_ev("Ability", "fast_forward", {"id": p.id, "t": ms.match_time})
	ms.push_state()


func _deny(p: Player, text: String) -> void:
	if p.id > 0:
		Game.rpc_notice.rpc_id(p.id, text, 1.5)
	Game.log_ev("Ability", "denied", {"id": p.id, "why": text})


# ---------------------------------------------------------------- result
func _alive_counts() -> Dictionary:
	var atk := 0
	var dfn := 0
	for p: Player in Game.players.values():
		if not is_instance_valid(p) or not p.alive:
			continue
		if role_of(p.team) == "attack":
			atk += 1
		else:
			dfn += 1
	return {"attack": atk, "defend": dfn}


func _check_result() -> void:
	if phase != "live":
		return
	var ac := _alive_counts()
	var r := HotReturnRules.resolve({
		"detonated": bool(core["detonated"]),
		"stabilized": bool(core["stabilized"]),
		"attackers_alive": ac["attack"],
		"defenders_alive": ac["defend"],
		"time_left": time_left,
	})
	if r != "":
		_finish_round(r)


func _finish_round(r: String) -> void:
	var parts := r.split(":")
	var winner_team := attacking_team() if parts[0] == "attack" else defending_team()
	var reason := parts[1]
	var round_no := int(m["round"])
	result = r
	last_result_reason = reason
	phase = "round_end"
	ms.phase = phase
	phase_t = ROUND_END_TIME
	for p: Player in Game.players.values():
		if is_instance_valid(p):
			p.frozen = true
			p.carrying_core = false
			p.rewind_t = 0.0
	ff_field["active"] = false
	var reason_text: String = {
		"detonation": "THE CAUSAL CORE DETONATED",
		"stabilized": "THE CORE WAS STABILIZED",
		"eliminated": "OPPOSING SQUAD ELIMINATED",
		"timer": "TIME EXPIRED BEFORE EXTRACTION",
	}.get(reason, reason.to_upper())
	HotReturnRules.record_round(m, winner_team)
	for id in Net.players:
		if int(Net.players[id]["team"]) == winner_team:
			Net.players[id]["points"] = int(Net.players[id]["points"]) + 1
	Net.broadcast_players()
	ms.push_state()
	var mp := ""
	if int(m["winner"]) == 0 and (int(m["wins"][1]) == 2 or int(m["wins"][2]) == 2) and not bool(m["overtime"]):
		mp = "  ·  MATCH POINT"
	Game.rpc_notice.rpc("%s WINS ROUND %d\n%s   ·   %d - %d%s" % [Palette.team_name(winner_team), round_no, reason_text, m["wins"][1], m["wins"][2], mp], ROUND_END_TIME - 0.5)
	Game.log_ev("Round", "end", {"round": round_no, "winner": winner_team, "reason": reason, "wins": m["wins"], "overtime": m["overtime"], "match_winner": m["winner"], "core_v": snappedf(float(core["v"]), 0.1)})


func _end_match() -> void:
	phase = "match_end"
	ms.phase = phase
	var w := int(m["winner"])
	var rows := []
	for id in Net.players:
		var i: Dictionary = Net.players[id]
		rows.append({"name": i["name"], "team": Palette.team_name(int(i["team"])), "kills": int(i["kills"]), "deaths": int(i["deaths"]), "points": int(i["points"]), "_t": int(i["team"])})
	rows.sort_custom(func(a, b) -> bool:
		if a["_t"] != b["_t"]:
			return a["_t"] == w
		return a["kills"] > b["kills"])
	Game.rpc_results.rpc({
		"mode": "hot_return", "map": Game.map_id,
		"winner_text": "%s WINS %d - %d" % [Palette.team_name(w), m["wins"][w], m["wins"][3 - w]],
		"reason": "Match decided after %d rounds%s." % [int(m["round"]) - 1, " including overtime" if m["overtime"] else ""],
		"rows": rows, "winner_team": w,
	})
	Game.log_ev("Match", "end", {"winner": w, "wins": m["wins"], "rounds": int(m["round"]) - 1})


# ---------------------------------------------------------------- hooks
func on_player_died(victim: Player, _killer_id: int, _cause: String) -> void:
	if int(core["carrier"]) == victim.id and str(core["mode"]) == "carried":
		_drop_core(victim, false)
	victim.rewind_t = 0.0
	_check_result()


func on_damaged(_victim: Player, _from_id: int, _cause: String) -> void:
	pass


func on_player_left(id: int) -> void:
	if int(core["carrier"]) == id and str(core["mode"]) == "carried":
		core["carrier"] = 0
		core["mode"] = "dropped"
		ms.push_state()
	_check_result()


func on_out_of_bounds(_p: Player) -> void:
	pass


# ---------------------------------------------------------------- replication
func state_dict() -> Dictionary:
	return {
		"mode": "hot_return",
		"phase": phase,
		"round": int(m["round"]),
		"scores": m["wins"],
		"roles": {1: role_of(1).to_upper(), 2: role_of(2).to_upper()},
		"overtime": bool(m["overtime"]),
		"attacking": attacking_team(),
		"core": {"mode": core["mode"]},
		"ff": {"active": bool(ff_field["active"]), "pos": ff_field["pos"], "until": ff_field["until"]},
		"objective": "",
	}


func live_dict() -> Dictionary:
	var fields := []
	for i in ms.def.fields.size():
		fields.append({"pos": ms.def.fields[i]["position"], "radius": float(ms.def.fields[i].get("radius", HotReturnRules.FIELD_RADIUS)), "remaining": float(field_allowance[i]) if i < field_allowance.size() else 0.0})
	return {
		"core": {"mode": core["mode"], "pos": core["pos"], "carrier": core["carrier"], "carrier_name": core["carrier_name"], "v": snappedf(float(core["v"]), 0.1), "lock_left": maxf(0.0, float(core["lock_until"]) - ms.match_time) if str(core["mode"]) == "locked" else 0.0},
		"fields": fields,
		"ff": {"active": bool(ff_field["active"]), "pos": ff_field["pos"], "left": maxf(0.0, float(ff_field["until"]) - ms.match_time)},
		"vault": ms.def.vaults.get(defending_team(), Vector3.ZERO),
		"stabilizer": ms.def.stabilizers.get(attacking_team(), Vector3.ZERO),
		"match_time": ms.match_time,
	}
