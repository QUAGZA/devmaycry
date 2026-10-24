extends Node
## Input map, player preferences (saved to user://settings.cfg).

const PATH := "user://settings.cfg"
## Automated tests pass --settings-path=user://<file> so they never touch the player's real preferences.
var cfg_path := PATH

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
var intro_seen := false             # the long startup sequence has been watched once; later launches get the short one
var bus_volumes := {"Music": 0.6, "Weapons": 1.0, "Effects": 1.0, "Ambience": 0.8, "UI": 1.0}
const PRESETS := ["low", "medium", "high"]
const FPS_CAPS := [30, 60, 120, 144, 0]
var resolution := Vector2i(1920, 1080)
var last_window_note := ""
## Window and per-feature graphics options. A preset writes all four; each can then be overridden.
var window_mode := "windowed"        # windowed / borderless / fullscreen
var shadow_quality := "high"         # low / medium / high
var aa_mode := "fxaa"                # off / fxaa / msaa2 / msaa4 / taa (MSAA shows edge dots with the toon shader, see docs)
var texture_quality := "high"        # low (no detail maps) / high (Poly Haven detail maps)
var effects_quality := "high"        # low (no ink, SSAO, glow, fog) / medium / high (halftone)
const WINDOW_MODES := ["windowed", "borderless", "fullscreen"]
const QUALITY := ["low", "medium", "high"]
const AA_MODES := ["off", "fxaa", "msaa2", "msaa4", "taa"]
const RESOLUTIONS := [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1366, 768), Vector2i(1280, 720)]


func _init() -> void:
	_setup_input_map()


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--settings-path="):
			cfg_path = a.substr(16)
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
	_bind_key("armory", KEY_B)
	_bind_mouse("weapon_prev", MOUSE_BUTTON_WHEEL_UP)
	_bind_mouse("weapon_next", MOUSE_BUTTON_WHEEL_DOWN)
	_bind_key("map", KEY_CAPSLOCK)
	_bind_mouse("ads", MOUSE_BUTTON_RIGHT)
	_bind_key("interact", KEY_E)
	_bind_key("drop_core", KEY_G)
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
	if cfg.load(cfg_path) != OK:
		return
	mouse_sensitivity = float(cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity))
	master_volume = float(cfg.get_value("audio", "master", master_volume))
	sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
	music_volume = float(cfg.get_value("audio", "music", music_volume))
	player_name = str(cfg.get_value("player", "name", player_name))
	intro_seen = bool(cfg.get_value("meta", "intro_seen", false))
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	window_mode = str(cfg.get_value("video", "window_mode", "fullscreen" if fullscreen else "windowed"))
	shadow_quality = str(cfg.get_value("video", "shadow_quality", shadow_quality))
	aa_mode = str(cfg.get_value("video", "aa_mode", aa_mode))
	# v2 settings: MSAA shows edge-dot artifacts with the PALIMPSEST toon shader on this renderer,
	# so files written before the fix (no version stamp) fall back to FXAA.
	if int(cfg.get_value("meta", "version", 1)) < 2 and aa_mode.begins_with("msaa"):
		aa_mode = "fxaa"
	texture_quality = str(cfg.get_value("video", "texture_quality", texture_quality))
	effects_quality = str(cfg.get_value("video", "effects_quality", effects_quality))
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
	# automated command-line runs never write the player's real preferences file
	if cfg_path == PATH and _cli_run():
		apply_prefs()
		return
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 2)
	cfg.set_value("meta", "intro_seen", intro_seen)
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("player", "name", player_name)
	fullscreen = window_mode == "fullscreen"
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "window_mode", window_mode)
	cfg.set_value("video", "shadow_quality", shadow_quality)
	cfg.set_value("video", "aa_mode", aa_mode)
	cfg.set_value("video", "texture_quality", texture_quality)
	cfg.set_value("video", "effects_quality", effects_quality)
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
	cfg.save(cfg_path)
	apply_prefs()


func _cli_run() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role=") or a.begins_with("--auto=") or a.begins_with("--screenshot"):
			return true
	return false


func reset_defaults() -> void:
	mouse_sensitivity = 0.0022
	master_volume = 1.0
	sfx_volume = 1.0
	music_volume = 0.6
	fullscreen = false
	window_mode = "windowed"
	resolution = Vector2i(1920, 1080)
	set_preset("high")
	max_fps = 60
	vsync = true
	fov = 86.0
	invert_y = false
	reticle_size = 1.0
	shake = 1.0
	head_bob = true
	bus_volumes = {"Music": 0.6, "Weapons": 1.0, "Effects": 1.0, "Ambience": 0.8, "UI": 1.0}


func snapshot() -> Dictionary:
	return {"window_mode": window_mode, "shadow_quality": shadow_quality, "aa_mode": aa_mode, "texture_quality": texture_quality, "effects_quality": effects_quality, "sens": mouse_sensitivity, "master": master_volume, "fullscreen": fullscreen, "resolution": resolution, "preset": preset, "max_fps": max_fps, "vsync": vsync, "fov": fov, "invert_y": invert_y, "reticle": reticle_size, "shake": shake, "head_bob": head_bob, "buses": bus_volumes.duplicate(), "name": player_name}


func restore(snap: Dictionary) -> void:
	window_mode = snap["window_mode"]
	shadow_quality = snap["shadow_quality"]
	aa_mode = snap["aa_mode"]
	texture_quality = snap["texture_quality"]
	effects_quality = snap["effects_quality"]
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
	var shadow_size := {"low": 1024, "medium": 2048, "high": 4096}
	RenderingServer.directional_shadow_atlas_set_size(int(shadow_size.get(shadow_quality, 4096)), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW if shadow_quality == "low" else (RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if shadow_quality == "medium" else RenderingServer.SHADOW_QUALITY_SOFT_HIGH))
	vp.msaa_3d = {"msaa2": Viewport.MSAA_2X, "msaa4": Viewport.MSAA_4X}.get(aa_mode, Viewport.MSAA_DISABLED)
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa_mode == "fxaa" else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = aa_mode == "taa"
	vp.scaling_3d_scale = render_scale()
	# materials bake the effects/texture quality when they are built, so a changed setting needs a fresh cache
	Style.clear_cache()
	Game.log_ev("Settings", "graphics_applied", {"preset": preset, "aa": aa_mode, "msaa": vp.msaa_3d, "ssaa": vp.screen_space_aa, "taa": vp.use_taa, "shadows": shadow_quality, "effects": effects_quality, "textures": texture_quality, "scale": vp.scaling_3d_scale, "cfg": cfg_path})
	Engine.max_fps = max_fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	if Game.world != null:
		var we := Game.world.get_node_or_null("Env")
		if we != null and we is WorldEnvironment:
			we.environment.glow_enabled = effects_quality != "low"
			we.environment.fog_enabled = effects_quality != "low"
			we.environment.ssao_enabled = effects_quality != "low"


## A preset writes every individual graphics option; they can then be changed one by one.
func set_preset(p: String) -> void:
	preset = p
	match p:
		"low":
			shadow_quality = "low"
			aa_mode = "fxaa"
			texture_quality = "low"
			effects_quality = "low"
		"medium":
			shadow_quality = "medium"
			aa_mode = "fxaa"
			texture_quality = "high"
			effects_quality = "medium"
		_:
			shadow_quality = "high"
			aa_mode = "fxaa"
			texture_quality = "high"
			effects_quality = "high"


func glow_allowed() -> bool:
	return preset != "low"


## Master and per-bus volumes (also used for live preview while a settings slider moves).
func apply_audio() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_volume_db(master, linear_to_db(clampf(master_volume, 0.0001, 1.0)))
	for b in bus_volumes:
		var bi := AudioServer.get_bus_index(b)
		if bi >= 0:
			AudioServer.set_bus_volume_db(bi, linear_to_db(clampf(float(bus_volumes[b]), 0.0001, 1.0)))


func apply_prefs() -> void:
	apply_audio()
	apply_graphics()
	if DisplayServer.get_name() != "headless" and not cli_overrides_window():
		call_deferred("apply_window")


static func cli_overrides_window() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--force-windowed") or a.begins_with("--screenshot") or a.begins_with("--winprobe"):
			return true
	return false


## The chosen resolution, or the largest preset that fits the screen when it does not.
func _fit_resolution(screen: Vector2i) -> Vector2i:
	var want := resolution
	if want.x > screen.x or want.y > screen.y:
		for r in RESOLUTIONS:
			if r.x <= screen.x and r.y <= screen.y:
				return r
		return screen
	return want


## 3D render scale: the graphics preset times the chosen resolution relative to the screen. A fullscreen or
## borderless window always covers the whole screen, so a lower resolution there means rendering the 3D scene
## smaller and upscaling it (the UI stays sharp). In a window the window itself is resized, so no extra scale.
func render_scale() -> float:
	var s := 0.8 if preset == "low" else 1.0
	if DisplayServer.get_name() != "headless" and window_mode != "windowed":
		var screen := DisplayServer.screen_get_size()
		s *= clampf(float(_fit_resolution(screen).y) / float(maxi(screen.y, 1)), 0.25, 1.0)
	return s


## Applies the window mode and resolution; falls back to the largest preset that fits the screen.
func apply_window() -> void:
	var screen := DisplayServer.screen_get_size()
	var want := _fit_resolution(screen)
	last_window_note = ""
	if want != resolution:
		last_window_note = "Display is %dx%d, using %dx%d instead of %dx%d." % [screen.x, screen.y, want.x, want.y, resolution.x, resolution.y]
	get_viewport().scaling_3d_scale = render_scale()
	if window_mode == "fullscreen":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	# leaving fullscreen is asynchronous: size and position are only honoured once the mode switch has landed
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await get_tree().process_frame
	if window_mode == "borderless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		DisplayServer.window_set_size(screen)
		DisplayServer.window_set_position(Vector2i.ZERO)
	else:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_size(want)
		DisplayServer.window_set_position((screen - want) / 2)
