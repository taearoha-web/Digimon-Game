shader_type spatial;
// The +15 set's aura (EnhanceFx._aura): a shell of rising energy round the whole body in
// the outfit's colour. Bright where the shell turns away from the camera (the body's
// outline), tongues of light licking upwards past the head, the shell itself swaying
// outwards with them. One shared mesh (EnhanceFx._aura_mesh: UV.x round it, UV.y up it),
// animated from TIME: no script runs per frame.
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float energy = 1.6;
uniform float rise = 0.8;
uniform float sway = 0.16;

const float AROUND = 9.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Value noise that wraps every AROUND cells in x (no seam round the shell).
float wnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float x0 = mod(i.x, AROUND);
	float x1 = mod(i.x + 1.0, AROUND);
	float a = hash(vec2(x0, i.y));
	float b = hash(vec2(x1, i.y));
	float c = hash(vec2(x0, i.y + 1.0));
	float d = hash(vec2(x1, i.y + 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Rising streaks: the noise stretched upwards, drifting sideways a little as it climbs.
float flames(vec2 uv, float t) {
	float wobble = wnoise(vec2(uv.x * AROUND, uv.y * 1.5 - t * 0.5)) * 0.35;
	vec2 q = vec2(uv.x * AROUND * 2.0 + wobble * 3.0, uv.y * 2.4 - t);
	return 0.6 * wnoise(q) + 0.4 * wnoise(vec2(uv.x * AROUND * 4.0 - wobble * 4.0, uv.y * 5.0 - t * 1.6));
}

void vertex() {
	float n = flames(UV, TIME * rise);
	VERTEX += NORMAL * (n - 0.4) * sway * smoothstep(0.05, 0.4, UV.y);
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	// Brightest a little inside the outline, fading out at the very edge (no hard line).
	float side = 1.0 - facing;
	float edge = smoothstep(0.05, 0.75, side) * (1.0 - smoothstep(0.8, 1.0, side) * 0.85);
	float t = TIME * rise * 1.4;
	float n = flames(UV, t);
	float h = UV.y;
	// Tongues: the noise cut by a line that climbs with height, so the top is ragged.
	float tongue = smoothstep(0.3 + h * 0.4, 0.62 + h * 0.3, n);
	float foot = smoothstep(0.0, 0.14, h);
	float glow = (edge * 1.1 + 0.05) * (0.15 + 0.85 * tongue) * foot * (1.0 - smoothstep(0.8, 1.0, h));
	float beat = 0.88 + 0.12 * sin(TIME * 2.2);
	vec3 col = mix(color.rgb, mix(color.rgb, vec3(1.0), 0.55), tongue * edge);
	glow *= beat * energy;
	if (glow <= 0.002) {
		discard;
	}
	ALBEDO = col * glow;
	ALPHA = clamp(glow * 0.7, 0.0, 0.85);
}
