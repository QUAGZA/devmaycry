class_name CorebreakMode
extends RefCounted
## Server-only Corebreak orchestration: pre-round freeze, Core pickup / carry / drop, plant and
## defuse with interrupts, detonation, deterministic round resolution, side swap, overtime, results.

const PRE_ROUND_TIME := 5.0
const ROUND_TIME := 100.0
const PLANT_TIME := 3.0
const DEFUSE_TIME := 5.0
const DETONATE_TIME := 35.0
const ROUND_END_TIME := 6.0
const PICKUP_RADIUS := 2.6

var ms: MatchServer
var m: Dictionary = CorebreakRules.new_match()
var phase := "pre_round"
var phase_t := PRE_ROUND_TIME
var time_left := ROUND_TIME
var detonate_t := 0.0
var core_mode := "spawned"
var core_pos := Vector3.ZERO
var carrier := 0
var planted_site := ""
var plant_progress := 0.0
var plant_player := 0
var defuse_progress := 0.0
var defuse_player := 0
var defused_by := 0


func _init(server: MatchServer) -> void:
	ms = server


func begin() -> void:
	_start_round()


func attacking_team() -> int:
	return CorebreakRules.attacking_team(m)


func defending_team() -> int:
	return 3 - attacking_team()


func role_of(team: int) -> String:
	return "attack" if attacking_team() == team else "defend"


func spawn_protection() -> float:
	return 0.0


# ---------------------------------------------------------------- round flow
func _start_round() -> void:
	phase = "pre_round"
	ms.phase = phase
	phase_t = PRE_ROUND_TIME
	time_left = ROUND_TIME
	core_mode = "spawned"
	core_pos = ms.def.core_spawn
	carrier = 0
	planted_site = ""
	plant_progress = 0.0
	plant_player = 0
	defuse_progress = 0.0
	defuse_player = 0
	defused_by = 0
	detonate_t = 0.0
	ms.cancel_respawns()
	ms.clear_echoes("round_reset")
	var idx := {1: 0, 2: 0, 0: 0}
	for p in Game.players.values():
		if not is_instance_valid(p):
			continue
		var sp: Dictionary = ms.def.pick_spawn(role_of(p.team), idx[p.team])
		idx[p.team] += 1
		Game.rpc_respawn.rpc(p.id, sp["position"], sp["yaw"], 0.0)
		p.frozen = true
		p.echo_cd = 0.0
	ms.push_state()
	var atk := attacking_team()
	Game.rpc_notice.rpc("ROUND %d%s\n%s ATTACK  ·  %s DEFEND" % [m["round"], " / OVERTIME" if m["overtime"] else "", Palette.team_name(atk), Palette.team_name(3 - atk)], PRE_ROUND_TIME)
	Game.log_ev("Round", "start", {"round": m["round"], "attack": atk, "overtime": m["overtime"], "wins": m["wins"]})


func _go_live() -> void:
	phase = "live"
	ms.phase = phase
	time_left = ROUND_TIME
	for p in Game.players.values():
		if is_instance_valid(p):
			p.frozen = false
	ms.push_state()
	Game.rpc_notice.rpc("LIVE\nATTACK: plant the Core at A or B   ·   DEFEND: stop the plant or defuse", 3.0)
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
			_step_core(delta)
			_check_result()
		"planted":
			detonate_t = maxf(0.0, detonate_t - delta)
			time_left = detonate_t
			_step_defuse(delta)
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


func _step_core(delta: float) -> void:
	if core_mode == "spawned" or core_mode == "dropped":
		for p in Game.players.values():
			if not is_instance_valid(p) or not p.alive or p.frozen:
				continue
			if role_of(p.team) != "attack":
				continue
			var d := Vector2(p.global_position.x - core_pos.x, p.global_position.z - core_pos.z).length()
			if d <= PICKUP_RADIUS and absf(p.global_position.y - core_pos.y) < 3.0:
				core_mode = "carried"
				carrier = p.id
				p.carrying_core = true
				Game.rpc_notice.rpc("%s PICKED UP THE RESONANCE CORE" % p.pname, 2.0)
				Game.log_ev("Objective", "pickup", {"id": p.id})
				ms.push_state()
				break
	elif core_mode == "carried":
		var c = Game.players.get(carrier)
		if c == null or not is_instance_valid(c) or not c.alive:
			_drop_core(c)
			return
		core_pos = c.global_position
		var site: String = ms.def.in_site(c.global_position)
		if site != "" and c.interact_held and not c.frozen:
			if plant_player != c.id:
				plant_player = c.id
				plant_progress = 0.0
			plant_progress += delta
			if plant_progress >= PLANT_TIME:
				_plant(site, c)
		elif plant_player == c.id:
			plant_progress = 0.0
			plant_player = 0


func _drop_core(c) -> void:
	core_mode = "dropped"
	if c != null and is_instance_valid(c):
		core_pos = c.global_position
		c.carrying_core = false
	if core_pos.y < ms.def.kill_y + 2.0:
		core_pos = ms.def.core_spawn
	carrier = 0
	plant_progress = 0.0
	plant_player = 0
	Game.rpc_notice.rpc("THE CORE WAS DROPPED", 2.0)
	Game.log_ev("Objective", "drop", {"pos": [core_pos.x, core_pos.y, core_pos.z]})
	ms.push_state()


func _plant(site: String, c: Player) -> void:
	core_mode = "planted"
	planted_site = site
	core_pos = ms.def.sites[site]["position"]
	carrier = 0
	c.carrying_core = false
	plant_progress = 0.0
	plant_player = 0
	defuse_progress = 0.0
	defuse_player = 0
	phase = "planted"
	ms.phase = phase
	detonate_t = DETONATE_TIME
	ms.push_state()
	Game.rpc_notice.rpc("CORE PLANTED AT SITE %s\nDEFENDERS: hold E on the Core to defuse (%d s)" % [site, int(DEFUSE_TIME)], 3.0)
	Game.log_ev("Objective", "plant", {"site": site, "by": c.id})


func _step_defuse(delta: float) -> void:
	var found := 0
	for p in Game.players.values():
		if not is_instance_valid(p) or not p.alive or role_of(p.team) != "defend":
			continue
		if ms.def.in_site(p.global_position) == planted_site and p.interact_held:
			found = p.id
			break
	if found != 0:
		if defuse_player != found:
			defuse_player = found
			defuse_progress = 0.0
		defuse_progress += delta
		if defuse_progress >= DEFUSE_TIME:
			defused_by = found
			Game.log_ev("Objective", "defuse", {"by": found, "site": planted_site})
			_check_result()
	elif defuse_progress > 0.0:
		defuse_progress = 0.0
		defuse_player = 0


func _alive_counts() -> Dictionary:
	var atk := 0
	var dfn := 0
	for p in Game.players.values():
		if not is_instance_valid(p) or not p.alive:
			continue
		if role_of(p.team) == "attack":
			atk += 1
		else:
			dfn += 1
	return {"attack": atk, "defend": dfn}


func _check_result() -> void:
	if phase != "live" and phase != "planted":
		return
	var ac := _alive_counts()
	var r := CorebreakRules.resolve({
		"detonated": phase == "planted" and detonate_t <= 0.0,
		"defused": defused_by != 0,
		"attackers_alive": ac["attack"],
		"defenders_alive": ac["defend"],
		"time_left": time_left if phase == "live" else 1.0,
		"planted": phase == "planted",
	})
	if r != "":
		_finish_round(r)


func _finish_round(result: String) -> void:
	var parts := result.split(":")
	var winner_team := attacking_team() if parts[0] == "attack" else defending_team()
	var reason := parts[1]
	var round_no := int(m["round"])
	phase = "round_end"
	ms.phase = phase
	phase_t = ROUND_END_TIME
	for p in Game.players.values():
		if is_instance_valid(p):
			p.frozen = true
			p.carrying_core = false
			p.interact_held = false
	ms.clear_echoes("round_end")
	var reason_text: String = {
		"detonation": "THE CORE DETONATED",
		"defuse": "THE CORE WAS DEFUSED",
		"eliminated": "OPPOSING SQUAD ELIMINATED",
		"timer": "TIME EXPIRED BEFORE A PLANT",
	}.get(reason, reason.to_upper())
	CorebreakRules.record_round(m, winner_team)
	for id in Net.players:
		if int(Net.players[id]["team"]) == winner_team:
			Net.players[id]["points"] = int(Net.players[id]["points"]) + 1
	Net.broadcast_players()
	ms.push_state()
	Game.rpc_notice.rpc("%s WINS ROUND %d\n%s   ·   %d - %d" % [Palette.team_name(winner_team), round_no, reason_text, m["wins"][1], m["wins"][2]], ROUND_END_TIME - 0.5)
	Game.log_ev("Round", "end", {"round": round_no, "winner": winner_team, "reason": reason, "wins": m["wins"], "overtime": m["overtime"], "match_winner": m["winner"]})


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
	var r := {
		"mode": "corebreak",
		"map": Game.map_id,
		"winner_text": "%s WINS %d - %d" % [Palette.team_name(w), m["wins"][w], m["wins"][3 - w]],
		"reason": "Match decided after %d rounds%s." % [int(m["round"]) - 1, " including overtime" if m["overtime"] else ""],
		"rows": rows,
		"winner_team": w,
	}
	Game.rpc_results.rpc(r)
	Game.log_ev("Match", "end", {"winner": w, "wins": m["wins"], "rounds": int(m["round"]) - 1})


# ---------------------------------------------------------------- hooks from MatchServer
func on_player_died(victim: Player, _killer_id: int, _cause: String) -> void:
	if carrier == victim.id:
		_drop_core(victim)
	if plant_player == victim.id:
		plant_progress = 0.0
		plant_player = 0
	if defuse_player == victim.id:
		defuse_progress = 0.0
		defuse_player = 0
	_check_result()


func on_damaged(victim: Player, _from_id: int, _cause: String) -> void:
	if plant_player == victim.id and plant_progress > 0.0:
		plant_progress = 0.0
		plant_player = 0
		if victim.id > 0:
			Game.rpc_notice.rpc_id(victim.id, "PLANT INTERRUPTED", 1.5)
	if defuse_player == victim.id and defuse_progress > 0.0:
		defuse_progress = 0.0
		defuse_player = 0
		if victim.id > 0:
			Game.rpc_notice.rpc_id(victim.id, "DEFUSE INTERRUPTED", 1.5)


func on_player_left(id: int) -> void:
	if carrier == id:
		core_mode = "dropped"
		carrier = 0
		plant_progress = 0.0
		plant_player = 0
		ms.push_state()
	if defuse_player == id:
		defuse_progress = 0.0
		defuse_player = 0
	_check_result()


func on_out_of_bounds(_p: Player) -> void:
	pass


# ---------------------------------------------------------------- replication
func state_dict() -> Dictionary:
	return {
		"mode": "corebreak",
		"phase": phase,
		"round": int(m["round"]),
		"scores": m["wins"],
		"roles": {1: role_of(1).to_upper(), 2: role_of(2).to_upper()},
		"overtime": bool(m["overtime"]),
		"core": {"planted_site": planted_site, "mode": core_mode},
		"objective": "",
	}


func live_dict() -> Dictionary:
	var d := {"core": {"mode": core_mode, "pos": core_pos, "carrier": carrier, "site": planted_site, "detonate": detonate_t}}
	if plant_player != 0:
		d["interaction"] = {"player": plant_player, "label": "PLANTING THE CORE", "fraction": plant_progress / PLANT_TIME}
	elif defuse_player != 0:
		d["interaction"] = {"player": defuse_player, "label": "DEFUSING", "fraction": defuse_progress / DEFUSE_TIME}
	return d
