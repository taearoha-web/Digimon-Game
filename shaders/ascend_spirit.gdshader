shader_type spatial;
// The ★500 spirit bodies (AscendUlt scripts: the Priest's guardian angel, the Summoner's
// fused chimera): a two-band cartoon light that never depends on the scene's lamps (unshaded,
// so it reads the same in every zone and in the Compatibility renderer), a bright rim of
// the core colour, an optional flash to the core (glow) and a fade for arrivals and exits.
render_mode blend_mix, depth_draw_always, cull_back, unshaded, shadows_disabled;

uniform vec4 body : source_color = vec4(0.23, 0.94, 0.63, 1.0);
uniform vec4 core : source_color = vec4(0.91, 1.0, 0.96, 1.0);
uniform vec4 shade : source_color = vec4(0.04, 0.23, 0.23, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform float rim_width : hint_range(0.5, 6.0) = 2.4;

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	vec3 l = normalize((VIEW_MATRIX * vec4(0.35, 0.85, 0.4, 0.0)).xyz);
	float d = dot(n, l);
	float band = smoothstep(-0.08, 0.04, d) * 0.62 + smoothstep(0.52, 0.62, d) * 0.38;
	vec3 col = mix(shade.rgb, body.rgb, 0.3 + 0.7 * band);
	float rim = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), rim_width);
	col = mix(col, core.rgb, smoothstep(0.3, 0.75, rim));
	col = mix(col, core.rgb, glow);
	ALBEDO = col;
	ALPHA = fade;
}
