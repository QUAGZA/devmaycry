// Map surface family: triplanar value-noise variation, plate seams on horizontal faces and edge wear.
// Colour families are set per map through the uniforms; one shader serves ceramic, stone and metal.
shader_type spatial;
render_mode blend_mix, cull_back;

uniform vec4 albedo : source_color = vec4(0.9, 0.86, 0.78, 1.0);
uniform vec4 accent : source_color = vec4(0.78, 0.72, 0.62, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float tile = 0.35;
uniform float wear : hint_range(0.0, 1.0) = 0.5;
uniform float seams : hint_range(0.0, 1.0) = 0.6;

varying vec3 wpos;
varying vec3 wnrm;

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
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float n = vnoise(wpos * tile);
	float n2 = vnoise(wpos * tile * 4.3 + 17.0);
	float n3 = vnoise(wpos * tile * 12.0 + 41.0);
	float top = smoothstep(0.55, 0.9, wnrm.y);
	float gx = step(0.985, fract(wpos.x * 0.5)) + step(0.985, fract(wpos.z * 0.5));
	float plate = clamp(gx, 0.0, 1.0) * top * seams;
	vec3 col = mix(albedo.rgb, accent.rgb, clamp(n * 0.7 + n2 * 0.25 - 0.1, 0.0, 1.0));
	col = mix(col, col * 0.78, plate);
	col = mix(col, col * 1.06, n3 * 0.5 * wear);
	ALBEDO = col;
	ROUGHNESS = clamp(roughness - n2 * 0.18 * wear, 0.05, 1.0);
	METALLIC = metallic;
}
