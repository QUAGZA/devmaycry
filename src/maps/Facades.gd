class_name Facades
extends RefCounted
## Architectural trim for the plan-built maps, generated from the same data that built the collision: plinths,
## cornices, pilasters, window rows (some lit), hazard bands and pipe runs on every EXPOSED wall face of a building
## mass or room. Faces hidden by a neighbouring mass, faces on the map perimeter and doorways are skipped.
## Everything is visual only, stays within ~0.14 m of the wall below head height, and is drawn with a handful of
## MultiMeshes (a few draw calls, no shadows, no per-instance nodes).

const CELL := 1.0

var _grid_h: PackedFloat32Array
var _gw := 0
var _gh := 0
var _ox := 0.0
var _oz := 0.0
var _outline := PackedVector2Array()
var _kinds: Dictionary = {}          # kind -> {"mesh": Mesh, "xf": Array[Transform3D]}
var _rng := RandomNumberGenerator.new()
var _style: Dictionary
var _faces := 0


static func build(def: MapDef, ops: Array, extent: Vector2, mats: Dictionary, style: Dictionary) -> Dictionary:
	var f := Facades.new()
	return f._run(def, ops, extent, mats, style)


func _run(def: MapDef, ops: Array, extent: Vector2, mats: Dictionary, style: Dictionary) -> Dictionary:
	_style = style
	_rng.seed = int(style.get("seed", 5))
	_ox = -extent.x
	_oz = -extent.y
	_gw = int(ceil(extent.x * 2.0 / CELL))
	_gh = int(ceil(extent.y * 2.0 / CELL))
	_grid_h.resize(_gw * _gh)
	_grid_h.fill(0.0)
	var masses: Array = []                 # {r: [x0,z0,x1,z1], y0, h, doors: {}}
	for op in ops:
		var kind := str(op["op"])
		if kind == "outline":
			_outline = PlanRunner._poly(op["poly"])
		elif kind == "block":
			if float(op.get("y0", 0.0)) <= 0.5 and float(op["h"]) >= 4.0:
				masses.append({"r": op["r"], "y0": 0.0, "h": float(op["h"]), "doors": {}, "fill": bool(op.get("fill", false))})
		elif kind == "room":
			masses.append({"r": op["r"], "y0": float(op.get("floor", 0.0)), "h": float(op["h"]), "doors": op.get("doors", {}), "fill": false, "room": true})
	for m in masses:
		_raster(m["r"], float(m["y0"]) + float(m["h"]))
	for m in masses:
		_faces_of(m)
	var made := 0
	for key in _kinds:
		var entry: Dictionary = _kinds[key]
		var xf: Array = entry["xf"]
		if xf.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = entry["mesh"]
		mm.instance_count = xf.size()
		for i in xf.size():
			mm.set_instance_transform(i, xf[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Facade_" + str(key)
		mmi.multimesh = mm
		mmi.material_override = mats.get(str(key), mats.get("wall_a"))
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		def.features.add_child(mmi)
		made += xf.size()
	var cuts := clear_doorways(def, ops)
	return {"faces": _faces, "instances": made, "kinds": _kinds.size(), "doorway_cuts": cuts}


## Facades dresses every room face with a plinth, pilasters and trim bands that ignore the doorways: a pilaster
## stood in the middle of the hall and warehouse doors and a 0.6 m plinth strip lay across every threshold, none of
## it solid (so the doorway looked barred but could be walked through). Cut
## every box-shaped facade instance that overlaps a doorway opening: pilasters are dropped, long strips are split
## around the opening. Returns the number of instances removed or split.
static func clear_doorways(def: MapDef, ops: Array) -> int:
	var openings: Array = []     # [axis (0 = along x, 1 = along z), lo, hi, depth_lo, depth_hi, y0, y1]
	for op in ops:
		if str(op["op"]) != "room":
			continue
		var r: Array = op["r"]
		var x0 := float(r[0])
		var z0 := float(r[1])
		var x1 := float(r[2])
		var z1 := float(r[3])
		var t := float(op.get("t", 0.8))
		var fl := float(op.get("floor", 0.0))
		var doors: Dictionary = op.get("doors", {})
		for k in doors:
			for d in doors[k]:
				var off := float(d[0])
				var half := float(d[1]) * 0.5
				match k:
					"n":
						var c := (x0 + x1) * 0.5 + off
						openings.append([0, c - half, c + half, z0 - 0.6, z0 + t + 0.1, fl, fl + PlanRunner.DOOR_H])
					"s":
						var c2 := (x0 + x1) * 0.5 + off
						openings.append([0, c2 - half, c2 + half, z1 - t - 0.1, z1 + 0.6, fl, fl + PlanRunner.DOOR_H])
					"w":
						var c3 := (z0 + z1) * 0.5 + off
						openings.append([1, c3 - half, c3 + half, x0 - 0.6, x0 + t + 0.1, fl, fl + PlanRunner.DOOR_H])
					_:
						var c4 := (z0 + z1) * 0.5 + off
						openings.append([1, c4 - half, c4 + half, x1 - t - 0.1, x1 + 0.6, fl, fl + PlanRunner.DOOR_H])
	var changed := 0
	for node in def.features.get_children():
		if not (node is MultiMeshInstance3D):
			continue
		var kind := str(node.name).trim_prefix("Facade_")
		if not (kind in ["plinth", "trim", "band", "hazard", "glass", "glass_lit"]):
			continue
		var mm := (node as MultiMeshInstance3D).multimesh
		var keep: Array = []
		for i in mm.instance_count:
			var xf := mm.get_instance_transform(i)
			var pieces: Array = [xf]
			for o in openings:
				var next: Array = []
				for pxf in pieces:
					var px: Transform3D = pxf
					var bx := px.basis.x
					var bz := px.basis.z
					var by := px.basis.y
					var along_x := absf(bx.x) > absf(bx.z)
					# the facade box must run along the opening's wall
					if along_x != (int(o[0]) == 0):
						next.append(px)
						continue
					var depth_c := px.origin.z if along_x else px.origin.x
					var depth_half := (absf(bz.z) if along_x else absf(bz.x)) * 0.5
					var len_c := px.origin.x if along_x else px.origin.z
					var len_half := (absf(bx.x) if along_x else absf(bx.z)) * 0.5
					var y_half := by.length() * 0.5
					if depth_c + depth_half < float(o[3]) or depth_c - depth_half > float(o[4]) or px.origin.y - y_half >= float(o[6]) or px.origin.y + y_half <= float(o[5]):
						next.append(px)
						continue
					var lo := len_c - len_half
					var hi := len_c + len_half
					if hi <= float(o[1]) or lo >= float(o[2]):
						next.append(px)
						continue
					changed += 1
					if hi - lo > 1.0:      # a long strip: keep what lies outside the opening
						for seg in [[lo, minf(hi, float(o[1]))], [maxf(lo, float(o[2])), hi]]:
							if float(seg[1]) - float(seg[0]) > 0.05:
								var piece := px
								var centre: float = (float(seg[0]) + float(seg[1])) * 0.5
								var scale: float = (float(seg[1]) - float(seg[0])) / (hi - lo)
								piece.basis.x = bx * scale
								if along_x:
									piece.origin.x = centre
								else:
									piece.origin.z = centre
								next.append(piece)
					# pilasters, window frames and glass inside the opening are dropped
				pieces = next
			for pxf in pieces:
				keep.append(pxf)
		if keep.size() != mm.instance_count:
			mm.instance_count = keep.size()
			for i in keep.size():
				mm.set_instance_transform(i, keep[i])
	return changed


# ---------------------------------------------------------------- occupancy grid
func _cell(x: float, z: float) -> int:
	var ix := int(floor((x - _ox) / CELL))
	var iz := int(floor((z - _oz) / CELL))
	if ix < 0 or iz < 0 or ix >= _gw or iz >= _gh:
		return -1
	return iz * _gw + ix


func _raster(r: Array, top: float) -> void:
	var x0 := int(floor((float(r[0]) - _ox) / CELL + 0.5))
	var x1 := int(ceil((float(r[2]) - _ox) / CELL - 0.5))
	var z0 := int(floor((float(r[1]) - _oz) / CELL + 0.5))
	var z1 := int(ceil((float(r[3]) - _oz) / CELL - 0.5))
	for iz in range(maxi(z0, 0), mini(z1, _gh)):
		for ix in range(maxi(x0, 0), mini(x1, _gw)):
			var k := iz * _gw + ix
			_grid_h[k] = maxf(_grid_h[k], top)


## true if something at least `top` high stands at (x, z) (a neighbouring mass hides the face)
func _hidden(x: float, z: float, top: float) -> bool:
	var k := _cell(x, z)
	if k < 0:
		return true
	return _grid_h[k] >= top - 0.01


# ---------------------------------------------------------------- faces
func _faces_of(m: Dictionary) -> void:
	var r: Array = m["r"]
	var x0 := float(r[0])
	var z0 := float(r[1])
	var x1 := float(r[2])
	var z1 := float(r[3])
	var y0: float = m["y0"]
	var h: float = m["h"]
	var top := y0 + h
	# side name, start, end, outward normal (plan x, z)
	var sides := [
		["n", Vector2(x0, z0), Vector2(x1, z0), Vector2(0, -1)],
		["s", Vector2(x1, z1), Vector2(x0, z1), Vector2(0, 1)],
		["w", Vector2(x0, z1), Vector2(x0, z0), Vector2(-1, 0)],
		["e", Vector2(x1, z0), Vector2(x1, z1), Vector2(1, 0)],
	]
	for s in sides:
		var a: Vector2 = s[1]
		var b: Vector2 = s[2]
		var n: Vector2 = s[3]
		var length := a.distance_to(b)
		if length < 2.0:
			continue
		var u := (b - a) / length
		# door intervals on this side (distance along the face from its start); rooms measure from the side centre
		var door_spans: Array = []
		if m.has("room") and (m["doors"] as Dictionary).has(s[0]):
			var side_len := length
			for d in m["doors"][s[0]]:
				var c := side_len * 0.5 + float(d[0])
				door_spans.append([c - float(d[1]) * 0.5 - 0.4, c + float(d[1]) * 0.5 + 0.4])
			if s[0] == "s" or s[0] == "w":
				# these sides run opposite to the room's own measuring direction
				var flipped: Array = []
				for sp in door_spans:
					flipped.append([side_len - float(sp[1]), side_len - float(sp[0])])
				door_spans = flipped
		# exposed stretches: 1 m cells just outside the face that are open at this height and inside the outline
		var run_start := -1.0
		var cells := int(floor(length / CELL))
		var stretches: Array = []
		for i in cells + 1:
			var t := minf(float(i) * CELL + CELL * 0.5, length - 0.01)
			var p := a + u * t + n * 0.35
			var exposed := i < cells and not _hidden(p.x, p.y, top) and (_outline.is_empty() or Geometry2D.is_point_in_polygon(p + n * 0.9, _outline))
			if exposed and run_start < 0.0:
				run_start = float(i) * CELL
			elif not exposed and run_start >= 0.0:
				stretches.append([run_start, minf(float(i) * CELL, length)])
				run_start = -1.0
		for st in stretches:
			if float(st[1]) - float(st[0]) >= 2.0:
				_decorate(a + u * float(st[0]), u, n, float(st[1]) - float(st[0]), y0, h, door_spans, float(st[0]), bool(m.get("room", false)), bool(m.get("fill", false)))


func _decorate(origin: Vector2, u: Vector2, n: Vector2, length: float, y0: float, h: float, doors: Array, face_offset: float, is_room: bool, is_fill: bool) -> void:
	_faces += 1
	var up := Vector3.UP
	var uu := Vector3(u.x, 0, u.y)
	var nn := Vector3(n.x, 0, n.y)
	var base := Vector3(origin.x, y0, origin.y)
	# trim bands run the full stretch
	_box("plinth", base + uu * (length * 0.5) + nn * 0.07 + up * 0.3, uu, nn, Vector3(length, 0.6, 0.14))
	_box("trim", base + uu * (length * 0.5) + nn * 0.12 + up * (h - 0.16), uu, nn, Vector3(length + 0.04, 0.32, 0.26))
	if h >= 5.0:
		_box("band", base + uu * (length * 0.5) + nn * 0.05 + up * (h - 0.62), uu, nn, Vector3(length, 0.12, 0.1))
	if str(_style.get("hazard_band", "")) != "" and length >= 4.0 and _rng.randf() < float(_style.get("hazard_chance", 0.0)):
		_box("hazard", base + uu * (length * 0.5) + nn * 0.08 + up * 0.78, uu, nn, Vector3(length, 0.16, 0.1))
	# pilasters
	var piers := int(floor(length / float(_style.get("pier_gap", 5.5))))
	var pier_pos: Array = []
	for i in piers + 1:
		var tt := length * float(i) / float(maxi(piers, 1)) if piers > 0 else length * 0.5
		tt = clampf(tt, 0.3, length - 0.3)
		pier_pos.append(tt)
		_box("trim", base + uu * tt + nn * 0.07 + up * (h * 0.5), uu, nn, Vector3(0.4, h - 0.9, 0.14))
	# window rows between pilasters, skipping doorways and the street-level band on tall masses
	var rows: Array = _style.get("rows", [3.2])
	var win: Vector2 = _style.get("window", Vector2(1.1, 1.5))
	var lit_p := float(_style.get("lit", 0.2))
	for ri in rows.size():
		var yy := float(rows[ri])
		if yy + win.y * 0.5 + 0.6 > h:
			continue
		for i in range(pier_pos.size() - 1):
			var c := (float(pier_pos[i]) + float(pier_pos[i + 1])) * 0.5
			var gap := float(pier_pos[i + 1]) - float(pier_pos[i])
			if gap < win.x + 1.0:
				continue
			var blocked := false
			for d in doors:
				var lo: float = float(d[0]) - face_offset
				var hi: float = float(d[1]) - face_offset
				if c + win.x * 0.5 + 0.2 > lo and c - win.x * 0.5 - 0.2 < hi:
					blocked = true
			if blocked or (is_fill and _rng.randf() < float(_style.get("skip", 0.12))):
				continue
			var cc := base + uu * c + up * yy
			_box("trim", cc + nn * 0.06, uu, nn, Vector3(win.x + 0.24, win.y + 0.24, 0.1))
			var kind := "glass_lit" if _rng.randf() < lit_p else "glass"
			_box(kind, cc + nn * 0.11, uu, nn, Vector3(win.x, win.y, 0.06))
	# pipe run (foundry / tideline): a horizontal conduit along the stretch
	if str(_style.get("pipe", "")) != "" and h >= 6.0 and length >= 5.0 and _rng.randf() < float(_style.get("pipe_chance", 0.0)):
		_cyl("pipe", base + uu * (length * 0.5) + nn * 0.2 + up * float(_style.get("pipe_y", 4.4)), uu, nn, length - 0.4, 0.11)


func _box(kind: String, center: Vector3, uu: Vector3, nn: Vector3, size: Vector3) -> void:
	if not _kinds.has(kind):
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE
		_kinds[kind] = {"mesh": bm, "xf": []}
	var basis := Basis(uu * size.x, Vector3.UP * size.y, -nn * size.z)      # right-handed (a mirrored basis would flip culling)
	(_kinds[kind]["xf"] as Array).append(Transform3D(basis, center))


func _cyl(kind: String, center: Vector3, uu: Vector3, nn: Vector3, length: float, radius: float) -> void:
	if not _kinds.has(kind):
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 1.0
		cm.radial_segments = 8
		cm.rings = 1
		_kinds[kind] = {"mesh": cm, "xf": []}
	var x_axis := Vector3.UP
	var z_axis := x_axis.cross(uu).normalized()
	var basis := Basis(x_axis * radius, uu * length, z_axis * radius)
	(_kinds[kind]["xf"] as Array).append(Transform3D(basis, center))
