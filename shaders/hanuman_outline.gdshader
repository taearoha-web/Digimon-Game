shader_type spatial;
// The ink outline round HanumanAvatar's toon body (the inverted hull: the mesh grown along
// its normals, its back faces drawn dark). Gone as soon as the body starts to dissolve.
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 color : source_color = vec4(0.19, 0.16, 0.28, 1.0);
uniform float width = 0.004;
uniform float fade = 1.0;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	// The ink goes first as the body starts to dissolve (no dark hull through the gaps).
	if (fade < 0.97) {
		discard;
	}
	ALBEDO = color.rgb;
}
