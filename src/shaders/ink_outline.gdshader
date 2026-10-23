// Screen-space ink outline for the PALIMPSEST style. Drawn on a full-screen quad parented to the
// camera after the opaque pass. Edges come from linear-depth discontinuities (silhouettes) and
// view-normal creases (architectural edges). Fades with distance so far geometry does not turn into
// noisy hatching, and stays thin at 1080p. Requires Forward+ (normal_roughness texture).
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, blend_mix, fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D nr_tex : hint_normal_roughness_texture, filter_nearest, repeat_disable;
uniform vec4 ink : source_color = vec4(0.10, 0.09, 0.12, 1.0);
uniform float thickness : hint_range(0.5, 3.0) = 1.0;
uniform float depth_threshold : hint_range(0.001, 0.5) = 0.06;
uniform float normal_threshold : hint_range(0.05, 1.0) = 0.4;
uniform float max_distance = 85.0;
uniform float strength : hint_range(0.0, 1.0) = 0.8;
uniform float normal_weight : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float lin_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

vec3 vnormal(vec2 uv) {
	vec4 t = texture(nr_tex, uv);
	return normalize(t.xyz * 2.0 - 1.0);
}

void fragment() {
	vec2 px = thickness / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	float dc = lin_depth(uv, INV_PROJECTION_MATRIX);
	float dl = lin_depth(uv - vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float dr = lin_depth(uv + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float du = lin_depth(uv - vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float dd = lin_depth(uv + vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float dmin = min(dc, min(min(dl, dr), min(du, dd)));
	// depth edge relative to distance so near and far silhouettes behave alike
	float dedge = (abs(dl - dc) + abs(dr - dc) + abs(du - dc) + abs(dd - dc)) / max(dmin, 0.05);
	float e_depth = smoothstep(depth_threshold, depth_threshold * 2.0, dedge);
	vec3 nc = vnormal(uv);
	float nd = 0.0;
	nd = max(nd, 1.0 - dot(nc, vnormal(uv - vec2(px.x, 0.0))));
	nd = max(nd, 1.0 - dot(nc, vnormal(uv + vec2(px.x, 0.0))));
	nd = max(nd, 1.0 - dot(nc, vnormal(uv - vec2(0.0, px.y))));
	nd = max(nd, 1.0 - dot(nc, vnormal(uv + vec2(0.0, px.y))));
	float e_norm = smoothstep(normal_threshold, normal_threshold + 0.2, nd) * (1.0 - smoothstep(30.0, max_distance * 0.8, dmin));
	float edge = max(e_depth, e_norm * normal_weight);
	float fade = 1.0 - smoothstep(max_distance * 0.6, max_distance, dmin);
	if (dmin > 3000.0) {
		edge = 0.0;
	}
	ALBEDO = ink.rgb;
	ALPHA = clamp(edge * fade * strength, 0.0, 1.0);
}
