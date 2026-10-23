extends Node
## Session layer: host / join / leave, player registry, lobby settings, LAN room-code beacon.
## LAN / same Wi-Fi only. No internet matchmaking exists in this build.

signal players_changed
signal lobby_changed
signal connected_as_client
signal join_failed(reason: String)
signal disconnected(reason: String)
signal code_search_update(text: String)

const PORT := 24642
const BEACON_PORT := 24643
const MAX_PLAYERS := 8
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const DIFFICULTIES := ["easy", "medium", "hard"]
const MODES := ["hot_return", "relic_rush"]

var peer: ENetMultiplayerPeer = null
var is_host := false
var connected := false
var room_code := ""
var port := PORT
var players: Dictionary = {}
var lobby: Dictionary = {
	"mode": "hot_return",
	"map": "oracle_gardens",
	"team_size": 3,
	"ffa_size": 4,
	"bot_fill": true,
	"bot_difficulty": "medium",
	"switch_policy": "every_round",
	"locked": false,
	"practice": false,
}
var next_bot_id := -1
var _beacon: PacketPeerUDP = null
var _beacon_timer := 0.0
var _listen: PacketPeerUDP = null
var _search_code := ""
var _search_t := 0.0
var _pending_kick: Array = []


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func local_id() -> int:
	return multiplayer.get_unique_id()


func is_server() -> bool:
	return multiplayer.is_server()


func human_count() -> int:
	var n := 0
	for id in players:
		if not players[id]["is_bot"]:
			n += 1
	return n


func team_count(team: int, include_bots: bool = true) -> int:
	var n := 0
	for id in players:
		var p: Dictionary = players[id]
		if int(p["team"]) == team and (include_bots or not p["is_bot"]):
			n += 1
	return n


# ---------------------------------------------------------------- host / join
func host(port_: int = PORT, practice: bool = false) -> Error:
	leave()
	port = port_
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		peer = null
		Game.log_ev("Session", "host_failed", {"err": err})
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	connected = true
	lobby["locked"] = false
	lobby["practice"] = practice
	room_code = _make_code()
	players.clear()
	next_bot_id = -1
	players[1] = _new_player_info(1, Settings.player_name, false)
	_auto_team(1)
	_assign_glyphs()
	if not practice:
		_start_beacon()
	Game.log_ev("Session", "hosting", {"port": port, "code": room_code, "practice": practice})
	players_changed.emit()
	lobby_changed.emit()
	return OK


func join_ip(ip: String, port_: int = PORT) -> Error:
	leave()
	port = port_
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		peer = null
		join_failed.emit("Could not start a connection to %s:%d (error %d)." % [ip, port, err])
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	Game.log_ev("Session", "joining", {"ip": ip, "port": port})
	return OK


func join_code(code: String) -> void:
	code = code.strip_edges().to_upper()
	if code.length() != 6:
		join_failed.emit("Room code must be 6 characters.")
		return
	_stop_listen()
	_listen = PacketPeerUDP.new()
	var err := _listen.bind(BEACON_PORT, "0.0.0.0")
	if err != OK:
		_listen = null
		join_failed.emit("Could not listen for LAN rooms on UDP %d (port in use)." % BEACON_PORT)
		return
	_search_code = code
	_search_t = 6.0
	code_search_update.emit("Searching the LAN for room %s..." % code)
	Game.log_ev("Session", "code_search", {"code": code})


func leave() -> void:
	_stop_beacon()
	_stop_listen()
	if peer != null:
		Game.log_ev("Session", "leave", {})
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_host = false
	connected = false
	room_code = ""
	players.clear()
	lobby["locked"] = false
	players_changed.emit()


# ---------------------------------------------------------------- lobby (host owned)
func set_lobby(key: String, value) -> void:
	if not is_server():
		return
	lobby[key] = value
	if key == "mode":
		_retarget_teams()
	broadcast_lobby()
	lobby_changed.emit()


func broadcast_lobby() -> void:
	if is_server() and connected:
		rpc_sync_lobby.rpc(lobby)


func set_team(id: int, team: int) -> void:
	if not is_server() or not players.has(id):
		return
	players[id]["team"] = team
	_assign_glyphs()
	broadcast_players()


func request_team(team: int) -> void:
	if is_server():
		set_team(1, team)
	else:
		rpc_request_team.rpc_id(1, team)


func broadcast_players() -> void:
	if is_server() and connected:
		rpc_sync_players.rpc(players)
	players_changed.emit()


func fill_bots() -> void:
	if not is_server():
		return
	remove_all_bots()
	if not lobby["bot_fill"]:
		ensure_playable()
		return
	var diff: String = lobby["bot_difficulty"]
	if lobby["mode"] != "relic_rush":
		var size := int(lobby["team_size"])
		_balance_humans(size)
		for team in [1, 2]:
			while team_count(team) < size:
				add_bot(team, diff)
	else:
		var total := int(lobby["ffa_size"])
		while players.size() < total and players.size() < MAX_PLAYERS:
			add_bot(0, diff)
	_assign_glyphs()
	broadcast_players()


func ensure_playable() -> void:
	if not is_server():
		return
	var diff: String = lobby["bot_difficulty"]
	if lobby["mode"] != "relic_rush":
		for team in [1, 2]:
			if team_count(team) == 0:
				add_bot(team, diff)
	elif players.size() < 2:
		add_bot(0, diff)
	_assign_glyphs()
	broadcast_players()


func add_bot(team: int, difficulty: String) -> int:
	var id := next_bot_id
	next_bot_id -= 1
	var info := _new_player_info(id, "BOT %02d" % (-id), true)
	info["team"] = team
	info["difficulty"] = difficulty
	players[id] = info
	return id


func remove_all_bots() -> void:
	for id in players.keys():
		if players[id]["is_bot"]:
			players.erase(id)


func _balance_humans(size: int) -> void:
	# Move humans off an over-full team, then even out counts.
	for team in [1, 2]:
		while team_count(team, false) > size:
			var moved := false
			for id in players:
				if not players[id]["is_bot"] and int(players[id]["team"]) == team:
					players[id]["team"] = 3 - team
					moved = true
					break
			if not moved:
				break
	while absi(team_count(1, false) - team_count(2, false)) > 1:
		var from_team := 1 if team_count(1, false) > team_count(2, false) else 2
		var moved := false
		for id in players:
			if not players[id]["is_bot"] and int(players[id]["team"]) == from_team and id != 1:
				players[id]["team"] = 3 - from_team
				moved = true
				break
		if not moved:
			break


func _retarget_teams() -> void:
	for id in players:
		if lobby["mode"] != "relic_rush":
			if int(players[id]["team"]) == 0:
				_auto_team(id)
		else:
			players[id]["team"] = 0
	_assign_glyphs()
	broadcast_players()


func _auto_team(id: int) -> void:
	if lobby["mode"] == "relic_rush":
		players[id]["team"] = 0
		return
	var c1 := team_count(1, false)
	var c2 := team_count(2, false)
	players[id]["team"] = 1 if c1 <= c2 else 2


func _assign_glyphs() -> void:
	var ids := players.keys()
	ids.sort()
	var i := 0
	for id in ids:
		players[id]["glyph"] = i
		i += 1


func _new_player_info(id: int, pname: String, is_bot: bool) -> Dictionary:
	return {
		"id": id, "name": pname.left(14), "team": 0, "is_bot": is_bot, "glyph": 0,
		"kills": 0, "deaths": 0, "points": 0, "difficulty": "", "ready": true,
	}


func _make_code() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var s := ""
	for i in 6:
		s += CODE_CHARS[rng.randi_range(0, CODE_CHARS.length() - 1)]
	return s


# ---------------------------------------------------------------- signals
func _on_peer_connected(id: int) -> void:
	Game.log_ev("Session", "peer_connected", {"id": id})


func _on_peer_disconnected(id: int) -> void:
	Game.log_ev("Session", "peer_disconnected", {"id": id})
	if is_server():
		if players.has(id):
			players.erase(id)
			broadcast_players()
		Game.on_peer_left(id)


func _on_connected_to_server() -> void:
	connected = true
	Game.log_ev("Session", "connected_to_server", {"my_id": local_id()})
	rpc_register.rpc_id(1, Settings.player_name)


func _on_connection_failed() -> void:
	Game.log_ev("Session", "connection_failed", {})
	leave()
	join_failed.emit("Connection failed. Check the host is running, the IP or code, and that both devices are on the same Wi-Fi.")


func _on_server_disconnected() -> void:
	Game.log_ev("Session", "server_disconnected", {})
	leave()
	disconnected.emit("The host left the room.")


func _process(delta: float) -> void:
	if _beacon != null:
		_beacon_timer -= delta
		if _beacon_timer <= 0.0:
			_beacon_timer = 1.0
			_send_beacon()
	if _listen != null:
		while _listen.get_available_packet_count() > 0:
			var pkt := _listen.get_packet()
			var from_ip := _listen.get_packet_ip()
			var d = JSON.parse_string(pkt.get_string_from_utf8())
			if d is Dictionary and d.get("app", "") == "echoclash" and str(d.get("code", "")) == _search_code:
				var p := int(d.get("port", PORT))
				_stop_listen()
				code_search_update.emit("Found room %s on %s. Connecting..." % [_search_code, from_ip])
				Game.log_ev("Session", "code_found", {"ip": from_ip, "port": p})
				join_ip(from_ip, p)
				return
		_search_t -= delta
		if _search_t <= 0.0:
			_stop_listen()
			join_failed.emit("No LAN room with code %s found in 6 s. Check the code and that both devices share the same Wi-Fi. You can also join by IP." % _search_code)
	if _pending_kick.size() > 0 and peer != null:
		for id in _pending_kick:
			peer.disconnect_peer(id)
		_pending_kick.clear()


# ---------------------------------------------------------------- beacon
func _start_beacon() -> void:
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	_beacon_timer = 0.0


func _stop_beacon() -> void:
	if _beacon != null:
		_beacon.close()
		_beacon = null


func _send_beacon() -> void:
	if _beacon == null:
		return
	var msg := JSON.stringify({"app": "echoclash", "code": room_code, "port": port, "name": Settings.player_name}).to_utf8_buffer()
	for addr in ["255.255.255.255", "127.0.0.1"]:
		_beacon.set_dest_address(addr, BEACON_PORT)
		_beacon.put_packet(msg)


func _stop_listen() -> void:
	if _listen != null:
		_listen.close()
		_listen = null


# ---------------------------------------------------------------- RPCs
@rpc("any_peer", "call_remote", "reliable")
func rpc_register(pname: String) -> void:
	if not is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if lobby["locked"] or players.size() >= MAX_PLAYERS:
		rpc_refused.rpc_id(id, "Match already in progress." if lobby["locked"] else "Room is full.")
		_pending_kick.append(id)
		return
	players[id] = _new_player_info(id, pname, false)
	_auto_team(id)
	_assign_glyphs()
	Game.log_ev("Session", "registered", {"id": id, "name": pname})
	rpc_welcome.rpc_id(id, room_code, lobby)
	broadcast_players()


@rpc("authority", "call_remote", "reliable")
func rpc_welcome(code: String, lobby_: Dictionary) -> void:
	room_code = code
	lobby = lobby_
	connected = true
	lobby_changed.emit()
	connected_as_client.emit()


@rpc("authority", "call_remote", "reliable")
func rpc_refused(reason: String) -> void:
	Game.log_ev("Session", "refused", {"reason": reason})
	leave()
	join_failed.emit(reason)


@rpc("authority", "call_remote", "reliable")
func rpc_sync_players(p: Dictionary) -> void:
	players = p
	players_changed.emit()


@rpc("authority", "call_remote", "reliable")
func rpc_sync_lobby(l: Dictionary) -> void:
	lobby = l
	lobby_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func rpc_request_team(team: int) -> void:
	if not is_server() or lobby["locked"]:
		return
	var id := multiplayer.get_remote_sender_id()
	if team in [1, 2]:
		set_team(id, team)
