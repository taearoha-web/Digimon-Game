// The pose of ดินแดนเทวาลัย's code-sculpted folk (HeavenFolk, HeavenFolkVisual): the child
// deva with her lantern and the hermit sage on his cloud. Shared by the body shader and its
// ink outline (heaven_folk.gdshader, heaven_folk_line.gdshader) so both draw the same pose.
// Every vertex carries its part in CUSTOM1.w and its flutter in CUSTOM0.w (a lock's or a
// ribbon's share grows to its tip: 1 - COLOR.a). The part's pivots are uniforms of the kind
// (set once on its base material); the script only tweens a few scalars.
//   0 body  1 head  2 upper arm A  3 forearm A (and what the hand holds)  4 the lantern
//   hanging from A's pole  5 upper arm B  6 forearm B  7 the cloud  8 the charge (the
//   deva's light orbs / the hermit's mantra seal)

uniform vec3 neck = vec3(0.0, 1.1, 0.0);
uniform vec3 shoulder_a = vec3(0.2, 1.0, 0.0);
uniform vec3 elbow_a = vec3(0.25, 0.8, 0.1);
uniform vec3 shoulder_b = vec3(-0.2, 1.0, 0.0);
uniform vec3 elbow_b = vec3(-0.25, 0.8, 0.1);
uniform vec3 hook = vec3(0.45, 1.4, 0.4);
uniform vec3 cloud_pivot = vec3(0.0, 0.2, 0.0);
uniform vec3 seal_pivot = vec3(0.0, 1.0, 0.0);
uniform vec3 seal_axis = vec3(0.0, 1.0, 0.0);
// The seal's flight on release (mesh metres, at seal_rise = 1).
uniform vec3 seal_fly = vec3(0.0, 1.2, 0.6);
uniform float seal_spin = 2.4;
uniform float seal_spread = 1.0;
// Per-creature phase, so a camp does not bob in step.
uniform float seed = 0.0;
uniform float bob_amp = 0.06;
// Movement: the body leans into it, ribbons, beard and lantern stream back.
uniform float lean = 0.0;
uniform float stream = 0.0;
uniform float pace = 0.0;
uniform float head_pitch = 0.0;
uniform float head_roll = 0.0;
// Arms: (shoulder raise forward-up, spread out, elbow bend up).
uniform vec3 arm_a = vec3(0.0);
uniform vec3 arm_b = vec3(0.0);
// Extra lantern swing (+ back) and how far the charge has grown / flown.
uniform float swing = 0.0;
uniform float seal = 0.0;
uniform float seal_rise = 0.0;
// Hit flinch (leans back, squashes), death (sinks, tips back, dissolves).
uniform float flinch = 0.0;
uniform float sink = 0.0;
uniform float dissolve = 0.0;

varying vec3 rest;

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

mat3 rot_axis(vec3 k, float a) {
	float c = cos(a);
	float s = sin(a);
	float t = 1.0 - c;
	return mat3(
		vec3(t * k.x * k.x + c, t * k.x * k.y + s * k.z, t * k.x * k.z - s * k.y),
		vec3(t * k.x * k.y - s * k.z, t * k.y * k.y + c, t * k.y * k.z + s * k.x),
		vec3(t * k.x * k.z + s * k.y, t * k.y * k.z - s * k.x, t * k.z * k.z + c));
}

float folk_hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.11, 0.17, 0.23));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// Value noise 0..1 (the dissolve's blotches, the tiger's broken stripes).
float folk_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(folk_hash(i), folk_hash(i + vec3(1, 0, 0)), f.x), mix(folk_hash(i + vec3(0, 1, 0)), folk_hash(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(folk_hash(i + vec3(0, 0, 1)), folk_hash(i + vec3(1, 0, 1)), f.x), mix(folk_hash(i + vec3(0, 1, 1)), folk_hash(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

mat3 arm_turn(vec3 arm, float side) {
	return rot_z(side * arm.y) * rot_x(-arm.x);
}

// Poses p / n in place.
void folk_pose(inout vec3 p, inout vec3 n, float part, float flutter, float tip) {
	float t = TIME + seed;
	// Locks, ribbons, the lantern's tails flutter, streaming back on the move.
	float fl = flutter * (1.0 - tip);
	if (fl > 0.0) {
		float w = t * 3.1 + p.z * 3.5 + p.y * 2.6 + p.x * 1.7;
		p += vec3(sin(w) * 0.03, sin(w * 0.8 + 1.3) * 0.035 + stream * 0.05, -stream * 0.2 - abs(sin(w * 0.6)) * 0.03) * fl;
	}
	if (part > 6.5 && part < 7.5) {
		// The cloud turns slowly under them and breathes.
		mat3 r = rot_y(t * 0.45);
		float puff = 1.0 + 0.05 * sin(t * 1.9 + p.x * 3.0);
		p = cloud_pivot + r * (p - cloud_pivot) * vec3(puff, 1.0 + 0.5 * (puff - 1.0), puff);
		n = r * n;
	} else if (part > 7.5) {
		// The charge: grows from nothing, spins, and flies off on release.
		mat3 r = rot_axis(normalize(seal_axis), t * seal_spin * (1.0 + seal * 0.8));
		float s = seal * (1.0 - seal_rise * 0.85);
		vec3 d = p - seal_pivot;
		vec3 along = normalize(seal_axis) * dot(d, normalize(seal_axis));
		vec3 wide = (d - along) * (1.0 + seal_rise * seal_spread) + along;
		p = seal_pivot + seal_fly * seal_rise + r * wide * s;
		n = r * n;
	} else if (part > 0.5 && part < 1.5) {
		float nod = head_pitch + sin(t * 1.3) * 0.03;
		mat3 r = rot_x(nod) * rot_z(head_roll + sin(t * 0.9) * 0.025);
		p = neck + r * (p - neck);
		n = r * n;
	} else if (part > 1.5 && part < 6.5) {
		bool a = part < 4.5;
		vec3 arm = a ? arm_a : arm_b;
		vec3 sh = a ? shoulder_a : shoulder_b;
		vec3 el = a ? elbow_a : elbow_b;
		float side = sign(sh.x);
		float breathe = sin(t * 1.8) * 0.03;
		if (part > 3.5 && part < 4.5) {
			// The lantern hangs from its pole, swings, and lags behind the arm.
			float ax = sin(t * 1.7) * 0.09 + stream * 0.45 + swing + (arm.x + arm.z) * 0.92;
			float az = sin(t * 1.25 + 0.7) * 0.07 - side * arm.y * 0.9;
			mat3 pr = rot_x(ax) * rot_z(az);
			p = hook + pr * (p - hook);
			n = pr * n;
		}
		if ((part > 2.5 && part < 4.5) || part > 5.5) {
			mat3 er = rot_x(-(arm.z + breathe * 0.5));
			p = el + er * (p - el);
			n = er * n;
		}
		mat3 sr = arm_turn(arm + vec3(breathe, 0.0, 0.0), side);
		p = sh + sr * (p - sh);
		n = sr * n;
	}
	// The whole figure: breathes, bobs on the air, leans into its flight, flinches, and on
	// death sinks and tips back while it dissolves upward into light.
	float br = 1.0 + sin(t * 1.8) * 0.012;
	if (part < 6.5) {
		p.y = 0.3 + (p.y - 0.3) * br;
	}
	vec3 base = vec3(0.0, 0.25, 0.0);
	mat3 pr = rot_x(lean - flinch * 0.32 - sink * 0.5) * rot_z(sin(t * 0.8) * 0.028);
	p = base + pr * (p - base);
	n = pr * n;
	float sq = flinch * 0.1;
	p = vec3(p.x * (1.0 + sq * 0.5), p.y * (1.0 - sq), p.z * (1.0 + sq * 0.5));
	float bob = sin(t * 1.7) * bob_amp + sin(t * 4.2) * bob_amp * 0.35 * pace;
	p.y += bob * (1.0 - sink) - sink * 0.25;
	p.z -= flinch * 0.12;
	if (dissolve > 0.0) {
		float k = folk_noise(rest * 7.0);
		p += vec3(sin(k * 31.0) * 0.12, 0.6 + k * 0.6, cos(k * 23.0) * 0.12) * dissolve * dissolve;
	}
}

// The death: blotches burn away into gold, the cloud last.
float folk_burn(float part) {
	if (dissolve <= 0.0) return 1.0;
	float k = folk_noise(rest * 7.0) * 0.8 + 0.2 * clamp(rest.y / 2.2, 0.0, 1.0);
	float edge = dissolve * 1.15 - (part > 6.5 && part < 7.5 ? 0.15 : 0.0);
	return k - edge;
}
