class_name MapDecor
extends RefCounted
## Art-pass helpers shared by the three arenas. They add visual architecture on top of the existing
## collision layout (which carries the measured Hot Return routes), so gameplay distances do not move:
## - dress_boxes: cap trims, plinths and corner posts on every wall/cover block, per material family
## - place: imported CC0 models (Kenney Nature / Space Station kits) scaled to a target height, restyled
## - column / arch: procedural ceremonial architecture (beveled shafts, capitals, lintels)
## - bastion: angled corner masses with collision that break the rectangular outline (corners only)

const NATURE := "res://assets/models/nature/"
const STATION := "res://assets/models/station/"


static func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _boxm(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## Adds trims to every box-shaped StaticBody in the map geometry. Floors, ramps and very large
## perimeter walls get their own treatment; the trims are visual (no collision) and stay within
## 0.12 m of the collision box so they never hide a player edge.
static func dress_boxes(def: MapDef) -> int:
	var fam := def.family
	var cap_col := Palette.PORCELAIN if fam == "oracle" else (Color("6C5A48") if fam == "tideline" else Color("3C4250"))
	var trim_col := Color("B7A88C") if fam == "oracle" else (Color("C8622F") if fam == "tideline" else Color("C7713A"))
	var cap := Style.surface("ceramic" if fam == "oracle" else "metal", cap_col)
	var trim := Style.surface("stone" if fam == "oracle" else "rust", trim_col.darkened(0.15))
	var post := Style.surface("metal" if fam != "oracle" else "ceramic", Color("4A4F55") if fam != "oracle" else Color("D8CDB5"))
	var n := 0
	for body in def.geometry.get_children():
		if not (body is StaticBody3D):
			continue
		var mi: MeshInstance3D = null
		for c in body.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
				mi = c
		if mi == null or not mi.visible:
			continue   # an invisible body (the barrier above a sea rail) must not grow floating trims
		var sz: Vector3 = (mi.mesh as BoxMesh).size
		if sz.y < 0.7 or sz.y > 7.0 or sz.x > 60.0 or sz.z > 60.0:
			continue
		if absf((body as StaticBody3D).rotation.x) > 0.05 or absf((body as StaticBody3D).rotation.z) > 0.05:
			continue
		var top := sz.y * 0.5
		_mesh(body, _boxm(Vector3(sz.x + 0.16, 0.14, sz.z + 0.16)), Vector3(0, top + 0.02, 0), cap)
		_mesh(body, _boxm(Vector3(sz.x + 0.12, 0.22, sz.z + 0.12)), Vector3(0, -top + 0.11, 0), trim)
		if sz.y >= 1.8:
			_mesh(body, _boxm(Vector3(sz.x + 0.06, 0.08, sz.z + 0.06)), Vector3(0, top - 0.42, 0), trim)
		if sz.y >= 1.2 and (sz.x >= 2.0 or sz.z >= 2.0):
			for sx in [-1.0, 1.0]:
				for sz2 in [-1.0, 1.0]:
					_mesh(body, _boxm(Vector3(0.18, sz.y - 0.1, 0.18)), Vector3(sx * (sz.x * 0.5 - 0.03), 0, sz2 * (sz.z * 0.5 - 0.03)), post)
		if fam == "tideline" and sz.y < 2.0:
			# hazard band on low dock cover
			_mesh(body, _boxm(Vector3(sz.x + 0.04, 0.1, sz.z + 0.04)), Vector3(0, top - 0.2, 0), Style.surface("ceramic", Color("D99A2B")))
		n += 1
	return n


static func _bounds(n: Node) -> AABB:
	var acc := [null]
	WeaponModels._bounds(n, Transform3D.IDENTITY, acc)
	return acc[0] if acc[0] != null else AABB(Vector3.ZERO, Vector3.ONE)


## Places an imported model, scaled so its height equals target_h, base on pos.y.
static func place(parent: Node3D, path: String, pos: Vector3, target_h: float, yaw_deg: float, kind: String, tint := Color.WHITE) -> Node3D:
	var m := Style.model(path)
	if m == null:
		return null
	var bb := _bounds(m)
	var s := target_h / maxf(bb.size.y, 0.01)
	m.scale = Vector3.ONE * s
	m.position = pos - Vector3(0, bb.position.y * s, 0)
	m.rotation_degrees.y = yaw_deg
	Style.restyle(m, kind, tint)
	parent.add_child(m)
	return m


## Ceremonial column: square plinth, beveled shaft (16 sides), echinus and abacus capital.
static func column(parent: Node3D, pos: Vector3, h: float, r: float, mat: Material, broken := 0.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	_mesh(root, _boxm(Vector3(r * 2.8, 0.35, r * 2.8)), Vector3(0, 0.175, 0), mat)
	_mesh(root, _boxm(Vector3(r * 2.4, 0.2, r * 2.4)), Vector3(0, 0.45, 0), mat)
	var shaft_h := h - 1.0 if broken <= 0.0 else (h - 1.0) * (1.0 - broken)
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.88
	cm.bottom_radius = r
	cm.height = shaft_h
	cm.radial_segments = 16
	_mesh(root, cm, Vector3(0, 0.55 + shaft_h * 0.5, 0), mat)
	if broken <= 0.0:
		var ech := CylinderMesh.new()
		ech.top_radius = r * 1.25
		ech.bottom_radius = r * 0.88
		ech.height = 0.25
		ech.radial_segments = 16
		_mesh(root, ech, Vector3(0, h - 0.45 + 0.125, 0), mat)
		_mesh(root, _boxm(Vector3(r * 2.7, 0.22, r * 2.7)), Vector3(0, h - 0.11, 0), mat)
	else:
		# fractured top: a tilted drum fragment
		var frag := CylinderMesh.new()
		frag.top_radius = r * 0.8
		frag.bottom_radius = r * 0.88
		frag.height = 0.5
		frag.radial_segments = 16
		_mesh(root, frag, Vector3(r * 0.3, 0.55 + shaft_h + 0.15, 0), mat, Vector3(0.0, 0.0, 0.35))
	return root


## Two columns joined by a lintel with a keystone, spanning `span` metres along local X.
static func arch(parent: Node3D, center: Vector3, yaw_deg: float, span: float, h: float, mat: Material, accent: Material) -> Node3D:
	var root := Node3D.new()
	root.position = center
	root.rotation_degrees.y = yaw_deg
	parent.add_child(root)
	column(root, Vector3(-span * 0.5, 0, 0), h, 0.42, mat)
	column(root, Vector3(span * 0.5, 0, 0), h, 0.42, mat)
	_mesh(root, _boxm(Vector3(span + 1.4, 0.55, 1.1)), Vector3(0, h + 0.27, 0), mat)
	_mesh(root, _boxm(Vector3(span + 1.0, 0.12, 1.18)), Vector3(0, h + 0.02, 0), accent)
	_mesh(root, _boxm(Vector3(0.7, 0.8, 1.2)), Vector3(0, h + 0.45, 0), accent)
	return root


## Collision column (for columns inside the play space, so bullets and players respect them).
static func solid_column(def: MapDef, pos: Vector3, h: float, r: float, mat: Material, broken := 0.0) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r * 1.1
	sh.height = h if broken <= 0.0 else h * (1.0 - broken) + 0.6
	cs.shape = sh
	cs.position = Vector3(0, sh.height * 0.5, 0)
	body.add_child(cs)
	def.geometry.add_child(body)
	body.add_to_group("navgeo")
	column(body, Vector3.ZERO, h, r, mat, broken)
	def.footprints.append({"node": body, "w": r * 2.4, "d": r * 2.4, "kind": "cyl"})


## Angled mass across a map corner (collision + visual). Only used where no route, spawn or gate is.
static func bastion(def: MapDef, corner: Vector3, yaw_deg: float, length: float, depth: float, height: float, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = corner + Vector3(0, height * 0.5, 0)
	body.rotation_degrees.y = yaw_deg
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(length, height, depth)
	cs.shape = bs
	body.add_child(cs)
	_mesh(body, _boxm(Vector3(length, height, depth)), Vector3.ZERO, mat)
	def.geometry.add_child(body)
	body.add_to_group("navgeo")
	def.footprints.append({"node": body, "w": length, "d": depth, "kind": "box"})
	return body


## Slowly rotating holder for decorative machinery (reactor rings).
class Spinner extends Node3D:
	var speed := 0.2

	func _process(delta: float) -> void:
		rotate_y(speed * delta)

## Large animated sea plane below the playable decks.
static func sea(def: MapDef, y: float, size: Vector2) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	pm.subdivide_width = 60
	pm.subdivide_depth = 40
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = load("res://src/shaders/sea.gdshader")
	mi.material_override = m
	mi.position = Vector3(0, y, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	def.features.add_child(mi)
	return mi


## Thin straight member between two points (cables, braces, lattice struts). Visual only.
static func strut(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = a.distance_to(b)
	cm.radial_segments = 6
	mi.mesh = cm
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = (a + b) * 0.5
	var dir := (b - a).normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	mi.basis = Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, PI * 0.5)
	return mi


## Lattice crane: mast around an existing tower, jib, counter-jib, counterweight, hook cable.
static func crane(parent: Node3D, base: Vector3, h: float, jib: float, yaw_deg: float, steel: Material, accent: Material) -> Node3D:
	var root := Node3D.new()
	root.position = base
	root.rotation_degrees.y = yaw_deg
	parent.add_child(root)
	var w := 1.6
	for cx in [-w, w]:
		for cz in [-w, w]:
			strut(root, Vector3(cx, 0, cz), Vector3(cx, h, cz), 0.12, steel)
	var y := 0.0
	while y < h - 1.0:
		strut(root, Vector3(-w, y, -w), Vector3(w, y + 2.0, -w), 0.06, steel)
		strut(root, Vector3(w, y, w), Vector3(-w, y + 2.0, w), 0.06, steel)
		strut(root, Vector3(-w, y, w), Vector3(-w, y + 2.0, -w), 0.06, steel)
		strut(root, Vector3(w, y, -w), Vector3(w, y + 2.0, w), 0.06, steel)
		y += 2.0
	_mesh(root, _boxm(Vector3(jib, 0.9, 1.2)), Vector3(jib * 0.5 - 2.0, h + 0.45, 0), accent)
	_mesh(root, _boxm(Vector3(9.0, 0.8, 1.2)), Vector3(-6.5, h + 0.4, 0), steel)
	_mesh(root, _boxm(Vector3(3.0, 2.4, 2.2)), Vector3(-9.5, h - 0.8, 0), steel)
	_mesh(root, _boxm(Vector3(2.6, 2.2, 2.6)), Vector3(0, h + 1.9, 0), accent)
	strut(root, Vector3(0, h + 3.0, 0), Vector3(jib - 3.0, h + 0.9, 0), 0.04, steel)
	strut(root, Vector3(0, h + 3.0, 0), Vector3(-10.0, h + 0.8, 0), 0.04, steel)
	strut(root, Vector3(jib * 0.7, h, 0), Vector3(jib * 0.7, h - 9.0, 0), 0.03, steel)
	_mesh(root, _boxm(Vector3(1.0, 0.8, 1.0)), Vector3(jib * 0.7, h - 9.4, 0), accent)
	return root


## Pier piles under a deck edge, from deck level down into the sea.
static func piles(parent: Node3D, from: Vector3, to: Vector3, count: int, depth: float, mat: Material) -> void:
	for i in count:
		var p := from.lerp(to, float(i) / maxf(1.0, float(count - 1)))
		strut(parent, p, p - Vector3(0, depth, 0), 0.55, mat)



## Perimeter wall along X at depth z, split around openings [[centre_x, width], ...].
static func split_wall_x(def: MapDef, z: float, half_len: float, h: float, gaps: Array, mat: Material) -> void:
	var cuts: Array = []
	for g in gaps:
		cuts.append([float(g[0]) - float(g[1]) * 0.5, float(g[0]) + float(g[1]) * 0.5])
	cuts.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	var start := -half_len
	for c in cuts + [[half_len, half_len]]:
		var seg_len := float(c[0]) - start
		if seg_len > 0.05:
			def.box(Vector3(start + seg_len * 0.5, h * 0.5, z), Vector3(seg_len, h, 1), mat, "", false)
		start = float(c[1])


## Semicircular walkable lobe beyond a perimeter opening (floor overlaps the main floor by 1 m).
static func lobe(def: MapDef, mouth: Vector3, outward: float, r: float, floor_mat: Material, wall_mat: Material, wall_h: float) -> void:
	def.box(mouth + Vector3(0, -0.5, outward * (r * 0.5 + 0.25)), Vector3(r * 2.0 + 2.0, 1.0, r + 2.5), floor_mat, "", true)
	def.footprints.pop_back()
	var segs := 9
	for i in segs + 1:
		var a := PI * float(i) / float(segs)
		var w := def.box(mouth + Vector3(cos(a) * r, wall_h * 0.5, outward * sin(a) * r), Vector3(1.0, wall_h, r * 0.38), wall_mat, "", false)
		w.rotation.y = -atan2(outward * sin(a), cos(a))


## Rectangular pier projecting through a perimeter opening over the sea, with low rails.
static func pier(def: MapDef, mouth: Vector3, outward: float, width: float, length: float, deck_mat: Material, rail_mat: Material) -> void:
	def.box(mouth + Vector3(0, -0.5, outward * (length * 0.5 - 0.5)), Vector3(width, 1.0, length + 1.0), deck_mat, "", true)
	def.footprints.pop_back()
	for sx in [-1.0, 1.0]:
		def.box(mouth + Vector3(sx * (width * 0.5 - 0.15), 0.55, outward * (length * 0.5 + 0.5)), Vector3(0.3, 1.1, length - 1.0), rail_mat, "", false)
	def.box(mouth + Vector3(0, 0.55, outward * (length - 0.15)), Vector3(width, 1.1, 0.3), rail_mat, "", false)
	for k in 3:
		strut(def.features, mouth + Vector3(-width * 0.5 + 0.6 + k * (width - 1.2) * 0.5, -0.9, outward * (length - 0.8)), mouth + Vector3(-width * 0.5 + 0.6 + k * (width - 1.2) * 0.5, -10.0, outward * (length - 0.8)), 0.45, rail_mat)
