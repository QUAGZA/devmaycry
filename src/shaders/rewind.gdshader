// Reverse Entropy silhouette: readable humanoid with dithered body, broken temporal edge bands and
// a fresnel rim in signal orange over oxidized mint.
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_prepass_alpha;

uniform vec4 tint : source_color = vec4(0.47, 0.79, 0.68, 0.6);
uniform vec4 edge : source_color = vec4(1.0, 0.36, 0.24, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.7;

varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	float bands = step(0.45, fract(world_y * 7.0 + TIME * 2.5));
	float dither = fract(sin(dot(floor(FRAGCOORD.xy * 0.5), vec2(12.9898, 78.233))) * 43758.5453);
	float body = density * (0.6 + 0.4 * bands);
	if (dither > body + fresnel) {
		discard;
	}
	vec3 col = mix(tint.rgb, edge.rgb, clamp(fresnel * 1.4 + bands * 0.15, 0.0, 1.0));
	ALBEDO = col;
	EMISSION = col * (0.9 + fresnel * 2.2);
	ALPHA = clamp(tint.a * body + fresnel * 0.5, 0.25, 0.95);
}
