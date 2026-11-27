shader_type spatial;
// The ink outline round a gate giant of ดินแดนเทวาลัย (HeavenYaksha): the inverted hull of
// the posed body (the same bones), grown along its normals, its back faces drawn dark. It
// goes as soon as the giant starts to dissolve.
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;
#include "res://shaders/heaven_yaksha_pose.gdshaderinc"

uniform vec4 color : source_color = vec4(0.06, 0.16, 0.16, 1.0);
uniform float width = 0.005;

void vertex() {
	vec3 p = VERTEX;
	vec3 n = NORMAL;
	pose_part(p, n, UV2.y);
	VERTEX = p + n * width;
	NORMAL = n;
}

void fragment() {
	if (fade < 0.97) {
		discard;
	}
	ALBEDO = color.rgb;
}
