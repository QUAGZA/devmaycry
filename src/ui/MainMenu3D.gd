class_name MainMenu3D
extends SubViewport
## Live 3D hero behind the main menu: a Causal Core on a porcelain plinth under a slow orbit camera.
## Uses the same shaders as the game so the menu and the match share one identity.

var _cam: Camera3D
var _core: MeshInstance3D
var _core_mat: ShaderMaterial
var _t := 0.0


func _ready() -> void:
	own_world_3d = true
	transparent_bg = false
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	msaa_3d = Viewport.MSAA_2X
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.INK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.4, 0.45)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.1, 0.1)
	env.fog_density = 0.02
	env_node.environment = env
	add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("FFE9CC")
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)
	sun.look_at_from_position(Vector3(4, 8, 4), Vector3.ZERO, Vector3.UP)
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor_mesh.mesh = pm
	var fm := ShaderMaterial.new()
	fm.shader = load("res://src/shaders/surface.gdshader")
	fm.set_shader_parameter("albedo", Palette.CHALK.darkened(0.35))
	fm.set_shader_parameter("accent", Palette.COBALT_DARK.darkened(0.3))
	fm.set_shader_parameter("roughness", 0.8)
	fm.set_shader_parameter("tile", 0.5)
	floor_mesh.material_override = fm
	add_child(floor_mesh)
	for i in 3:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 2.0 + i * 1.3
		tm.outer_radius = 2.12 + i * 1.3
		tm.rings = 64
		ring.mesh = tm
		ring.position = Vector3(0, 0.02 + i * 0.01, 0)
		ring.material_override = Features.glow_mat([Palette.MINT, Palette.COBALT, Palette.BRASS][i], 1.2)
		add_child(ring)
	var plinth := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.9
	cm.bottom_radius = 1.2
	cm.height = 0.8
	plinth.mesh = cm
	plinth.position = Vector3(0, 0.4, 0)
	var plm := ShaderMaterial.new()
	plm.shader = load("res://src/shaders/surface.gdshader")
	plm.set_shader_parameter("albedo", Palette.PORCELAIN)
	plm.set_shader_parameter("accent", Palette.STONE)
	plm.set_shader_parameter("roughness", 0.6)
	plinth.material_override = plm
	add_child(plinth)
	_core = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.55
	sm.height = 1.1
	sm.radial_segments = 48
	sm.rings = 24
	_core.mesh = sm
	_core_mat = ShaderMaterial.new()
	_core_mat.shader = load("res://src/shaders/core.gdshader")
	_core.material_override = _core_mat
	_core.position = Vector3(0, 1.6, 0)
	add_child(_core)
	for i in 2:
		var halo := MeshInstance3D.new()
		var ht := TorusMesh.new()
		ht.inner_radius = 0.8 + i * 0.25
		ht.outer_radius = 0.86 + i * 0.25
		halo.mesh = ht
		halo.rotation_degrees = Vector3(60 + i * 45, 0, i * 30)
		halo.material_override = Features.glow_mat(Palette.PORCELAIN if i == 0 else Palette.VERMILION, 1.6)
		_core.add_child(halo)
	_cam = Camera3D.new()
	_cam.fov = 42.0
	add_child(_cam)
	_cam.current = true
	Style.add_outline(_cam)


func _process(delta: float) -> void:
	_t += delta
	var ang := _t * 0.12
	_cam.global_position = Vector3(cos(ang) * 6.5, 2.6 + sin(_t * 0.3) * 0.3, sin(ang) * 6.5)
	_cam.look_at(Vector3(0, 1.4, 0), Vector3.UP)
	_core.rotate_y(delta * 0.6)
	_core_mat.set_shader_parameter("volatility", 0.25 + 0.2 * sin(_t * 0.5))
