shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float age = 0.0;
uniform float fade = 0.0;
void vertex() {
	float angle=UV2.x*6.2831853;
	VERTEX.xz += vec2(cos(angle),sin(angle))*age*(0.9+UV2.y);
	VERTEX.y += age*(1.1+UV2.y*2.0);
}
void fragment() {
	ALBEDO=mix(vec3(1.0,0.64,0.13),vec3(1.0,0.96,0.77),UV2.y);
	ALPHA=fade*(0.68+0.32*sin(UV2.x*37.0+age*3.0));
}
