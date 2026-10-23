class_name Maps
extends RefCounted
## Registry of selectable arenas. The three presentation maps are authored layouts; the developer
## test arena is the original open plaza, kept for testing and marked as such in the selector.
## Legacy ids (legacy_tideline / legacy_foundry) remain loadable from the command line only.


static func list() -> Array:
	return [
		{"id": "oracle_gardens", "name": "ORACLE GARDENS", "mechanic": "PHASE GATES", "blurb": "Temples, terraces and a sunken basin around a fractured sanctuary.", "test": false},
		{"id": "tideline_exchange", "name": "TIDELINE EXCHANGE", "mechanic": "ZIPLINES + LADDERS", "blurb": "Covered cargo exchange over the sea: catwalks, loading channels and cable crossings.", "test": false},
		{"id": "vector_foundry", "name": "VECTOR FOUNDRY", "mechanic": "LAUNCH PADS + PORTALS", "blurb": "Looping kinetic facility around a reactor, with a watchtower and a service tunnel.", "test": false},
		{"id": "dev_test_arena", "name": "DEVELOPER TEST ARENA (TEST MAP)", "mechanic": "PHASE GATES", "blurb": "Original open plaza kept for testing. Not a presentation map.", "test": true},
	]


static func make(id: String) -> MapDef:
	var paths := {
		"oracle_gardens": "res://src/maps/OracleSanctuary.gd",
		"tideline_exchange": "res://src/maps/TidelineHall.gd",
		"vector_foundry": "res://src/maps/FoundryLoop.gd",
		"dev_test_arena": "res://src/maps/OracleGardens.gd",
		"legacy_tideline": "res://src/maps/TidelineExchange.gd",
		"legacy_foundry": "res://src/maps/VectorFoundry.gd",
	}
	var path: String = paths.get(id, "res://src/maps/OracleSanctuary.gd")
	if not ResourceLoader.exists(path):
		path = "res://src/maps/OracleGardens.gd"
	return load(path).new()


static func info(id: String) -> Dictionary:
	for m in list():
		if m["id"] == id:
			return m
	return {"id": id, "name": id.to_upper(), "mechanic": "", "blurb": "", "test": true}
