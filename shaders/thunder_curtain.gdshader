shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// A faint curtain of light falling from the sky ring to the ground, with streaks of
// charge sliding down it. UV.y runs 0 at the ring to 1 at the ground.
uniform float fade = 0.0;
uniform float age = 0.0;
uniform float pulse = 0.0;
uniform vec3 tint = vec3(0.3, 0.5, 1.0);

void fragment() {
	float top = pow(1.0 - UV.y, 1.6);
	float streak = pow(max(0.0, sin(UV.x * 6.2831853 * 18.0 + sin(UV.x * 40.0) * 2.0)), 18.0);
	float slide = smoothstep(0.75, 1.0, fract(UV.y * 1.5 - age * 1.4 + UV.x * 7.0));
	float glow = top * 0.06 + streak * slide * top * 0.45;
	ALBEDO = mix(tint, vec3(1.0), streak * 0.5);
	ALPHA = clamp(glow * fade * (1.0 + pulse * 1.5), 0.0, 1.0);
}
