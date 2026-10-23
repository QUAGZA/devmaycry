extends Node
## PALIMPSEST SPORT / FUTURE ARCHAEOLOGY palette and player glyphs.

const INK := Color("111513")
const CHARCOAL := Color("1A1C1A")
const PORCELAIN := Color("F1E8D8")
const IVORY := Color("E8E1D3")
const CHALK := Color("D9CFBA")
const VERMILION := Color("FF5B3D")
const MINT := Color("78C9AE")
const MINT_DARK := Color("4E8C78")
const COBALT := Color("586BC0")
const COBALT_DARK := Color("3E5B88")
const BRASS := Color("D9B34A")
const STONE := Color("B9B1A2")
const TERRACOTTA := Color("B5593A")
const INDIGO := Color("2E3A6B")

const TEAM_NAMES := {1: "COBALT", 2: "VERMILION"}
const GLYPHS := ["▲", "■", "●", "✚", "◆", "★", "⬢", "✦"]
const FFA_COLORS := [COBALT, VERMILION, MINT, BRASS, Color("C98BD9"), Color("E0E0E0"), Color("8FD35C"), Color("F0A050")]


func team_color(team: int) -> Color:
	match team:
		1:
			return COBALT
		2:
			return VERMILION
	return PORCELAIN


func team_name(team: int) -> String:
	return TEAM_NAMES.get(team, "SOLO")


func glyph(index: int) -> String:
	return GLYPHS[index % GLYPHS.size()]


func ffa_color(index: int) -> Color:
	return FFA_COLORS[index % FFA_COLORS.size()]


func player_color(info: Dictionary) -> Color:
	var team := int(info.get("team", 0))
	if team != 0:
		return team_color(team)
	return ffa_color(int(info.get("glyph", 0)))
