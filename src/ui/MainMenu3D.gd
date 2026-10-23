class_name MainMenu3D
extends SubViewport
## Live 3D background behind the main menu: the real Oracle Gardens arena (same builder, materials,
## shaders and lighting as the match) under a slow cinematic orbit, with the Causal Core suspended
## over the fractured sanctuary. Nothing here is a static image.

var _cam: Camera3D
var _core: Node3D
var _core_mat: ShaderMaterial
var _t := 0.0
var _def: MapDef


func _ready() -> void:
	own_world_3d = true
	transparent_bg = false
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	msaa_3d = Viewport.MSAA_2X
	var root := Node3D.new()
	root.name = "MenuWorld"
	add_child(root)
	_def = Maps.make("oracle_gardens")
	if _def != null:
		_def.build(root)
	_core = Node3D.new()
	root.add_child(_core)
	_core.position = Vector3(0, 11.5, 0)
	var inner := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.9
	sm.height = 1.8
	sm.radial_segments = 48
	sm.rings = 24
	inner.mesh = sm
	_core_mat = ShaderMaterial.new()
	_core_mat.shader = load("res://src/shaders/core.gdshader")
	inner.material_override = _core_mat
	_core.add_child(inner)
	for i in 3:
		var halo := MeshInstance3D.new()
		var ht := TorusMesh.new()
		ht.inner_radius = 1.3 + i * 0.35
		ht.outer_radius = 1.4 + i * 0.35
		ht.rings = 48
		halo.mesh = ht
		halo.rotation_degrees = Vector3(60 + i * 45, 0, i * 30)
		halo.material_override = Features.glow_mat([Palette.MINT, Palette.PORCELAIN, Palette.VERMILION][i], 1.4)
		_core.add_child(halo)
	var glow := OmniLight3D.new()
	glow.light_color = Palette.MINT
	glow.light_energy = 2.0
	glow.omni_range = 14.0
	_core.add_child(glow)
	_cam = Camera3D.new()
	_cam.fov = 55.0
	_cam.far = 600.0
	root.add_child(_cam)
	_cam.current = true
	Style.add_outline(_cam)


func _process(delta: float) -> void:
	_t += delta
	var ang := 0.6 + _t * 0.035
	var r := 34.0 + sin(_t * 0.07) * 4.0
	_cam.global_position = Vector3(cos(ang) * r, 15.0 + sin(_t * 0.11) * 1.5, sin(ang) * r * 0.8)
	_cam.look_at(Vector3(0, 3.0, 0), Vector3.UP)
	_core.rotate_y(delta * 0.5)
	_core.position.y = 11.5 + sin(_t * 0.8) * 0.25
	_core_mat.set_shader_parameter("volatility", 0.3 + 0.25 * sin(_t * 0.4))
