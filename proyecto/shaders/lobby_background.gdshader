shader_type canvas_item;
render_mode unshaded;

// Fondo del lobby construido con la paleta de los circuitos:
// cobalto y azul de cielo, cian de pista/hielo, oro de barandilla y
// naranja de lava. El magenta aparece solo en el confeti, como en Pivot.
// Sin rayos ni bandas duras: campos suaves y un borde cian de sticker.

uniform vec4 cobalt : source_color = vec4(0.039, 0.165, 0.373, 1.0);
uniform vec4 royal : source_color = vec4(0.047, 0.235, 0.518, 1.0);
uniform vec4 cyan : source_color = vec4(0.047, 0.894, 0.988, 1.0);
uniform vec4 sky_deep : source_color = vec4(0.039, 0.145, 0.43, 1.0);
uniform vec4 sky_blue : source_color = vec4(0.051, 0.333, 0.788, 1.0);
uniform vec4 sky_cyan : source_color = vec4(0.071, 0.769, 0.894, 1.0);
uniform vec4 abyss : source_color = vec4(0.031, 0.302, 0.345, 1.0);
uniform vec4 ice : source_color = vec4(0.937, 0.98, 1.0, 1.0);
uniform vec4 sun : source_color = vec4(1.0, 0.824, 0.247, 1.0);
uniform vec4 orange : source_color = vec4(1.0, 0.357, 0.102, 1.0);
uniform vec4 magenta : source_color = vec4(0.961, 0.173, 0.525, 1.0);
uniform vec2 burst_center = vec2(0.5, 0.46);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 p = uv - burst_center;
	p.x *= 1.7;
	float r = length(p);
	float angle = atan(p.y, p.x);

	// Cielo de circuito: azul profundo arriba a la izquierda, azul eléctrico
	// en el centro y cian de horizonte abajo a la derecha.
	float diagonal = smoothstep(0.0, 1.0, uv.x * 0.36 + uv.y * 0.64);
	vec3 col = mix(sky_deep.rgb, sky_blue.rgb, smoothstep(0.0, 0.5, diagonal));
	col = mix(col, sky_cyan.rgb, smoothstep(0.34, 0.92, diagonal));

	// Luz de horizonte: el mismo cian frío de los mapas de hielo y de agua,
	// rebajado con un pelín de blanco para que no parezca un foco plano.
	float horizon = 1.0 - smoothstep(0.0, 0.82,
		length((uv - vec2(0.76, 0.78)) * vec2(0.92, 1.12)));
	col = mix(col, mix(sky_cyan.rgb, ice.rgb, 0.25), horizon * 0.12);

	// Esquinas en cobalto/abisal: profundidad sin apagar el campo de color.
	float edge = smoothstep(0.58, 1.28,
		length((uv - burst_center) * vec2(1.28, 1.0)));
	col = mix(col, mix(cobalt.rgb, abyss.rgb, 0.35), edge * 0.13);

	// Estrella central de diez puntas, el emblema que ya funcionaba.
	float star_edge = 0.265 + 0.055 * cos(angle * 10.0 + 0.4)
		+ 0.014 * cos(angle * 20.0 - 0.7);
	float aura = 1.0 - smoothstep(star_edge + 0.005, star_edge + 0.11, r);
	col = mix(col, cyan.rgb, aura * 0.07);

	float star = 1.0 - smoothstep(star_edge - 0.004, star_edge + 0.002, r);
	vec3 disc_color = mix(royal.rgb, cobalt.rgb, smoothstep(0.0, 0.25, r));
	col = mix(col, disc_color, star);
	float rim = 1.0 - smoothstep(0.008, 0.014, abs(r - star_edge));
	col = mix(col, cyan.rgb, rim * 0.95);

	// Brillo cian tenue por dentro del borde.
	col = mix(col, cyan.rgb, smoothstep(0.21, 0.23, r)
		* (1.0 - smoothstep(0.23, 0.25, r)) * 0.18);

	// Confeti de cómic: oro, cian, naranja y magenta de Pivot. Poco y
	// separado, para que el cielo respire.
	vec2 cells = vec2(30.0, 17.0);
	vec2 cell = floor(uv * cells);
	vec2 local = fract(uv * cells) - 0.5;
	float h = hash(cell);
	float diamond = 1.0 - smoothstep(0.12, 0.18,
		abs(local.x) + abs(local.y));
	float confetti = step(0.94, h) * diamond;
	vec3 confetti_color = h < 0.45 ? sun.rgb
		: (h < 0.68 ? cyan.rgb : (h < 0.85 ? orange.rgb : magenta.rgb));
	col = mix(col, confetti_color, confetti * 0.9);

	COLOR = vec4(col, 1.0);
}
