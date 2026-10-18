shader_type spatial;
// A soft shaft of light (VfxKit.pillar): no cylinder silhouette, only glow.
// Alpha falls off up the column (UV.y 0 at the foot, 1 at the top), the
// bright core sits where the surface faces the camera and dies out towards
// the silhouette, a thin rim glows just inside the edge, energy scrolls
// upward and a flared ring burns at the foot. Additive, so stacked columns
// and crossing shafts brighten instead of turning into opaque slabs.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform vec4 core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float falloff = 2.8;
uniform float flow = 1.4;
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float v = UV.y;
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float height = pow(1.0 - v, falloff) * smoothstep(0.0, 0.02, v);
	// Two scrolling bands of energy climb the shaft.
	float t = TIME * flow + seed;
	float n = noise(vec2(UV.x * 5.0 + seed, v * 4.0 - t)) * 0.6 + noise(vec2(UV.x * 11.0 - seed, v * 9.0 - t * 1.7)) * 0.4;
	float body = pow(facing, 2.0) * (0.4 + 0.6 * n);
	float rim = smoothstep(0.08, 0.28, facing) * (1.0 - smoothstep(0.28, 0.55, facing)) * 0.35;
	float foot = (1.0 - smoothstep(0.015, 0.09, v)) * smoothstep(0.0, 0.015, v) * (0.3 + 0.4 * facing);
	// Both faces of the open shaft add up, so each one stays well under half.
	float energy = ((body + rim) * height + foot) * 0.58;
	float hot = clamp(pow(facing, 5.0) * height * (0.4 + 0.6 * n) * 0.8 + foot * 0.25, 0.0, 0.85);
	ALBEDO = mix(color.rgb, core.rgb, hot);
	ALPHA = clamp(energy, 0.0, 1.0) * fade * color.a;
}
