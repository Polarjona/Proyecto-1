shader_type canvas_item;
render_mode unshaded;

// Screen-space grade: chromatic aberration, cool shadows, warm highlights,
// radial speed blur, streaks, vignette, grain and flash. Drawn under the HUD.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float aberration : hint_range(0.0, 0.05) = 0.0015;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
uniform float grain : hint_range(0.0, 1.0) = 0.025;
uniform float speed : hint_range(0.0, 1.0) = 0.0;
uniform float stun : hint_range(0.0, 1.0) = 0.0;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.12;
uniform float contrast : hint_range(0.5, 2.0) = 1.06;
uniform float dithering : hint_range(0.0, 2.0) = 0.7;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 grade(vec3 col) {
	// Cool the shadows, warm the highlights: a cheap split-toning pass.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 shadows = vec3(0.86, 0.94, 1.12);
	vec3 highlights = vec3(1.08, 1.02, 0.94);
	col *= mix(shadows, highlights, smoothstep(0.15, 0.8, luma));
	col = mix(vec3(luma), col, saturation);
	col = (col - 0.5) * contrast + 0.5;
	return max(col, vec3(0.0));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - vec2(0.5);
	float dist = length(centered);
	vec2 direction = centered / max(dist, 0.0001);

	// Radial smear towards the screen edges when moving fast.
	vec3 blur = vec3(0.0);
	float smear = speed * 0.006;
	blur += texture(screen_texture, uv + direction * smear * 0.35).rgb * 0.5;
	blur += texture(screen_texture, uv + direction * smear * 0.75).rgb * 0.3;
	blur += texture(screen_texture, uv + direction * smear).rgb * 0.2;

	vec2 offset = centered * aberration * (0.4 + dist);
	vec3 col;
	col.r = texture(screen_texture, uv + offset).r;
	col.g = texture(screen_texture, uv).g;
	col.b = texture(screen_texture, uv - offset).b;
	col = mix(col, blur, clamp(speed * 0.4, 0.0, 0.5));

	// Stun: desaturate towards a cold tint.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma) * vec3(0.82, 0.96, 1.16), stun * 0.5);

	// Speed streaks radiating from the centre.
	float angle = atan(centered.y, centered.x);
	float streaks = sin(angle * 64.0 + TIME * 8.0) * 0.5 + 0.5;
	streaks = smoothstep(0.86, 1.0, streaks) * smoothstep(0.18, 0.62, dist);
	col += vec3(streaks) * speed * 0.035;

	col = grade(col);

	// Vignette + animated film grain.
	float vig = smoothstep(0.3, 0.78, dist);
	col *= 1.0 - vig * vignette;
	float n = hash(uv * vec2(1920.0, 1080.0) + vec2(TIME * 61.0, TIME * 37.0));
	col += (n - 0.5) * grain;

	// Dithering hides banding on the big flat gradients of the sky.
	col += (hash(uv * vec2(4096.0, 2160.0) + TIME) - 0.5) * dithering / 255.0;

	col = mix(col, flash_color.rgb, clamp(flash_amount, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
