shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// The sky ring's seal: a horizontal glowing magic circle (seen from below and from the
// camera above) with double rims, a turning band of segments, counter-turning lightning
// ticks, a hexagram, a soft core and sparks crawling round the rim.
uniform float fade = 0.0;
uniform float age = 0.0;
uniform float pulse = 0.0;
uniform vec3 tint = vec3(0.32, 0.55, 1.0);

float line(float d, float w) {
	float aa = max(fwidth(d), 0.002);
	return 1.0 - smoothstep(w, w + aa, abs(d));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float a = atan(p.y, p.x);
	float g = 0.0;
	// Rims and inner circles.
	g += line(r - 0.97, 0.012) * 1.1 + line(r - 0.93, 0.004) * 0.8;
	g += line(r - 0.70, 0.006) * 0.8 + line(r - 0.66, 0.003) * 0.6 + line(r - 0.36, 0.005) * 0.7;
	// A band of segments turning one way, ticks the other.
	float seg = step(0.42, fract((a + age * 0.9) / 6.2831853 * 16.0));
	g += seg * line(r - 0.95, 0.014) * 0.55;
	float tick = step(0.82, cos((a - age * 0.6) * 48.0));
	g += tick * line(r - 0.81, 0.06) * 0.6;
	// Bolt glyphs between the rings.
	float cell = fract((a - age * 0.6) / 6.2831853 * 12.0) - 0.5;
	float zig = abs(cell * 0.9 - (r - 0.81) * (step(0.0, r - 0.81) * 2.0 - 1.0) * 1.6);
	g += line(zig - 0.02, 0.008) * line(r - 0.81, 0.07) * 0.9;
	// The hexagram, slowly turning.
	float hex_d = 1.0;
	for (int k = 0; k < 6; k++) {
		float t = float(k) * 1.0471976 + age * 0.25;
		hex_d = min(hex_d, abs(dot(p, vec2(cos(t), sin(t))) - 0.33));
	}
	g += line(hex_d, 0.005) * step(r, 0.66) * 0.9;
	// Soft core glow and an outer haze.
	g += exp(-r * r * 9.0) * 0.22;
	g += exp(-pow((r - 0.97) * 14.0, 2.0)) * 0.35;
	// Sparks crawling round the rim.
	float n = sin(a * 23.0 + age * 31.0) * sin(a * 9.0 - age * 17.0);
	g += smoothstep(0.82, 1.0, n) * exp(-pow((r - 0.96) * 30.0, 2.0)) * 1.6;
	// Lines of light over a deep storm-blue disc, so the seal reads on any ground or sky.
	float lines = clamp(g * (1.0 + pulse * 0.9), 0.0, 1.0);
	vec3 deep = mix(vec3(0.05, 0.07, 0.24), vec3(0.12, 0.2, 0.55), exp(-r * r * 3.0));
	vec3 light = mix(tint, vec3(0.88, 0.96, 1.0), clamp(g * 0.5 + pulse * 0.4, 0.0, 1.0));
	ALBEDO = mix(deep, light, lines);
	ALPHA = clamp((0.42 * smoothstep(1.0, 0.9, r) + lines) * fade, 0.0, 1.0);
}
