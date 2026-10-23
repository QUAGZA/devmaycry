extends Node
## Input map, player preferences (saved to user://settings.cfg).

const PATH := "user://settings.cfg"

var mouse_sensitivity := 0.0022  # radians per pixel
var master_volume := 1.0
var sfx_volume := 1.0
var music_volume := 0.6
var player_name := "PLAYER"
var fullscreen := false
var resolution := Vector2i(1920, 1080)
var last_window_note := ""
const RESOLUTIONS := [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1366, 768), Vector2i(1280, 720)]


func _init() -> void:
	_setup_input_map()


func _ready() -> void:
	load_prefs()
	if OS.has_environment("USERNAME") and player_name == "PLAYER":
		player_name = OS.get_environment("USERNAME").to_upper().left(12)


func _setup_input_map() -> void:
	_bind_key("move_forward", KEY_W)
	_bind_key("move_back", KEY_S)
	_bind_key("move_left", KEY_A)
	_bind_key("move_right", KEY_D)
	_bind_key("jump", KEY_SPACE)
	_bind_key("sprint", KEY_SHIFT)
	_bind_key("crouch", KEY_C)
	_bind_key("dash", KEY_CTRL)
	_bind_key("echo", KEY_Q)
	_bind_key("ability", KEY_Q)
	_bind_key("slot1", KEY_1)
	_bind_key("slot2", KEY_2)
	_bind_key("slot3", KEY_3)
	_bind_key("slot4", KEY_4)
	_bind_key("map", KEY_CAPSLOCK)
	_bind_mouse("ads", MOUSE_BUTTON_RIGHT)
	_bind_key("interact", KEY_E)
	_bind_key("reload", KEY_R)
	_bind_key("pause", KEY_ESCAPE)
	_bind_key("scoreboard", KEY_TAB)
	_bind_mouse("fire", MOUSE_BUTTON_LEFT)


func _bind_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _bind_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func load_prefs() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	mouse_sensitivity = float(cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity))
	master_volume = float(cfg.get_value("audio", "master", master_volume))
	sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
	music_volume = float(cfg.get_value("audio", "music", music_volume))
	player_name = str(cfg.get_value("player", "name", player_name))
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	resolution = Vector2i(int(cfg.get_value("video", "width", resolution.x)), int(cfg.get_value("video", "height", resolution.y)))
	apply_prefs()


func save_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("player", "name", player_name)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "width", resolution.x)
	cfg.set_value("video", "height", resolution.y)
	cfg.save(PATH)
	apply_prefs()


func apply_prefs() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_volume_db(master, linear_to_db(clampf(master_volume, 0.0001, 1.0)))
	if DisplayServer.get_name() != "headless":
		call_deferred("apply_window")


## Applies the chosen resolution; falls back to the largest preset that fits the screen.
func apply_window() -> void:
	var screen := DisplayServer.screen_get_size()
	var want := resolution
	last_window_note = ""
	if want.x > screen.x or want.y > screen.y:
		for r in RESOLUTIONS:
			if r.x <= screen.x and r.y <= screen.y:
				want = r
				break
		if want.x > screen.x or want.y > screen.y:
			want = screen
		last_window_note = "Display is %dx%d, using %dx%d instead of %dx%d." % [screen.x, screen.y, want.x, want.y, resolution.x, resolution.y]
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(want)
		DisplayServer.window_set_position((screen - want) / 2)
