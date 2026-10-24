class_name Style
extends RefCounted
## PALIMPSEST material library. Every map surface, imported prop, character and weapon goes through
## here so the toon lighting, painted detail and ink outline stay consistent. Material identity
## (stone, plaster, ceramic, floor tile, cliff, concrete, metal, rust, cloth, gear) comes from a small
## table of uniforms plus a CC0 Poly Haven detail map sampled triplanar under the palette colour.

const TOON := "res://src/shaders/palimpsest_toon.gdshader"
const INK := "res://src/shaders/ink_outline.gdshader"
const DETAIL := "res://assets/textures/detail/"

## kind -> [detail texture id or "", roughness, metallic, detail_strength, normal_strength, detail_tile, rim, spec_step, halftone]
const KINDS := {
	"stone":    ["sandstone_cracks", 0.92, 0.0, 0.55, 0.8, 0.22, 0.18, 0.0, 0.0],
	"plaster":  ["painted_plaster_wall", 0.85, 0.0, 0.45, 0.6, 0.3, 0.18, 0.0, 0.0],
	"ceramic":  ["painted_plaster_wall", 0.45, 0.0, 0.25, 0.35, 0.45, 0.3, 0.35, 0.0],
	"floor":    ["worn_tile_floor", 0.9, 0.0, 0.5, 0.7, 0.18, 0.0, 0.0, 0.0],
	"cliff":    ["castle_wall_slates", 0.95, 0.0, 0.6, 1.0, 0.12, 0.1, 0.0, 0.3],
	"concrete": ["concrete_floor_worn_001", 0.9, 0.0, 0.5, 0.6, 0.2, 0.1, 0.0, 0.0],
	"metal":    ["metal_plate", 0.42, 0.65, 0.35, 0.5, 0.35, 0.35, 0.6, 0.0],
	"rust":     ["rusty_metal_02", 0.7, 0.35, 0.6, 0.8, 0.3, 0.2, 0.25, 0.0],
	"cloth":    ["", 0.95, 0.0, 0.0, 0.0, 0.5, 0.45, 0.0, 0.0],
	"gear":     ["", 0.6, 0.2, 0.0, 0.0, 0.5, 0.5, 0.3, 0.0],
	"skin":     ["", 0.7, 0.0, 0.0, 0.0, 0.5, 0.35, 0.0, 0.0],
	"foliage":  ["", 0.95, 0.0, 0.0, 0.0, 0.5, 0.15, 0.0, 0.3],
}

static var _cache: Dictionary = {}
static var _tex: Dictionary = {}
static var _outline_slot := 0


## Drops cached materials so the next build picks up a changed effects or texture quality.
static func clear_cache() -> void:
	_cache.clear()


static func _setting(key: String, fallback: String) -> String:
	if Engine.get_main_loop() == null:
		return fallback
	var s = Engine.get_main_loop().root.get_node_or_null("/root/Settings")
	return str(s.get(key)) if s != null else fallback


## Effects quality: ink outline and halftone. Texture quality: detail maps.
static func quality() -> String:
	return _setting("effects_quality", "high")


static func textures_on() -> bool:
	return _setting("texture_quality", "high") != "low"


static func _texture(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


## Shared toon material for a palette colour and a material kind. Cached per (kind, colour, emissive).
static func surface(kind: String, color: Color, emissive: Color = Color.BLACK, emissive_energy: float = 0.0, albedo_tex: Texture2D = null) -> ShaderMaterial:
	var key := "%s|%s|%s|%f|%s" % [kind, color.to_html(), emissive.to_html(), emissive_energy, str(albedo_tex.get_instance_id()) if albedo_tex != null else ""]
	if _cache.has(key):
		return _cache[key]
	var k: Array = KINDS.get(kind, KINDS["stone"])
	var q := quality()
	var m := ShaderMaterial.new()
	m.shader = load(TOON)
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("accent", color.darkened(0.2).lerp(Palette.COBALT_DARK, 0.1))
	m.set_shader_parameter("roughness", k[1])
	m.set_shader_parameter("metallic", k[2])
	m.set_shader_parameter("rim_strength", k[6])
	m.set_shader_parameter("spec_step", k[7])
	m.set_shader_parameter("halftone", float(k[8]) * (1.0 if q == "high" else (0.5 if q == "medium" else 0.0)))
	m.set_shader_parameter("tile", 0.3)
	m.set_shader_parameter("wear", 0.5)
	m.set_shader_parameter("noise_intensity", 0.45 if albedo_tex == null else 0.15)
	m.set_shader_parameter("shade_tint", Color("4A5A8C"))
	if str(k[0]) != "" and textures_on():
		m.set_shader_parameter("detail_albedo", _texture(DETAIL + str(k[0]) + "_col.jpg"))
		m.set_shader_parameter("detail_normal", _texture(DETAIL + str(k[0]) + "_nrm.jpg"))
		m.set_shader_parameter("use_detail", 1.0)
		m.set_shader_parameter("detail_strength", k[3])
		m.set_shader_parameter("normal_strength", k[4])
		m.set_shader_parameter("detail_tile", k[5])
		m.set_shader_parameter("quality_far", 80.0 if q == "high" else 50.0)
	if albedo_tex != null:
		m.set_shader_parameter("albedo_tex", albedo_tex)
		m.set_shader_parameter("use_albedo_tex", 1.0)
	if emissive_energy > 0.0:
		m.set_shader_parameter("emissive", emissive)
		m.set_shader_parameter("emissive_energy", emissive_energy)
	_cache[key] = m
	return m


## Picks a kind for a legacy mat(color, rough, metal) call using the map's material family.
static func kind_for(family: String, color: Color, rough: float, metal: float) -> String:
	if metal >= 0.5:
		return "rust" if family == "tideline" and rough > 0.5 else "metal"
	if metal >= 0.1:
		return "gear"
	var lum := color.get_luminance()
	match family:
		"tideline":
			return "concrete" if lum < 0.7 else "ceramic"
		"foundry":
			return "concrete" if rough > 0.8 else ("ceramic" if lum > 0.6 else "plaster")
		_:
			if rough < 0.75:
				return "ceramic"
			return "stone" if lum > 0.45 else "plaster"


## Replaces the materials of an imported model with toon equivalents, keeping its albedo colour/texture.
static func restyle(node: Node, kind: String, tint: Color = Color.WHITE, saturation: float = 1.0) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var src: Material = mi.get_active_material(i)
				var col := tint
				var tex: Texture2D = null
				if src is BaseMaterial3D:
					col = (src as BaseMaterial3D).albedo_color * tint
					tex = (src as BaseMaterial3D).albedo_texture
				var m := surface(kind, col, Color.BLACK, 0.0, tex)
				if saturation < 1.0 and tex != null:
					m = m.duplicate() as ShaderMaterial
					m.set_shader_parameter("tex_saturation", saturation)
				mi.set_surface_override_material(i, m)
	for c in node.get_children():
		restyle(c, kind, tint, saturation)


## Full-screen ink outline attached to a camera. Skipped on the Low preset.
static func add_outline(cam: Camera3D) -> MeshInstance3D:
	if cam == null or cam.get_node_or_null("InkOutline") != null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = "InkOutline"
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load(INK)
	m.render_priority = 100
	m.set_shader_parameter("thickness", 1.0)
	mi.material_override = m
	mi.extra_cull_margin = 16384.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0, -0.5)
	mi.visible = quality() != "low"
	# each outline quad lives on its own render layer (20-23) and only its own camera sees it, so a
	# spectator camera and the local player camera never stack two outline passes
	var bit := 19 + (_outline_slot % 4)
	_outline_slot += 1
	mi.layers = 1 << bit
	cam.cull_mask = (cam.cull_mask & ~(0xF << 19)) | (1 << bit)
	cam.add_child(mi)
	return mi


## Loads an imported glTF/GLB scene and instances it, or returns null if it is missing.
static func model(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var ps: PackedScene = load(path)
	return ps.instantiate() as Node3D
