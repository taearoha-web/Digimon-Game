// The pose of ดินแดนเทวาลัย's winged Himmapan folk (HeavenBird, HeavenBirdVisual): the
// กินรี and the ครุฑน้อย, each one code-built mesh posed here, shared by the body shader
// (heaven_bird.gdshader) and its ink outline (heaven_bird_ink.gdshader).
// Every vertex carries CUSTOM1 = (side: +1 the figure's left / -1 its right / 0 middle,
// flutter, outlined, part) and CUSTOM0 = (u: how far along a lock / feather / ribbon,
// toe: 1 on a talon, 0, 0). The joints are the kind's (left side, mirrored by side);
// the script only moves scalars: the beat of the wings, the gait, the arms, the torso,
// the head, the crouch and leap, the ribbon of light, the fall.

// Parts.
const int P_BODY = 0;
const int P_TORSO = 1;
const int P_HEAD = 2;
const int P_ARM = 3;
const int P_FORE = 4;
const int P_WING = 5;
const int P_WING_TIP = 6;
const int P_THIGH = 7;
const int P_SHIN = 8;
const int P_TAIL = 9;
const int P_RIBBON = 10;

// Wing beat cycles (the script runs them faster on the move), gait cycles, and a seed
// that sets this one's breeze apart (the breeze runs on TIME).
uniform float clock = 0.0;
uniform float gait = 0.0;
uniform float seed = 0.0;
uniform float stride = 0.0;
uniform float stream = 0.0;
uniform float flap_amp = 0.2;
uniform float wing_raise = 0.0;
uniform float wing_sweep = 0.0;
uniform float wing_fold = 0.0;
// The torso round the waist (bow: + forward), the head round the neck (+ down).
uniform float bow = 0.0;
uniform float twist = 0.0;
uniform float sway = 0.0;
uniform float head_pitch = 0.0;
uniform float head_turn = 0.0;
// Arms: swing (+ forward), raise (+ out to the side), bend (the elbow), twist (the upper
// arm round its own axis: + turns the elbow's bend outward).
uniform float la_swing = 0.0;
uniform float la_raise = 0.0;
uniform float la_bend = 0.0;
uniform float la_twist = 0.0;
uniform float ra_swing = 0.0;
uniform float ra_raise = 0.0;
uniform float ra_bend = 0.0;
uniform float ra_twist = 0.0;
// The legs (both): swing (+ forward), knee bend, the crouch (knees bent, the body lowered
// so the feet stay down), the talons (+ open).
uniform float leg_swing = 0.0;
uniform float leg_bend = 0.0;
uniform float crouch = 0.0;
uniform float talon = 0.0;
uniform float tail_lift = 0.0;
// The whole figure: lifted, thrust forward, pitched round its middle (dive, and the gait's
// own lean), rolled over on its side.
uniform float lift = 0.0;
uniform float lunge = 0.0;
uniform float dive = 0.0;
uniform float lean = 0.0;
uniform float roll = 0.0;
// The ribbon of light out of the right hand (0 hidden, 1 unfurled).
uniform float ribbon = 0.0;
uniform float ribbon_len = 6.0;
// The idle dance of the arms and the breathing (0 still).
uniform float dance = 0.0;
uniform float breathe = 1.0;
uniform vec3 j_waist = vec3(0.0, 1.2, 0.0);
uniform vec3 j_neck = vec3(0.0, 1.7, 0.0);
uniform vec3 j_shoulder = vec3(0.2, 1.58, 0.0);
uniform vec3 j_elbow = vec3(0.24, 1.33, 0.0);
uniform vec3 j_hand = vec3(0.26, 1.05, 0.02);
uniform vec3 j_wing = vec3(0.08, 1.5, -0.12);
uniform vec3 j_wing_mid = vec3(0.6, 1.85, -0.25);
uniform vec3 j_hip = vec3(0.12, 0.84, 0.0);
uniform vec3 j_knee = vec3(0.13, 0.5, 0.08);
uniform vec3 j_foot = vec3(0.13, 0.1, 0.0);
uniform vec3 j_tail = vec3(0.0, 0.95, -0.36);
uniform vec3 j_center = vec3(0.0, 1.2, 0.0);

mat3 bird_rx(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}

mat3 bird_ry(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
}

mat3 bird_rz(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0));
}

vec3 bird_side(vec3 j, float s) {
	return vec3(j.x * s, j.y, j.z);
}

void bird_turn(inout vec3 p, inout vec3 n, vec3 pivot, mat3 r) {
	p = pivot + r * (p - pivot);
	n = r * n;
}

void bird_pose(inout vec3 p, inout vec3 n, vec4 c0, vec4 c1) {
	int part = int(c1.w + 0.5);
	float s = c1.x < 0.0 ? -1.0 : 1.0;
	float u = c0.x;
	float breeze = TIME + seed;
	// Locks, sashes, feather tips and tail flutter, streaming back on the move.
	float fl = c1.y * u;
	if (fl > 0.0) {
		float w = breeze * 3.3 + p.y * 3.0 + p.z * 2.4 + p.x * 1.7;
		p += vec3(sin(w) * 0.045, sin(w * 0.8 + 1.3) * 0.045 + stream * 0.05, -stream * 0.2 - abs(sin(w * 0.6)) * 0.035) * fl;
	}
	if (part == P_RIBBON) {
		// The ribbon of light: hidden in the hand at rest, unfurling down the forearm's line
		// (straight at the target once the arm points there), rippling as it goes.
		vec3 h = bird_side(j_hand, s);
		vec3 q = p - h;
		float e = ribbon;
		q.y *= e;
		q.x *= 0.3 + 0.7 * e;
		q.x += sin(u * 11.0 - breeze * 13.0) * 0.2 * u * e;
		q.z += sin(u * 7.0 - breeze * 9.0 + 1.0) * 0.14 * u * e;
		p = h + q * smoothstep(0.0, 0.06, e);
	}
	bool upper = part == P_TORSO || part == P_HEAD || part == P_ARM || part == P_FORE || part == P_WING || part == P_WING_TIP || part == P_RIBBON;
	if (part == P_ARM || part == P_FORE || part == P_RIBBON) {
		bool left = s > 0.0;
		float sw = left ? la_swing : ra_swing;
		float ra = left ? la_raise : ra_raise;
		float be = left ? la_bend : ra_bend;
		float tw = left ? la_twist : ra_twist;
		// The idle dance: the arms drift, the wrists curl, each arm on its own beat.
		float beat = breeze * 1.15 + (left ? 0.0 : 2.1);
		ra += sin(beat) * 0.09 * dance;
		be += sin(beat + 1.1) * 0.14 * dance;
		sw += sin(beat * 0.7 + 0.4) * 0.06 * dance;
		// A sash hung from the wrist keeps falling toward the ground however the arm turns.
		bool hang = part == P_FORE && c1.y > 0.0;
		vec3 wrist = bird_side(j_hand, s) + vec3(0.0, 0.08, -0.045);
		vec3 d = p - wrist;
		vec3 dn = n;
		mat3 elbow = bird_rx(-be);
		mat3 shoulder = bird_rz(s * ra) * bird_rx(-sw) * bird_ry(s * tw);
		if (part != P_ARM) {
			bird_turn(p, n, bird_side(j_elbow, s), elbow);
		}
		bird_turn(p, n, bird_side(j_shoulder, s), shoulder);
		if (hang) {
			vec3 w2 = wrist;
			vec3 up = vec3(0.0, 1.0, 0.0);
			bird_turn(w2, up, bird_side(j_elbow, s), elbow);
			bird_turn(w2, up, bird_side(j_shoulder, s), shoulder);
			float k = smoothstep(0.0, 0.5, u) * 0.9;
			vec3 dm = mix(p - w2, d, k);
			p = w2 + normalize(dm + vec3(0.0, -1e-4, 0.0)) * length(d);
			n = normalize(mix(n, dn, k));
		}
	}
	if (part == P_WING || part == P_WING_TIP) {
		float t = 6.2832 * clock;
		float f1 = sin(t) * flap_amp;
		float f2 = sin(t - 0.9) * flap_amp * 0.7;
		if (part == P_WING_TIP) {
			bird_turn(p, n, bird_side(j_wing_mid, s), bird_rz(s * (f2 - wing_fold * 1.1)) * bird_ry(s * wing_fold * 0.8));
		}
		bird_turn(p, n, bird_side(j_wing, s), bird_rz(s * (wing_raise + f1)) * bird_ry(s * (wing_sweep + wing_fold * 0.5)));
	}
	if (part == P_THIGH || part == P_SHIN) {
		float ph = 6.2832 * (gait + (s > 0.0 ? 0.0 : 0.5));
		float sw = sin(ph) * stride + leg_swing + crouch;
		float be = max(0.0, cos(ph)) * stride * 1.4 + leg_bend + crouch * 2.0;
		if (part == P_SHIN) {
			if (c0.y > 0.5) {
				bird_turn(p, n, bird_side(j_foot, s), bird_rx(-talon));
			}
			bird_turn(p, n, bird_side(j_knee, s), bird_rx(be));
		}
		bird_turn(p, n, bird_side(j_hip, s), bird_rx(-sw));
	}
	if (part == P_TAIL) {
		bird_turn(p, n, j_tail, bird_ry(sin(breeze * 1.4) * 0.12) * bird_rx(-tail_lift - sin(breeze * 1.1) * 0.05 - stream * 0.2));
	}
	if (upper) {
		if (part == P_HEAD) {
			float look = sin(breeze * 0.37) * 0.16 * breathe;
			float nod = sin(breeze * 1.3) * 0.03 * breathe;
			bird_turn(p, n, j_neck, bird_ry(head_turn + look) * bird_rx(head_pitch + nod));
		}
		if (part == P_TORSO) {
			// Breathing: the chest swells a little.
			float b = 1.0 + 0.018 * sin(breeze * 2.1) * breathe * smoothstep(j_waist.y, j_neck.y, p.y);
			p.xz *= b;
		}
		bird_turn(p, n, j_waist, bird_ry(twist) * bird_rx(bow) * bird_rz(sway));
	}
	// The whole figure: lowered by the crouch (the feet stay down), pitched round its
	// middle, rolled over, lifted and thrust forward; a walk's bob.
	float lt = max(j_hip.y - j_knee.y, 0.0);
	float ls = max(j_knee.y - j_foot.y, 0.0);
	float drop = (lt + ls) * (1.0 - cos(crouch));
	float bob = sin(6.2832 * gait * 2.0) * 0.035 * stride;
	p.y -= drop;
	bird_turn(p, n, j_center, bird_rx(dive + lean));
	bird_turn(p, n, vec3(0.0), bird_rz(roll));
	p += vec3(0.0, lift + bob, lunge);
}
