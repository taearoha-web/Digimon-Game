shader_type spatial;
// The Muay Thai fighter's painted skill art (MuayThaiArt): flat cartoon colour that
// keeps its hue on a sunny field instead of adding up to white.
// COLOR.r picks the tone, COLOR.g is the opacity mask, COLOR.b picks the ramp:
//   0 the layer's own palette (primary / accent / shade), 0.5 the second ramp (_b),
//   1 the third (_c), so one painted figure (RamakienArt: หนุมาน, ทศกัณฐ์) can wear
//   its skin, its gold and its red in one draw. Every older piece has b = 0.
//   ink (glow = 0): a three-stop cel ramp, 0 = the dark outline (shade), 0.5 = the body
//                   (primary), 1 = the highlight (accent); a dark rim on round pieces.
//   light (glow = 1): luminous paint from the primary colour to the accent core (r²),
//                   with a heat shimmer running through the hot parts.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform vec4 primary : source_color = vec4(1.0, 0.48, 0.1, 1.0);
uniform vec4 accent : source_color = vec4(1.0, 0.9, 0.5, 1.0);
uniform vec4 shade : source_color = vec4(0.35, 0.07, 0.03, 1.0);
uniform vec4 primary_b : source_color = vec4(0.91, 0.63, 0.09, 1.0);
uniform vec4 accent_b : source_color = vec4(1.0, 0.94, 0.66, 1.0);
uniform vec4 shade_b : source_color = vec4(0.35, 0.14, 0.02, 1.0);
uniform vec4 primary_c : source_color = vec4(0.85, 0.13, 0.16, 1.0);
uniform vec4 accent_c : source_color = vec4(1.0, 0.6, 0.42, 1.0);
uniform vec4 shade_c : source_color = vec4(0.23, 0.02, 0.03, 1.0);
uniform float fade = 1.0;
uniform float age = 0.0;
uniform float opacity = 0.9;
uniform float glow = 0.0;
varying vec3 local;
void vertex() { local = VERTEX; }
void fragment() {
	float r = clamp(COLOR.r, 0.0, 1.0);
	float mask = clamp(COLOR.g, 0.0, 1.0);
	float wc = step(0.75, COLOR.b);
	float wb = step(0.25, COLOR.b) - wc;
	float wa = 1.0 - wb - wc;
	vec3 p = primary.rgb * wa + primary_b.rgb * wb + primary_c.rgb * wc;
	vec3 a = accent.rgb * wa + accent_b.rgb * wb + accent_c.rgb * wc;
	vec3 s = shade.rgb * wa + shade_b.rgb * wb + shade_c.rgb * wc;
	vec3 cel = r < 0.5 ? mix(s, p, r * 2.0) : mix(p, a, r * 2.0 - 1.0);
	float rim = pow(max(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0), 2.4);
	cel = mix(cel, s, rim * 0.6 * (1.0 - r));
	float shimmer = 0.5 + 0.5 * sin(local.x * 7.0 + local.y * 9.0 + local.z * 5.0 - age * 11.0);
	vec3 light = mix(p, a, r * r);
	light = mix(light, a, shimmer * 0.22 * smoothstep(0.35, 0.9, r));
	float grain = 0.5 + 0.5 * sin(local.x * 19.0 + local.y * 13.0 - age * 3.0) * sin(local.z * 15.0 + local.x * 9.0);
	float dissolve = smoothstep((1.0 - fade) * 1.1 - 0.1, (1.0 - fade) * 1.1 + 0.1, grain);
	ALBEDO = mix(cel, light, glow);
	ALPHA = opacity * mask * dissolve * smoothstep(0.0, 0.1, fade);
}
