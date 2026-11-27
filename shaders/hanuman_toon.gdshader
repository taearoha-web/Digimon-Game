shader_type spatial;
// หนุมาน as a fighting companion (HanumanAvatar / HanumanSculpt): the same sculpture data as
// RamakienArt's spirit giants (COLOR.r tone, COLOR.b material, COLOR.a inner glow, UV2.x
// pattern: 1 the jacket's ลาย, 2 the khon mask, 5 engraved gold), but a solid cartoon body:
// cel shaded in two soft bands under a key light fixed to the view (it reads in any zone,
// day or night), a gold fresnel rim, glowing gems, and the mask's mouth opening on the yawn
// (mouth_open). fade 0..1 condenses it from (and dissolves it into) gold sparks; flash whitens
// it on a blow. The ink outline is HanumanAvatar's second pass (hanuman_outline).
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;

uniform vec4 skin : source_color = vec4(0.97, 0.98, 0.95, 1.0);
uniform vec4 skin_dark : source_color = vec4(0.62, 0.7, 0.8, 1.0);
uniform vec4 rim : source_color = vec4(1.0, 0.8, 0.42, 1.0);
uniform vec4 gold : source_color = vec4(0.98, 0.74, 0.3, 1.0);
uniform vec4 gold_dark : source_color = vec4(0.5, 0.25, 0.05, 1.0);
uniform vec4 red : source_color = vec4(0.82, 0.12, 0.16, 1.0);
uniform vec4 ink : source_color = vec4(0.1, 0.12, 0.22, 1.0);
uniform vec4 lines : source_color = vec4(1.0, 0.8, 0.38, 1.0);
uniform float fade = 1.0;
uniform float flash = 0.0;
uniform float mouth_open = 0.0;
uniform float detail = 1.0;
uniform float lai_scale = 15.0;

varying vec3 local;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// Soft blotches (value noise, two octaves) for the gold dissolve.
float blotch(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n = mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
	return n;
}

void vertex() {
	local = VERTEX;
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

// The khon masks: features as brush work on the face's -1..1 frame (x across, y up).
vec3 mask_hanuman(vec2 uv, vec3 c, float open, inout float glow) {
	float w = (fwidth(uv.x) + fwidth(uv.y)) * 0.6 + 0.003;
	vec2 q = vec2(abs(uv.x), uv.y);
	// ลายหน้า: fine gold curls from the nose round the cheek, a red flame under the eye.
	float l1 = stroke(q, vec2(0.1, -0.04), vec2(0.62, -0.08), vec2(0.64, 0.34), 0.016, w);
	float l2 = stroke(q, vec2(0.3, -0.12), vec2(0.5, -0.24), vec2(0.42, -0.36), 0.024, w);
	float l3 = stroke(q, vec2(0.14, 0.62), vec2(0.36, 0.7), vec2(0.6, 0.6), 0.014, w);
	c = mix(c, lines.rgb, max(l1, l3));
	c = mix(c, red.rgb, l2 * 0.85);
	glow += max(l1, l3) * 0.6;
	// Brows: a noble arch, a fine ink line over a red one, curling out at the temple.
	float brow = stroke(q, vec2(0.07, 0.33), vec2(0.38, 0.5), vec2(0.7, 0.4), 0.03, w);
	float under = stroke(q, vec2(0.12, 0.27), vec2(0.4, 0.42), vec2(0.66, 0.33), 0.016, w);
	float curl = fill(abs(length(q - vec2(0.7, 0.47)) - 0.045) - 0.01, w) * step(q.x, 0.74);
	c = mix(c, red.rgb, under);
	c = mix(c, ink.rgb, max(brow, curl));
	// Eyes: almond, slanted, gold iris, dark pupil, a glint; a heavy upper lid, a tail.
	float eye = almond(q, vec2(0.34, 0.15), 0.36, 0.15, 0.24);
	vec2 e = tilted(q, vec2(0.34, 0.15), 0.24);
	float inside = fill(eye, w);
	float ir = length(e - vec2(-0.012, 0.0));
	vec3 eyec = vec3(1.0, 0.97, 0.88);
	eyec = mix(eyec, gold.rgb * 1.1, fill(ir - 0.068, w));
	eyec = mix(eyec, vec3(0.5, 0.16, 0.02), fill(ir - 0.05, w));
	eyec = mix(eyec, vec3(0.02, 0.02, 0.03), fill(ir - 0.032, w));
	eyec = mix(eyec, vec3(1.0), fill(length(e - vec2(-0.03, 0.022)) - 0.012, w));
	c = mix(c, eyec, inside);
	glow += inside * 0.35;
	float lid = fill(abs(eye) - 0.012 - 0.012 * step(0.0, e.y), w);
	float tail = stroke(q, vec2(0.5, 0.21), vec2(0.6, 0.25), vec2(0.68, 0.34), 0.014, w);
	c = mix(c, ink.rgb, max(lid, tail));
	// Nose: a ridge, curled nostrils.
	float nose = max(fill(seg(q, vec2(0.0, 0.1), vec2(0.0, -0.14)) - 0.008, w) * 0.5, fill(length((q - vec2(0.065, -0.18)) / vec2(1.0, 0.6)) - 0.018, w));
	c = mix(c, ink.rgb, nose * 0.75);
	// The forehead's diamond (เพชร), gold round a red heart.
	vec2 fj = vec2(q.x, uv.y - 0.6);
	float dia = abs(fj.x) * 1.5 + abs(fj.y) - 0.1;
	c = mix(c, gold.rgb, fill(dia, w));
	c = mix(c, red.rgb * 1.2, fill(dia + 0.04, w));
	glow += fill(dia, w) * 0.7;
	// The mouth, open (wider on the yawn): the corners turned down, a row of teeth under
	// the upper lip, fangs; dark within, edged in red and a thread of gold.
	float o = 0.25 + 0.75 * open;
	float x = uv.x;
	float y0 = -0.5;
	float up = y0 + 0.07 - 0.32 * x * x;
	float lo = y0 - (0.1 + 0.2 * o) * sqrt(max(1.0 - pow(x / (0.36 + 0.05 * o), 2.0), 0.0)) + 0.02;
	float md = max(max(uv.y - up, lo - uv.y), abs(x) - (0.36 + 0.05 * o));
	float mouth = fill(md, w);
	vec3 mc = mix(vec3(0.18, 0.0, 0.03), vec3(0.55, 0.08, 0.1), smoothstep(lo, up, uv.y) * 0.6);
	float teeth = fill(max(uv.y - (up - 0.004), up - 0.045 - uv.y), w);
	float gaps = fill(abs(fract(x * 9.0) - 0.5) - 0.46, w * 9.0);
	mc = mix(mc, mix(vec3(1.0, 0.97, 0.88), vec3(0.6, 0.5, 0.45), gaps * 0.6), teeth);
	float fang_up = fill(seg(q, vec2(0.25, up + 0.01 - 0.32 * (0.0625 - x * x) * 0.0), vec2(0.24, up - 0.14)) - 0.028 * clamp((uv.y - (up - 0.14)) * 6.0, 0.0, 1.0), w);
	float fang_lo = fill(seg(q, vec2(0.28, lo + 0.02), vec2(0.285, lo + 0.12)) - 0.024 * clamp((lo + 0.12 - uv.y) * 7.0, 0.0, 1.0), w);
	c = mix(c, mc, mouth);
	c = mix(c, vec3(1.0, 0.98, 0.9), max(fang_up, fang_lo) * mouth);
	float lip = fill(abs(md) - 0.018, w);
	c = mix(c, red.rgb, lip);
	float edge = fill(abs(md - 0.03) - 0.007, w) * (1.0 - mouth);
	c = mix(c, lines.rgb, edge);
	glow += edge * 0.6;
	return c;
}


void fragment() {
	// The dissolve first (cheap discard before any shading).
	float grain = blotch(local * 38.0);
	float cut = (1.0 - fade) * 1.15 - 0.08;
	if (fade < 0.999 && grain < cut) {
		discard;
	}
	vec3 N = normalize(NORMAL);
	vec3 V = normalize(VIEW);
	vec3 L = normalize(vec3(-0.45, 0.75, 0.5));
	float ndl = dot(N, L);
	float wrap = clamp(ndl * 0.6 + 0.4, 0.0, 1.0);
	float nv = clamp(dot(N, V), 0.0, 1.0);
	float m = COLOR.b;
	int pat = int(UV2.x + 0.5);
	vec3 base;
	vec3 dark;
	float shine;
	if (m < 0.125) {
		base = skin.rgb;
		dark = skin_dark.rgb;
		shine = 0.25;
	} else if (m < 0.375) {
		base = gold.rgb;
		dark = gold_dark.rgb;
		shine = 1.0;
	} else if (m < 0.625) {
		base = red.rgb;
		dark = red.rgb * 0.45;
		shine = 0.7;
	} else if (m < 0.875) {
		base = ink.rgb;
		dark = ink.rgb * 0.5;
		shine = 0.3;
	} else {
		base = vec3(1.0, 0.98, 0.93);
		dark = vec3(0.6, 0.68, 0.78);
		shine = 0.7;
	}
	float glow = COLOR.a;
	if (pat == 2) {
		base = mask_hanuman(UV, base, mouth_open, glow);
		dark = mix(dark, base * 0.62, 0.55);
	} else if (pat == 1 && detail > 0.5) {
		float l = lai(UV * lai_scale);
		base = mix(base, lines.rgb, l * 0.55);
		dark = mix(dark, lines.rgb * 0.6, l * 0.45);
		glow += l * 0.15;
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
	col += rim.rgb * fres * 0.55;
	col += mix(base, lines.rgb, 0.5) * glow * 0.5;
	// The gold seam at the dissolving edge.
	if (fade < 0.999) {
		col = mix(col, vec3(1.0, 0.86, 0.45) * 1.6, smoothstep(0.1, 0.0, grain - cut));
	}
	col = mix(col, vec3(1.0, 0.97, 0.86), flash);
	ALBEDO = col;
}
