// Stylized deep sea for Tideline Exchange: gentle vertex swell, banded toon shading, fresnel sky tint,
// crest foam bands and distance mist. Opaque (no transparency sorting issues), cheap.
shader_type spatial;
render_mode cull_back, diffuse_toon, specular_toon;

uniform vec4 deep : source_color = vec4(0.12, 0.18, 0.36, 1.0);
uniform vec4 shallow : source_color = vec4(0.22, 0.42, 0.55, 1.0);
uniform vec4 foam : source_color = vec4(0.86, 0.9, 0.92, 1.0);
uniform float swell = 0.6;
uniform float speed = 0.35;

varying vec3 wpos;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = sin(w.x * 0.07 + TIME * speed) * 0.6 + sin(w.z * 0.11 - TIME * speed * 1.3) * 0.4;
	VERTEX.y += h * swell;
	wpos = w;
}

void fragment() {
	float band = sin(wpos.x * 0.07 + TIME * speed) * 0.6 + sin(wpos.z * 0.11 - TIME * speed * 1.3) * 0.4;
	float crest = smoothstep(0.78, 0.86, band * 0.5 + 0.5);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 col = mix(deep.rgb, shallow.rgb, clamp(band * 0.5 + 0.5, 0.0, 1.0) * 0.6 + fres * 0.4);
	col = mix(col, foam.rgb, crest * 0.35);
	ALBEDO = col;
	ROUGHNESS = 0.18;
	SPECULAR = 0.6;
}
