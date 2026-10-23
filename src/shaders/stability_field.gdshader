// Stability Field floor glyph: ring, rotating calibration ticks and an arc that shows remaining protection.
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

uniform vec4 color : source_color = vec4(0.47, 0.79, 0.68, 1.0);
uniform vec4 spent_color : source_color = vec4(0.73, 0.69, 0.64, 1.0);
uniform float remaining : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float r = length(uv) * 2.0;
	float ang = atan(uv.y, uv.x);
	float a01 = (ang + PI) / (2.0 * PI);
	float outer = smoothstep(0.962, 0.975, r) - smoothstep(0.99, 1.0, r);
	float inner = smoothstep(0.46, 0.47, r) - smoothstep(0.485, 0.495, r);
	float arc = (smoothstep(0.86, 0.875, r) - smoothstep(0.925, 0.94, r)) * step(a01, remaining);
	float ticks = pow(abs(sin(ang * 36.0 + TIME * 0.6)), 40.0) * (smoothstep(0.52, 0.56, r) - smoothstep(0.62, 0.66, r));
	float fill = (1.0 - smoothstep(0.0, 1.0, r)) * 0.08;
	vec3 col = mix(spent_color.rgb, color.rgb, step(0.001, remaining));
	float a = (outer * 1.6 + inner * 0.8 + arc * 1.8 + ticks * 0.8 + fill) * step(r, 1.0);
	ALBEDO = col;
	EMISSION = col * a * 1.6;
	ALPHA = clamp(a, 0.0, 0.9);
}
