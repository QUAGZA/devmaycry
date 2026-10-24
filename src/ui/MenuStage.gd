class_name MenuStage
extends SubViewport
## Dark real-time presentation behind the front end: the Causal Core inside a slowly turning lattice, thin energy
## rings, teal and amber light and a few drifting motes. Everything is generated at runtime (no video, no map):
## one small 3D scene rendered at a reduced size, a few dozen motes and four lights.

const GRAPHITE := Color("101419")
const TEAL := Color("48E0C1")
const AMBER := Color("FFB454")
const TEXT := Color("F3F0E8")

## 0..1: how much of the Core has materialised (the startup sequence drives this; the menu keeps it at 1)
var reveal := 1.0:
	set(v):
		reveal = clampf(v, 0.0, 1.0)
		_apply_reveal()

var _root: Node3D
var _core: Node3D
var _core_mat: ShaderMaterial
var _cam: Camera3D
var _rings: Array = []
var _ring_mats: Array = []
var _lattice: MeshInstance3D
var _lattice_mat: StandardMaterial3D
var _t := 0.0
var _parallax := Vector2.ZERO
var _parallax_smooth := Vector2.ZERO
var _motes: CPUParticles3D
var _glow_light: OmniLight3D
var _quality := "high"


func _ready() -> void:
	own_world_3d = true
	transparent_bg = false
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	msaa_3d = Viewport.MSAA_2X
	_quality = str(Settings.effects_quality)
	if _quality == "low":
		msaa_3d = Viewport.MSAA_DISABLED
	_root = Node3D.new()
	_root.name = "MenuStageWorld"
	add_child(_root)
	_build_environment()
	_build_core()
	_build_lattice()
	_build_rings()
	_build_lights()
	_build_motes()
	_cam = Camera3D.new()
	_cam.fov = 38.0
	_cam.near = 0.1
	_cam.far = 60.0
	_cam.h_offset = -1.6          # the Core sits right of centre, the menu column gets the left side
	_root.add_child(_cam)
	_cam.position = Vector3(0, 0.3, 7.2)
	_cam.current = true
	_apply_reveal()


func set_parallax(v: Vector2) -> void:
	_parallax = v.clamp(Vector2(-1, -1), Vector2(1, 1))


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = GRAPHITE
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("1B232B")
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	if _quality != "low":
		env.glow_enabled = true
		env.glow_intensity = 0.45
		env.glow_bloom = 0.0
		env.glow_hdr_threshold = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	_root.add_child(we)


func _build_core() -> void:
	_core = Node3D.new()
	_root.add_child(_core)
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 64
	sm.rings = 32
	body.mesh = sm
	_core_mat = ShaderMaterial.new()
	_core_mat.shader = load("res://src/shaders/menu_core.gdshader")
	_core_mat.set_shader_parameter("calm_color", TEAL)
	_core_mat.set_shader_parameter("warm_color", AMBER)
	body.material_override = _core_mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_core.add_child(body)


## Icosahedron wireframe around the Core.
func _build_lattice() -> void:
	var phi := (1.0 + sqrt(5.0)) * 0.5
	var raw := [
		Vector3(0, 1, phi), Vector3(0, -1, phi), Vector3(0, 1, -phi), Vector3(0, -1, -phi),
		Vector3(1, phi, 0), Vector3(-1, phi, 0), Vector3(1, -phi, 0), Vector3(-1, -phi, 0),
		Vector3(phi, 0, 1), Vector3(phi, 0, -1), Vector3(-phi, 0, 1), Vector3(-phi, 0, -1)]
	var pts := PackedVector3Array()
	for i in raw.size():
		for j in range(i + 1, raw.size()):
			if absf((raw[i] as Vector3).distance_to(raw[j]) - 2.0) < 0.01:
				pts.append((raw[i] as Vector3).normalized() * 2.15)
				pts.append((raw[j] as Vector3).normalized() * 2.15)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	_lattice = MeshInstance3D.new()
	_lattice.mesh = mesh
	_lattice_mat = StandardMaterial3D.new()
	_lattice_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lattice_mat.albedo_color = Color(TEAL, 0.28)
	_lattice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lattice.material_override = _lattice_mat
	_lattice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(_lattice)


func _build_rings() -> void:
	var specs := [[1.55, TEAL, 0.55, Vector3(72, 0, 14)], [1.85, AMBER, 0.38, Vector3(28, 40, 70)], [2.5, TEXT, 0.14, Vector3(96, 20, 0)]]
	for s in specs:
		var m := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = float(s[0]) - 0.012
		tm.outer_radius = float(s[0]) + 0.012
		tm.rings = 96
		tm.ring_segments = 6
		m.mesh = tm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(s[1], float(s[2]))
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.material_override = mat
		m.rotation_degrees = s[3]
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(m)
		_rings.append(m)
		_ring_mats.append(mat)


func _build_lights() -> void:
	_glow_light = OmniLight3D.new()
	_glow_light.light_color = TEAL
	_glow_light.light_energy = 1.4
	_glow_light.omni_range = 9.0
	_glow_light.position = Vector3(1.6, 1.2, 3.0)
	_root.add_child(_glow_light)
	var warm := OmniLight3D.new()
	warm.light_color = AMBER
	warm.light_energy = 0.7
	warm.omni_range = 9.0
	warm.position = Vector3(-3.0, -1.2, 2.0)
	_root.add_child(warm)


func _build_motes() -> void:
	_motes = CPUParticles3D.new()
	_motes.amount = 40 if _quality == "low" else 72
	_motes.lifetime = 10.0
	_motes.preprocess = 10.0
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_motes.emission_sphere_radius = 7.0
	_motes.direction = Vector3(0, 1, 0)
	_motes.spread = 180.0
	_motes.gravity = Vector3.ZERO
	_motes.initial_velocity_min = 0.08
	_motes.initial_velocity_max = 0.3
	_motes.scale_amount_min = 0.5
	_motes.scale_amount_max = 1.3
	var qm := QuadMesh.new()
	qm.size = Vector2(0.11, 0.11)
	_motes.mesh = qm
	var dot_grad := Gradient.new()
	dot_grad.set_color(0, Color(1, 1, 1, 1))
	dot_grad.set_color(1, Color(1, 1, 1, 0))
	var dot := GradientTexture2D.new()
	dot.gradient = dot_grad
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 32
	dot.height = 32
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = dot
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(TEAL, 0.8)
	_motes.material_override = mat
	var grad := Gradient.new()
	grad.set_color(0, Color(TEAL, 0.0))
	grad.set_color(1, Color(TEAL, 0.0))
	grad.add_point(0.25, Color(TEAL, 0.75))
	grad.add_point(0.75, Color(AMBER, 0.55))
	_motes.color_ramp = grad
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(_motes)


func _apply_reveal() -> void:
	if _core == null:
		return
	var e := 1.0 - pow(1.0 - reveal, 3.0)
	_core.scale = Vector3.ONE * maxf(e, 0.001)
	_core.visible = reveal > 0.01
	_lattice_mat.albedo_color.a = 0.28 * e
	for i in _ring_mats.size():
		var base: float = [0.55, 0.38, 0.14][i]
		(_ring_mats[i] as StandardMaterial3D).albedo_color.a = base * clampf((reveal - 0.15 * i) / (1.0 - 0.15 * i), 0.0, 1.0)
	_glow_light.light_energy = 1.4 * e
	_motes.visible = reveal > 0.2


func _process(delta: float) -> void:
	_t += delta
	_core.rotate_y(delta * 0.28)
	_core.position.y = sin(_t * 0.7) * 0.06
	_lattice.rotate_y(-delta * 0.07)
	_lattice.rotate_x(delta * 0.03)
	for i in _rings.size():
		var m: MeshInstance3D = _rings[i]
		m.rotate_y(delta * (0.11 + 0.05 * i) * (1.0 if i % 2 == 0 else -1.0))
		m.rotate_z(delta * 0.04)
	_core_mat.set_shader_parameter("pulse_amount", 0.5 + 0.5 * sin(_t * 0.35))
	_parallax_smooth = _parallax_smooth.lerp(_parallax, clampf(delta * 3.0, 0.0, 1.0))
	_cam.position = Vector3(_parallax_smooth.x * 0.45, 0.3 - _parallax_smooth.y * 0.25, 7.2)
	_cam.look_at(Vector3(-0.8 + _parallax_smooth.x * 0.2, 0.0, 0.0), Vector3.UP)
