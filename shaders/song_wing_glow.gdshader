shader_type spatial;
// The Bard's wing light (SongWingArt). kind 1: a staff ribbon, five fine gold lines
// on a faint rosy glow, light running along them, the free tail swaying (ends = 1
// fades both ends; the star pair's circular staff has none). kind 2: a note drifting
// off a wing tip, rising and fading, then starting again (UV.x: its phase). Blended,
// not added, and never brighter than its colours, so it holds on bright day maps
// and never washes out the hero; it never writes depth. motion = 0 holds it still.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform vec4 line_color : source_color = vec4(1.0, 0.83, 0.42, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.72, 0.85, 1.0);
uniform float kind = 1.0;
uniform float ends = 1.0;
uniform float lines = 5.0;
uniform float opacity = 1.0;
uniform float motion = 1.0;
varying float fade;

void vertex() {
	fade = 1.0;
	if (kind > 1.5) {
		float ph = fract(TIME * 0.2 + UV.x);
		vec3 rise = vec3(sign(VERTEX.x) * 0.1, 0.3, -0.06) * ph + vec3(sin(TIME * 1.3 + UV.x * 20.0) * 0.025, 0.0, 0.0);
		VERTEX += rise * motion;
		fade = mix(1.0, smoothstep(0.0, 0.15, ph) * (1.0 - smoothstep(0.55, 1.0, ph)), motion);
	} else {
		float tail = smoothstep(0.7, 1.0, UV.x) * ends;
		VERTEX += vec3(0.0, sin(TIME * 1.6 + UV.x * 9.0) * 0.02, cos(TIME * 1.3 + UV.x * 7.0) * 0.016) * tail * motion;
	}
}

void fragment() {
	if (kind > 1.5) {
		ALBEDO = mix(glow_color.rgb, vec3(1.0, 0.97, 0.99), 0.25);
		ALPHA = fade * opacity;
	} else {
		float y = (UV.y - 0.1) / 0.8 * (lines - 1.0);
		float d = abs(fract(y + 0.5) - 0.5);
		float w = max(fwidth(y), 0.001);
		float line = (1.0 - smoothstep(0.07, 0.07 + w * 1.5, d)) * step(-0.3, y) * step(y, lines - 0.7);
		float pulse = pow(max(0.5 + 0.5 * sin(UV.x * 16.0 - TIME * 2.4 * motion), 0.0), 6.0);
		float fadeout = mix(1.0, smoothstep(0.0, 0.05, UV.x) * (1.0 - smoothstep(0.86, 1.0, UV.x)), ends);
		vec3 col = mix(line_color.rgb, vec3(1.0, 0.96, 0.86), pulse * 0.45);
		ALBEDO = mix(glow_color.rgb, col, line);
		ALPHA = clamp(line * (0.85 + 0.15 * pulse) + (1.0 - line) * (0.04 + 0.08 * pulse), 0.0, 1.0) * fadeout * opacity;
	}
}
