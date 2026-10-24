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


## ---------------------------------------------------------------- shared clearance helpers (zipline, gates)
const CAPSULE_R := 0.4
const CAPSULE_H := 1.8
static var _cap_shape: CapsuleShape3D = null


static func capsule() -> CapsuleShape3D:
	if _cap_shape == null:
		_cap_shape = CapsuleShape3D.new()
		_cap_shape.radius = CAPSULE_R
		_cap_shape.height = CAPSULE_H
	return _cap_shape


## True if the player capsule standing at `feet` would overlap static world geometry (collision layer 1).
static func blocked(world: World3D, feet: Vector3, lift: float = 0.06) -> bool:
	if world == null:
		return false
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = capsule()
	q.transform = Transform3D(Basis.IDENTITY, feet + Vector3(0, CAPSULE_H * 0.5 + lift, 0))
	q.collision_mask = 1
	q.margin = 0.0
	return not world.direct_space_state.intersect_shape(q, 1).is_empty()


## Nearest standing spot to `pos` with room for the whole capsule and floor underneath (a few candidates around it).
## Returns {"ok": bool, "pos": Vector3, "moved": float}.
static func safe_spot(world: World3D, pos: Vector3, forward: Vector3 = Vector3.FORWARD) -> Dictionary:
	var fwd := Vector3(forward.x, 0, forward.z).normalized() if Vector2(forward.x, forward.z).length() > 0.01 else Vector3.FORWARD
	var side := Vector3(-fwd.z, 0, fwd.x)
	var offsets: Array = [Vector3.ZERO, fwd * 0.6, -fwd * 0.6, side * 0.7, -side * 0.7, fwd * 1.2, -fwd * 1.2, side * 1.4, -side * 1.4,
		fwd * 0.8 + side * 0.8, fwd * 0.8 - side * 0.8, -fwd * 0.8 + side * 0.8, -fwd * 0.8 - side * 0.8, fwd * 2.0, -fwd * 2.0]
	var space := world.direct_space_state
	for o in offsets:
		for up in [0.0, 0.3, 0.6]:
			var cand: Vector3 = pos + (o as Vector3) + Vector3(0, up, 0)
			var ray := PhysicsRayQueryParameters3D.create(cand + Vector3(0, 0.7, 0), cand + Vector3(0, -1.6, 0), 1)
			var hit := space.intersect_ray(ray)
			if hit.is_empty():
				continue
			var feet: Vector3 = hit["position"]
			if not blocked(world, feet):
				return {"ok": true, "pos": feet, "moved": feet.distance_to(pos)}
	return {"ok": false, "pos": pos, "moved": 0.0}


## Hint shown to the local player while within `radius` (horizontal) of `at`.
static func near_local(at: Vector3, radius: float, height: float = 3.0) -> bool:
	var lp = Game.local_player
	if lp == null or not is_instance_valid(lp) or not lp.alive:
		return false
	var d := Vector2(lp.global_position.x - at.x, lp.global_position.z - at.z).length()
	return d <= radius and absf(lp.global_position.y - at.y) <= height


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
	const LOCKOUT := 2.5
	var exit_pos := Vector3.ZERO
	var exit_yaw := 0.0
	var gate_name := ""
	var progress: Dictionary = {}
	var lockout: Dictionary = {}
	var refused: Dictionary = {}       # carriers told the gate will not take the Core (message throttle)
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

	func validate() -> Dictionary:
		var fwd := Basis(Vector3.UP, exit_yaw) * Vector3.FORWARD
		var spot := Features.safe_spot(get_world_3d(), exit_pos, fwd)
		var here_blocked := Features.blocked(get_world_3d(), global_position)
		return {"kind": "gate", "name": gate_name, "pos": [snappedf(global_position.x, 0.1), snappedf(global_position.y, 0.1), snappedf(global_position.z, 0.1)],
			"ok": bool(spot["ok"]) and not here_blocked, "exit_ok": bool(spot["ok"]), "exit_moved": snappedf(float(spot["moved"]), 0.01), "entry_blocked": here_blocked}

	func _process(_delta: float) -> void:
		if Features.near_local(global_position, 3.4):
			var lp = Game.local_player
			if lp.carrying_core:
				Game.set_prompt("PHASE GATES REFUSE THE CAUSAL CORE")
			else:
				Game.set_prompt("STAND IN THE GATE TO PHASE")

	func _physics_process(delta: float) -> void:
		ring.rotation.z += delta * 0.6
		if not multiplayer.is_server():
			return
		for id in lockout.keys():
			lockout[id] -= delta
			if lockout[id] <= 0.0:
				lockout.erase(id)
		for id in refused.keys():
			refused[id] -= delta
			if refused[id] <= 0.0:
				refused.erase(id)
		var inside := {}
		for p in Features.players_in(self):
			inside[p.id] = true
			if lockout.has(p.id) or p.zip_t > 0.0:
				continue
			if p.carrying_core:
				# the carry routes (and the 26 s fuse) are tuned around walking: a gate would skip them
				if not refused.has(p.id):
					refused[p.id] = 2.5
					Game.log_ev("Feature", "gate_refused_core", {"id": p.id, "gate": gate_name})
					if p.id > 0:
						Game.rpc_notice.rpc_id(p.id, "PHASE GATES REFUSE THE CAUSAL CORE", 1.6)
				progress.erase(p.id)
				continue
			progress[p.id] = float(progress.get(p.id, 0.0)) + delta
			var need := ACTIVATION
			if progress[p.id] >= need:
				progress.erase(p.id)
				# the exit must have room for the whole capsule: nudge to the nearest clear standing spot or stay put
				var fwd := Basis(Vector3.UP, exit_yaw) * Vector3.FORWARD
				var spot := Features.safe_spot(get_world_3d(), exit_pos, fwd)
				if not bool(spot["ok"]):
					lockout[p.id] = LOCKOUT
					Game.log_ev("Feature", "gate_exit_blocked", {"id": p.id, "gate": gate_name})
					if p.id > 0:
						Game.rpc_notice.rpc_id(p.id, "GATE EXIT BLOCKED", 1.4)
					continue
				lockout[p.id] = LOCKOUT
				Game.rpc_fx.rpc("teleport", p.id, p.global_position)
				Game.rpc_teleport.rpc(p.id, spot["pos"], exit_yaw)
				Game.log_ev("Feature", "gate", {"id": p.id, "gate": gate_name, "moved": snappedf(float(spot["moved"]), 0.01)})
		for id in progress.keys():
			if not inside.has(id):
				progress.erase(id)


## ZIPLINE: press E at an anchor to ride the cable to the other anchor. Server moves the rider;
## riders cannot shoot or plant. Death, round reset or disconnect drops the rider cleanly.
class Zipline extends Node3D:
	const SPEED := 14.0
	const LOCKOUT := 1.5
	const ATTACH_TIME := 0.2
	const RIDE_LIFT := 0.3
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var zip_name := ""
	var anchors: Array = []
	var riders: Dictionary = {}
	var lockout: Dictionary = {}
	var refused: Dictionary = {}
	var disabled_reason := ""

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
			sh.radius = 2.2
			sh.height = 3.4
			cs.shape = sh
			cs.position = Vector3(0, 1.7, 0)
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

	## Sweep the player capsule along the whole cable (and check both anchors) against static geometry.
	func validate() -> Dictionary:
		var w := get_world_3d()
		var length := a.distance_to(b)
		var steps := maxi(2, int(ceil(length / 0.4)))
		var first_hit := -1.0
		for i in steps + 1:
			var k := float(i) / float(steps)
			var feet := a.lerp(b, k) + Vector3(0, RIDE_LIFT, 0)
			if Features.blocked(w, feet, 0.08):
				first_hit = k * length
				break
		var start_ok := not Features.blocked(w, a + Vector3(0, 0.05, 0))
		var end_spot := Features.safe_spot(w, b, (b - a).normalized())
		var ok := first_hit < 0.0 and start_ok and bool(end_spot["ok"])
		return {"kind": "zip", "name": zip_name, "length": snappedf(length, 0.1), "ok": ok, "blocked_at_m": snappedf(first_hit, 0.1) if first_hit >= 0.0 else -1.0,
			"start_ok": start_ok, "end_ok": bool(end_spot["ok"]), "end_moved": snappedf(float(end_spot["moved"]), 0.01)}

	func _ready() -> void:
		# validated once the physics bodies of the map exist; an unsafe cable is switched off instead of ridden
		if multiplayer.is_server():
			await get_tree().physics_frame
			await get_tree().physics_frame
			var r := validate()
			Game.log_ev("Feature", "zip_validated", r)
			if not bool(r["ok"]):
				disabled_reason = "BLOCKED"
				push_warning("Zipline %s is obstructed and has been disabled: %s" % [zip_name, str(r)])

	func _process(_delta: float) -> void:
		for ar in anchors:
			if Features.near_local((ar as Area3D).global_position, 2.6):
				var lp = Game.local_player
				if disabled_reason != "":
					Game.set_prompt("ZIPLINE OFFLINE")
				elif lp.carrying_core:
					Game.set_prompt("THE CAUSAL CORE CANNOT RIDE A ZIPLINE")
				else:
					Game.set_prompt("HOLD E  /  RIDE THE ZIPLINE")

	func _physics_process(delta: float) -> void:
		if not multiplayer.is_server():
			return
		for id in lockout.keys():
			lockout[id] -= delta
			if lockout[id] <= 0.0:
				lockout.erase(id)
		for id in refused.keys():
			refused[id] -= delta
			if refused[id] <= 0.0:
				refused.erase(id)
		for i in anchors.size():
			for p in Features.players_in(anchors[i]):
				if riders.has(p.id) or lockout.has(p.id) or not (p.interact_held or p.interact_buffer_t > 0.0) or p.zip_t > 0.0:
					continue
				if disabled_reason != "":
					continue
				if p.carrying_core:
					# cables are shortcuts over the carry route: the Core is too volatile to hang from one
					if not refused.has(p.id):
						refused[p.id] = 2.5
						Game.log_ev("Feature", "zip_refused_core", {"id": p.id, "zip": zip_name})
						if p.id > 0:
							Game.rpc_notice.rpc_id(p.id, "THE CAUSAL CORE CANNOT RIDE A ZIPLINE", 1.6)
					continue
				var start: Vector3 = a if i == 0 else b
				var goal: Vector3 = b if i == 0 else a
				var dur := start.distance_to(goal) / SPEED
				riders[p.id] = {"t": 0.0, "dur": dur, "from": start, "to": goal, "p0": p.global_position, "last": p.global_position}
				p.zip_t = dur + ATTACH_TIME + 0.05
				p.velocity = Vector3.ZERO
				p.interact_buffer_t = 0.0
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
			var from: Vector3 = r["from"]
			var to: Vector3 = r["to"]
			var line_start := from + Vector3(0, RIDE_LIFT, 0)
			var pos: Vector3
			var done := false
			if r["t"] < ATTACH_TIME:
				# short blend from wherever the rider stood onto the cable: no pop, no pull through walls
				pos = (r["p0"] as Vector3).lerp(line_start, clampf(r["t"] / ATTACH_TIME, 0.0, 1.0))
			else:
				var k: float = clampf((r["t"] - ATTACH_TIME) / r["dur"], 0.0, 1.0)
				pos = from.lerp(to, k) + Vector3(0, RIDE_LIFT, 0)
				done = k >= 1.0
			var dir: Vector3 = (to - from).normalized()
			if Features.blocked(get_world_3d(), pos, 0.08):
				# something solid is on the line (a prop moved, a bad route): stop at the last free point and drop
				var last: Vector3 = r["last"]
				var spot := Features.safe_spot(get_world_3d(), last, dir)
				p.global_position = spot["pos"] if bool(spot["ok"]) else last
				p.velocity = Vector3.ZERO
				p.zip_t = 0.0
				riders.erase(id)
				lockout[id] = LOCKOUT
				Game.log_ev("Feature", "zip_blocked", {"id": id, "zip": zip_name})
				continue
			r["last"] = pos
			p.global_position = pos
			p.yaw = atan2(-dir.x, -dir.z)
			if done:
				var spot2 := Features.safe_spot(get_world_3d(), to, dir)
				p.global_position = spot2["pos"] if bool(spot2["ok"]) else pos
				riders.erase(id)
				p.zip_t = 0.0
				p.velocity = dir * 3.0
				lockout[id] = LOCKOUT
				Game.log_ev("Feature", "zip_detach", {"id": id, "zip": zip_name, "moved": snappedf(float(spot2["moved"]), 0.01)})

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
	var refused: Dictionary = {}
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
		for id in refused.keys():
			refused[id] -= delta
			if refused[id] <= 0.0:
				refused.erase(id)
		if cooldown > 0.0:
			return
		for p in Features.players_in(self):
			if lockout.has(p.id) or p.zip_t > 0.0 or not p.is_on_floor():
				continue
			if p.carrying_core:
				# pads would turn the measured carry routes into a jump: the Core is too volatile to be launched
				if not refused.has(p.id):
					refused[p.id] = 2.5
					Game.log_ev("Feature", "sling_refused_core", {"id": p.id, "sling": sling_name})
					if p.id > 0:
						Game.rpc_notice.rpc_id(p.id, "LAUNCH PADS REFUSE THE CAUSAL CORE", 1.6)
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
			if p.ladder_ignore_t > 0.0:
				continue
			if p.ladder_t <= 0.0:
				Game.log_ev("Feature", "ladder_enter", {"id": p.id, "y": snappedf(p.global_position.y, 0.1), "top": top_y})
			p.ladder_t = 0.15
			p.ladder_out = out
			p.ladder_top = top_y
			p.ladder_base_y = base.y
