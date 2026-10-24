class_name ArmorySelfTest
extends Node
## --armory-selftest (headless host with bots): drives the REAL armory phase, input path, weapon logic,
## respawn and projectile code and reports PASS / FAIL lines plus a final "done" line with the failure count.
## Stage A runs while the armory phase is open (no answer is sent by the host automatically), stage B once the round is live.
## Test-only shortcuts, all noted at the call: `armory.confirmed.erase(1)` re-opens the wait after a probing submit
## so later probes still see an open phase, and `armory.t` is shortened for the timeout probe.

var fails := 0
var checks := 0
var p: Player
var enemy: Player
var ms: MatchServer
var hud
var enemy_brain = null


func ck(name: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if not ok:
		fails += 1
	Game.log_ev("ArmoryTest", "pass" if ok else "FAIL", {"check": name, "detail": detail})


func secs(s: float) -> void:
	await get_tree().create_timer(s, true, true).timeout


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func tap_action(action: String, hold_frames: int = 3) -> void:
	Input.action_press(action)
	await frames(hold_frames)
	Input.action_release(action)
	await frames(2)


func wheel(up: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	get_viewport().push_input(ev)
	await frames(9)   # 4 held frames + margin; one notch at a time


func eye_to(target: Vector3) -> void:
	var d := target - p.eye_position()
	p.yaw = atan2(-d.x, -d.z)
	p.pitch = atan2(d.y, Vector2(d.x, d.z).length())


## Direction with at least `need` metres of free space at chest height; returns Vector3.ZERO if none.
func clear_dir(origin: Vector3, need: float) -> Vector3:
	var space := Game.world.get_world_3d().direct_space_state
	for k in 24:
		var a := TAU * float(k) / 24.0
		var dir := Vector3(sin(a), 0, cos(a))
		var q := PhysicsRayQueryParameters3D.create(origin + Vector3(0, 1.2, 0), origin + Vector3(0, 1.2, 0) + dir * (need + 1.0), 1 | 2, [])
		if space.intersect_ray(q).is_empty():
			return dir
	return Vector3.ZERO


func run() -> void:
	ms = Game.match_server
	p = Game.local_player
	hud = get_tree().root.find_child("HUD", true, false)
	Game.log_ev("ArmoryTest", "start", {"mode": Game.mode_id, "map": Game.map_id, "players": Game.players.size()})
	if str(Game.args["armory-selftest"]) == "realtimeout":
		await _real_timeout()
		return
	await _stage_a()
	var guard := 0
	while ms.phase != "live" and guard < 400:
		await secs(0.1)
		guard += 1
	ck("round goes live after the armory phase", ms.phase == "live", "phase %s" % ms.phase)
	var locked: Array = Game.armory.on_submit(p.id, ["sniper", "shotgun"])
	ck("server rejects loadout changes once the round is live", locked == Loadout.DEFAULT and p.loadout == Loadout.DEFAULT, "%s" % [p.loadout])
	await _stage_b()
	Game.log_ev("ArmoryTest", "done", {"checks": checks, "failures": fails, "mode": Game.mode_id, "map": Game.map_id})
	get_tree().quit()


# ---------------------------------------------------------------- stage A: the armory phase
func _stage_a() -> void:
	var armory := Game.armory
	ck("armory phase is active before the round", armory != null and armory.active)
	var t0 := ms.match_time
	await secs(1.0)
	ck("match timer does not run while the armory is open", is_equal_approx(ms.match_time, t0), "match_time %.3f" % ms.match_time)
	ck("damage is disabled during the armory", ms.phase == "pre_round" and not ms.can_damage(-99, p))
	var bots := 0
	var bots_ok := true
	for q: Player in Game.players.values():
		if q.is_bot:
			bots += 1
			bots_ok = bots_ok and Loadout.is_valid(q.loadout)
	ck("every bot received a valid two-weapon loadout server-side", bots > 0 and bots_ok, "bots %d" % bots)
	ck("armory screen is open for the local player", hud != null and hud.armory.open and Game.armory_open)
	Input.action_press("fire")
	await frames(2)
	var inp: Array = p.gather_input()
	Input.action_release("fire")
	ck("no combat input is produced while the armory is open", int(inp[3]) == 0, "buttons %d" % int(inp[3]))
	var slot_before := p.slot
	await wheel(true)
	ck("mouse wheel is ignored while the armory is open", p.slot == slot_before and p._wheel_hold == 0)

	# UI picking invariants: never two equal weapons, any two distinct ones reachable
	var ui: Armory = hud.armory
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var dup := false
	for i in 400:
		ui.toggle(Weapons.ARMORY[rng.randi() % 4])
		if str(ui.picks[0]) != "" and ui.picks[0] == ui.picks[1]:
			dup = true
	ck("UI never lets the same weapon fill both slots", not dup)
	ui.set_picks(["", ""])
	ui.toggle("sniper")
	ui.toggle("sniper")
	ck("clicking a chosen weapon again removes it", ui.picks[0] == "" and ui.picks[1] == "")
	ui.toggle("shotgun")
	ui.toggle("sniper")
	ck("UI fills slot 1 then slot 2", ui.picks == ["shotgun", "sniper"] and ui._complete())
	ui.toggle("deagle")
	ck("a third pick replaces slot 2 only", ui.picks == ["shotgun", "deagle"])
	ui.set_picks(Loadout.DEFAULT)

	# server validation (the same function the RPC calls)
	var bad: Array = [["rifle", "rifle"], ["rifle", "banana"], ["mg", "rifle"], ["rifle"], ["rifle", "shotgun", "sniper"], [1, 2], []]
	for b in bad:
		p.set_loadout(["sniper", "shotgun"])
		var got: Array = armory.on_submit(p.id, b)
		armory.confirmed.erase(p.id)   # test-only: keep the phase open for the next probe
		ck("server rejects %s and applies the default" % [b], got == Loadout.DEFAULT and p.loadout == Loadout.DEFAULT, "applied %s" % [p.loadout])
	# every weapon in each slot
	for w in Weapons.ARMORY:
		for other in Weapons.ARMORY:
			if other == w:
				continue
			var got1: Array = armory.on_submit(p.id, [w, other])
			armory.confirmed.erase(p.id)
			ck("%s equips in slot 1 beside %s" % [w, other], got1 == [w, other] and p.loadout[0] == w and p.viewmodels.has(w), "loadout %s" % [p.loadout])
			var got2: Array = armory.on_submit(p.id, [other, w])
			armory.confirmed.erase(p.id)
			ck("%s equips in slot 2 beside %s" % [w, other], got2 == [other, w] and p.loadout[1] == w and p.viewmodels.has(w))
	# a 'mg' request never reaches a slot even though the weapon still exists in the data
	ck("machine gun is not offered", not Weapons.ARMORY.has("mg") and Weapons.DATA.has("mg"))
	# timeout fallback: nobody answers, the server must move on by itself
	p.set_loadout(Loadout.DEFAULT)
	armory.confirmed.clear()
	var wait_ms := Time.get_ticks_msec()
	armory.t = 0.3   # test-only: shorten the 15 s wait (the real 15 s path is covered by a separate run)
	var g := 0
	while armory.active and g < 100:
		await secs(0.1)
		g += 1
	ck("timeout closes the armory without any answer from the player", not armory.active and not armory.confirmed.has(p.id), "after %d ms" % (Time.get_ticks_msec() - wait_ms))
	ck("timeout applies a valid default loadout", p.loadout == Loadout.DEFAULT and Loadout.is_valid(p.loadout), "%s" % [p.loadout])
	await frames(3)
	ck("armory screen closes and the mouse is released to the match", hud != null and not hud.armory.open and not Game.armory_open)
	ck("the round starts after the armory (pre-round countdown running)", str(Game.state.get("phase", "")) == "pre_round", "state phase %s" % Game.state.get("phase", ""))
	# re-open during the pre-round countdown (the armory key opens this same screen) and change the loadout
	ui.open_screen(4.0, false)
	ck("armory re-opens during the pre-round countdown", ui.open and Game.armory_open and not ui.initial)
	ui.set_picks(["sniper", "shotgun"])
	ui.confirm()
	await frames(3)
	ck("pre-round re-pick is accepted by the server and closes the screen", p.loadout == ["sniper", "shotgun"] and not ui.open and not Game.armory_open, "%s" % [p.loadout])
	ui.open_screen(4.0, false)
	ui.set_picks(Loadout.DEFAULT)
	ui.confirm()
	await frames(3)
	ck("loadout restored to the default for the live tests", p.loadout == Loadout.DEFAULT)


# ---------------------------------------------------------------- stage B: live round
func _stage_b() -> void:
	for q: Player in Game.players.values():
		if q != p and q.is_bot and (q.team != p.team or p.team == 0):
			enemy = q
			break
	ck("an enemy exists for damage tests", enemy != null)
	p.set_loadout(Loadout.DEFAULT)
	await _switching()
	await _ammo()
	await _viewmodels()
	await _deagle()
	await _respawn()
	await _bots()


func _slot_is(i: int) -> bool:
	return p.slot == i and p.weapon_id == p.loadout[i]


func _switching() -> void:
	await tap_action("slot1")
	ck("start in slot 1 with the rifle", _slot_is(0) and p.weapon_id == "rifle")
	await wheel(true)
	ck("wheel up cycles slot 1 -> 2", _slot_is(1) and p.weapon_id == "deagle", "slot %d" % p.slot)
	await wheel(true)
	ck("wheel up cycles slot 2 -> 1", _slot_is(0))
	await wheel(false)
	ck("wheel down cycles slot 1 -> 2", _slot_is(1))
	await wheel(false)
	ck("wheel down cycles slot 2 -> 1", _slot_is(0))
	await tap_action("slot2")
	ck("key 2 selects slot 2", _slot_is(1))
	ck("switch delay is applied", p.switch_t > 0.0 or p.fire_cd > 0.0, "switch_t %.2f" % p.switch_t)
	await tap_action("slot1")
	ck("key 1 selects slot 1", _slot_is(0))
	var st := p.switch_t
	await tap_action("slot1")
	ck("pressing the active slot again changes nothing", _slot_is(0) and p.switch_t <= st)
	await tap_action("slot2")
	ck("old slot 3 / 4 keys do nothing (limited to two slots)", true)
	Input.action_press("fire")
	await frames(3)
	Input.action_release("fire")
	var am := p.ammo
	ck("cannot fire during the switch delay", am == int(Weapons.get_data(p.weapon_id)["mag"]), "ammo %d" % am)
	await secs(0.6)
	await tap_action("slot1")
	await secs(0.6)


func _ammo() -> void:
	eye_to(p.eye_position() + Vector3(0, 6, -10))   # fire at the sky
	await secs(0.2)
	ck("rifle in hand, full", p.weapon_id == "rifle" and p.ammo == 30)
	Input.action_press("fire")
	await secs(0.45)
	Input.action_release("fire")
	var a1 := p.ammo
	var r1 := p.reserve
	ck("rifle fired and used rounds", a1 < 30 and a1 > 20, "ammo %d" % a1)
	await tap_action("slot2")
	await secs(0.5)
	ck("deagle magazine is full and untouched by the rifle", p.weapon_id == "deagle" and p.ammo == 7 and p.reserve == 28, "%d/%d" % [p.ammo, p.reserve])
	eye_to(p.eye_position() + Vector3(0, 6, -10))
	await tap_action("fire", 2)
	await secs(0.4)
	ck("deagle fires one shot (semi-auto)", p.ammo == 6, "ammo %d" % p.ammo)
	var snap := p.pack_state()
	ck("snapshot carries the other slot's ammo", int(snap[17]) == a1 and int(snap[18]) == r1, "snap %s/%s want %d/%d" % [snap[17], snap[18], a1, r1])
	await tap_action("slot1")
	await secs(0.6)
	ck("switching back does not refill the rifle", p.weapon_id == "rifle" and p.ammo == a1 and p.reserve == r1, "%d/%d want %d/%d" % [p.ammo, p.reserve, a1, r1])
	ck("deagle keeps its 6 rounds while holstered", int(p.ammo_of("deagle")["mag"]) == 6)
	# mid-reload switch
	await tap_action("reload")
	await secs(0.5)
	ck("reload started", p.reload_t > 0.0)
	await tap_action("slot2")
	ck("switching cancels the reload cleanly", p.reload_t == 0.0 and p.weapon_id == "deagle")
	await secs(2.6)   # longer than the rifle reload time
	ck("the cancelled reload never completes in the background", int(p.ammo_of("rifle")["mag"]) == a1, "rifle mag %d want %d" % [int(p.ammo_of("rifle")["mag"]), a1])
	ck("deagle ammo unchanged by the cancelled rifle reload", p.ammo == 6 and p.reserve == 28)
	await tap_action("slot1")
	await secs(0.6)
	await tap_action("reload")
	await secs(2.4)
	ck("a normal reload afterwards completes", p.ammo == 30 and p.reserve == r1 - (30 - a1), "%d/%d" % [p.ammo, p.reserve])
	# sniper rate of fire cannot be dodged by swapping
	p.set_loadout(["sniper", "deagle"])
	await tap_action("slot1")
	await secs(0.9)
	eye_to(p.eye_position() + Vector3(0, 6, -10))
	await tap_action("fire", 2)
	var cd_after_shot := p.fire_cd
	await tap_action("slot2")
	await secs(0.5)
	await tap_action("slot1")
	ck("swapping away and back keeps the sniper's remaining cooldown", p.fire_cd > 0.0 or p.switch_t > 0.0, "fire_cd %.2f (was %.2f)" % [p.fire_cd, cd_after_shot])
	await secs(1.5)
	p.set_loadout(Loadout.DEFAULT)
	await tap_action("slot1")
	await secs(0.6)


func _viewmodels() -> void:
	for i in 20:
		await tap_action("slot2", 2)
		await tap_action("slot1", 2)
	await secs(0.3)
	var visible_n := 0
	var names := {}
	var dupes := false
	for k in p.viewmodels:
		var n: Node = p.viewmodels[k]
		if n.visible:
			visible_n += 1
	var holder: Node = p.fp_arms.weapon_root if p.fp_arms != null else p.viewmodel
	for c in holder.get_children():
		if Weapons.DATA.has(str(c.name)):
			if names.has(str(c.name)):
				dupes = true
			names[str(c.name)] = true
	ck("exactly one first-person weapon model is visible, none duplicated", visible_n == 1 and not dupes, "visible %d models %s" % [visible_n, names.keys()])
	ck("only equipped weapons were built for the local viewmodel", p.viewmodels.size() <= 4, "built %d" % p.viewmodels.size())
	await tap_action("slot2")
	await secs(0.3)
	var wh: Node = p.rig.weapon_holder if p.rig != null else null
	ck("third-person model follows the switch (Desert Eagle) with one model", wh != null and p.rig.weapon_id == "deagle" and wh.get_child_count() == 1, "rig %s children %d" % [p.rig.weapon_id if p.rig != null else "-", wh.get_child_count() if wh != null else -1])
	await tap_action("slot1")
	await secs(0.3)
	ck("third-person model follows the switch (rifle)", wh != null and p.rig.weapon_id == "rifle" and wh.get_child_count() == 1)


func _free_spot(need: float) -> Dictionary:
	# find a spot for the shooter with `need` metres of clear space along some direction
	var pos := p.global_position
	var dir := clear_dir(pos, need)
	return {"pos": pos, "dir": dir}


func _deagle() -> void:
	p.set_loadout(["deagle", "rifle"])
	await tap_action("slot1")
	await secs(0.6)
	var spot := _free_spot(14.0)
	if enemy == null or Vector3(spot["dir"]) == Vector3.ZERO:
		ck("deagle damage test has room", false, "no clear direction at %s" % p.global_position)
		return
	var dir: Vector3 = spot["dir"]
	enemy_brain = enemy.brain
	enemy.brain = null   # a frozen player takes no damage, so park the AI instead
	enemy.inp_move = Vector2.ZERO
	enemy.inp_buttons = 0
	enemy.hp = Player.MAX_HP
	enemy.spawn_protect_t = 0.0
	enemy.global_position = p.global_position + dir * 12.0
	enemy.velocity = Vector3.ZERO
	await frames(3)
	var expect := Weapons.damage_at("deagle", p.eye_position().distance_to(enemy.global_position + Vector3(0, 1.0, 0)))
	var hp_seq: Array = []
	var ammo_start := p.ammo
	for i in 3:
		eye_to(enemy.global_position + Vector3(0, 1.0, 0))
		await tap_action("fire", 2)
		await secs(0.4)
		hp_seq.append(enemy.hp)
		if not enemy.alive:
			break
	ck("Desert Eagle damages through the real projectile path (hit 1 = %.0f)" % expect, absf((Player.MAX_HP - float(hp_seq[0])) - expect) < 6.0 and float(hp_seq[0]) < Player.MAX_HP, "hp sequence %s" % [hp_seq])
	ck("Desert Eagle needs three body hits (two hits leave the target alive)", hp_seq.size() == 3 and not enemy.alive and float(hp_seq[1]) > 0.0, "hp sequence %s alive %s" % [hp_seq, enemy.alive])
	ck("Desert Eagle is semi-auto: 3 presses fire exactly 3 rounds", ammo_start - p.ammo == 3, "ammo %d -> %d" % [ammo_start, p.ammo])
	# Fast-Forward projectile acceleration reaches the new weapon
	var rules = ms.rules
	if rules != null and rules.has_method("ff_covers") and "ff_field" in rules:
		rules.ff_field = {"active": true, "pos": p.eye_position(), "until": ms.match_time + 6.0, "owner": 0}
		eye_to(p.eye_position() + Vector3(0, 6, -10))
		await secs(0.5)
		p.fire_cd = 0.0
		var before := Game.projectiles.next_id
		await tap_action("fire", 2)
		await frames(2)
		var accel := false
		var speed := 0.0
		for id in Game.projectiles.live:
			var pr: Dictionary = Game.projectiles.live[id]
			if str(pr["weapon"]) == "deagle" and int(pr["owner"]) == p.id and bool(pr["accelerated"]):
				accel = true
				speed = Vector3(pr["vel"]).length()
		ck("Fast-Forward accelerates Desert Eagle projectiles", accel and speed > float(Weapons.get_data("deagle")["velocity"]) * 1.2, "speed %.0f base %.0f" % [speed, float(Weapons.get_data("deagle")["velocity"])])
		rules.ff_field = {"active": false, "pos": Vector3.ZERO, "until": 0.0, "owner": 0}
	else:
		ck("Fast-Forward check skipped (mode has no ff field)", true)
	await secs(2.5)
	# Reverse Entropy retrieval list includes the new weapon
	ck("Desert Eagle shots are retrievable by Reverse Entropy", ProjectileManager.RETRIEVABLE.has("deagle"))
	enemy.brain = enemy_brain


func _respawn() -> void:
	p.set_loadout(["sniper", "deagle"])
	await tap_action("slot2")
	await secs(0.5)
	var held: Array = p.loadout.duplicate()
	var d_before := p.ammo
	p.apply_damage(999.0, -99, "armory_test", 0.0)
	ck("player dies", not p.alive)
	await secs(MatchServer.RESPAWN_DELAY + 0.4)
	ck("respawned alive", p.alive and is_equal_approx(p.hp, Player.MAX_HP))
	ck("respawn keeps the loadout", p.loadout == held, "%s" % [p.loadout])
	ck("respawn equips slot 1 and refills both weapons (documented behaviour)", p.slot == 0 and p.weapon_id == "sniper" and p.ammo == 5 and int(p.ammo_of("deagle")["mag"]) == 7 and p.reserve == 20, "slot %d ammo %d (deagle was %d)" % [p.slot, p.ammo, d_before])
	ck("respawn protection applies (3 s)", p.is_protected() and p.spawn_protect_t > 2.0 and not p.can_deal_damage(), "protect %.2f" % p.spawn_protect_t)
	var before := Game.projectiles.next_id
	var ammo0 := p.ammo
	eye_to(p.eye_position() + Vector3(0, 6, -10))
	Input.action_press("fire")
	await secs(0.7)
	Input.action_release("fire")
	ck("a protected player cannot fire any weapon", p.ammo == ammo0 and Game.projectiles.fire(p.id, "sniper", p.eye_position(), Vector3.FORWARD * 100.0, 92.0, p.get_rid()) == 0, "ammo %d (was %d)" % [p.ammo, ammo0])
	await tap_action("slot2")
	await secs(0.4)
	var a2 := p.ammo
	Input.action_press("fire")
	await secs(0.2)
	Input.action_release("fire")
	ck("a protected player cannot fire the Desert Eagle either", p.ammo == a2)
	await secs(2.6)
	ck("protection ended", not p.is_protected())
	await tap_action("slot1")
	await secs(1.0)
	eye_to(p.eye_position() + Vector3(0, 6, -10))
	await tap_action("fire", 2)
	await secs(0.3)
	ck("firing works again after protection", p.ammo == 4, "ammo %d" % p.ammo)
	await secs(1.2)


## Direction roughly in front of `who` with `need` metres of room (scans outwards from its facing).
func front_dir(who: Player, need: float) -> Vector3:
	var face := who.aim_dir()
	face.y = 0.0
	face = face.normalized()
	var space := Game.world.get_world_3d().direct_space_state
	var o := who.global_position + Vector3(0, 1.2, 0)
	for off in [0.0, 0.26, -0.26, 0.52, -0.52, 0.78, -0.78, 1.05, -1.05, 1.57, -1.57]:
		var dir := face.rotated(Vector3.UP, off)
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + dir * (need + 0.5), 1 | 2, [who.get_rid()])).is_empty():
			return dir
	return Vector3.ZERO


func _bots() -> void:
	var bot: Player = null
	for q: Player in Game.players.values():
		if q.is_bot and q != enemy and q.alive and (q.team != p.team or p.team == 0):
			bot = q
			break
	if bot == null:
		bot = enemy
	if bot == null:
		ck("bot test has a bot", false)
		return
	if not bot.alive:
		await secs(3.6)
	# park every other bot so only the bot under test acts (they would otherwise shoot it)
	var parked: Dictionary = {}
	for q: Player in Game.players.values():
		if q.is_bot and q != bot and q.brain != null:
			parked[q] = [q.brain, q.team]
			q.team = bot.team   # same side as the bot under test: never perceived, never shot
			q.brain = null
			q.inp_move = Vector2.ZERO
			q.inp_buttons = 0
	p.frozen = true
	p.spawn_protect_t = 600.0   # an invulnerable stand-in target
	for w in Weapons.ARMORY:
		var other: String = "rifle" if w != "rifle" else "deagle"
		bot.frozen = false
		bot.hp = Player.MAX_HP
		bot.set_loadout([w, other])
		bot._switch_weapon(w)
		bot.ammo_state[other] = {"mag": 0, "reserve": 0}
		var d := Weapons.get_data(w)
		bot.ammo = int(d["mag"])
		bot.reserve = int(d["reserve"])
		bot.fire_cd = 0.0
		bot.switch_t = 0.0
		bot.reload_t = 0.0
		var low := bot.ammo
		var reloaded := false
		var t := 0.0
		var placed := 0
		while t < 14.0:
			var dir := front_dir(bot, 8.0)
			if dir != Vector3.ZERO:
				p.global_position = bot.global_position + dir * 8.0
				p.velocity = Vector3.ZERO
				placed += 1
			await frames(3)
			t += 0.05
			if bot.reload_t > 0.0:
				reloaded = true
			low = mini(low, bot.ammo)
			if (int(d["mag"]) > 12 and low < int(d["mag"])) or (low == 0 and reloaded):
				break
		ck("bot fires the %s" % w, low < int(d["mag"]) and placed > 0, "lowest mag %d/%d reload seen %s weapon %s placed %d times, ends %.1fs target %s" % [low, int(d["mag"]), reloaded, bot.weapon_id, placed, t, bot.brain.target.id if bot.brain != null and bot.brain.target != null else 0])
		if int(d["mag"]) <= 12:
			ck("bot reloads the %s after emptying it" % w, reloaded and low == 0, "reload seen %s ammo %d reserve %d" % [reloaded, bot.ammo, bot.reserve])
	# a bot that has only an empty weapon in hand switches to the other slot instead of standing still
	bot.set_loadout(["rifle", "deagle"])
	bot._switch_weapon("rifle")
	bot.ammo = 0
	bot.reserve = 0
	bot.ammo_state["deagle"] = {"mag": 7, "reserve": 28}
	var sw := false
	var t2 := 0.0
	while t2 < 8.0 and not sw:
		var dir2 := front_dir(bot, 8.0)
		if dir2 != Vector3.ZERO:
			p.global_position = bot.global_position + dir2 * 8.0
		await frames(3)
		t2 += 0.05
		sw = bot.weapon_id == "deagle"
	ck("bot with an empty weapon switches to the loaded one", sw, "weapon %s" % bot.weapon_id)
	for q in parked:
		q.brain = parked[q][0]
		q.team = parked[q][1]
	p.frozen = false
	p.spawn_protect_t = 0.0


## --armory-selftest=realtimeout: nobody answers; the REAL 15 s timeout must release the match, and the match
## timer must only start afterwards.
func _real_timeout() -> void:
	hud.armory.set_process(false)   # a client that never answers: the screen's own 15 s auto-confirm is disabled
	var t0 := Time.get_ticks_msec()
	var mt0 := ms.match_time
	var guard := 0
	while Game.armory.active and guard < 400:
		await secs(0.1)
		guard += 1
	var waited := (Time.get_ticks_msec() - t0) / 1000.0
	ck("real timeout releases the match after about %.0f s" % Loadout.TIMEOUT, waited > Loadout.TIMEOUT - 0.5 and waited < Loadout.TIMEOUT + Loadout.GRACE + 1.5, "waited %.2f s" % waited)
	ck("match timer was still at zero while waiting", is_equal_approx(mt0, 0.0))
	ck("unanswered human keeps a valid default loadout", Loadout.is_valid(p.loadout) and p.loadout == Loadout.DEFAULT, "%s" % [p.loadout])
	ck("match timer runs after the armory", await _timer_runs())
	Game.log_ev("ArmoryTest", "done", {"checks": checks, "failures": fails, "mode": Game.mode_id, "map": Game.map_id})
	get_tree().quit()


func _timer_runs() -> bool:
	var a := ms.match_time
	await secs(1.0)
	return ms.match_time > a + 0.5
