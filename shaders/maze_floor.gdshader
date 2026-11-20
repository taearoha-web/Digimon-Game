shader_type spatial;
render_mode diffuse_toon, specular_disabled;
// The floor of เขาวงกตหนึ่งในใต้หล้า (MazeArena): one flat mesh over the whole maze, the
// paving worked out per pixel from the maze's own map (`links`, a CELLS x CELLS texture:
// R open to the east, G open to the south, B how near a shrine the cell is, A the plaza
// (k + 1) / 8). Every corridor is a runner of big pale slabs with an inlaid line of the
// quadrant's glow down its middle, ringed at the crossings, brighter on the ways into a
// shrine; the rest is small cobbles in the quadrant's colour, worn dark and mossy at the
// foot of every wall (a painted shade where a wall stands); the plazas are laid in rings
// round their landmark, the throne plaza in white and gold with red carpets to its gates.
// One draw for the whole floor, no texture but the tiny map (and the shared grain).
#include "res://shaders/surface_detail.gdshaderinc"

uniform sampler2D links : filter_nearest;
uniform float half_size = 108.0;
uniform float cell = 12.0;
uniform float cells = 18.0;
uniform float wall_face = 5.3;
uniform vec4 floor0 : source_color;
uniform vec4 floor1 : source_color;
uniform vec4 floor2 : source_color;
uniform vec4 floor3 : source_color;
uniform vec4 runner0 : source_color;
uniform vec4 runner1 : source_color;
uniform vec4 runner2 : source_color;
uniform vec4 runner3 : source_color;
uniform vec4 glow0 : source_color;
uniform vec4 glow1 : source_color;
uniform vec4 glow2 : source_color;
uniform vec4 glow3 : source_color;
uniform vec4 shrine_glow : source_color = vec4(0.6, 1.0, 0.95, 1.0);
uniform vec4 marble : source_color = vec4(0.93, 0.9, 0.84, 1.0);
uniform vec4 gold : source_color = vec4(0.95, 0.75, 0.3, 1.0);
uniform vec4 carpet : source_color = vec4(0.62, 0.1, 0.14, 1.0);
uniform vec4 moss : source_color = vec4(0.22, 0.32, 0.2, 1.0);
// The plazas: centre x, centre z, half size (PLAZAS order).
uniform vec3 plaza0;
uniform vec3 plaza1;
uniform vec3 plaza2;
uniform vec3 plaza3;
uniform vec3 plaza4;
uniform float glow_amount = 1.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

// Offset-row slabs `size` metres: x the slab's own hash, y how far into the mortar (0 in
// the slab, 1 on the joint), `aa` the pixel's width in metres.
vec2 slabs(vec2 p, vec2 size, float aa) {
	vec2 q = p / size;
	float row = floor(q.y);
	q.x += fract(row * 0.5) + hash21(vec2(row, 7.0)) * 0.3;
	vec2 id = floor(q);
	vec2 f = fract(q);
	vec2 edge = min(f, 1.0 - f) * size;
	float d = min(edge.x, edge.y);
	float w = 0.05 + aa;
	return vec2(hash21(id), 1.0 - smoothstep(w, w + 0.05 + aa, d));
}

void fragment() {
	vec2 w = wpos.xz;
	float aa = length(fwidth(w));
	vec2 g = (w + half_size) / cell;
	ivec2 ci = ivec2(clamp(floor(g), vec2(0.0), vec2(cells - 1.0)));
	vec2 m = (fract(g) - 0.5) * cell;
	vec4 d = texelFetch(links, ci, 0);
	float e_open = step(0.5, d.r);
	float s_open = step(0.5, d.g);
	float w_open = ci.x > 0 ? step(0.5, texelFetch(links, ci - ivec2(1, 0), 0).r) : 0.0;
	float n_open = ci.y > 0 ? step(0.5, texelFetch(links, ci - ivec2(0, 1), 0).g) : 0.0;
	int plaza = int(round(d.a * 8.0)) - 1;
	float guide = d.b;
	// The quadrant's colours.
	int q = (w.x >= 0.0 ? 1 : 0) + (w.y >= 0.0 ? 2 : 0);
	vec3 base = q == 0 ? floor0.rgb : (q == 1 ? floor1.rgb : (q == 2 ? floor2.rgb : floor3.rgb));
	vec3 run_col = q == 0 ? runner0.rgb : (q == 1 ? runner1.rgb : (q == 2 ? runner2.rgb : runner3.rgb));
	vec3 glow = q == 0 ? glow0.rgb : (q == 1 ? glow1.rgb : (q == 2 ? glow2.rgb : glow3.rgb));
	vec3 col;
	vec3 emit = vec3(0.0);
	float wear = 0.0;
	if (plaza < 0) {
		// The runner: a band down the middle of every open way, and the crossing itself.
		float r = max(abs(m.x), abs(m.y));
		if (m.x > 0.0 && e_open > 0.5) { r = min(r, abs(m.y)); }
		if (m.x < 0.0 && w_open > 0.5) { r = min(r, abs(m.y)); }
		if (m.y > 0.0 && s_open > 0.5) { r = min(r, abs(m.x)); }
		if (m.y < 0.0 && n_open > 0.5) { r = min(r, abs(m.x)); }
		float runner = 1.0 - smoothstep(1.85, 1.95 + aa, r);
		vec2 big = slabs(w + vec2(0.37, 0.11), vec2(2.1, 1.4), aa);
		vec2 small = slabs(w, vec2(0.95, 0.7), aa);
		vec3 cobble = base * (0.82 + small.x * 0.3);
		cobble = mix(cobble, cobble * 0.62, small.y);
		vec3 slab = run_col * (0.88 + big.x * 0.18);
		slab = mix(slab, run_col * 0.58, big.y);
		// The runner's border: a darker kerb.
		float kerb = smoothstep(1.55, 1.7, r) * runner;
		slab = mix(slab, base * 0.7, kerb);
		col = mix(cobble, slab, runner);
		// The inlay down the middle and the ring at a crossing.
		float exits = e_open + w_open + s_open + n_open;
		float line_w = 0.07 + aa * 0.5;
		float inlay = 1.0 - smoothstep(line_w, line_w + 0.05 + aa, r);
		float ring_d = abs(length(m) - 1.15);
		float ring = (exits != 2.0 ? 1.0 : 0.0) * (1.0 - smoothstep(line_w, line_w + 0.05 + aa, ring_d));
		inlay = max(inlay * (exits == 2.0 ? 1.0 : step(1.15, length(m))), ring);
		vec3 lit = mix(glow, shrine_glow.rgb, guide);
		col = mix(col, mix(gold.rgb, lit, 0.55), inlay);
		emit += lit * inlay * (0.28 + guide * 1.1) * glow_amount;
		// A soft glow round the inlay on the ways into a shrine.
		emit += shrine_glow.rgb * guide * (1.0 - smoothstep(0.0, 1.6, r)) * 0.18 * glow_amount;
		// The walls' feet: shade and moss where a side is closed.
		float face = wall_face;
		float near_e = (1.0 - e_open) * (1.0 - smoothstep(0.0, 1.9, face - m.x));
		float near_w = (1.0 - w_open) * (1.0 - smoothstep(0.0, 1.9, face + m.x));
		float near_s = (1.0 - s_open) * (1.0 - smoothstep(0.0, 1.9, face - m.y));
		float near_n = (1.0 - n_open) * (1.0 - smoothstep(0.0, 1.9, face + m.y));
		wear = max(max(near_e, near_w), max(near_s, near_n));
	} else {
		vec3 pc = plaza == 0 ? plaza0 : (plaza == 1 ? plaza1 : (plaza == 2 ? plaza2 : (plaza == 3 ? plaza3 : plaza4)));
		vec2 rel = w - pc.xy;
		float rad = length(rel);
		float ang = atan(rel.y, rel.x);
		// Rings of slabs, cut radially.
		float band = floor(rad / 1.8);
		float segs = max(6.0, floor(band * 3.0 + 6.0));
		float a01 = (ang / 6.2831853 + 0.5) * segs;
		float sid = floor(a01 + hash21(vec2(band, 3.0)));
		float h = hash21(vec2(band, sid));
		float joint_r = abs(fract(rad / 1.8) - 0.5) * 1.8;
		float joint_a = abs(fract(a01 + hash21(vec2(band, 3.0))) - 0.5) * rad * 6.2831853 / segs;
		float joint = 1.0 - smoothstep(0.05 + aa, 0.1 + aa * 2.0, min(0.9 - joint_r, joint_a));
		vec3 pale = plaza == 0 ? marble.rgb : mix(run_col, marble.rgb, 0.35);
		vec3 deep = plaza == 0 ? mix(marble.rgb, gold.rgb, 0.28) : base * 1.05;
		col = mix(pale, deep, mod(band, 2.0)) * (0.9 + h * 0.16);
		col = mix(col, col * 0.62, joint);
		// Gold inlaid rings.
		float lw = 0.11 + aa * 0.5;
		float rings = 0.0;
		rings = max(rings, 1.0 - smoothstep(lw, lw + 0.06 + aa, abs(rad - 4.6)));
		rings = max(rings, 1.0 - smoothstep(lw, lw + 0.06 + aa, abs(rad - 8.4)));
		rings = max(rings, 1.0 - smoothstep(lw, lw + 0.06 + aa, abs(rad - 12.6)));
		rings = max(rings, (plaza == 0 ? 1.0 : 0.0) * (1.0 - smoothstep(lw, lw + 0.06 + aa, abs(rad - 17.4))));
		vec3 ring_col = plaza == 0 ? gold.rgb : mix(gold.rgb, glow, 0.5);
		col = mix(col, ring_col, rings);
		emit += (plaza == 0 ? gold.rgb : glow) * rings * 0.32 * glow_amount;
		// Radiating spokes of glow from the landmark to the gates.
		float spoke = 1.0 - smoothstep(lw, lw + 0.06 + aa, min(abs(rel.x), abs(rel.y)));
		spoke *= step(4.6, rad) * (1.0 - step(pc.z, max(abs(rel.x), abs(rel.y))));
		if (plaza == 0) {
			// Red carpets with gold borders from the dais to the four gates.
			float lane = min(abs(rel.x), abs(rel.y));
			float on = (1.0 - smoothstep(1.6, 1.62 + aa, lane)) * step(4.4, rad);
			float border = (1.0 - smoothstep(1.6, 1.62 + aa, lane)) * smoothstep(1.3, 1.32 + aa, lane);
			vec3 rug = carpet.rgb * (0.9 + 0.1 * sin(max(abs(rel.x), abs(rel.y)) * 6.0));
			col = mix(col, rug, on);
			col = mix(col, gold.rgb, border * on);
			spoke *= 0.0;
		}
		col = mix(col, mix(gold.rgb, glow, 0.6), spoke);
		emit += glow * spoke * 0.4 * glow_amount;
		// Shade along the plaza's own walls.
		float edge = pc.z - max(abs(rel.x), abs(rel.y));
		wear = 1.0 - smoothstep(0.7, 2.6, edge);
	}
	vec3 shade = mix(col * 0.55, moss.rgb, 0.35);
	col = mix(col, shade, wear * 0.8);
	if (surface_amount > 0.0) {
		col = sd_apply(col, sd_tex(w / 3.1, SD_ROCK), 0.55);
	}
	ALBEDO = col;
	EMISSION = emit;
	ROUGHNESS = 1.0;
}
