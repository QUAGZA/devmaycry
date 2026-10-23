// Phase Gate surface: layered animated dimensional disc with an honest destination glyph ring.
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled;

uniform vec4 color_a : source_color = vec4(0.47, 0.79, 0.68, 1.0);
uniform vec4 color_b : source_color = vec4(0.35, 0.42, 0.75, 1.0);

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float r = length(uv) * 2.0;
	float ang = atan(uv.y, uv.x);
	float swirl = sin(r * 14.0 - TIME * 2.2 + ang * 3.0) * 0.5 + 0.5;
	float rings = pow(abs(sin(r * 9.0 - TIME * 1.4)), 10.0);
	float rim = smoothstep(0.9, 0.97, r) - smoothstep(0.985, 1.0, r);
	float core = 1.0 - smoothstep(0.0, 0.35, r);
	vec3 col = mix(color_b.rgb, color_a.rgb, swirl);
	float a = (0.35 + swirl * 0.25 + rings * 0.4 + rim * 1.5 + core * 0.3) * step(r, 1.0);
	ALBEDO = col;
	EMISSION = col * (0.6 + rings * 1.2 + rim * 1.8);
	ALPHA = clamp(a, 0.0, 0.92);
}
