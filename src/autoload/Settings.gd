extends Node
## Input map, player preferences (saved to user://settings.cfg).

const PATH := "user://settings.cfg"

var mouse_sensitivity := 0.0022  # radians per pixel
var master_volume := 1.0
var sfx_volume := 1.0
var music_volume := 0.6
var player_name := "PLAYER"
var fullscreen := false
var preset := "high"
var max_fps := 60
var vsync := true
var fov := 86.0
var invert_y := false
var reticle_size := 1.0
var shake := 1.0
var head_bob := true
var bus_volumes := {"Music": 0.6, "Weapons": 1.0, "Effects": 1.0, "Ambience": 0.8, "UI": 1.0}
const PRESETS := ["low", "medium", "high"]
const FPS_CAPS := [30, 60, 120, 144, 0]
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
	preset = str(cfg.get_value("video", "preset", preset))
	max_fps = int(cfg.get_value("video", "max_fps", max_fps))
	vsync = bool(cfg.get_value("video", "vsync", vsync))
	fov = float(cfg.get_value("input", "fov", fov))
	invert_y = bool(cfg.get_value("input", "invert_y", invert_y))
	reticle_size = float(cfg.get_value("input", "reticle", reticle_size))
	shake = float(cfg.get_value("input", "shake", shake))
	head_bob = bool(cfg.get_value("input", "head_bob", head_bob))
	for b in bus_volumes.keys():
		bus_volumes[b] = float(cfg.get_value("audio", b.to_lower(), bus_volumes[b]))
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
	cfg.set_value("video", "preset", preset)
	cfg.set_value("video", "max_fps", max_fps)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("input", "fov", fov)
	cfg.set_value("input", "invert_y", invert_y)
	cfg.set_value("input", "reticle", reticle_size)
	cfg.set_value("input", "shake", shake)
	cfg.set_value("input", "head_bob", head_bob)
	for b in bus_volumes:
		cfg.set_value("audio", b.to_lower(), bus_volumes[b])
	cfg.save(PATH)
	apply_prefs()


func reset_defaults() -> void:
	mouse_sensitivity = 0.0022
	master_volume = 1.0
	sfx_volume = 1.0
	music_volume = 0.6
	fullscreen = false
	resolution = Vector2i(1920, 1080)
	preset = "high"
	max_fps = 60
	vsync = true
	fov = 86.0
	invert_y = false
	reticle_size = 1.0
	shake = 1.0
	head_bob = true
	bus_volumes = {"Music": 0.6, "Weapons": 1.0, "Effects": 1.0, "Ambience": 0.8, "UI": 1.0}


func snapshot() -> Dictionary:
	return {"sens": mouse_sensitivity, "master": master_volume, "fullscreen": fullscreen, "resolution": resolution, "preset": preset, "max_fps": max_fps, "vsync": vsync, "fov": fov, "invert_y": invert_y, "reticle": reticle_size, "shake": shake, "head_bob": head_bob, "buses": bus_volumes.duplicate(), "name": player_name}


func restore(snap: Dictionary) -> void:
	mouse_sensitivity = snap["sens"]
	master_volume = snap["master"]
	fullscreen = snap["fullscreen"]
	resolution = snap["resolution"]
	preset = snap["preset"]
	max_fps = snap["max_fps"]
	vsync = snap["vsync"]
	fov = snap["fov"]
	invert_y = snap["invert_y"]
	reticle_size = snap["reticle"]
	shake = snap["shake"]
	head_bob = snap["head_bob"]
	bus_volumes = snap["buses"].duplicate()
	player_name = snap["name"]


## Graphics preset: shadows, anti-aliasing, 3D scale, glow. Low is meaningfully lighter.
func apply_graphics() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var vp := get_viewport()
	match preset:
		"low":
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.scaling_3d_scale = 0.8
		"medium":
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.scaling_3d_scale = 1.0
		_:
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			vp.msaa_3d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.scaling_3d_scale = 1.0
	Engine.max_fps = max_fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	if Game.world != null:
		var we := Game.world.get_node_or_null("Env")
		if we != null and we is WorldEnvironment:
			we.environment.glow_enabled = preset != "low"
			we.environment.fog_enabled = preset != "low"


func glow_allowed() -> bool:
	return preset != "low"


func apply_prefs() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_volume_db(master, linear_to_db(clampf(master_volume, 0.0001, 1.0)))
	for b in bus_volumes:
		var bi := AudioServer.get_bus_index(b)
		if bi >= 0:
			AudioServer.set_bus_volume_db(bi, linear_to_db(clampf(float(bus_volumes[b]), 0.0001, 1.0)))
	apply_graphics()
	if DisplayServer.get_name() != "headless" and not cli_overrides_window():
		call_deferred("apply_window")


static func cli_overrides_window() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--force-windowed") or a.begins_with("--screenshot") or a.begins_with("--winprobe"):
			return true
	return false


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
