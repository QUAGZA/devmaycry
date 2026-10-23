class_name CorebreakRules
extends RefCounted
## Pure, deterministic Corebreak rules (no scene access) so they can be unit-tested headlessly.
##
## Round win priority (resolved once on the server, in this order):
##   1. detonation      -> attackers
##   2. defuse          -> defenders
##   3. eliminations    -> defenders dead: attackers win (planted or not)
##                         attackers dead and NOT planted: defenders win
##                         attackers dead and planted: round continues (defenders may defuse)
##                         both dead: planted -> attackers, else defenders
##   4. timer at zero   -> defenders, only if the Core was never planted
##
## Match: 4 regulation rounds, sides swap after round 2, first to 3 wins. 2-2 -> overtime in pairs;
## each team attacks once per pair, the first attacker alternates between pairs; a split pair keeps
## the match tied and starts another pair; sweeping a pair wins.

const REGULATION_ROUNDS := 4
const WINS_NEEDED := 3


static func resolve(s: Dictionary) -> String:
	if bool(s.get("detonated", false)):
		return "attack:detonation"
	if bool(s.get("defused", false)):
		return "defend:defuse"
	var planted := bool(s.get("planted", false))
	var attackers := int(s.get("attackers_alive", 0))
	var defenders := int(s.get("defenders_alive", 0))
	if attackers == 0 and defenders == 0:
		return "attack:eliminated" if planted else "defend:eliminated"
	if defenders == 0:
		return "attack:eliminated"
	if attackers == 0 and not planted:
		return "defend:eliminated"
	if float(s.get("time_left", 1.0)) <= 0.0 and not planted:
		return "defend:timer"
	return ""


static func new_match() -> Dictionary:
	return {
		"round": 1,
		"wins": {1: 0, 2: 0},
		"winner": 0,
		"overtime": false,
		"ot_set": 0,
		"ot_round_in_set": 0,
		"ot_set_wins": {1: 0, 2: 0},
		"history": [],
	}


static func attacking_team(m: Dictionary) -> int:
	if not bool(m["overtime"]):
		return 1 if int(m["round"]) <= 2 else 2
	var first := 2 if int(m["ot_set"]) % 2 == 0 else 1
	return first if int(m["ot_round_in_set"]) == 0 else 3 - first


static func record_round(m: Dictionary, winner_team: int) -> void:
	m["wins"][winner_team] = int(m["wins"][winner_team]) + 1
	m["history"].append({"round": m["round"], "winner": winner_team, "overtime": m["overtime"]})
	if not bool(m["overtime"]):
		if int(m["wins"][winner_team]) >= WINS_NEEDED:
			m["winner"] = winner_team
			m["round"] = int(m["round"]) + 1
			return
		if int(m["round"]) >= REGULATION_ROUNDS:
			if int(m["wins"][1]) == int(m["wins"][2]):
				m["overtime"] = true
				m["ot_set"] = 0
				m["ot_round_in_set"] = 0
				m["ot_set_wins"] = {1: 0, 2: 0}
			else:
				m["winner"] = 1 if int(m["wins"][1]) > int(m["wins"][2]) else 2
		m["round"] = int(m["round"]) + 1
		return
	m["ot_set_wins"][winner_team] = int(m["ot_set_wins"][winner_team]) + 1
	m["ot_round_in_set"] = int(m["ot_round_in_set"]) + 1
	m["round"] = int(m["round"]) + 1
	if int(m["ot_round_in_set"]) >= 2:
		if int(m["ot_set_wins"][winner_team]) >= 2:
			m["winner"] = winner_team
			return
		m["ot_set"] = int(m["ot_set"]) + 1
		m["ot_round_in_set"] = 0
		m["ot_set_wins"] = {1: 0, 2: 0}
