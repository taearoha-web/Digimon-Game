shader_type spatial;
// A gate giant of ดินแดนเทวาลัย (HeavenYaksha / HeavenYakshaVisual): the same sculpture data
// as RamakienSculpt's khon figures (COLOR.r tone, COLOR.b material: 0 skin, 0.25 gold,
// 0.5 red, 0.75 ivory, 1 jewel; COLOR.a inner glow; UV2.x pattern: 1 the jacket's ลาย,
// 3 the khon yak mask, 5 engraved gold), each part carried by its bone (UV2.y, see
// heaven_yaksha_pose.gdshaderinc). A solid cartoon body: skin wearing ลาย is the costume
// (cloth); cel shaded in two soft bands under a key light fixed to the view (it reads in
// any light), a warm fresnel rim, glowing gems. The club kindles gold through a wind-up
// (club_glow), a blow whitens the body (flash), a cast tints it (glow); fade dissolves it
// into gold. The ink outline is its next pass (heaven_yaksha_outline).
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;
#include "res://shaders/heaven_yaksha_pose.gdshaderinc"

uniform vec4 skin : source_color = vec4(0.27, 0.81, 0.6, 1.0);
uniform vec4 skin_dark : source_color = vec4(0.08, 0.45, 0.35, 1.0);
uniform vec4 cloth : source_color = vec4(0.1, 0.54, 0.4, 1.0);
uniform vec4 cloth_dark : source_color = vec4(0.04, 0.27, 0.22, 1.0);
uniform vec4 gold : source_color = vec4(1.0, 0.78, 0.29, 1.0);
uniform vec4 gold_dark : source_color = vec4(0.5, 0.26, 0.05, 1.0);
uniform vec4 red : source_color = vec4(0.83, 0.17, 0.24, 1.0);
uniform vec4 ivory : source_color = vec4(1.0, 0.96, 0.88, 1.0);
uniform vec4 jewel : source_color = vec4(1.0, 0.3, 0.37, 1.0);
uniform vec4 ink : source_color = vec4(0.07, 0.23, 0.2, 1.0);
uniform vec4 lines : source_color = vec4(1.0, 0.85, 0.44, 1.0);
uniform vec4 rim : source_color = vec4(1.0, 0.94, 0.7, 1.0);
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float glow = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.4, 1.0);
uniform float club_glow = 0.0;
uniform float detail = 1.0;
uniform float lai_scale = 15.0;

varying vec3 rest;
varying vec2 info;

void vertex() {
	rest = VERTEX;
	info = UV2;
	vec3 p = VERTEX;
	vec3 n = NORMAL;
	pose_part(p, n, UV2.y);
	VERTEX = p;
	NORMAL = n;
}

float fill(float d, float w) {
	return 1.0 - smoothstep(-w, w, d);
}

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
	return length(pa - ba * h);
}

// Distance to a quadratic curve a-b-c, and where along it (0..1).
vec2 bez(vec2 p, vec2 a, vec2 b, vec2 c) {
	float best = 1e5;
	float bt = 0.0;
	vec2 prev = a;
	for (int i = 1; i <= 9; i++) {
		float t = float(i) / 9.0;
		vec2 q = mix(mix(a, b, t), mix(b, c, t), t);
		vec2 pa = p - prev;
		vec2 ba = q - prev;
		float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
		float d = length(pa - ba * h);
		if (d < best) {
			best = d;
			bt = (float(i - 1) + h) / 9.0;
		}
		prev = q;
	}
	return vec2(best, bt);
}

// A tapered brush stroke along a curve: thick in the middle, pointed at the ends.
float stroke(vec2 p, vec2 a, vec2 b, vec2 c, float width, float w) {
	vec2 k = bez(p, a, b, c);
	return fill(k.x - width * sin(clamp(k.y, 0.0, 1.0) * 3.14159) - 0.002, w);
}

// ลายประจำยาม: four-petal rosettes in a diamond lattice (the khon jacket's embroidery).
float lai(vec2 p) {
	vec2 g = vec2(p.x + p.y, p.x - p.y) * 0.7071;
	vec2 c = fract(g) - 0.5;
	float fw = fwidth(g.x) + fwidth(g.y);
	float w = fw * 0.7 + 0.008;
	float r = length(c);
	float a = atan(c.y, c.x);
	float petal = 0.27 * (0.42 + 0.58 * abs(cos(2.0 * a)));
	float ring = fill(abs(r - petal) - 0.018, w);
	float bud = fill(r - 0.055, w);
	float lattice = fill(0.5 - max(abs(c.x), abs(c.y)) - 0.012, w);
	return max(max(ring, bud), lattice * 0.7) * (1.0 - smoothstep(0.18, 0.4, fw));
}

// Engraved gold: rows of beads between fine bands.
float engrave(vec2 p) {
	vec2 q = vec2(p.x * 2.2, p.y * 1.4);
	vec2 c = fract(q) - 0.5;
	float fw = fwidth(q.x) + fwidth(q.y);
	float bead = smoothstep(0.5, 0.15, length(c * vec2(1.0, 1.25)));
	float band = smoothstep(0.08, 0.0, abs(c.y) - 0.42);
	return mix(0.78 + 0.22 * bead - 0.2 * band, 0.88, smoothstep(0.25, 0.6, fw));
}

// A Thai almond eye (two arcs meeting in points), tilted up to the temple.
float almond(vec2 p, vec2 c, float w, float h, float tilt) {
	vec2 e = p - c;
	float cs = cos(tilt);
	float sn = sin(tilt);
	e = vec2(e.x * cs + e.y * sn, -e.x * sn + e.y * cs);
	float r = (w * w * 0.25 + h * h * 0.25) / h;
	float off = r - h * 0.5;
	return max(length(e - vec2(0.0, -off)) - r, length(e + vec2(0.0, -off)) - r);
}

vec2 tilted(vec2 p, vec2 c, float tilt) {
	vec2 e = p - c;
	float cs = cos(tilt);
	float sn = sin(tilt);
	return vec2(e.x * cs + e.y * sn, -e.x * sn + e.y * cs);
}


vec3 mask_yak(vec2 uv, vec3 c, inout float lit_io) {
	float w = (fwidth(uv.x) + fwidth(uv.y)) * 0.6 + 0.003;
	vec2 q = vec2(abs(uv.x), uv.y);
	// Gold ลายหน้า sweeping from the brow round the cheek, a flame on the forehead.
	float l1 = stroke(q, vec2(0.14, -0.08), vec2(0.7, -0.1), vec2(0.7, 0.4), 0.018, w);
	float l2 = stroke(q, vec2(0.0, 0.42), vec2(0.12, 0.56), vec2(0.04, 0.72), 0.03, w);
	c = mix(c, lines.rgb, max(l1, l2));
	lit_io += max(l1, l2) * 0.6;
	// Brows: thick, wavy, slanting up from the nose to the temple and curling over.
	vec2 br = bez(q, vec2(0.05, 0.27), vec2(0.36, 0.36), vec2(0.76, 0.58));
	float bw = 0.05 * sin(clamp(br.y * 0.85 + 0.15, 0.0, 1.0) * 3.14159) + 0.012 + 0.01 * sin(br.y * 22.0);
	float brow = fill(br.x - bw, w);
	float edge = fill(br.x - bw - 0.02, w) - brow;
	float curl = fill(abs(length(q - vec2(0.75, 0.64)) - 0.055) - 0.015, w) * step(0.66, q.y + 0.0) * step(q.x, 0.82);
	c = mix(c, lines.rgb, max(edge, curl));
	lit_io += max(edge, curl) * 0.7;
	c = mix(c, ink.rgb, brow);
	// Staring eyes (ตาโพลง): wide slanted almonds, a gold-ringed red iris, a dark pupil.
	float eye = almond(q, vec2(0.34, 0.15), 0.4, 0.2, 0.36);
	vec2 e = tilted(q, vec2(0.34, 0.15), 0.36);
	float inside = fill(eye, w);
	float r = length(e);
	vec3 eyec = vec3(1.0, 0.95, 0.8);
	eyec = mix(eyec, gold.rgb * 1.1, fill(r - 0.085, w));
	eyec = mix(eyec, vec3(0.86, 0.24, 0.04), fill(r - 0.068, w));
	eyec = mix(eyec, vec3(0.02, 0.01, 0.01), fill(r - 0.036, w));
	eyec = mix(eyec, vec3(1.0), fill(length(e - vec2(-0.028, 0.026)) - 0.013, w));
	c = mix(c, eyec, inside);
	lit_io += inside * 0.45;
	float lid = fill(abs(eye) - 0.014 - 0.014 * step(0.0, e.y), w);
	float tail = stroke(q, vec2(0.52, 0.24), vec2(0.62, 0.3), vec2(0.7, 0.42), 0.016, w);
	c = mix(c, ink.rgb, max(lid, tail));
	float ring = fill(abs(eye - 0.03) - 0.008, w) * (1.0 - inside);
	c = mix(c, lines.rgb, ring);
	lit_io += ring * 0.5;
	// A broad nose, flared nostrils.
	float nose = fill(length((q - vec2(0.075, -0.16)) / vec2(1.0, 0.6)) - 0.024, w);
	c = mix(c, ink.rgb, max(nose, fill(seg(q, vec2(0.0, 0.1), vec2(0.0, -0.1)) - 0.008, w) * 0.5));
	// Moustache curls of gold over the lip.
	float mo = stroke(q, vec2(0.04, -0.27), vec2(0.3, -0.26), vec2(0.42, -0.16), 0.02, w);
	c = mix(c, lines.rgb, mo);
	lit_io += mo * 0.5;
	// The snarl (ปากแสยะ): lips drawn back and down at the corners over gritted teeth,
	// fangs rising from the corners.
	float x = uv.x;
	float up = -0.4 - 0.34 * x * x;
	float lo = up - 0.08 - 0.03 * (1.0 - abs(x) / 0.42);
	float md = max(max(uv.y - up, lo - uv.y), abs(x) - 0.42);
	float mouth = fill(md, w);
	float gaps = fill(abs(fract(x * 8.0) - 0.5) - 0.45, w * 8.0);
	float bite = fill(abs(uv.y - (up + lo) * 0.5) - 0.005, w);
	vec3 mc = mix(vec3(1.0, 0.96, 0.86), vec3(0.45, 0.38, 0.34), max(gaps, bite) * 0.65);
	c = mix(c, mc, mouth);
	float lips = fill(abs(md) - 0.02, w);
	c = mix(c, red.rgb, lips);
	vec2 fa = vec2(0.37, lo + 0.01);
	vec2 fb = vec2(0.43, -0.22);
	float fd = seg(q, fa, fb) - 0.03 * clamp((fb.y - q.y) / (fb.y - fa.y), 0.0, 1.0);
	c = mix(c, vec3(1.0, 0.98, 0.9), fill(fd, w));
	c = mix(c, ink.rgb, fill(abs(fd) - 0.005, w) * 0.6);
	return c;
}

void fragment() {
	// The dissolve first (cheap discard before any shading).
	float grain = yak_blotch(rest * 34.0);
	float cut = (1.0 - fade) * 1.15 - 0.08;
	if (fade < 0.999 && grain < cut) {
		discard;
	}
	vec3 N = normalize(NORMAL);
	vec3 V = normalize(VIEW);
	vec3 L = normalize(vec3(-0.45, 0.75, 0.5));
	float wrap = clamp(dot(N, L) * 0.6 + 0.4, 0.0, 1.0);
	float nv = clamp(dot(N, V), 0.0, 1.0);
	float m = COLOR.b;
	int pat = int(info.x + 0.5);
	int part = int(info.y + 0.5);
	vec3 base;
	vec3 dark;
	float shine;
	if (m < 0.125) {
		if (pat == 1) {
			base = cloth.rgb;
			dark = cloth_dark.rgb;
			shine = 0.35;
		} else {
			base = skin.rgb;
			dark = skin_dark.rgb;
			shine = 0.3;
		}
	} else if (m < 0.375) {
		base = gold.rgb;
		dark = gold_dark.rgb;
		shine = 1.0;
	} else if (m < 0.625) {
		base = red.rgb;
		dark = red.rgb * 0.42;
		shine = 0.7;
	} else if (m < 0.875) {
		base = ivory.rgb;
		dark = ivory.rgb * vec3(0.7, 0.66, 0.62);
		shine = 0.6;
	} else {
		base = jewel.rgb;
		dark = jewel.rgb * 0.5;
		shine = 1.0;
	}
	float lit = COLOR.a;
	if (pat == 3) {
		base = mask_yak(UV, base, lit);
		dark = mix(dark, base * 0.6, 0.55);
	} else if (pat == 1 && detail > 0.5) {
		float l = lai(UV * lai_scale);
		base = mix(base, lines.rgb, l * 0.6);
		dark = mix(dark, lines.rgb * 0.55, l * 0.5);
		lit += l * 0.12;
	} else if (pat == 5 && detail > 0.5) {
		float e = engrave(UV * lai_scale * 3.2);
		base *= e;
		dark *= mix(1.0, e, 0.5);
	}
	// Two cel bands with a soft edge, crevices darker (tone).
	float band = smoothstep(0.38, 0.46, wrap) * 0.7 + smoothstep(0.78, 0.84, wrap) * 0.3;
	vec3 col = mix(dark, base, band) * mix(0.62, 1.0, COLOR.r);
	vec3 H = normalize(L + V);
	col += step(0.93, dot(N, H)) * shine * vec3(1.0, 0.95, 0.8) * 0.45;
	float fres = smoothstep(0.62, 0.9, 1.0 - nv);
	col += rim.rgb * fres * 0.5;
	col += mix(base, lines.rgb, 0.5) * lit * 0.5;
	// The club kindles through the wind-up.
	if (part == 11) {
		col = mix(col, glow_color.rgb * 1.3 + 0.1, club_glow * (0.35 + 0.5 * fres));
	}
	col = mix(col, glow_color.rgb, glow);
	// The gold seam at the dissolving edge.
	if (fade < 0.999) {
		col = mix(col, vec3(1.0, 0.86, 0.45) * 1.6, smoothstep(0.1, 0.0, grain - cut));
	}
	col = mix(col, flash_color.rgb, flash);
	ALBEDO = col;
}
