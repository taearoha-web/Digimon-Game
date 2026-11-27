// The gate giants of ดินแดนเทวาลัย (HeavenYaksha): every vertex belongs to one rigid part
// (UV2.y, its bone) and is carried by that bone's transform, which HeavenYakshaVisual
// works out each frame (bones[4 * i .. 4 * i + 3]: the basis's columns and the origin, in
// mesh units). Shared by the body and its ink outline. fade 0..1 dissolves the giant into
// gold (a soft blotch noise on its rest position).
uniform vec3 bones[48];
uniform float fade = 1.0;

void pose_part(inout vec3 p, inout vec3 n, float part) {
	int i = int(part + 0.5) * 4;
	mat3 b = mat3(bones[i], bones[i + 1], bones[i + 2]);
	p = b * p + bones[i + 3];
	n = normalize(b * n);
}

float yak_hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float yak_blotch(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(yak_hash(i), yak_hash(i + vec3(1, 0, 0)), f.x), mix(yak_hash(i + vec3(0, 1, 0)), yak_hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(yak_hash(i + vec3(0, 0, 1)), yak_hash(i + vec3(1, 0, 1)), f.x), mix(yak_hash(i + vec3(0, 1, 1)), yak_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
