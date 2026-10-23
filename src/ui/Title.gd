extends Control
## Front end: title, mode/room setup, join by code or IP, lobby, settings. Also handles CLI roles.

var column: VBoxContainer
var status_lbl: Label
var _lobby_roster: VBoxContainer = null
var _lobby_summary: Label = null
var _lobby_start: Button = null
var _auto_start_t := -1.0
var _auto_min_players := 1


func _ready() -> void:
	theme = UiTheme.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Palette.INK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var marks := Control.new()
	marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.draw.connect(_draw_marks.bind(marks))
	add_child(marks)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var h := HBoxContainer.new()
	margin.add_child(h)
	column = VBoxContainer.new()
	column.custom_minimum_size = Vector2(620, 0)
	column.add_theme_constant_override("separation", 10)
	h.add_child(column)
	Net.players_changed.connect(_on_players_changed)
	Net.lobby_changed.connect(_on_players_changed)
	Net.connected_as_client.connect(func() -> void: _screen_lobby())
	Net.join_failed.connect(func(reason: String) -> void: _set_status(reason, Palette.VERMILION))
	Net.disconnected.connect(func(reason: String) -> void:
		_screen_main()
		_set_status(reason, Palette.VERMILION))
	Net.code_search_update.connect(func(text: String) -> void: _set_status(text, Palette.MINT))
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Game.open_lobby_on_menu and Net.connected:
		Game.open_lobby_on_menu = false
		_screen_lobby()
	else:
		_screen_main()
		if Game.menu_message != "":
			_set_status(Game.menu_message, Palette.BRASS)
			Game.menu_message = ""
	_handle_cli()


# ---------------------------------------------------------------- CLI roles for automated tests
func _handle_cli() -> void:
	var a := Game.args
	if not a.has("role"):
		return
	if a.has("name"):
		Settings.player_name = str(a["name"])
	var port := int(a.get("port", Net.PORT))
	match str(a["role"]):
		"host":
			for key in ["mode", "map", "bot_difficulty"]:
				if a.has(key):
					Net.lobby[key] = str(a[key])
			if a.has("team_size"):
				Net.lobby["team_size"] = int(a["team_size"])
			if a.has("ffa_size"):
				Net.lobby["ffa_size"] = int(a["ffa_size"])
			Net.lobby["bot_fill"] = str(a.get("bots", "false")) == "true"
			var err := Net.host(port, a.has("practice"))
			if a.has("code"):
				Net.room_code = str(a["code"]).to_upper()
			Game.log_ev("Cli", "host", {"err": err, "code": Net.room_code})
			_screen_lobby()
			if a.has("autostart"):
				_auto_start_t = float(a["autostart"])
				_auto_min_players = int(a.get("min_players", 1))
		"join":
			Net.join_ip(str(a.get("ip", "127.0.0.1")), port)
			_set_status("CLI: joining %s:%d" % [str(a.get("ip", "127.0.0.1")), port], Palette.MINT)
		"code":
			Net.join_code(str(a.get("code", "")))


func _process(delta: float) -> void:
	if _auto_start_t >= 0.0 and Net.is_host:
		if Net.human_count() >= _auto_min_players:
			_auto_start_t -= delta
		if _auto_start_t <= 0.0:
			_auto_start_t = -1.0
			Game.log_ev("Cli", "autostart", {"players": Net.players.size()})
			Game.host_start_match()


# ---------------------------------------------------------------- helpers
func _clear() -> void:
	for c in column.get_children():
		column.remove_child(c)
		c.queue_free()
	status_lbl = null
	_lobby_roster = null
	_lobby_summary = null
	_lobby_start = null


func _header(kicker: String, title: String, sub: String = "") -> void:
	column.add_child(UiTheme.stamp(kicker, Palette.VERMILION, 14))
	column.add_child(UiTheme.label(title, 54, Palette.PORCELAIN, UiTheme.display_font()))
	if sub != "":
		column.add_child(UiTheme.label(sub, 18, Palette.STONE, UiTheme.serif_font()))
	column.add_child(UiTheme.rule(Palette.STONE))


func _button(text: String, cb: Callable, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.pressed.connect(cb)
	b.custom_minimum_size = Vector2(360, 0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(b)
	return b


func _status_line() -> void:
	status_lbl = UiTheme.label("", 15, Palette.MINT, UiTheme.mono_font())
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_lbl.custom_minimum_size = Vector2(600, 0)
	column.add_child(status_lbl)


func _set_status(text: String, color: Color) -> void:
	if status_lbl == null or not is_instance_valid(status_lbl):
		return
	status_lbl.text = text
	status_lbl.add_theme_color_override("font_color", color)


func _option(label: String, items: Array, current: int, cb: Callable) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	var l := UiTheme.stamp(label, Palette.MINT, 13)
	l.custom_minimum_size = Vector2(170, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var ob := OptionButton.new()
	for it in items:
		ob.add_item(str(it))
	ob.selected = current
	ob.item_selected.connect(cb)
	ob.custom_minimum_size = Vector2(300, 0)
	row.add_child(ob)
	return ob


func _check(label: String, value: bool, cb: Callable) -> CheckButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	var l := UiTheme.stamp(label, Palette.MINT, 13)
	l.custom_minimum_size = Vector2(170, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var cb_btn := CheckButton.new()
	cb_btn.button_pressed = value
	cb_btn.text = "ON" if value else "OFF"
	cb_btn.toggled.connect(func(v: bool) -> void:
		cb_btn.text = "ON" if v else "OFF"
		cb.call(v))
	row.add_child(cb_btn)
	return cb_btn


func _line(label: String, placeholder: String, value: String = "") -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	var l := UiTheme.stamp(label, Palette.MINT, 13)
	l.custom_minimum_size = Vector2(170, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.text = value
	le.custom_minimum_size = Vector2(300, 0)
	row.add_child(le)
	return le


# ---------------------------------------------------------------- screens
func _screen_main() -> void:
	_clear()
	column.add_child(UiTheme.stamp("HACKATHON BUILD / ARCHIVE SPORTS DIVISION / FRAME 001", Palette.VERMILION, 14))
	column.add_child(UiTheme.label("ECHO\nCLASH", 96, Palette.PORCELAIN, UiTheme.display_font()))
	column.add_child(UiTheme.stamp("THE ARENA REMEMBERS.", Palette.MINT, 20))
	column.add_child(UiTheme.rule(Palette.STONE))
	_button("PLAY / OFFLINE PRACTICE", func() -> void: _screen_setup(true))
	_button("HOST LAN ROOM", func() -> void: _screen_setup(false))
	_button("JOIN ROOM", func() -> void: _screen_join())
	_button("SETTINGS / CONTROLS", func() -> void: _screen_settings())
	_button("EXIT", func() -> void: get_tree().quit())
	column.add_child(UiTheme.rule(Palette.STONE))
	column.add_child(UiTheme.label("Room codes work on the same LAN / Wi-Fi only. There is no internet matchmaking in this build.", 14, Palette.STONE, UiTheme.serif_font()))
	_status_line()


func _screen_setup(practice: bool) -> void:
	_clear()
	_header("MODE / ROOM SETUP", "OFFLINE PRACTICE" if practice else "HOST LAN ROOM", "Choose the record to play. Bots fill the vacant seats." if practice else "Your room gets a 6-character code that other players on this Wi-Fi can join.")
	var lobby := Net.lobby
	_line("YOUR NAME", "PLAYER", Settings.player_name).text_changed.connect(func(t: String) -> void: Settings.player_name = t.strip_edges().to_upper().left(14))
	var modes := ["HOT RETURN / STEAL THE CORE", "RELIC RUSH / FREE FOR ALL"]
	_option("MODE", modes, 0 if lobby["mode"] == "hot_return" else 1, func(i: int) -> void:
		Net.lobby["mode"] = "hot_return" if i == 0 else "relic_rush")
	var map_names := []
	var map_ids := []
	var cur := 0
	var k := 0
	for m in Maps.list():
		map_names.append("%s / %s" % [m["name"], m["mechanic"]])
		map_ids.append(m["id"])
		if m["id"] == lobby["map"]:
			cur = k
		k += 1
	_option("MAP", map_names, cur, func(i: int) -> void: Net.lobby["map"] = map_ids[i])
	for m in Maps.list():
		column.add_child(UiTheme.label("%s: %s" % [m["name"], m["blurb"]], 13, Palette.STONE, UiTheme.serif_font()))
	_option("TEAM SIZE (HOT RETURN)", ["1 v 1", "2 v 2", "3 v 3", "4 v 4"], int(lobby["team_size"]) - 1, func(i: int) -> void: Net.lobby["team_size"] = i + 1)
	_option("PLAYERS (RELIC RUSH)", ["2", "4", "6", "8"], clampi(int(lobby["ffa_size"]) / 2 - 1, 0, 3), func(i: int) -> void: Net.lobby["ffa_size"] = (i + 1) * 2)
	_check("FILL WITH BOTS", bool(lobby["bot_fill"]), func(v: bool) -> void: Net.lobby["bot_fill"] = v)
	_option("BOT DIFFICULTY", ["EASY", "MEDIUM", "HARD"], Net.DIFFICULTIES.find(str(lobby["bot_difficulty"])), func(i: int) -> void: Net.lobby["bot_difficulty"] = Net.DIFFICULTIES[i])
	column.add_child(UiTheme.rule(Palette.STONE))
	column.add_child(UiTheme.label("Hot Return: attackers steal the Causal Core from the vault and carry it home before it detonates (26 s fuse, Stability Fields pause it). First to 3 rounds, 2-2 goes to overtime pairs. Relic Rush: 5 minutes, first to 25 points.", 14, Palette.STONE, UiTheme.serif_font()))
	_button("CREATE ROOM" if not practice else "OPEN PRACTICE LOBBY", func() -> void:
		Settings.save_prefs()
		var err := Net.host(Net.PORT, practice)
		if err != OK:
			_set_status("Could not open UDP port %d (error %d). Another instance may be hosting on this machine." % [Net.PORT, err], Palette.VERMILION)
			return
		_screen_lobby())
	_button("BACK", func() -> void: _screen_main())
	_status_line()


func _screen_join() -> void:
	_clear()
	_header("JOIN ROOM", "ENTER THE ARCHIVE", "Type the host's 6-character room code. Both devices must share the same LAN / Wi-Fi.")
	_line("YOUR NAME", "PLAYER", Settings.player_name).text_changed.connect(func(t: String) -> void: Settings.player_name = t.strip_edges().to_upper().left(14))
	var code := _line("ROOM CODE", "e.g. K7PX2A")
	code.max_length = 6
	code.text_changed.connect(func(t: String) -> void:
		var up := t.to_upper()
		if up != t:
			code.text = up
			code.caret_column = up.length())
	_button("FIND AND JOIN BY CODE", func() -> void:
		Settings.save_prefs()
		Net.join_code(code.text))
	var ip := _line("HOST IP (FALLBACK)", "e.g. 192.168.1.20")
	_button("JOIN BY IP", func() -> void:
		Settings.save_prefs()
		var addr := ip.text.strip_edges()
		if addr == "":
			_set_status("Enter the host IP address shown in their lobby.", Palette.VERMILION)
			return
		_set_status("Connecting to %s..." % addr, Palette.MINT)
		Net.join_ip(addr))
	_button("BACK", func() -> void:
		Net.leave()
		_screen_main())
	_status_line()


func _screen_lobby() -> void:
	_clear()
	var host := Net.is_host
	_header("LOBBY / %s" % ("HOST" if host else "GUEST"), "ROOM  %s" % Net.room_code if not Net.lobby.get("practice", false) else "PRACTICE LOBBY", "Share this code with players on the same Wi-Fi. They choose JOIN ROOM and type it." if host and not Net.lobby.get("practice", false) else "")
	if host and not Net.lobby.get("practice", false):
		var ips := []
		for addr in IP.get_local_addresses():
			if addr.find(".") >= 0 and not addr.begins_with("127.") and not addr.begins_with("169."):
				ips.append(addr)
		column.add_child(UiTheme.label("Fallback join by IP: %s   (UDP port %d)" % [", ".join(ips), Net.PORT], 14, Palette.STONE, UiTheme.mono_font()))
		var copy := _button("COPY ROOM CODE", func() -> void:
			DisplayServer.clipboard_set(Net.room_code)
			_set_status("Room code %s copied to the clipboard." % Net.room_code, Palette.MINT))
		copy.custom_minimum_size = Vector2(260, 0)
	_lobby_summary = UiTheme.stamp("", Palette.BRASS, 14)
	column.add_child(_lobby_summary)
	column.add_child(UiTheme.rule(Palette.STONE))
	_lobby_roster = VBoxContainer.new()
	column.add_child(_lobby_roster)
	column.add_child(UiTheme.rule(Palette.STONE))
	if host:
		var lobby := Net.lobby
		_option("MODE", ["HOT RETURN", "RELIC RUSH"], 0 if lobby["mode"] == "hot_return" else 1, func(i: int) -> void: Net.set_lobby("mode", "hot_return" if i == 0 else "relic_rush"))
		var map_names := []
		var map_ids := []
		var cur := 0
		var k := 0
		for m in Maps.list():
			map_names.append(m["name"])
			map_ids.append(m["id"])
			if m["id"] == lobby["map"]:
				cur = k
			k += 1
		_option("MAP", map_names, cur, func(i: int) -> void: Net.set_lobby("map", map_ids[i]))
		_option("TEAM SIZE", ["1 v 1", "2 v 2", "3 v 3", "4 v 4"], int(lobby["team_size"]) - 1, func(i: int) -> void: Net.set_lobby("team_size", i + 1))
		_option("FFA PLAYERS", ["2", "4", "6", "8"], clampi(int(lobby["ffa_size"]) / 2 - 1, 0, 3), func(i: int) -> void: Net.set_lobby("ffa_size", (i + 1) * 2))
		_check("FILL WITH BOTS", bool(lobby["bot_fill"]), func(v: bool) -> void: Net.set_lobby("bot_fill", v))
		_option("BOT DIFFICULTY", ["EASY", "MEDIUM", "HARD"], Net.DIFFICULTIES.find(str(lobby["bot_difficulty"])), func(i: int) -> void: Net.set_lobby("bot_difficulty", Net.DIFFICULTIES[i]))
	var teams := HBoxContainer.new()
	teams.add_theme_constant_override("separation", 12)
	column.add_child(teams)
	var t1 := Button.new()
	t1.text = "JOIN COBALT"
	t1.pressed.connect(func() -> void: Net.request_team(1))
	teams.add_child(t1)
	var t2 := Button.new()
	t2.text = "JOIN VERMILION"
	t2.pressed.connect(func() -> void: Net.request_team(2))
	teams.add_child(t2)
	if host:
		_lobby_start = _button("START MATCH", func() -> void: Game.host_start_match())
	else:
		column.add_child(UiTheme.stamp("WAITING FOR THE HOST TO START", Palette.MINT, 14))
	_button("LEAVE ROOM", func() -> void:
		Net.leave()
		_screen_main())
	_status_line()
	_on_players_changed()


func _on_players_changed() -> void:
	if _lobby_roster == null or not is_instance_valid(_lobby_roster):
		return
	for c in _lobby_roster.get_children():
		c.queue_free()
	var l := Net.lobby
	var mode_txt := "HOT RETURN %dv%d" % [int(l["team_size"]), int(l["team_size"])] if l["mode"] != "relic_rush" else "RELIC RUSH / %d PLAYERS" % int(l["ffa_size"])
	if _lobby_summary != null:
		_lobby_summary.text = "%s  ·  %s  ·  BOTS %s (%s)" % [mode_txt, Maps.info(str(l["map"]))["name"], "ON" if l["bot_fill"] else "OFF", str(l["bot_difficulty"]).to_upper()]
	var ids := Net.players.keys()
	ids.sort()
	for id in ids:
		var info: Dictionary = Net.players[id]
		var row := UiTheme.label("%s  %-14s  %-10s  %s%s" % [Palette.glyph(int(info["glyph"])), str(info["name"]), Palette.team_name(int(info["team"])) if l["mode"] != "relic_rush" else "SOLO", "BOT" if info["is_bot"] else "HUMAN", "  (HOST)" if id == 1 else ""], 16, Palette.player_color(info), UiTheme.mono_font())
		_lobby_roster.add_child(row)
	_lobby_roster.add_child(UiTheme.label("%d human(s) connected. Bots are added when the match starts." % Net.human_count(), 13, Palette.STONE, UiTheme.serif_font()))


func _screen_settings() -> void:
	_clear()
	_header("SETTINGS / CONTROLS", "CALIBRATION")
	column.add_child(UiTheme.stamp("MOUSE SENSITIVITY", Palette.MINT, 13))
	var sens := HSlider.new()
	sens.min_value = 0.0005
	sens.max_value = 0.006
	sens.step = 0.0001
	sens.value = Settings.mouse_sensitivity
	sens.custom_minimum_size = Vector2(400, 0)
	sens.value_changed.connect(func(v: float) -> void: Settings.mouse_sensitivity = v)
	column.add_child(sens)
	column.add_child(UiTheme.stamp("MASTER VOLUME", Palette.MINT, 13))
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = Settings.master_volume
	vol.custom_minimum_size = Vector2(400, 0)
	vol.value_changed.connect(func(v: float) -> void: Settings.master_volume = v)
	column.add_child(vol)
	_check("FULLSCREEN", Settings.fullscreen, func(v: bool) -> void: Settings.fullscreen = v)
	column.add_child(UiTheme.rule(Palette.STONE))
	var controls := UiTheme.label("WASD  move          MOUSE  aim\nLMB   Pulse Caster  R      reload\nSHIFT sprint        SPACE  jump\nC     crouch        CTRL   dash\nQ     Echo replay   E      interact / plant / defuse / traverse\nTAB   scoreboard    ESC    pause", 16, Palette.PORCELAIN, UiTheme.mono_font())
	column.add_child(controls)
	_button("SAVE AND BACK", func() -> void:
		Settings.save_prefs()
		_screen_main())
	_status_line()


func _draw_marks(c: Control) -> void:
	var col := Color(Palette.STONE, 0.18)
	var s := c.size
	for i in range(0, int(s.x), 80):
		c.draw_line(Vector2(i, 0), Vector2(i, s.y), Color(Palette.STONE, 0.05), 1.0)
	for j in range(0, int(s.y), 80):
		c.draw_line(Vector2(0, j), Vector2(s.x, j), Color(Palette.STONE, 0.05), 1.0)
	for p in [Vector2(40, 40), Vector2(s.x - 40, 40), Vector2(40, s.y - 40), Vector2(s.x - 40, s.y - 40)]:
		c.draw_line(p + Vector2(-12, 0), p + Vector2(12, 0), col, 1.0)
		c.draw_line(p + Vector2(0, -12), p + Vector2(0, 12), col, 1.0)
		c.draw_arc(p, 8.0, 0.0, TAU, 24, col, 1.0)
	c.draw_arc(Vector2(s.x - 240, s.y * 0.5), 150.0, 0.0, TAU, 64, Color(Palette.MINT, 0.12), 2.0)
	c.draw_arc(Vector2(s.x - 240, s.y * 0.5), 110.0, 0.4, 5.6, 64, Color(Palette.VERMILION, 0.18), 3.0)
	c.draw_arc(Vector2(s.x - 240, s.y * 0.5), 60.0, 0.0, TAU, 48, Color(Palette.PORCELAIN, 0.12), 1.0)
