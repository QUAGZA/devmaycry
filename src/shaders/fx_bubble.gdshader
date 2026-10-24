shader_type spatial;
// Soft burst for large cosmetic effects (teleport, rewind, stabilize, detonation): additive rim glow with a faint
// body, so a burst reads as a bubble of light instead of a hard polygon ball and never darkens what is behind it.
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.4, 0.8, 1.0, 1.0);
uniform float fade = 1.0;
uniform float rim_power = 2.2;
uniform float body = 0.10;

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	ALBEDO = tint.rgb * 1.6;
	ALPHA = clamp((body + rim) * fade, 0.0, 1.0);
}
