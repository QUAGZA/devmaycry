class_name Maps
extends RefCounted
## Registry of selectable arenas.


static func list() -> Array:
	return [
		{"id": "oracle_gardens", "name": "ORACLE GARDENS", "mechanic": "PHASE GATES", "blurb": "Three lanes around a monumental plaza. Paired gates fold the flanks together."},
		{"id": "tideline_exchange", "name": "TIDELINE EXCHANGE", "mechanic": "ZIPLINES", "blurb": "Suspended maritime archive with a high route, a low route and cable crossings."},
		{"id": "vector_foundry", "name": "VECTOR FOUNDRY", "mechanic": "VECTOR SLINGS", "blurb": "Kinetic sculpture hall. Launch pads throw you along fixed arcs to offset platforms."},
	]


static func make(id: String) -> MapDef:
	match id:
		"tideline_exchange":
			if ResourceLoader.exists("res://src/maps/TidelineExchange.gd"):
				return load("res://src/maps/TidelineExchange.gd").new()
		"vector_foundry":
			if ResourceLoader.exists("res://src/maps/VectorFoundry.gd"):
				return load("res://src/maps/VectorFoundry.gd").new()
	return OracleGardens.new()


static func info(id: String) -> Dictionary:
	for m in list():
		if m["id"] == id:
			return m
	return list()[0]
