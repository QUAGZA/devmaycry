class_name BotBrain
extends RefCounted
## Server-side AI for bot combatants. Perception is line-of-sight only (no wallhacks), aim is
## imperfect, and decisions are staggered on timers. Difficulty changes reaction time, aim error,
## decision cadence, aggression, engagement range and ability use.

const PROFILES := {
	"easy": {"reaction": 0.95, "aim_err": 0.085, "decide": 0.9, "aggro": 0.3, "echo": 0.05, "fire_gap": 0.55, "range": 38.0, "rotate": 0.1, "dash": 0.1},
	"medium": {"reaction": 0.55, "aim_err": 0.045, "decide": 0.55, "aggro": 0.6, "echo": 0.25, "fire_gap": 0.32, "range": 55.0, "rotate": 0.35, "dash": 0.3},
	"hard": {"reaction": 0.32, "aim_err": 0.024, "decide": 0.3, "aggro": 0.85, "echo": 0.5, "fire_gap": 0.2, "range": 70.0, "rotate": 0.6, "dash": 0.55},
}
const FOV_COS := 0.25  # ~75 degrees each side

var p: Player
var prof: Dictionary
var difficulty := "medium"
var target: Player = null
var target_seen_t := 0.0
var lost_t := 0.0
var last_seen_pos := Vector3.ZERO
var decide_t := 0.0
var goal := Vector3.ZERO
var goal_kind := ""
var path: PackedVector3Array = PackedVector3Array()
var path_i := 0
var repath_t := 0.0
var fire_t := 0.0
var strafe_dir := 1.0
var strafe_t := 0.0
var aim_yaw := 0.0
var aim_pitch := 0.0
var err_yaw := 0.0
var err_pitch := 0.0
var err_t := 0.0
var stuck_t := 0.0
var stuck_pos := Vector3.ZERO
var stuck_count := 0          # consecutive stuck episodes on the current goal
var jumped_this_goal := false # at most one recovery jump per goal (no jump spam)
var sidestep_t := 0.0
var sidestep_dir := 1.0
var blocked_goals: Array = [] # [{pos, until}] goals abandoned as unreachable, avoided for a while
var raw_goal := Vector3.ZERO
var trace_t := 0.0
var site_pref := ""
var last_hp := 100.0
var hurt_t := 0.0
var rng := RandomNumberGenerator.new()
var want_ability := false


func _init(player: Player, diff: String) -> void:
	p = player
	difficulty = diff
	prof = PROFILES.get(diff, PROFILES["medium"])
	rng.randomize()
	aim_yaw = p.yaw
	stuck_pos = p.global_position


func think(delta: float) -> void:
	if not p.alive or p.frozen:
		p.inp_move = Vector2.ZERO
		p.inp_buttons = 0
		target = null
		goal_kind = ""
		return
	if p.hp < last_hp:
		hurt_t = 1.5
	last_hp = p.hp
	hurt_t = maxf(0.0, hurt_t - delta)
	_perceive(delta)
	decide_t -= delta
	if decide_t <= 0.0:
		decide_t = float(prof["decide"]) * rng.randf_range(0.8, 1.25)
		_decide()
	var buttons := 0
	var move := Vector2.ZERO
	var path_yaw := aim_yaw
	var arrived := false
	if goal_kind != "":
		var r := _follow(delta)
		move = r["move"]
		path_yaw = r["yaw"]
		arrived = r["arrived"]
	var engaging := target != null and target_seen_t >= float(prof["reaction"])
	if engaging:
		var to := target.global_position + Vector3(0, 1.25, 0) - p.eye_position()
		var dist := to.length()
		err_t -= delta
		if err_t <= 0.0:
			err_t = 0.18
			var e := float(prof["aim_err"]) * (1.0 + dist * 0.015)
			err_yaw = rng.randfn(0.0, e)
			err_pitch = rng.randfn(0.0, e * 0.7)
		var want_yaw := atan2(-to.x, -to.z) + err_yaw
		var want_pitch := atan2(to.y, Vector2(to.x, to.z).length()) + err_pitch
		aim_yaw = lerp_angle(aim_yaw, want_yaw, minf(1.0, delta * 9.0))
		aim_pitch = lerpf(aim_pitch, want_pitch, minf(1.0, delta * 9.0))
		fire_t -= delta
		var aligned := absf(wrapf(aim_yaw - want_yaw + err_yaw, -PI, PI)) < 0.09
		if fire_t <= 0.0 and dist < float(prof["range"]) and aligned and p.ammo > 0 and p.reload_t <= 0.0:
			buttons |= Player.BTN_FIRE
			fire_t = float(prof["fire_gap"]) * rng.randf_range(0.8, 1.3)
		if p.ammo == 0:
			buttons |= Player.BTN_RELOAD
		strafe_t -= delta
		if strafe_t <= 0.0:
			strafe_t = rng.randf_range(0.5, 1.4)
			if rng.randf() < 0.6:
				strafe_dir = -strafe_dir
		var objective_focus := goal_kind in ["plant", "defuse", "core", "field"] and arrived
		if objective_focus:
			move = Vector2.ZERO
		elif goal_kind in ["plant", "defuse", "core", "beacon", "shard"] and not arrived and rng.randf() < 0.7:
			pass  # keep pushing the objective while shooting
		else:
			var fwd := 0.0
			if dist > 16.0 and rng.randf() < float(prof["aggro"]):
				fwd = -0.6
			elif dist < 5.0:
				fwd = 0.5
			move = Vector2(strafe_dir * 0.8, fwd)
			if p.dash_cd <= 0.0 and hurt_t > 0.0 and rng.randf() < float(prof["dash"]) * delta * 4.0:
				buttons |= Player.BTN_DASH
		if Game.match_server != null and Game.match_server.mode == "relic_rush" and not p.re_spent and p.hp < 50.0 and rng.randf() < float(prof["echo"]) * delta * 0.8 and dist < 40.0 and p.recorder.has_span(5.9):
			buttons |= Player.BTN_ECHO
	else:
		if move != Vector2.ZERO:
			aim_yaw = lerp_angle(aim_yaw, path_yaw, minf(1.0, delta * 6.0))
		aim_pitch = lerpf(aim_pitch, 0.0, minf(1.0, delta * 4.0))
		if p.ammo < Player.MAG_SIZE and p.reload_t <= 0.0 and rng.randf() < 0.02:
			buttons |= Player.BTN_RELOAD
		if move != Vector2.ZERO and goal_kind in ["core", "site", "beacon", "shard", "rotate", "escort", "investigate", "chase", "stabilize"]:
			buttons |= Player.BTN_SPRINT
	if arrived and goal_kind in ["plant", "defuse"]:
		buttons |= Player.BTN_INTERACT
		move = Vector2.ZERO
	# stuck detection: replan first, then sidestep, a single jump at most, then abandon the goal
	if sidestep_t > 0.0:
		sidestep_t -= delta
		move = Vector2(sidestep_dir, 0.4)
	if move != Vector2.ZERO:
		stuck_t += delta
		if stuck_t > 1.2:
			if p.global_position.distance_to(stuck_pos) < 0.5:
				stuck_count += 1
				path = PackedVector3Array()
				repath_t = 0.0
				if stuck_count == 2:
					sidestep_t = 0.6
					sidestep_dir = -1.0 if rng.randf() < 0.5 else 1.0
				elif stuck_count == 3 and not jumped_this_goal:
					buttons |= Player.BTN_JUMP
					jumped_this_goal = true
					Game.log_ev("Bot", "stuck_jump", {"id": p.id, "pos": [snappedf(p.global_position.x, 0.1), snappedf(p.global_position.z, 0.1)]})
				elif stuck_count >= 4:
					blocked_goals.append({"pos": goal, "until": Time.get_ticks_msec() / 1000.0 + 12.0})
					if blocked_goals.size() > 8:
						blocked_goals.pop_front()
					Game.log_ev("Bot", "goal_abandoned", {"id": p.id, "goal": [snappedf(goal.x, 0.1), snappedf(goal.y, 0.1), snappedf(goal.z, 0.1)], "kind": goal_kind})
					goal_kind = ""
					stuck_count = 0
					decide_t = 0.0
			else:
				stuck_count = 0
			stuck_t = 0.0
			stuck_pos = p.global_position
	else:
		stuck_t = 0.0
		stuck_pos = p.global_position
	if Game.args.has("bot-trace"):
		trace_t -= delta
		if trace_t <= 0.0:
			trace_t = 4.0
			Game.log_ev("BotTrace", "state", {"id": p.id, "team": p.team, "pos": [snappedf(p.global_position.x, 0.1), snappedf(p.global_position.y, 0.1), snappedf(p.global_position.z, 0.1)], "goal": [snappedf(goal.x, 0.1), snappedf(goal.y, 0.1), snappedf(goal.z, 0.1)], "kind": goal_kind, "target": target.id if target != null else 0, "engaging": engaging, "path": path.size()})
	if want_ability:
		buttons |= Player.BTN_ECHO
		want_ability = false
	p.inp_move = move
	p.yaw = wrapf(aim_yaw, -PI, PI)
	p.pitch = clampf(aim_pitch, -1.2, 1.2)
	p.inp_buttons = buttons


# ---------------------------------------------------------------- perception
func _perceive(delta: float) -> void:
	var best: Player = null
	var best_d := 1e9
	var facing := p.aim_dir()
	for other: Player in Game.players.values():
		if not is_instance_valid(other) or other == p or not other.alive:
			continue
		if p.team != 0 and other.team == p.team:
			continue
		var to := other.global_position + Vector3(0, 1.2, 0) - p.eye_position()
		var d := to.length()
		if d > float(prof["range"]) + 15.0:
			continue
		var dir := to / maxf(d, 0.001)
		var in_fov := dir.dot(facing) > FOV_COS or d < 4.0 or (other == target)
		if not in_fov:
			continue
		if not _has_los(other):
			continue
		if d < best_d:
			best_d = d
			best = other
	if best != null:
		if best != target:
			target = best
			target_seen_t = 0.0
		else:
			target_seen_t += delta
		last_seen_pos = best.global_position
		lost_t = 0.0
	else:
		lost_t += delta
		if lost_t > 2.0:
			target = null
			target_seen_t = 0.0
	# being shot is a cue: face the attacker and go investigate (medium/hard)
	if target == null and p.last_attacker != 0 and hurt_t > 0.0 and difficulty != "easy":
		var a: Player = Game.players.get(p.last_attacker)
		if a != null and is_instance_valid(a) and a.alive:
			var to := a.global_position - p.global_position
			aim_yaw = atan2(-to.x, -to.z)
			if goal_kind in ["guard", "patrol", "rotate", ""] and rng.randf() < float(prof["aggro"]):
				goal = a.global_position
				goal_kind = "investigate"
				path = PackedVector3Array()


func _has_los(other: Player) -> bool:
	var space := p.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p.eye_position(), other.global_position + Vector3(0, 1.2, 0), 1, [p.get_rid()])
	var hit := space.intersect_ray(q)
	return hit.is_empty()


# ---------------------------------------------------------------- decisions
func _decide() -> void:
	var ms := Game.match_server
	if ms == null:
		return
	var rules = ms.rules
	if rules == null:
		_decide_warmup()
		return
	if ms.mode == "corebreak":
		_decide_corebreak(rules)
	elif ms.mode == "hot_return":
		_decide_hotreturn(rules)
	else:
		_decide_relic(rules)


func _set_goal(pos: Vector3, kind: String) -> void:
	# Root-cause fix for the "jumping at the tower" loop: goals are snapped to the closest point of the
	# navigation mesh, so a target inside a collider (e.g. the old Relic beacon inside the central
	# obelisk) becomes the nearest reachable spot instead of an unreachable point the bot walks into.
	var nav_pos := pos
	var map_rid := p.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map_rid) > 0:
		nav_pos = NavigationServer3D.map_get_closest_point(map_rid, pos)
		if nav_pos == Vector3.ZERO and pos.length() > 1.0:
			nav_pos = pos
	var now := Time.get_ticks_msec() / 1000.0
	for b in blocked_goals:
		if float(b["until"]) > now and Vector3(b["pos"]).distance_to(nav_pos) < 2.5:
			return
	if goal_kind != kind or goal.distance_to(nav_pos) > 2.0:
		path = PackedVector3Array()
		repath_t = 0.0
		stuck_count = 0
		jumped_this_goal = false
	raw_goal = pos
	goal = nav_pos
	goal_kind = kind


func _decide_warmup() -> void:
	if target != null:
		_set_goal(target.global_position, "investigate")
	elif goal_kind == "" or (goal_kind == "patrol" and p.global_position.distance_to(goal) < 3.0):
		var sp: Dictionary = Game.map_def.pick_spawn("ffa", rng.randi_range(0, 7))
		_set_goal(sp["position"], "patrol")


func _decide_corebreak(rules) -> void:
	var def: MapDef = Game.map_def
	var role: String = rules.role_of(p.team)
	var phase: String = rules.phase
	if site_pref == "" or rng.randf() < 0.02:
		site_pref = "A" if (p.glyph_index % 2 == 0) == (rng.randf() < 0.8) else "B"
	if role == "attack":
		if phase == "planted":
			var sp: Vector3 = def.sites[rules.planted_site]["position"]
			_set_goal(sp + _orbit_offset(7.0), "guard")
			return
		if rules.core_mode == "carried" and rules.carrier == p.id:
			if difficulty == "hard" and target != null:
				site_pref = _safer_site(def)
			_set_goal(def.sites[site_pref]["position"] + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2)), "plant")
			return
		if rules.core_mode == "spawned" or rules.core_mode == "dropped":
			var core_pos: Vector3 = rules.core_pos
			if _closest_attacker_to(core_pos, rules) == p.id or rng.randf() < 0.3:
				_set_goal(core_pos, "core")
			else:
				_set_goal(def.sites[site_pref]["position"] + _orbit_offset(9.0), "site")
			return
		if rules.core_mode == "carried":
			var c: Player = Game.players.get(rules.carrier)
			if c != null and is_instance_valid(c):
				_set_goal(c.global_position + _orbit_offset(5.0), "escort")
				return
		_set_goal(def.sites[site_pref]["position"] + _orbit_offset(9.0), "site")
	else:
		if phase == "planted":
			var sp: Vector3 = def.sites[rules.planted_site]["position"]
			_set_goal(sp + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5)), "defuse")
			return
		if goal_kind == "defuse":
			goal_kind = ""
		var want_rotate := rng.randf() < float(prof["rotate"]) * 0.5
		if goal_kind == "" or goal_kind == "investigate" or want_rotate:
			var guard_site := site_pref
			if want_rotate and difficulty != "easy":
				guard_site = "B" if site_pref == "A" else "A"
				site_pref = guard_site
			var sp: Vector3 = def.sites[guard_site]["position"]
			var toward_mid := (Vector3.ZERO - sp).normalized()
			_set_goal(sp + toward_mid * rng.randf_range(6.0, 14.0) + _orbit_offset(4.0), "guard")
		elif goal_kind == "guard" and p.global_position.distance_to(goal) < 2.5 and rng.randf() < 0.5:
			var sp: Vector3 = def.sites[site_pref]["position"]
			_set_goal(sp + _orbit_offset(rng.randf_range(4.0, 12.0)), "patrol")


func _decide_hotreturn(rules) -> void:
	var def: MapDef = Game.map_def
	var role: String = rules.role_of(p.team)
	var core: Dictionary = rules.core
	var mode := str(core["mode"])
	var core_pos: Vector3 = core["pos"]
	if role == "attack":
		if mode == "carried" and int(core["carrier"]) == p.id:
			var st: Vector3 = def.stabilizers.get(rules.attacking_team(), Vector3.ZERO)
			var dist := p.global_position.distance_to(st)
			var projected: float = float(core["v"]) + dist / HotReturnRules.CARRY_SPEED * HotReturnRules.RATE
			var here_field: int = rules._field_index_at(p.global_position)
			if here_field >= 0 and float(rules.field_allowance[here_field]) > 0.3 and projected > 92.0:
				_set_goal(p.global_position, "field")
				return
			if difficulty != "easy" and projected > 92.0:
				var best := -1
				var bd := 1e9
				for i in def.fields.size():
					if float(rules.field_allowance[i]) > 1.0:
						var d: float = p.global_position.distance_to(def.fields[i]["position"])
						if d < bd:
							bd = d
							best = i
				if best >= 0:
					_set_goal(def.fields[best]["position"], "field")
					return
			if not p.re_spent and difficulty != "easy" and p.hp < 45.0 and target != null and p.recorder.has_span(5.9) and rng.randf() < 0.6:
				want_ability = true
			_set_goal(st, "stabilize")
			return
		if mode == "cradle" or mode == "dropped" or mode == "locked":
			var lead_id := _closest_attacker_to(core_pos, rules)
			if lead_id == p.id or rng.randf() < 0.2:
				_set_goal(core_pos, "core")
			else:
				# push as a group: supporting attackers stay a few metres off the lead attacker
				var lead: Player = Game.players.get(lead_id)
				if lead != null and is_instance_valid(lead) and lead.alive:
					_set_goal(lead.global_position + _orbit_offset(4.0), "escort")
				else:
					_set_goal(core_pos + _orbit_offset(7.0), "escort")
			return
		if mode == "carried":
			var c: Player = Game.players.get(int(core["carrier"]))
			if c != null and is_instance_valid(c):
				_set_goal(c.global_position + _orbit_offset(5.0), "escort")
				return
		_set_goal(def.stabilizers.get(rules.attacking_team(), Vector3.ZERO) + _orbit_offset(6.0), "guard")
	else:
		var vault: Vector3 = def.vaults.get(rules.defending_team(), Vector3.ZERO)
		if mode == "cradle":
			if goal_kind != "guard" or p.global_position.distance_to(goal) < 2.0 or rng.randf() < float(prof["rotate"]) * 0.3:
				var toward_mid := (Vector3.ZERO - vault).normalized()
				_set_goal(vault + toward_mid * rng.randf_range(6.0, 16.0) + _orbit_offset(5.0), "guard")
			return
		if mode == "stabilized" or mode == "detonated":
			return
		_set_goal(core_pos + _orbit_offset(3.0), "chase")
		var ticking := mode == "carried" or mode == "dropped"
		if ticking and not p.ff_spent and p.global_position.distance_to(core_pos) < 7.0:
			var chance: float = {"easy": 0.15, "medium": 0.45, "hard": 0.8}.get(difficulty, 0.4)
			if rng.randf() < chance:
				want_ability = true


func _decide_relic(rules) -> void:
	var beacon: Dictionary = rules.beacon_info() if rules.has_method("beacon_info") else {}
	var shards: Array = rules.active_shards() if rules.has_method("active_shards") else []
	if target != null and rng.randf() < float(prof["aggro"]):
		_set_goal(target.global_position, "investigate")
		return
	if not beacon.is_empty() and (int(beacon.get("owner", 0)) != p.id or rng.randf() < 0.3):
		var bp: Vector3 = beacon["pos"]
		if p.global_position.distance_to(bp) > 4.0 or int(beacon.get("owner", 0)) != p.id:
			_set_goal(bp + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2)), "beacon")
			return
	if not shards.is_empty():
		var best: Vector3 = shards[0]
		var bd := 1e9
		for s in shards:
			var d: float = p.global_position.distance_to(s)
			if d < bd:
				bd = d
				best = s
		_set_goal(best, "shard")
		return
	if goal_kind == "" or p.global_position.distance_to(goal) < 3.0:
		var sp: Dictionary = Game.map_def.pick_spawn("ffa", rng.randi_range(0, 7))
		_set_goal(sp["position"], "patrol")


func _orbit_offset(r: float) -> Vector3:
	var a := rng.randf_range(0.0, TAU)
	return Vector3(cos(a) * r, 0, sin(a) * r)


func _closest_attacker_to(pos: Vector3, rules) -> int:
	var best := 0
	var bd := 1e9
	for other: Player in Game.players.values():
		if not is_instance_valid(other) or not other.alive or rules.role_of(other.team) != "attack":
			continue
		var d: float = other.global_position.distance_to(pos)
		if d < bd:
			bd = d
			best = other.id
	return best


func _safer_site(def: MapDef) -> String:
	if target == null:
		return site_pref
	var da: float = target.global_position.distance_to(def.sites["A"]["position"])
	var db: float = target.global_position.distance_to(def.sites["B"]["position"])
	return "A" if da > db else "B"


# ---------------------------------------------------------------- navigation
func _follow(delta: float) -> Dictionary:
	repath_t -= delta
	var flat_goal := Vector2(goal.x, goal.z)
	var here := Vector2(p.global_position.x, p.global_position.z)
	var arrive_r := 2.2 if goal_kind in ["plant", "defuse"] else 1.6
	if here.distance_to(flat_goal) < arrive_r:
		return {"move": Vector2.ZERO, "yaw": aim_yaw, "arrived": true}
	if path.is_empty() or repath_t <= 0.0:
		var map_rid := p.get_world_3d().navigation_map
		# navigation layer 2 holds the ladder links: open to everyone except a Core carrier (two hands on the Core)
		path = NavigationServer3D.map_get_path(map_rid, p.global_position, goal, true, 1 if p.carrying_core else 3)
		path_i = 0
		repath_t = rng.randf_range(0.7, 1.1)
	var next := goal if path.is_empty() else path[path.size() - 1]
	if not path.is_empty():
		var end := path[path.size() - 1]
		if Vector2(end.x, end.z).distance_to(here) < arrive_r and absf(end.y - p.global_position.y) < 2.5 and Vector2(end.x, end.z).distance_to(flat_goal) > arrive_r:
			# the reachable end of the path is as close as the bot can get: treat it as arrival
			return {"move": Vector2.ZERO, "yaw": aim_yaw, "arrived": true}
	while path_i < path.size():
		var wp := path[path_i]
		if Vector2(wp.x, wp.z).distance_to(here) < 1.0:
			path_i += 1
		else:
			next = wp
			break
	var to := next - p.global_position
	var yaw := atan2(-to.x, -to.z)
	# move relative to the current facing so bots can shoot one way and walk another
	var local := Basis(Vector3.UP, -p.yaw) * Vector3(to.x, 0, to.z)
	var m := Vector2(local.x, local.z)
	if m.length() > 0.001:
		m = m.normalized()
	return {"move": m, "yaw": yaw, "arrived": false}
