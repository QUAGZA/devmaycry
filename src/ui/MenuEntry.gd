class_name MenuEntry
extends Button
## Main-menu entry: flat text on the dark stage with a teal edge and a gentle lift on hover or keyboard focus, a short
## press pulse, and a staggered fade-in. Behaves exactly like a Button (pressed signal, focus navigation, disabled).

const TEAL := Color("48E0C1")
const TEXT := Color("F3F0E8")
const MUTED := Color("B4BEC6")

var _tw: Tween
var _hot := false
var _chevron: Label


func _ready() -> void:
	flat = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(400, 56)
	add_theme_font_override("font", UiTheme.title_font(3))
	add_theme_font_size_override("font_size", 23)
	add_theme_color_override("font_color", MUTED)
	add_theme_color_override("font_hover_color", TEXT)
	add_theme_color_override("font_focus_color", TEXT)
	add_theme_color_override("font_pressed_color", TEAL)
	add_theme_color_override("font_disabled_color", Color(MUTED, 0.35))
	var idle := UiTheme.flat(Color.TRANSPARENT, Color.TRANSPARENT, 0, 4, 22, 10)
	var live := UiTheme.flat(Color(TEAL, 0.10), Color.TRANSPARENT, 0, 4, 22, 10)
	live.border_width_left = 3
	live.border_color = TEAL
	var press := UiTheme.flat(Color(TEAL, 0.24), Color.TRANSPARENT, 0, 4, 22, 10)
	press.border_width_left = 3
	press.border_color = TEAL
	for n in ["normal", "disabled"]:
		add_theme_stylebox_override(n, idle)
	for n in ["hover", "focus"]:
		add_theme_stylebox_override(n, live)
	add_theme_stylebox_override("pressed", press)
	_chevron = UiTheme.label("›", 30, TEAL, UiTheme.display_font())
	_chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chevron.modulate.a = 0.0
	_chevron.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_chevron.position = Vector2(-44, -20)
	add_child(_chevron)
	mouse_entered.connect(func() -> void: _set_hot(true))
	mouse_exited.connect(func() -> void: _set_hot(has_focus()))
	focus_entered.connect(func() -> void: _set_hot(true))
	focus_exited.connect(func() -> void: _set_hot(is_hovered()))
	button_down.connect(_press)
	resized.connect(func() -> void: pivot_offset = Vector2(0, size.y * 0.5))
	pivot_offset = Vector2(0, size.y * 0.5)


func _set_hot(on: bool) -> void:
	if disabled or on == _hot:
		return
	_hot = on
	if on:
		Sfx.play("ui", -18.0, 1.15)
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "scale", Vector2.ONE * (1.035 if on else 1.0), 0.12)
	_tw.tween_property(_chevron, "modulate:a", 1.0 if on else 0.0, 0.12)
	_tw.tween_property(_chevron, "position:x", -34.0 if on else -44.0, 0.12)


func _press() -> void:
	Sfx.play("ui", -10.0, 0.9)
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE * 0.97, 0.05)
	t.tween_property(self, "scale", Vector2.ONE * (1.035 if _hot else 1.0), 0.10)


## Fade and slide in after `delay` seconds (used for the staggered menu reveal).
func reveal(delay: float) -> void:
	modulate.a = 0.0
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, 0.28).set_delay(delay)
