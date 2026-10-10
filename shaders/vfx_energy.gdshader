shader_type spatial;
// Scrolling energy for skill effects: flowing noise instead of flat colour.
// mode 0 = ring on a ground quad (polar UV), mode 1 = band along a mesh's U
// (slash crescents, trails). Animated by TIME and by `progress` (0 -> 1) from a tween.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform vec4 core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int mode = 0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float ring_radius = 0.78;
uniform float ring_width = 0.16;
uniform float flow = 1.6;
uniform float swirl = 0.0;
uniform float noise_scale = 5.0;
uniform float fill = 0.12;
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

// Two octaves are plenty and stay cheap on phones.
float fbm(vec2 p) {
	return noise(p) * 0.65 + noise(p * 2.13 + 7.1) * 0.35;
}

void fragment() {
	float t = TIME * flow + seed;
	float energy = 0.0;
	if (mode == 0) {
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		float a = atan(p.y, p.x) / 6.2831853 + 0.5 + swirl * TIME * 0.15;
		float n = fbm(vec2(a * noise_scale * 2.0, r * noise_scale - t));
		float n2 = fbm(vec2(a * noise_scale * 5.0 + t * 0.3, r * noise_scale * 2.0 - t * 1.7));
		// The ring thins and grows a little as it plays out; noise tears its edge into flames.
		float rr = ring_radius + progress * 0.12;
		float w = ring_width * (1.0 - progress * 0.6) * (0.6 + 0.8 * n);
		float d = r - rr;
		float band = 1.0 - smoothstep(0.0, w, abs(d) + (d < 0.0 ? 0.0 : (n2 - 0.4) * w));
		band *= smoothstep(0.15 + progress * 0.45, 0.6 + progress * 0.3, n2 + 0.25);
		float inner = (1.0 - smoothstep(0.0, rr, r)) * fill * smoothstep(0.35, 0.9, n);
		energy = band * (0.7 + 0.8 * n) + inner;
		energy *= 1.0 - smoothstep(0.92, 1.0, r);
	} else {
		float u = UV.x;
		float v = UV.y;
		float n = fbm(vec2(u * noise_scale * 2.5 - t * 1.5, v * 3.0));
		float edge = 1.0 - smoothstep(0.0, 0.85, v);
		float ends = smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.7 - progress * 0.5, 1.0, u));
		energy = edge * ends * (0.7 + 1.2 * n);
	}
	float hot = smoothstep(1.0, 1.5, energy);
	ALBEDO = mix(color.rgb * 1.15, core.rgb, hot);
	ALPHA = clamp(energy * 1.2, 0.0, 1.0) * fade * color.a;
}
