// Fast-Forward Entropy: contained ground ring with compressed forward-moving linework and a brief ripple.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

uniform vec4 color : source_color = vec4(1.0, 0.36, 0.24, 1.0);
uniform float life : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float r = length(uv) * 2.0;
	float ang = atan(uv.y, uv.x);
	float ring = smoothstep(0.955, 0.98, r) - smoothstep(0.985, 1.0, r);
	float spokes = pow(abs(sin(ang * 28.0 - TIME * 14.0)), 24.0) * smoothstep(0.25, 1.0, r) * 0.45;
	float wave = fract(r * 2.5 - TIME * 3.0);
	float sweep = smoothstep(0.0, 0.04, wave) * (1.0 - smoothstep(0.04, 0.22, wave)) * 0.6;
	float ripple = (1.0 - smoothstep(0.0, 0.12, abs(r - clamp(life * 1.4, 0.0, 1.0)))) * (1.0 - life);
	float a = (ring * 2.2 + spokes + sweep + ripple * 1.5) * step(r, 1.0) * (1.0 - life * 0.6);
	ALBEDO = color.rgb;
	EMISSION = color.rgb * a * 2.5;
	ALPHA = clamp(a, 0.0, 1.0);
}
