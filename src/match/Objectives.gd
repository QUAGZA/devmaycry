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
var hr_built := false
var cradle: Node3D = null
var stabilizer: Node3D = null
var field_nodes: Array = []
var ff_ring: MeshInstance3D = null
var core_mat: StandardMaterial3D = null


func _process(delta: float) -> void:
	if Game.world == null or Game.map_def == null:
		return
	if core_mesh == null:
		_build()
	_bob += delta
	if Game.mode_id == "corebreak":
		_update_corebreak(delta)
	elif Game.mode_id == "hot_return":
		_update_hotreturn(delta)
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
	core_mat = im
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


func _ring_mesh(radius: float, thickness: float, color: Color, energy: float = 2.5) -> MeshInstance3D:
	var r := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = maxf(0.05, radius - thickness)
	tm.outer_radius = radius
	tm.rings = 64
	r.mesh = tm
	r.material_override = Features.glow_mat(color, energy)
	return r


func _build_hotreturn() -> void:
	hr_built = true
	var holder: Node3D = Game.world.get_node("Objectives")
	for sid in site_labels:
		site_labels[sid].visible = false
	cradle = Node3D.new()
	cradle.name = "Cradle"
	var ped := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.3
	cm.bottom_radius = 1.6
	cm.height = 0.8
	ped.mesh = cm
	ped.position = Vector3(0, 0.4, 0)
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Palette.COBALT_DARK
	pm.metallic = 0.4
	pm.roughness = 0.4
	ped.material_override = pm
	cradle.add_child(ped)
	var cr := _ring_mesh(2.2, 0.25, Palette.COBALT, 2.0)
	cr.position = Vector3(0, 0.1, 0)
	cradle.add_child(cr)
	cradle.add_child(Features.label("VAULT / CAUSAL CORE", Vector3(0, 4.5, 0), Palette.COBALT, 70))
	holder.add_child(cradle)
	stabilizer = Node3D.new()
	stabilizer.name = "Stabilizer"
	var sr := _ring_mesh(3.2, 0.3, Palette.MINT, 2.5)
	sr.position = Vector3(0, 0.1, 0)
	stabilizer.add_child(sr)
	for k in 3:
		var ang := k * TAU / 3.0
		var pylon := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.4, 3.0, 0.4)
		pylon.mesh = bm
		pylon.position = Vector3(cos(ang) * 3.0, 1.5, sin(ang) * 3.0)
		pylon.material_override = Features.glow_mat(Palette.MINT, 1.2)
		stabilizer.add_child(pylon)
	stabilizer.add_child(Features.label("HOME STABILIZER", Vector3(0, 4.8, 0), Palette.MINT, 70))
	holder.add_child(stabilizer)
	for i in Game.map_def.fields.size():
		var f: Dictionary = Game.map_def.fields[i]
		var n := Node3D.new()
		n.position = f["position"]
		var rad := float(f.get("radius", 12.0))
		var ring := _ring_mesh(rad, 0.35, Palette.MINT, 1.6)
		ring.position = Vector3(0, 0.12, 0)
		n.add_child(ring)
		var inner := _ring_mesh(rad * 0.5, 0.15, Palette.PORCELAIN, 1.0)
		inner.position = Vector3(0, 0.1, 0)
		n.add_child(inner)
		var beam := MeshInstance3D.new()
		var bb := CylinderMesh.new()
		bb.top_radius = 0.15
		bb.bottom_radius = 0.3
		bb.height = 6.0
		beam.mesh = bb
		beam.position = Vector3(0, 3.0, 0)
		beam.material_override = Features.glow_mat(Palette.MINT, 1.5, 0.5)
		n.add_child(beam)
		var lbl := Features.label("STABILITY FIELD %s / 7.0 s" % ["A", "B"][i % 2], Vector3(0, 6.8, 0), Palette.MINT, 64)
		n.add_child(lbl)
		holder.add_child(n)
		field_nodes.append({"node": n, "ring": ring, "label": lbl, "beam": beam})
	ff_ring = _ring_mesh(8.0, 0.4, Palette.VERMILION, 3.0)
	ff_ring.visible = false
	holder.add_child(ff_ring)


func _update_hotreturn(delta: float) -> void:
	if not hr_built:
		_build_hotreturn()
	var live := Game.live
	var core: Dictionary = live.get("core", {})
	var mode := str(core.get("mode", "cradle"))
	var v := float(core.get("v", 0.0))
	var vault: Vector3 = live.get("vault", Vector3.ZERO)
	var stab: Vector3 = live.get("stabilizer", Vector3.ZERO)
	cradle.global_position = vault
	stabilizer.global_position = stab
	var k := clampf(v / 100.0, 0.0, 1.0)
	var col := Palette.MINT.lerp(Palette.BRASS, clampf(k * 2.0, 0.0, 1.0)) if k < 0.5 else Palette.BRASS.lerp(Palette.VERMILION, clampf((k - 0.5) * 2.0, 0.0, 1.0))
	var pulse := 1.0 + 0.08 * sin(_bob * (2.0 + 10.0 * k))
	core_mat.emission = col
	core_mat.emission_energy_multiplier = 2.0 + 4.0 * k
	core_mesh.scale = Vector3.ONE * pulse
	core_mesh.rotate_y(delta * (0.8 + 3.0 * k))
	match mode:
		"cradle":
			core_mesh.visible = true
			core_mesh.global_position = vault + Vector3(0, 1.6, 0)
			core_label.text = "CAUSAL CORE / CONTAINED"
		"carried":
			var c = Game.players.get(int(core.get("carrier", 0)))
			if c != null and is_instance_valid(c):
				core_mesh.visible = not (c.is_local() and c.alive)
				core_mesh.global_position = c.global_position + Vector3(0, 2.7, 0)
				core_label.text = "%s / %d%%" % [c.pname, int(v)]
			else:
				core_mesh.visible = false
		"dropped":
			core_mesh.visible = true
			core_mesh.global_position = Vector3(core.get("pos", Vector3.ZERO)) + Vector3(0, 1.0 + sin(_bob * 2.0) * 0.15, 0)
			core_label.text = "DROPPED / %d%% TICKING" % int(v)
		"locked":
			core_mesh.visible = true
			core_mesh.global_position = Vector3(core.get("pos", Vector3.ZERO)) + Vector3(0, 1.0, 0)
			core_mesh.scale = Vector3.ONE
			core_mat.emission = Palette.COBALT
			var ll := float(core.get("lock_left", 0.0))
			core_label.text = "TEMPORAL LOCK / %d%% FROZEN%s" % [int(v), (" / %0.1f" % ll) if ll > 0.0 else " / PICK UP"]
		"stabilized":
			core_mesh.visible = true
			core_mesh.global_position = stab + Vector3(0, 1.6, 0)
			core_mat.emission = Palette.MINT
			core_label.text = "STABILIZED"
		_:
			core_mesh.visible = false
	var fields: Array = live.get("fields", [])
	for i in mini(fields.size(), field_nodes.size()):
		var rem := float(fields[i].get("remaining", 0.0))
		var fn: Dictionary = field_nodes[i]
		fn["label"].text = "STABILITY FIELD %s / %0.1f s" % [["A", "B"][i % 2], rem]
		var fmat: StandardMaterial3D = fn["ring"].material_override
		var fcol := Palette.MINT if rem > 0.0 else Palette.STONE
		fmat.albedo_color = fcol
		fmat.emission = fcol
		fn["beam"].visible = rem > 0.0
	var ff: Dictionary = live.get("ff", {})
	if bool(ff.get("active", false)):
		ff_ring.visible = true
		ff_ring.global_position = Vector3(ff.get("pos", Vector3.ZERO)) + Vector3(0, 0.2, 0)
		ff_ring.scale = Vector3.ONE * (1.0 + 0.05 * sin(_bob * 12.0))
	else:
		ff_ring.visible = false


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
