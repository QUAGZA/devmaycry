class_name WeaponModels
extends RefCounted
## Weapon art: Kenney Blaster Kit 2.1 (CC0) bodies chosen for silhouette per weapon class, combined with
## kit attachments (scopes, magazines) and restyled through the PALIMPSEST toon shader in graphite,
## brass and per-weapon accent colours. The returned node is normalised: grip at the origin, barrel
## pointing toward -Z, with a "Muzzle" Marker3D at the barrel tip and a "Mag" node for reload motion.

const DIR := "res://assets/models/weapons/"
## id -> [body glb, scale, accent colour, attachments [[glb, pos, scale]], grip offset (body space)]
const DEF := {
	"rifle":   ["blaster-d.glb", 1.0, Color("C8622F"), [["scope-small.glb", Vector3(0, 0.17, 0.05), 0.8], ["clip-large.glb", Vector3(0, -0.12, -0.06), 0.9]]],
	"shotgun": ["blaster-l.glb", 1.05, Color("B98A3A"), []],
	"sniper":  ["blaster-e.glb", 1.0, Color("3E5F9E"), [["scope-large-a.glb", Vector3(0, 0.16, 0.0), 1.0]]],
	"mg":      ["blaster-a.glb", 1.15, Color("7A8C3E"), [["clip-large.glb", Vector3(0, -0.2, 0.0), 1.3]]],
}

static var _aabb_cache: Dictionary = {}


static func _bounds(n: Node, xf: Transform3D, acc: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var a: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
		acc[0] = a if acc[0] == null else (acc[0] as AABB).merge(a)
	for c in n.get_children():
		_bounds(c, t, acc)


static func build(id: String) -> Node3D:
	if not DEF.has(id):
		return null
	var d: Array = DEF[id]
	var body := Style.model(DIR + str(d[0]))
	if body == null:
		return null
	var root := Node3D.new()
	root.name = "Weapon_" + id
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	root.add_child(pivot)
	pivot.add_child(body)
	Style.restyle(body, "metal", Color(0.78, 0.78, 0.8), 0.12)
	for att in d[3]:
		var a := Style.model(DIR + str(att[0]))
		if a != null:
			a.position = att[1]
			a.scale = Vector3.ONE * float(att[2])
			Style.restyle(a, "gear", Color(0.6, 0.6, 0.62), 0.1)
			pivot.add_child(a)
			if str(att[0]).begins_with("clip"):
				a.name = "Mag"
	# accent stripe so the four weapons read apart at a glance
	var acc := [null]
	_bounds(pivot, Transform3D.IDENTITY, acc)
	var bb: AABB = acc[0] if acc[0] != null else AABB(Vector3(-0.1, -0.1, -0.4), Vector3(0.2, 0.2, 0.8))
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(bb.size.x * 1.02, 0.025, bb.size.z * 0.28)
	stripe.mesh = sm
	stripe.material_override = Style.surface("ceramic", d[2])
	stripe.position = Vector3(bb.get_center().x, bb.position.y + bb.size.y * 0.62, bb.get_center().z)
	pivot.add_child(stripe)
		# Kenney blasters model their barrel toward +Z; turn them so the barrel points down -Z (camera forward)
	pivot.rotation.y = PI
	pivot.position = Vector3(bb.get_center().x * float(d[1]), 0.0, 0.0)
	pivot.scale = Vector3.ONE * float(d[1])
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, (bb.position.y + bb.size.y * 0.7) * float(d[1]), -bb.end.z * float(d[1]) - 0.02)
	root.add_child(muzzle)
	root.set_meta("length", bb.size.z * float(d[1]))
	return root
