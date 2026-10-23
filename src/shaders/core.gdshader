// Causal Core: layered energy shell with fissures and emissive rings that escalate with volatility.
shader_type spatial;
render_mode blend_mix, cull_back;

uniform float volatility : hint_range(0.0, 1.0) = 0.0;
uniform vec3 calm_color : source_color = vec3(0.47, 0.79, 0.68);
uniform vec3 warm_color : source_color = vec3(0.85, 0.70, 0.29);
uniform vec3 hot_color : source_color = vec3(1.0, 0.36, 0.24);
uniform float frozen : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_pos;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash3(i);
	float n100 = hash3(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash3(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash3(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash3(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash3(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash3(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash3(i + vec3(1.0, 1.0, 1.0));
	float x00 = mix(n000, n100, f.x);
	float x10 = mix(n010, n110, f.x);
	float x01 = mix(n001, n101, f.x);
	float x11 = mix(n011, n111, f.x);
	float y0 = mix(x00, x10, f.y);
	float y1 = mix(x01, x11, f.y);
	return mix(y0, y1, f.z);
}

void vertex() {
	v_pos = VERTEX;
}

void fragment() {
	float t = TIME * (1.0 - frozen * 0.9);
	float k = clamp(volatility, 0.0, 1.0);
	vec3 base = k < 0.5 ? mix(calm_color, warm_color, k * 2.0) : mix(warm_color, hot_color, (k - 0.5) * 2.0);
	base = mix(base, vec3(0.35, 0.42, 0.75), frozen);
	float n = vnoise(v_pos * 5.0 + vec3(0.0, t * 0.7, 0.0));
	float n2 = vnoise(v_pos * 11.0 - vec3(t * 0.45));
	float fiss = smoothstep(0.47, 0.5, n) - smoothstep(0.5, 0.53, n);
	float rings = pow(abs(sin(v_pos.y * 18.0 + t * (1.5 + 8.0 * k))), 30.0);
	float pulse = 0.5 + 0.5 * sin(t * (2.0 + 14.0 * k));
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.4);
	ALBEDO = base * 0.3 + vec3(0.93, 0.90, 0.84) * n2 * 0.18;
	EMISSION = base * (1.1 + 2.6 * k * pulse) + vec3(1.0, 0.85, 0.65) * fiss * (1.5 + 6.0 * k) + base * rings * (0.8 + 2.0 * k) + base * fresnel * 1.8;
	ROUGHNESS = 0.22;
	METALLIC = 0.15;
}
