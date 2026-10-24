class_name ArmoryFlow
extends RefCounted
## Server-side armory phase. Runs BEFORE MatchServer.begin() so the round and match timers never start while
## players are still choosing. Every human gets Loadout.TIMEOUT seconds (+ a short grace) and the phase ends as
## soon as all of them have answered; anyone who has not answered simply keeps the default (or current) loadout.
## The server never waits on a peer for longer than the timeout, and a vanished peer is dropped from the wait.
## Picks are always validated here: invalid or duplicate picks fall back to Loadout.DEFAULT.

var active := false
var t := 0.0
var confirmed: Dictionary = {}     # peer id -> true once the player has answered this phase
var started_ms := 0


func start(bots_rng: RandomNumberGenerator) -> void:
	active = true
	t = Loadout.TIMEOUT + Loadout.GRACE
	confirmed.clear()
	started_ms = Time.get_ticks_msec()
	for p: Player in Game.players.values():
		if not is_instance_valid(p):
			continue
		p.frozen = true
		if p.is_bot:
			var diff := str(Net.players.get(p.id, {}).get("difficulty", "medium"))
			p.set_loadout(Loadout.for_bot(bots_rng, diff))
			Game.log_ev("Armory", "bot_loadout", {"id": p.id, "loadout": p.loadout, "difficulty": diff})
	if Game.match_server != null:
		Game.match_server.phase = "pre_round"   # no damage, no abilities while choosing
	Game.log_ev("Armory", "open", {"timeout": Loadout.TIMEOUT, "humans": _awaiting().size()})
	Game.rpc_armory_open.rpc(Loadout.TIMEOUT, true)


func _awaiting() -> Array:
	var out: Array = []
	for id in Game.players.keys():
		var p = Game.players[id]
		if is_instance_valid(p) and not p.is_bot and not confirmed.has(id):
			out.append(id)
	return out


func step(delta: float) -> void:
	if not active:
		return
	t -= delta
	if _awaiting().is_empty():
		finish("all_confirmed")
	elif t <= 0.0:
		finish("timeout")


## Validate and apply a player's picks. Allowed while the armory phase is active, or during the pre-round
## countdown of a round (re-opened with the armory key). Returns the loadout that was applied.
func on_submit(pid: int, picks: Array) -> Array:
	var p = Game.players.get(pid)
	if p == null or not is_instance_valid(p) or p.is_bot:
		return []
	var in_pre_round: bool = Game.match_server != null and Game.match_server.phase == "pre_round" and p.alive
	if not active and not in_pre_round:
		Game.log_ev("Armory", "rejected_phase", {"id": pid})
		Game.send_armory_ack(pid, p.loadout, false, "ROUND IN PROGRESS")
		return p.loadout
	var ok := Loadout.is_valid(picks)
	var clean := Loadout.sanitize(picks)
	p.set_loadout(clean)
	confirmed[pid] = true
	Game.log_ev("Armory", "confirm" if ok else "invalid_fallback", {"id": pid, "picks": picks, "applied": clean})
	Game.send_armory_ack(pid, clean, ok, "" if ok else "INVALID PICK / DEFAULT LOADOUT APPLIED")
	return clean


func finish(reason: String) -> void:
	if not active:
		return
	active = false
	for id in _awaiting():
		var p: Player = Game.players.get(id)
		if p != null and is_instance_valid(p):
			p.set_loadout(p.loadout)   # keep what they hold (default on first use); re-validated
			Game.send_armory_ack(id, p.loadout, false, "TIME UP / LOADOUT LOCKED")
	Game.log_ev("Armory", "close", {"reason": reason, "ms": Time.get_ticks_msec() - started_ms})
	Game.rpc_armory_close.rpc()
	if Game.match_server != null:
		Game.match_server.begin()
