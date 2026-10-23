shader_type spatial;
render_mode diffuse_toon, specular_toon;

// Stylised course surface: world-space tile grid, cool "grout" lines and a
// glowing energy sweep that travels down the track. Works on CSG blocks
// without needing UVs.

uniform vec3 base_color : source_color = vec3(0.2, 0.55, 1.0);
uniform vec3 accent_color : source_color = vec3(0.65, 0.92, 1.0);
uniform vec3 grout_color : source_color = vec3(0.07, 0.11, 0.28);
uniform float tile_scale : hint_range(0.1, 4.0) = 0.7;
uniform float line_width : hint_range(0.01, 0.2) = 0.045;
uniform float glow_strength : hint_range(0.0, 4.0) = 0.35;
uniform float pulse_speed : hint_range(0.0, 4.0) = 0.8;
uniform float sweep_strength : hint_range(0.0, 2.0) = 0.3;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float grid_line(vec2 p) {
	vec2 f = fract(p);
	vec2 d = min(f, 1.0 - f);
	return 1.0 - smoothstep(0.0, line_width, min(d.x, d.y));
}

void fragment() {
	vec3 n = normalize(world_normal);
	float top = smoothstep(0.55, 0.95, abs(n.y));

	float top_lines = grid_line(world_position.xz * tile_scale);
	float side_lines = grid_line(vec2((world_position.x + world_position.z) * tile_scale, world_position.y * tile_scale));
	float lines = mix(side_lines, top_lines, top);

	float ripple = sin(world_position.z * 0.35 + TIME * pulse_speed) * 0.5 + 0.5;
	float sweep = smoothstep(0.72, 1.0, sin((world_position.z + TIME * 7.0) * 0.28)) * top;

	vec3 color = mix(base_color * 0.7, base_color, 0.55 + 0.45 * top);
	color = mix(color, grout_color, lines * 0.4);
	color += accent_color * lines * 0.06;

	ALBEDO = color;
	ROUGHNESS = 0.55;
	SPECULAR = 0.5;
	EMISSION = accent_color * (lines * 0.25 + sweep * sweep_strength) * glow_strength;
	EMISSION *= 0.72 + 0.28 * ripple;
}
