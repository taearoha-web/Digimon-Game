shader_type spatial;
// RamakienArt's spirit sculptures (หนุมาน, ทศกัณฐ์, their spirit fists and the gold ตรีเพชร):
// real volume, softly lit from a key light fixed to the view (so a giant reads from any
// camera), a gold fresnel rim, a jade / emerald body that turns translucent towards its
// edge-on parts and dissolves into mist below the chest (mist_lo .. mist_hi, model y),
// and its gold line work drawn here instead of a forest of separate pieces:
//   COLOR.r  tone (1 lit, lower in crevices), COLOR.g  opacity mask,
//   COLOR.b  material: 0 skin, .25 gold, .5 red, .75 ink, 1 pearl,
//   COLOR.a  inner glow (gems, eyes, the trident's edges),
//   UV2.x    pattern: 0 none, 1 the khon jacket's ลายประจำยาม lattice (UV in model
//            units), 2 / 3 / 4 the masks of หนุมาน / a ยักษ์ / a เทวดา (UV: the face's own
//            -1..1 frame), 5 engraved gold (beads and bands).
// front_push > 0: the figure's depth is drawn just behind front_world (the fighter), so
// the giant standing far behind is hidden by the fighter and the near ground only, not
// by the field between them (its parts keep their own order, a little compressed).
render_mode unshaded, cull_back, blend_mix, depth_draw_always, shadows_disabled, fog_disabled;

uniform vec4 skin : source_color = vec4(0.93, 0.97, 0.95, 1.0);
uniform vec4 skin_dark : source_color = vec4(0.36, 0.58, 0.62, 1.0);
uniform vec4 rim : source_color = vec4(1.0, 0.8, 0.42, 1.0);
uniform vec4 gold : source_color = vec4(0.98, 0.74, 0.3, 1.0);
uniform vec4 gold_dark : source_color = vec4(0.42, 0.2, 0.04, 1.0);
uniform vec4 red : source_color = vec4(0.78, 0.1, 0.14, 1.0);
uniform vec4 ink : source_color = vec4(0.08, 0.14, 0.22, 1.0);
uniform vec4 lines : source_color = vec4(1.0, 0.82, 0.42, 1.0);
uniform float fade = 1.0;
uniform float age = 0.0;
uniform float opacity = 0.95;
uniform float detail = 1.0;
uniform float manifest = 0.0;
uniform float mist_lo = -10.0;
uniform float mist_hi = -9.0;
uniform float yawn_at = -10.0;
uniform float yawn_len = 1.0;
uniform vec3 front_world = vec3(0.0);
uniform float front_push = 0.0;
uniform float lai_scale = 30.0;
uniform float rim_power = 1.0;
// How solid the skin is next to the gold (a halo of spirit arms round solid gold arms).
uniform float skin_alpha = 1.0;

varying vec3 local;
varying float whole;

void vertex() {
	local = VERTEX;
	whole = smoothstep(mist_lo, mist_hi, VERTEX.y);
	if (front_push > 0.0) {
		vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		float anchor = -(MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).z;
		float front = -(VIEW_MATRIX * vec4(front_world, 1.0)).z + front_push;
		float real = -vp.z;
		float fake = max(front + (real - anchor) * 0.12, 0.3);
		fake += (1.0 - whole) * 3.0;
		vec4 clip = PROJECTION_MATRIX * vp;
		vec4 fc = PROJECTION_MATRIX * vec4(0.0, 0.0, -fake, 1.0);
		clip.z = fc.z / fc.w * clip.w;
		POSITION = clip;
	} else {
		// Writing POSITION anywhere means writing it everywhere (it is not filled in otherwise).
		POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	}
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

vec3 mask_yak(vec2 uv, vec3 c, inout float glow) {
	float w = (fwidth(uv.x) + fwidth(uv.y)) * 0.6 + 0.003;
	vec2 q = vec2(abs(uv.x), uv.y);
	// Gold ลายหน้า sweeping from the brow round the cheek, a flame on the forehead.
	float l1 = stroke(q, vec2(0.14, -0.08), vec2(0.7, -0.1), vec2(0.7, 0.4), 0.018, w);
	float l2 = stroke(q, vec2(0.0, 0.42), vec2(0.12, 0.56), vec2(0.04, 0.72), 0.03, w);
	c = mix(c, lines.rgb, max(l1, l2));
	glow += max(l1, l2) * 0.6;
	// Brows: thick, wavy, slanting up from the nose to the temple and curling over.
	vec2 br = bez(q, vec2(0.05, 0.27), vec2(0.36, 0.36), vec2(0.76, 0.58));
	float bw = 0.05 * sin(clamp(br.y * 0.85 + 0.15, 0.0, 1.0) * 3.14159) + 0.012 + 0.01 * sin(br.y * 22.0);
	float brow = fill(br.x - bw, w);
	float edge = fill(br.x - bw - 0.02, w) - brow;
	float curl = fill(abs(length(q - vec2(0.75, 0.64)) - 0.055) - 0.015, w) * step(0.66, q.y + 0.0) * step(q.x, 0.82);
	c = mix(c, lines.rgb, max(edge, curl));
	glow += max(edge, curl) * 0.7;
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
	glow += inside * 0.45;
	float lid = fill(abs(eye) - 0.014 - 0.014 * step(0.0, e.y), w);
	float tail = stroke(q, vec2(0.52, 0.24), vec2(0.62, 0.3), vec2(0.7, 0.42), 0.016, w);
	c = mix(c, ink.rgb, max(lid, tail));
	float ring = fill(abs(eye - 0.03) - 0.008, w) * (1.0 - inside);
	c = mix(c, lines.rgb, ring);
	glow += ring * 0.5;
	// A broad nose, flared nostrils.
	float nose = fill(length((q - vec2(0.075, -0.16)) / vec2(1.0, 0.6)) - 0.024, w);
	c = mix(c, ink.rgb, max(nose, fill(seg(q, vec2(0.0, 0.1), vec2(0.0, -0.1)) - 0.008, w) * 0.5));
	// Moustache curls of gold over the lip.
	float mo = stroke(q, vec2(0.04, -0.27), vec2(0.3, -0.26), vec2(0.42, -0.16), 0.02, w);
	c = mix(c, lines.rgb, mo);
	glow += mo * 0.5;
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

vec3 mask_deva(vec2 uv, vec3 c, inout float glow) {
	float w = (fwidth(uv.x) + fwidth(uv.y)) * 0.6 + 0.003;
	vec2 q = vec2(abs(uv.x), uv.y);
	// Serene: arched brows, downcast eyes, a gentle mouth, a gold ตาที่สาม mark.
	float brow = stroke(q, vec2(0.08, 0.36), vec2(0.36, 0.52), vec2(0.66, 0.38), 0.024, w);
	float lid = stroke(q, vec2(0.16, 0.16), vec2(0.34, 0.06), vec2(0.56, 0.18), 0.026, w);
	float mouth = stroke(q, vec2(0.0, -0.5), vec2(0.14, -0.46), vec2(0.24, -0.4), 0.022, w);
	c = mix(c, ink.rgb, max(brow, lid));
	c = mix(c, red.rgb, mouth);
	float mark = fill(length((uv - vec2(0.0, 0.5)) / vec2(0.6, 1.0)) - 0.05, w);
	c = mix(c, gold.rgb, mark);
	glow += mark * 0.8 + max(brow, lid) * 0.1;
	return c;
}

void fragment() {
	vec3 N = normalize(NORMAL);
	vec3 V = normalize(VIEW);
	vec3 L = normalize(vec3(-0.42, 0.72, 0.56));
	float ndl = dot(N, L);
	float wrap = clamp(ndl * 0.55 + 0.45, 0.0, 1.0);
	float nv = clamp(dot(N, V), 0.0, 1.0);
	float fres = pow(1.0 - nv, 2.3);
	float m = COLOR.b;
	int pat = int(UV2.x + 0.5);
	vec3 base;
	vec3 dark;
	float shine;
	if (m < 0.125) {
		base = skin.rgb;
		dark = skin_dark.rgb;
		shine = 0.3;
	} else if (m < 0.375) {
		base = gold.rgb;
		dark = gold_dark.rgb;
		shine = 1.0;
	} else if (m < 0.625) {
		base = red.rgb;
		dark = red.rgb * 0.3;
		shine = 0.8;
	} else if (m < 0.875) {
		base = ink.rgb;
		dark = ink.rgb * 0.4;
		shine = 0.3;
	} else {
		base = vec3(1.0, 0.98, 0.93);
		dark = vec3(0.6, 0.68, 0.78);
		shine = 0.7;
	}
	float glow = COLOR.a;
	if (pat == 2) {
		float t = age - yawn_at;
		float open = clamp(t / (yawn_len * 0.25), 0.0, 1.0) * clamp((yawn_len - t) / (yawn_len * 0.3), 0.0, 1.0);
		base = mask_hanuman(UV, base, open, glow);
		dark = mix(dark, base * 0.55, 0.5);
	} else if (pat == 3) {
		base = mask_yak(UV, base, glow);
		dark = mix(dark, base * 0.5, 0.5);
	} else if (pat == 4) {
		base = mask_deva(UV, base, glow);
	} else if (pat == 1 && detail > 0.5) {
		float l = lai(UV * lai_scale);
		base = mix(base, lines.rgb, l * 0.38);
		dark = mix(dark, lines.rgb * 0.55, l * 0.3);
		glow += l * 0.22;
	} else if (pat == 5 && detail > 0.5) {
		float e = engrave(UV * lai_scale * 3.2);
		base *= e;
		dark *= mix(1.0, e, 0.5);
	}
	vec3 col = mix(dark, base, smoothstep(0.02, 1.0, wrap)) * mix(0.55, 1.0, COLOR.r);
	vec3 H = normalize(L + V);
	col += pow(max(dot(N, H), 0.0), 32.0) * shine * vec3(1.0, 0.94, 0.78) * 0.65;
	col += rim.rgb * fres * 1.2 * rim_power;
	col += mix(base, lines.rgb, 0.5) * glow * 0.45;
	float alpha = opacity * mix(0.84, 1.0, fres) * whole * COLOR.g;
	if (m < 0.125 && pat != 2 && pat != 3 && pat != 4) {
		alpha *= mix(skin_alpha, 1.0, fres * 0.7);
	}
	// The body condenses from the mist up, a seam of gold light at its edge.
	if (manifest > 0.0) {
		float band = mix(mist_lo - 0.05, 1.08, clamp(age / manifest, 0.0, 1.0));
		float seam = exp(-abs(local.y - band) * 36.0);
		alpha *= smoothstep(band + 0.025, band - 0.025, local.y);
		col += rim.rgb * seam * 1.8;
	}
	// The mist's edge: a faint gold breath where the body thins out.
	col += rim.rgb * (whole * (1.0 - whole)) * 1.2;
	float grain = 0.5 + 0.5 * sin(local.x * 61.0 + local.y * 43.0 - age * 3.0) * sin(local.z * 57.0 + local.x * 29.0);
	float dissolve = smoothstep((1.0 - fade) * 1.1 - 0.1, (1.0 - fade) * 1.1 + 0.1, grain);
	alpha *= dissolve * smoothstep(0.0, 0.1, fade);
	if (alpha < 0.03) {
		discard;
	}
	ALBEDO = col;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
