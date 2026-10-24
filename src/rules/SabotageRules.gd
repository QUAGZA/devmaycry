class_name SabotageRules
extends RefCounted
## Defender sabotage kit for HOT RETURN. Pure constants and helpers (no scene access; unit-tested).
##
## Each defender has one sabotage per round (any of the four kinds). A team-wide cooldown separates any two
## sabotages from the same team, and every effect is announced to the attackers when it lands.
## Nothing here touches the Causal Core, its volatility or fuse, the home Stabilizer, or anyone's health:
## sabotages only delay routes, abilities and information for a few seconds, and each one can be played around.

const KINDS := ["mirage", "seal", "jam", "cut"]
const NAMES := {"mirage": "MIRAGE", "seal": "SEAL", "jam": "JAMMER", "cut": "CUT"}

## seconds before the same team can sabotage again (any kind)
const TEAM_COOLDOWN := 10.0
## height tolerance for "is this player at that spot" checks, same as the pickup and gate checks
const HEIGHT_TOL := 3.0

## MIRAGE: a decoy Core signal on the floor where the defender stands. Attackers check it by holding E next to it.
const MIRAGE_LIFE := 14.0
const MIRAGE_REVEAL_RADIUS := 2.6

## SEAL: the nearest Phase Gate within reach refuses everyone for a few seconds (carriers were already refused).
const SEAL_REACH := 15.0
const SEAL_TIME := 7.0

## JAMMER: a charged pulse at the defender's feet. Attackers still inside the radius when it fires lose
## Reverse Entropy for the duration. Leaving the ring during the charge is the counter.
const JAM_CHARGE := 1.5
const JAM_RADIUS := 7.0
const JAM_DURATION := 10.0

## CUT: the nearest zipline or launch pad within reach goes offline (zipline riders are dropped).
const CUT_REACH := 12.0
const CUT_TIME := 10.0


static func next_kind(i: int) -> int:
	return (i + 1) % KINDS.size()


static func name_of(i: int) -> String:
	return str(NAMES.get(KINDS[posmod(i, KINDS.size())], "?"))


static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Horizontal distance within radius and vertically on the same level (not on a floor above or below).
static func within(a: Vector3, b: Vector3, radius: float) -> bool:
	return flat_distance(a, b) <= radius and absf(a.y - b.y) < HEIGHT_TOL
