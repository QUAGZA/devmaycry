extends SceneTree
## Headless unit tests. Run: godot --headless --path . --script res://tests/run_tests.gd

var _fails := 0
var _passes := 0


func _init() -> void:
	_test_echo_buffer()
	if ResourceLoader.exists("res://src/rules/CorebreakRules.gd"):
		_test_corebreak_rules()
	if ResourceLoader.exists("res://src/rules/RelicRules.gd"):
		_test_relic_rules()
	print("[Tests] passed=%d failed=%d" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


func check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("  PASS  " + label)
	else:
		_fails += 1
		print("  FAIL  " + label)


func _test_echo_buffer() -> void:
	print("[Tests] EchoBuffer")
	var b := EchoBuffer.new()
	for i in 60:
		b.push(i * 0.05, Vector3(i, 0, 0), i * 0.1, 0.0)
	check(b.sample_count() <= 26 and b.sample_count() >= 24, "keeps about 25 samples (2.5 s at 10 Hz), got %d" % b.sample_count())
	check(b.times[0] >= b.times[b.times.size() - 1] - 2.5 - 0.001, "oldest sample is within 2.5 s of the newest")
	var p := b.payload()
	check(p["t"][0] == 0.0, "payload times start at zero")
	check(absf(p["duration"] - 2.4) < 0.11, "payload duration about 2.4 s, got %f" % p["duration"])
	var mid_x: float = (p["pos"][0].x + p["pos"][1].x) * 0.5
	var s_mid := EchoBuffer.sample_at(p, p["t"][1] * 0.5)
	check(absf(s_mid["pos"].x - mid_x) < 0.01, "sample_at interpolates between samples")
	var s_end := EchoBuffer.sample_at(p, 99.0)
	check(s_end["pos"] == p["pos"][p["pos"].size() - 1], "sample_at clamps to last sample")
	b.push_event(3.0, EchoBuffer.EVT_FIRE, 1.0, 0.2)
	b.push(3.0, Vector3.ZERO, 0, 0)
	var p2 := b.payload()
	check(p2["events"].size() == 1, "fire event survives in payload")
	b.clear()
	check(b.sample_count() == 0 and b.payload().is_empty(), "clear empties buffer and payload is empty")
	var short := EchoBuffer.new()
	short.push(0.0, Vector3.ZERO, 0, 0)
	var sp := short.payload()
	check(sp["t"].size() == 1 and sp["duration"] == 0.0, "single-sample history yields a valid zero-duration payload")


func _test_corebreak_rules() -> void:
	print("[Tests] CorebreakRules")
	var R = load("res://src/rules/CorebreakRules.gd")
	# Win priority: detonation > defuse > eliminations > timer
	check(R.resolve({"detonated": true, "defused": true, "attackers_alive": 0, "defenders_alive": 0, "time_left": 0.0, "planted": true}) == "attack:detonation", "detonation beats everything")
	check(R.resolve({"detonated": false, "defused": true, "attackers_alive": 0, "defenders_alive": 0, "time_left": 0.0, "planted": true}) == "defend:defuse", "defuse beats eliminations and timer")
	check(R.resolve({"detonated": false, "defused": false, "attackers_alive": 0, "defenders_alive": 2, "time_left": 50.0, "planted": false}) == "defend:eliminated", "attackers eliminated before plant -> defenders")
	check(R.resolve({"detonated": false, "defused": false, "attackers_alive": 0, "defenders_alive": 2, "time_left": 50.0, "planted": true}) == "", "attackers dead but core planted -> round continues")
	check(R.resolve({"detonated": false, "defused": false, "attackers_alive": 2, "defenders_alive": 0, "time_left": 50.0, "planted": true}) == "attack:eliminated", "defenders dead with core planted -> attackers")
	check(R.resolve({"detonated": false, "defused": false, "attackers_alive": 2, "defenders_alive": 0, "time_left": 50.0, "planted": false}) == "attack:eliminated", "defenders dead before plant -> attackers")
	check(R.resolve({"detonated": false, "defused": false, "attackers_alive": 0, "defenders_alive": 0, "time_left": 50.0, "planted": false}) == "defend:eliminated", "mutual elimination before plant -> defenders (attack failed)")
	check(R.resolve({"detonated": false, "defused": false, "attackers_alive": 0, "defenders_alive": 0, "time_left": 50.0, "planted": true}) == "attack:eliminated", "mutual elimination after plant -> attackers (core live)")
	check(R.resolve({"detonated": false, "defused": false, "attackers_alive": 2, "defenders_alive": 2, "time_left": 0.0, "planted": false}) == "defend:timer", "timer expiry without plant -> defenders")
	check(R.resolve({"detonated": false, "defused": false, "attackers_alive": 2, "defenders_alive": 2, "time_left": 0.0, "planted": true}) == "", "timer expiry with plant -> continue to detonation")
	check(R.resolve({"detonated": false, "defused": false, "attackers_alive": 2, "defenders_alive": 2, "time_left": 10.0, "planted": false}) == "", "live round -> no result")
	# Match structure
	var m = R.new_match()
	check(R.attacking_team(m) == 1, "team 1 attacks in round 1")
	for i in 2:
		R.record_round(m, 1)
	check(R.attacking_team(m) == 2 and m["round"] == 3, "sides swap after round 2")
	R.record_round(m, 1)
	check(m["winner"] == 1, "first to 3 wins the match")
	var m2 = R.new_match()
	R.record_round(m2, 1)
	R.record_round(m2, 2)
	R.record_round(m2, 1)
	R.record_round(m2, 2)
	check(m2["overtime"] and m2["winner"] == 0 and m2["round"] == 5, "2-2 after regulation enters overtime")
	check(R.attacking_team(m2) == 2, "first overtime set: team 2 attacks first (alternating)")
	R.record_round(m2, 1)
	check(R.attacking_team(m2) == 1, "second round of the overtime pair swaps roles")
	R.record_round(m2, 2)
	check(m2["winner"] == 0 and m2["overtime"] and m2["round"] == 7, "split overtime pair keeps the match tied and starts another pair")
	check(R.attacking_team(m2) == 1, "next overtime set alternates who attacks first")
	R.record_round(m2, 2)
	R.record_round(m2, 2)
	check(m2["winner"] == 2, "sweeping an overtime pair wins the match")


func _test_relic_rules() -> void:
	print("[Tests] RelicRules")
	var R = load("res://src/rules/RelicRules.gd")
	var s = R.new_state([1, 2, 3])
	R.add_points(s, 1, 2)
	check(s["points"][1] == 2, "elimination awards 2")
	for i in 12:
		R.add_points(s, 1, 2)
	check(R.winner(s, 100.0) == 1, "reaching 25 ends the match immediately")
	var s2 = R.new_state([1, 2])
	R.add_points(s2, 1, 5)
	R.add_points(s2, 2, 5)
	check(R.winner(s2, 0.0) == 0 and R.needs_sudden_death(s2, 0.0), "tie at zero -> sudden death")
	R.add_points(s2, 2, 1)
	check(R.winner(s2, 0.0) == 2, "first point in sudden death wins")
	check(R.beacon_owner({1: true, 2: false}) == 1 and R.beacon_owner({1: true, 2: true}) == 0, "beacon: sole occupant controls, contest yields nobody")
