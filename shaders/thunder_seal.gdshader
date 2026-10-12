shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float fade = 0.0;
uniform float age = 0.0;
uniform float pulse = 0.0;

float stroke(float d, float width) {
	float aa = max(fwidth(d), 0.0015);
	return 1.0 - smoothstep(width, width + aa, abs(d));
}
float segment(vec2 p, vec2 a, vec2 b) {
	vec2 v = b - a;
	return length(p - a - v * clamp(dot(p - a, v) / dot(v, v), 0.0, 1.0));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p), a = atan(p.y, p.x);
	float outer = stroke(r - 0.94, 0.006) + stroke(r - 0.91, 0.003);
	float inner = stroke(r - 0.73, 0.006) + stroke(r - 0.69, 0.0025) + stroke(r - 0.38, 0.004);
	float clock = a + age * 0.065;
	float ticks = step(0.78, cos(clock * 64.0)) * stroke(r - 0.89, 0.013);
	// Twenty-four authored lightning runes, slowly orbiting within the boundary.
	float cell = mod(clock + 0.1309, 0.261799) - 0.1309;
	vec2 glyph = vec2(cell * 0.82, r - 0.816);
	float rune_d = min(segment(glyph, vec2(0.026,0.037), vec2(-0.018,0.003)),
		min(segment(glyph, vec2(-0.018,0.003), vec2(0.018,-0.003)), segment(glyph, vec2(0.018,-0.003), vec2(-0.026,-0.037))));
	float runes = stroke(rune_d, 0.0038);
	// Two counter-turning squares form the star; its open centre leaves actors clear.
	float turn = a - age * 0.10;
	vec2 star = vec2(cos(turn), sin(turn)) * r;
	vec2 tilted = vec2(star.x + star.y, star.y - star.x) * 0.707107;
	float lattice_d = min(abs(max(abs(star.x), abs(star.y)) - 0.46), abs(max(abs(tilted.x), abs(tilted.y)) - 0.46));
	float lattice = stroke(lattice_d, 0.0035);
	float spokes = pow(max(0.0, cos(turn * 8.0)), 90.0) * smoothstep(0.37,0.41,r) * (1.0 - smoothstep(0.64,0.70,r));
	float jewels = stroke(abs(mod(turn + 0.392699, 0.785398) - 0.392699) * 0.54 + abs(r - 0.54) - 0.048, 0.003);
	float centre = stroke(r - 0.15, 0.003) + stroke(r - 0.21, 0.002);
	float ink = clamp(outer + inner + ticks + runes + lattice + spokes + jewels + centre, 0.0, 1.0);
	float mist = exp(-pow((r - 0.82) * 12.0, 2.0)) * (0.5 + 0.5 * sin(a * 9.0 + r * 65.0 - age * 1.8));
	float etching = clamp(runes + lattice + jewels + centre, 0.0, 1.0);
	// All seal layers remain smoke grey; only the lightning uses gold and blue.
	vec3 silver = mix(vec3(0.29,0.31,0.33), vec3(0.70,0.72,0.74), etching);
	ALBEDO = silver + vec3(0.12) * pulse;
	ALPHA = (ink * 0.94 + mist * 0.14) * fade * (1.0 - smoothstep(0.965,0.99,r));
}
