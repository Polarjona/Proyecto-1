shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_toon;

// Franjas diagonales de peligro, inspiradas en las zonas naranjas de
// Spin Go Round. Se aplican a tiras finas sobre el suelo y a los bordes de
// las plataformas; no necesitan UV porque usan coordenadas de mundo.

uniform vec4 color_a : source_color = vec4(1.0, 0.42, 0.04, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.93, 0.72, 1.0);
uniform float stripe_width : hint_range(0.1, 2.0) = 0.45;
uniform float angle : hint_range(0.0, 3.1416) = 0.785;
uniform float emission_strength : hint_range(0.0, 1.0) = 0.18;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float diagonal = sin(angle) * world_position.x + cos(angle) * world_position.z;
	float band = step(0.5, fract(diagonal / max(stripe_width, 0.01)));
	vec3 col = mix(color_a.rgb, color_b.rgb, band);
	ALBEDO = col;
	ROUGHNESS = 0.3;
	SPECULAR = 0.8;
	EMISSION = col * emission_strength;
}
