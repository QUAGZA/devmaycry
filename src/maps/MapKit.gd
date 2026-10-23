class_name MapKit
extends RefCounted
## Level-building toolkit for the authored arenas. Layouts are written as 2D plans (x, z) and
## extruded into real collision + meshes:
##   wall(a, b)            straight wall segment with collision (carves the navmesh)
##   walls(points, gaps)   polyline / closed loop of walls, gaps = segment indices left open (doorways)
##   slab(points, top, t)  concave floor / terrace / roof polygon, trimesh collision, triangulated mesh
##   floor_with_holes      floor polygon minus sunken areas (split into notched strips, no hole math)
##   stairs(low, high, w)  walkable ramp collision dressed with visual steps
##   ladder(base, top, n)  climbable ladder with a bidirectional navigation link for bots
## Every collider that should shape navigation is put in the "navgeo" group; floor polygons are also
## recorded in def.floor_polys so the minimap draws the real topology.


static func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


## Wall segment from a to b (plan coordinates). y0 = base height.
static func wall(def: MapDef, a: Vector2, b: Vector2, h: float, thick: float, mat: Material, y0 := 0.0, nav := true) -> StaticBody3D:
	var mid := (a + b) * 0.5
	var length := a.distance_to(b)
	var body := def.box(Vector3(mid.x, y0 + h * 0.5, mid.y), Vector3(length + thick * 0.5, h, thick), mat, "", nav)
	body.rotation.y = -atan2(b.y - a.y, b.x - a.x)
	return body


## Walls along a polyline. closed = also join last to first. gaps = indices of segments to skip.
static func walls(def: MapDef, pts: Array, h: float, thick: float, mat: Material, closed := false, gaps: Array = [], y0 := 0.0) -> void:
	var n := pts.size()
	var segs := n if closed else n - 1
	for i in segs:
		if gaps.has(i):
			continue
		wall(def, pts[i], pts[(i + 1) % n], h, thick, mat, y0)


## Solid extruded polygon: top face at `top`, `thick` deep. Used for floors, terraces, platforms, roofs.
static func slab(def: MapDef, pts: PackedVector2Array, top: float, thick: float, mat: Material, walkable := true, record := true) -> StaticBody3D:
	var tris := Geometry2D.triangulate_polygon(pts)
	if tris.is_empty():
		push_warning("MapKit.slab: polygon could not be triangulated")
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var bot := top - thick
	# top (CCW seen from above in Godot's -Z-forward convention => wind so normals point up)
	for i in range(0, tris.size(), 3):
		var a := _v3(pts[tris[i]], top)
		var b := _v3(pts[tris[i + 1]], top)
		var c := _v3(pts[tris[i + 2]], top)
		if (b - a).cross(c - a).y > 0.0:
			var t := b
			b = c
			c = t
		for v in [a, b, c]:
			st.set_uv(Vector2(v.x, v.z) * 0.25)
			st.add_vertex(v)
			faces.append(v)
	# sides
	var n := pts.size()
	var cw := Geometry2D.is_polygon_clockwise(pts)
	for i in n:
		var p0 := pts[i]
		var p1 := pts[(i + 1) % n]
		var q: Array[Vector3] = [_v3(p0, top), _v3(p1, top), _v3(p1, bot), _v3(p0, bot)]
		var order: Array = [0, 1, 2, 0, 2, 3] if not cw else [0, 2, 1, 0, 3, 2]
		var outward := Vector3(p1.y - p0.y, 0, -(p1.x - p0.x))
		var test: Vector3 = (q[order[1]] - q[order[0]]).cross(q[order[2]] - q[order[0]])
		if test.dot(outward) < 0.0:
			order = [0, 2, 1, 0, 3, 2] if order == [0, 1, 2, 0, 2, 3] else [0, 1, 2, 0, 2, 3]
		for k in order:
			var v: Vector3 = q[k]
			st.set_uv(Vector2(v.x + v.z, v.y) * 0.25)
			st.add_vertex(v)
			faces.append(v)
	st.generate_normals()
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	body.add_child(mi)
	if walkable:
		body.add_to_group("navgeo")
	def.geometry.add_child(body)
	if record:
		def.floor_polys.append({"pts": pts, "y": top})
	return body


## Floor polygon with sunken holes. The outline is split into vertical strips at each hole's centre
## so every hole becomes a notch on two strips (no polygon-with-hole triangulation needed).
static func floor_with_holes(def: MapDef, outline: PackedVector2Array, holes: Array, top: float, thick: float, mat: Material) -> void:
	var cuts: Array = []
	for h in holes:
		var hp: PackedVector2Array = h
		var cx := 0.0
		for p in hp:
			cx += p.x
		cuts.append(cx / hp.size())
	cuts.sort()
	var xs := [-10000.0] + cuts + [10000.0]
	for i in xs.size() - 1:
		var strip := PackedVector2Array([Vector2(xs[i], -10000), Vector2(xs[i + 1], -10000), Vector2(xs[i + 1], 10000), Vector2(xs[i], 10000)])
		var parts := Geometry2D.intersect_polygons(outline, strip)
		for part in parts:
			var pieces: Array = [part]
			for h in holes:
				var next: Array = []
				for pc in pieces:
					for r in Geometry2D.clip_polygons(pc, h):
						if not Geometry2D.is_polygon_clockwise(r) or Geometry2D.is_polygon_clockwise(pc):
							next.append(r)
				pieces = next
			for pc in pieces:
				if pc.size() >= 3:
					slab(def, pc, top, thick, mat)


## Walkable ramp with visual steps (collision is the smooth ramp so movement never snags).
static func stairs(def: MapDef, low: Vector3, high: Vector3, width: float, mat: Material, step_mat: Material = null) -> void:
	var ramp := def.slope(low, high, width, 0.35, mat)
	var mi_ramp := ramp.get_child(1) as MeshInstance3D
	if mi_ramp != null:
		mi_ramp.visible = false
	var rise := high.y - low.y
	var steps := maxi(2, int(ceil(absf(rise) / 0.3)))
	var dir := high - low
	var flat := Vector3(dir.x, 0, dir.z)
	var run := flat.length()
	var yaw := atan2(flat.x, flat.z)
	for i in steps:
		var f0 := float(i) / steps
		var h0 := low.y + rise * (float(i + 1) / steps)
		var center := low + flat * (f0 + 0.5 / steps)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(width, maxf(0.05, h0 - low.y + 0.02), run / steps + 0.02)
		mi.mesh = bm
		mi.position = Vector3(center.x, low.y + (h0 - low.y) * 0.5, center.z)
		mi.rotation.y = yaw
		mi.material_override = step_mat if step_mat != null else mat
		def.features.add_child(mi)


## Ladder on a wall face. base = floor point at the foot (in front of the wall), top_y = platform
## height, outward = unit vector pointing from the wall toward the climber.
static func ladder(def: MapDef, base: Vector3, top_y: float, outward: Vector3, lname: String) -> void:
	var l := Features.Ladder.new()
	l.setup(base, top_y, outward.normalized(), lname)
	def.features.add_child(l)
	var link := NavigationLink3D.new()
	link.bidirectional = true
	link.start_position = base + outward * 0.9
	link.end_position = Vector3(base.x, top_y, base.z) - outward * 1.4
	def.features.add_child(link)
	def.ladders.append({"base": base, "top_y": top_y, "out": outward})


## Ceiling / roof slab (not walkable, not recorded on the minimap).
static func roof(def: MapDef, pts: PackedVector2Array, y: float, mat: Material) -> void:
	slab(def, pts, y + 0.5, 0.5, mat, false, false)


static func rect(cx: float, cz: float, w: float, d: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(cx - w * 0.5, cz - d * 0.5), Vector2(cx + w * 0.5, cz - d * 0.5), Vector2(cx + w * 0.5, cz + d * 0.5), Vector2(cx - w * 0.5, cz + d * 0.5)])


## Regular polygon (circle approximation) in plan.
static func ngon(cx: float, cz: float, r: float, sides: int, rot := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in sides:
		var a := rot + TAU * float(i) / float(sides)
		out.append(Vector2(cx + cos(a) * r, cz + sin(a) * r))
	return out


## Mirror a plan polygon across x = 0 (keeps winding consistent).
static func mirror_x(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(pts.size() - 1, -1, -1):
		out.append(Vector2(-pts[i].x, pts[i].y))
	return out


## Rectangular room walls with doorways. doors = {"n": [[offset, width], ...], "s": ..., "e": ..., "w": ...}
## where offset is measured from the side's centre along the wall. Optional roof at height h.
static func room(def: MapDef, cx: float, cz: float, w: float, d: float, h: float, mat: Material, doors: Dictionary, roof_mat: Material = null, thick := 0.8) -> void:
	var sides := {
		"n": [Vector2(cx - w * 0.5, cz - d * 0.5), Vector2(cx + w * 0.5, cz - d * 0.5)],
		"s": [Vector2(cx - w * 0.5, cz + d * 0.5), Vector2(cx + w * 0.5, cz + d * 0.5)],
		"w": [Vector2(cx - w * 0.5, cz - d * 0.5), Vector2(cx - w * 0.5, cz + d * 0.5)],
		"e": [Vector2(cx + w * 0.5, cz - d * 0.5), Vector2(cx + w * 0.5, cz + d * 0.5)],
	}
	for k in sides:
		var a: Vector2 = sides[k][0]
		var b: Vector2 = sides[k][1]
		var length := a.distance_to(b)
		var dir := (b - a) / length
		var cuts: Array = []
		for dd in doors.get(k, []):
			var c := length * 0.5 + float(dd[0])
			cuts.append([c - float(dd[1]) * 0.5, c + float(dd[1]) * 0.5])
		cuts.sort_custom(func(x, y) -> bool: return x[0] < y[0])
		var t := 0.0
		for c in cuts + [[length, length]]:
			if float(c[0]) - t > 0.3:
				wall(def, a + dir * t, a + dir * float(c[0]), h, thick, mat)
			# lintel over each doorway so interiors read as rooms, not gaps
			if float(c[0]) < length and roof_mat != null:
				var la := a + dir * float(c[0])
				var lb := a + dir * float(c[1])
				wall(def, la, lb, 1.4, thick, mat, h - 1.4, false)
			t = float(c[1])
	if roof_mat != null:
		roof(def, rect(cx, cz, w + thick, d + thick), h, roof_mat)
