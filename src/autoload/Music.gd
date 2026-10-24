extends Node
## Main-menu music. One AudioStreamPlayer on the "Music" bus, so the existing MUSIC VOLUME slider and
## the master volume apply with no extra code. Lifecycle:
##   menu()      Title screen _ready: start (or resume) with a fade-in. Idempotent, never a second instance. After a
##               match the track continues from where the menu left it.
##   fade_out()  A match is loading: fade, then stop. Calling menu() during the fade turns it around.
##   stop()      Immediate stop.
## The supplied track ends with 0.25 s of digital silence after a hard cut and opens on a full-level hit,
## so the import loops it at the last audible sample (theplan.wav.import) and a ~70 ms gain dip at the
## wrap removes the click. Nothing here touches the source file.

const TRACK := "res://assets/sfx/bg_soundtrack/theplan.wav"
const BASE_DB := -7.0            # the master is very loud (RMS about -7.6 dBFS); leave headroom for the Music bus
const FADE_IN := 1.6
const FADE_OUT := 0.9
const WRAP_DIP := 0.07           # seconds of fade on each side of the loop point
const LOOP_END := 185.86         # last audible sample; must match edit/loop_end in the .import file

var _player: AudioStreamPlayer
var _fade := 0.0                 # 0..1 master envelope driven by tweens
var _tween: Tween
var _state := "stopped"          # stopped / playing / fading_out
var _stream: AudioStream
var _wraps := 0
var _last_pos := 0.0
var _enabled := true
var _resume_pos := 0.0           # where the menu music was when a match took over; the menu picks it up from there


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# headless runs (dedicated tests) stay silent unless a test asks for the music logic explicitly
	_enabled = DisplayServer.get_name() != "headless" or Game.args.has("music-test")
	_player = AudioStreamPlayer.new()
	_player.name = "MenuMusic"
	_player.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	_player.volume_db = -80.0
	add_child(_player)
	set_process(false)


func menu(fresh := true) -> void:
	if not _enabled:
		return
	if _stream == null:
		_stream = load(TRACK) as AudioStream
		if _stream == null:
			push_warning("Music: %s could not be loaded" % TRACK)
			Game.log_ev("Music", "load_failed", {"path": TRACK})
			return
	if _state == "playing":
		return
	if _state == "fading_out":
		# the player came back before the fade finished: turn the same player around
		_ramp(1.0, FADE_IN * 0.5)
		_state = "playing"
		Game.log_ev("Music", "resumed", _status())
		return
	_player.stream = _stream
	_fade = 0.0
	_wraps = 0
	var from := clampf(_resume_pos, 0.0, maxf(0.0, LOOP_END - 5.0)) if fresh else 0.0
	_resume_pos = 0.0
	_last_pos = from
	_apply_gain(1.0)
	_player.play(from)
	_state = "playing"
	_ramp(1.0, FADE_IN)
	set_process(true)
	Game.log_ev("Music", "started", _status())


func fade_out(seconds := FADE_OUT) -> void:
	if _state != "playing":
		return
	_state = "fading_out"
	_ramp(0.0, seconds)
	Game.log_ev("Music", "fade_out", _status())
	if _tween != null:
		_tween.finished.connect(_on_faded, CONNECT_ONE_SHOT)


func stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_player.stop()
	_fade = 0.0
	_state = "stopped"
	set_process(false)
	Game.log_ev("Music", "stopped", _status())


## Test helper: jump the playhead (used by tests/music_test.gd to reach the loop point quickly).
func debug_seek(seconds: float) -> void:
	if _player != null and _player.playing:
		_player.seek(seconds)
		_last_pos = seconds


func is_playing() -> bool:
	return _player != null and _player.playing


## Number of music players currently producing sound (must never exceed 1).
func active_players() -> int:
	var n := 0
	for c in get_children():
		if c is AudioStreamPlayer and (c as AudioStreamPlayer).playing:
			n += 1
	return n


func _status() -> Dictionary:
	return {
		"state": _state, "players": active_players(), "pos": snappedf(_player.get_playback_position(), 0.01),
		"bus": str(_player.bus), "bus_db": snappedf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(_player.bus)), 0.1),
		"wraps": _wraps, "length": snappedf(_stream.get_length() if _stream != null else 0.0, 0.01),
	}


func _on_faded() -> void:
	if _state == "fading_out":
		_resume_pos = maxf(0.0, _player.get_playback_position() - 1.0)   # back up a second so the return does not start mid-phrase
		stop()


func _ramp(to: float, seconds: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(v: float) -> void: _fade = v, _fade, to, maxf(seconds, 0.01))


func _apply_gain(wrap_gain: float) -> void:
	var lin := clampf(_fade * wrap_gain, 0.0, 1.0)
	_player.volume_db = BASE_DB + (linear_to_db(lin) if lin > 0.0001 else -80.0)


func _process(_delta: float) -> void:
	if not _player.playing:
		return
	var pos := _player.get_playback_position()
	if pos < _last_pos - 1.0:
		_wraps += 1
		Game.log_ev("Music", "loop_wrap", {"wraps": _wraps, "from": snappedf(_last_pos, 0.01), "to": snappedf(pos, 0.01)})
	_last_pos = pos
	# click-free loop point: dip the gain just before the wrap and ease back in just after it
	var g := 1.0
	if pos > LOOP_END - WRAP_DIP:
		g = clampf((LOOP_END - pos) / WRAP_DIP, 0.0, 1.0)
	elif _wraps > 0 and pos < WRAP_DIP:
		g = clampf(pos / WRAP_DIP, 0.0, 1.0)
	_apply_gain(g)
