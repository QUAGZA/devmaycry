class_name IntroSequence
extends Control
## Startup sequence drawn in real time over the dark MenuStage: fade in, converging teal motes, geometric traces,
## the Causal Core materialising, a restrained energy pattern, a soft light sweep, then beats for the tagline, the
## title and the menu (the Title scene owns those nodes, so the hand-over has no jump). Any key or click skips it.
## A returning player gets the short version (settings flag intro_seen); the sequence never plays after a match.

signal beat(name: String)
signal core_reveal(amount: float)
signal finished

const TEAL := Color("48E0C1")
const AMBER := Color("FFB454")
const TEXT := Color("F3F0E8")
const GRAPHITE := Color("101419")

const FULL := {"fade": 0.9, "trace": [0.6, 2.4], "particles": [0.5, 2.6], "core": [1.3, 3.0], "arcs": [2.2, 6.2], "sweep": [3.2, 4.3],
	"tagline": 4.1, "title": 5.0, "menu": 5.9, "done": 6.7}
const FAST := {"fade": 0.35, "trace": [0.1, 0.7], "particles": [0.0, 0.8], "core": [0.1, 0.8], "arcs": [0.5, 1.6], "sweep": [0.6, 0.95],
	"tagline": 0.45, "title": 0.7, "menu": 0.95, "done": 1.3}

var core_pos := Vector2(900, 380)      # set by Title: where the Core appears on screen
var fast := false

var _t := 0.0
var _plan: Dictionary
var _fired: Dictionary = {}
var _skipped := false
var _skip_t := 0.0
var _motes: Array = []
var _hint: Label
var _finished_emitted := false


func _ready() -> void:
	Game.log_ev("Intro", "start", {"fast": fast})
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_plan = FAST if fast else FULL
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in (30 if fast else 64):
		_motes.append({"a": rng.randf() * TAU, "r0": rng.randf_range(300.0, 760.0), "d": rng.randf_range(0.0, 1.1), "amber": rng.randf() < 0.16, "s": rng.randf_range(1.2, 2.6)})
	_hint = UiTheme.stamp("PRESS ANY KEY TO SKIP", Color(TEXT, 0.0), 12)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position = Vector2(-120, -46)
	_hint.size = Vector2(240, 20)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)


func _input(event: InputEvent) -> void:
	if _skipped:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed)
	if pressed:
		skip()
		get_viewport().set_input_as_handled()


func skip() -> void:
	if _skipped:
		return
	_skipped = true
	_skip_t = 0.0
	Game.log_ev("Intro", "skipped", {"at": snappedf(_t, 0.01)})
	for k in ["tagline", "title", "menu"]:
		_fire(k)
	core_reveal.emit(1.0)


func _fire(name: String) -> void:
	if _fired.has(name):
		return
	_fired[name] = true
	beat.emit(name)


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


func _span(key: String) -> float:
	var s: Array = _plan[key]
	return clampf((_t - float(s[0])) / (float(s[1]) - float(s[0])), 0.0, 1.0)


func _process(delta: float) -> void:
	if _finished_emitted:
		return
	if _skipped:
		_skip_t += delta
		if _skip_t >= 0.32:
			_finish()
		queue_redraw()
		return
	_t += delta
	if Game.args.has("intro-skip-at") and _t >= float(Game.args["intro-skip-at"]):
		Game.args.erase("intro-skip-at")
		skip()
		return
	core_reveal.emit(_ease(_span("core")))
	for k in ["tagline", "title", "menu"]:
		if _t >= float(_plan[k]):
			_fire(k)
	if _t >= float(_plan["done"]):
		_finish()
	_hint.add_theme_color_override("font_color", Color(TEXT, 0.45 * clampf((_t - 0.8) / 0.6, 0.0, 1.0) * (1.0 - _span("core") * 0.0)))
	queue_redraw()


func _finish() -> void:
	if _finished_emitted:
		return
	_finished_emitted = true
	core_reveal.emit(1.0)
	Game.log_ev("Intro", "finished", {"skipped": _skipped, "seconds": snappedf(_t, 0.01)})
	finished.emit()
	queue_free()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var fade_in := 1.0 - clampf(_t / float(_plan["fade"]), 0.0, 1.0)
	var skip_fade := clampf(_skip_t / 0.32, 0.0, 1.0)
	var vis := 1.0 - skip_fade                       # everything the overlay draws leaves together when skipped
	# the overlay itself is transparent: the dark stage shows through; the black fade-in sits on top
	var c := core_pos
	# converging motes
	var ring_r := 150.0
	for m in _motes:
		var lt := clampf((_t - float(_plan["particles"][0]) - float(m["d"])) / 1.7, 0.0, 1.0)
		if lt <= 0.0:
			continue
		var e := _ease(lt)
		var r := lerpf(float(m["r0"]), ring_r + 12.0 * sin(float(m["a"]) * 3.0), e)
		var p := c + Vector2(cos(float(m["a"]) + e * 0.9), sin(float(m["a"]) + e * 0.9)) * r
		var col: Color = AMBER if m["amber"] else TEAL
		var alpha := sin(lt * PI) * 0.85 * vis
		draw_circle(p, float(m["s"]), Color(col, alpha))
	# geometric traces
	var tf := _span("trace")
	_trace_poly(c, 6, 190.0, 0.0, tf, Color(TEAL, 0.55 * vis), 1.5)
	_trace_poly(c, 6, 238.0, PI / 6.0, clampf(tf * 1.2 - 0.1, 0.0, 1.0), Color(TEAL, 0.28 * vis), 1.0)
	if tf > 0.05:
		draw_arc(c, 150.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(tf * 1.1, 0.0, 1.0), 96, Color(TEAL, 0.5 * vis), 1.2, true)
	for k in 24:
		var a := TAU * float(k) / 24.0
		var d: float = 262.0 if k % 6 == 0 else 252.0
		var tick := clampf(tf * 1.4 - float(k) / 40.0, 0.0, 1.0)
		if tick > 0.0:
			draw_line(c + Vector2(cos(a), sin(a)) * 244.0, c + Vector2(cos(a), sin(a)) * d, Color(TEXT, 0.20 * tick * vis), 1.0)
	# energy pattern
	var af := _span("arcs")
	if af > 0.0:
		var env := clampf(af * 6.0, 0.0, 1.0) * clampf((1.0 - af) * 8.0, 0.0, 1.0) * vis
		var t := _t
		draw_arc(c, 118.0, t * 1.1, t * 1.1 + 1.9, 48, Color(TEAL, 0.9 * env), 2.0, true)
		draw_arc(c, 118.0, t * 1.1 + PI, t * 1.1 + PI + 0.7, 24, Color(TEAL, 0.5 * env), 2.0, true)
		draw_arc(c, 165.0, -t * 0.8, -t * 0.8 + 1.2, 40, Color(AMBER, 0.85 * env), 2.0, true)
		draw_arc(c, 207.0, t * 0.5 + 1.0, t * 0.5 + 4.2, 64, Color(TEXT, 0.22 * env), 1.0, true)
	# soft light sweep across the Core
	var sf := _span("sweep")
	if sf > 0.0 and sf < 1.0:
		var x := lerpf(c.x - 340.0, c.x + 340.0, _ease(sf))
		var w := 54.0
		var skew := 90.0
		var top := c.y - 230.0
		var bot := c.y + 230.0
		var mid := Color(TEXT, sin(sf * PI) * 0.17 * vis)
		var edge := Color(TEXT, 0.0)
		var ct := Vector2(x + skew * 0.5, top)
		var cb := Vector2(x - skew * 0.5, bot)
		draw_polygon(PackedVector2Array([ct - Vector2(w, 0), ct, cb, cb - Vector2(w, 0)]), PackedColorArray([edge, mid, mid, edge]))
		draw_polygon(PackedVector2Array([ct, ct + Vector2(w, 0), cb + Vector2(w, 0), cb]), PackedColorArray([mid, edge, edge, mid]))
	# black fade-in last
	if fade_in > 0.0:
		draw_rect(rect, Color(0, 0, 0, fade_in))


func _trace_poly(center: Vector2, sides: int, radius: float, rot: float, frac: float, col: Color, width: float) -> void:
	if frac <= 0.0:
		return
	var pts := PackedVector2Array()
	for i in sides + 1:
		var a := rot + TAU * float(i) / float(sides)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	var total := 0.0
	for i in sides:
		total += pts[i].distance_to(pts[i + 1])
	var want := total * frac
	var drawn := PackedVector2Array([pts[0]])
	var acc := 0.0
	for i in sides:
		var seg := pts[i].distance_to(pts[i + 1])
		if acc + seg <= want:
			drawn.append(pts[i + 1])
			acc += seg
		else:
			drawn.append(pts[i].lerp(pts[i + 1], (want - acc) / seg))
			break
	if drawn.size() >= 2:
		draw_polyline(drawn, col, width, true)
