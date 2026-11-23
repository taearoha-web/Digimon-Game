// Shared by the +15 set's god looks (EnhanceFx._god: shaders/enhance_god_light,
// enhance_god_pillar, enhance_god_flame): hashing, noise, the body's outline and
// camera-facing cards. One mesh per look whose parts say what they are in COLOR.r
// (kind / 8), COLOR.g (a seed), COLOR.b (an index 0..1); a card's VERTEX is its centre and
// UV2 its size in metres. WebGL2 / Compatibility safe: no textures, no screen reads.

float g_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float g_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(g_hash(i), g_hash(i + vec2(1.0, 0.0)), u.x), mix(g_hash(i + vec2(0.0, 1.0)), g_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// The view-space position of a card corner: its centre [anchor] (model space) moved [push]
// metres along the camera's ray (+ behind the body, - in front of it; the card grows or
// shrinks with it so it keeps its size on screen), then [off] metres across. [upright]:
// it only turns round the vertical (so it leans with the body as the camera looks down).
vec3 g_card(mat4 model, mat4 view, mat4 inv_view, vec3 anchor, vec2 off, float push, bool upright) {
	float s = length(model[1].xyz);
	vec3 w = (model * vec4(anchor, 1.0)).xyz;
	vec3 to = w - inv_view[3].xyz;
	float dist = max(length(to), 0.05);
	w += to / dist * push * s;
	off *= s * (dist + push * s) / dist;
	vec3 right = inv_view[0].xyz;
	vec3 up = inv_view[1].xyz;
	if (upright) {
		right = normalize(vec3(right.x, 0.0, right.z) + vec3(0.0001, 0.0, 0.0));
		up = vec3(0.0, 1.0, 0.0);
	}
	return (view * vec4(w + right * off.x + up * off.y, 1.0)).xyz;
}

// How much a mote at [at] (model space) may shine: dimmed while it passes in front of the
// face, so nothing bright ever covers it.
float g_face_guard(mat4 model, mat4 inv_view, vec3 at) {
	vec3 o = model[3].xyz;
	vec2 out_dir = (model * vec4(at.x, 0.0, at.z, 1.0)).xz - o.xz;
	vec2 to_cam = inv_view[3].xz - o.xz;
	float front = dot(normalize(out_dir + vec2(0.0001)), normalize(to_cam + vec2(0.0001)));
	return 1.0 - 0.85 * smoothstep(0.15, 0.6, front) * smoothstep(0.9, 1.1, at.y) * smoothstep(2.0, 1.8, at.y);
}

// The chibi body's outline seen from the side (x across, y up from the feet, metres; for
// a hero 1.85 tall): the big head on a trunk, joined smoothly. < 0 inside.
float g_body(vec2 p) {
	float head = length((p - vec2(0.0, 1.38)) / vec2(1.08, 1.0)) - 0.47;
	vec2 pa = p - vec2(0.0, 0.16);
	vec2 ba = vec2(0.0, 0.8);
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	float trunk = length(pa - ba * h) - (0.26 + 0.07 * h);
	float k = 0.2;
	float m = clamp(0.5 + 0.5 * (trunk - head) / k, 0.0, 1.0);
	return mix(trunk, head, m) - k * m * (1.0 - m);
}
