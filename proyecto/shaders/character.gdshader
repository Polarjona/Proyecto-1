shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Plástico de juguete con la saturación del banner. `CharacterCatalog` deja en
// la superficie Face solo las franjas verticales de los ojos y las pinta con
// el color de tinta del juego.

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float gloss : hint_range(0.0, 1.0) = 0.38;
uniform float saturation : hint_range(0.5, 2.0) = 1.08;
uniform float emission_strength : hint_range(0.0, 1.0) = 0.0;


void fragment() {
	vec3 base = albedo_color.rgb;
	float luma = dot(base, vec3(0.299, 0.587, 0.114));
	base = mix(vec3(luma), base, saturation);

	ALBEDO = base;
	// Plástico de juguete: brillo contenido, sin emisión.
	ROUGHNESS = mix(0.76, 0.48, gloss);
	METALLIC = 0.0;
	SPECULAR = mix(0.2, 0.48, gloss);
	EMISSION = base * emission_strength;
}
