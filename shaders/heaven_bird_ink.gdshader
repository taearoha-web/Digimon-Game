shader_type spatial;
// The ink outline of HeavenBird's กินรี and ครุฑน้อย (the next pass of heaven_bird.gdshader,
// quality 1 and up): the same pose (heaven_bird_pose.gdshaderinc), the mesh grown along its
// normals and its far side drawn dark (HeavenBird winds its faces
// counter-clockwise seen from outside, so Godot's culled "back" is the near side). Only the closed solids carry it (CUSTOM1.z);
// thin feathers and ribbons collapse out of it. Gone as soon as the body starts to dissolve.
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;

#include "res://shaders/heaven_bird_pose.gdshaderinc"

uniform vec4 color : source_color = vec4(0.3, 0.13, 0.1, 1.0);
uniform float width = 0.014;
uniform float fade = 1.0;

void vertex() {
	vec3 p = VERTEX;
	vec3 n = NORMAL;
	bird_pose(p, n, CUSTOM0, CUSTOM1);
	VERTEX = CUSTOM1.z > 0.5 ? p + normalize(n) * width : vec3(0.0);
}

void fragment() {
	if (fade < 0.97) {
		discard;
	}
	ALBEDO = color.rgb;
}
