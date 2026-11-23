shader_type spatial;
// The Muay Thai fighter's painted skill art (MuayThaiArt): flat cartoon colour that
// keeps its hue on a sunny field instead of adding up to white.
// COLOR.r picks the tone, COLOR.g is the opacity mask.
//   ink (glow = 0): a three-stop cel ramp, 0 = the dark outline (shade), 0.5 = the body
//                   (primary), 1 = the highlight (accent); a dark rim on round pieces.
//   light (glow = 1): luminous paint from the primary colour to the accent core (r²),
//                   with a heat shimmer running through the hot parts.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform vec4 primary : source_color = vec4(1.0, 0.48, 0.1, 1.0);
uniform vec4 accent : source_color = vec4(1.0, 0.9, 0.5, 1.0);
uniform vec4 shade : source_color = vec4(0.35, 0.07, 0.03, 1.0);
uniform float fade = 1.0;
uniform float age = 0.0;
uniform float opacity = 0.9;
uniform float glow = 0.0;
varying vec3 local;
void vertex() { local = VERTEX; }
void fragment() {
	float r = clamp(COLOR.r, 0.0, 1.0);
	float mask = clamp(COLOR.g, 0.0, 1.0);
	vec3 cel = r < 0.5 ? mix(shade.rgb, primary.rgb, r * 2.0) : mix(primary.rgb, accent.rgb, r * 2.0 - 1.0);
	float rim = pow(max(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0), 2.4);
	cel = mix(cel, shade.rgb, rim * 0.6 * (1.0 - r));
	float shimmer = 0.5 + 0.5 * sin(local.x * 7.0 + local.y * 9.0 + local.z * 5.0 - age * 11.0);
	vec3 light = mix(primary.rgb, accent.rgb, r * r);
	light = mix(light, accent.rgb, shimmer * 0.22 * smoothstep(0.35, 0.9, r));
	float grain = 0.5 + 0.5 * sin(local.x * 19.0 + local.y * 13.0 - age * 3.0) * sin(local.z * 15.0 + local.x * 9.0);
	float dissolve = smoothstep((1.0 - fade) * 1.1 - 0.1, (1.0 - fade) * 1.1 + 0.1, grain);
	ALBEDO = mix(cel, light, glow);
	ALPHA = opacity * mask * dissolve * smoothstep(0.0, 0.1, fade);
}
