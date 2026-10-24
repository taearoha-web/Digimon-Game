shader_type spatial;
// The Assassin's cuts and luminous pieces (ShadowSkillArt): additive energy from
// the primary colour to a white-hot accent core, with light streaming along the
// stroke. COLOR.r = core heat, COLOR.g = opacity mask.
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform vec4 primary : source_color = vec4(0.6, 0.42, 1.0, 1.0);
uniform vec4 accent : source_color = vec4(0.95, 0.9, 1.0, 1.0);
uniform vec4 shade : source_color = vec4(0.1, 0.05, 0.18, 1.0);
uniform float fade = 1.0;
uniform float age = 0.0;
uniform float opacity = 0.9;
varying vec3 local;
void vertex() { local = VERTEX; }
void fragment() {
	float core = clamp(COLOR.r, 0.0, 1.0);
	float mask = clamp(COLOR.g, 0.0, 1.0);
	float stream = pow(0.5 + 0.5 * sin(local.x * 10.0 + local.y * 6.0 + local.z * 4.0 - age * 14.0), 6.0);
	vec3 energy = mix(primary.rgb, accent.rgb, core * core) + accent.rgb * stream * 0.3 * mask;
	float grain = 0.5 + 0.5 * sin(local.x * 19.0 + local.y * 13.0 - age * 3.0) * sin(local.z * 15.0 + local.x * 9.0);
	float dissolve = smoothstep((1.0 - fade) * 1.1 - 0.1, (1.0 - fade) * 1.1 + 0.1, grain);
	ALBEDO = energy;
	ALPHA = opacity * mask * dissolve * smoothstep(0.0, 0.1, fade);
}
