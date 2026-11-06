shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Personajes con un acabado mate y natural.
// Los cuerpos del pack vienen con materiales planos (sin texturas) y casi
// negros, así que el color llega ya resuelto desde la paleta del catálogo
// (`CharacterCatalog.PALETTES`); el shader solo da un plástico suave: sin
// borde luminoso, sin emisión y con la rugosidad alta, para que parezcan
// personajes normales y no bombillas.

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float gloss : hint_range(0.0, 1.0) = 0.3;
uniform float saturation : hint_range(0.5, 2.0) = 0.94;
uniform float emission_strength : hint_range(0.0, 1.0) = 0.0;


void fragment() {
	vec3 base = albedo_color.rgb;
	float luma = dot(base, vec3(0.299, 0.587, 0.114));
	base = mix(vec3(luma), base, saturation);

	ALBEDO = base;
	// Plástico mate de verdad: nada de borde luminoso ni de chispas.
	ROUGHNESS = mix(0.8, 0.55, gloss);
	METALLIC = 0.0;
	SPECULAR = mix(0.2, 0.45, gloss);
	EMISSION = base * emission_strength;
}
