// PALIMPSEST toon surface: stepped light bands, cool cobalt shadow ramp, restrained halftone in shade,
// rim light, triplanar painted detail (luminance + normal from CC0 texture maps) and edge wear.
// One shader serves stone, ceramic, metal and cloth; material identity comes from the uniforms.
// Distant fragments skip the detail sampling (quality_far) so background geometry stays cheap.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_lambert, specular_schlick_ggx;

group_uniforms Colour;
uniform vec4 albedo : source_color = vec4(0.9, 0.86, 0.78, 1.0);
uniform vec4 accent : source_color = vec4(0.78, 0.72, 0.62, 1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float use_albedo_tex : hint_range(0.0, 1.0) = 0.0;
uniform float tex_saturation : hint_range(0.0, 1.0) = 1.0;
uniform vec4 shade_tint : source_color = vec4(0.30, 0.34, 0.52, 1.0);
uniform float shade_strength : hint_range(0.0, 1.0) = 0.35;

group_uniforms Lighting;
uniform float bands : hint_range(1.0, 6.0) = 3.0;
uniform float band_soft : hint_range(0.001, 0.5) = 0.06;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.25;
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float halftone : hint_range(0.0, 1.0) = 0.0;
uniform float halftone_scale = 5.0;

group_uniforms Material;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float spec_step : hint_range(0.0, 1.0) = 0.0;

group_uniforms Detail;
uniform sampler2D detail_albedo : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float use_detail : hint_range(0.0, 1.0) = 0.0;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.55;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.7;
uniform float detail_tile = 0.25;
uniform float noise_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float tile = 0.3;
uniform float wear : hint_range(0.0, 1.0) = 0.5;
uniform float seams : hint_range(0.0, 1.0) = 0.4;
uniform float quality_far = 70.0;

group_uniforms Temporal;
uniform vec4 emissive : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emissive_energy = 0.0;

varying vec3 wpos;
varying vec3 wnrm;
// Lighting normal (view space) carrying the painted detail. It is deliberately NOT written to NORMAL:
// the geometric normal must reach the normal-roughness buffer untouched, because SSAO and the depth
// prepass read it. Writing the perturbed normal there produced back-facing normals that SSAO turned
// into black stippling (worst with MSAA). Diagnosed with src/style/Diag.gd, see the build status.
varying vec3 lit_n;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float near_q = 1.0 - smoothstep(quality_far * 0.7, quality_far, dist);
	float n = vnoise(wpos * tile);
	float n2 = vnoise(wpos * tile * 4.3 + 17.0);
	vec3 base = albedo.rgb;
	if (use_albedo_tex > 0.5) {
		vec3 tc = texture(albedo_tex, UV).rgb;
		tc = mix(vec3(dot(tc, vec3(0.299, 0.587, 0.114))), tc, tex_saturation);
		base *= tc;
	}
	vec3 acc = use_albedo_tex > 0.5 ? base * 0.86 : accent.rgb;
	vec3 col = mix(base, acc, clamp(n * 0.7 + n2 * 0.25 - 0.1, 0.0, 1.0) * noise_intensity * 1.6);
	float top = smoothstep(0.55, 0.9, wnrm.y);
	float gx = step(0.985, fract(wpos.x * 0.5)) + step(0.985, fract(wpos.z * 0.5));
	col = mix(col, col * 0.8, clamp(gx, 0.0, 1.0) * top * seams);
	vec3 nrm_out = NORMAL;
	if (use_detail > 0.5 && near_q > 0.01) {
		vec3 bw = pow(abs(wnrm), vec3(4.0));
		bw /= (bw.x + bw.y + bw.z);
		vec2 ux = wpos.zy * detail_tile;
		vec2 uy = wpos.xz * detail_tile;
		vec2 uz = wpos.xy * detail_tile;
		vec3 dc = texture(detail_albedo, ux).rgb * bw.x + texture(detail_albedo, uy).rgb * bw.y + texture(detail_albedo, uz).rgb * bw.z;
		float lum = dot(dc, vec3(0.299, 0.587, 0.114));
		col *= mix(1.0, clamp(0.55 + lum * 0.9, 0.6, 1.35), detail_strength * near_q);
		vec3 tx = texture(detail_normal, ux).xyz * 2.0 - 1.0;
		vec3 ty = texture(detail_normal, uy).xyz * 2.0 - 1.0;
		vec3 tz = texture(detail_normal, uz).xyz * 2.0 - 1.0;
		vec3 s = sign(wnrm);
		vec3 wx = vec3(0.0, tx.y, tx.x * s.x);
		vec3 wy = vec3(ty.x * s.y, 0.0, ty.y);
		vec3 wz = vec3(tz.x * s.z, tz.y, 0.0);
		vec3 wn = normalize(wnrm + (wx * bw.x + wy * bw.y + wz * bw.z) * normal_strength * near_q);
		nrm_out = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
		// never let the detail tilt the lighting normal away from the viewer
		float facing = dot(nrm_out, VIEW);
		if (facing < 0.05) {
			nrm_out = normalize(mix(NORMAL, nrm_out, 0.35));
		}
	}
	// edge wear: brighten convex-looking high-frequency spots, mostly near the top of vertical faces
	float n3 = vnoise(wpos * tile * 12.0 + 41.0);
	col = mix(col, col * 1.08 + vec3(0.02), smoothstep(0.72, 0.9, n3) * wear * near_q);
	lit_n = nrm_out;
	ALBEDO = col;
	ROUGHNESS = clamp(roughness - n2 * 0.15 * wear, 0.05, 1.0);
	METALLIC = metallic;
	EMISSION = emissive.rgb * emissive_energy;
	// rim: view-facing falloff, kept subtle on architecture, stronger on characters and hero props
	float fres = pow(1.0 - clamp(dot(nrm_out, VIEW), 0.0, 1.0), 3.0);
	EMISSION += rim_color.rgb * fres * rim_strength * 0.35;
	// cool ramp in shadow comes through ambient: tint ambient toward the shade colour
	AO = 1.0;
	AO_LIGHT_AFFECT = 0.0;
}

void light() {
	vec3 N = normalize(lit_n);
	float ndl = clamp(dot(N, LIGHT), 0.0, 1.0) * ATTENUATION;
	float stepped = floor(ndl * bands + 0.5) / bands;
	// soften the band boundary a touch so steps read as painted, not aliased
	float lo = floor(ndl * bands) / bands;
	float hi = lo + 1.0 / bands;
	float lit = clamp(mix(lo, hi, smoothstep(0.5 - band_soft * bands, 0.5 + band_soft * bands, fract(ndl * bands))), 0.0, 1.0);
	// halftone dots lift the darkest band slightly so shade reads as printed rather than flat
	float dots = 0.0;
	if (halftone > 0.0) {
		vec2 g = FRAGCOORD.xy / halftone_scale;
		float d = length(fract(g) - 0.5);
		float shade_amt = 1.0 - smoothstep(0.0, 0.34, ndl);
		dots = step(d, 0.22) * shade_amt * halftone * 0.12;
	}
	vec3 warm = LIGHT_COLOR * lit;
	vec3 cool = shade_tint.rgb * (1.0 - lit) * shade_strength * length(LIGHT_COLOR) * 0.25 * ATTENUATION;
	DIFFUSE_LIGHT += warm + cool + LIGHT_COLOR * dots;
	if (spec_step > 0.0) {
		vec3 h = normalize(LIGHT + VIEW);
		float sp = pow(clamp(dot(N, h), 0.0, 1.0), mix(8.0, 96.0, 1.0 - ROUGHNESS));
		SPECULAR_LIGHT += LIGHT_COLOR * step(0.55, sp) * spec_step * ATTENUATION;
	}
}
