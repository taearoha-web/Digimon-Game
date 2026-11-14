shader_type spatial;
// The dragon's breath round a Dragon God weapon in the hand (DragonGearArt.breath): one
// small open shell (UV.x around, UV.y up) of jade wisps curling upward, strongest on
// the shell's silhouette so it reads as a soft aura and leaves the weapon clear.
// Blended, not added, and never brighter than its colours, so it holds on bright maps
// and never washes the hero out; it never writes depth. No textures, no lights.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
uniform vec4 breath_color : source_color = vec4(0.36, 1.0, 0.8, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.96, 0.7, 1.0);
uniform float opacity = 0.5;

void vertex() {
	float sway = sin(TIME * 1.7 + UV.y * 5.0 + UV.x * 6.2832);
	VERTEX.xz *= 1.0 + 0.12 * sway * UV.y;
}

void fragment() {
	float a = UV.x * 6.2832;
	float rise = UV.y * 5.0 - TIME * 1.6;
	float w1 = sin(a * 3.0 + rise * 1.3 + sin(rise * 0.7) * 1.5);
	float w2 = sin(a * 2.0 - rise * 0.9 + 1.7);
	float wisps = smoothstep(0.15, 0.95, 0.5 + 0.5 * w1 * w2 + 0.25 * sin(a * 5.0 + rise * 2.0));
	float ends = smoothstep(0.0, 0.22, UV.y) * (1.0 - smoothstep(0.5, 1.0, UV.y));
	vec3 n = normalize(NORMAL);
	float rim = 1.0 - abs(dot(n, normalize(VIEW)));
	rim = rim * rim;
	ALBEDO = mix(breath_color.rgb, hot_color.rgb, wisps * 0.45);
	ALPHA = clamp(wisps * ends * (0.12 + 0.88 * rim) * opacity, 0.0, 1.0);
}
