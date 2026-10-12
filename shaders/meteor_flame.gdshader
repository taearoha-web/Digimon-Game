shader_type spatial;
// Noise erodes a real tapered 3D plume, rather than a camera-facing ribbon.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 ember : source_color = vec4(0.76, 0.085, 0.02, 1.0);
uniform vec4 gold : source_color = vec4(1.0, 0.55, 0.07, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;
uniform float density = 0.85;
varying vec3 flame_position;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y);
}

void vertex() {
	float sway = UV.y * UV.y;
	VERTEX.x += sin(UV.y * 9.0 - TIME * 7.0 + seed) * sway * 0.17;
	VERTEX.z += cos(UV.y * 8.0 - TIME * 6.1 + seed) * sway * 0.15;
	flame_position = VERTEX;
}

void fragment() {
	float n = noise(vec2(UV.x * 9.0 + seed, UV.y * 5.0 - TIME * 3.5));
	float fine = noise(vec2(UV.x * 24.0, UV.y * 15.0 - TIME * 6.0 + seed));
	float tongue = 0.5 + 0.5 * sin(UV.x * 56.55 + n * 5.0 + UV.y * 5.0);
	float end = 1.0 - smoothstep(0.48 + n * 0.35, 1.0, UV.y);
	float broken = smoothstep(0.08, 0.48, n * 0.6 + fine * 0.2 + tongue * 0.35);
	float face = pow(abs(dot(NORMAL, VIEW)), 0.32);
	float heat = clamp((1.0 - UV.y) * 0.68 + tongue * 0.26 + fine * 0.16, 0.0, 1.0);
	ALBEDO = mix(ember.rgb, gold.rgb, heat);
	ALPHA = end * broken * mix(0.18, 0.88, face) * fade * density;
}
