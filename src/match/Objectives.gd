extends Node
## Presentation of replicated objective state on every peer: the Resonance Core, site labels,
## planted-site pulse, Relic Rush shards and beacon. Reads Game.live / Game.state only.

var core_mesh: Node3D = null
var core_label: Label3D = null
var site_labels: Dictionary = {}
var site_rings: Dictionary = {}
var shard_nodes: Dictionary = {}
var beacon_ring: MeshInstance3D = null
var beacon_label: Label3D = null
var _bob := 0.0


func _process(delta: float) -> void:
	if Game.world == null or Game.map_def == null:
		return
	if core_mesh == null:
		_build()
	_bob += delta
	if Game.mode_id == "corebreak":
		_update_corebreak(delta)
	else:
		_update_relic(delta)


func _build() -> void:
	var holder: Node3D = Game.world.get_node("Objectives")
	core_mesh = Node3D.new()
	core_mesh.name = "Core"
	var inner := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	inner.mesh = sm
	var im := StandardMaterial3D.new()
	im.albedo_color = Palette.BRASS
	im.emission_enabled = true
	im.emission = Palette.VERMILION
	im.emission_energy_multiplier = 3.0
	inner.material_override = im
	core_mesh.add_child(inner)
	for i in 2:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.55 + i * 0.2
		tm.outer_radius = 0.62 + i * 0.2
		ring.mesh = tm
		ring.rotation_degrees = Vector3(60 + i * 50, 0, i * 40)
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Palette.PORCELAIN
		rm.emission_enabled = true
		rm.emission = Palette.MINT if i == 0 else Palette.VERMILION
		rm.emission_energy_multiplier = 2.0
		ring.material_override = rm
		core_mesh.add_child(ring)
	core_label = Label3D.new()
	core_label.text = "RESONANCE CORE"
	core_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	core_label.position = Vector3(0, 1.3, 0)
	core_label.font_size = 44
	core_label.pixel_size = 0.007
	core_label.outline_size = 10
	core_label.modulate = Palette.BRASS
	core_mesh.add_child(core_label)
	holder.add_child(core_mesh)
	core_mesh.visible = false
	for sid in Game.map_def.sites:
		var s: Dictionary = Game.map_def.sites[sid]
		var l := Label3D.new()
		l.text = "SITE %s" % sid
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = s["position"] + Vector3(0, 5.5, 0)
		l.font_size = 96
		l.pixel_size = 0.01
		l.outline_size = 14
		l.modulate = Palette.VERMILION if sid == "A" else Palette.COBALT
		holder.add_child(l)
		site_labels[sid] = l
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = s["radius"] - 0.6
		tm.outer_radius = s["radius"] - 0.2
		tm.rings = 48
		ring.mesh = tm
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Palette.VERMILION
		rm.emission_enabled = true
		rm.emission = Palette.VERMILION
		rm.emission_energy_multiplier = 4.0
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = rm
		ring.position = s["position"] + Vector3(0, 0.45, 0)
		ring.visible = false
		holder.add_child(ring)
		site_rings[sid] = ring
	if Game.mode_id == "corebreak":
		for sid in site_labels:
			site_labels[sid].visible = true
	else:
		for sid in site_labels:
			site_labels[sid].visible = false
		beacon_ring = MeshInstance3D.new()
		var btm := TorusMesh.new()
		btm.inner_radius = 5.2
		btm.outer_radius = 5.8
		btm.rings = 48
		beacon_ring.mesh = btm
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Palette.BRASS
		bm.emission_enabled = true
		bm.emission = Palette.BRASS
		bm.emission_energy_multiplier = 3.0
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		beacon_ring.material_override = bm
		holder.add_child(beacon_ring)
		beacon_label = Label3D.new()
		beacon_label.text = "RELAY BEACON"
		beacon_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		beacon_label.font_size = 90
		beacon_label.pixel_size = 0.01
		beacon_label.outline_size = 14
		beacon_label.modulate = Palette.BRASS
		holder.add_child(beacon_label)


func _update_corebreak(delta: float) -> void:
	var core: Dictionary = Game.live.get("core", {})
	var mode := str(core.get("mode", "none"))
	core_mesh.rotate_y(delta * 1.2)
	match mode:
		"carried":
			var c = Game.players.get(int(core.get("carrier", 0)))
			if c != null and is_instance_valid(c):
				core_mesh.visible = not (c.is_local() and c.alive)
				core_mesh.global_position = c.global_position + Vector3(0, 2.7, 0)
				core_label.text = "CORE / %s" % c.pname
			else:
				core_mesh.visible = false
		"spawned", "dropped":
			core_mesh.visible = true
			var p: Vector3 = core.get("pos", Vector3.ZERO)
			core_mesh.global_position = p + Vector3(0, 1.0 + sin(_bob * 2.0) * 0.15, 0)
			core_label.text = "RESONANCE CORE / PICK UP"
		"planted":
			core_mesh.visible = true
			var p: Vector3 = core.get("pos", Vector3.ZERO)
			var det := float(core.get("detonate", 0.0))
			var pulse := 1.0 + 0.15 * sin(_bob * (4.0 + (35.0 - det) * 0.3))
			core_mesh.global_position = p + Vector3(0, 1.1, 0)
			core_mesh.scale = Vector3.ONE * pulse
			core_label.text = "PLANTED / %02d" % int(ceil(det))
		_:
			core_mesh.visible = false
	var site := str(core.get("site", ""))
	for sid in site_rings:
		var r: MeshInstance3D = site_rings[sid]
		r.visible = mode == "planted" and sid == site
		if r.visible:
			r.scale = Vector3.ONE * (1.0 + 0.05 * sin(_bob * 6.0))
		site_labels[sid].text = "SITE %s%s" % [sid, " / PLANTED" if r.visible else ""]


func _update_relic(_delta: float) -> void:
	var holder: Node3D = Game.world.get_node("Objectives")
	var shards: Dictionary = Game.live.get("shards", {})
	for key in shards:
		var k := str(key)
		if not shard_nodes.has(k):
			var n := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.6, 0.9, 0.6)
			n.mesh = pm
			var mm := StandardMaterial3D.new()
			mm.albedo_color = Palette.MINT
			mm.emission_enabled = true
			mm.emission = Palette.MINT
			mm.emission_energy_multiplier = 3.0
			n.material_override = mm
			holder.add_child(n)
			var lbl := Label3D.new()
			lbl.text = "MEMORY SHARD"
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.position = Vector3(0, 1.2, 0)
			lbl.font_size = 36
			lbl.pixel_size = 0.007
			lbl.outline_size = 8
			lbl.modulate = Palette.MINT
			n.add_child(lbl)
			shard_nodes[k] = n
		var entry: Dictionary = shards[key]
		var node: MeshInstance3D = shard_nodes[k]
		node.visible = bool(entry.get("active", false))
		var p: Vector3 = entry.get("pos", Vector3.ZERO)
		node.global_position = p + Vector3(0, 1.0 + sin(_bob * 2.0) * 0.15, 0)
		node.rotate_y(0.03)
	var beacon: Dictionary = Game.live.get("beacon", {})
	if beacon_ring != null and not beacon.is_empty():
		var bp: Vector3 = beacon.get("pos", Vector3.ZERO)
		beacon_ring.visible = true
		beacon_ring.global_position = bp + Vector3(0, 0.5, 0)
		beacon_label.global_position = bp + Vector3(0, 5.0, 0)
		var contested := bool(beacon.get("contested", false))
		var owner := str(beacon.get("owner_name", ""))
		var mat: StandardMaterial3D = beacon_ring.material_override
		var col := Palette.VERMILION if contested else (Palette.MINT if owner != "" else Palette.BRASS)
		mat.albedo_color = col
		mat.emission = col
		beacon_label.modulate = col
		beacon_label.text = "BEACON / CONTESTED" if contested else ("BEACON / %s" % owner if owner != "" else "RELAY BEACON / OPEN")
		beacon_ring.scale = Vector3.ONE * (1.0 + 0.06 * sin(_bob * 5.0))
