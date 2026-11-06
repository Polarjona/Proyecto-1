shader_type spatial;
render_mode unshaded, cull_disabled;

// Soft pastel "cloud sea" far below the course. It fills the void the player
// falls into and gives the floating track a sense of height.

uniform vec3 deep_color : source_color = vec3(0.1, 0.22, 0.52);
uniform vec3 mid_color : source_color = vec3(0.3, 0.5, 0.86);
uniform vec3 foam_color : source_color = vec3(0.76, 0.86, 1.0);
uniform float wave_height : hint_range(0.0, 4.0) = 1.4;
uniform float wave_scale : hint_range(0.01, 0.5) = 0.07;
uniform float flow_speed : hint_range(0.0, 2.0) = 0.45;

varying vec3 world_position;
varying float wave_amplitude;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * flow_speed;
	float h = sin(wp.x * wave_scale + t) * 0.5
		+ sin(wp.z * wave_scale * 1.31 - t * 1.2) * 0.35
		+ sin((wp.x + wp.z) * wave_scale * 0.63 + t * 0.8) * 0.3;
	VERTEX.y += h * wave_height;
	world_position = wp;
	wave_amplitude = h;
}

void fragment() {
	float h = clamp(wave_amplitude * 0.5 + 0.5, 0.0, 1.0);
	vec3 col = mix(deep_color, mid_color, smoothstep(0.12, 0.78, h));
	float crest = smoothstep(0.74, 1.0, h);
	col = mix(col, foam_color, crest * 0.35);

	float bands = sin(world_position.x * 0.16 + world_position.z * 0.11 + TIME * 0.55) * 0.5 + 0.5;
	col += foam_color * pow(bands, 6.0) * 0.03;

	ALBEDO = col;
	EMISSION = foam_color * crest * 0.06 + mid_color * 0.02;
}
