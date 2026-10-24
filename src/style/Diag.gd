class_name Diag
extends RefCounted
## Rendering isolation harness. `-- --diag=a,b,c` switches individual suspects off (or on) so the
## same camera view can be captured with exactly one variable changed:
##   no_outline   hide the screen-space ink pass       no_ssao     disable SSAO
##   hard_shadow  directional soft-shadow filter off  no_shadow   sun casts no shadows
##   no_halftone  halftone dots off in toon materials  smooth_light toon bands -> continuous ramp
##   no_detail    triplanar detail maps off             no_glow     glow off
##   no_fog       fog off                               msaa4       force MSAA 4x
## Every applied switch is logged so screenshots can be matched to their configuration.

static func flags() -> PackedStringArray:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--diag="):
			return a.substr(7).split(",", false)
	return PackedStringArray()


static func apply(world: Node) -> void:
	var f := flags()
	if f.is_empty() or world == null:
		return
	var vp := world.get_viewport()
	for n in world.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = (n as WorldEnvironment).environment
		if f.has("no_ssao"):
			env.ssao_enabled = false
		if f.has("no_glow"):
			env.glow_enabled = false
		if f.has("no_fog"):
			env.fog_enabled = false
	for n in world.find_children("*", "DirectionalLight3D", true, false):
		var l := n as DirectionalLight3D
		if f.has("no_shadow"):
			l.shadow_enabled = false
	if f.has("hard_shadow"):
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
	if f.has("msaa4"):
		vp.msaa_3d = Viewport.MSAA_4X
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	var variant := ""
	for x in f:
		if x.begins_with("shader_"):
			variant = "res://src/shaders/diag/toon_%s.gdshader" % x.substr(7)
	for m in Style._cache.values():
		var sm := m as ShaderMaterial
		if variant != "":
			sm.shader = load(variant)
		if f.has("no_halftone"):
			sm.set_shader_parameter("halftone", 0.0)
		if f.has("smooth_light"):
			sm.set_shader_parameter("bands", 64.0)
		if f.has("no_detail"):
			sm.set_shader_parameter("use_detail", 0.0)
	if f.has("std_mats"):
		var swapped := 0
		for mi: MeshInstance3D in world.get_tree().root.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null or mi.name == "InkOutline":
				continue
			var mo := mi.material_override
			if mo is ShaderMaterial and (mo as ShaderMaterial).shader != null and (mo as ShaderMaterial).shader.resource_path.ends_with("palimpsest_toon.gdshader"):
				mi.material_override = _std(mo as ShaderMaterial)
				swapped += 1
			for i in mi.mesh.get_surface_count():
				var so := mi.get_surface_override_material(i)
				if so is ShaderMaterial and (so as ShaderMaterial).shader != null and (so as ShaderMaterial).shader.resource_path.ends_with("palimpsest_toon.gdshader"):
					mi.set_surface_override_material(i, _std(so as ShaderMaterial))
					swapped += 1
		Game.log_ev("Diag", "std_mats", {"swapped": swapped})
	if f.has("no_outline"):
		for n in world.get_tree().root.find_children("InkOutline", "MeshInstance3D", true, false):
			(n as MeshInstance3D).visible = false
	Game.log_ev("Diag", "applied", {"flags": Array(f), "msaa": vp.msaa_3d, "ssaa": vp.screen_space_aa})


static func _std(sm: ShaderMaterial) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = sm.get_shader_parameter("albedo")
	m.roughness = float(sm.get_shader_parameter("roughness"))
	m.metallic = float(sm.get_shader_parameter("metallic"))
	return m
