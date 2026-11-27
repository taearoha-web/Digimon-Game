shader_type spatial;
// พญานาคทองเทวาลัย (HeavenNaga / HeavenNagaVisual): one code-built mesh. The body (CUSTOM1.w
// 0) is laid along the coil's spline by its distance from the neck (VERTEX.z), rippling;
// the clouds (2) drift where they stand; the hood (9) and the heads (10 + i) ride the
// neck's top in their own frame, each head swaying round its neck's foot (CUSTOM1.xyz) by
// its weight (CUSTOM0.w) and dropping its jaw (COLOR.a 0) round its hinge (CUSTOM0.xyz).
// The neck's last metres bend (lean: forward +, turn: aside) round a point down the body,
// so the hood rears and strikes with them. Toon lit with a warm rim; gold scales edged in
// light over a cream belly of plates (UV2.y > 0); the mouths kindle (UV2.x = 2, breath);
// the clouds are lit as vapour (UV2.y = -2). fade dissolves it into gold.
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;
uniform vec3 pts[72];
uniform int count = 2;
uniform float spacing = 0.5;
uniform float head = 10.0;
uniform vec3 neck = vec3(0.0, 2.7, 0.4);
uniform float clock = 0.0;
uniform float breeze = 0.0;
uniform float wave_amp = 0.12;
uniform float wave_len = 4.5;
uniform float wave_speed = 2.2;
uniform float bend_len = 2.3;
uniform float lean = 0.0;
uniform float turn = 0.0;
uniform float reach = 0.0;
uniform float rise = 0.0;
uniform float sink = 0.0;
uniform float gape = 0.0;
uniform float sway = 1.0;
uniform float spread = 0.0;
uniform float breath = 0.0;
uniform vec4 breath_color : source_color = vec4(1.0, 0.92, 0.55, 1.0);
uniform float scales = 1.0;
uniform vec4 scale_light : source_color = vec4(1.0, 0.97, 0.75, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.94, 0.72, 1.0);
uniform float rim = 0.45;
uniform vec4 shadow_tint : source_color = vec4(0.7, 0.56, 0.6, 1.0);
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float glow = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.4, 1.0);
uniform float fade = 1.0;
varying vec3 wn;
varying vec3 wp;
varying vec2 info;
varying vec3 rest;

vec3 path_at(float p) {
	float last = float(count - 1);
	float pc = clamp(p, 0.0, last);
	int i = min(int(floor(pc)), count - 2);
	float f = pc - float(i);
	vec3 p0 = pts[max(i - 1, 0)];
	vec3 p1 = pts[i];
	vec3 p2 = pts[i + 1];
	vec3 p3 = pts[min(i + 2, count - 1)];
	vec3 c = 0.5 * ((2.0 * p1) + (p2 - p0) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f + (3.0 * p1 - p0 - 3.0 * p2 + p3) * f * f * f);
	if (p < 0.0) c += (pts[0] - pts[1]) * (-p);
	if (p > last) c += (pts[count - 1] - pts[count - 2]) * (p - last);
	return c;
}

mat3 rot_x(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}

mat3 rot_y(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float blotch(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	float part = CUSTOM1.w;
	vec3 p = VERTEX;
	vec3 n = NORMAL;
	float s = 0.0;
	rest = VERTEX;
	if (part < 0.5) {
		// The body along its spline, rippling (the coil gently, the risen neck more).
		s = VERTEX.z;
		float a = head - max(s, 0.0);
		vec3 c = path_at(a / spacing);
		vec3 T = normalize(path_at(a / spacing + 0.3) - path_at(a / spacing - 0.3));
		vec3 up = normalize(mix(vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, -1.0), smoothstep(0.72, 0.96, abs(T.y))));
		vec3 S = normalize(cross(up, T) + vec3(0.0001, 0.0, 0.0));
		vec3 N = cross(T, S);
		if (s < 0.0) c += T * (-s);
		float body = smoothstep(0.2, 2.0, s) * (1.0 - 0.55 * smoothstep(3.5, 8.0, s));
		float ph = a * 6.2832 / wave_len;
		c += (N * sin(ph - clock * wave_speed) * 0.5 + S * cos(ph * 0.7 - clock * wave_speed * 0.8)) * wave_amp * body;
		p = c + S * VERTEX.x + N * VERTEX.y;
		n = normalize(S * NORMAL.x + N * NORMAL.y - T * NORMAL.z);
	} else if (part < 2.5) {
		// The clouds drift and breathe round the coil.
		float k = 1.0 + 0.04 * sin(breeze * 1.3 + VERTEX.x * 2.0);
		vec3 o = vec3(0.0, 0.0, -0.5);
		p = o + rot_y(breeze * 0.06) * (VERTEX - o) * vec3(k, 1.0, k);
		p.y += 0.05 * sin(breeze * 0.9 + VERTEX.z * 1.7);
		n = rot_y(breeze * 0.06) * NORMAL;
	} else {
		// The hood and heads, in the neck-top frame.
		vec3 lp = VERTEX;
		vec3 ln = NORMAL;
		if (part > 9.5) {
			float i = part - 10.0;
			vec3 piv = CUSTOM1.xyz;
			if (COLOR.a < 0.5) {
				mat3 j = rot_x(0.08 + gape * 0.55);
				lp = CUSTOM0.xyz + j * (lp - CUSTOM0.xyz);
				ln = j * ln;
			}
			float w = CUSTOM0.w;
			float side = piv.x > 0.01 ? 1.0 : (piv.x < -0.01 ? -1.0 : 0.0);
			float yaw = (sin(breeze * 1.05 + i * 1.7) * 0.1 * sway + side * spread * 0.22) * w;
			float pitch = (sin(breeze * 0.83 + i * 2.3) * 0.07 * sway - spread * 0.1) * w;
			mat3 r = rot_y(yaw) * rot_x(pitch);
			lp = piv + r * (lp - piv);
			ln = r * ln;
		}
		p = neck + lp;
		n = ln;
	}
	// The neck's bend: its last bend_len metres lean and turn round the point that far down.
	float kb = 1.0 - smoothstep(0.0, bend_len, max(s, 0.0));
	if (kb > 0.0 && (part < 0.5 || part > 2.5)) {
		vec3 pivot = path_at((head - bend_len) / spacing);
		mat3 r = rot_y(turn * kb) * rot_x(lean * kb);
		p = pivot + r * (p - pivot);
		n = r * n;
		p += vec3(0.0, rise, reach) * kb;
	}
	p.y -= sink * (0.4 + 0.6 * smoothstep(0.0, 3.0, p.y));
	VERTEX = p;
	NORMAL = normalize(n);
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	info = UV2;
}

void fragment() {
	float grain = blotch(rest * 9.0);
	float cut = (1.0 - fade) * 1.15 - 0.08;
	if (fade < 0.999 && grain < cut) {
		discard;
	}
	vec3 base = COLOR.rgb;
	vec3 nn = normalize(wn);
	vec3 v = normalize(CAMERA_POSITION_WORLD - wp);
	if (scales > 0.0 && info.y > 0.05) {
		// Overlapping scales, each lit along its free edge; cream plates down the belly.
		vec2 q = vec2(UV.x * 4.2, UV.y * 14.0);
		float row = floor(q.x);
		float fa = fract(q.x);
		float da = length(vec2(fa - 1.0, (fract(q.y + 0.5 * mod(row, 2.0)) - 0.5) * 1.6));
		float db = length(vec2(fa, (fract(q.y + 0.5 * mod(row + 1.0, 2.0)) - 0.5) * 1.6));
		float d = da < 1.0 ? da : db;
		float belly = smoothstep(-0.35, -0.75, sin(UV.y * 6.2832)) * step(0.75, info.y);
		float k = info.y * scales * (1.0 - belly);
		base = mix(base, base * mix(1.16, 0.74, d) + 0.02, k);
		base = mix(base, scale_light.rgb, smoothstep(0.8, 0.95, d) * k * 0.7);
		float plate = fract(UV.x * 3.2);
		base = mix(base, base * vec3(0.92, 0.82, 0.6), smoothstep(0.55, 1.0, plate) * belly * 0.6);
		base = mix(base, vec3(1.0, 0.78, 0.3), smoothstep(0.9, 0.97, plate) * belly * 0.7);
	}
	float l = dot(nn, normalize(vec3(0.25, 0.9, 0.1) + v * 0.55)) * 0.5 + 0.5;
	vec3 col = mix(base * shadow_tint.rgb, base, smoothstep(0.42, 0.54, l));
	col += base * smoothstep(0.84, 0.93, l) * 0.22;
	float fr = pow(1.0 - abs(dot(nn, v)), 2.5);
	col = mix(col, rim_color.rgb, clamp(fr * rim, 0.0, 1.0));
	float emit = clamp(info.x, 0.0, 1.0);
	col = mix(col, base * 1.2 + 0.08, emit);
	if (info.y < -1.5) {
		// Cloud: a wide soft shade, its outline melting into white.
		vec3 vapour = mix(base * vec3(0.86, 0.92, 0.97), base * 1.06 + 0.04, smoothstep(0.2, 0.95, l));
		col = mix(vapour, vec3(1.0), clamp(fr * 1.5, 0.0, 0.8));
		if (base.b < 0.6) col = base * 1.15 + 0.06;
	}
	if (info.x > 1.5) col = mix(col, breath_color.rgb * 1.5, breath);
	col = mix(col, glow_color.rgb, glow);
	if (fade < 0.999) {
		col = mix(col, vec3(1.0, 0.86, 0.45) * 1.6, smoothstep(0.1, 0.0, grain - cut));
	}
	ALBEDO = mix(col, flash_color.rgb, flash);
}
