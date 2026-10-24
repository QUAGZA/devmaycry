// Menu Causal Core: a calm teal energy sphere (the match Core shader is tuned for a daylight arena and washes out
// on the dark stage). Rim glow, drifting fissures and thin latitude rings; the peak emission stays below white.
shader_type spatial;
render_mode blend_mix, cull_back, shadows_disabled;

uniform vec3 calm_color : source_color = vec3(0.28, 0.88, 0.76);
uniform vec3 warm_color : source_color = vec3(1.0, 0.71, 0.33);
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.2;

varying vec3 v_pos;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

void vertex() {
	v_pos = VERTEX;
}

void fragment() {
	float t = TIME;
	float n = vnoise(v_pos * 4.0 + vec3(0.0, t * 0.35, 0.0));
	float n2 = vnoise(v_pos * 9.0 - vec3(t * 0.2));
	float fiss = smoothstep(0.46, 0.5, n) - smoothstep(0.5, 0.54, n);
	float rings = pow(abs(sin(v_pos.y * 14.0 + t * 0.8)), 40.0);
	float pulse = 0.5 + 0.5 * sin(t * 1.3);
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.6);
	vec3 shell = calm_color * (0.10 + 0.10 * n2);
	ALBEDO = shell;
	EMISSION = calm_color * (0.16 + 0.18 * pulse * pulse_amount + 0.9 * fresnel) + warm_color * fiss * 0.55 + calm_color * rings * 0.5;
	ROUGHNESS = 0.35;
	METALLIC = 0.0;
}
