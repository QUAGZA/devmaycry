class_name SabotageSelfTest
extends Node
## --sabotage-selftest (headless host with bots, Hot Return, round live): drives the real defender sabotage path on the
## server (request_sabotage, the per-step resolution of decoys and jammers, and the Reverse Entropy check) and reports
## PASS / FAIL lines plus a final "done" line. It checks each kind's effect, the once-per-round and team-cooldown
## denials, that attackers cannot deploy anything, and that no sabotage changes the Causal Core.
## Test-only shortcuts, marked at each call: the team cooldown and the defender's charge are cleared between probes,
## and the jammer's charge time is skipped by setting fire_at to now. No frame passes between the probes after setup,
## so the bots cannot move the Core while they run.

var fails := 0
var checks := 0


func ck(name: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if not ok:
		fails += 1
	Game.log_ev("SabotageTest", "pass" if ok else "FAIL", {"check": name, "detail": detail})


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func run() -> void:
	var ms: MatchServer = Game.match_server
	var rules = ms.rules
	var def_team: int = rules.defending_team()
	var atk_team: int = rules.attacking_team()
	var d: Player = null
	var a: Player = null
	for p: Player in Game.players.values():
		if not is_instance_valid(p) or not p.alive:
			continue
		if p.team == def_team and d == null:
			d = p
		if p.team == atk_team and a == null:
			a = p
	ck("a defender and an attacker are alive", d != null and a != null)
	if d == null or a == null:
		_done()
		return

	# Stand the defender on clear floor beside the first phase gate (or on the spawn if the map has none) and
	# the attacker a few metres away. Then let the bodies settle so is_on_floor() is meaningful.
	var gate = null
	var pad = null
	for n in ms.def.features.get_children():
		if gate == null and n is Features.PhaseGate:
			gate = n
		if pad == null and (n is Features.Zipline or n is Features.VectorSling):
			pad = n
	var world := Game.world.get_world_3d()
	var start: Vector3 = (gate.global_position + Vector3(3.0, 0.0, 0.0)) if gate != null else d.global_position
	var spot: Dictionary = Features.safe_spot(world, start, Vector3.FORWARD)
	d.global_position = spot["pos"]
	d.velocity = Vector3.ZERO
	a.global_position = Vector3(spot["pos"]) + Vector3(3.0, 0.0, 0.0)
	a.velocity = Vector3.ZERO
	await frames(10)

	# ---- no frames from here on: the probes run back to back on the server
	var core_before: Dictionary = rules.core.duplicate()

	# An attacker has no sabotage: the request is ignored.
	rules.request_sabotage(a, 0)
	ck("attackers cannot deploy a sabotage", not bool(rules.sabo_decoy["active"]) and not a.sabo_spent)

	# MIRAGE: a decoy appears where the defender stands and lasts its full life.
	d.sabo_spent = false
	rules.sabo_team_cd[def_team] = 0.0
	rules.request_sabotage(d, 0)
	ck("mirage deploys a decoy where the defender stands", bool(rules.sabo_decoy["active"]) and d.sabo_spent and absf(float(rules.sabo_decoy["left"]) - SabotageRules.MIRAGE_LIFE) < 0.01, "left %s" % str(rules.sabo_decoy["left"]))

	# An attacker holding E beside the decoy finds out it is not the Core: the decoy is removed.
	a.global_position = Vector3(rules.sabo_decoy["pos"]) + Vector3(1.0, 0.0, 0.0)
	a.interact_held = true
	rules._step_sabotage(0.0)
	a.interact_held = false
	ck("holding E beside the decoy reveals it", not bool(rules.sabo_decoy["active"]))

	# A spent charge refuses the next sabotage (the charge is checked first, so this is the reason that refuses).
	rules.request_sabotage(d, 1)
	ck("a spent charge refuses another sabotage this round", gate == null or float(gate.sealed_left) == 0.0)

	# The team cooldown refuses a sabotage from a defender who still has a charge.
	d.sabo_spent = false
	rules.request_sabotage(d, 1)
	ck("the team cooldown refuses the next sabotage", gate == null or float(gate.sealed_left) == 0.0)

	# SEAL: the nearest phase gate refuses everyone for its full time.
	rules.sabo_team_cd[def_team] = 0.0
	d.sabo_spent = false
	rules.request_sabotage(d, 1)
	if gate == null:
		ck("seal needs a phase gate in reach (none on this map)", true, "skipped")
	else:
		ck("seal closes the nearest phase gate for its full time", float(gate.sealed_left) > 0.0 and absf(float(gate.sealed_left) - SabotageRules.SEAL_TIME) < 0.01, "sealed_left %s" % str(gate.sealed_left))

	# JAMMER: charges at the defender's feet; an attacker inside the ring when it fires loses Reverse Entropy.
	rules.sabo_team_cd[def_team] = 0.0
	d.sabo_spent = false
	rules.request_sabotage(d, 2)
	ck("jammer starts charging at the defender's feet", bool(rules.sabo_jam["pending"]))
	a.global_position = d.global_position + Vector3(2.0, 0.0, 0.0)
	a.jam_until = 0.0
	rules.sabo_jam["fire_at"] = ms.match_time   # test shortcut: skip the charge time
	rules._step_sabotage(0.0)
	ck("a fired jammer jams the attackers inside its ring", a.jam_until > ms.match_time and not bool(rules.sabo_jam["pending"]), "jam_until %s now %s" % [str(a.jam_until), str(ms.match_time)])
	a.re_spent = false
	rules.request_ability(a)
	ck("a jammed attacker cannot start Reverse Entropy", not a.re_spent)

	# CUT: the nearest zipline or launch pad within reach goes offline.
	rules.sabo_team_cd[def_team] = 0.0
	d.sabo_spent = false
	if pad == null:
		ck("cut needs a zipline or launch pad in reach (none on this map)", true, "skipped")
	else:
		var pad_pos: Vector3 = pad.to_global(pad.a) if pad is Features.Zipline else pad.global_position
		d.global_position = Vector3(Features.safe_spot(world, pad_pos + Vector3(2.0, 0.0, 0.0), Vector3.FORWARD)["pos"])
		rules.request_sabotage(d, 3)
		ck("cut takes the nearest pad offline for its full time", float(pad.cut_left) > 0.0 and absf(float(pad.cut_left) - SabotageRules.CUT_TIME) < 0.01, "cut_left %s" % str(pad.cut_left))

	# The Causal Core is never changed by any sabotage.
	var core_after: Dictionary = rules.core.duplicate()
	ck("no sabotage changes the Causal Core", core_before == core_after)

	# The live state carries the sabotage fields that clients draw and show.
	var live: Dictionary = rules.live_dict()
	ck("the live state carries the sabotage state for clients", live.has("sabotage") and (live["sabotage"] as Dictionary).has("decoy") and (live["sabotage"] as Dictionary).has("team_cd"))

	# The defender card reads that replicated state. Only windowed runs have a HUD, so headless runs skip this.
	var hud = get_tree().root.find_child("HUD", true, false)
	if hud == null:
		ck("the defender sabotage card reads the live state (no HUD in headless runs)", true, "skipped")
	else:
		d.sabo_spent = true   # test shortcut: the probes above leave the charge free on maps without a pad
		await frames(20)      # let a snapshot carry the spent charge to the client-side state
		hud._update_sabotage_card(d)
		ck("the defender sabotage card shows SPENT once the charge is used", hud.sabo_card["cd"].text == "SPENT", "text %s" % str(hud.sabo_card["cd"].text))
	_done()


func _done() -> void:
	Game.log_ev("SabotageTest", "done", {"checks": checks, "failures": fails})
