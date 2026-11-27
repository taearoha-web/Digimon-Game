shader_type spatial;
// The ink outline of ดินแดนเทวาลัย's folk (HeavenFolk): the body's own pose
// (heaven_folk_pose.gdshaderinc), pushed out along the normals and drawn inside out (the builder winds its triangles the other way round, so its back faces are culled) in a warm
// dark ink. The cloud, the lights and the fluttering locks and ribbons wear none.
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;

#include "res://shaders/heaven_folk_pose.gdshaderinc"

uniform float width = 0.012;
uniform vec4 ink : source_color = vec4(0.24, 0.15, 0.1, 1.0);
varying float part_id;

void vertex() {
	rest = VERTEX;
	vec3 p = VERTEX;
	vec3 n = NORMAL;
	folk_pose(p, n, CUSTOM1.w, CUSTOM0.w, COLOR.a);
	bool bare = (CUSTOM1.w > 6.5) || UV2.x > 0.9 || CUSTOM0.w > 0.0 || floor(UV2.y + 0.5) == 3.0 || UV2.y > 9.5;
	// Bare pieces collapse to one point (nothing drawn); the rest grow by the ink's width.
	VERTEX = bare ? vec3(0.0, 0.5, 0.0) : p + normalize(n) * width;
	part_id = CUSTOM1.w;
}

void fragment() {
	if (folk_burn(part_id) < 0.0) discard;
	ALBEDO = ink.rgb;
}
