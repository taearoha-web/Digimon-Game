shader_type spatial;
// กิเลนเหยียบเมฆ, the isle's kirin (Kirin, KirinVisual): one code-built mesh posed by
// this vertex stage. Every vertex carries its part (CUSTOM1.w: 0 body, 1-4 the legs
// FL FR HL HR, 11-14 the cloud under that leg's hoof, 5 neck and head, 6 tail), the
// part's pivot (CUSTOM1.xyz: hip, neck base, tail root), and CUSTOM0 = (knee height,
// knee z, flutter, hoof z). A tuft's flutter share grows to its tip (1 - COLOR.a).
// The script only tweens scalars: the gait (clock, stride, gallop), rearing, the front
// legs tucked, the head's nod, the charge, the fall, and the hit flash.
// Toon lit with a rim like the isle's dragons; the jade hide wears gold-edged scales.
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

// Gait cycles (the script runs it faster on the move) and the breeze (real seconds).
uniform float clock = 0.0;
uniform float breeze = 0.0;
// How far the legs swing (radians) and how much of the gait is a gallop.
uniform float stride = 0.0;
uniform float gallop = 0.0;
// Mane and tail blown back by the speed.
uniform float stream = 0.0;
// Rearing (nose up, round the hind hooves), front legs tucked, the head's nod (+ down).
uniform float rear = 0.0;
uniform float tuck = 0.0;
uniform float head_pitch = 0.0;
// Death: legs folded, rolled on its side.
uniform float fold = 0.0;
uniform float roll = 0.0;
uniform float lift = 0.0;
uniform float lunge = 0.0;
uniform float hind_z = -0.66;
uniform float cloud_y = 0.09;
uniform float swirl = 0.9;
uniform float scales = 1.0;
uniform vec4 scale_gold : source_color = vec4(1.0, 0.82, 0.3, 1.0);
uniform vec4 rim_color : source_color = vec4(0.84, 1.0, 0.94, 1.0);
uniform float rim = 0.5;
uniform vec4 shadow_tint : source_color = vec4(0.44, 0.54, 0.72, 1.0);
uniform float glow = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0);
uniform float charge = 0.0;
varying vec3 wn;
varying vec3 wp;
varying vec2 info;
varying float hide;

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

mat3 rot_z(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0));
}

// One leg's swing (forward +) and knee bend for leg i (0 FL, 1 FR, 2 HL, 3 HR).
vec2 leg_angles(int i) {
	vec4 walk = vec4(0.0, 0.5, 0.75, 0.25);
	vec4 run = vec4(0.42, 0.54, 0.0, 0.1);
	float ph = 6.2832 * (clock + mix(walk[i], run[i], gallop));
	float swing = sin(ph) * stride;
	float bend = max(0.0, cos(ph)) * stride * (1.5 + gallop * 0.6);
	if (i < 2) {
		swing += tuck * 1.05 + fold * 0.5;
		bend += tuck * 1.9 + fold * 1.9;
	} else {
		swing -= rear + fold * 0.6;
		bend += fold * 1.6;
	}
	return vec2(swing, bend);
}

void vertex() {
	vec3 p = VERTEX;
	vec3 n = NORMAL;
	float part = CUSTOM1.w;
	vec3 piv = CUSTOM1.xyz;
	// Tufts, mane, beard and whiskers flutter, streaming back on the move.
	float fl = CUSTOM0.z * (1.0 - COLOR.a);
	if (fl > 0.0) {
		float w = breeze * 3.4 + p.z * 4.0 + p.y * 3.0;
		p += vec3(sin(w) * 0.045, sin(w * 0.8 + 1.3) * 0.05 + stream * 0.05, -stream * 0.16 - abs(sin(w * 0.6)) * 0.03) * fl;
	}
	if (part > 5.5 && part < 6.5) {
		// The ox tail swishes, and lifts out behind at a gallop.
		float f = clamp(distance(p, piv) / 1.3, 0.0, 1.0);
		float sw = sin(breeze * 1.9 - f * 2.6) * (0.2 + 0.25 * stride) * f * f;
		p += vec3(sw, stream * 0.55 * f * f, -stream * 0.25 * f * f);
	}
	if (part > 0.5 && part < 4.5 || part > 10.5) {
		int i = int(mod(part, 10.0) + 0.5) - 1;
		vec2 a = leg_angles(i);
		vec3 knee = vec3(0.0, CUSTOM0.x, CUSTOM0.y);
		mat3 kr = rot_x(a.y);
		mat3 hr = rot_x(-a.x);
		if (part > 10.5) {
			// A small cloud under the hoof: it drifts round and follows the hoof (level).
			vec3 c0 = vec3(piv.x, cloud_y, CUSTOM0.w);
			vec3 k = vec3(c0.x, knee.y, knee.z);
			vec3 c1 = k + kr * (c0 - k);
			c1 = piv + hr * (c1 - piv);
			float dir = piv.x > 0.0 ? 1.0 : -1.0;
			mat3 sr = rot_y(breeze * swirl * dir);
			float puff = 1.0 + 0.08 * sin(breeze * 2.2 + piv.z * 3.0);
			p = c1 + sr * (p - c0) * puff;
			n = sr * n;
		} else {
			float below = 1.0 - smoothstep(CUSTOM0.x - 0.07, CUSTOM0.x + 0.07, p.y);
			mat3 kb = rot_x(a.y * below);
			vec3 k = vec3(p.x, knee.y, knee.z);
			p = k + kb * (p - k);
			n = kb * n;
			p = piv + hr * (p - piv);
			n = hr * n;
		}
	}
	if (part > 4.5 && part < 5.5) {
		// The neck bends from its base, the head goes with it.
		float hw = smoothstep(piv.y, piv.y + 0.55, p.y);
		float nod = head_pitch + sin(breeze * 1.3) * 0.035 + stride * 0.12 * sin(6.2832 * clock * 2.0) * (1.0 - gallop * 0.4) + gallop * 0.12;
		mat3 r = rot_x(nod * hw);
		p = piv + r * (p - piv);
		n = r * n;
	}
	// The whole beast: rocks at a gallop, rears round its hind hooves, falls on its side.
	float rock = sin(6.2832 * (clock + 0.2)) * 0.09 * gallop;
	float bob = (sin(6.2832 * clock * 2.0) * 0.035 * (1.0 - gallop) + sin(6.2832 * (clock + 0.45)) * 0.1 * gallop) * smoothstep(0.0, 0.35, stride);
	vec3 rp = vec3(0.0, 0.1, hind_z);
	mat3 pr = rot_x(-(rear + rock));
	p = rp + pr * (p - rp);
	n = pr * n;
	mat3 zr = rot_z(roll);
	p = zr * p;
	n = zr * n;
	p += vec3(0.0, lift + bob, lunge);
	VERTEX = p;
	NORMAL = normalize(n);
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	info = UV2;
	hide = 1.0 - smoothstep(0.5, 0.82, COLOR.r);
}

void fragment() {
	vec3 base = COLOR.rgb;
	vec3 nn = normalize(wn);
	vec3 v = normalize(CAMERA_POSITION_WORLD - wp);
	if (scales > 0.0 && info.y > 0.0) {
		// Overlapping jade scales, their free (back) edges rimmed in gold; none on the belly.
		vec2 q = vec2(UV.x * 4.6, UV.y * 15.0);
		float fa = fract(q.x);
		float row = floor(q.x);
		float da = length(vec2(fa - 1.0, (fract(q.y + 0.5 * mod(row, 2.0)) - 0.5) * 1.7));
		float db = length(vec2(fa, (fract(q.y + 0.5 * mod(row + 1.0, 2.0)) - 0.5) * 1.7));
		float d = da < 1.0 ? da : db;
		float k = info.y * scales * hide;
		base = mix(base, base * mix(1.18, 0.82, d) + 0.02, k);
		base = mix(base, scale_gold.rgb, smoothstep(0.8, 0.94, d) * k * 0.85);
		// The cream belly in broad plates, each lined in gold.
		float plate = fract(UV.x * 5.5);
		float belly = (1.0 - hide) * info.y * scales;
		base = mix(base, base * vec3(0.95, 0.86, 0.66), smoothstep(0.55, 1.0, plate) * belly * 0.5);
		base = mix(base, scale_gold.rgb, smoothstep(0.9, 0.97, plate) * belly * 0.7);
	}
	float l = dot(nn, normalize(vec3(0.25, 0.9, 0.1) + v * 0.55)) * 0.5 + 0.5;
	vec3 col = mix(base * shadow_tint.rgb, base, smoothstep(0.42, 0.54, l));
	col += base * smoothstep(0.82, 0.92, l) * 0.2;
	float fr = pow(1.0 - abs(dot(nn, v)), 2.5);
	col = mix(col, rim_color.rgb, clamp(fr * rim, 0.0, 1.0));
	float emit = clamp(info.x, 0.0, 1.0);
	col = mix(col, base * 1.2 + 0.08, emit);
	// The horn burns gold while it charges (UV2.x = 2).
	if (info.x > 1.5) col = mix(base * 1.15 + 0.1, vec3(1.0, 0.97, 0.75), charge * 0.8);
	ALBEDO = mix(col, glow_color.rgb, glow);
}
