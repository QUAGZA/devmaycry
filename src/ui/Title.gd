extends Control
## Front end: startup sequence, dark animated main menu, match setup (practice / LAN host), join by code or IP,
## lobby, settings, controls, credits. Also handles the CLI roles used by the automated tests.
## Look: graphite surfaces, teal for interaction and energy, amber and coral for team and combat states
## (UiTheme). Behind everything runs the MenuStage: a small real-time Causal Core scene, no video, no map.

const PREVIEW_PATH := "res://assets/ui/map_%s.png"

var column: VBoxContainer
var status_lbl: Label
var _lobby_roster: VBoxContainer = null
var _lobby_summary: Label = null
var _lobby_start: Button = null
var _auto_start_t := -1.0
var _auto_min_players := 1

var _stage: MenuStage = null
var _stage_tex: TextureRect = null
var _card: PanelContainer
var _screen := "main"
var _back: Callable = Callable()
var _entries: Array = []
var _logo: Label
var _tag: Label
var _foot: Label
var _kicker: Label
var _intro: IntroSequence = null
var _card_tween: Tween
var _map_ui: Dictionary = {}          # references into the setup screen's map card
var _mode_ui: Dictionary = {}


func _ready() -> void:
	Music.menu()
	theme = UiTheme.menu_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiTheme.GRAPHITE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	if DisplayServer.get_name() != "headless":
		_stage = MenuStage.new()
		_stage.size = Vector2i(1280, 720)
		add_child(_stage)
		_stage_tex = TextureRect.new()
		_stage_tex.texture = _stage.get_texture()
		_stage_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		_stage_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_stage_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_stage_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_stage_tex)
		_add_shade()
	var marks := Control.new()
	marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.draw.connect(_draw_marks.bind(marks))
	add_child(marks)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 150)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_bottom", 60)
	add_child(margin)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(h)
	_card = PanelContainer.new()
	_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_card)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_card.add_child(column)
	var hints := UiTheme.label("MOUSE OR ARROW KEYS  /  ENTER CONFIRM  /  ESC BACK", 12, Color(UiTheme.MUTED, 0.7), UiTheme.mono_font())
	hints.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hints.position = Vector2(150, -34)
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hints)
	Net.players_changed.connect(_on_players_changed)
	Net.lobby_changed.connect(_on_players_changed)
	Net.connected_as_client.connect(func() -> void: _screen_lobby())
	Net.join_failed.connect(func(reason: String) -> void: _set_status(reason, UiTheme.CORAL))
	Net.disconnected.connect(func(reason: String) -> void:
		_screen_main()
		_set_status(reason, UiTheme.CORAL))
	Net.code_search_update.connect(func(text: String) -> void: _set_status(text, UiTheme.TEAL))
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Game.open_lobby_on_menu and Net.connected:
		Game.open_lobby_on_menu = false
		_screen_lobby()
	else:
		_screen_main()
		if Game.menu_message != "":
			_set_status(Game.menu_message, UiTheme.AMBER)
			Game.menu_message = ""
		if Game.args.has("open-settings"):
			_screen_settings()
		match str(Game.args.get("open-screen", "")):
			"setup":
				_screen_setup(true)
			"host":
				_screen_setup(false)
			"join":
				_screen_join()
			"settings":
				_screen_settings()
			"credits":
				_screen_credits()
			"controls":
				_screen_controls()
	if _screen == "main":
		_start_presentation()
	_handle_cli()


## Intro on the first launch of a session (short for a player who has seen it); a plain staggered fade otherwise.
func _start_presentation() -> void:
	var play_intro := _stage != null and not Game.intro_done and not Game.args.has("skip-intro") and not Game.args.has("role") \
		and not Game.args.has("auto") and not Game.args.has("open-settings") and not Game.args.has("open-screen")
	if not play_intro:
		Game.intro_done = true
		if _stage != null:
			_stage.reveal = 1.0
		_reveal_main(false)
		return
	for n in [_kicker, _tag, _logo, _foot]:
		(n as Control).modulate.a = 0.0
	for e in _entries:
		(e as Control).modulate.a = 0.0
	_stage.reveal = 0.0
	_intro = IntroSequence.new()
	_intro.fast = Settings.intro_seen
	_intro.core_pos = _core_screen_pos()
	add_child(_intro)
	_intro.core_reveal.connect(func(v: float) -> void:
		if _stage != null:
			_stage.reveal = v)
	_intro.beat.connect(_on_intro_beat)
	_intro.finished.connect(func() -> void:
		_intro = null
		Game.intro_done = true
		if not Settings.intro_seen:
			Settings.intro_seen = true
			Settings.save_prefs()
		if _stage != null:
			_stage.reveal = 1.0)


func _core_screen_pos() -> Vector2:
	var s := size if size.x > 0.0 else Vector2(1920, 1080)
	var covered_w := maxf(s.x, s.y * 16.0 / 9.0)
	return Vector2(s.x * 0.5 + covered_w * 0.18, s.y * 0.5 - 8.0)


func _on_intro_beat(beat: String) -> void:
	if _screen != "main":
		return
	match beat:
		"tagline":
			for n in [_kicker, _tag]:
				create_tween().tween_property(n, "modulate:a", 1.0, 0.5)
		"title":
			_logo.modulate.a = 0.0
			var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			t.tween_property(_logo, "modulate:a", 1.0, 0.7)
			_logo.pivot_offset = Vector2(0, _logo.size.y * 0.5)
			_logo.scale = Vector2(1.06, 1.06)
			t.tween_property(_logo, "scale", Vector2.ONE, 0.7)
		"menu":
			_reveal_main(true)


func _reveal_main(delayed: bool) -> void:
	for n in [_kicker, _tag, _logo, _foot]:
		(n as Control).modulate.a = 1.0
	var i := 0
	for e in _entries:
		(e as MenuEntry).reveal(0.06 * i if delayed else 0.04 * i)
		i += 1
	if not _entries.is_empty() and DisplayServer.get_name() != "headless":
		(_entries[0] as Control).grab_focus.call_deferred()


func _add_shade() -> void:
	# left-to-right legibility gradient and a soft vignette; both are two cheap textures
	var grad := Gradient.new()
	grad.set_color(0, Color(UiTheme.GRAPHITE, 0.88))
	grad.set_color(1, Color(UiTheme.GRAPHITE, 0.0))
	grad.add_point(0.55, Color(UiTheme.GRAPHITE, 0.30))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0.5)
	gt.fill_to = Vector2(1, 0.5)
	var left := TextureRect.new()
	left.texture = gt
	left.set_anchors_preset(Control.PRESET_FULL_RECT)
	left.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	left.stretch_mode = TextureRect.STRETCH_SCALE
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left)
	var vg := Gradient.new()
	vg.set_color(0, Color(UiTheme.GRAPHITE, 0.0))
	vg.set_color(1, Color(UiTheme.GRAPHITE, 0.78))
	vg.add_point(0.62, Color(UiTheme.GRAPHITE, 0.0))
	var vt := GradientTexture2D.new()
	vt.gradient = vg
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.62, 0.5)
	vt.fill_to = Vector2(1.15, 1.0)
	var vig := TextureRect.new()
	vig.texture = vt
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)


# ---------------------------------------------------------------- CLI roles for automated tests
func _handle_cli() -> void:
	var a := Game.args
	if not a.has("role") or Game.cli_consumed:
		return
	Game.cli_consumed = true
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
			if a.has("switch_policy"):
				Net.lobby["switch_policy"] = str(a["switch_policy"])
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
			_set_status("CLI: joining %s:%d" % [str(a.get("ip", "127.0.0.1")), port], UiTheme.TEAL)
		"code":
			Net.join_code(str(a.get("code", "")))


func _process(delta: float) -> void:
	if _stage != null and size.x > 0.0:
		var m := get_viewport().get_mouse_position()
		_stage.set_parallax(Vector2(m.x / size.x - 0.5, m.y / size.y - 0.5) * 2.0)
	if _auto_start_t >= 0.0 and Net.is_host:
		if Net.human_count() >= _auto_min_players:
			_auto_start_t -= delta
		if _auto_start_t <= 0.0:
			_auto_start_t = -1.0
			Game.log_ev("Cli", "autostart", {"players": Net.players.size()})
			Game.host_start_match()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _intro == null and _back.is_valid():
		get_viewport().set_input_as_handled()
		Sfx.play("ui", -14.0, 0.85)
		_back.call()


# ---------------------------------------------------------------- helpers
## Starts a screen: clears the column, restyles the card (the main menu has none) and fades it in.
func _begin(screen: String, width: float = 0.0, framed: bool = true) -> void:
	_screen = screen
	_back = Callable()
	for c in column.get_children():
		column.remove_child(c)
		c.queue_free()
	status_lbl = null
	_lobby_roster = null
	_lobby_summary = null
	_lobby_start = null
	_entries = []
	_map_ui = {}
	_mode_ui = {}
	column.add_theme_constant_override("separation", 10)
	if framed:
		_card.add_theme_stylebox_override("panel", UiTheme.card_menu())
	else:
		_card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_card.custom_minimum_size = Vector2(width, 0)
	if _card_tween != null and _card_tween.is_valid():
		_card_tween.kill()
	if DisplayServer.get_name() != "headless":
		_card.modulate.a = 0.0
		_card_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_card_tween.tween_property(_card, "modulate:a", 1.0, 0.18)
	else:
		_card.modulate.a = 1.0


func _header(kicker: String, title: String, sub: String = "") -> void:
	column.add_child(UiTheme.stamp(kicker, UiTheme.TEAL, 13))
	column.add_child(UiTheme.label(title, UiTheme.SIZE_H2, UiTheme.TEXT, UiTheme.title_font(3)))
	if sub != "":
		var l := UiTheme.label(sub, UiTheme.SIZE_BODY, UiTheme.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(560, 0)
		column.add_child(l)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	column.add_child(gap)


func _button(text: String, cb: Callable, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.pressed.connect(func() -> void:
		Sfx.play("ui", -12.0, 0.9)
		cb.call())
	b.custom_minimum_size = Vector2(240, 46)
	column.add_child(b)
	return b


func _status_line() -> void:
	status_lbl = UiTheme.label("", 15, UiTheme.TEAL, UiTheme.mono_font())
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_lbl.custom_minimum_size = Vector2(560, 0)
	column.add_child(status_lbl)


func _set_status(text: String, color: Color) -> void:
	if status_lbl == null or not is_instance_valid(status_lbl):
		return
	status_lbl.text = text
	status_lbl.add_theme_color_override("font_color", color)


func _row_label(text: String) -> Label:
	var l := UiTheme.label(text, 15, UiTheme.MUTED, UiTheme.mono_font())
	l.uppercase = true
	l.custom_minimum_size = Vector2(210, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _row(label: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	row.add_child(_row_label(label))
	return row


func _option(label: String, items: Array, current: int, cb: Callable) -> OptionButton:
	var row := _row(label)
	var ob := OptionButton.new()
	for it in items:
		ob.add_item(str(it))
	ob.selected = maxi(current, 0)
	ob.item_selected.connect(func(i: int) -> void:
		Sfx.play("ui", -16.0, 1.1)
		cb.call(i))
	ob.custom_minimum_size = Vector2(330, 42)
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ob)
	return ob


func _check(label: String, value: bool, cb: Callable) -> CheckButton:
	var row := _row(label)
	var cb_btn := CheckButton.new()
	cb_btn.button_pressed = value
	cb_btn.text = "ON" if value else "OFF"
	cb_btn.toggled.connect(func(v: bool) -> void:
		cb_btn.text = "ON" if v else "OFF"
		Sfx.play("ui", -14.0, 1.2 if v else 0.9)
		cb.call(v))
	row.add_child(cb_btn)
	return cb_btn


func _line(label: String, placeholder: String, value: String = "") -> LineEdit:
	var row := _row(label)
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.text = value
	le.custom_minimum_size = Vector2(330, 44)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(le)
	return le


func _slider(label: String, minv: float, maxv: float, step: float, value: float, cb: Callable, fmt: String = "%.2f") -> HSlider:
	var row := _row(label)
	var s := HSlider.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(240, 30)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var readout := UiTheme.label(fmt % value, 15, UiTheme.TEXT, UiTheme.mono_font())
	readout.custom_minimum_size = Vector2(64, 0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(readout)
	s.value_changed.connect(func(v: float) -> void:
		readout.text = fmt % v
		cb.call(v))
	return s


# ---------------------------------------------------------------- screens
func _screen_main() -> void:
	_begin("main", 430.0, false)
	column.add_theme_constant_override("separation", 4)
	_kicker = UiTheme.stamp("PALIMPSEST  /  ARCHITECTURE OF BROKEN TIME", UiTheme.TEAL, 13)
	column.add_child(_kicker)
	_logo = UiTheme.label("ECHO" + char(10) + "CLASH", 108, UiTheme.TEXT, UiTheme.title_font(10))
	_logo.add_theme_constant_override("line_spacing", -26)
	_logo.add_theme_color_override("font_shadow_color", Color(UiTheme.TEAL, 0.22))
	_logo.add_theme_constant_override("shadow_offset_x", 0)
	_logo.add_theme_constant_override("shadow_offset_y", 5)
	column.add_child(_logo)
	_tag = UiTheme.stamp("THE ARENA REMEMBERS", UiTheme.AMBER, 19)
	column.add_child(_tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	column.add_child(gap)
	for item in [["PLAY", func() -> void: _screen_setup(true)], ["HOST LAN GAME", func() -> void: _screen_setup(false)],
			["JOIN LAN GAME", func() -> void: _screen_join()], ["SETTINGS", func() -> void: _screen_settings()],
			["CREDITS / ASSETS", func() -> void: _screen_credits()], ["EXIT", func() -> void: get_tree().quit()]]:
		var e := MenuEntry.new()
		e.text = item[0]
		e.pressed.connect(item[1])
		column.add_child(e)
		_entries.append(e)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 22)
	column.add_child(gap2)
	_foot = UiTheme.label("Room codes work on the same LAN or Wi-Fi. There is no internet matchmaking in this build.", 14, Color(UiTheme.MUTED, 0.8))
	_foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_foot.custom_minimum_size = Vector2(400, 0)
	column.add_child(_foot)
	_status_line()
	if _intro == null and not _entries.is_empty() and DisplayServer.get_name() != "headless" and Game.intro_done:
		(_entries[0] as Control).grab_focus.call_deferred()


func _screen_setup(practice: bool) -> void:
	_begin("setup", 1240.0)
	_back = func() -> void: _screen_main()
	_header("OFFLINE PRACTICE" if practice else "HOST LAN ROOM", "Match setup",
		"Choose the record to play. Bots fill the vacant seats." if practice else "Your room gets a 6-character code that other players on this Wi-Fi can join.")
	var lobby := Net.lobby
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 44)
	column.add_child(body)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 10)
	form.custom_minimum_size = Vector2(640, 0)
	body.add_child(form)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	side.custom_minimum_size = Vector2(450, 0)
	body.add_child(side)
	var main_col := column
	column = form
	form.add_child(UiTheme.section("Player"))
	_line("YOUR NAME", "PLAYER", Settings.player_name).text_changed.connect(func(t: String) -> void: Settings.player_name = t.strip_edges().to_upper().left(14))
	form.add_child(UiTheme.section("Match"))
	var modes := ["HOT RETURN / STEAL THE CORE", "RELIC RUSH / FREE FOR ALL"]
	var map_names := []
	var map_ids := []
	var cur := 0
	var k := 0
	for m in Maps.list():
		map_names.append("%s%s" % [m["name"], "" if not m["test"] else ""])
		map_ids.append(m["id"])
		if m["id"] == lobby["map"]:
			cur = k
		k += 1
	_option("MODE", modes, 0 if lobby["mode"] == "hot_return" else 1, func(i: int) -> void:
		Net.lobby["mode"] = "hot_return" if i == 0 else "relic_rush"
		_refresh_setup_state())
	_option("MAP", map_names, cur, func(i: int) -> void:
		Net.lobby["map"] = map_ids[i]
		_refresh_map_card())
	_mode_ui["team"] = _option("TEAM SIZE", ["1 v 1", "2 v 2", "3 v 3", "4 v 4"], int(lobby["team_size"]) - 1, func(i: int) -> void: Net.lobby["team_size"] = i + 1)
	_mode_ui["ffa"] = _option("PLAYERS", ["2", "4", "6", "8"], clampi(int(lobby["ffa_size"]) / 2 - 1, 0, 3), func(i: int) -> void: Net.lobby["ffa_size"] = (i + 1) * 2)
	form.add_child(UiTheme.section("Bots"))
	_check("FILL WITH BOTS", bool(lobby["bot_fill"]), func(v: bool) -> void: Net.lobby["bot_fill"] = v)
	_option("BOT DIFFICULTY", ["EASY", "MEDIUM", "HARD"], Net.DIFFICULTIES.find(str(lobby["bot_difficulty"])), func(i: int) -> void: Net.lobby["bot_difficulty"] = Net.DIFFICULTIES[i])
	form.add_child(UiTheme.section("Rules"))
	_option("ROLE SWITCH", ["EVERY ROUND", "AFTER 2 ROUNDS (HALVES)"], 1 if str(lobby.get("switch_policy", "every_round")) == "halves" else 0, func(i: int) -> void: Net.lobby["switch_policy"] = "halves" if i == 1 else "every_round")
	column = side
	_build_map_card(side)
	column = main_col
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	actions.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(actions)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(160, 50)
	back.pressed.connect(func() -> void: _screen_main())
	actions.add_child(back)
	var go := Button.new()
	go.text = "OPEN PRACTICE LOBBY" if practice else "CREATE ROOM"
	go.custom_minimum_size = Vector2(300, 50)
	UiTheme.style_primary(go)
	go.pressed.connect(func() -> void:
		Sfx.play("ui", -8.0, 1.0)
		Settings.save_prefs()
		var err := Net.host(Net.PORT, practice)
		if err != OK:
			_set_status("Could not open UDP port %d (error %d). Another instance may be hosting on this machine." % [Net.PORT, err], UiTheme.CORAL)
			return
		_screen_lobby())
	actions.add_child(go)
	_status_line()
	_refresh_setup_state()
	_refresh_map_card()


## Map card: preview image, name, mechanic tag, description and the rules of the selected mode.
func _build_map_card(into: VBoxContainer) -> void:
	into.add_child(UiTheme.section("Selected map"))
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.flat(UiTheme.GRAPHITE, UiTheme.LINE, 1, 8, 6, 6))
	into.add_child(frame)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(430, 262)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(pic)
	var name_l := UiTheme.label("", 26, UiTheme.TEXT, UiTheme.title_font(3))
	into.add_child(name_l)
	var mech := UiTheme.stamp("", UiTheme.AMBER, 13)
	into.add_child(mech)
	var blurb := UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.MUTED)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(430, 0)
	into.add_child(blurb)
	var rules := UiTheme.label("", 14, Color(UiTheme.MUTED, 0.85))
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.custom_minimum_size = Vector2(430, 0)
	into.add_child(rules)
	_map_ui = {"pic": pic, "name": name_l, "mech": mech, "blurb": blurb, "rules": rules}


func _refresh_map_card() -> void:
	if _map_ui.is_empty() or not is_instance_valid(_map_ui["pic"]):
		return
	var info := Maps.info(str(Net.lobby["map"]))
	(_map_ui["name"] as Label).text = str(info["name"])
	(_map_ui["mech"] as Label).text = ("TEST MAP  /  " if info["test"] else "") + str(info["mechanic"])
	(_map_ui["blurb"] as Label).text = str(info["blurb"])
	var path := PREVIEW_PATH % str(info["id"])
	(_map_ui["pic"] as TextureRect).texture = load(path) if ResourceLoader.exists(path) else null
	_refresh_setup_state()


func _refresh_setup_state() -> void:
	var hot := str(Net.lobby["mode"]) != "relic_rush"
	if _mode_ui.has("team") and is_instance_valid(_mode_ui["team"]):
		(_mode_ui["team"] as OptionButton).disabled = not hot
		(_mode_ui["ffa"] as OptionButton).disabled = hot
	if _map_ui.has("rules") and is_instance_valid(_map_ui["rules"]):
		(_map_ui["rules"] as Label).text = "HOT RETURN  /  attackers steal the Causal Core and carry it home before the 26 s fuse ends; Stability Fields pause it. First to 3 rounds, 2-2 goes to overtime pairs." if hot \
			else "RELIC RUSH  /  five minutes, first to 25 points, everyone for themselves."


func _screen_join() -> void:
	_begin("join", 700.0)
	_back = func() -> void:
		Net.leave()
		_screen_main()
	_header("JOIN ROOM", "Enter the archive", "Type the host's 6-character room code. Both devices must share the same LAN or Wi-Fi.")
	column.add_child(UiTheme.section("Player"))
	_line("YOUR NAME", "PLAYER", Settings.player_name).text_changed.connect(func(t: String) -> void: Settings.player_name = t.strip_edges().to_upper().left(14))
	column.add_child(UiTheme.section("Room code"))
	var code := _line("ROOM CODE", "e.g. K7PX2A")
	code.max_length = 6
	code.text_changed.connect(func(t: String) -> void:
		var up := t.to_upper()
		if up != t:
			code.text = up
			code.caret_column = up.length())
	var by_code := _button("FIND AND JOIN BY CODE", func() -> void:
		Settings.save_prefs()
		Net.join_code(code.text))
	UiTheme.style_primary(by_code)
	column.add_child(UiTheme.section("Direct connection"))
	var ip := _line("HOST IP (FALLBACK)", "e.g. 192.168.1.20")
	_button("JOIN BY IP", func() -> void:
		Settings.save_prefs()
		var addr := ip.text.strip_edges()
		if addr == "":
			_set_status("Enter the host IP address shown in their lobby.", UiTheme.CORAL)
			return
		_set_status("Connecting to %s..." % addr, UiTheme.TEAL)
		Net.join_ip(addr))
	_button("BACK", func() -> void:
		Net.leave()
		_screen_main())
	_status_line()


func _screen_lobby() -> void:
	_begin("lobby", 760.0)
	var host := Net.is_host
	_header("LOBBY  /  %s" % ("HOST" if host else "GUEST"), ("Room  %s" % Net.room_code) if not Net.lobby.get("practice", false) else "Practice lobby",
		"Share this code with players on the same Wi-Fi. They choose JOIN LAN GAME and type it." if host and not Net.lobby.get("practice", false) else "")
	if host and not Net.lobby.get("practice", false):
		var ips := []
		for addr in IP.get_local_addresses():
			if addr.find(".") >= 0 and not addr.begins_with("127.") and not addr.begins_with("169."):
				ips.append(addr)
		column.add_child(UiTheme.label("Fallback join by IP: %s   (UDP port %d)" % [", ".join(ips), Net.PORT], 14, UiTheme.MUTED, UiTheme.mono_font()))
		var copy := _button("COPY ROOM CODE", func() -> void:
			DisplayServer.clipboard_set(Net.room_code)
			_set_status("Room code %s copied to the clipboard." % Net.room_code, UiTheme.TEAL))
		copy.custom_minimum_size = Vector2(260, 44)
	_lobby_summary = UiTheme.stamp("", UiTheme.AMBER, 14)
	column.add_child(_lobby_summary)
	column.add_child(UiTheme.section("Players"))
	_lobby_roster = VBoxContainer.new()
	_lobby_roster.add_theme_constant_override("separation", 4)
	column.add_child(_lobby_roster)
	if host:
		column.add_child(UiTheme.section("Match"))
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
		_option("ROLE SWITCH", ["EVERY ROUND", "AFTER 2 ROUNDS (HALVES)"], 1 if str(lobby.get("switch_policy", "every_round")) == "halves" else 0, func(i: int) -> void: Net.set_lobby("switch_policy", "halves" if i == 1 else "every_round"))
	column.add_child(UiTheme.section("Team"))
	var teams := HBoxContainer.new()
	teams.add_theme_constant_override("separation", 12)
	column.add_child(teams)
	var t1 := Button.new()
	t1.text = "JOIN COBALT"
	t1.custom_minimum_size = Vector2(200, 44)
	t1.pressed.connect(func() -> void: Net.request_team(1))
	teams.add_child(t1)
	var t2 := Button.new()
	t2.text = "JOIN VERMILION"
	t2.custom_minimum_size = Vector2(200, 44)
	t2.pressed.connect(func() -> void: Net.request_team(2))
	teams.add_child(t2)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	actions.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(actions)
	var leave := Button.new()
	leave.text = "LEAVE ROOM"
	leave.custom_minimum_size = Vector2(180, 50)
	leave.pressed.connect(func() -> void:
		Net.leave()
		_screen_main())
	actions.add_child(leave)
	if host:
		_lobby_start = Button.new()
		_lobby_start.text = "START MATCH"
		_lobby_start.custom_minimum_size = Vector2(240, 50)
		UiTheme.style_primary(_lobby_start)
		_lobby_start.pressed.connect(func() -> void: Game.host_start_match())
		actions.add_child(_lobby_start)
	else:
		column.add_child(UiTheme.stamp("WAITING FOR THE HOST TO START", UiTheme.TEAL, 14))
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
	_lobby_roster.add_child(UiTheme.label("%d human(s) connected. Bots are added when the match starts." % Net.human_count(), 14, UiTheme.MUTED))


func _screen_settings() -> void:
	_begin("settings", 1240.0)
	_back = func() -> void: _screen_main()
	var snap := Settings.snapshot()
	_header("SETTINGS", "Calibration", "Changes apply when you press APPLY. REVERT restores the saved values.")
	var res_names := []
	var res_list := []
	for r in Settings.RESOLUTIONS:
		res_names.append("%d x %d" % [r.x, r.y])
		res_list.append(r)
	var native := DisplayServer.screen_get_size()
	res_names.append("NATIVE %d x %d" % [native.x, native.y])
	res_list.append(native)
	var cur := res_list.find(Settings.resolution)
	var main_col := column
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 56)
	main_col.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(560, 0)
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.custom_minimum_size = Vector2(560, 0)
	cols.add_child(right)
	column = left
	left.add_child(UiTheme.section("Display and graphics"))
	_option("RESOLUTION", res_names, maxi(cur, 0), func(i: int) -> void: Settings.resolution = res_list[i])
	_option("WINDOW MODE", ["WINDOWED", "BORDERLESS", "FULLSCREEN"], maxi(Settings.WINDOW_MODES.find(Settings.window_mode), 0), func(i: int) -> void: Settings.window_mode = Settings.WINDOW_MODES[i])
	_option("GRAPHICS PRESET", ["LOW", "MEDIUM", "HIGH"], Settings.PRESETS.find(Settings.preset), func(i: int) -> void:
		Settings.set_preset(Settings.PRESETS[i])
		_screen_settings())
	_option("SHADOW QUALITY", ["LOW", "MEDIUM", "HIGH"], maxi(Settings.QUALITY.find(Settings.shadow_quality), 0), func(i: int) -> void: Settings.shadow_quality = Settings.QUALITY[i])
	_option("ANTI-ALIASING", ["OFF", "FXAA", "MSAA 2X", "MSAA 4X", "TAA"], maxi(Settings.AA_MODES.find(Settings.aa_mode), 0), func(i: int) -> void: Settings.aa_mode = Settings.AA_MODES[i])
	_option("TEXTURE QUALITY", ["LOW (NO DETAIL MAPS)", "HIGH"], 0 if Settings.texture_quality == "low" else 1, func(i: int) -> void: Settings.texture_quality = "low" if i == 0 else "high")
	_option("EFFECTS QUALITY", ["LOW", "MEDIUM", "HIGH"], maxi(Settings.QUALITY.find(Settings.effects_quality), 0), func(i: int) -> void: Settings.effects_quality = Settings.QUALITY[i])
	_option("FRAME CAP", ["30", "60", "120", "144", "UNLIMITED"], maxi(Settings.FPS_CAPS.find(Settings.max_fps), 1), func(i: int) -> void: Settings.max_fps = Settings.FPS_CAPS[i])
	_check("VSYNC", Settings.vsync, func(v: bool) -> void: Settings.vsync = v)
	column = right
	right.add_child(UiTheme.section("Controls"))
	_slider("MOUSE SENSITIVITY", 0.0005, 0.006, 0.0001, Settings.mouse_sensitivity, func(v: float) -> void: Settings.mouse_sensitivity = v, "%.4f")
	_slider("FIELD OF VIEW", 70.0, 105.0, 1.0, Settings.fov, func(v: float) -> void: Settings.fov = v, "%d")
	_check("INVERT Y", Settings.invert_y, func(v: bool) -> void: Settings.invert_y = v)
	_slider("RETICLE SIZE", 0.6, 1.8, 0.1, Settings.reticle_size, func(v: float) -> void: Settings.reticle_size = v, "%.1f")
	_slider("CAMERA SHAKE", 0.0, 1.0, 0.1, Settings.shake, func(v: float) -> void: Settings.shake = v, "%.1f")
	_check("HEAD BOB", Settings.head_bob, func(v: bool) -> void: Settings.head_bob = v)
	right.add_child(UiTheme.section("Audio"))
	_slider("MASTER VOLUME", 0.0, 1.0, 0.05, Settings.master_volume, func(v: float) -> void:
		Settings.master_volume = v
		Settings.apply_audio(), "%.2f")
	for b in ["Music", "Weapons", "Effects", "Ambience", "UI"]:
		var bus_name: String = b
		_slider(bus_name.to_upper() + " VOLUME", 0.0, 1.0, 0.05, float(Settings.bus_volumes[bus_name]), func(v: float) -> void:
			Settings.bus_volumes[bus_name] = v
			Settings.apply_audio(), "%.2f")
	column = main_col
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(150, 48)
	back.pressed.connect(func() -> void: _screen_main())
	row.add_child(back)
	var ctrl := Button.new()
	ctrl.text = "CONTROLS"
	ctrl.custom_minimum_size = Vector2(170, 48)
	ctrl.pressed.connect(func() -> void: _screen_controls())
	row.add_child(ctrl)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var reset := Button.new()
	reset.text = "RESET TO DEFAULTS"
	reset.custom_minimum_size = Vector2(230, 48)
	reset.pressed.connect(func() -> void:
		Settings.reset_defaults()
		_screen_settings()
		_set_status("Defaults restored. Press APPLY to keep them.", UiTheme.AMBER))
	row.add_child(reset)
	var revert := Button.new()
	revert.text = "REVERT"
	revert.custom_minimum_size = Vector2(150, 48)
	revert.pressed.connect(func() -> void:
		Settings.restore(snap)
		Settings.apply_audio()
		Settings.apply_prefs()
		_screen_settings()
		_set_status("Reverted to the saved settings.", UiTheme.AMBER))
	row.add_child(revert)
	var apply := Button.new()
	apply.text = "APPLY"
	apply.custom_minimum_size = Vector2(170, 48)
	UiTheme.style_primary(apply)
	apply.pressed.connect(func() -> void:
		Settings.save_prefs()
		Settings.apply_window()
		Settings.apply_graphics()
		_set_status("Settings applied and saved." + (" " + Settings.last_window_note if Settings.last_window_note != "" else ""), UiTheme.TEAL))
	row.add_child(apply)
	_status_line()


func _screen_controls() -> void:
	_begin("controls", 860.0)
	_back = func() -> void: _screen_settings()
	_header("CONTROLS", "Input map")
	var controls := UiTheme.label("WASD  move               MOUSE      aim\nLMB   fire               RMB        aim down sights\n1 2 / WHEEL  switch your two weapons   B  armory (pre-round)\nR     reload             SHIFT      sprint\nSPACE jump               C          crouch\nCTRL  dash               E          pick up / interact / zipline (hold)\nG     drop the Core (carrier)\nQ     entropy ability (attack: Reverse  ·  defend: Fast-Forward)  once per round\nCAPS LOCK tactical map   TAB        scoreboard\nESC   pause", 17, UiTheme.TEXT, UiTheme.mono_font())
	column.add_child(controls)
	_button("BACK", func() -> void: _screen_settings())
	_status_line()


func _screen_credits() -> void:
	_begin("credits", 860.0)
	_back = func() -> void: _screen_main()
	_header("CREDITS / ASSETS", "The arena remembers")
	var body := UiTheme.label("ECHO CLASH is a hackathon build in Godot 4.7.2. Identity: PALIMPSEST / ARCHITECTURE OF BROKEN TIME. Game code, map layouts, shaders (toon surface, ink outline, Core, fields, portals, sea), procedural sounds and UI are original to this project." + char(10) + char(10) + "THIRD-PARTY ASSETS (all CC0, no attribution required, credited with thanks):" + char(10) + "Quaternius: Universal Base Characters, Universal Animation Library (quaternius.com)" + char(10) + "Kenney: Blaster Kit, Nature Kit, Space Station Kit, Impact Sounds (kenney.nl)" + char(10) + "Poly Haven: sandstone_cracks, painted_plaster_wall, worn_tile_floor, metal_plate, rusty_metal_02, castle_wall_slates, concrete_floor_worn_001 (polyhaven.com)" + char(10) + char(10) + "MUSIC: supplied by the project owner (assets/sfx/bg_soundtrack/theplan.wav), used unmodified as the menu soundtrack." + char(10) + char(10) + "Hot Return: steal the Causal Core and carry it home before it detonates. Reverse Entropy / Fast-Forward, once per round. Relic Rush: five-minute free-for-all. LAN only: no accounts, no telemetry, no internet matchmaking. Full list: ASSET_REGISTER.md", 16, UiTheme.TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(780, 0)
	column.add_child(body)
	_button("BACK", func() -> void: _screen_main())
	_status_line()


func _draw_marks(c: Control) -> void:
	var s := c.size
	var col := Color(UiTheme.TEAL, 0.16)
	for i in range(0, int(s.x), 96):
		c.draw_line(Vector2(i, 0), Vector2(i, s.y), Color(UiTheme.TEAL, 0.025), 1.0)
	for j in range(0, int(s.y), 96):
		c.draw_line(Vector2(0, j), Vector2(s.x, j), Color(UiTheme.TEAL, 0.025), 1.0)
	for p in [Vector2(40, 40), Vector2(s.x - 40, 40), Vector2(40, s.y - 40), Vector2(s.x - 40, s.y - 40)]:
		c.draw_line(p + Vector2(-12, 0), p + Vector2(12, 0), col, 1.0)
		c.draw_line(p + Vector2(0, -12), p + Vector2(0, 12), col, 1.0)
