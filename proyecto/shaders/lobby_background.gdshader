shader_type canvas_item;
render_mode unshaded;

// Fondo del lobby: campo cobalto plano. Un único foco radial detrás de la
// peana y un emblema de estrella en un solo tono, casi imperceptible; el
// confeti queda en dos tonos y muy bajo. El protagonista es el corredor.

uniform vec4 cobalt : source_color = vec4(0.031, 0.094, 0.231, 1.0);
uniform vec4 royal : source_color = vec4(0.043, 0.165, 0.435, 1.0);
uniform vec4 deep : source_color = vec4(0.024, 0.071, 0.18, 1.0);
uniform vec4 ice : source_color = vec4(0.937, 0.98, 1.0, 1.0);
uniform vec4 sun : source_color = vec4(1.0, 0.824, 0.247, 1.0);
uniform vec2 burst_center = vec2(0.5, 0.52);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 p = uv - burst_center;
	p.x *= 1.7;
	float r = length(p);
	float angle = atan(p.y, p.x);

	// Campo cobalto plano: sin degradado diagonal a pantalla completa.
	vec3 col = cobalt.rgb;

	// Una sola luz radial, en el mismo tono, detrás de la peana.
	float spotlight = 1.0 - smoothstep(
		0.0, 0.58, length((uv - burst_center) * vec2(1.25, 1.0))
	);
	col = mix(col, royal.rgb, spotlight * 0.22);

	// Emblema de diez puntas en una sola tinta: sin borde ni aureola.
	float star_edge = 0.195 + 0.032 * cos(angle * 10.0 + 0.4)
		+ 0.008 * cos(angle * 20.0 - 0.7);
	float star = 1.0 - smoothstep(star_edge - 0.006, star_edge + 0.006, r);
	col = mix(col, royal.rgb, star * 0.35);

	// Confeti de dos tonos, separado y escaso.
	vec2 cells = vec2(28.0, 16.0);
	vec2 cell = floor(uv * cells);
	vec2 local = fract(uv * cells) - 0.5;
	float h = hash(cell);
	float diamond = 1.0 - smoothstep(0.10, 0.16, abs(local.x) + abs(local.y));
	float confetti = step(0.982, h) * diamond;
	vec3 confetti_color = h < 0.68 ? sun.rgb : ice.rgb;
	col = mix(col, confetti_color, confetti * 0.34);

	// Viñeta tenue para cerrar los bordes sin oscurecer el centro.
	float vignette = smoothstep(0.68, 1.15, length((uv - 0.5) * vec2(1.15, 1.0)));
	col = mix(col, deep.rgb, vignette * 0.16);

	COLOR = vec4(col, 1.0);
}
