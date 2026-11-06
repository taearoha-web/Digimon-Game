shader_type spatial;
// A mark a heavy skill leaves on the ground (GroundMarks): one flat quad, drawn
// procedurally from UV so no texture is loaded. kind:
//   0 scorch  a dark burnt blot with a glowing ember rim
//   1 cracks  radial cracks out of a dented centre
//   2 frost   a pale icy rime with spiky crystals at the edge
//   3 glyph   a holy / arcane ring with runes and a star inside
// `fade` takes it in and out (GroundMarks ages it); `seed` varies each mark.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float kind = 0.0;
uniform float fade = 1.0;
uniform float seed = 0.0;

float hash(float n) { return fract(sin(n * 12.9898 + seed * 78.233) * 43758.5453); }

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float ang = (a + 3.14159265) / 6.2831853;
	float alpha = 0.0;
	vec3 col = tint.rgb;
	if (kind < 0.5) {
		float edge = 0.78 + 0.16 * noise1(ang * 14.0);
		float blot = 1.0 - smoothstep(edge - 0.25, edge, r);
		float rim = smoothstep(edge - 0.22, edge - 0.08, r) * (1.0 - smoothstep(edge - 0.06, edge + 0.02, r));
		col = mix(vec3(0.07, 0.05, 0.05), tint.rgb * 1.6, rim);
		alpha = blot * 0.55 + rim * 0.5;
	} else if (kind < 1.5) {
		float lines = 0.0;
		for (int i = 0; i < 7; i++) {
			float fi = float(i);
			float dir = hash(fi + 1.0) + fi / 7.0;
			float d = abs(fract(ang - dir + 0.5) - 0.5) * 6.2831853 * r;
			float wiggle = (noise1(r * 9.0 + fi * 3.0) - 0.5) * 0.12 * r;
			float width = mix(0.05, 0.012, r);
			lines = max(lines, (1.0 - smoothstep(width * 0.4, width, abs(d + wiggle))) * (1.0 - smoothstep(0.55 + 0.4 * hash(fi + 7.0), 1.0, r)));
		}
		float dent = 1.0 - smoothstep(0.1, 0.32, r);
		col = mix(vec3(0.12, 0.09, 0.07), tint.rgb * 1.3, lines * 0.35);
		alpha = max(lines * 0.85, dent * 0.55);
	} else if (kind < 2.5) {
		float edge = 0.82 + 0.14 * noise1(ang * 22.0);
		float spikes = pow(abs(sin(ang * 3.14159265 * 18.0 + seed)), 6.0) * 0.12;
		float body = 1.0 - smoothstep(edge - 0.3 + spikes, edge + spikes, r);
		float sparkle = step(0.985, hash(floor(UV.x * 40.0) * 41.0 + floor(UV.y * 40.0)));
		col = mix(tint.rgb, vec3(0.95, 1.0, 1.0), 0.45 + 0.4 * (1.0 - r) + sparkle);
		alpha = body * (0.42 + 0.3 * smoothstep(0.3, 0.8, r)) + sparkle * body * 0.4;
	} else {
		float ring = (1.0 - smoothstep(0.015, 0.035, abs(r - 0.86))) + (1.0 - smoothstep(0.01, 0.025, abs(r - 0.68)));
		float runes = step(0.72, r) * step(r, 0.82) * step(0.45, fract(ang * 24.0)) * step(fract(ang * 24.0), 0.8) * step(0.35, hash(floor(ang * 24.0)));
		float star_r = 0.5 + 0.12 * cos(a * 6.0 + seed);
		float star = 1.0 - smoothstep(0.015, 0.04, abs(r - star_r * 0.9));
		float glow = (1.0 - smoothstep(0.0, 0.6, r)) * 0.25;
		col = tint.rgb * (1.0 + ring * 0.5);
		alpha = clamp(ring + runes * 0.85 + star * 0.8 + glow, 0.0, 1.0);
	}
	ALBEDO = col;
	ALPHA = clamp(alpha, 0.0, 1.0) * fade * step(r, 1.0);
}
