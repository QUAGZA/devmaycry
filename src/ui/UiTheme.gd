class_name UiTheme
extends RefCounted
## PALIMPSEST SPORT interface styling: editorial type, archival cards, stamped labels.

static var _theme: Theme = null
static var _display: Font = null
static var _mono: Font = null
static var _serif: Font = null


static func display_font() -> Font:
	if _display == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
		f.font_weight = 700
		_display = f
	return _display


static func mono_font() -> Font:
	if _mono == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New"])
		_mono = f
	return _mono


static func serif_font() -> Font:
	if _serif == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Georgia", "Constantia", "Times New Roman"])
		_serif = f
	return _serif


static func card(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 1, radius: int = 2, pad: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w if border.a > 0.0 else 0)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = display_font()
	t.default_font_size = 18
	# Buttons: porcelain plate on ink, vermilion hover, stamped label
	t.set_stylebox("normal", "Button", card(Palette.PORCELAIN, Palette.PORCELAIN, 1, 2, 12))
	t.set_stylebox("hover", "Button", card(Palette.VERMILION, Palette.VERMILION, 1, 2, 12))
	t.set_stylebox("pressed", "Button", card(Palette.BRASS, Palette.BRASS, 1, 2, 12))
	t.set_stylebox("focus", "Button", card(Color.TRANSPARENT, Palette.MINT, 2, 2, 12))
	t.set_stylebox("disabled", "Button", card(Color(0.95, 0.91, 0.85, 0.25), Color.TRANSPARENT, 0, 2, 12))
	t.set_color("font_color", "Button", Palette.INK)
	t.set_color("font_hover_color", "Button", Palette.PORCELAIN)
	t.set_color("font_pressed_color", "Button", Palette.INK)
	t.set_color("font_focus_color", "Button", Palette.INK)
	t.set_color("font_disabled_color", "Button", Color(0.1, 0.1, 0.1, 0.6))
	t.set_font_size("font_size", "Button", 20)
	# Option buttons / check buttons share the look
	for cls in ["OptionButton", "CheckButton", "CheckBox"]:
		t.set_stylebox("normal", cls, card(Palette.PORCELAIN, Palette.PORCELAIN, 1, 2, 10))
		t.set_stylebox("hover", cls, card(Palette.VERMILION, Palette.VERMILION, 1, 2, 10))
		t.set_stylebox("pressed", cls, card(Palette.BRASS, Palette.BRASS, 1, 2, 10))
		t.set_stylebox("focus", cls, card(Color.TRANSPARENT, Palette.MINT, 2, 2, 10))
		t.set_color("font_color", cls, Palette.INK)
		t.set_color("font_hover_color", cls, Palette.PORCELAIN)
		t.set_color("font_pressed_color", cls, Palette.INK)
		t.set_color("font_focus_color", cls, Palette.INK)
	t.set_stylebox("normal", "LineEdit", card(Color(0.07, 0.08, 0.07), Palette.STONE, 1, 2, 10))
	t.set_stylebox("focus", "LineEdit", card(Color(0.07, 0.08, 0.07), Palette.MINT, 2, 2, 10))
	t.set_color("font_color", "LineEdit", Palette.PORCELAIN)
	t.set_color("caret_color", "LineEdit", Palette.VERMILION)
	t.set_font("font", "LineEdit", mono_font())
	t.set_font_size("font_size", "LineEdit", 22)
	t.set_color("font_color", "Label", Palette.PORCELAIN)
	t.set_stylebox("panel", "PopupMenu", card(Palette.PORCELAIN, Palette.INK, 1, 2, 6))
	t.set_color("font_color", "PopupMenu", Palette.INK)
	t.set_color("font_hover_color", "PopupMenu", Palette.VERMILION)
	t.set_stylebox("hover", "PopupMenu", card(Palette.IVORY, Color.TRANSPARENT, 0, 2, 6))
	t.set_stylebox("slider", "HSlider", card(Palette.STONE, Color.TRANSPARENT, 0, 2, 2))
	t.set_stylebox("grabber_area", "HSlider", card(Palette.VERMILION, Color.TRANSPARENT, 0, 2, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", card(Palette.VERMILION, Color.TRANSPARENT, 0, 2, 2))
	_theme = t
	return t


static func label(text: String, size: int = 18, color: Color = Palette.PORCELAIN, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


static func stamp(text: String, color: Color = Palette.VERMILION, size: int = 14) -> Label:
	var l := label(text, size, color, mono_font())
	l.uppercase = true
	return l


static func rule(color: Color = Palette.STONE, height: int = 1) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, height)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r
