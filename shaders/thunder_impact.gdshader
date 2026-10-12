shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float age = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p), a = atan(p.y, p.x);
	float wave = 0.28 + age * 0.66;
	float ring = 1.0 - smoothstep(0.014,0.035,abs(r - wave));
	float fracture = abs(sin(a * 7.0 + sin(r * 19.0) * 0.55));
	float cracks = (1.0 - smoothstep(0.02,0.09,fracture)) * smoothstep(0.1,0.18,r) * (1.0 - smoothstep(0.5,0.87,r));
	float flash = exp(-r * r * 38.0) * (1.0 - age);
	ALBEDO = mix(vec3(0.22,0.66,1.0), vec3(1.0,0.76,0.24), clamp(cracks + flash,0.0,1.0));
	ALPHA = clamp(ring * 0.8 + cracks + flash,0.0,1.0) * (1.0 - smoothstep(0.28,1.0,age));
}
