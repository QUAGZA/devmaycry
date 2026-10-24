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


# ================================================================ FRONT-END THEME (startup, menu, setup, settings)
# Restrained palette: graphite surfaces, teal for interaction and energy, amber and coral for team and combat states.
const GRAPHITE := Color("101419")
const SURFACE := Color("1B232B")
const SURFACE_HI := Color("25303A")
const LINE := Color("2C3844")
const TEAL := Color("48E0C1")
const AMBER := Color("FFB454")
const TEXT := Color("F3F0E8")
const CORAL := Color("FF624D")
const MUTED := Color("93A0AB")

const SIZE_H1 := 72
const SIZE_H2 := 34
const SIZE_BODY := 17
const SIZE_SMALL := 14
const SIZE_BUTTON := 19

static var _menu_theme: Theme = null
static var _body: Font = null
static var _toggle_on: Texture2D = null
static var _toggle_off: Texture2D = null
static var _knob: Texture2D = null


static func body_font() -> Font:
	if _body == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Segoe UI", "Bahnschrift", "Arial"])
		_body = f
	return _body


## Wide-tracked display face for the logo and big headings.
static func title_font(tracking: int = 6) -> Font:
	var base := SystemFont.new()
	base.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
	base.font_weight = 700
	var fv := FontVariation.new()
	fv.base_font = base
	fv.spacing_glyph = tracking
	return fv


static func _pill(on: bool) -> Texture2D:
	var w := 46
	var h := 24
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track := Color(TEAL, 0.85) if on else Color("33414E")
	for y in h:
		for x in w:
			var r := h * 0.5
			var cx := clampf(float(x), r, w - r)
			if Vector2(x - cx, y - r + 0.5).length() <= r:
				img.set_pixel(x, y, track)
	var kx := w - h * 0.5 if on else h * 0.5
	for y in h:
		for x in w:
			if Vector2(x - kx + 0.5, y - h * 0.5 + 0.5).length() <= h * 0.5 - 3.0:
				img.set_pixel(x, y, GRAPHITE if on else MUTED)
	return ImageTexture.create_from_image(img)


static func _knob_tex() -> Texture2D:
	var s := 20
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x + 0.5 - s * 0.5, y + 0.5 - s * 0.5).length()
			if d <= s * 0.5 - 1.0:
				img.set_pixel(x, y, TEAL if d > 4.0 else TEXT)
	return ImageTexture.create_from_image(img)


static func flat(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 1, radius: int = 6, pad_x: int = 14, pad_y: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w if border.a > 0.0 else 0)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


static func menu_theme() -> Theme:
	if _menu_theme != null:
		return _menu_theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = SIZE_BODY
	t.set_color("font_color", "Label", TEXT)
	# buttons (secondary): dark plate, teal edge on hover, strong keyboard focus ring
	t.set_stylebox("normal", "Button", flat(SURFACE_HI, LINE))
	t.set_stylebox("hover", "Button", flat(Color(TEAL, 0.14), TEAL))
	t.set_stylebox("pressed", "Button", flat(Color(TEAL, 0.30), TEAL))
	t.set_stylebox("focus", "Button", flat(Color.TRANSPARENT, TEAL, 2))
	t.set_stylebox("disabled", "Button", flat(Color(SURFACE, 0.6), Color(LINE, 0.6)))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.6))
	t.set_font("font", "Button", body_font())
	t.set_font_size("font_size", "Button", SIZE_BUTTON)
	# drop-downs
	t.set_stylebox("normal", "OptionButton", flat(SURFACE_HI, LINE))
	t.set_stylebox("hover", "OptionButton", flat(Color(TEAL, 0.14), TEAL))
	t.set_stylebox("pressed", "OptionButton", flat(Color(TEAL, 0.24), TEAL))
	t.set_stylebox("focus", "OptionButton", flat(Color.TRANSPARENT, TEAL, 2))
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_color("font_hover_color", "OptionButton", TEXT)
	t.set_color("font_pressed_color", "OptionButton", TEXT)
	t.set_color("font_focus_color", "OptionButton", TEXT)
	t.set_font_size("font_size", "OptionButton", SIZE_BODY + 1)
	t.set_stylebox("panel", "PopupMenu", flat(SURFACE, TEAL, 1, 6, 6, 6))
	t.set_stylebox("hover", "PopupMenu", flat(Color(TEAL, 0.20), Color.TRANSPARENT, 0, 4, 8, 6))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", TEXT)
	t.set_font_size("font_size", "PopupMenu", SIZE_BODY + 1)
	# toggles
	if _toggle_on == null:
		_toggle_on = _pill(true)
		_toggle_off = _pill(false)
		_knob = _knob_tex()
	t.set_icon("checked", "CheckButton", _toggle_on)
	t.set_icon("unchecked", "CheckButton", _toggle_off)
	t.set_icon("checked_disabled", "CheckButton", _toggle_on)
	t.set_icon("unchecked_disabled", "CheckButton", _toggle_off)
	t.set_stylebox("normal", "CheckButton", flat(Color.TRANSPARENT, Color.TRANSPARENT, 0, 6, 4, 4))
	t.set_stylebox("hover", "CheckButton", flat(Color(TEAL, 0.08), Color.TRANSPARENT, 0, 6, 4, 4))
	t.set_stylebox("pressed", "CheckButton", flat(Color.TRANSPARENT, Color.TRANSPARENT, 0, 6, 4, 4))
	t.set_stylebox("hover_pressed", "CheckButton", flat(Color(TEAL, 0.08), Color.TRANSPARENT, 0, 6, 4, 4))
	t.set_stylebox("focus", "CheckButton", flat(Color.TRANSPARENT, TEAL, 2, 6, 4, 4))
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", TEXT)
	t.set_color("font_pressed_color", "CheckButton", TEXT)
	t.set_color("font_hover_pressed_color", "CheckButton", TEXT)
	t.set_color("font_focus_color", "CheckButton", TEXT)
	t.set_constant("h_separation", "CheckButton", 12)
	t.set_font_size("font_size", "CheckButton", SIZE_BODY + 1)
	# text input
	t.set_stylebox("normal", "LineEdit", flat(GRAPHITE, LINE, 1, 6, 12, 10))
	t.set_stylebox("focus", "LineEdit", flat(GRAPHITE, TEAL, 2, 6, 12, 10))
	t.set_stylebox("read_only", "LineEdit", flat(SURFACE, LINE, 1, 6, 12, 10))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color(MUTED, 0.7))
	t.set_color("caret_color", "LineEdit", TEAL)
	t.set_color("selection_color", "LineEdit", Color(TEAL, 0.35))
	t.set_font("font", "LineEdit", mono_font())
	t.set_font_size("font_size", "LineEdit", 21)
	# sliders
	t.set_stylebox("slider", "HSlider", flat(LINE, Color.TRANSPARENT, 0, 3, 0, 2))
	t.set_stylebox("grabber_area", "HSlider", flat(TEAL, Color.TRANSPARENT, 0, 3, 0, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", flat(TEAL, Color.TRANSPARENT, 0, 3, 0, 2))
	t.set_icon("grabber", "HSlider", _knob)
	t.set_icon("grabber_highlight", "HSlider", _knob)
	t.set_icon("grabber_disabled", "HSlider", _knob)
	# panels
	t.set_stylebox("panel", "PanelContainer", card_menu())
	_menu_theme = t
	return t


static func card_menu(alpha: float = 0.94) -> StyleBoxFlat:
	var sb := flat(Color(SURFACE, alpha), Color(TEAL, 0.22), 1, 12, 30, 26)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 28
	sb.shadow_offset = Vector2(0, 10)
	return sb


## Primary action button: solid teal with graphite text.
static func style_primary(b: Button) -> void:
	b.add_theme_stylebox_override("normal", flat(TEAL, TEAL, 1, 6, 18, 12))
	b.add_theme_stylebox_override("hover", flat(TEAL.lightened(0.18), TEAL.lightened(0.18), 1, 6, 18, 12))
	b.add_theme_stylebox_override("pressed", flat(TEAL.darkened(0.15), TEAL.darkened(0.15), 1, 6, 18, 12))
	b.add_theme_stylebox_override("focus", flat(Color.TRANSPARENT, TEXT, 2, 6, 18, 12))
	b.add_theme_color_override("font_color", GRAPHITE)
	b.add_theme_color_override("font_hover_color", GRAPHITE)
	b.add_theme_color_override("font_pressed_color", GRAPHITE)
	b.add_theme_color_override("font_focus_color", GRAPHITE)
	b.add_theme_font_size_override("font_size", SIZE_BUTTON + 1)
	b.add_theme_font_override("font", title_font(2))


## Small teal caps heading with a hairline rule, used to group a form.
static func section(text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := label(text, SIZE_SMALL, TEAL, mono_font())
	l.uppercase = true
	row.add_child(l)
	var r := ColorRect.new()
	r.color = LINE
	r.custom_minimum_size = Vector2(0, 1)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(r)
	return row
