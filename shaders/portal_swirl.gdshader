shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
// Swirling gateway surface. Cheap: no textures, a few trig calls.

uniform vec4 tint : source_color = vec4(0.25, 0.9, 1.0, 1.0);
uniform float intensity = 1.2;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float swirl = sin(a * 5.0 + r * 12.0 - TIME * 3.0) * 0.5 + 0.5;
	float rings = sin(r * 26.0 - TIME * 4.0) * 0.5 + 0.5;
	float mask = smoothstep(1.0, 0.75, r);
	float core = exp(-r * r * 6.0);
	vec3 col = tint.rgb * (swirl * 0.6 + rings * 0.25 + core * 1.2);
	ALBEDO = col * intensity * mask;
	ALPHA = mask;
}
