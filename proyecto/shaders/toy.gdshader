shader_type spatial;
render_mode diffuse_toon, specular_toon;

// "Toy" shading: banded diffuse light, soft vertical gradient, fresnel rim and
// a glossy balloon highlight on top. Gives every course piece a plastic,
// inflatable Fall Guys look without touching its geometry.

uniform vec4 base_color : source_color = vec4(1.0, 0.42, 0.7, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.85, 0.95, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.55, 0.6, 0.9, 1.0);
uniform float rim_strength : hint_range(0.0, 3.0) = 0.3;
uniform float rim_power : hint_range(0.5, 8.0) = 2.8;
uniform float emission_strength : hint_range(0.0, 2.0) = 0.03;
uniform float gloss : hint_range(0.0, 1.0) = 0.35;
uniform float gradient_amount : hint_range(0.0, 0.6) = 0.16;
// Glossy "balloon" highlight baked from a fixed key light, so the plastic
// sheen reads even with toon shading and without a reflection probe.
uniform float balloon_sheen : hint_range(0.0, 2.0) = 0.55;
uniform float sheen_power : hint_range(4.0, 96.0) = 26.0;
uniform bool use_vertex_color = false;

varying vec3 local_vertex;

void vertex() {
	local_vertex = VERTEX;
}

void fragment() {
	vec3 tint = mix(
		vec3(1.0 - gradient_amount) * shadow_tint.rgb,
		vec3(1.0 + gradient_amount),
		clamp(local_vertex.y * 0.9 + 0.5, 0.0, 1.0)
	);
	vec3 base = base_color.rgb;
	if (use_vertex_color) {
		base *= COLOR.rgb;
	}
	ALBEDO = base * tint;
	ROUGHNESS = mix(0.55, 0.03, gloss);
	METALLIC = 0.0;
	SPECULAR = mix(0.55, 0.95, gloss);

	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	vec3 key_dir = normalize(vec3(-0.35, 0.85, 0.4));
	float sheen = pow(clamp(dot(normalize(NORMAL), key_dir), 0.0, 1.0), sheen_power);
	EMISSION = rim_color.rgb * fresnel * rim_strength
		+ base * emission_strength
		+ mix(vec3(1.0), rim_color.rgb, 0.35) * sheen * balloon_sheen * gloss;
}
