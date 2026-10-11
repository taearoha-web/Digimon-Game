shader_type spatial;
// The glow of a summoned spirit, drawn over its body: a pulsing rim in the
// summon's colour so allies read as ethereal, never as wild monsters.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.5, 1.0, 0.8, 1.0);
uniform float strength = 1.2;

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float pulse = 0.72 + 0.28 * sin(TIME * 3.2);
	ALBEDO = color.rgb * (fres * strength * pulse + 0.08);
	ALPHA = clamp(fres + 0.1, 0.0, 1.0);
}
