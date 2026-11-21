shader_type spatial;
// The Dark Lord's cape (CapeArt). The mesh is only a UV grid: the vertex stage
// builds the cloth from UV (x across, y down) so the pleats, the walk ripple, the
// streaming while flying (billow) and the gathering up (fold) all come with true
// normals, and the toon light shades every pleat. Three kinds of layer:
//   kind 0  the long cape: flaring from the shoulders, deep pleats, a curved hem
//   kind 1  the capelet over the shoulders, its hem cut into feather scallops
//   kind 2  the standing collar behind the neck
// Two styles: 0 royal (Lv.100: crimson velvet, gold filigree, a raven crest) and
// 1 star (100 stars: galaxy cloth with twinkling stars, a crowned raven on a gold
// sunburst, a hem of glowing raven feathers, an indigo feather mantle).
// The Muay Thai fighter's capes (boxer > 0) paint the same cloth their own way
// (boxer_paint): 1 the ring robe (satin red, gold trim and fringe, a mongkhon with
// an unalom and rows of yant script on the back), 2 the star robe (crimson-to-orange
// flame satin, glowing drifting script, embers along the hem). They add two layers:
// ribbon (the prajiad tails tied at the shoulders) and kind 3, the mantra ring that
// floats behind the shoulders of the star robe.
render_mode cull_disabled, diffuse_toon, specular_disabled;

uniform vec4 outer_color : source_color = vec4(0.56, 0.11, 0.16, 1.0);
uniform vec4 outer_deep : source_color = vec4(0.32, 0.05, 0.09, 1.0);
uniform vec4 lining_color : source_color = vec4(0.08, 0.05, 0.06, 1.0);
uniform vec4 trim_color : source_color = vec4(0.91, 0.71, 0.29, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.75, 0.95, 1.0);
uniform float kind = 0.0;
uniform float style = 0.0;
uniform float top_y = 0.79;
uniform float back_z = -0.11;
uniform float behind = 0.0;
uniform float top_width = 0.4;
uniform float hem_width = 0.78;
uniform float cape_length = 0.76;
uniform float hem_curve = 0.06;
uniform float wrap = 0.12;
uniform float fold_depth = 0.05;
uniform float folds = 4.5;
uniform float crest = 1.0;
uniform float feather_len = 0.0;
uniform float scallop = 0.0;
uniform float phase = 0.0;
// How much of the flying stream this layer takes (the capelet sits closer).
uniform float stiff = 1.0;
uniform float billow = 0.15;
uniform float fold = 0.0;
// The Muay Thai robes: 0 off (the Dark Lord), 1 Lv.100, 2 the star robe.
uniform float boxer = 0.0;
// A prajiad tail (boxer only): a narrow band with a swallowtail end.
uniform float ribbon = 0.0;

varying vec2 cloth;
varying float pleat_shade;



// The cloth surface at a UV point, at time t.
vec3 shape(vec2 uv, float t) {
	float s = uv.x * 2.0 - 1.0;
	float v = uv.y;
	if (kind > 2.5) {
		// The mantra ring: an upright band (u around, v across) behind the shoulders,
		// turning slowly, tipping back as the robe streams and shrinking when stowed.
		float a = uv.x * 2.0 * PI + TIME * 0.35;
		float r = mix(top_width, hem_width, v) * (1.0 - fold * 0.7) * (1.0 + 0.03 * sin(TIME * 2.2));
		vec3 c = vec3(cos(a) * r, sin(a) * r, 0.0);
		float tip = billow * 0.5;
		c = vec3(c.x, c.y * cos(tip), -c.y * sin(tip));
		c.y += top_y - cape_length + 0.012 * sin(TIME * 1.3);
		c.z += back_z - behind;
		return c;
	}
	if (kind > 1.5) {
		// The collar: an arc behind the neck, flaring outwards as it rises.
		float a = s * 1.45;
		float rise = 1.0 - v;
		float r = mix(top_width, hem_width, rise * rise);
		vec3 c;
		c.x = sin(a) * r;
		c.z = back_z + 0.1 - cos(a) * r - rise * 0.03;
		c.y = top_y - 0.02 + rise * cape_length * (1.0 - fold * 0.6);
		return c;
	}
	// Stowed: the cloth rolls up towards the shoulders and draws in.
	// The normal is found from neighbours a step past the edges (v < 0 above the
	// shoulders): pow() of a negative number is NaN on Apple GPUs, and a NaN normal
	// broke whole frames on iPhones, so every base below is kept at or above zero.
	float vv = max(v, 0.0) * (1.0 - fold * 0.82);
	float flare = pow(vv, 0.8);
	float half_w = mix(top_width, hem_width, flare) * 0.5 * mix(1.0, 0.62, fold * v);
	float len = cape_length * (1.0 + hem_curve * (1.0 - s * s));
	vec3 p;
	p.x = s * half_w;
	p.y = top_y - vv * len;
	// Hugging the shoulders at the top, hanging clear of the back lower down.
	float hug = 1.0 - smoothstep(0.0, 0.5, vv);
	p.z = back_z - behind + s * s * wrap * hug - (1.0 - s * s) * 0.03 * hug - vv * 0.06 * cape_length;
	// Pleats, deeper towards the hem and swaying slowly.
	float depth = (0.003 + fold_depth * pow(smoothstep(0.08, 1.0, vv), 1.1)) * (1.0 - fold * 0.8);
	float sway = sin(t * 0.7 + vv * 2.4 + phase) * 0.45;
	float pleat = sin((s * 0.5 + 0.5) * folds * 2.0 * PI + sway);
	p.z -= depth * pleat;
	p.y += depth * 0.45 * pleat * smoothstep(0.7, 1.0, vv);
	// A ripple running down the cloth, stronger near the hem and when flying.
	float wave = sin(t * 2.0 - vv * 6.0 + s * 1.5) * 0.5 + sin(t * 3.1 - vv * 9.0 - s * 2.5) * 0.25;
	float reach = pow(vv, 1.4);
	p.z -= reach * (0.02 + billow * 0.06 * stiff) * wave * (1.0 - fold);
	p.x += reach * 0.012 * sin(t * 1.7 + vv * 4.0) * (1.0 - fold);
	// Streaming back and lifting while flying, the hem flaring wider.
	float stream = billow * (1.0 - fold) * stiff;
	// The long cape streams from below the capelet, so it never cuts through it.
	float from = kind < 0.5 ? clamp((vv - 0.2) / 0.8, 0.0, 1.0) : max(vv, 0.0);
	p.z -= stream * pow(from, 1.3) * len * 0.85;
	p.y += stream * pow(from, 2.0) * len * 0.45;
	p.x *= 1.0 + stream * vv * 0.3;
	return p;
}

void vertex() {
	float t = TIME * (1.6 + billow * 2.4);
	vec3 p = shape(UV, t);
	vec3 pu = shape(UV + vec2(0.01, 0.0), t) - shape(UV - vec2(0.01, 0.0), t);
	vec3 pv = shape(UV + vec2(0.0, 0.01), t) - shape(UV - vec2(0.0, 0.01), t);
	VERTEX = p;
	vec3 n = cross(pu, pv);
	NORMAL = dot(n, n) > 1e-12 ? normalize(n) : vec3(0.0, 0.0, -1.0);
	cloth = UV;
	float s = UV.x * 2.0 - 1.0;
	float sway = sin(t * 0.7 + UV.y * 2.4 + phase) * 0.45;
	pleat_shade = kind > 1.5 ? 1.0 : sin((s * 0.5 + 0.5) * folds * 2.0 * PI + sway) * smoothstep(0.0, 0.5, UV.y);
}

float hash1(float n) {
	return fract(sin(n * 91.3458) * 47453.5453);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float a = 0.5;
	float sum = 0.0;
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 4; i++) {
		sum += a * noise(p);
		p = turn * p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return sum / 0.9375;
}

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

// A heraldic raven, displayed: wings raised with five long fingered flight
// feathers each, head turned in profile with a heavy beak and shaggy throat, a
// wedge-shaped tail and open talons. About 0.4 wide, centred on its body;
// negative inside.
float raven(vec2 p) {
	vec2 q = vec2(abs(p.x), p.y);
	float d = (length((p - vec2(0.0, -0.01)) / vec2(0.045, 0.088)) - 1.0) * 0.045;
	d = smin(d, length(p - vec2(0.008, 0.098)) - 0.036, 0.02);
	// The heavy beak, facing right, and the shaggy throat under it.
	d = min(d, seg(p, vec2(0.03, 0.102), vec2(0.074, 0.094)) - 0.013);
	d = min(d, seg(p, vec2(0.074, 0.094), vec2(0.084, 0.088)) - 0.006);
	d = smin(d, seg(p, vec2(0.02, 0.072), vec2(0.03, 0.058)) - 0.012, 0.01);
	// Wings: a raised leading edge with feathers hanging and spreading from it.
	vec2 sh = vec2(0.032, 0.046);
	vec2 tip = vec2(0.158, 0.148);
	float w = seg(q, sh, tip) - 0.024;
	for (int i = 0; i < 6; i++) {
		float k = float(i) / 5.0;
		vec2 root = mix(sh + vec2(0.012, -0.004), tip, k);
		float ang = mix(-1.75, 0.25, k);
		float l = mix(0.1, 0.075, abs(k - 0.55) * 1.6) + k * 0.02;
		vec2 end = root + vec2(cos(ang), sin(ang)) * l;
		w = smin(w, seg(q, root, end) - mix(0.022, 0.016, k), 0.014);
	}
	// Fill the wing between the leading edge and the inner feathers.
	float web = max(seg(q, vec2(0.05, 0.03), vec2(0.12, 0.08)) - 0.045, -(q.y + 0.03));
	w = smin(w, web, 0.02);
	d = smin(d, w, 0.012);
	// The wedge-shaped tail: the middle feathers longest.
	for (int j = 0; j < 5; j++) {
		float a = -PI * 0.5 + (float(j) - 2.0) * 0.16;
		vec2 root = vec2(0.0, -0.08);
		d = min(d, seg(p, root, root + vec2(cos(a), sin(a)) * (0.11 - abs(float(j) - 2.0) * 0.016)) - 0.014);
	}
	// Legs and open talons.
	float leg = seg(q, vec2(0.026, -0.06), vec2(0.056, -0.098)) - 0.009;
	leg = min(leg, seg(q, vec2(0.056, -0.098), vec2(0.082, -0.104)) - 0.005);
	leg = min(leg, seg(q, vec2(0.056, -0.098), vec2(0.06, -0.126)) - 0.005);
	leg = min(leg, seg(q, vec2(0.056, -0.098), vec2(0.038, -0.118)) - 0.005);
	return min(d, leg);
}

// Gold that reads as metal under the toon light: a bright ridge along the middle
// of a band (x 0..1 across it) and darker edges.
vec3 gold(vec3 base, float x) {
	float ridge = 1.0 - abs(x * 2.0 - 1.0);
	return base * (0.62 + 0.62 * pow(max(ridge, 0.0), 0.7));
}

// The star cape's cloth: deep space with drifting nebula and twinkling stars.
vec3 galaxy(vec2 p, out float sparkle) {
	vec2 q = p * vec2(4.0, 3.4);
	// Domain-warped clouds, so the nebula drifts in soft wisps.
	vec2 warp = vec2(fbm(q + vec2(0.0, TIME * 0.04)), fbm(q + vec2(5.2, 1.3) - vec2(TIME * 0.03, 0.0)));
	float n = fbm(q + warp * 1.6);
	vec3 c = mix(outer_deep.rgb, outer_color.rgb, smoothstep(0.2, 0.8, n));
	float neb = smoothstep(0.5, 0.85, fbm(q * 0.8 + warp * 2.2 + vec2(3.0, 0.0)));
	c = mix(c, glow_color.rgb * 0.6, neb * 0.4);
	vec2 g = p * vec2(48.0, 44.0);
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash2(id);
	vec2 o = vec2(hash2(id + 1.3), hash2(id + 7.1)) - 0.5;
	float d = length(f - o * 0.6);
	float tw = 0.45 + 0.55 * sin(TIME * (2.0 + h * 3.0) + h * 40.0);
	sparkle = smoothstep(0.13, 0.0, d) * step(0.78, h) * tw;
	float cross_ray = smoothstep(0.05, 0.0, min(abs(f.x - o.x * 0.6), abs(f.y - o.y * 0.6))) * smoothstep(0.35, 0.0, d) * step(0.95, h) * tw;
	sparkle += cross_ray * 0.8;
	return c;
}

// ---- The Muay Thai robes ----------------------------------------------------

// One glyph of yant script in a cell (p 0..1): a small head loop, a stem and one of
// a few hooks, the way Khom letters read from afar. Negative inside.
float yant_glyph(vec2 p, float h) {
	float d = abs(length(p - vec2(0.3, 0.28)) - 0.15) - 0.06;
	d = min(d, seg(p, vec2(0.45, 0.28), vec2(0.45, 0.84)) - 0.065);
	if (h < 0.3) {
		d = min(d, seg(p, vec2(0.45, 0.84), vec2(0.78, 0.84)) - 0.065);
		d = min(d, seg(p, vec2(0.78, 0.84), vec2(0.78, 0.2)) - 0.065);
	} else if (h < 0.6) {
		d = min(d, seg(p, vec2(0.45, 0.84), vec2(0.82, 0.6)) - 0.065);
		d = min(d, abs(length(p - vec2(0.74, 0.3)) - 0.12) - 0.055);
	} else if (h < 0.8) {
		d = min(d, seg(p, vec2(0.15, 0.84), vec2(0.45, 0.84)) - 0.065);
		d = min(d, seg(p, vec2(0.7, 0.15), vec2(0.7, 0.7)) - 0.065);
	} else {
		d = min(d, seg(p, vec2(0.45, 0.6), vec2(0.8, 0.6)) - 0.06);
	}
	return d;
}

// Rows of yant script (Hah Taew, the lines of a sak yant) in cloth units, the first
// line's top at [param top]; [param drift] slides the letters along their lines.
// 1 on a stroke.
float yant_rows(vec2 dp, float top, float rows, float cell, float half_w, float drift) {
	float ry = (top - dp.y) / (cell * 1.55);
	float row = floor(ry);
	if (row < 0.0 || row >= rows) {
		return 0.0;
	}
	// The lines shorten towards the bottom, like a tapering yant.
	float w = half_w * (1.0 - row * 0.12);
	if (abs(dp.x) > w) {
		return 0.0;
	}
	float fy = fract(ry) * 1.55;
	if (fy > 1.0) {
		return 0.0;
	}
	float gx = dp.x / cell + drift * (mod(row, 2.0) < 0.5 ? 1.0 : -1.0);
	float id = floor(gx);
	float g = yant_glyph(vec2(fract(gx), 1.0 - fy), hash1(id * 7.1 + row * 13.0));
	return smoothstep(0.04, -0.04, g);
}

// The back emblem: a gold mongkhon (a twisted rope ring with its tail) round an
// unalom. Returns 1 on gold; [param shade] the rope's twist light.
float mongkhon(vec2 c, out float shade) {
	float r = length(c);
	float ang = atan(c.y, c.x);
	float ring = abs(r - 0.1) - 0.022;
	float m = smoothstep(0.004, -0.002, ring);
	// The rope twist: diagonal light and dark bands round the ring.
	float twist = fract(ang / (2.0 * PI) * 22.0 + (r - 0.1) * 30.0);
	shade = mix(0.62, 1.12, smoothstep(0.0, 0.5, twist) * smoothstep(1.0, 0.5, twist));
	// The tail, hanging from the bottom of the ring and ending in a knot.
	float tail = seg(c, vec2(0.0, -0.12), vec2(0.012, -0.2)) - 0.012;
	tail = min(tail, length(c - vec2(0.014, -0.215)) - 0.02);
	float t = smoothstep(0.004, -0.002, tail);
	if (t > m) {
		shade = 0.95;
	}
	m = max(m, t);
	// The unalom: a coiled loop, a line winding up and a dot of light at the top.
	float un = abs(length(c - vec2(0.0, -0.035)) - 0.018) - 0.006;
	un = min(un, seg(c, vec2(0.018, -0.035), vec2(-0.014, 0.0)) - 0.006);
	un = min(un, seg(c, vec2(-0.014, 0.0), vec2(0.012, 0.025)) - 0.006);
	un = min(un, seg(c, vec2(0.012, 0.025), vec2(0.0, 0.05)) - 0.006);
	un = min(un, length(c - vec2(0.0, 0.066)) - 0.01);
	float un_m = smoothstep(0.004, -0.002, un);
	if (un_m > m) {
		shade = 1.05;
	}
	return max(m, un_m);
}

// The colour and glow of a robe point; cut > 0.5 discards it.
void boxer_paint(vec2 uv, bool front, vec3 n, vec3 view, float shade_pleat, out vec3 col, out vec3 emit, out float cut) {
	float u = uv.x;
	float v = uv.y;
	float s = u * 2.0 - 1.0;
	float star = boxer > 1.5 ? 1.0 : 0.0;
	vec3 gold_c = trim_color.rgb;
	cut = 0.0;
	emit = vec3(0.0);
	if (kind > 2.5) {
		// The mantra ring: a glowing band with gold rims and dark script turning in it.
		float rim = smoothstep(0.24, 0.12, min(v, 1.0 - v));
		vec2 g = vec2(u * 46.0, (v - 0.22) / 0.56);
		float glyph = 0.0;
		if (g.y > 0.0 && g.y < 1.0) {
			glyph = smoothstep(0.05, -0.05, yant_glyph(vec2(fract(g.x), g.y), hash1(floor(g.x) * 3.7)));
		}
		float pulse = 0.85 + 0.15 * sin(TIME * 3.0 + u * 2.0 * PI * 3.0);
		col = mix(glow_color.rgb, outer_color.rgb * 0.5, glyph * 0.8);
		col = mix(col, gold_c, rim);
		emit = mix(glow_color.rgb * 1.6 * pulse, gold_c * 0.9, rim) * (1.0 - glyph * 0.65);
		return;
	}
	float width_here = mix(top_width, hem_width, pow(max(v, 0.0), 0.8));
	float len_here = cape_length * (1.0 + hem_curve * (1.0 - s * s));
	float e_side = min(u, 1.0 - u) * width_here;
	float e_hem = (1.0 - v) * len_here;
	vec2 dp = vec2((u - 0.5) * width_here, -v * len_here);
	if (ribbon > 0.5) {
		// A prajiad tail: a swallowtail end, red with gold edges and a row of gold dots.
		if (e_hem < 0.05 * (1.0 - abs(s))) {
			cut = 1.0;
			return;
		}
		col = mix(outer_color.rgb * 1.15, outer_deep.rgb, v * 0.7);
		col *= 0.85 + 0.4 * pow(max(1.0 - abs(dot(n, view)), 0.0), 2.0);
		float edge = smoothstep(0.62, 0.72, abs(s));
		float dots = smoothstep(0.35, 0.2, length(vec2(s * 1.6, (fract(-dp.y * 22.0) - 0.5))));
		col = mix(col, gold(gold_c, abs(s)), max(edge, dots * 0.9));
		emit = gold_c * (edge * 0.3 + dots * 0.5) * star + glow_color.rgb * star * 0.15 * v;
		return;
	}
	// The cloth: satin, a deep crimson running into flame orange on the star robe.
	if (star > 0.5) {
		col = mix(outer_color.rgb, glow_color.rgb * 0.95, smoothstep(0.3, 1.0, v));
		vec2 q = dp * vec2(9.0, 5.0) + vec2(0.0, -TIME * 0.6);
		float f = fbm(q + vec2(fbm(q * 0.7 + TIME * 0.1), 0.0));
		float flame = smoothstep(0.45, 0.85, f + v * 0.9 - 0.55);
		col = mix(col, vec3(1.0, 0.72, 0.25), flame * 0.7);
		emit += vec3(1.0, 0.45, 0.1) * flame * 0.8 * smoothstep(0.4, 1.0, v);
	} else {
		col = mix(outer_color.rgb * 1.05, outer_deep.rgb, smoothstep(0.0, 1.1, v));
	}
	// Satin: bright crests on the folds and a sheen at grazing angles.
	float fres = pow(max(1.0 - clamp(abs(dot(n, view)), 0.0, 1.0), 0.0), 2.0);
	float crest_light = pow(max(shade_pleat, 0.0), 4.0);
	col *= mix(0.8, 1.05, shade_pleat * 0.5 + 0.5);
	col += outer_color.rgb * (0.45 * crest_light + 0.55 * fres) + vec3(0.18) * crest_light;
	// A gold fringe of tassels along the hem (the Lv.100 robe).
	float fringe_h = star > 0.5 ? 0.0 : 0.035;
	if (e_hem < fringe_h) {
		float strand = abs(fract(u * 46.0) - 0.5);
		if (strand > 0.3 - 0.1 * (1.0 - e_hem / fringe_h)) {
			cut = 1.0;
			return;
		}
		col = gold(gold_c, strand * 2.0 + 0.3) * mix(0.75, 1.0, e_hem / fringe_h);
		if (!front) {
			col *= 0.7;
		}
		return;
	}
	// Gold trim: a broad band down the sides and above the fringe, a thin line inside it.
	float tw = 0.026;
	float e = min(e_side, e_hem - fringe_h);
	float trim = smoothstep(tw, tw - 0.004, e);
	float inner = smoothstep(0.004, 0.0, abs(e - tw - 0.014));
	vec3 trim_col = gold(gold_c, clamp(e / tw, 0.0, 1.0));
	col = mix(col, trim_col * 0.35, smoothstep(0.004, 0.0, abs(e - tw)) * (1.0 - trim));
	col = mix(col, gold(gold_c, 0.5), inner);
	col = mix(col, trim_col, trim);
	emit += gold_c * (trim * 0.25 + inner * 0.35) * star;
	if (front) {
		// The back: the mongkhon over the yant rows.
		float ring_y = -0.17 * cape_length / 0.56;
		vec2 c = dp - vec2(0.0, ring_y);
		float shade;
		float m = mongkhon(c, shade);
		float halo = smoothstep(0.16, 0.1, length(c)) * star;
		col = mix(col, gold_c * 1.1, halo * 0.15);
		col = mix(col, outer_deep.rgb * 0.35, smoothstep(0.02, 0.0, abs(length(c) - 0.1) - 0.026) * (1.0 - m) * 0.8);
		col = mix(col, gold_c * shade, m);
		emit += gold_c * (m * (0.25 + 0.9 * star) + halo * 0.25);
		float script = yant_rows(dp, ring_y - 0.135, 4.0, 0.034, 0.17, star * TIME * 0.35);
		vec3 ink = star > 0.5 ? mix(gold_c, vec3(1.0, 0.95, 0.7), 0.4) : gold_c;
		col = mix(col, ink, script);
		emit += ink * script * (0.15 + 1.1 * star * (0.8 + 0.2 * sin(TIME * 4.0 + dp.x * 30.0)));
	} else {
		// The lining.
		col = mix(lining_color.rgb * mix(1.2, 0.8, v), trim_col, trim * 0.8);
		emit *= 0.3;
	}
	if (star > 0.5) {
		// Embers rising off the hem.
		vec2 eg = vec2(dp.x * 40.0, (e_hem - TIME * 0.05) * 34.0);
		vec2 id = floor(eg);
		vec2 f = fract(eg) - 0.5;
		float h = hash2(id);
		vec2 o = vec2(hash2(id + 3.1), hash2(id + 5.7)) - 0.5;
		float ember = smoothstep(0.22, 0.0, length(f - o * 0.5)) * step(0.72, h) * smoothstep(0.2, 0.0, e_hem);
		ember *= 0.6 + 0.4 * sin(TIME * (4.0 + h * 6.0) + h * 30.0);
		col = mix(col, vec3(1.0, 0.8, 0.35), ember);
		emit += vec3(1.0, 0.55, 0.15) * ember * 2.2;
		// The hem itself smoulders.
		float burn = smoothstep(0.03, 0.0, e_hem);
		emit += vec3(1.0, 0.5, 0.12) * burn * (0.8 + 0.4 * sin(TIME * 5.0 + dp.x * 40.0));
	}
}

void fragment() {
	if (boxer > 0.5) {
		vec3 bcol;
		vec3 bemit;
		float bcut;
		boxer_paint(cloth, FRONT_FACING, NORMAL, VIEW, pleat_shade, bcol, bemit, bcut);
		if (bcut > 0.5) {
			discard;
		}
		ALBEDO = bcol;
		EMISSION = bemit;
	} else {
	float u = cloth.x;
	float v = cloth.y;
	float s = u * 2.0 - 1.0;
	vec3 gold_c = trim_color.rgb;
	vec3 col;
	float glow = 0.0;
	vec3 glow_rgb = gold_c;
	float tw = 0.022;
	if (kind > 1.5) {
		// The collar's top edge rises in points.
		float tooth = pow(abs(fract(u * 7.0) - 0.5) * 2.0, 0.7);
		if (v < 0.22 * tooth) {
			discard;
		}
		// The collar: velvet facing out, gold at the rim and down the edges.
		float rim = smoothstep(0.2, 0.12, v - 0.22 * tooth);
		float edge = 1.0 - smoothstep(0.04, 0.07, min(u, 1.0 - u));
		col = style > 0.5 ? gold(gold_c, v) : outer_deep.rgb * 0.8;
		col = mix(col, gold(gold_c, fract((1.0 - v) * 4.0)), max(rim, edge));
		if (style > 0.5) {
			// Gold plates with a violet gem row.
			float gem = smoothstep(0.03, 0.0, length(vec2(fract(u * 7.0) - 0.5, (v - 0.45) * 2.4)) - 0.12);
			col = mix(col, glow_color.rgb, gem);
			glow += gem * 1.4 + rim * 0.3;
			glow_rgb = mix(gold_c, glow_color.rgb, gem);
		}
		if (!FRONT_FACING) {
			col = mix(lining_color.rgb, gold_c, rim);
			glow = 0.0;
		}
		ALBEDO = col;
		EMISSION = glow_rgb * glow;
	} else {
		float flare = pow(max(v, 0.0), 0.8);
		float width_here = mix(top_width, hem_width, flare);
		float len_here = cape_length * (1.0 + hem_curve * (1.0 - s * s));
		float e_side = min(u, 1.0 - u) * width_here;
		float e_hem = (1.0 - v) * len_here;
		vec2 dp = vec2((u - 0.5) * width_here, -v * len_here);
		// Hem cut-outs: raven feathers for the star cape, rounded scallops for the capelet.
		float band_at = 0.0;
		float feather_paint = 0.0;
		float feather_x = 0.0;
		float feather_h = 1.0;
		if (feather_len > 0.0 || scallop > 0.0) {
			float n = scallop > 0.0 ? scallop : 13.0;
			float cell = u * n;
			float idx = floor(cell);
			float fx = fract(cell) - 0.5;
			float flen = scallop > 0.0 ? 0.055 : feather_len * mix(0.82, 1.08, hash1(idx + 2.0)) * (mod(idx, 2.0) < 0.5 ? 1.0 : 0.86);
			float h = e_hem / flen;
			float hw = scallop > 0.0 ? 0.5 * sqrt(clamp(h * 1.8, 0.0, 1.0)) : 0.5 * pow(clamp(h * 1.25, 0.0, 1.0), 0.55);
			if (h < 1.0 && abs(fx) > hw) {
				discard;
			}
			band_at = scallop > 0.0 ? 0.055 : feather_len * 1.08;
			if (h < 1.0) {
				feather_paint = 1.0;
				feather_x = fx / max(hw, 0.001);
				feather_h = h;
			}
		}
		// The cloth.
		float sparkle = 0.0;
		if (style > 0.5 && kind < 0.5) {
			col = galaxy(dp * 1.6, sparkle);
			glow += sparkle * 1.6;
		} else {
			col = mix(outer_color.rgb * 1.08, outer_deep.rgb, smoothstep(0.0, 1.0, v));
		}
		if (kind > 0.5) {
			// The capelet: rows of feather scales, outlined in gold.
			float rows = 7.0;
			float rv = dp.y * -rows / max(cape_length, 0.01);
			float row = floor(rv);
			float ru = u * scallop + (mod(row, 2.0) < 0.5 ? 0.0 : 0.5);
			vec2 cell_p = vec2(fract(ru) - 0.5, fract(rv));
			float scale_d = length(cell_p * vec2(1.0, 1.25));
			float scale_line = smoothstep(0.07, 0.0, abs(scale_d - 0.5));
			// Each scale lighter towards its rounded lower edge, like a feather catching light.
			col = mix(outer_deep.rgb, outer_color.rgb, smoothstep(0.15, 0.5, scale_d)) * mix(0.8, 1.15, smoothstep(0.0, 1.0, fract(rv)));
			col = mix(col, gold(gold_c, 0.5), scale_line * 0.9);
			glow += scale_line * 0.45 * style;
		}
		// Velvet sheen at grazing angles.
		float fres = pow(max(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 0.0), 2.0);
		col *= 0.92 + 0.5 * fres;
		// Deeper shade inside the pleats.
		col *= mix(0.78, 1.04, pleat_shade * 0.5 + 0.5);
		// Gold trim down the sides (and along the hem, or above the feathers).
		float e_band = band_at > 0.0 ? abs(e_hem - band_at) : e_hem;
		float e = min(e_side, e_band);
		float trim = 1.0 - smoothstep(tw - 0.003, tw, e);
		vec3 trim_col = gold(gold_c, clamp(e / tw, 0.0, 1.0));
		// Filigree inside the trim: a chain of diamonds and dots.
		float fil = 0.0;
		if (kind < 0.5) {
			float band_x = (e_side - (tw + 0.02)) / 0.012;
			float along = fract(-dp.y * 15.0);
			float dia = abs(band_x) + abs(along - 0.5) * 1.6;
			fil = (smoothstep(0.62, 0.52, dia) - smoothstep(0.42, 0.32, dia)) * step(abs(band_x), 1.2);
			fil += smoothstep(0.2, 0.1, length(vec2(band_x * 0.5, (along - 0.0) * 1.2))) * step(abs(band_x), 1.0);
			float hem_x = (e_band - (tw + 0.02)) / 0.012;
			float along_h = fract(dp.x * 15.0);
			float dia_h = abs(hem_x) + abs(along_h - 0.5) * 1.6;
			fil += (smoothstep(0.62, 0.52, dia_h) - smoothstep(0.42, 0.32, dia_h)) * step(abs(hem_x), 1.2) * step(tw * 2.0, e_side);
			fil = clamp(fil, 0.0, 1.0) * step(tw * 1.5, e);
		}
		col = mix(col, gold(gold_c, 0.55), fil * 0.9);
		// A thin dark line where the trim meets the cloth.
		float seam = smoothstep(0.004, 0.0, abs(e - tw)) * (1.0 - trim);
		col = mix(col, trim_col * 0.35, seam);
		col = mix(col, trim_col, trim);
		glow += (trim * 0.28 + fil * 0.45) * style;
		// The raven feathers of the star hem: violet into a glowing tip, a gold shaft and barbs.
		if (feather_paint > 0.5 && kind < 0.5) {
			float tipness = 1.0 - smoothstep(0.0, 0.75, feather_h);
			vec3 fcol = mix(outer_color.rgb * 1.3, glow_color.rgb, tipness);
			float barb = smoothstep(0.25, 0.0, abs(fract(feather_h * 7.0 + abs(feather_x) * 1.6) - 0.5)) * 0.25;
			fcol *= 1.0 - barb;
			float shaft = smoothstep(0.12, 0.0, abs(feather_x));
			float rim = smoothstep(0.75, 1.0, abs(feather_x));
			fcol = mix(fcol, gold_c * 1.1, max(shaft, rim * 0.8));
			col = fcol;
			glow += tipness * 1.3 + shaft * 0.5 + rim * 0.4;
			glow_rgb = mix(gold_c, glow_color.rgb, tipness);
		}
		// Capelet scallop edges, outlined in gold.
		if (feather_paint > 0.5 && kind > 0.5) {
			float rim = smoothstep(0.62, 0.9, abs(feather_x)) + smoothstep(0.35, 0.0, feather_h);
			col = mix(col, gold(gold_c, 0.5), clamp(rim, 0.0, 1.0));
			glow += rim * 0.3 * style;
		}
		// The crest on the back.
		if (crest > 0.5 && kind < 0.5) {
			vec2 c = (dp - vec2(0.0, -0.47 * cape_length)) / 0.72;
			float hd = raven(c);
			float aa = fwidth(hd) * 1.2;
			float body = 1.0 - smoothstep(-aa, aa, hd);
			float outline = smoothstep(aa + 0.004, 0.0, abs(hd + 0.002)) * (1.0 - body * 0.3);
			// Emboss: lit from the upper left.
			vec2 grad = vec2(dFdx(hd), dFdy(hd));
			float lit = clamp(0.5 + dot(normalize(grad + vec2(1e-6)), vec2(-0.6, 0.8)) * 0.5, 0.0, 1.0);
			vec3 raven_col = gold_c * mix(0.72, 1.08, lit) * mix(1.0, 0.82, smoothstep(-0.02, 0.0, hd));
			float ring = abs(length(c - vec2(0.0, 0.02)) - 0.215) - 0.007;
			float ring_mask = 1.0 - smoothstep(0.0, fwidth(ring) * 1.5, ring);
			float dots = smoothstep(0.012, 0.004, length(vec2(fract(atan(c.y - 0.02, c.x) / (2.0 * PI) * 24.0) - 0.5, (length(c - vec2(0.0, 0.02)) - 0.24) * 30.0)));
			if (style > 0.5) {
				// A gold sunburst behind the crowned raven.
				float ang = atan(c.y - 0.02, c.x);
				float rays = smoothstep(0.35, 0.0, abs(fract(ang / (2.0 * PI) * 16.0) - 0.5)) * smoothstep(0.2, 0.06, length(c)) * smoothstep(0.03, 0.08, length(c));
				col = mix(col, gold_c, rays * 0.35);
				glow += rays * 0.4;
				vec2 k = c - vec2(0.006, 0.165);
				float band = step(abs(k.y), 0.009) * step(abs(k.x), 0.042);
				float spikes = step(abs(fract(k.x * 23.8 + 0.5) - 0.5), 0.2 - k.y * 5.0) * step(0.0, k.y) * step(k.y, 0.04) * step(abs(k.x), 0.042);
				float crown_mask = max(band, spikes);
				col = mix(col, gold(gold_c, 0.5), crown_mask);
				glow += crown_mask * 0.8;
			}
			col = mix(col, trim_col * 0.95, ring_mask);
			col = mix(col, gold_c, dots * 0.9);
			col = mix(col, outer_deep.rgb * 0.4, outline * (1.0 - body));
			col = mix(col, raven_col, body);
			glow += (body * 0.45 + ring_mask * 0.6 + dots * 0.5) * style;
		}
		if (!FRONT_FACING) {
			// The lining, seen from the hero's side.
			vec3 lin = lining_color.rgb * mix(1.15, 0.8, v);
			if (style > 0.5) {
				float sp = 0.0;
				vec3 gx = galaxy(dp * 2.1 + 3.0, sp);
				lin = mix(lin, lining_color.rgb * 1.4, 0.3) + gold_c * sp * 0.6;
				glow = sp * 0.8;
			} else {
				// Quilted diamonds in the lining.
				vec2 qd = abs(fract(dp * vec2(14.0, 14.0) + vec2(dp.y * 14.0, 0.0)) - 0.5);
				lin *= 1.0 - smoothstep(0.04, 0.0, min(qd.x, qd.y)) * 0.35;
				glow = 0.0;
			}
			col = mix(lin, trim_col, trim * 0.8);
			if (feather_paint > 0.5 && kind < 0.5) {
				col = mix(col, glow_color.rgb, 1.0 - smoothstep(0.0, 0.7, feather_h));
			}
		}
		ALBEDO = col;
		EMISSION = glow_rgb * glow;
	}
}
}
