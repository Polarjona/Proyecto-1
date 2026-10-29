shader_type spatial;
render_mode diffuse_toon, specular_toon;

// Personajes con el mismo acabado que el circuito: plástico de juguete.
// Los cuerpos del pack vienen con materiales planos (sin texturas), así que el
// shader toma el color de cada superficie, lo satura un poco y le añade brillo
// tipo globo, fresnel y una luz de banda cartoon.

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.22;
uniform float rim_power : hint_range(0.5, 8.0) = 3.2;
uniform float gloss : hint_range(0.0, 1.0) = 0.82;
uniform float saturation : hint_range(0.5, 2.0) = 1.18;
// Sube los colores oscuros hacia el pastel para que no se lean como agujeros.
uniform float pastel_lift : hint_range(0.0, 0.5) = 0.1;
uniform float balloon_sheen : hint_range(0.0, 2.0) = 0.4;
uniform float emission_strength : hint_range(0.0, 1.0) = 0.04;


void fragment() {
	vec3 base = albedo_color.rgb;
	float luma = dot(base, vec3(0.299, 0.587, 0.114));
	base = mix(vec3(luma), base, saturation);
	base = mix(base, vec3(1.0), pastel_lift);

	ALBEDO = base;
	ROUGHNESS = mix(0.5, 0.08, gloss);
	METALLIC = 0.0;
	SPECULAR = mix(0.5, 0.95, gloss);

	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	vec3 key_dir = normalize(vec3(-0.35, 0.85, 0.4));
	float sheen = pow(clamp(dot(normalize(NORMAL), key_dir), 0.0, 1.0), 24.0);
	EMISSION = rim_color.rgb * fresnel * rim_strength
		+ base * emission_strength
		+ vec3(1.0) * sheen * balloon_sheen * gloss;
}
