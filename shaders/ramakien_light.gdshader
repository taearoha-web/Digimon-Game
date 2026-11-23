shader_type spatial;
// RamakienArt's light: luminous pieces drawn in premultiplied alpha, so one shader both
// adds light (glows, the crescent's halo, star glints, shafts, embers, gold cracks) and
// lays soft colour over the field (mist, temple glass, flame). On quads with UV 0..1:
//   0 soft glow          1 the aureole of flame tongues behind a giant's heads
//   2 crescent moon      3 four-point star glint     4 light shaft (UV.y up)
//   5 drifting embers (a mesh of tiny quads, animated here; UV2 = phase, speed)
//   6 temple glass mosaic cracking out from the centre over `spread` seconds
//   7 comet trail (UV.x 0 tail .. 1 head)  8 flame wisp  9 cloud bank, gold edged
//   10 impact flash with rays
render_mode unshaded, cull_disabled, blend_premul_alpha, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color_a : source_color = vec4(1.0, 0.68, 0.22, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.95, 0.78, 1.0);
uniform vec4 color_c : source_color = vec4(0.1, 0.7, 0.5, 1.0);
uniform int mode = 0;
uniform float fade = 1.0;
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform float spread = 0.5;
uniform float seed = 0.0;
uniform vec3 front_world = vec3(0.0);
uniform float front_push = 0.0;

varying float life;

void vertex() {
	life = 1.0;
	vec4 vp;
	if (mode == 5) {
		float t = fract(age * (0.16 + 0.16 * UV2.y) + UV2.x);
		vec3 c = VERTEX + vec3(sin(t * 5.0 + UV2.x * 40.0) * 0.1, t * 0.8, cos(t * 4.0 + UV2.y * 31.0) * 0.1);
		vp = MODELVIEW_MATRIX * vec4(c, 1.0);
		float s = length(MODELVIEW_MATRIX[0].xyz) * (0.008 + 0.012 * UV2.y);
		vp.xy += (UV * 2.0 - 1.0) * s;
		life = sin(t * 3.14159);
	} else {
		vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	}
	// POSITION is written on every path (it is not filled in otherwise).
	vec4 clip = PROJECTION_MATRIX * vp;
	if (front_push > 0.0) {
		// A giant's light: drawn at its depth (just behind the fighter), see RamakienSpirit.
		float fake = max(-(VIEW_MATRIX * vec4(front_world, 1.0)).z + front_push, 0.3);
		vec4 fc = PROJECTION_MATRIX * vec4(0.0, 0.0, -fake, 1.0);
		clip.z = fc.z / fc.w * clip.w;
	}
	POSITION = clip;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 p = uv * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	vec3 add = vec3(0.0);
	vec3 paint = vec3(0.0);
	float cover = 0.0;
	float fw = fwidth(r) + 0.002;
	if (mode == 0) {
		float g = exp(-r * r * 3.6) * (1.0 - smoothstep(0.8, 1.0, r));
		add = mix(color_a.rgb, color_b.rgb, exp(-r * r * 16.0)) * g;
	} else if (mode == 1) {
		// ประภามณฑล: a disc of soft light inside a ring of flame tongues (กนก, leaning one
		// way), slowly turning; gold, never white.
		float a = ang + age * 0.08;
		float k = a * 18.0;
		float tongue = pow(0.5 + 0.5 * cos(k + 1.1 * sin(k)), 4.0);
		float tip = 0.64 + 0.3 * tongue;
		float flame = smoothstep(tip, tip - 0.14, r) * smoothstep(0.56, 0.64, r) * (0.35 + 0.65 * tongue);
		float inner = exp(-r * r * 3.0) * smoothstep(0.7, 0.3, r);
		float ring = exp(-abs(r - 0.58) * 90.0) + 0.45 * exp(-abs(r - 0.53) * 140.0);
		add = color_a.rgb * (flame * 0.28 + inner * 0.12 + ring * 0.5);
	} else if (mode == 2) {
		// The crescent: a crisp lit sliver, the dark of the moon faintly lit, a wide halo.
		float disc = 1.0 - smoothstep(0.42 - fw, 0.42 + fw, r);
		float cut = 1.0 - smoothstep(0.39 - fw, 0.39 + fw, length(p - vec2(0.17, 0.1)));
		float sliver = disc * (1.0 - cut);
		float halo = exp(-max(r - 0.42, 0.0) * 7.0) * 0.3 * (1.0 - smoothstep(0.8, 1.0, r));
		vec3 lit = mix(color_b.rgb, vec3(1.0, 0.99, 0.94), smoothstep(0.3, 0.42, r));
		add = color_a.rgb * halo + color_a.rgb * disc * cut * 0.12;
		paint = lit;
		cover = sliver * 0.92;
		add += lit * sliver * 0.25;
	} else if (mode == 3) {
		float tw = 0.75 + 0.25 * sin(age * 9.0 + seed * 7.0);
		float flare = exp(-abs(p.x) * 26.0) * exp(-abs(p.y) * 2.6) + exp(-abs(p.y) * 26.0) * exp(-abs(p.x) * 2.6);
		vec2 d = vec2(p.x + p.y, p.x - p.y) * 0.7071;
		flare += 0.4 * (exp(-abs(d.x) * 30.0) * exp(-abs(d.y) * 5.0) + exp(-abs(d.y) * 30.0) * exp(-abs(d.x) * 5.0));
		float core = exp(-r * r * 60.0);
		float halo = exp(-r * r * 7.0) * 0.35;
		add = color_a.rgb * (flare * tw + halo) + color_b.rgb * core * 1.4;
		add *= 1.0 - smoothstep(0.85, 1.0, r);
	} else if (mode == 4) {
		float x = uv.x * 2.0 - 1.0;
		float beam = exp(-x * x * 7.0) * smoothstep(0.0, 0.25, uv.y) * smoothstep(1.0, 0.55, uv.y);
		float motes = 0.75 + 0.25 * sin(uv.y * 30.0 - age * 1.6 + x * 4.0);
		add = mix(color_a.rgb, color_b.rgb, exp(-x * x * 30.0)) * beam * motes * 0.55;
	} else if (mode == 5) {
		float g = exp(-r * r * 5.0);
		add = mix(color_a.rgb, color_b.rgb, exp(-r * r * 20.0)) * g * life * 1.4;
	} else if (mode == 6) {
		// Temple glass: lotus-arched panes in rings round the slam, thin seams of gold light,
		// a few panes of jade, red and gold glass; the crack front runs out, then all fades.
		float reach = clamp(age / max(spread, 0.01), 0.0, 1.2);
		float wob = 0.035 * sin(ang * 7.0 + seed) + 0.02 * sin(ang * 17.0 - seed * 2.0);
		float rc = (r + wob) * 7.0;
		float ri = floor(rc);
		float nseg = 8.0 + 5.0 * ri;
		float sc = (ang / 6.28318 + 0.5) * nseg + ri * 0.5;
		float fs = fract(sc);
		// Each pane's outer edge bows out like a lotus petal; the next ring is offset half
		// a pane, so the spokes meet the petals' crowns (a petal / scale mosaic).
		float arch = 0.42 * sqrt(max(1.0 - pow(2.0 * fs - 1.0, 2.0), 0.0));
		float rc2 = rc - arch;
		float e1 = 0.5 - abs(fract(rc2) - 0.5);
		float e2 = (0.5 - abs(fs - 0.5)) * 6.28318 * max(rc, 0.4) / nseg;
		float e = min(e1, e2 * 1.1);
		float few = fwidth(rc) * 0.9 + 0.006;
		float seam = 1.0 - smoothstep(0.012, 0.012 + few, e);
		float glowseam = exp(-e * 14.0) * 0.35;
		float id = hash(vec2(floor(rc2), floor(sc - 0.5 * floor(rc2) + 0.5 * ri)) + seed);
		vec3 glass = id < 0.12 ? color_c.rgb : (id < 0.2 ? vec3(0.72, 0.1, 0.14) : color_a.rgb * 0.8);
		float has = id < 0.2 ? 0.8 : (id < 0.26 ? 0.5 : 0.0);
		float inside = 1.0 - smoothstep(reach - 0.05, reach, r);
		float front = exp(-abs(r - reach) * 22.0) * step(reach, 1.05);
		float edge = 1.0 - smoothstep(0.55, 1.0, r);
		float shimmer = 0.7 + 0.3 * sin(age * 3.0 - r * 12.0 + ang * 3.0);
		add = (mix(color_a.rgb, color_b.rgb, 0.45) * seam * shimmer * 0.9 + color_a.rgb * glowseam * 0.6) * inside * edge + color_a.rgb * front * 0.7 * edge;
		paint = glass;
		cover = has * inside * edge * 0.22 * (1.0 - seam);
	} else if (mode == 7) {
		float head = smoothstep(0.0, 1.0, uv.x);
		float wdt = 0.08 + 0.42 * pow(head, 0.7);
		float y = (uv.y - 0.5) * 2.0;
		float body = exp(-y * y / (wdt * wdt) * 1.6) * pow(head, 1.4) * smoothstep(1.0, 0.92, uv.x);
		add = mix(color_a.rgb, color_b.rgb, pow(head, 3.0) * exp(-y * y * 8.0)) * body * 1.5;
	} else if (mode == 8) {
		// A flame wisp: a flickering teardrop, red-orange skin round a gold heart.
		float y = uv.y;
		float sway = sin(y * 6.0 - age * 10.0 + seed * 5.0) * 0.08 * y;
		float x = (uv.x - 0.5 + sway) * 2.0;
		float width = 0.62 * pow(clamp(1.0 - y, 0.0, 1.0), 0.75) * smoothstep(0.0, 0.25, y) + 0.001;
		float d = abs(x) / width;
		float body = smoothstep(1.0, 0.7, d);
		float core = smoothstep(0.6, 0.1, d) * smoothstep(0.75, 0.2, y);
		paint = mix(color_a.rgb, color_b.rgb, core);
		cover = body * 0.85;
		add = color_a.rgb * body * 0.3;
	} else if (mode == 9) {
		// A bank of cloud (เมฆ): scalloped tops edged in gold, soft and drifting.
		float s = uv.x * 5.0 + age * 0.06 + seed;
		float f = fract(s);
		float bump = sqrt(max(1.0 - pow(2.0 * f - 1.0, 2.0), 0.0));
		float s2 = uv.x * 8.0 - age * 0.05 + 0.37 + seed;
		float f2 = fract(s2);
		float bump2 = sqrt(max(1.0 - pow(2.0 * f2 - 1.0, 2.0), 0.0));
		float top = max(0.45 + 0.28 * bump, 0.35 + 0.22 * bump2);
		float sidefade = smoothstep(0.0, 0.18, uv.x) * smoothstep(1.0, 0.82, uv.x);
		float body = smoothstep(top, top - 0.12, uv.y) * smoothstep(0.0, 0.35, uv.y) * sidefade;
		float rimd = abs(uv.y - top + 0.012);
		float goldrim = exp(-rimd * 90.0) * sidefade * smoothstep(0.0, 0.3, uv.y);
		vec2 cq = vec2((f - 0.5) * 0.4, uv.y - (top - 0.17));
		float curl = exp(-abs(length(cq) - 0.07) * 120.0) * step(cq.y, 0.02) * sidefade * 0.6;
		body = smoothstep(top, top - 0.22, uv.y) * smoothstep(0.0, 0.45, uv.y) * sidefade;
		paint = mix(color_b.rgb * 0.75, color_b.rgb, smoothstep(top - 0.3, top, uv.y));
		cover = body * 0.42;
		add = color_a.rgb * (goldrim * 0.65 + curl * body * 0.8);
	} else if (mode == 10) {
		float rays = pow(abs(cos(ang * 6.0 + seed)), 18.0) * exp(-r * 2.4) * 0.8;
		rays += pow(abs(cos(ang * 6.0 + seed + 0.26)), 30.0) * exp(-r * 3.4) * 0.5;
		float core = exp(-r * r * 10.0);
		add = color_a.rgb * (rays + core * 0.6) + color_b.rgb * exp(-r * r * 40.0);
		add *= 1.0 - smoothstep(0.85, 1.0, r);
	}
	float k = fade * opacity;
	ALBEDO = (add + paint * cover) * k;
	ALPHA = clamp(cover * k, 0.0, 1.0);
}
