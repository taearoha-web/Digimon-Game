shader_type spatial;
// A painted ribbon: saturated body, a narrow pearl edge and transparent tips.
// UV.x follows each stroke; UV.y spans its width. No screen texture or noise
// samples, so the same silhouette remains affordable in mobile Compatibility.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 ink : source_color = vec4(0.4, 0.7, 0.8, 1.0);
uniform vec4 pearl : source_color = vec4(0.9, 0.95, 0.8, 1.0);
uniform vec4 shade : source_color = vec4(0.3, 0.4, 0.6, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	float edge = 1.0 - smoothstep(0.58, 1.0, across);
	float ends = smoothstep(0.0, 0.05, UV.x) * (1.0 - smoothstep(0.91, 1.0, UV.x));
	float reveal = 1.0 - smoothstep(progress, progress + 0.15, UV.x);
	float grain = 0.93 + 0.07 * sin(UV.x * 92.0 + UV.y * 14.0);
	float thread = 1.0 - smoothstep(0.035, 0.13, abs(UV.y - 0.32));
	vec3 body = mix(shade.rgb, ink.rgb, 0.48 + 0.52 * edge);
	ALBEDO = mix(body, pearl.rgb, thread * 0.82);
	ALPHA = edge * ends * reveal * fade * ink.a * grain;
}
