shader_type spatial;
render_mode cull_disabled;

// Cuadros de meta, tipo bandera a cuadros. Se usa en el cartel del arco y en
// la franja del suelo, con distinta densidad y emisión.

uniform vec4 color_a : source_color = vec4(0.07, 0.06, 0.13, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.94, 0.72, 1.0);
uniform vec2 tiles = vec2(16.0, 4.0);
uniform float emission_strength : hint_range(0.0, 2.0) = 0.0;
uniform float gloss : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	vec2 cell = floor(UV * tiles);
	float checker = mod(cell.x + cell.y, 2.0);
	vec3 col = mix(color_a.rgb, color_b.rgb, checker);
	ALBEDO = col;
	METALLIC = 0.05;
	ROUGHNESS = mix(0.85, 0.1, gloss);
	EMISSION = col * emission_strength;
}
