class_name Armory
extends CanvasLayer
## Armory screen: pick any two distinct weapons for free. Opens at the start of a match (server-driven, with a
## timeout so nobody waits forever) and can be re-opened with the armory key during a round's pre-round countdown.
## Front-end style: graphite surfaces, teal for interaction, amber for the secondary slot, warm off-white text.
## The screen only collects picks; the server validates and applies them (ArmoryFlow).

const CARD_W := 270.0
const CARD_H := 330.0

static var last_picks: Array = Loadout.DEFAULT.duplicate()   # remembered between rounds and rematches

var open := false
var initial := true
var picks: Array = []                  # [slot1, slot2] weapon ids; "" while a slot is empty
var time_left := 0.0
var waiting := false                   # confirmed, waiting for the other players (initial phase)
var notice := ""

var _dim: ColorRect
var _panel: PanelContainer
var _cards: Dictionary = {}            # weapon id -> {root, badge, name, style}
var _slot_lbl: Array = []
var _timer_lbl: Label
var _status_lbl: Label
var _confirm: Button
var _close_btn: Button
var _hint: Label
var _previews: Array = []              # [{node, vp}]


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_dim.visible = false
	_panel.visible = false
	Game.armory_requested.connect(_on_requested)
	Game.armory_ack.connect(_on_ack)
	Game.armory_closed.connect(_on_closed)


func _exit_tree() -> void:
	if open:
		Game.armory_open = false


# ---------------------------------------------------------------- build
func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(UiTheme.GRAPHITE, 0.93)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_hint = UiTheme.stamp("[B]  ARMORY  /  CHANGE LOADOUT", UiTheme.TEAL, 15)
	_hint.add_theme_color_override("font_outline_color", UiTheme.GRAPHITE)
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position = Vector2(-170, -112)
	_hint.size = Vector2(340, 24)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.visible = false
	add_child(_hint)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.add_child(center)
	_panel = PanelContainer.new()
	_panel.theme = UiTheme.menu_theme()
	center.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	_panel.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	titles.add_child(UiTheme.label("ARMORY", UiTheme.SIZE_H2 + 8, UiTheme.TEXT, UiTheme.title_font(8)))
	titles.add_child(UiTheme.label("Choose any two different weapons. Everything is free.", UiTheme.SIZE_BODY, UiTheme.MUTED))
	_timer_lbl = UiTheme.label("", 26, UiTheme.AMBER, UiTheme.mono_font())
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timer_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_timer_lbl)

	col.add_child(UiTheme.section("Your two slots"))
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 14)
	col.add_child(slots)
	for i in 2:
		var pc := PanelContainer.new()
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var accent := UiTheme.TEAL if i == 0 else UiTheme.AMBER
		pc.add_theme_stylebox_override("panel", UiTheme.flat(Color(accent, 0.10), Color(accent, 0.7), 1, 6, 16, 10))
		slots.add_child(pc)
		var l := UiTheme.label("", 22, UiTheme.TEXT, UiTheme.title_font(2))
		pc.add_child(l)
		_slot_lbl.append(l)

	col.add_child(UiTheme.section("Weapons"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	for wid in Weapons.ARMORY:
		row.add_child(_make_card(wid))

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	col.add_child(foot)
	_status_lbl = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.MUTED)
	_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_status_lbl)
	var def_btn := Button.new()
	def_btn.text = "DEFAULT  (RIFLE + DESERT EAGLE)"
	def_btn.pressed.connect(func() -> void: set_picks(Loadout.DEFAULT))
	foot.add_child(def_btn)
	_close_btn = Button.new()
	_close_btn.text = "CLOSE"
	_close_btn.pressed.connect(close_local)
	foot.add_child(_close_btn)
	_confirm = Button.new()
	_confirm.text = "CONFIRM LOADOUT"
	UiTheme.style_primary(_confirm)
	_confirm.pressed.connect(confirm)
	foot.add_child(_confirm)
	col.add_child(UiTheme.label("Keys 1 / 2 and the mouse wheel switch between your two weapons in the match. R reloads.  Click a weapon to equip it; click again to drop it.", UiTheme.SIZE_SMALL, UiTheme.MUTED))


func _make_card(wid: String) -> Control:
	var w := Weapons.get_data(wid)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			toggle(wid))
	card.mouse_entered.connect(func() -> void: _style_card(wid, true))
	card.mouse_exited.connect(func() -> void: _style_card(wid, false))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var nm := UiTheme.label(str(w["name"]), 21, UiTheme.TEXT, UiTheme.title_font(2))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(nm)
	var badge := UiTheme.stamp("", UiTheme.GRAPHITE, 13)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(badge)
	var prev := _make_preview(wid)
	prev.custom_minimum_size = Vector2(CARD_W - 28, 112)
	prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(prev)
	var role := UiTheme.label(str(Loadout.ROLE.get(wid, "")), UiTheme.SIZE_SMALL + 1, UiTheme.TEXT)
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role.custom_minimum_size = Vector2(CARD_W - 28, 40)
	role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(role)
	var bars := [
		["DAMAGE", clampf(float(w["damage"]) * float(w["pellets"]) * (0.45 if int(w["pellets"]) > 1 else 1.0) / 95.0, 0.05, 1.0)],
		["FIRE RATE", clampf((1.0 / float(w["rof"])) / 10.5, 0.05, 1.0)],
		["RANGE", clampf(float(w["range"]) / 300.0, 0.05, 1.0)],
		["ACCURACY", clampf(1.0 - float(w["spread"]) * 9.0, 0.05, 1.0)],
	]
	for b in bars:
		v.add_child(_stat_row(str(b[0]), float(b[1])))
	var facts := UiTheme.label("MAG %d / RESERVE %d   RELOAD %.1fs   %s" % [int(w["mag"]), int(w["reserve"]), float(w["reload"]), "AUTO" if bool(w["auto"]) else "SEMI"], 12, UiTheme.MUTED, UiTheme.mono_font())
	facts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(facts)
	_cards[wid] = {"root": card, "badge": badge, "name": nm}
	_style_card(wid, false)
	return card


func _stat_row(label: String, value: float) -> Control:
	var r := HBoxContainer.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_constant_override("separation", 8)
	var l := UiTheme.label(label, 11, UiTheme.MUTED, UiTheme.mono_font())
	l.custom_minimum_size = Vector2(78, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(l)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(150, 8)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(holder)
	var bg := ColorRect.new()
	bg.color = UiTheme.LINE
	bg.size = Vector2(150, 6)
	bg.position = Vector2(0, 1)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bg)
	var fg := ColorRect.new()
	fg.color = UiTheme.TEAL
	fg.size = Vector2(150.0 * value, 6)
	fg.position = Vector2(0, 1)
	fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(fg)
	return r


## Small rotating 3D model of the weapon (own World3D so it never touches the match scene).
func _make_preview(wid: String) -> Control:
	if DisplayServer.get_name() == "headless":
		return Control.new()
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(int(CARD_W - 28), 112)
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	vp.positional_shadow_atlas_size = 0   # no omni/spot shadows in a preview: skip allocating the atlas
	vpc.add_child(vp)
	var model := WeaponModels.build(wid)
	if model != null:
		var pivot := Node3D.new()
		vp.add_child(pivot)
		pivot.add_child(model)
		var length := float(model.get_meta("length", 0.8))
		model.position = Vector3(0, -0.03, length * 0.38)   # centre the barrel/grip span on the turntable axis
		var dist := length * 1.45 + 0.3
		var cam := Camera3D.new()
		cam.fov = 28.0
		vp.add_child(cam)
		cam.look_at_from_position(Vector3(0, dist * 0.18, dist), Vector3.ZERO)
		pivot.rotation.y = 0.6
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-35, 40, 0)
		light.light_energy = 1.4
		vp.add_child(light)
		var env := Environment.new()
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.75, 0.8, 0.85)
		env.ambient_light_energy = 0.9
		var we := WorldEnvironment.new()
		we.environment = env
		vp.add_child(we)
		_previews.append({"node": pivot})
	return vpc


func _process(delta: float) -> void:
	for pv in _previews:
		var n: Node3D = pv["node"]
		if is_instance_valid(n) and open:
			n.rotation.y += delta * 0.7
	# the pre-round hint
	var show_hint := not open and _can_reopen()
	if _hint.visible != show_hint:
		_hint.visible = show_hint
	if not open:
		return
	time_left = maxf(0.0, time_left - delta)
	_timer_lbl.text = ("AUTO-CONFIRM %02d" % int(ceil(time_left))) if not waiting else "WAITING FOR PLAYERS"
	if not initial and str(Game.state.get("phase", "")) != "pre_round":
		_finish_close("ROUND STARTED")
		return
	if time_left <= 0.0 and not waiting:
		# timeout fallback on the client: answer with whatever is picked (the server also enforces its own timeout)
		if _complete():
			confirm()
		elif initial:
			Game.submit_loadout(Loadout.DEFAULT)
			_after_confirm()
		else:
			_finish_close("")


func _can_reopen() -> bool:
	var p := Game.local_player
	return Game.in_match and p != null and is_instance_valid(p) and p.alive and Game.results.is_empty() and not Game.paused_local \
		and str(Game.state.get("phase", "")) == "pre_round" and Game.autopilot == null and DisplayServer.get_name() != "headless"


# ---------------------------------------------------------------- picks
func _complete() -> bool:
	return picks.size() == 2 and str(picks[0]) != "" and str(picks[1]) != "" and str(picks[0]) != str(picks[1])


func set_picks(p: Array) -> void:
	picks = [str(p[0]) if p.size() > 0 else "", str(p[1]) if p.size() > 1 else ""]
	_refresh()


## Click / key on a weapon: equip into the first free slot, or remove it if already chosen. With both slots full a
## new weapon replaces slot 2 (the first stays), so any two distinct weapons stay one click away.
func toggle(wid: String) -> void:
	if waiting:
		return
	if picks.size() != 2:
		picks = ["", ""]
	if picks[0] == wid:
		picks[0] = ""
	elif picks[1] == wid:
		picks[1] = ""
	elif picks[0] == "":
		picks[0] = wid
	elif picks[1] == "":
		picks[1] = wid
	else:
		picks[1] = wid
	_refresh()


func _style_card(wid: String, hover: bool) -> void:
	var c: Dictionary = _cards[wid]
	var idx := picks.find(wid) if picks.size() == 2 else -1
	var bg := UiTheme.SURFACE
	var edge := UiTheme.LINE
	var bw := 1
	if idx >= 0:
		var accent := UiTheme.TEAL if idx == 0 else UiTheme.AMBER
		bg = Color(accent, 0.12)
		edge = accent
		bw = 3
	elif hover and not waiting:
		edge = Color(UiTheme.TEAL, 0.6)
		bg = UiTheme.SURFACE_HI
	(c["root"] as PanelContainer).add_theme_stylebox_override("panel", UiTheme.flat(bg, edge, bw, 8, 14, 12))
	var badge: Label = c["badge"]
	if idx >= 0:
		badge.text = " SLOT %d " % (idx + 1)
		var accent2 := UiTheme.TEAL if idx == 0 else UiTheme.AMBER
		badge.add_theme_color_override("font_color", UiTheme.GRAPHITE)
		badge.add_theme_stylebox_override("normal", UiTheme.flat(accent2, accent2, 0, 4, 4, 1))
	else:
		badge.text = ""
		badge.remove_theme_stylebox_override("normal")


func _refresh() -> void:
	for i in 2:
		var id := str(picks[i]) if picks.size() == 2 else ""
		var l: Label = _slot_lbl[i]
		l.text = "SLOT %d   %s" % [i + 1, str(Weapons.get_data(id)["name"]) if id != "" else "- EMPTY -"]
		l.add_theme_color_override("font_color", UiTheme.TEXT if id != "" else UiTheme.MUTED)
	for wid in _cards:
		_style_card(wid, false)
	var ok := _complete()
	_confirm.disabled = not ok or waiting
	_confirm.text = "CONFIRMED" if waiting else "CONFIRM LOADOUT"
	if waiting:
		_status_lbl.text = "Loadout locked in. The match starts when everyone is ready or the timer ends."
	elif ok:
		_status_lbl.text = "Ready. Slot 1 is drawn first on every spawn."
	else:
		_status_lbl.text = "Pick two different weapons to continue."
	if notice != "":
		_status_lbl.text = notice
	_close_btn.visible = not initial and not waiting


# ---------------------------------------------------------------- flow
func open_screen(seconds: float, is_initial: bool) -> void:
	if open:
		return
	open = true
	initial = is_initial
	waiting = false
	notice = ""
	time_left = seconds
	var cur := last_picks
	if is_initial and Game.args.has("loadout"):
		cur = Game.cli_loadout()   # --loadout=a,b preselects the screen (screenshots, tests)
	var lp := Game.local_player
	if not is_initial and lp != null and is_instance_valid(lp):
		cur = lp.loadout
	set_picks(cur)
	_dim.visible = true
	_panel.visible = true
	Game.armory_open = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_confirm.grab_focus()
	Game.log_ev("Armory", "ui_open", {"initial": is_initial, "seconds": seconds})


func confirm() -> void:
	if not open or waiting or not _complete():
		return
	last_picks = picks.duplicate()
	Game.submit_loadout(picks)
	_after_confirm()


func _after_confirm() -> void:
	if initial:
		waiting = true
		_refresh()   # stay up until the server closes the phase
	else:
		_finish_close("")


func close_local() -> void:
	if not initial:
		_finish_close("")


func _finish_close(msg: String) -> void:
	if not open:
		return
	open = false
	waiting = false
	_dim.visible = false
	_panel.visible = false
	Game.armory_open = false
	if DisplayServer.get_name() != "headless" and not Game.paused_local and Game.results.is_empty() and Game.autopilot == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if msg != "":
		Game.notice.emit(msg, 1.5)
	Game.log_ev("Armory", "ui_close", {"msg": msg})


func _on_requested(seconds: float, is_initial: bool) -> void:
	open_screen(seconds, is_initial)


func _on_ack(p: Array, accepted: bool, reason: String) -> void:
	if p.size() == 2:
		last_picks = p.duplicate()
	if not accepted and reason != "":
		Game.notice.emit(reason, 2.0)
		notice = reason if open else ""
		if open:
			set_picks(p)


func _on_closed() -> void:
	if open and initial:
		_finish_close("")


func _input(event: InputEvent) -> void:
	if not open:
		if event.is_action_pressed("armory") and _can_reopen():
			open_screen(maxf(1.0, Game.time_left), false)
			get_viewport().set_input_as_handled()
		return
	# the screen swallows pause, map and every combat key while open
	if event.is_action_pressed("pause"):
		if not initial:
			close_local()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("armory"):
		if not initial:
			close_local()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and ((event as InputEventKey).physical_keycode == KEY_ENTER or (event as InputEventKey).physical_keycode == KEY_KP_ENTER):
		confirm()
		get_viewport().set_input_as_handled()
