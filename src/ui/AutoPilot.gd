class_name AutoPilot
extends Node
## Scripted input for automated tests (enabled with `-- --auto=<pattern>`). Produces the same
## [move, yaw, pitch, buttons] tuple a human would, so the whole server path is exercised.
## Patterns: idle | forward | sprint | circle | strafe | spin_fire | hunt | echo_loop | dash_loop
##           nav,X,Z[,interact]      walk the navmesh to (X, Z); optionally hold E on arrival
##           seq:step+step+...       run steps in order; steps use ',' between args, e.g.
##           seq:nav,-50,0+nav,40,-26,interact   or   seq:wait,5+hunt

var pattern := "idle"
var t := 0.0
var _fire_toggle := false
var _steps: Array = []
var _step_i := 0
var _step_t := 0.0
var _path: PackedVector3Array = PackedVector3Array()
var _path_i := 0
var _repath_t := 0.0
var _path_target := Vector3.ZERO


func produce(p: Player) -> Array:
	t += 1.0 / 60.0
	if pattern.begins_with("seq:"):
		if _steps.is_empty():
			for s in pattern.substr(4).split("+"):
				_steps.append(s.split(","))
		if _step_i >= _steps.size():
			return [Vector2.ZERO, p.yaw, p.pitch, 0]
		var step: PackedStringArray = _steps[_step_i]
		_step_t += 1.0 / 60.0
		var result := _run(step, p)
		if result["done"]:
			_step_i += 1
			_step_t = 0.0
			_path = PackedVector3Array()
		return result["input"]
	return _run(PackedStringArray(pattern.split(",")), p)["input"]


func _run(step: PackedStringArray, p: Player) -> Dictionary:
	var move := Vector2.ZERO
	var yaw := p.yaw
	var pitch := 0.0
	var b := 0
	var done := false
	match step[0]:
		"idle":
			pass
		"wait":
			pitch = p.pitch
			done = _step_t >= float(step[1]) if step.size() > 1 else true
		"forward":
			move = Vector2(0, -1)
		"walk":
			move = Vector2(0, -1)
			done = _step_t >= (float(step[1]) if step.size() > 1 else 1.0)
		"sprint":
			move = Vector2(0, -1)
			b |= Player.BTN_SPRINT
		"circle":
			move = Vector2(0, -1)
			yaw = p.yaw + 0.02
		"strafe":
			move = Vector2(1 if fmod(t, 2.0) < 1.0 else -1, 0)
		"spin_fire":
			yaw = p.yaw + 0.05
			_fire_toggle = not _fire_toggle
			if _fire_toggle:
				b |= Player.BTN_FIRE
		"hunt":
			var target := nearest_enemy(p)
			if target != null:
				var to := target.global_position + Vector3(0, 1.3, 0) - p.eye_position()
				yaw = atan2(-to.x, -to.z)
				pitch = atan2(to.y, Vector2(to.x, to.z).length())
				if to.length() > 9.0:
					move = Vector2(0, -1)
				_fire_toggle = not _fire_toggle
				if _fire_toggle and absf(wrapf(yaw - p.yaw, -PI, PI)) < 0.1:
					b |= Player.BTN_FIRE
			else:
				yaw = p.yaw + 0.03
		"nav", "navy":
			var target := Vector3(float(step[1]), p.global_position.y, float(step[2]))
			var flag_i := 3
			if step[0] == "navy":
				target = Vector3(float(step[1]), float(step[2]), float(step[3]))
				flag_i = 4
			var r := nav_step(p, target)
			yaw = r["yaw"]
			move = r["move"]
			if r["arrived"]:
				if step.size() > flag_i and step[flag_i] == "interact":
					b |= Player.BTN_INTERACT
				else:
					done = true
		"aim":
			var to := Vector3(float(step[1]), float(step[2]), float(step[3])) - p.eye_position()
			yaw = atan2(-to.x, -to.z)
			pitch = atan2(to.y, Vector2(to.x, to.z).length())
			p.yaw = yaw
			p.pitch = pitch
			done = _step_t > 0.3
		"slot":
			var n := int(step[1]) if step.size() > 1 else 1
			b |= [Player.BTN_SLOT1, Player.BTN_SLOT2, Player.BTN_SLOT3, Player.BTN_SLOT4][clampi(n - 1, 0, 3)]
			done = true
		"hold_fire":
			pitch = p.pitch
			b |= Player.BTN_FIRE
			done = _step_t > (float(step[1]) if step.size() > 1 else 1.0)
		"echo", "ability":
			b |= Player.BTN_ECHO
			done = _step_t > 0.2
		"fire":
			pitch = p.pitch
			_fire_toggle = not _fire_toggle
			if _fire_toggle:
				b |= Player.BTN_FIRE
			done = _step_t > (float(step[1]) if step.size() > 1 else 1.0)
		"echo_loop":
			move = Vector2(0, -1)
			yaw = p.yaw + 0.03
			if fmod(t, 4.0) < 0.1:
				b |= Player.BTN_ECHO
			if fmod(t, 1.0) < 0.05:
				b |= Player.BTN_FIRE
		"dash_loop":
			move = Vector2(0, -1)
			if fmod(t, 5.0) < 0.05:
				b |= Player.BTN_DASH
	return {"input": [move, yaw, pitch, b], "done": done}


## Navmesh path following shared with bots: returns {"yaw", "move", "arrived"}.
func nav_step(p: Player, target: Vector3) -> Dictionary:
	_repath_t -= 1.0 / 60.0
	if _path.is_empty() or _repath_t <= 0.0 or _path_target.distance_to(target) > 0.5:
		var map_rid := p.get_world_3d().navigation_map
		_path = NavigationServer3D.map_get_path(map_rid, p.global_position, target, true)
		_path_i = 0
		_repath_t = 1.0
		_path_target = target
	var flat_target := Vector2(target.x, target.z)
	var here := Vector2(p.global_position.x, p.global_position.z)
	if here.distance_to(flat_target) < 1.4 and absf(p.global_position.y - target.y) < 2.5:
		return {"yaw": p.yaw, "move": Vector2.ZERO, "arrived": true}
	var goal := target
	while _path_i < _path.size():
		var wp := _path[_path_i]
		if Vector2(wp.x, wp.z).distance_to(here) < 0.9:
			_path_i += 1
		else:
			goal = wp
			break
	if _path.is_empty():
		goal = target
	var to := goal - p.global_position
	var yaw := atan2(-to.x, -to.z)
	return {"yaw": yaw, "move": Vector2(0, -1), "arrived": false}


static func nearest_enemy(p: Player) -> Player:
	var best: Player = null
	var best_d := 1e9
	for other in Game.players.values():
		if not is_instance_valid(other) or other == p or not other.alive:
			continue
		if p.team != 0 and other.team == p.team:
			continue
		var d: float = other.global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = other
	return best
