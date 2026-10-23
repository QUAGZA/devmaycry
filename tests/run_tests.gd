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
	if ResourceLoader.exists("res://src/rules/HotReturnRules.gd"):
		_test_hot_return_rules()
	if ResourceLoader.exists("res://src/weapons/Weapons.gd"):
		_test_weapons()
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
	check(b.sample_count() == 30, "keeps every 10 Hz sample within the 6 s window (30 pushes), got %d" % b.sample_count())
	check(b.times[0] >= b.times[b.times.size() - 1] - EchoBuffer.DURATION - 0.001, "oldest sample is within the window of the newest")
	var p := b.payload()
	check(p["t"][0] == 0.0, "payload times start at zero")
	check(absf(p["duration"] - 2.9) < 0.11, "payload duration matches the recorded span, got %f" % p["duration"])
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
	var long := EchoBuffer.new()
	for i in 100:
		long.push(3.0 + i * 0.1, Vector3(i, 0, 0), 0.0, 0.0)
	check(long.has_span(5.9) and not long.has_span(6.5), "has_span reports a full 6 s history")
	check(long.sample_abs(12.95)["pos"].x == 99.0, "sample_abs clamps to the newest sample")
	check(absf(long.sample_abs(10.05)["pos"].x - 70.5) < 0.01, "sample_abs interpolates at an absolute time")


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


func _test_hot_return_rules() -> void:
	print("[Tests] HotReturnRules")
	var R = load("res://src/rules/HotReturnRules.gd")
	check(R.resolve({"detonated": true, "stabilized": true, "attackers_alive": 0, "defenders_alive": 0, "time_left": 0.0}) == "defend:detonation", "a resolved detonation is final")
	check(R.resolve({"detonated": false, "stabilized": true, "attackers_alive": 0, "defenders_alive": 0, "time_left": 0.0}) == "attack:stabilized", "stabilization beats eliminations and timer")
	check(R.resolve({"detonated": false, "stabilized": false, "attackers_alive": 0, "defenders_alive": 0, "time_left": 50.0}) == "defend:eliminated", "mutual elimination -> defenders (no extraction)")
	check(R.resolve({"detonated": false, "stabilized": false, "attackers_alive": 1, "defenders_alive": 0, "time_left": 50.0}) == "attack:eliminated", "defenders eliminated -> attackers")
	check(R.resolve({"detonated": false, "stabilized": false, "attackers_alive": 0, "defenders_alive": 1, "time_left": 50.0}) == "defend:eliminated", "attackers eliminated -> defenders")
	check(R.resolve({"detonated": false, "stabilized": false, "attackers_alive": 1, "defenders_alive": 1, "time_left": 0.0}) == "defend:timer", "timer expiry -> defenders")
	check(R.resolve({"detonated": false, "stabilized": false, "attackers_alive": 1, "defenders_alive": 1, "time_left": 10.0}) == "", "live round -> no result")
	var r = R.volatility_step(0.0, 1.0, true, false, 0.0, false)
	check(absf(float(r["v"]) - 100.0 / 26.0) < 0.001, "one second outside a field adds 100/26 points")
	check(absf(float(R.volatility_step(0.0, 26.0, true, false, 0.0, false)["v"]) - 100.0) < 0.001, "26 s of exposure reaches 100")
	r = R.volatility_step(40.0, 1.0, true, true, 7.0, false)
	check(absf(float(r["v"]) - 40.0) < 0.001 and absf(float(r["used"]) - 1.0) < 0.001, "inside a field with allowance: paused, allowance consumed")
	r = R.volatility_step(40.0, 1.0, true, true, 0.4, false)
	check(absf(float(r["used"]) - 0.4) < 0.001 and absf(float(r["v"]) - (40.0 + 0.6 * 100.0 / 26.0)) < 0.001, "allowance exhaustion mid-tick resumes ticking for the remainder")
	r = R.volatility_step(40.0, 1.0, true, true, 0.0, true)
	check(absf(float(r["v"]) - (40.0 + 100.0 / 26.0)) < 0.001, "fast-forward does not apply inside a field")
	r = R.volatility_step(40.0, 1.0, true, false, 0.0, true)
	check(absf(float(r["v"]) - (40.0 + 1.75 * 100.0 / 26.0)) < 0.001, "fast-forward multiplies the rate outside a field")
	check(float(R.volatility_step(40.0, 1.0, false, false, 0.0, true)["v"]) == 40.0, "a non-ticking core never changes")
	var hist := [[10.0, 0.0], [11.0, 3.8], [12.0, 7.7], [13.0, 7.7], [14.0, 11.5]]
	check(absf(R.history_value(hist, 11.5) - 5.75) < 0.001, "history interpolates between samples")
	check(R.history_value(hist, 12.5) == 7.7, "history keeps paused values flat")
	check(R.history_value(hist, 5.0) == 0.0 and R.history_value(hist, 99.0) == 11.5, "history clamps to its range")
	var e = R.route_exposure(128.0, 0.0)
	check(float(e["volatility"]) >= 100.0, "a 128 m direct run without pauses detonates")
	e = R.route_exposure(150.0, 14.0)
	check(float(e["volatility"]) < 100.0, "a 150 m field route with 14 s of pauses survives")


func _test_weapons() -> void:
	print("[Tests] Weapons")
	var W = load("res://src/weapons/Weapons.gd")
	for wid in ["rifle", "shotgun", "sniper", "mg"]:
		var ok := true
		for n in 30:
			var k: Vector2 = W.recoil(wid, n)
			if k.y <= 0.0 or k.y > 0.1 or absf(k.x) > 0.05:
				ok = false
		check(ok, "%s recoil climbs upward and stays bounded over 30 shots" % wid)
		check(W.spread(wid, 0.0, false, false, false, false) <= W.spread(wid, 20.0, false, false, false, false), "%s sustained fire never tightens" % wid)
		check(W.spread(wid, 0.0, true, false, false, false) > W.spread(wid, 0.0, false, false, false, false), "%s moving widens the cone" % wid)
		check(W.spread(wid, 0.0, false, false, false, true) < W.spread(wid, 0.0, false, false, false, false), "%s aiming tightens the cone" % wid)
	check(W.damage_at("rifle", 10.0) == 24.0 and W.damage_at("rifle", 280.0) < 24.0, "rifle damage falls off beyond its range")
	check(int(W.get_data("shotgun")["pellets"]) == 8 and int(W.get_data("mg")["mag"]) == 100 and int(W.get_data("sniper")["mag"]) == 5, "weapon classes carry distinct magazine and pellet definitions")
	check(W.recoil("rifle", 10).x != 0.0 and W.recoil("mg", 10).x != W.recoil("rifle", 10).x, "patterns differ between weapons")


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
