// Circular clip with a porcelain rim for the minimap texture.
shader_type canvas_item;

uniform vec4 rim : source_color = vec4(0.95, 0.91, 0.85, 1.0);

void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d) * 2.0;
	vec4 c = texture(TEXTURE, UV);
	float edge = smoothstep(0.985, 1.0, r);
	float ring = smoothstep(0.94, 0.965, r) * (1.0 - edge);
	c.rgb = mix(c.rgb, rim.rgb, ring);
	c.a = mix(c.a, 1.0, ring) * (1.0 - edge);
	COLOR = c;
}
