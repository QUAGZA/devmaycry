class_name Weapons
extends RefCounted
## Four original weapon classes with distinct roles, ballistics and learnable recoil patterns.
## Patterns are authored here (not copied from any existing game): rifle climbs then drifts in a slow S,
## shotgun kicks once hard, sniper kicks up and settles, machine gun climbs steadily with a bounded wander.

const ORDER := ["rifle", "shotgun", "sniper", "mg"]

const DATA := {
	"rifle": {
		"name": "RIFLE", "slot": 1, "mag": 30, "reserve": 90, "damage": 24.0, "rof": 0.095, "velocity": 320.0,
		"reload": 2.0, "auto": true, "pellets": 1, "spread": 0.004, "spread_move": 0.018, "spread_jump": 0.05,
		"spread_grow": 0.0015, "ads_fov": 58.0, "ads_spread": 0.5, "range": 140.0, "falloff": 0.6, "move_mult": 1.0,
		"switch": 0.45, "recover": 5.0, "color": "78C9AE",
	},
	"shotgun": {
		"name": "SHOTGUN", "slot": 2, "mag": 6, "reserve": 24, "damage": 13.0, "rof": 0.85, "velocity": 220.0,
		"reload": 2.6, "auto": false, "pellets": 8, "spread": 0.055, "spread_move": 0.07, "spread_jump": 0.09,
		"spread_grow": 0.0, "ads_fov": 70.0, "ads_spread": 0.8, "range": 28.0, "falloff": 0.25, "move_mult": 1.0,
		"switch": 0.55, "recover": 3.0, "color": "D9B34A",
	},
	"sniper": {
		"name": "SNIPER", "slot": 3, "mag": 5, "reserve": 20, "damage": 92.0, "rof": 1.3, "velocity": 650.0,
		"reload": 2.8, "auto": false, "pellets": 1, "spread": 0.03, "spread_move": 0.06, "spread_jump": 0.1,
		"spread_grow": 0.0, "ads_fov": 26.0, "ads_spread": 0.02, "range": 300.0, "falloff": 0.9, "move_mult": 0.92,
		"switch": 0.7, "recover": 2.5, "color": "FF5B3D",
	},
	"mg": {
		"name": "MACHINE GUN", "slot": 4, "mag": 100, "reserve": 200, "damage": 18.0, "rof": 0.075, "velocity": 300.0,
		"reload": 3.8, "auto": true, "pellets": 1, "spread": 0.008, "spread_move": 0.03, "spread_jump": 0.07,
		"spread_grow": 0.0012, "ads_fov": 64.0, "ads_spread": 0.65, "range": 120.0, "falloff": 0.6, "move_mult": 0.85,
		"switch": 0.8, "recover": 4.0, "color": "F1E8D8",
	},
}


static func get_data(id: String) -> Dictionary:
	return DATA.get(id, DATA["rifle"])


## Recoil kick (yaw, pitch) in radians for the n-th consecutive shot. Vertical climb plus a bounded
## horizontal pattern that a player can learn and counter.
static func recoil(id: String, n: int) -> Vector2:
	match id:
		"rifle":
			var climb := 0.016 if n < 7 else 0.007
			var sway := 0.010 * sin(float(n) * 0.55 + 0.4) if n >= 5 else 0.0
			return Vector2(sway, climb)
		"shotgun":
			return Vector2(0.012 * (1.0 if n % 2 == 0 else -1.0), 0.06)
		"sniper":
			return Vector2(0.004, 0.07)
		"mg":
			var climb := 0.011 + minf(0.016, float(n) * 0.0006)
			var wander := 0.013 * sin(float(n) * 0.35) + 0.006 * sin(float(n) * 1.7)
			return Vector2(wander, climb)
	return Vector2(0.0, 0.02)


## Cone half-angle (radians) for a shot. First shot accurate, sustained fire grows, movement and
## jumping penalise, aiming down sights tightens.
static func spread(id: String, n: float, moving: bool, airborne: bool, crouching: bool, ads: bool) -> float:
	var w := get_data(id)
	var s := float(w["spread"]) + float(w["spread_grow"]) * minf(n, 25.0)
	if moving:
		s += float(w["spread_move"])
	if airborne:
		s += float(w["spread_jump"])
	if crouching:
		s *= 0.8
	if ads:
		s *= float(w["ads_spread"])
	return s


## Damage after distance falloff: full damage inside range, scaled down to `falloff` fraction at 2x range.
static func damage_at(id: String, distance: float) -> float:
	var w := get_data(id)
	var r := float(w["range"])
	if distance <= r:
		return float(w["damage"])
	var k := clampf((distance - r) / r, 0.0, 1.0)
	return float(w["damage"]) * lerpf(1.0, float(w["falloff"]), k)
