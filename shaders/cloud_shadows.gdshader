shader_type spatial;
// Drifting cloud shadows (SkyArt): a plane just over the ground, a cool shade colour
// alpha-blended in soft blotches (two octaves of value noise, scrolling with the wind).
// They thin out toward the plane's rim and the far distance so its edge never shows.
// (Alpha blending, not multiply: the Compatibility renderer's multiply blend darkens
// the whole ground under the plane.)
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float depth = 0.18;
uniform vec3 shade : source_color = vec3(0.16, 0.2, 0.34);
uniform vec2 wind = vec2(0.9, 0.35);
uniform float scale = 0.022;
varying vec3 v_world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_world.xz * scale + wind * TIME * 0.01;
	float n = noise(p) * 0.65 + noise(p * 2.3 + 7.1) * 0.35;
	float blot = smoothstep(0.52, 0.66, n);
	float rim = 1.0 - smoothstep(0.35, 0.5, length(UV - vec2(0.5)));
	float far = 1.0 - smoothstep(45.0, 90.0, length(v_world - CAMERA_POSITION_WORLD));
	ALBEDO = shade;
	ALPHA = clamp(blot * rim * far * depth * 1.6, 0.0, 1.0);
}
