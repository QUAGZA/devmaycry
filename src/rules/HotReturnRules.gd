class_name HotReturnRules
extends RefCounted
## Pure, deterministic HOT RETURN rules (no scene access; unit-tested).
##
## Round result priority, resolved once on the server:
##   1. detonation already resolved      -> defenders
##   2. stabilized at the home Stabilizer -> attackers
##   3. round timer at zero              -> defenders
## Eliminations never decide a round: dead players respawn after RESPAWN_DELAY with spawn protection.
## Match structure (side swap after 2 regulation rounds, first to 3, 2-2 overtime pairs) is shared with
## CorebreakRules.new_match / record_round / attacking_team.

const ROUND_TIME := 120.0
const FUSE := 26.0
const RATE := 100.0 / FUSE           # volatility points per second while ticking
const FIELD_ALLOWANCE := 7.0         # seconds of pause per field per round
const FIELD_RADIUS := 15.0
const FF_RATE_MULT := 1.75
const FF_RADIUS := 8.0
const FF_DURATION := 3.0
const FF_PROJECTILE_MULT := 1.5
const FF_SENS_MULT := 1.15
const REWIND_SECONDS := 6.0
const CARRY_SPEED := 4.2
const PICKUP_RADIUS := 2.6
const STABILIZE_RADIUS := 3.2
const HISTORY_SECONDS := 10.0


static func resolve(s: Dictionary) -> String:
	if bool(s.get("detonated", false)):
		return "defend:detonation"
	if bool(s.get("stabilized", false)):
		return "attack:stabilized"
	if float(s.get("time_left", 1.0)) <= 0.0:
		return "defend:timer"
	return ""


## Advances volatility for one tick. Returns {"v": new value, "used": field allowance consumed}.
## ticking: Core is being carried (a dropped, cradled or temporally locked Core is paused).
## allowance: remaining pause seconds of the field the Core is inside (0 when not in a field).
## ff: a Fast-Forward field covers the Core (only applies outside a Stability Field).
static func volatility_step(v: float, delta: float, ticking: bool, in_field: bool, allowance: float, ff: bool) -> Dictionary:
	if not ticking or delta <= 0.0:
		return {"v": v, "used": 0.0}
	var used := 0.0
	var dt := delta
	if in_field and allowance > 0.0:
		used = minf(allowance, delta)
		dt = delta - used
	var mult := 1.0
	if ff and not in_field:
		mult = FF_RATE_MULT
	return {"v": clampf(v + RATE * dt * mult, 0.0, 100.0), "used": used}


## Volatility at absolute time t from a history of [time, value] samples (oldest first).
static func history_value(history: Array, t: float) -> float:
	if history.is_empty():
		return 0.0
	if t <= float(history[0][0]):
		return float(history[0][1])
	var last: Array = history[history.size() - 1]
	if t >= float(last[0]):
		return float(last[1])
	for i in range(1, history.size()):
		var a: Array = history[i - 1]
		var b: Array = history[i]
		if float(b[0]) >= t:
			var span := float(b[0]) - float(a[0])
			var k := 0.0 if span <= 0.0 else clampf((t - float(a[0])) / span, 0.0, 1.0)
			return lerpf(float(a[1]), float(b[1]), k)
	return float(last[1])


static func new_match(policy := "every_round") -> Dictionary:
	return CorebreakRules.new_match(policy)


static func attacking_team(m: Dictionary) -> int:
	return CorebreakRules.attacking_team(m)


static func record_round(m: Dictionary, winner_team: int) -> void:
	CorebreakRules.record_round(m, winner_team)


## Seconds of carrying needed for a route, and the resulting volatility with a given pause budget.
static func route_exposure(distance_m: float, pause_seconds: float) -> Dictionary:
	var carry := distance_m / CARRY_SPEED
	var exposure := maxf(0.0, carry - pause_seconds)
	return {"carry": carry, "exposure": exposure, "volatility": clampf(exposure * RATE, 0.0, 100.0)}
