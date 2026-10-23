class_name MapDef
extends RefCounted
## Base for runtime-built arenas. Maps are built from code into a NavigationRegion3D so
## geometry, collision, lighting, spawns, sites and features are all data-driven and testable.
## (Documented honestly: these are runtime-built layouts, not hand-authored scene files.)

var id := ""
var display_name := ""
var mechanic := ""
var blurb := ""
var kill_y := -12.0
var role_spawns := {"attack": [], "defend": []}
var ffa_spawns: Array = []
var sites: Dictionary = {}          # "A"/"B" -> {"position": Vector3, "radius": float}
var shard_points: Array = []        # Relic Rush pickups
var beacon_points: Array = []       # Relic Rush beacon locations
var core_spawn := Vector3.ZERO
var root: Node3D = null
var nav: NavigationRegion3D = null
var geometry: Node3D = null
var features: Node3D = null
var _mats: Dictionary = {}


func build(target: Node3D) -> void:
	root = target
	nav = NavigationRegion3D.new()
	nav.name = "Nav"
	root.add_child(nav)
	geometry = Node3D.new()
	geometry.name = "Geometry"
	nav.add_child(geometry)
	features = Node3D.new()
	features.name = "Features"
	root.add_child(features)
	for n in ["Players", "Echoes", "Objectives", "Fx"]:
		var holder := Node3D.new()
		holder.name = n
		root.add_child(holder)
	_build_layout()


func _build_layout() -> void:
	pass


func bake_nav() -> void:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.6
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 50.0
	nm.cell_size = 0.3
	nm.cell_height = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = "navgeo"
	nav.navigation_mesh = nm
	nav.bake_navigation_mesh(false)


# ---------------------------------------------------------------- helpers
func mat(color: Color, rough: float = 0.9, metal: float = 0.0, emissive: Color = Color.BLACK, emissive_energy: float = 1.0) -> StandardMaterial3D:
	var key := "%s|%f|%f|%s|%f" % [color.to_html(), rough, metal, emissive.to_html(), emissive_energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emissive != Color.BLACK:
		m.emission_enabled = true
		m.emission = emissive
		m.emission_energy_multiplier = emissive_energy
	_mats[key] = m
	return m


## Axis-aligned solid box with collision (world layer 1) and a mesh.
func box(pos: Vector3, size: Vector3, material: Material, label: String = "", walkable: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	if label != "":
		body.name = label
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	body.add_child(mi)
	if walkable:
		body.add_to_group("navgeo")
	geometry.add_child(body)
	return body


func ramp(pos: Vector3, size: Vector3, yaw_deg: float, pitch_deg: float, material: Material) -> StaticBody3D:
	var body := box(pos, size, material, "", true)
	body.rotation_degrees = Vector3(pitch_deg, yaw_deg, 0)
	return body


func cylinder(pos: Vector3, radius: float, height: float, material: Material, walkable: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = height
	cs.shape = sh
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = material
	body.add_child(mi)
	if walkable:
		body.add_to_group("navgeo")
	geometry.add_child(body)
	return body


## Flat decorative marking (no collision).
func decal(pos: Vector3, size: Vector2, material: Material, yaw_deg: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = Vector3(0, yaw_deg, 0)
	features.add_child(mi)
	return mi


func ring(pos: Vector3, radius: float, thickness: float, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius - thickness
	tm.outer_radius = radius
	tm.rings = 48
	mi.mesh = tm
	mi.material_override = material
	mi.position = pos
	features.add_child(mi)
	return mi


func spawn_point(role: String, pos: Vector3, yaw_deg: float) -> void:
	role_spawns[role].append({"position": pos, "yaw": deg_to_rad(yaw_deg)})


func ffa_spawn(pos: Vector3, yaw_deg: float) -> void:
	ffa_spawns.append({"position": pos, "yaw": deg_to_rad(yaw_deg)})


func site(site_id: String, pos: Vector3, radius: float) -> void:
	sites[site_id] = {"position": pos, "radius": radius}


func light_env(sun_dir: Vector3, sun_color: Color, sky_top: Color, sky_horizon: Color, ground: Color, fog_color: Color, fog_density: float = 0.004) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = sun_color
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	root.add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, sun_dir.normalized(), Vector3.UP)
	var we := WorldEnvironment.new()
	we.name = "Env"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var skm := ProceduralSkyMaterial.new()
	skm.sky_top_color = sky_top
	skm.sky_horizon_color = sky_horizon
	skm.ground_bottom_color = ground
	skm.ground_horizon_color = sky_horizon
	skm.sun_angle_max = 20.0
	skm.sun_curve = 0.1
	sky.sky_material = skm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.45
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.78
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.2
	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_density = fog_density
	env.fog_sky_affect = 0.1
	we.environment = env
	root.add_child(we)


func pick_spawn(role: String, index: int) -> Dictionary:
	var list: Array = ffa_spawns if role == "ffa" else role_spawns.get(role, [])
	if list.is_empty():
		list = ffa_spawns if not ffa_spawns.is_empty() else role_spawns["attack"]
	if list.is_empty():
		return {"position": Vector3(0, 2, 0), "yaw": 0.0}
	return list[posmod(index, list.size())]


func in_site(pos: Vector3) -> String:
	for sid in sites:
		var s: Dictionary = sites[sid]
		var p: Vector3 = s["position"]
		var d := Vector2(pos.x - p.x, pos.z - p.z).length()
		if d <= s["radius"] and absf(pos.y - p.y) < 3.5:
			return sid
	return ""
