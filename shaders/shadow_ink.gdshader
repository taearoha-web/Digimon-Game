shader_type spatial;
// The Assassin's shadow sculptures (ShadowSkillArt): a dark, slowly churning
// body with a violet rim, bright inlays (eyes, blade edges, rims) in the accent
// colour and a grainy dissolve on fade. COLOR.r = inlay, COLOR.g = opacity mask.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform vec4 primary : source_color = vec4(0.6, 0.42, 1.0, 1.0);
uniform vec4 accent : source_color = vec4(0.95, 0.9, 1.0, 1.0);
uniform vec4 shade : source_color = vec4(0.1, 0.05, 0.18, 1.0);
uniform float fade = 1.0;
uniform float age = 0.0;
uniform float opacity = 0.9;
varying vec3 local;
void vertex() { local = VERTEX; }
void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.2);
	float inlay = clamp(COLOR.r, 0.0, 1.0);
	float churn = 0.5 + 0.5 * sin(local.y * 9.0 - age * 6.0 + sin(local.x * 7.0 + age * 2.0) * 1.5);
	vec3 body = mix(shade.rgb, primary.rgb * 0.55, churn * 0.35 + rim * 0.2);
	vec3 ink = mix(body, primary.rgb, rim * 0.85);
	ink = mix(ink, accent.rgb, inlay);
	float grain = 0.5 + 0.5 * sin(local.x * 21.0 + local.y * 15.0 + age * 2.0) * sin(local.z * 17.0 - local.y * 11.0);
	float dissolve = smoothstep((1.0 - fade) * 1.15 - 0.12, (1.0 - fade) * 1.15 + 0.08, grain);
	ALBEDO = ink;
	EMISSION = primary.rgb * rim * 0.6 + accent.rgb * inlay * 0.9;
	ALPHA = opacity * mix(0.75 + rim * 0.25, 1.0, inlay) * clamp(COLOR.g + inlay, 0.0, 1.0) * dissolve * smoothstep(0.0, 0.12, fade);
}
