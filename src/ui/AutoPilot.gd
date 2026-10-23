class_name AutoPilot
extends Node
## Scripted input for automated tests (enabled with `-- --auto=<pattern>`). Produces the same
## [move, yaw, pitch, buttons] tuple a human would, so the whole server path is exercised.

var pattern := "idle"
var t := 0.0
var _fire_toggle := false


func produce(p: Player) -> Array:
	t += 1.0 / 60.0
	var move := Vector2.ZERO
	var yaw := p.yaw
	var pitch := 0.0
	var b := 0
	var parts := pattern.split(":")
	match parts[0]:
		"idle":
			pass
		"forward":
			move = Vector2(0, -1)
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
			var target := _nearest_enemy(p)
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
		"goto":
			var tx := float(parts[1]) if parts.size() > 1 else 0.0
			var tz := float(parts[2]) if parts.size() > 2 else 0.0
			var to := Vector3(tx, p.global_position.y, tz) - p.global_position
			if to.length() > 1.5:
				yaw = atan2(-to.x, -to.z)
				move = Vector2(0, -1)
			if parts.size() > 3 and parts[3] == "interact":
				b |= Player.BTN_INTERACT
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
	return [move, yaw, pitch, b]


func _nearest_enemy(p: Player) -> Player:
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
