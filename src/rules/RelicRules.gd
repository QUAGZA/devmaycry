class_name RelicRules
extends RefCounted
## Pure Relic Rush scoring rules (unit-tested): 2 per elimination, 1 per shard, 1 per beacon tick.
## First to TARGET wins immediately; otherwise highest score at zero; a tie at zero goes to
## sudden death where the first point decides.

const TARGET := 25
const KILL_POINTS := 2
const SHARD_POINTS := 1
const BEACON_POINTS := 1


static func new_state(ids: Array) -> Dictionary:
	var pts := {}
	for id in ids:
		pts[id] = 0
	return {"points": pts, "sudden_death": false}


static func add_points(s: Dictionary, id: int, n: int) -> void:
	s["points"][id] = int(s["points"].get(id, 0)) + n


static func leaders(s: Dictionary) -> Array:
	var best := -1
	var ids := []
	for id in s["points"]:
		var v := int(s["points"][id])
		if v > best:
			best = v
			ids = [id]
		elif v == best:
			ids.append(id)
	return ids


static func winner(s: Dictionary, time_left: float) -> int:
	var top := leaders(s)
	if top.is_empty():
		return 0
	var best := int(s["points"][top[0]])
	if best >= TARGET and top.size() == 1:
		return top[0]
	if time_left <= 0.0 and top.size() == 1 and (best > 0 or bool(s["sudden_death"])):
		return top[0]
	return 0


static func needs_sudden_death(s: Dictionary, time_left: float) -> bool:
	return time_left <= 0.0 and leaders(s).size() > 1


static func beacon_owner(occupants: Dictionary) -> int:
	var owner := 0
	var n := 0
	for id in occupants:
		if occupants[id]:
			n += 1
			owner = id
	return owner if n == 1 else 0
