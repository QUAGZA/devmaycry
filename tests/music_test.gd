extends SceneTree
## Menu-music lifecycle test. Run:
##   Godot --headless --path . --script res://tests/music_test.gd -- --music-test
## Verifies: the supplied track loads, one player only, fade-out stops it, a quick return resumes the same
## player, repeated menu <-> match transitions never duplicate it, the loop wraps at the trimmed end point and
## audio actually reaches the Music bus.

var failures := 0


func check(cond: bool, label: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + label)
	if not cond:
		failures += 1


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame   # autoload _ready() calls run before the first frame
	var music: Node = root.get_node("Music")
	check(ResourceLoader.exists("res://assets/sfx/bg_soundtrack/theplan.wav"), "supplied track is part of the project resources")
	var st := load("res://assets/sfx/bg_soundtrack/theplan.wav") as AudioStreamWAV
	check(st != null and absf(st.get_length() - 186.12) < 0.5, "track loads as AudioStreamWAV, length %.2f s" % (st.get_length() if st != null else 0.0))
	check(st != null and st.loop_mode == AudioStreamWAV.LOOP_FORWARD, "import sets a forward loop (loop_mode %d, loop_end %d)" % [st.loop_mode, st.loop_end])
	# 1) three rapid menu() calls = one instance
	music.menu()
	music.menu()
	music.menu()
	await _wait(0.4)
	check(music.active_players() == 1, "three menu() calls produce one playing instance (%d)" % music.active_players())
	await _wait(2.0)
	var peak := maxf(AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index("Music"), 0), AudioServer.get_bus_peak_volume_right_db(AudioServer.get_bus_index("Music"), 0))
	check(peak > -40.0, "audio reaches the Music bus (peak %.1f dB)" % peak)
	# 2) fade-out stops it
	music.fade_out(0.5)
	await _wait(0.9)
	check(music.active_players() == 0 and not music.is_playing(), "fade_out stops playback (players %d)" % music.active_players())
	# 3) back in the menu restarts exactly one instance
	music.menu()
	await _wait(0.5)
	check(music.active_players() == 1, "returning to the menu restarts one instance")
	# 3b) a match in between: the track continues from where the menu left it (about a second earlier)
	music.debug_seek(40.0)
	music.fade_out(0.2)
	await _wait(0.6)
	music.menu()
	await _wait(0.4)
	var resumed: float = music._player.get_playback_position()
	check(resumed > 38.5 and resumed < 42.5, "the menu continues from the saved position (%.1f s)" % resumed)
	# 4) returning during the fade-out turns the same player around
	music.fade_out(0.8)
	await _wait(0.25)
	music.menu()
	await _wait(1.2)
	check(music.active_players() == 1 and music.is_playing(), "menu() during a fade-out resumes without a second player")
	# 5) ten menu <-> match cycles
	for i in 10:
		music.fade_out(0.1)
		await _wait(0.2)
		music.menu()
		await _wait(0.1)
	await _wait(0.5)
	check(music.active_players() == 1, "ten menu/match cycles leave exactly one player (%d)" % music.active_players())
	var kids := 0
	for c in music.get_children():
		if c is AudioStreamPlayer:
			kids += 1
	check(kids == 1, "Music owns a single AudioStreamPlayer node (%d)" % kids)
	# 6) loop wrap near the trimmed end
	music.debug_seek(185.2)
	await _wait(1.6)
	var wraps: int = music._wraps
	var pos: float = music._player.get_playback_position()
	check(wraps >= 1 and pos < 5.0, "playback wraps to the start after the loop end (wraps %d, pos %.2f s)" % [wraps, pos])
	music.stop()
	check(music.active_players() == 0, "stop() silences the player")
	print("[MusicTest] failures=%d" % failures)
	quit(failures)
