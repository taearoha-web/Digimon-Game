shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
// Translucent holographic pillar with rising data lines.

uniform vec4 tint : source_color = vec4(0.25, 0.85, 1.0, 1.0);
uniform float speed = 0.5;

void fragment() {
	float lines = step(0.92, fract(UV.y * 18.0 - TIME * speed));
	float columns = step(0.9, fract(UV.x * 12.0));
	float fade = 1.0 - UV.y;
	float glow = 0.18 + lines * 0.6 + columns * 0.2;
	ALBEDO = tint.rgb * glow;
	ALPHA = clamp(glow * fade, 0.0, 1.0);
}
