extends Node
## RPC hub (same node path on every peer), server orchestration and client mirror.
## The server owns: simulation, hits, damage, deaths, objectives, timers, echoes, results.

signal state_changed
signal player_spawned(id: int)
signal player_despawned(id: int)
signal notice(text: String, seconds: float)
signal kill_feed(killer_name: String, victim_name: String, cause: String, killer_id: int, victim_id: int)
signal shot_fx(shooter_id: int, from: Vector3, to: Vector3, hit_id: int)
signal damage_fx(victim_id: int, attacker_id: int, amount: float, hp_after: float, cause: String)
signal fx(kind: String, id: int, pos: Vector3)
signal match_scene_ready
signal echo_spawned(echo: Node)
signal results_ready(results: Dictionary)

const SNAPSHOT_EVERY := 2
const MAP_READY_TIMEOUT := 20.0

var args: Dictionary = {}
var world: Node3D = null
var map_def: MapDef = null
var players: Dictionary = {}
var local_player: Player = null
var state: Dictionary = {}
var results: Dictionary = {}
var live: Dictionary = {}
var spectating := ""
var time_left := 0.0
var server_tick := 0
var in_match := false
var map_id := "oracle_gardens"
var mode_id := "hot_return"
var match_server: MatchServer = null
var autopilot = null
var projectiles: ProjectileManager = null
var paused_local := false
var map_open := false
var echoes: Dictionary = {}
var props: Dictionary = {}
var menu_message := ""
var open_lobby_on_menu := false
var _map_ready: Dictionary = {}
var _map_ready_t := 0.0
var _waiting_spawn := false
var _quit_t := -1.0
var _shots: Array = []
var _shot_elapsed := 0.0
var _log_snap_t := 0.0
var _probed := false
var _window_logged := false
var _probe_stage := 0


func _ready() -> void:
	_parse_args()
	projectiles = ProjectileManager.new()
	projectiles.name = "Projectiles"
	add_child(projectiles)
	if args.has("quit-after-sec"):
		_quit_t = float(args["quit-after-sec"])
	if args.has("auto"):
		autopilot = AutoPilot.new()
		autopilot.pattern = str(args["auto"])
		add_child(autopilot)
	if args.has("screenshot-at"):
		for s in str(args["screenshot-at"]).split(","):
			_shots.append(float(s))
		_shots.sort()
	log_ev("Boot", "ready", {"args": args, "headless": DisplayServer.get_name() == "headless"})
	if DisplayServer.get_name() != "headless":
		if not Settings.cli_overrides_window():
			Settings.apply_window()
		var ws := DisplayServer.window_get_size()
		var ss := DisplayServer.screen_get_size()
		log_ev("Boot", "window", {"window": [ws.x, ws.y], "screen": [ss.x, ss.y], "viewport": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y]})
	if args.has("settings-test"):
		if str(args["settings-test"]) == "write":
			Settings.mouse_sensitivity = 0.0042
			Settings.master_volume = 0.37
			Settings.save_prefs()
			log_ev("Settings", "written", {"sens": Settings.mouse_sensitivity, "master": Settings.master_volume, "path": ProjectSettings.globalize_path(Settings.PATH)})
		else:
			log_ev("Settings", "read", {"sens": Settings.mouse_sensitivity, "master": Settings.master_volume})


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "true"


func log_ev(cat: String, ev: String, data: Dictionary = {}) -> void:
	var d := {"t": Time.get_ticks_msec(), "peer": multiplayer.get_unique_id(), "cat": cat, "ev": ev}
	d.merge(data)
	print("[EchoClash][%s] %s" % [cat, JSON.stringify(d)])


func local_id() -> int:
	return multiplayer.get_unique_id()


func is_server() -> bool:
	return multiplayer.is_server()


func player_name(id: int) -> String:
	var p = players.get(id)
	if p != null and is_instance_valid(p):
		return p.pname
	if Net.players.has(id):
		return str(Net.players[id]["name"])
	return "WORLD"


# ---------------------------------------------------------------- match flow
func host_start_match() -> void:
	if not multiplayer.is_server() or _waiting_spawn:
		return
	Net.lobby["locked"] = true
	Net.broadcast_lobby()
	Net.fill_bots()
	if not args.has("allow-empty-team"):
		Net.ensure_playable()
	mode_id = str(Net.lobby["mode"])
	map_id = str(Net.lobby["map"])
	_map_ready.clear()
	_map_ready_t = MAP_READY_TIMEOUT
	_waiting_spawn = true
	log_ev("Match", "start", {"mode": mode_id, "map": map_id, "players": Net.players.size()})
	rpc_load_map.rpc(map_id, mode_id)


@rpc("authority", "call_local", "reliable")
func rpc_load_map(map_id_: String, mode_id_: String) -> void:
	map_id = map_id_
	mode_id = mode_id_
	in_match = true
	paused_local = false
	results = {}
	_clear_match_nodes()
	_shot_elapsed = 0.0
	get_tree().change_scene_to_file("res://src/match/Match.tscn")


func _clear_match_nodes() -> void:
	players.clear()
	echoes.clear()
	props.clear()
	if projectiles != null:
		projectiles.clear()
	local_player = null
	world = null
	map_def = null
	state = {}
	live = {}
	spectating = ""
	if match_server != null:
		match_server.queue_free()
		match_server = null


func on_match_scene_ready(world_node: Node3D, def: MapDef) -> void:
	world = world_node
	map_def = def
	match_scene_ready.emit()
	log_ev("Match", "scene_ready", {"map": map_id})
	if multiplayer.is_server():
		_on_map_ready(1)
	else:
		rpc_map_ready.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func rpc_map_ready() -> void:
	if multiplayer.is_server():
		_on_map_ready(multiplayer.get_remote_sender_id())


func _on_map_ready(id: int) -> void:
	_map_ready[id] = true
	log_ev("Match", "map_ready", {"id": id})
	_try_spawn_all()


func _try_spawn_all() -> void:
	if not _waiting_spawn or world == null:
		return
	for id in Net.players:
		if id > 0 and not _map_ready.has(id):
			return
	_spawn_all()


func _spawn_all() -> void:
	_waiting_spawn = false
	for id in Net.players.keys():
		if id > 0 and not _map_ready.has(id):
			log_ev("Match", "drop_unready_peer", {"id": id})
			Net.players.erase(id)
	Net.broadcast_players()
	match_server = MatchServer.new()
	match_server.name = "MatchServer"
	add_child(match_server)
	match_server.setup(mode_id, map_def)
	var i := 0
	for id in Net.players:
		var info: Dictionary = Net.players[id]
		var sp: Dictionary = match_server.spawn_for(info, i)
		rpc_spawn_player.rpc(id, info, sp["position"], sp["yaw"])
		i += 1
	match_server.begin()


@rpc("authority", "call_local", "reliable")
func rpc_spawn_player(id: int, info: Dictionary, pos: Vector3, yaw: float) -> void:
	if world == null:
		return
	var holder := world.get_node("Players")
	if players.has(id) and is_instance_valid(players[id]):
		players[id].queue_free()
	var p := Player.new()
	p.setup(id, info)
	holder.add_child(p)
	p.global_position = pos
	p.yaw = yaw
	p.rotation.y = yaw
	p._net_pos = pos
	p._net_prev = pos
	players[id] = p
	if multiplayer.is_server() and bool(info.get("is_bot", false)) and ResourceLoader.exists("res://src/player/BotBrain.gd"):
		var brain_script = load("res://src/player/BotBrain.gd")
		p.brain = brain_script.new(p, str(info.get("difficulty", "medium")))
	if id == multiplayer.get_unique_id():
		local_player = p
		p.make_local()
	player_spawned.emit(id)
	log_ev("Match", "spawn", {"id": id, "name": info.get("name", ""), "team": info.get("team", 0), "bot": info.get("is_bot", false)})


@rpc("authority", "call_local", "reliable")
func rpc_despawn_player(id: int) -> void:
	if players.has(id):
		if is_instance_valid(players[id]):
			players[id].queue_free()
		players.erase(id)
		player_despawned.emit(id)


func on_peer_left(id: int) -> void:
	if match_server != null:
		match_server.on_player_left(id)
	if players.has(id):
		rpc_despawn_player.rpc(id)


func return_to_menu(message: String = "", keep_session: bool = false) -> void:
	menu_message = message
	in_match = false
	map_open = false
	_waiting_spawn = false
	_clear_match_nodes()
	open_lobby_on_menu = keep_session and Net.connected
	if not keep_session:
		Net.leave()
	paused_local = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://src/ui/Title.tscn")


## Host: everyone back to the lobby, session kept.
func host_back_to_lobby() -> void:
	if not multiplayer.is_server():
		return
	Net.lobby["locked"] = false
	Net.remove_all_bots()
	for id in Net.players:
		Net.players[id]["kills"] = 0
		Net.players[id]["deaths"] = 0
		Net.players[id]["points"] = 0
	Net.broadcast_players()
	Net.broadcast_lobby()
	rpc_back_to_lobby.rpc()


@rpc("authority", "call_local", "reliable")
func rpc_back_to_lobby() -> void:
	return_to_menu("", true)


func host_rematch() -> void:
	if not multiplayer.is_server():
		return
	Net.lobby["locked"] = false
	for id in Net.players:
		Net.players[id]["kills"] = 0
		Net.players[id]["deaths"] = 0
		Net.players[id]["points"] = 0
	_clear_match_nodes()
	host_start_match()


func set_paused(p: bool) -> void:
	paused_local = p
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED


# ---------------------------------------------------------------- ticking
func _physics_process(delta: float) -> void:
	if multiplayer.is_server() and _waiting_spawn:
		_map_ready_t -= delta
		if _map_ready_t <= 0.0:
			log_ev("Match", "map_ready_timeout", {})
			if world != null:
				_spawn_all()
	if not in_match or world == null:
		return
	if args.has("routeprobe") and not _probed and server_tick > 60 and map_def != null and mode_id == "hot_return":
		_probed = true
		var map_rid: RID = world.get_world_3d().navigation_map
		var vault: Vector3 = map_def.vaults.get(2, Vector3.ZERO)
		var stab: Vector3 = map_def.stabilizers.get(1, Vector3.ZERO)
		var fa: Vector3 = map_def.fields[0]["position"]
		var fb: Vector3 = map_def.fields[1]["position"]
		var routes := {
			"direct": [vault, stab], "via_A": [vault, fa, stab], "via_B": [vault, fb, stab],
			"via_B_then_A": [vault, fb, fa, stab], "via_A_then_B": [vault, fa, fb, stab],
		}
		for key in routes:
			var pts: Array = routes[key]
			var total := 0.0
			var ok := true
			for i in range(1, pts.size()):
				var path := NavigationServer3D.map_get_path(map_rid, pts[i - 1], pts[i], true)
				if path.size() < 2 or path[path.size() - 1].distance_to(pts[i]) > 4.0:
					ok = false
				for j in range(1, path.size()):
					total += path[j - 1].distance_to(path[j])
			var pauses := 0.0 if key == "direct" else (7.0 if pts.size() == 3 else 14.0)
			var e := HotReturnRules.route_exposure(total, pauses)
			log_ev("Route", key, {"map": map_id, "metres": snappedf(total, 0.1), "carry_s": snappedf(float(e["carry"]), 0.1), "exposure_s": snappedf(float(e["exposure"]), 0.1), "volatility": snappedf(float(e["volatility"]), 0.1), "reachable": ok})
	if args.has("navprobe") and not _probed and server_tick > 5:
		_probed = true
		var map_rid: RID = world.get_world_3d().navigation_map
		for spec in str(args["navprobe"]).split(";"):
			var v := spec.split(",")
			var want := Vector3(float(v[0]), float(v[1]), float(v[2]))
			var closest := NavigationServer3D.map_get_closest_point(map_rid, want)
			var from := Vector3(float(v[3]), float(v[4]), float(v[5])) if v.size() >= 6 else Vector3.ZERO
			var path := NavigationServer3D.map_get_path(map_rid, from, want, true)
			log_ev("Nav", "probe", {"want": [want.x, want.y, want.z], "closest": [snappedf(closest.x, 0.1), snappedf(closest.y, 0.1), snappedf(closest.z, 0.1)], "path_len": path.size(), "path_end": [snappedf(path[path.size() - 1].x, 0.1), snappedf(path[path.size() - 1].y, 0.1), snappedf(path[path.size() - 1].z, 0.1)] if path.size() > 0 else []})
	if local_player != null and is_instance_valid(local_player):
		var inp: Array = local_player.gather_input()
		if multiplayer.is_server():
			local_player.set_input(inp[0], inp[1], inp[2], inp[3], server_tick + 1)
		else:
			rpc_submit_input.rpc_id(1, inp[0], inp[1], inp[2], inp[3], Engine.get_physics_frames())
	if multiplayer.is_server():
		server_tick += 1
		for p in players.values():
			if is_instance_valid(p):
				p.server_step(delta)
		if match_server != null:
			match_server.step(delta)
		if server_tick % SNAPSHOT_EVERY == 0:
			_send_snapshot()
	if args.has("kill-local-at") and multiplayer.is_server() and local_player != null and is_instance_valid(local_player) and local_player.alive and _shot_elapsed > float(args["kill-local-at"]):
		local_player.apply_damage(999.0, -99, "debug", 0.0)
		log_ev("Debug", "killed_local", {})
	if args.has("log-snap"):
		_log_snap_t -= delta
		if _log_snap_t <= 0.0:
			_log_snap_t = 1.0
			var d := {}
			for id in players:
				var p = players[id]
				if is_instance_valid(p):
					var gp: Vector3 = p.global_position
					d[str(id)] = [snappedf(gp.x, 0.01), snappedf(gp.y, 0.01), snappedf(gp.z, 0.01), int(p.hp), int(p.alive)]
			log_ev("Snap", "players", {"n": players.size(), "p": d, "time_left": snappedf(time_left, 0.1), "phase": state.get("phase", "")})


func _process(delta: float) -> void:
	if not _window_logged and DisplayServer.get_name() != "headless" and Time.get_ticks_msec() > 2500:
		_window_logged = true
		var ws := DisplayServer.window_get_size()
		log_ev("Boot", "window_settled", {"window": [ws.x, ws.y], "mode": DisplayServer.window_get_mode(), "note": Settings.last_window_note})
	if args.has("winprobe") and DisplayServer.get_name() != "headless":
		var ms := Time.get_ticks_msec()
		if ms > 1000 and _probe_stage == 0:
			_probe_stage = 1
			log_ev("Win", "cli", {"args": OS.get_cmdline_args(), "override": Settings.cli_overrides_window(), "pref_fs": Settings.fullscreen})
			log_ev("Win", "probe", {"stage": 1, "size": DisplayServer.window_get_size(), "mode": DisplayServer.window_get_mode(), "fs_const": DisplayServer.WINDOW_MODE_FULLSCREEN, "max_const": DisplayServer.WINDOW_MODE_MAXIMIZED, "screen": DisplayServer.screen_get_size(), "scale": DisplayServer.screen_get_scale(), "pref_fs": Settings.fullscreen, "pref_res": Settings.resolution})
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(1920, 1080))
		elif ms > 2000 and _probe_stage == 1:
			_probe_stage = 2
			log_ev("Win", "probe", {"stage": 2, "size": DisplayServer.window_get_size(), "mode": DisplayServer.window_get_mode(), "pos": DisplayServer.window_get_position()})
			get_window().mode = Window.MODE_WINDOWED
			get_window().size = Vector2i(1920, 1080)
			get_window().position = Vector2i(100, 100)
		elif ms > 3200 and _probe_stage == 2:
			_probe_stage = 3
			log_ev("Win", "probe", {"stage": 3, "size": DisplayServer.window_get_size(), "mode": DisplayServer.window_get_mode(), "pos": DisplayServer.window_get_position(), "win_size": get_window().size, "content_scale": get_window().content_scale_factor})
	if _quit_t >= 0.0:
		_quit_t -= delta
		if _quit_t <= 0.0:
			_quit_t = -1.0
			log_ev("Boot", "quit_after", {})
			get_tree().quit()
	if args.has("screenshot-title") and not in_match:
		_shot_elapsed += delta
		if _shot_elapsed > float(args["screenshot-title"]):
			args.erase("screenshot-title")
			_take_screenshot(0.0)
	if world != null and in_match:
		_shot_elapsed += delta
		if args.has("open-map-at") and _shot_elapsed >= float(args["open-map-at"]):
			map_open = true
		if not _shots.is_empty() and _shot_elapsed >= _shots[0]:
			var at: float = _shots.pop_front()
			_take_screenshot(at)


func _take_screenshot(at: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var base := str(args.get("screenshot", "build/shots/shot"))
	var path := "%s_%d_%02d.png" % [base, multiplayer.get_unique_id(), int(at)]
	var abs_path := ProjectSettings.globalize_path("res://" + path) if not path.begins_with("/") and path.find(":") < 0 else path
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var err := img.save_png(abs_path)
	log_ev("Shot", "saved", {"path": abs_path, "err": err})


func _send_snapshot() -> void:
	var data := []
	for p in players.values():
		if is_instance_valid(p):
			data.append(p.pack_state())
	time_left = match_server.time_left if match_server != null else 0.0
	live = match_server.live_dict() if match_server != null else {}
	rpc_snapshot.rpc(server_tick, data, time_left, live)


# ---------------------------------------------------------------- RPCs: inputs & snapshots
@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_snapshot(_tick: int, data: Array, tl: float, live_: Dictionary) -> void:
	time_left = tl
	live = live_
	for s in data:
		var p = players.get(s[0])
		if p != null and is_instance_valid(p):
			p.apply_state(s)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_submit_input(move: Vector2, yaw: float, pitch: float, buttons: int, seq: int) -> void:
	if not multiplayer.is_server():
		return
	var p = players.get(multiplayer.get_remote_sender_id())
	if p != null and is_instance_valid(p) and not p.is_bot:
		p.set_input(move, yaw, pitch, buttons, seq)


# ---------------------------------------------------------------- RPCs: state & events (server -> all)
@rpc("authority", "call_local", "reliable")
func rpc_state(s: Dictionary) -> void:
	state = s
	state_changed.emit()


@rpc("authority", "call_local", "reliable")
func rpc_notice(text: String, seconds: float) -> void:
	notice.emit(text, seconds)


@rpc("authority", "call_local", "reliable")
func rpc_kill(killer_name: String, victim_name: String, cause: String, killer_id: int, victim_id: int) -> void:
	kill_feed.emit(killer_name, victim_name, cause, killer_id, victim_id)
	var v = players.get(victim_id)
	if v != null and is_instance_valid(v):
		v.alive = false
		v._apply_flags_visual()
	Sfx.play("elim", -4.0)


@rpc("authority", "call_local", "unreliable")
func rpc_shot(shooter_id: int, from: Vector3, to: Vector3, hit_id: int) -> void:
	shot_fx.emit(shooter_id, from, to, hit_id)
	var p = players.get(shooter_id)
	if p != null and is_instance_valid(p) and p.is_local():
		p.kick_view()
		Sfx.play("shot", -6.0, randf_range(0.97, 1.03))
	else:
		Sfx.play("shot", -16.0, randf_range(0.9, 1.1))


@rpc("authority", "call_local", "reliable")
func rpc_damage(victim_id: int, attacker_id: int, amount: float, hp_after: float, cause: String) -> void:
	damage_fx.emit(victim_id, attacker_id, amount, hp_after, cause)
	var v = players.get(victim_id)
	if v != null and is_instance_valid(v):
		v.hp = hp_after
	if attacker_id == local_id():
		Sfx.play("hit", -6.0)
	elif victim_id == local_id():
		Sfx.play("elim", -14.0, 1.6)


@rpc("authority", "call_local", "unreliable")
func rpc_fx(kind: String, id: int, pos: Vector3) -> void:
	fx.emit(kind, id, pos)


@rpc("authority", "call_local", "reliable")
func rpc_respawn(id: int, pos: Vector3, yaw: float, protect: float) -> void:
	var p = players.get(id)
	if p != null and is_instance_valid(p):
		p.respawn(pos, yaw, protect)


@rpc("authority", "call_local", "reliable")
func rpc_teleport(id: int, pos: Vector3, yaw: float) -> void:
	var p = players.get(id)
	if p != null and is_instance_valid(p):
		p.teleport(pos, yaw)
		fx.emit("teleport", id, pos)


@rpc("authority", "call_local", "reliable")
func rpc_echo_spawn(eid: int, owner_id: int, payload: Dictionary) -> void:
	if world == null or not ResourceLoader.exists("res://src/echo/Echo.gd"):
		return
	var e = load("res://src/echo/Echo.gd").new()
	e.setup(eid, owner_id, payload)
	world.get_node("Echoes").add_child(e)
	echoes[eid] = e
	echo_spawned.emit(e)


@rpc("authority", "call_local", "reliable")
func rpc_echo_end(eid: int, reason: String) -> void:
	var e = echoes.get(eid)
	if e != null and is_instance_valid(e):
		e.finish(reason)
	echoes.erase(eid)


@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_projectile_spawn(id: int, origin: Vector3, velocity: Vector3, weapon: String) -> void:
	projectiles.on_spawn(id, origin, velocity, weapon)


@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_projectile_accel(id: int, factor: float) -> void:
	projectiles.on_accel(id, factor)


@rpc("authority", "call_local", "unreliable_ordered")
func rpc_projectile_hit(id: int, pos: Vector3, hit_id: int) -> void:
	projectiles.on_hit(id, pos, hit_id)


@rpc("authority", "call_remote", "reliable")
func rpc_recoil(dyaw: float, dpitch: float) -> void:
	if local_player != null and is_instance_valid(local_player):
		local_player.apply_recoil(dyaw, dpitch)


@rpc("authority", "call_local", "unreliable")
func rpc_muzzle(shooter_id: int, weapon: String) -> void:
	var p = players.get(shooter_id)
	var cue_by := {"rifle": "shot", "shotgun": "shot_shotgun", "sniper": "shot_sniper", "mg": "shot_mg"}
	var cue: String = cue_by.get(weapon, "shot")
	if p != null and is_instance_valid(p):
		if p.is_local():
			p.kick_view()
			Sfx.play(cue, -5.0, randf_range(0.98, 1.02))
		else:
			var d: float = local_player.global_position.distance_to(p.global_position) if local_player != null and is_instance_valid(local_player) else 30.0
			Sfx.play(cue, -10.0 - clampf(d / 6.0, 0.0, 18.0), randf_range(0.95, 1.05))
		fx.emit("muzzle", shooter_id, p.muzzle_position())
		if not p.is_local() and p.rig != null:
			p.rig.fire()


@rpc("authority", "call_local", "reliable")
func rpc_prop_state(prop_id: int, state: String, version: int, t: float) -> void:
	var prop = props.get(prop_id)
	if prop != null and is_instance_valid(prop):
		prop.apply_state(state, version, t)


@rpc("authority", "call_local", "reliable")
func rpc_results(r: Dictionary) -> void:
	results = r
	results_ready.emit(r)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
