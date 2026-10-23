extends CanvasLayer
## In-match interface: timer, objective, score, health, ammo, abilities, feed, notices, pause, results.

var root: Control
var timer_lbl: Label
var mode_lbl: Label
var objective_lbl: Label
var role_lbl: Label
var score_lbl: Label
var round_lbl: Label
var hp_lbl: Label
var hp_bar: ColorRect
var hp_bar_bg: Control
var ammo_lbl: Label
var ammo_state_lbl: Label
var dash_card: Dictionary
var echo_card: Dictionary
var feed_box: VBoxContainer
var notice_lbl: Label
var sub_notice_lbl: Label
var crosshair: Control
var flash: ColorRect
var protect_lbl: Label
var site_lbl: Label
var progress_box: Control
var progress_lbl: Label
var progress_bar: ColorRect
var pause_panel: PanelContainer
var results_panel: PanelContainer
var scoreboard_panel: PanelContainer
var scoreboard_body: VBoxContainer
var dead_lbl: Label
var hint_lbl: Label
var ffa_box: VBoxContainer
var _notice_t := 0.0
var _hit_t := 0.0
var _flash_t := 0.0
var _feed_items: Array = []
var _last_warn := -1
var _last_ads := false
var vol_box: VBoxContainer
var vol_lbl: Label
var vol_bar: ColorRect
var vol_bg: ColorRect


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build()
	Game.notice.connect(_on_notice)
	Game.kill_feed.connect(_on_kill)
	Game.damage_fx.connect(_on_damage)
	Game.state_changed.connect(_refresh_state)
	Game.results_ready.connect(_on_results)
	_refresh_state()


# ---------------------------------------------------------------- build
func _build() -> void:
	var mono := UiTheme.mono_font()
	var disp := UiTheme.display_font()
	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(Palette.VERMILION, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)

	# Top centre: timer + mode
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-160, 18)
	top.size = Vector2(320, 90)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(top)
	var timer_card := PanelContainer.new()
	timer_card.add_theme_stylebox_override("panel", UiTheme.card(Palette.PORCELAIN, Palette.INK, 2, 2, 6))
	top.add_child(timer_card)
	timer_lbl = UiTheme.label("01:40", 44, Palette.INK, mono)
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_card.add_child(timer_lbl)
	mode_lbl = UiTheme.stamp("COREBREAK / ROUND 1", Palette.PORCELAIN, 14)
	mode_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_lbl.add_theme_color_override("font_outline_color", Palette.INK)
	mode_lbl.add_theme_constant_override("outline_size", 5)
	top.add_child(mode_lbl)
	vol_box = VBoxContainer.new()
	vol_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	vol_box.position = Vector2(-150, 112)
	vol_box.size = Vector2(300, 40)
	root.add_child(vol_box)
	vol_lbl = UiTheme.stamp("CAUSAL CORE / CONTAINED", Palette.MINT, 13)
	vol_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vol_lbl.add_theme_color_override("font_outline_color", Palette.INK)
	vol_lbl.add_theme_constant_override("outline_size", 5)
	vol_box.add_child(vol_lbl)
	var vol_holder := Control.new()
	vol_holder.custom_minimum_size = Vector2(300, 8)
	vol_box.add_child(vol_holder)
	vol_bg = ColorRect.new()
	vol_bg.color = Color(Palette.INK, 0.6)
	vol_bg.size = Vector2(300, 8)
	vol_holder.add_child(vol_bg)
	vol_bar = ColorRect.new()
	vol_bar.color = Palette.MINT
	vol_bar.size = Vector2(0, 8)
	vol_holder.add_child(vol_bar)
	vol_box.visible = false

	# Top left: score card
	var tl := VBoxContainer.new()
	tl.position = Vector2(24, 18)
	tl.custom_minimum_size = Vector2(400, 0)
	tl.size = Vector2(400, 0)
	root.add_child(tl)
	var score_card := PanelContainer.new()
	score_card.add_theme_stylebox_override("panel", UiTheme.card(Color(Palette.INK, 0.82), Palette.STONE, 1, 2, 10))
	tl.add_child(score_card)
	var sc := VBoxContainer.new()
	score_card.add_child(sc)
	score_lbl = UiTheme.label("COBALT 0   0 VERMILION", 24, Palette.PORCELAIN, disp)
	sc.add_child(score_lbl)
	round_lbl = UiTheme.stamp("REGULATION / ROUND 1 OF 4", Palette.BRASS, 13)
	sc.add_child(round_lbl)
	role_lbl = UiTheme.label("ATTACK", 30, Palette.VERMILION, disp)
	sc.add_child(role_lbl)
	objective_lbl = UiTheme.label("Plant the Core at Site A or B", 16, Palette.PORCELAIN, UiTheme.serif_font())
	objective_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_lbl.custom_minimum_size = Vector2(380, 0)
	score_card.custom_minimum_size = Vector2(400, 0)
	sc.add_child(objective_lbl)
	site_lbl = UiTheme.stamp("SITE A / OPEN     SITE B / OPEN", Palette.MINT, 13)
	sc.add_child(site_lbl)
	ffa_box = VBoxContainer.new()
	sc.add_child(ffa_box)

	# Top right: kill feed
	feed_box = VBoxContainer.new()
	feed_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	feed_box.position = Vector2(-380, 18)
	feed_box.size = Vector2(356, 200)
	feed_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(feed_box)

	# Bottom left: health
	var bl := VBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.position = Vector2(24, -118)
	bl.size = Vector2(300, 100)
	root.add_child(bl)
	var hp_stamp := UiTheme.stamp("INTEGRITY", Palette.MINT, 13)
	bl.add_child(hp_stamp)
	hp_lbl = UiTheme.label("100", 56, Palette.PORCELAIN, mono)
	bl.add_child(hp_lbl)
	hp_bar_bg = Control.new()
	hp_bar_bg.custom_minimum_size = Vector2(260, 8)
	bl.add_child(hp_bar_bg)
	var bg := ColorRect.new()
	bg.color = Color(Palette.STONE, 0.35)
	bg.size = Vector2(260, 8)
	hp_bar_bg.add_child(bg)
	hp_bar = ColorRect.new()
	hp_bar.color = Palette.MINT
	hp_bar.size = Vector2(260, 8)
	hp_bar_bg.add_child(hp_bar)
	protect_lbl = UiTheme.stamp("SPAWN SHIELD", Palette.BRASS, 13)
	protect_lbl.visible = false
	bl.add_child(protect_lbl)

	# Bottom right: ammo + abilities
	var br := HBoxContainer.new()
	br.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	br.position = Vector2(-430, -118)
	br.size = Vector2(406, 100)
	br.alignment = BoxContainer.ALIGNMENT_END
	br.add_theme_constant_override("separation", 12)
	root.add_child(br)
	dash_card = _ability_card("CTRL", "DASH")
	br.add_child(dash_card["root"])
	echo_card = _ability_card("Q", "ECHO")
	br.add_child(echo_card["root"])
	var ammo_box := VBoxContainer.new()
	ammo_box.alignment = BoxContainer.ALIGNMENT_END
	br.add_child(ammo_box)
	ammo_state_lbl = UiTheme.stamp("PULSE CASTER", Palette.MINT, 13)
	ammo_state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_box.add_child(ammo_state_lbl)
	ammo_lbl = UiTheme.label("08", 56, Palette.PORCELAIN, mono)
	ammo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_box.add_child(ammo_lbl)

	# Centre: crosshair, notices, interaction progress
	crosshair = Control.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.draw.connect(_draw_crosshair)
	root.add_child(crosshair)
	var centre := VBoxContainer.new()
	centre.set_anchors_preset(Control.PRESET_CENTER_TOP)
	centre.position = Vector2(-400, 190)
	centre.size = Vector2(800, 120)
	centre.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(centre)
	notice_lbl = UiTheme.label("", 40, Palette.PORCELAIN, disp)
	notice_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_lbl.add_theme_color_override("font_outline_color", Palette.INK)
	notice_lbl.add_theme_constant_override("outline_size", 6)
	centre.add_child(notice_lbl)
	sub_notice_lbl = UiTheme.stamp("", Palette.BRASS, 16)
	sub_notice_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre.add_child(sub_notice_lbl)
	progress_box = Control.new()
	progress_box.set_anchors_preset(Control.PRESET_CENTER)
	progress_box.position = Vector2(-150, 60)
	progress_box.size = Vector2(300, 40)
	progress_box.visible = false
	root.add_child(progress_box)
	progress_lbl = UiTheme.stamp("PLANTING", Palette.PORCELAIN, 14)
	progress_lbl.position = Vector2(0, -22)
	progress_box.add_child(progress_lbl)
	var pbg := ColorRect.new()
	pbg.color = Color(Palette.INK, 0.7)
	pbg.size = Vector2(300, 10)
	progress_box.add_child(pbg)
	progress_bar = ColorRect.new()
	progress_bar.color = Palette.VERMILION
	progress_bar.size = Vector2(0, 10)
	progress_box.add_child(progress_bar)
	dead_lbl = UiTheme.label("", 22, Palette.PORCELAIN, UiTheme.serif_font())
	dead_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dead_lbl.position = Vector2(-300, -170)
	dead_lbl.size = Vector2(600, 30)
	dead_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(dead_lbl)
	hint_lbl = UiTheme.stamp("", Palette.PORCELAIN, 13)
	hint_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_lbl.position = Vector2(-300, -140)
	hint_lbl.size = Vector2(600, 20)
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint_lbl)

	_build_pause()
	_build_results()
	_build_scoreboard()


func _ability_card(key: String, label: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(92, 84)
	panel.add_theme_stylebox_override("panel", UiTheme.card(Color(Palette.INK, 0.82), Palette.STONE, 1, 2, 8))
	var fill := ColorRect.new()
	fill.color = Color(Palette.MINT, 0.35)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(fill)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var k := UiTheme.label(key, 26, Palette.PORCELAIN, UiTheme.mono_font())
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(k)
	var n := UiTheme.stamp(label, Palette.MINT, 13)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var cd := UiTheme.label("READY", 13, Palette.PORCELAIN, UiTheme.mono_font())
	cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cd)
	return {"root": panel, "fill": fill, "cd": cd, "name": n}


func _build_pause() -> void:
	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-220, -170)
	pause_panel.size = Vector2(440, 340)
	pause_panel.add_theme_stylebox_override("panel", UiTheme.card(Color(Palette.INK, 0.94), Palette.PORCELAIN, 1, 2, 24))
	pause_panel.visible = false
	root.add_child(pause_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pause_panel.add_child(v)
	v.add_child(UiTheme.stamp("MATCH PAUSED (LOCAL)", Palette.VERMILION, 14))
	v.add_child(UiTheme.label("ECHO CLASH", 36, Palette.PORCELAIN, UiTheme.display_font()))
	v.add_child(UiTheme.rule())
	var resume := Button.new()
	resume.text = "RESUME"
	resume.pressed.connect(func() -> void: Game.set_paused(false))
	v.add_child(resume)
	v.add_child(UiTheme.stamp("MOUSE SENSITIVITY", Palette.MINT, 13))
	var sens := HSlider.new()
	sens.min_value = 0.0005
	sens.max_value = 0.006
	sens.step = 0.0001
	sens.value = Settings.mouse_sensitivity
	sens.value_changed.connect(func(val: float) -> void:
		Settings.mouse_sensitivity = val
		Settings.save_prefs())
	v.add_child(sens)
	v.add_child(UiTheme.stamp("MASTER VOLUME", Palette.MINT, 13))
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = Settings.master_volume
	vol.value_changed.connect(func(val: float) -> void:
		Settings.master_volume = val
		Settings.save_prefs())
	v.add_child(vol)
	var controls := UiTheme.label("WASD move  ·  SHIFT sprint  ·  SPACE jump  ·  C crouch  ·  CTRL dash\nLMB fire  ·  R reload  ·  Q echo  ·  E interact  ·  TAB scoreboard", 13, Palette.STONE, UiTheme.mono_font())
	v.add_child(controls)
	var leave := Button.new()
	leave.text = "LEAVE MATCH"
	leave.pressed.connect(func() -> void: Game.return_to_menu("You left the match."))
	v.add_child(leave)


func _build_results() -> void:
	results_panel = PanelContainer.new()
	results_panel.set_anchors_preset(Control.PRESET_CENTER)
	results_panel.position = Vector2(-300, -220)
	results_panel.size = Vector2(600, 440)
	results_panel.add_theme_stylebox_override("panel", UiTheme.card(Palette.PORCELAIN, Palette.INK, 2, 2, 26))
	results_panel.visible = false
	root.add_child(results_panel)


func _build_scoreboard() -> void:
	scoreboard_panel = PanelContainer.new()
	scoreboard_panel.set_anchors_preset(Control.PRESET_CENTER)
	scoreboard_panel.position = Vector2(-320, -200)
	scoreboard_panel.size = Vector2(640, 400)
	scoreboard_panel.add_theme_stylebox_override("panel", UiTheme.card(Color(Palette.INK, 0.92), Palette.STONE, 1, 2, 20))
	scoreboard_panel.visible = false
	root.add_child(scoreboard_panel)
	scoreboard_body = VBoxContainer.new()
	scoreboard_body.add_theme_constant_override("separation", 4)
	scoreboard_panel.add_child(scoreboard_body)


# ---------------------------------------------------------------- events
func _on_notice(text: String, seconds: float) -> void:
	if seconds >= 3.0:
		Sfx.play("sting", -8.0)
	var parts := text.split("\n", true, 1)
	notice_lbl.text = parts[0]
	sub_notice_lbl.text = parts[1] if parts.size() > 1 else ""
	_notice_t = seconds


func _on_kill(killer_name: String, victim_name: String, cause: String, killer_id: int, victim_id: int) -> void:
	var l := UiTheme.label("", 15, Palette.PORCELAIN, UiTheme.mono_font())
	var verb := "ERASED" if cause == "pulse" else ("ECHOED" if cause == "echo" else "LOST")
	l.text = "%s  %s  %s" % [killer_name, verb, victim_name]
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var me := Game.local_id()
	if killer_id == me:
		l.add_theme_color_override("font_color", Palette.MINT)
	elif victim_id == me:
		l.add_theme_color_override("font_color", Palette.VERMILION)
	feed_box.add_child(l)
	_feed_items.append({"node": l, "t": 6.0})
	if victim_id == me:
		dead_lbl.text = "ELIMINATED BY %s" % killer_name
	if feed_box.get_child_count() > 6:
		var first := feed_box.get_child(0)
		feed_box.remove_child(first)
		first.queue_free()


func _on_damage(victim_id: int, attacker_id: int, _amount: float, _hp_after: float, _cause: String) -> void:
	var me := Game.local_id()
	if attacker_id == me:
		_hit_t = 0.18
		crosshair.queue_redraw()
	if victim_id == me:
		_flash_t = 0.3


func _on_results(r: Dictionary) -> void:
	for c in results_panel.get_children():
		c.queue_free()
	pause_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	results_panel.add_child(v)
	v.add_child(UiTheme.stamp("MATCH RECORD / %s / %s" % [str(r.get("mode", "")).to_upper(), str(r.get("map", "")).to_upper()], Palette.VERMILION, 14))
	v.add_child(UiTheme.label(str(r.get("winner_text", "MATCH OVER")), 40, Palette.INK, UiTheme.display_font()))
	v.add_child(UiTheme.label(str(r.get("reason", "")), 18, Palette.INK, UiTheme.serif_font()))
	v.add_child(UiTheme.rule(Palette.INK))
	var rows: Array = r.get("rows", [])
	var head := UiTheme.stamp("PLAYER                  TEAM    K    D    PTS", Palette.INK, 13)
	v.add_child(head)
	for row in rows:
		var line := UiTheme.label("%-22s %-7s %3d  %3d  %4d" % [str(row.get("name", "")).left(22), str(row.get("team", "")), int(row.get("kills", 0)), int(row.get("deaths", 0)), int(row.get("points", 0))], 15, Palette.INK, UiTheme.mono_font())
		v.add_child(line)
	v.add_child(UiTheme.rule(Palette.INK))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	if Game.is_server():
		var rematch := Button.new()
		rematch.text = "REMATCH"
		rematch.pressed.connect(func() -> void: Game.host_rematch())
		h.add_child(rematch)
		var lobby := Button.new()
		lobby.text = "BACK TO LOBBY"
		lobby.pressed.connect(func() -> void: Game.host_back_to_lobby())
		h.add_child(lobby)
	else:
		h.add_child(UiTheme.stamp("WAITING FOR HOST: REMATCH OR LOBBY", Palette.INK, 13))
	var menu := Button.new()
	menu.text = "MAIN MENU"
	menu.pressed.connect(func() -> void: Game.return_to_menu(""))
	h.add_child(menu)
	results_panel.visible = true


func _refresh_state() -> void:
	var s := Game.state
	var mode := str(s.get("mode", Game.mode_id))
	var phase := str(s.get("phase", ""))
	if mode == "hot_return":
		var scores: Dictionary = s.get("scores", {1: 0, 2: 0})
		score_lbl.text = "COBALT %d   %d VERMILION" % [int(scores.get(1, 0)), int(scores.get(2, 0))]
		var ot := bool(s.get("overtime", false))
		round_lbl.text = "%s / ROUND %d%s" % ["OVERTIME" if ot else "REGULATION", int(s.get("round", 1)), "" if ot else " OF 4"]
		var me := Game.local_player
		var team := me.team if me != null and is_instance_valid(me) else 0
		var roles: Dictionary = s.get("roles", {})
		var role := str(roles.get(team, "")).to_upper()
		role_lbl.text = role
		role_lbl.add_theme_color_override("font_color", Palette.VERMILION if role == "ATTACK" else Palette.COBALT)
		if role == "ATTACK":
			objective_lbl.text = "ATTACK: steal the Causal Core from the enemy vault and reach your Stabilizer before it detonates"
			echo_card["name"].text = "REVERSE"
		elif role == "DEFEND":
			objective_lbl.text = "DEFEND: hold the vault, pressure the carrier, let the Core reach 100%"
			echo_card["name"].text = "FAST-FWD"
		else:
			objective_lbl.text = str(s.get("objective", ""))
		mode_lbl.text = "HOT RETURN / %s" % phase.to_upper().replace("_", " ")
		ffa_box.visible = false
		site_lbl.visible = true
		role_lbl.visible = true
		round_lbl.visible = true
		vol_box.visible = true
	elif mode == "corebreak":
		var scores: Dictionary = s.get("scores", {1: 0, 2: 0})
		score_lbl.text = "COBALT %d   %d VERMILION" % [int(scores.get(1, 0)), int(scores.get(2, 0))]
		var ot := bool(s.get("overtime", false))
		round_lbl.text = "%s / ROUND %d%s" % ["OVERTIME" if ot else "REGULATION", int(s.get("round", 1)), "" if ot else " OF 4"]
		var me := Game.local_player
		var team := me.team if me != null and is_instance_valid(me) else 0
		var roles: Dictionary = s.get("roles", {})
		var role := str(roles.get(team, "")).to_upper()
		role_lbl.text = role
		role_lbl.add_theme_color_override("font_color", Palette.VERMILION if role == "ATTACK" else Palette.COBALT)
		if role == "ATTACK":
			objective_lbl.text = "ATTACK: carry the Core (E) and plant it at Site A or B"
		elif role == "DEFEND":
			objective_lbl.text = "DEFEND: stop the plant, or defuse the planted Core (hold E)"
		else:
			objective_lbl.text = str(s.get("objective", ""))
		var core: Dictionary = s.get("core", {})
		var planted := str(core.get("planted_site", ""))
		var a_state := "PLANTED" if planted == "A" else "OPEN"
		var b_state := "PLANTED" if planted == "B" else "OPEN"
		site_lbl.text = "SITE A / %s     SITE B / %s" % [a_state, b_state]
		mode_lbl.text = "COREBREAK / %s" % phase.to_upper().replace("_", " ")
		ffa_box.visible = false
		site_lbl.visible = true
		role_lbl.visible = true
		round_lbl.visible = true
	else:
		score_lbl.text = "RELIC RUSH / FIRST TO %d" % int(s.get("target", 25))
		round_lbl.visible = false
		role_lbl.visible = false
		site_lbl.visible = false
		objective_lbl.text = str(s.get("objective", "Eliminate (2), collect shards (1), hold the Beacon (1 / 4 s)"))
		mode_lbl.text = "RELIC RUSH / %s" % phase.to_upper().replace("_", " ")
		ffa_box.visible = true
		_refresh_ffa(s)
	if Game.results.is_empty():
		results_panel.visible = false


func _refresh_ffa(s: Dictionary) -> void:
	for c in ffa_box.get_children():
		c.queue_free()
	var pts: Dictionary = s.get("points", {})
	var ids := pts.keys()
	ids.sort_custom(func(a, b) -> bool: return int(pts[a]) > int(pts[b]))
	var rank := 1
	for id in ids:
		var info: Dictionary = Net.players.get(int(id), {})
		var l := UiTheme.label("%d  %s %-12s %3d" % [rank, Palette.glyph(int(info.get("glyph", 0))), str(info.get("name", "?")).left(12), int(pts[id])], 14, Palette.player_color(info) if not info.is_empty() else Palette.PORCELAIN, UiTheme.mono_font())
		if int(id) == Game.local_id():
			l.add_theme_color_override("font_color", Palette.MINT)
		ffa_box.add_child(l)
		rank += 1
		if rank > 8:
			break
	var beacon: Dictionary = s.get("beacon", {})
	if not beacon.is_empty():
		var owner := str(beacon.get("owner_name", ""))
		var txt := "BEACON / OPEN"
		if bool(beacon.get("contested", false)):
			txt = "BEACON / CONTESTED"
		elif owner != "":
			txt = "BEACON / HELD BY %s" % owner
		ffa_box.add_child(UiTheme.stamp(txt + "   (rotates in %ds)" % int(beacon.get("rotate_in", 0)), Palette.BRASS, 13))


# ---------------------------------------------------------------- per frame
func _process(delta: float) -> void:
	var p := Game.local_player
	var tl := Game.time_left
	timer_lbl.text = "%02d:%02d" % [int(tl) / 60, int(tl) % 60]
	var warn := tl <= 10.0 and tl > 0.0
	timer_lbl.add_theme_color_override("font_color", Palette.VERMILION if warn else Palette.INK)
	if p != null and is_instance_valid(p) and p.ads != _last_ads:
		_last_ads = p.ads
		crosshair.queue_redraw()
	if p != null and is_instance_valid(p):
		hp_lbl.text = "%03d" % int(ceil(p.hp))
		hp_bar.size.x = 260.0 * clampf(p.hp / Player.MAX_HP, 0.0, 1.0)
		hp_bar.color = Palette.MINT if p.hp > 50 else (Palette.BRASS if p.hp > 25 else Palette.VERMILION)
		ammo_lbl.text = "%02d / %03d" % [p.ammo, p.reserve]
		var wname := str(Weapons.get_data(p.weapon_id)["name"])
		if p.reload_t > 0.0:
			ammo_state_lbl.text = "%s / RELOADING %0.1f" % [wname, p.reload_t]
			ammo_state_lbl.add_theme_color_override("font_color", Palette.BRASS)
		elif p.ammo == 0:
			ammo_state_lbl.text = "%s / EMPTY / PRESS R" % wname if p.reserve > 0 else "%s / NO AMMO" % wname
			ammo_state_lbl.add_theme_color_override("font_color", Palette.VERMILION)
		else:
			ammo_state_lbl.text = "%s / %d" % [wname, int(Weapons.get_data(p.weapon_id)["slot"])]
			ammo_state_lbl.add_theme_color_override("font_color", Palette.MINT)
		_update_card(dash_card, p.dash_cd, Player.DASH_COOLDOWN)
		if Game.mode_id == "hot_return":
			var roles: Dictionary = Game.state.get("roles", {})
			var spent := p.ff_spent if str(roles.get(p.team, "")) == "DEFEND" else p.re_spent
			_update_charge(echo_card, not spent)
			_update_hotreturn_live(p)
		else:
			_update_card(echo_card, p.echo_cd, 18.0)
		protect_lbl.visible = p.spawn_protect_t > 0.0
		dead_lbl.visible = not p.alive
		if p.alive:
			dead_lbl.text = ""
		elif Game.spectating != "":
			dead_lbl.text = "ELIMINATED / SPECTATING %s" % Game.spectating
		var hint := ""
		var core_live: Dictionary = Game.live.get("core", {})
		if str(core_live.get("mode", "")) == "planted":
			hint = "CORE PLANTED AT SITE %s / DETONATION IN %d" % [str(core_live.get("site", "")), int(ceil(float(core_live.get("detonate", 0.0))))]
		if p.stagger_t > 0.0:
			hint = "STAGGERED"
		elif p.carrying_core:
			hint = "CARRYING THE RESONANCE CORE / hold E inside a site to plant"
		hint_lbl.text = hint
		var prog: Dictionary = Game.live.get("interaction", {})
		if not prog.is_empty() and int(prog.get("player", 0)) == p.id:
			progress_box.visible = true
			progress_lbl.text = str(prog.get("label", ""))
			progress_bar.size.x = 300.0 * clampf(float(prog.get("fraction", 0.0)), 0.0, 1.0)
		else:
			progress_box.visible = false
	if _notice_t > 0.0:
		_notice_t -= delta
		if _notice_t <= 0.0:
			notice_lbl.text = ""
			sub_notice_lbl.text = ""
	if _hit_t > 0.0:
		_hit_t -= delta
		crosshair.queue_redraw()
	if _flash_t > 0.0:
		_flash_t -= delta
		flash.color.a = clampf(_flash_t / 0.3, 0.0, 1.0) * 0.28
	else:
		flash.color.a = 0.0
	var keep: Array = []
	for it in _feed_items:
		it["t"] -= delta
		if it["t"] <= 0.0:
			if is_instance_valid(it["node"]):
				it["node"].queue_free()
		else:
			keep.append(it)
	_feed_items = keep
	pause_panel.visible = Game.paused_local and Game.results.is_empty()
	crosshair.visible = p != null and is_instance_valid(p) and p.alive and not Game.paused_local and Game.results.is_empty()
	var sb := (Input.is_action_pressed("scoreboard") and Game.autopilot == null) or Game.args.has("show-scoreboard")
	if sb != scoreboard_panel.visible:
		scoreboard_panel.visible = sb
		if sb:
			_refresh_scoreboard()


func _update_charge(card: Dictionary, available: bool) -> void:
	var fill: ColorRect = card["fill"]
	var panel: PanelContainer = card["root"]
	fill.size = Vector2(panel.size.x, panel.size.y if available else 0.0)
	fill.position = Vector2(0, panel.size.y - fill.size.y)
	var cdl: Label = card["cd"]
	cdl.text = "AVAILABLE" if available else "SPENT"
	cdl.add_theme_color_override("font_color", Palette.MINT if available else Palette.VERMILION)


func _update_hotreturn_live(p: Player) -> void:
	var core: Dictionary = Game.live.get("core", {})
	var mode := str(core.get("mode", "cradle"))
	var v := float(core.get("v", 0.0))
	var k := clampf(v / 100.0, 0.0, 1.0)
	vol_bar.size.x = 300.0 * k
	vol_bar.color = Palette.MINT if k < 0.5 else (Palette.BRASS if k < 0.8 else Palette.VERMILION)
	var txt := ""
	match mode:
		"cradle":
			txt = "CAUSAL CORE / CONTAINED IN THE VAULT"
		"carried":
			txt = "CORE / %s CARRYING / %d%%" % [str(core.get("carrier_name", "")), int(v)]
		"dropped":
			txt = "CORE / DROPPED / %d%% TICKING" % int(v)
		"locked":
			var ll := float(core.get("lock_left", 0.0))
			txt = "CORE / TEMPORAL LOCK / %d%% FROZEN%s" % [int(v), (" / %0.1f s" % ll) if ll > 0.0 else " / PICK UP"]
		"stabilized":
			txt = "CORE / STABILIZED"
		"detonated":
			txt = "CORE / DETONATED"
	vol_lbl.text = txt
	vol_lbl.add_theme_color_override("font_color", Palette.COBALT if mode == "locked" else (Palette.MINT if k < 0.5 else (Palette.BRASS if k < 0.8 else Palette.VERMILION)))
	var fields: Array = Game.live.get("fields", [])
	var ftxt := ""
	for i in fields.size():
		ftxt += "%sFIELD %s %0.1fs" % ["   " if i > 0 else "", ["A", "B"][i % 2], float(fields[i].get("remaining", 0.0))]
	site_lbl.text = ftxt
	var ff: Dictionary = Game.live.get("ff", {})
	if bool(ff.get("active", false)):
		hint_lbl.text = "FAST-FORWARD ACTIVE / %0.1f s" % float(ff.get("left", 0.0))
	if p.rewind_t > 0.0:
		hint_lbl.text = "REVERSE ENTROPY / RE-TRAVERSING YOUR ROUTE  ·  AIM AND FIRE FREELY"


func _update_card(card: Dictionary, cd: float, total: float) -> void:
	var frac := 1.0 - clampf(cd / total, 0.0, 1.0)
	var fill: ColorRect = card["fill"]
	var panel: PanelContainer = card["root"]
	fill.size = Vector2(panel.size.x, panel.size.y * frac)
	fill.position = Vector2(0, panel.size.y - fill.size.y)
	var cdl: Label = card["cd"]
	if cd > 0.0:
		cdl.text = "%04.1f" % cd
		cdl.add_theme_color_override("font_color", Palette.STONE)
	else:
		cdl.text = "READY"
		cdl.add_theme_color_override("font_color", Palette.MINT)


func _refresh_scoreboard() -> void:
	for c in scoreboard_body.get_children():
		c.queue_free()
	scoreboard_body.add_child(UiTheme.stamp("MATCH RECORD / %s / ROOM %s" % [Game.mode_id.to_upper(), Net.room_code], Palette.VERMILION, 14))
	scoreboard_body.add_child(UiTheme.label("%-18s %-10s %-5s %4s %4s %5s" % ["PLAYER", "TEAM", "TYPE", "K", "D", "PTS"], 14, Palette.STONE, UiTheme.mono_font()))
	scoreboard_body.add_child(UiTheme.rule())
	var ids := Net.players.keys()
	ids.sort_custom(func(a, b) -> bool:
		var pa: Dictionary = Net.players[a]
		var pb: Dictionary = Net.players[b]
		if int(pa["team"]) != int(pb["team"]):
			return int(pa["team"]) < int(pb["team"])
		return int(pa["points"]) + int(pa["kills"]) > int(pb["points"]) + int(pb["kills"]))
	for id in ids:
		var info: Dictionary = Net.players[id]
		var l := UiTheme.label("%s %-16s %-10s %-5s %4d %4d %5d" % [Palette.glyph(int(info["glyph"])), str(info["name"]).left(16), Palette.team_name(int(info["team"])), "BOT" if info["is_bot"] else "HUMAN", int(info["kills"]), int(info["deaths"]), int(info["points"])], 14, Palette.player_color(info), UiTheme.mono_font())
		scoreboard_body.add_child(l)


func _draw_crosshair() -> void:
	var c := Palette.VERMILION if _hit_t > 0.0 else Palette.PORCELAIN
	var p := Game.local_player
	var ads_now := p != null and is_instance_valid(p) and p.ads
	var gap := 3.0 if ads_now else 6.0
	var len := 7.0 if ads_now else 9.0
	var w := 2.0
	if ads_now and p.weapon_id == "sniper":
		crosshair.draw_arc(Vector2.ZERO, 120.0, 0.0, TAU, 96, Color(c, 0.9), 2.0)
		crosshair.draw_arc(Vector2.ZERO, 40.0, 0.0, TAU, 48, Color(c, 0.6), 1.0)
		crosshair.draw_line(Vector2(-120, 0), Vector2(-40, 0), c, 1.0)
		crosshair.draw_line(Vector2(40, 0), Vector2(120, 0), c, 1.0)
		crosshair.draw_line(Vector2(0, -120), Vector2(0, -40), c, 1.0)
		crosshair.draw_line(Vector2(0, 40), Vector2(0, 120), c, 1.0)
	crosshair.draw_line(Vector2(-gap - len, 0), Vector2(-gap, 0), c, w)
	crosshair.draw_line(Vector2(gap, 0), Vector2(gap + len, 0), c, w)
	crosshair.draw_line(Vector2(0, -gap - len), Vector2(0, -gap), c, w)
	crosshair.draw_line(Vector2(0, gap), Vector2(0, gap + len), c, w)
	if _hit_t > 0.0:
		var d := 14.0
		crosshair.draw_line(Vector2(-d, -d), Vector2(-d + 6, -d + 6), c, w)
		crosshair.draw_line(Vector2(d, -d), Vector2(d - 6, -d + 6), c, w)
		crosshair.draw_line(Vector2(-d, d), Vector2(-d + 6, d - 6), c, w)
		crosshair.draw_line(Vector2(d, d), Vector2(d - 6, d - 6), c, w)
