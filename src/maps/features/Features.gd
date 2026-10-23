class_name Features
extends RefCounted
## Signature traversal features. All gameplay effects run on the server and reach clients through
## the normal snapshot / teleport / fx replication. Visual parts exist on every peer.


static func glow_mat(color: Color, energy: float = 2.5, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func label(text: String, pos: Vector3, color: Color, size: int = 60) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	l.font_size = size
	l.pixel_size = 0.008
	l.outline_size = 10
	l.modulate = color
	return l


static func players_in(area: Area3D) -> Array:
	var out := []
	for b in area.get_overlapping_bodies():
		if b is Player and b.alive and not b.frozen:
			out.append(b)
	return out


## PHASE GATE: paired portals. Standing inside the ring for the activation time teleports you to the
## paired exit facing outward. Per-player re-entry lockout prevents bounce loops.
class PhaseGate extends Area3D:
	const ACTIVATION := 0.45
	const CORE_ACTIVATION := 0.9
	const LOCKOUT := 2.5
	var exit_pos := Vector3.ZERO
	var exit_yaw := 0.0
	var gate_name := ""
	var progress: Dictionary = {}
	var lockout: Dictionary = {}
	var ring: MeshInstance3D

	func setup(pos: Vector3, yaw_deg: float, exit: Vector3, exit_yaw_deg: float, gname: String) -> void:
		position = pos
		rotation.y = deg_to_rad(yaw_deg)
		exit_pos = exit
		exit_yaw = deg_to_rad(exit_yaw_deg)
		gate_name = gname
		collision_layer = 16
		collision_mask = 2
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 1.4
		sh.height = 3.2
		cs.shape = sh
		cs.position = Vector3(0, 1.6, 0)
		add_child(cs)
		ring = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.55
		tm.outer_radius = 1.8
		tm.rings = 48
		ring.mesh = tm
		ring.rotation_degrees = Vector3(90, 0, 0)
		ring.position = Vector3(0, 1.9, 0)
		ring.material_override = Features.glow_mat(Palette.MINT, 2.5)
		add_child(ring)
		var surface := MeshInstance3D.new()
		var surf_mesh := PlaneMesh.new()
		surf_mesh.size = Vector2(3.2, 3.2)
		surface.mesh = surf_mesh
		surface.rotation_degrees = Vector3(90, 0, 0)
		surface.position = Vector3(0, 1.9, 0)
		var psm := ShaderMaterial.new()
		psm.shader = load("res://src/shaders/portal_ring.gdshader")
		surface.material_override = psm
		add_child(surface)
		var frame := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(4.4, 0.4, 0.6)
		frame.mesh = bm
		frame.position = Vector3(0, 4.0, 0)
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Palette.STONE
		frame.material_override = fm
		add_child(frame)
		for sx in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.5, 4.2, 0.6)
			post.mesh = pm
			post.position = Vector3(sx * 1.95, 2.1, 0)
			post.material_override = fm
			add_child(post)
		var floor_mark := MeshInstance3D.new()
		var pl := PlaneMesh.new()
		pl.size = Vector2(3.4, 3.4)
		floor_mark.mesh = pl
		floor_mark.position = Vector3(0, 0.03, 0)
		floor_mark.material_override = Features.glow_mat(Palette.MINT, 1.2, 0.35)
		add_child(floor_mark)
		add_child(Features.label("PHASE GATE %s" % gname, Vector3(0, 5.0, 0), Palette.MINT, 56))

	func _physics_process(delta: float) -> void:
		ring.rotation.z += delta * 0.6
		if not multiplayer.is_server():
			return
		for id in lockout.keys():
			lockout[id] -= delta
			if lockout[id] <= 0.0:
				lockout.erase(id)
		var inside := {}
		for p in Features.players_in(self):
			inside[p.id] = true
			if lockout.has(p.id) or p.zip_t > 0.0:
				continue
			progress[p.id] = float(progress.get(p.id, 0.0)) + delta
			var need := CORE_ACTIVATION if p.carrying_core else ACTIVATION
			if progress[p.id] >= need:
				progress.erase(p.id)
				lockout[p.id] = LOCKOUT
				Game.rpc_fx.rpc("teleport", p.id, p.global_position)
				Game.rpc_teleport.rpc(p.id, exit_pos, exit_yaw)
				Game.log_ev("Feature", "gate", {"id": p.id, "gate": gate_name})
		for id in progress.keys():
			if not inside.has(id):
				progress.erase(id)


## ZIPLINE: press E at an anchor to ride the cable to the other anchor. Server moves the rider;
## riders cannot shoot or plant. Death, round reset or disconnect drops the rider cleanly.
class Zipline extends Node3D:
	const SPEED := 14.0
	const LOCKOUT := 1.5
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var zip_name := ""
	var anchors: Array = []
	var riders: Dictionary = {}
	var lockout: Dictionary = {}

	func setup(from: Vector3, to: Vector3, zname: String) -> void:
		a = from
		b = to
		zip_name = zname
		var cable := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 0.05
		cm.height = from.distance_to(to)
		cable.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Palette.BRASS
		mat.metallic = 0.8
		mat.roughness = 0.3
		cable.material_override = mat
		add_child(cable)
		var mid := (from + to) * 0.5 + Vector3(0, 2.2, 0)
		cable.position = mid
		var dir := (to - from).normalized()
		cable.look_at_from_position(mid, mid + dir, Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT)
		cable.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		for end in [from, to]:
			var ar := Area3D.new()
			ar.collision_layer = 16
			ar.collision_mask = 2
			ar.position = end
			var cs := CollisionShape3D.new()
			var sh := CylinderShape3D.new()
			sh.radius = 1.8
			sh.height = 3.0
			cs.shape = sh
			cs.position = Vector3(0, 1.5, 0)
			ar.add_child(cs)
			var post := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 0.18
			pm.bottom_radius = 0.22
			pm.height = 3.0
			post.mesh = pm
			post.position = Vector3(0, 1.5, 0)
			post.material_override = mat
			ar.add_child(post)
			var top := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.35
			sm.height = 0.7
			top.mesh = sm
			top.position = Vector3(0, 3.0, 0)
			top.material_override = Features.glow_mat(Palette.VERMILION, 2.0)
			ar.add_child(top)
			var mark := MeshInstance3D.new()
			var pl := PlaneMesh.new()
			pl.size = Vector2(3.6, 3.6)
			mark.mesh = pl
			mark.position = Vector3(0, 0.03, 0)
			mark.material_override = Features.glow_mat(Palette.BRASS, 1.0, 0.3)
			ar.add_child(mark)
			ar.add_child(Features.label("ZIPLINE %s / HOLD E" % zname, Vector3(0, 4.2, 0), Palette.BRASS, 52))
			add_child(ar)
			anchors.append(ar)

	func _physics_process(delta: float) -> void:
		if not multiplayer.is_server():
			return
		for id in lockout.keys():
			lockout[id] -= delta
			if lockout[id] <= 0.0:
				lockout.erase(id)
		for i in anchors.size():
			for p in Features.players_in(anchors[i]):
				if riders.has(p.id) or lockout.has(p.id) or not p.interact_held or p.zip_t > 0.0:
					continue
				var start: Vector3 = a if i == 0 else b
				var goal: Vector3 = b if i == 0 else a
				var dur := start.distance_to(goal) / SPEED
				riders[p.id] = {"t": 0.0, "dur": dur, "from": start, "to": goal}
				p.zip_t = dur + 0.05
				p.velocity = Vector3.ZERO
				p.carrying_core = p.carrying_core
				Game.rpc_fx.rpc("zip", p.id, p.global_position)
				Game.log_ev("Feature", "zip_attach", {"id": p.id, "zip": zip_name, "dur": snappedf(dur, 0.1)})
		for id in riders.keys():
			var r: Dictionary = riders[id]
			var p = Game.players.get(id)
			if p == null or not is_instance_valid(p) or not p.alive or p.frozen:
				riders.erase(id)
				if p != null and is_instance_valid(p):
					p.zip_t = 0.0
				continue
			r["t"] += delta
			var k: float = clampf(r["t"] / r["dur"], 0.0, 1.0)
			var pos: Vector3 = r["from"].lerp(r["to"], k) + Vector3(0, 0.3, 0)
			p.global_position = pos
			var dir: Vector3 = (r["to"] - r["from"]).normalized()
			p.yaw = atan2(-dir.x, -dir.z)
			if k >= 1.0:
				riders.erase(id)
				p.zip_t = 0.0
				p.velocity = dir * 4.0
				lockout[id] = LOCKOUT
				Game.log_ev("Feature", "zip_detach", {"id": id, "zip": zip_name})

	func drop_all() -> void:
		for id in riders.keys():
			var p = Game.players.get(id)
			if p != null and is_instance_valid(p):
				p.zip_t = 0.0
		riders.clear()


## VECTOR SLING: step on the pad to be launched along a fixed ballistic arc to the landing marker.
class VectorSling extends Area3D:
	const COOLDOWN := 1.2
	const LOCKOUT := 2.0
	var target := Vector3.ZERO
	var flight := 1.6
	var sling_name := ""
	var cooldown := 0.0
	var lockout: Dictionary = {}
	var arrow: MeshInstance3D

	func setup(pos: Vector3, land: Vector3, flight_time: float, sname: String) -> void:
		position = pos
		target = land
		flight = flight_time
		sling_name = sname
		collision_layer = 16
		collision_mask = 2
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 1.6
		sh.height = 2.0
		cs.shape = sh
		cs.position = Vector3(0, 1.0, 0)
		add_child(cs)
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.7
		cm.bottom_radius = 1.9
		cm.height = 0.12
		disc.mesh = cm
		disc.position = Vector3(0, 0.06, 0)
		disc.material_override = Features.glow_mat(Palette.VERMILION, 1.6)
		add_child(disc)
		arrow = MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(1.2, 0.3, 1.6)
		arrow.mesh = pm
		arrow.position = Vector3(0, 0.3, 0)
		var flat := Vector3(land.x - pos.x, 0, land.z - pos.z)
		if flat.length() > 0.01:
			arrow.rotation.y = atan2(-flat.x, -flat.z)
		arrow.material_override = Features.glow_mat(Palette.PORCELAIN, 2.0)
		add_child(arrow)
		add_child(Features.label("VECTOR SLING %s" % sname, Vector3(0, 3.0, 0), Palette.VERMILION, 52))
		var marker := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.6
		tm.outer_radius = 1.9
		marker.mesh = tm
		marker.position = land - pos + Vector3(0, 0.1, 0)
		marker.material_override = Features.glow_mat(Palette.VERMILION, 2.0, 0.8)
		add_child(marker)
		add_child(Features.label("LANDING %s" % sname, land - pos + Vector3(0, 2.0, 0), Palette.VERMILION, 40))
		# mechanism: steel housing ring, four charge coils with signal bands, and a faint dotted
		# trajectory arc computed from the same flight time and gravity the launch uses
		var steel := Style.surface("metal", Color("4A505A"))
		var housing := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 2.15
		hm.bottom_radius = 2.35
		hm.height = 0.22
		hm.radial_segments = 8
		housing.mesh = hm
		housing.position = Vector3(0, 0.11, 0)
		housing.material_override = steel
		add_child(housing)
		for k in 4:
			var a := k * TAU / 4.0 + PI * 0.25
			var coil := MeshInstance3D.new()
			var cc := CylinderMesh.new()
			cc.top_radius = 0.16
			cc.bottom_radius = 0.2
			cc.height = 1.1
			coil.mesh = cc
			coil.position = Vector3(cos(a) * 2.1, 0.55, sin(a) * 2.1)
			coil.material_override = steel
			add_child(coil)
			for b in 3:
				var band := MeshInstance3D.new()
				var bt := TorusMesh.new()
				bt.inner_radius = 0.17
				bt.outer_radius = 0.24
				band.mesh = bt
				band.position = coil.position + Vector3(0, -0.3 + b * 0.3, 0)
				band.material_override = Features.glow_mat(Color("E2683A"), 1.4)
				add_child(band)
		var rel := land - pos
		var t := maxf(flight_time, 0.3)
		var vy := (rel.y + 0.5 * 18.0 * t * t) / t
		var dot_mat := Features.glow_mat(Palette.VERMILION, 1.2, 0.45)
		for i in range(1, 12):
			var f := float(i) / 12.0
			var tt := f * t
			var d := MeshInstance3D.new()
			var sp := SphereMesh.new()
			sp.radius = 0.09
			sp.height = 0.18
			sp.radial_segments = 8
			sp.rings = 4
			d.mesh = sp
			d.position = Vector3(rel.x * f, vy * tt - 0.5 * 18.0 * tt * tt + 0.6, rel.z * f)
			d.material_override = dot_mat
			d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(d)

	func _physics_process(delta: float) -> void:
		arrow.position.y = 0.3 + 0.1 * sin(Time.get_ticks_msec() / 250.0)
		if not multiplayer.is_server():
			return
		cooldown = maxf(0.0, cooldown - delta)
		for id in lockout.keys():
			lockout[id] -= delta
			if lockout[id] <= 0.0:
				lockout.erase(id)
		if cooldown > 0.0:
			return
		for p in Features.players_in(self):
			if lockout.has(p.id) or p.zip_t > 0.0 or not p.is_on_floor():
				continue
			p.global_position = Vector3(global_position.x, p.global_position.y, global_position.z)
			var d: Vector3 = target - p.global_position
			var g: float = Player.GRAVITY
			var v := Vector3(d.x / flight, (d.y + 0.5 * g * flight * flight) / flight, d.z / flight)
			p.velocity = v
			p.launch_t = flight + 0.3
			p.global_position.y += 0.15
			p.inp_move = Vector2.ZERO
			lockout[p.id] = LOCKOUT
			cooldown = COOLDOWN
			Game.rpc_fx.rpc("sling", p.id, p.global_position)
			Game.log_ev("Feature", "sling", {"id": p.id, "sling": sling_name})



## LADDER: climbable strip on a wall face. Players inside the volume climb by moving toward the wall
## (forward), descend by moving away, and jump off with jump. Server-authoritative: the area only
## flags the player (ladder_t / ladder_out / ladder_top); Player.server_step does the movement.
class Ladder extends Area3D:
	var out := Vector3.FORWARD
	var top_y := 4.0
	var base := Vector3.ZERO

	func setup(base_: Vector3, top_y_: float, out_: Vector3, lname: String) -> void:
		base = base_
		top_y = top_y_
		out = out_
		position = base_
		collision_layer = 16
		collision_mask = 2
		var h := top_y - base.y + 1.2
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.4, h, 1.3)
		cs.shape = bs
		cs.position = Vector3(0, h * 0.5, 0) + out * 0.45
		cs.rotation.y = atan2(out.x, out.z)
		add_child(cs)
		var steel := Style.surface("metal", Color("4A505A"))
		var hazard := Style.surface("ceramic", Color("D99A2B"))
		var side := Vector3(out.z, 0, -out.x)
		for sx in [-0.42, 0.42]:
			MapDecor.strut(self, side * sx + out * 0.12, side * sx + out * 0.12 + Vector3(0, top_y - base.y + 1.0, 0), 0.04, steel)
		var rungs := int((top_y - base.y) / 0.35)
		for i in rungs:
			var y := 0.3 + i * 0.35
			MapDecor.strut(self, side * -0.42 + out * 0.12 + Vector3(0, y, 0), side * 0.42 + out * 0.12 + Vector3(0, y, 0), 0.025, hazard if i % 4 == 0 else steel)
		add_child(Features.label("LADDER %s" % lname, Vector3(0, top_y - base.y + 1.6, 0) + out * 0.3, Palette.BRASS, 36))

	func _physics_process(_delta: float) -> void:
		if not multiplayer.is_server():
			return
		for p in Features.players_in(self):
			p.ladder_t = 0.15
			p.ladder_out = out
			p.ladder_top = top_y
