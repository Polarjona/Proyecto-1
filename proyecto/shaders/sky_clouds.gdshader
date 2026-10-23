shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled;

// Layered procedural sky: saturated zenith, warm horizon, two parallax cloud
// layers and a soft sun disk that matches the DirectionalLight3D.

uniform vec3 top_color : source_color = vec3(0.16, 0.42, 0.92);
uniform vec3 horizon_color : source_color = vec3(0.82, 0.92, 1.0);
uniform vec3 ground_color : source_color = vec3(0.55, 0.68, 0.9);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.94, 0.78);
uniform vec3 sun_direction = vec3(0.5, 0.61, -0.61);
uniform float cloud_opacity : hint_range(0.0, 1.0) = 0.55;
uniform float cloud_scale : hint_range(0.5, 8.0) = 2.6;
uniform float cloud_speed : hint_range(0.0, 1.0) = 0.03;
uniform float sun_size : hint_range(0.9, 1.0) = 0.9991;
uniform float sun_glow : hint_range(0.0, 3.0) = 0.8;
uniform float horizon_warmth : hint_range(0.0, 1.0) = 0.35;

varying vec3 local_dir;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		value += amplitude * noise(p);
		p = p * 2.03 + vec2(7.3, 3.1);
		amplitude *= 0.5;
	}
	return value;
}

void vertex() {
	local_dir = normalize(VERTEX);
}

void fragment() {
	vec3 dir = normalize(local_dir);
	vec3 sun = normalize(sun_direction);

	float h = clamp(dir.y, -1.0, 1.0);
	vec3 col = mix(horizon_color, top_color, smoothstep(0.0, 0.85, h));
	col = mix(col, ground_color, 1.0 - smoothstep(-0.35, -0.02, h));

	// Warm halo around the sun.
	float sd = max(dot(dir, sun), 0.0);
	col += sun_color * pow(sd, 12.0) * horizon_warmth * 0.5;
	col = mix(col, sun_color, smoothstep(0.55, 1.0, sd) * horizon_warmth * 0.25);
	col += sun_color * pow(sd, 220.0) * sun_glow;

	// Two cloud layers at different heights and speeds.
	vec2 sky_uv = dir.xz / max(dir.y + 0.35, 0.06) * 0.55;
	float c1 = fbm(sky_uv * cloud_scale + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.35));
	float c2 = fbm(sky_uv * cloud_scale * 1.9 - vec2(TIME * cloud_speed * 0.7, TIME * cloud_speed * 0.2) + vec2(13.7, 4.2));
	float clouds = smoothstep(0.46, 0.78, c1) * 0.65 + smoothstep(0.55, 0.86, c2) * 0.45;
	clouds *= smoothstep(0.05, 0.35, h);
	vec3 cloud_tint = mix(cloud_color, horizon_color, (1.0 - smoothstep(0.0, 0.35, h)) * 0.4);
	col = mix(col, cloud_tint, clamp(clouds, 0.0, 1.0) * cloud_opacity);

	// Sun disk on top of the clouds.
	float disk = smoothstep(sun_size - 0.0006, sun_size + 0.0006, sd);
	col = mix(col, sun_color, disk);

	// Dither the gradient so the tone mapping does not band.
	col += (hash(FRAGCOORD.xy) - 0.5) * (1.0 / 255.0);

	ALBEDO = col;
	ROUGHNESS = 1.0;
}
