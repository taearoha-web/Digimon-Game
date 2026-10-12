shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float fade = 0.0;
uniform float age = 0.0;
uniform float pulse = 0.0;
void fragment() {
	float edge = pow(max(0.0, sin(UV.y * 3.141593)), 1.7);
	float ends = pow(max(0.0, sin(UV.x * 3.141593)), 0.7);
	float wisps = 0.6 + 0.4 * sin(UV.x * 42.0 + sin(UV.y * 11.0) - age * 1.7);
	ALBEDO = mix(vec3(0.23,0.26,0.30), vec3(0.68,0.71,0.75), UV.y) + vec3(0.09) * pulse;
	ALPHA = edge * ends * wisps * fade * 0.40;
}
