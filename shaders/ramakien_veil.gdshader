shader_type spatial;
// RamakienArt's dusk: while a Ramakien giant is manifest the field dims and warms (a
// veil of dark amber over the whole screen, deeper at the edges), so its gold light
// reads. Drawn first among the transparent pieces (render_priority), it darkens the
// opaque world and the sky only; the giant and the skill's light are drawn after it.
// A mix, not a multiply: the Compatibility renderer tonemaps each draw, so a multiply
// by "white" would still darken.
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.2, 0.1, 0.035, 1.0);
uniform float strength = 0.4;
uniform float fade = 0.0;
uniform float age = 0.0;
uniform float opacity = 1.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 0.5, 1.0);
}

void fragment() {
	vec2 p = SCREEN_UV * 2.0 - 1.0;
	float vig = smoothstep(0.3, 1.5, length(p * vec2(0.9, 1.15)));
	ALBEDO = tint.rgb * (1.0 - 0.6 * vig);
	ALPHA = clamp(strength * fade * opacity * (0.8 + 0.45 * vig), 0.0, 0.9);
}
