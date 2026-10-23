shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

// Inverted-hull outline, used as a `next_pass` on the character body so it
// stays readable against any background.

uniform vec4 outline_color : source_color = vec4(0.18, 0.08, 0.26, 1.0);
uniform float thickness : hint_range(0.0, 0.1) = 0.018;

void vertex() {
	VERTEX += NORMAL * thickness;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
