class_name Loadout
extends RefCounted
## Two-slot weapon loadout rules shared by the armory UI, the server and the bots. A loadout is an
## Array of exactly two DISTINCT weapon ids taken from Weapons.ARMORY. Everything is free: no currency.

const DEFAULT: Array = ["rifle", "deagle"]
const SLOTS := 2
## Seconds the armory waits for a player before the server applies the default (or last) loadout.
const TIMEOUT := 15.0
const GRACE := 0.75

## Armory card text: one-line role, then the stat line (derived from Weapons.DATA so they never drift).
const ROLE := {
	"deagle": "Powerful, accurate sidearm. Semi-auto, heavy kick.",
	"rifle": "Reliable full-auto all-rounder.",
	"shotgun": "Eight pellets. Devastating up close.",
	"sniper": "Scoped bolt-action. Two hits eliminate.",
}


static func is_valid(picks: Array) -> bool:
	if picks.size() != SLOTS:
		return false
	for p in picks:
		if typeof(p) != TYPE_STRING or not Weapons.ARMORY.has(p):
			return false
	return picks[0] != picks[1]


## Server-side sanitising: anything invalid or duplicated becomes `fallback` (itself validated).
static func sanitize(picks: Array, fallback: Array = DEFAULT) -> Array:
	if is_valid(picks):
		return [str(picks[0]), str(picks[1])]
	return fallback.duplicate() if is_valid(fallback) else DEFAULT.duplicate()


static func stat_line(id: String) -> String:
	var w := Weapons.get_data(id)
	var dmg := "%d x%d" % [int(w["damage"]), int(w["pellets"])] if int(w["pellets"]) > 1 else "%d" % int(w["damage"])
	var rate := "AUTO" if bool(w["auto"]) else "SEMI"
	return "DMG %s   MAG %d   %s   RANGE %dm" % [dmg, int(w["mag"]), rate, int(w["range"])]


## Random but sensible bot loadout: easy bots avoid the sniper, hard bots always bring a primary.
static func for_bot(rng: RandomNumberGenerator, difficulty: String) -> Array:
	var pool: Array = Weapons.ARMORY.duplicate()
	if difficulty == "easy":
		pool.erase("sniper")
	var a: String = pool[rng.randi() % pool.size()]
	pool.erase(a)
	var b: String = pool[rng.randi() % pool.size()]
	var out := [a, b]
	if difficulty == "hard" and not (out.has("rifle") or out.has("sniper") or out.has("shotgun")):
		out[1] = "rifle"
	# primary slot first: the longer-range weapon of the pair
	if float(Weapons.get_data(out[1])["range"]) > float(Weapons.get_data(out[0])["range"]):
		out.reverse()
	return sanitize(out)
