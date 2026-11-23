shader_type spatial;
// Electric arcs of a +10..+15 weapon (EnhanceWeaponFx), all drawn here: no script
// runs per frame. One mesh holds every arc of a weapon:
//  * strands (COLOR.r = 0): a quad along the weapon's long axis (+Y). Its vertices sit
//    on the strand's axis; UV.x (0 / 1) says which side, and the vertex stage turns
//    the quad to face the camera around that axis, COLOR.g * 0.5 wide each side.
//    UV2 = (seed, length). Each strand throws one or two jagged bolts (with short
//    branches) between two points of the weapon, re-routed several times a second.
//  * hand rings (COLOR.r = 1): a flat quad around the hand (UV the corner), UV2 =
//    (seed, half size): crackling circular arcs that turn around the grip.
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(0.6, 0.85, 1.0);
// Overall brightness, and the share of time slots a bolt is lit (0..1).
uniform float intensity = 1.0;
uniform float density = 0.7;
// Re-routes a second, and bolts per strand (1 or 2).
uniform float rate = 9.0;
uniform float layers = 1.0;
// Fast flicker depth (0 steady, 1 strong).
uniform float flicker = 0.5;
// The bolt's bright core and its soft glow (model units).
uniform float core_width = 0.0035;
uniform float glow_width = 0.018;

varying float kind;
varying float seed;
varying float span;
varying float half_w;
varying float metre;

float h11(float n) {
	return fract(sin(n * 127.1 + 0.37) * 43758.5453);
}

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// A jagged path over t in 0..1 (three octaves of piecewise-linear noise), -1..1,
// pinned to 0 at both ends when pin is 1.
float bolt(float t, float s, float pin) {
	float x = 0.0;
	float amp = 0.62;
	float n = 4.0;
	for (int o = 0; o < 3; o++) {
		float f = t * n;
		float i = floor(f);
		float a = h21(vec2(i, s)) * 2.0 - 1.0;
		float b = h21(vec2(i + 1.0, s)) * 2.0 - 1.0;
		x += mix(a, b, f - i) * amp;
		amp *= 0.42;
		n *= 2.7;
		s += 17.13;
	}
	return x * mix(1.0, sin(3.14159 * clamp(t, 0.0, 1.0)), pin);
}

// Light of a line at distance d (model units), aa the pixel footprint.
float line(float d, float w, float aa) {
	float cw = max(w, aa * 0.6);
	return 1.0 - smoothstep(cw, cw + aa * 1.4, d);
}

void vertex() {
	kind = COLOR.r;
	seed = UV2.x;
	span = UV2.y;
	half_w = COLOR.g * 0.5;
	metre = 1.0 / max(length(mat3(MODEL_MATRIX) * vec3(1.0, 0.0, 0.0)), 0.001);
	vec3 p = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (kind < 0.5) {
		vec3 axis = normalize(mat3(MODELVIEW_MATRIX) * vec3(0.0, 1.0, 0.0));
		float sc = length(mat3(MODELVIEW_MATRIX) * vec3(1.0, 0.0, 0.0));
		vec3 side = cross(axis, normalize(-p));
		side = length(side) > 0.0001 ? normalize(side) : vec3(1.0, 0.0, 0.0);
		p += side * (UV.x * 2.0 - 1.0) * half_w * sc;
		// Brought in front of the weapon's core (COLOR.b * 0.5 deep) so the blade
		// does not hide its own arcs.
		p += normalize(-p) * COLOR.b * 0.5 * sc;
	}
	VERTEX = p;
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float core = 0.0;
	float glow = 0.0;
	float fl = 1.0 - flicker * 0.55 * h11(floor(TIME * 31.0) + seed * 57.0);
	if (kind < 0.5) {
		// Strand space, model units: x across (centre 0), y along the weapon.
		vec2 q = vec2((UV.x - 0.5) * 2.0 * half_w, UV.y * span);
		float aa = fwidth(q.x);
		for (int k = 0; k < 2; k++) {
			if (float(k) >= layers) {
				break;
			}
			float slot = floor(TIME * rate * (1.0 - 0.23 * float(k)) + seed * 31.0 + float(k) * 0.5);
			float s = seed * 113.0 + slot * 7.31 + float(k) * 51.7;
			if (h11(s + 3.1) > density) {
				continue;
			}
			float len = min(mix(0.25, 0.6, h11(s + 5.7)) * span, mix(0.45, 0.85, h11(s + 6.1)) * metre);
			float y0 = h11(s + 9.2) * (span - len);
			float t = (q.y - y0) / len;
			if (t < -0.05 || t > 1.05) {
				continue;
			}
			float amp = min(half_w * 0.7, len * 0.25);
			float tc = clamp(t, 0.0, 1.0);
			float x = bolt(tc, s, 1.0) * amp;
			float d = length(vec2(q.x - x, (t - tc) * len));
			float bright = 0.75 + 0.25 * h11(s + 1.3);
			core += line(d, core_width, aa) * bright;
			glow += exp(-d / glow_width) * bright;
			// Two short branches leaving the bolt (one each way).
			for (int j = 0; j < 2; j++) {
				float tb = mix(0.18, 0.72, h11(s + 13.0 + float(j) * 4.1));
				float bl = mix(0.12, 0.26, h11(s + 15.0 + float(j) * 2.3));
				float u = (t - tb) / bl;
				if (u < 0.0 || u > 1.0) {
					continue;
				}
				float dir = j == 0 ? 1.0 : -1.0;
				float bx = bolt(tb, s, 1.0) * amp + dir * u * amp * 1.1 + bolt(u, s + 40.0 + float(j), 0.0) * amp * 0.22 * u;
				float db = abs(q.x - bx);
				float fade = 1.0 - u;
				core += line(db, core_width * 0.7, aa) * fade * 0.85 * bright;
				glow += exp(-db / (glow_width * 0.7)) * fade * 0.5 * bright;
			}
			// Bright contact points where the bolt touches the weapon.
			vec2 a0 = vec2(0.0, y0);
			vec2 a1 = vec2(0.0, y0 + len);
			glow += (exp(-length(q - a0) / (glow_width * 0.9)) + exp(-length(q - a1) / (glow_width * 0.9))) * 0.6;
		}
		// The glow fades out before the quad's sides.
		glow *= 1.0 - smoothstep(0.7, 1.0, abs(UV.x * 2.0 - 1.0));
	} else {
		// Hand ring: polar, radius 0.68 of the quad's half size (span).
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		float a = atan(p.y, p.x) / 6.28318 + 0.5;
		float aa = fwidth(r) * span;
		float base = 0.68;
		// A faint steady ring the arcs crawl along.
		glow += exp(-abs(r - base) * span / (glow_width * 1.6)) * (0.55 + 0.2 * sin(TIME * 7.0 + seed * 9.0));
		for (int k = 0; k < 3; k++) {
			float dir = mod(float(k) + floor(seed * 2.0), 2.0) < 0.5 ? 1.0 : -1.0;
			float slot = floor(TIME * rate * 0.8 + seed * 19.0 + float(k) * 0.33);
			float s = seed * 71.0 + slot * 5.17 + float(k) * 23.0;
			float arc = mix(0.28, 0.46, h11(s + 2.0));
			float t = fract(a - TIME * 0.45 * dir + float(k) / 3.0 + h11(s + 6.0) * 0.1) / arc;
			if (t > 1.0) {
				continue;
			}
			float rr = base + bolt(t, s, 1.0) * 0.1;
			float d = abs(r - rr) * span;
			core += line(d, core_width * 1.5, aa) * 1.2;
			glow += exp(-d / (glow_width * 1.3)) * 1.4;
			// A spark flicking outward from the ring.
			float tb = mix(0.2, 0.8, h11(s + 9.0));
			float u = (t - tb) * arc * 6.28318 / 0.22;
			if (u > 0.0 && u < 1.0) {
				float out_r = base + bolt(tb, s, 1.0) * 0.1 + u * 0.22 * (h11(s + 11.0) > 0.5 ? 1.0 : -0.7);
				float db = abs(r - out_r) * span;
				core += line(db, core_width * 0.7, aa) * (1.0 - u) * 0.8;
				glow += exp(-db / (glow_width * 0.7)) * (1.0 - u) * 0.4;
			}
		}
		glow *= 1.0 - smoothstep(0.92, 1.0, r);
		core *= 1.0 - smoothstep(0.92, 1.0, r);
	}
	// Premultiplied: the glow also covers a little of what is behind, so a red arc
	// stays red over green grass (pure addition would turn it yellow).
	vec3 hot = mix(tint, vec3(1.0), 0.4);
	float c = min(core, 1.2) * intensity * fl;
	float g = min(glow, 1.4) * intensity * fl;
	ALBEDO = hot * c * 1.5 + tint * g * 1.0;
	ALPHA = clamp(c * 0.95 + g * 0.65, 0.0, 1.0);
}
