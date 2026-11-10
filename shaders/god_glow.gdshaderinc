// Light for the god-tier hero objects (GodRangedKit): one procedural card with many
// faces, on a quad (UV 0..1), on a column (UV.x round, UV.y 1 at the foot) or as a
// MultiMesh swarm whose instances start one by one. Included by god_glow (additive) and
// god_veil (alpha blended: the dark and the dense faces).
// INSTANCE_CUSTOM: x = start delay, y = seed, z = size factor (0: 1).
// WebGL2 / Compatibility safe: no textures, no screen or depth reads.
//   0 soft disc        1 shock ring (prism: rainbow)   2 corona with rays round a body
//   3 column of light or fire     4 deep space with stars     5 area rim
//   6 cross of light   7 scorch with cooling cracks    8 fire puff
//   9 mote            10 four-point star              11 accretion swirl
//  12 healing plus    13 lightning ribbon           14 fire on a column or a wall
uniform int mode = 0;
uniform vec4 c_core : source_color = vec4(1.0, 0.98, 0.85, 1.0);
uniform vec4 c_mid : source_color = vec4(1.0, 0.72, 0.2, 1.0);
uniform vec4 c_edge : source_color = vec4(0.9, 0.3, 0.08, 1.0);
uniform float fade = 1.0;
uniform float age = 0.0;
uniform float life = 1.0;
uniform float seed = 0.0;
uniform float gain = 1.0;
uniform float p1 = 1.0;
uniform float p2 = 0.0;
uniform float prism = 0.0;
// Swarm cards face the camera and move: drift (m/s), gravity, sway, a burst along the
// instance's own +Y that slows down, and a size that goes from grow.x to grow.y.
uniform bool billboard = false;
uniform vec3 drift = vec3(0.0);
uniform float gravity = 0.0;
uniform float sway = 0.0;
uniform float burst = 0.0;
uniform vec2 grow = vec2(1.0, 1.0);
varying float v_k;
varying float v_seed;
varying float v_on;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) { return noise(p) * 0.62 + noise(p * 2.2 + 3.7) * 0.38; }
vec3 hue(float h) { return clamp(abs(fract(h + vec3(0.0, 0.6667, 0.3333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0); }
// Noise round a circle without a seam.
float ring_noise(float a, float freq, float along) {
	return noise(vec2(cos(a), sin(a)) * freq + vec2(along, -along * 0.7));
}

void vertex() {
	float lt = age - INSTANCE_CUSTOM.x;
	v_seed = seed + INSTANCE_CUSTOM.y;
	v_k = clamp(lt / max(life, 0.001), 0.0, 1.0);
	v_on = step(0.0, lt) * step(lt, life);
	float ease = 1.0 - (1.0 - v_k) * (1.0 - v_k);
	float size = mix(grow.x, grow.y, ease) * (INSTANCE_CUSTOM.z > 0.001 ? INSTANCE_CUSTOM.z : 1.0) * v_on;
	if (billboard) {
		vec3 pos = MODEL_MATRIX[3].xyz;
		float s = length(MODEL_MATRIX[0].xyz) * size;
		float t = max(lt, 0.0);
		pos += drift * t + vec3(0.0, -0.5 * gravity * t * t, 0.0);
		pos += vec3(sin(t * 2.1 + v_seed * 6.28), 0.0, cos(t * 1.7 + v_seed * 9.4)) * sway * min(t, 1.0);
		pos += normalize(MODEL_MATRIX[1].xyz) * burst * (1.0 - exp(-t * 3.5)) / 3.5;
		vec3 r = normalize(INV_VIEW_MATRIX[0].xyz);
		vec3 u = normalize(INV_VIEW_MATRIX[1].xyz);
		vec3 back = normalize(INV_VIEW_MATRIX[2].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(r * s, 0.0), vec4(u * s, 0.0), vec4(back * s, 0.0), vec4(pos, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	} else {
		VERTEX *= size;
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float r = length(p);
	float a = atan(p.y, p.x);
	float k = v_k;
	float al = 0.0;
	float h = 0.0;
	vec3 over = vec3(0.0);
	float over_mix = 0.0;
	if (mode == 0) {
		al = pow(max(1.0 - r, 0.0), max(p1, 0.2));
		h = al;
	} else if (mode == 1) {
		float e = 1.0 - pow(1.0 - k, 3.0);
		float r0 = mix(0.06, 0.92, e);
		float w = mix(0.17, 0.045, e) * max(p1, 0.1);
		float teeth = ring_noise(a, 5.0, v_seed * 7.0 + age * 0.8);
		float ring = 1.0 - smoothstep(0.0, w, abs(r - r0 + (teeth - 0.5) * w * 0.8));
		float wash = smoothstep(r0 - 0.55, r0, r) * step(r, r0) * 0.3;
		float second = (1.0 - smoothstep(0.0, w * 0.7, abs(r - r0 * 0.62))) * p2;
		al = (ring * (0.75 + 0.5 * teeth) + wash * (0.4 + teeth) + second * 0.7) * (1.0 - smoothstep(0.5, 1.0, k));
		h = max(ring, second * 0.7);
		over = hue(a / 6.2832 + r * 1.3 - age * 0.35);
		over_mix = prism * (0.35 + 0.65 * (1.0 - ring * 0.5));
	} else if (mode == 2) {
		float n = ring_noise(a, 2.4, v_seed + age * 0.5 - r * 2.0);
		float n2 = ring_noise(a, 6.0, age * 0.9 + r * 3.0);
		float rays = pow(0.5 + 0.5 * sin(a * p1 + n * 3.5 + age * 0.5), 3.0);
		float inner = max(p2, 0.01);
		float out_r = clamp((r - inner) / (1.0 - inner), 0.0, 1.0);
		float body = smoothstep(inner * 0.86, inner * 1.02, r);
		// Tongues of fire lick out of the limb, long rays reach past them.
		float tongues = smoothstep(0.42 + n2 * 0.5, 0.0, out_r) * (0.55 + 0.6 * n);
		float halo = pow(1.0 - out_r, 2.4);
		float beams = rays * pow(1.0 - out_r, 1.3) * (0.35 + 0.65 * n);
		al = body * (halo * 0.6 + tongues * 0.75 + beams * 0.7) * step(r, 1.0);
		h = halo * 0.9 + tongues * 0.5 + beams * 0.2;
	} else if (mode == 3) {
		float y = 1.0 - UV.y;
		float ax = UV.x * 6.2832;
		float n = noise(vec2(cos(ax), sin(ax)) * 2.2 + vec2(v_seed * 5.0, y * 4.0 * max(p2, 0.1) - age * p1));
		float n2 = noise(vec2(cos(ax), sin(ax)) * 5.0 + vec2(y * 9.0 * max(p2, 0.1) - age * p1 * 1.7, v_seed));
		float streak = pow(0.5 + 0.5 * sin(ax * 7.0 + n * 5.0), 2.0);
		float facing = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.9);
		float top = 1.0 - smoothstep(0.35 + n * 0.5, 1.0, y);
		float foot = smoothstep(0.0, 0.03, y);
		// It comes down from the sky in the first tenth of its life and thins out at the end.
		float shown = step(1.0 - k * 10.0, y) * (1.0 - smoothstep(0.72, 1.0, k));
		al = facing * top * foot * (0.45 + 0.4 * n + 0.35 * streak * n2) * shown;
		h = facing * (1.05 - y * 0.55) * (0.55 + 0.6 * n);
	} else if (mode == 4) {
		float ragged = ring_noise(a, 3.0, age * 0.25 + v_seed);
		float rim_r = 0.8 + 0.1 * ragged;
		float inside = 1.0 - smoothstep(rim_r - 0.02, rim_r + 0.05, r);
		vec2 sp = p * 7.0 + vec2(v_seed * 9.0, 0.0);
		vec2 cell = floor(sp);
		vec2 f = fract(sp) - 0.5;
		float pick = hash(cell);
		vec2 off = (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.6;
		float tw = 0.55 + 0.45 * sin(age * (3.0 + pick * 6.0) + pick * 40.0);
		float star = step(0.55, pick) * (1.0 - smoothstep(0.0, 0.05 + pick * 0.1, length(f - off))) * tw;
		float neb = fbm(p * 1.8 + vec2(age * 0.06, -age * 0.04) + v_seed);
		float neb2 = fbm(p * 3.1 - vec2(age * 0.05, age * 0.08));
		vec3 col = c_edge.rgb * (0.5 + 0.5 * neb);
		col += c_mid.rgb * pow(neb, 2.5) * 0.9;
		col += c_core.rgb * pow(neb2, 4.0) * 0.6;
		col += vec3(1.0) * star;
		float glow_rim = (1.0 - smoothstep(0.0, 0.07, abs(r - rim_r))) * (0.6 + 0.6 * ragged);
		col = mix(col, mix(c_mid.rgb, c_core.rgb, 0.6), glow_rim);
		over = col;
		over_mix = 1.0;
		al = max(inside * p1, glow_rim);
	} else if (mode == 5) {
		float line = 1.0 - smoothstep(0.004, 0.016, abs(r - 0.965));
		float dash = (1.0 - smoothstep(0.003, 0.01, abs(r - 0.915))) * step(0.5, fract(a / 6.2832 * max(p1, 1.0) + age * 0.04));
		float wash = smoothstep(0.55, 0.965, r) * step(r, 0.965) * 0.14;
		float pulse = 0.8 + 0.2 * sin(age * 5.0);
		al = (line + dash * 0.75) * pulse + wash;
		h = line * 0.8 + dash * 0.4;
	} else if (mode == 6) {
		// A latin cross that burns outward from its heart.
		vec2 q = p;
		float reach = age * max(p2, 0.5);
		float flick = 0.85 + 0.15 * noise(vec2(q.x * 9.0 + age * 6.0, q.y * 9.0 - age * 5.0));
		float w = max(p1, 0.02);
		float stem = (1.0 - smoothstep(w * 0.45, w, abs(q.x))) * (1.0 - smoothstep(0.84, 0.96, abs(q.y)));
		float arm = (1.0 - smoothstep(w * 0.45, w, abs(q.y - 0.3))) * (1.0 - smoothstep(0.52, 0.64, abs(q.x)));
		float core = max((1.0 - smoothstep(w * 0.1, w * 0.45, abs(q.x))) * (1.0 - smoothstep(0.84, 0.96, abs(q.y))), (1.0 - smoothstep(w * 0.1, w * 0.45, abs(q.y - 0.3))) * (1.0 - smoothstep(0.52, 0.64, abs(q.x))));
		float aura = max(exp(-abs(q.x) * 7.0) * (1.0 - smoothstep(0.7, 1.0, abs(q.y))), exp(-abs(q.y - 0.3) * 7.0) * (1.0 - smoothstep(0.4, 0.7, abs(q.x)))) * 0.45;
		float lit = step(length(q - vec2(0.0, 0.3)), reach);
		al = (max(stem, arm) * flick + aura) * lit;
		h = core + max(stem, arm) * 0.45;
	} else if (mode == 7) {
		float n = fbm(p * 3.4 + v_seed * 13.0);
		float n2 = noise(p * 9.0 - v_seed * 7.0);
		float blot = 1.0 - smoothstep(0.18 + n * 0.5, 0.55 + n * 0.45, r + (n2 - 0.5) * 0.12);
		float cr = abs(noise(p * 5.5 + v_seed * 31.0) - 0.5);
		float crack = (1.0 - smoothstep(0.0, 0.05, cr)) * (1.0 - smoothstep(0.15, 0.75, r));
		float hot = crack * (1.0 - smoothstep(0.1, 0.9, k));
		float heart = (1.0 - smoothstep(0.0, 0.3, r)) * (1.0 - smoothstep(0.0, 0.45, k));
		over = mix(c_edge.rgb, mix(c_mid.rgb, c_core.rgb, hot), clamp(hot + heart * 0.7, 0.0, 1.0));
		over_mix = 1.0;
		al = max(blot * 0.62, hot) * (1.0 - smoothstep(0.7, 1.0, k)) * smoothstep(0.0, 0.04, k);
	} else if (mode == 8) {
		// A burst of fire: a round belly that licks upward and tears apart as it ages.
		vec2 q = vec2(p.x, p.y * 0.8 + 0.12);
		float n = fbm(vec2(q.x * 2.4 + v_seed * 9.0, q.y * 2.0 - age * 2.6 + v_seed * 4.0));
		float lick = max(q.y, 0.0);
		float d = length(vec2(q.x * (1.0 + lick * 0.9), q.y)) ;
		float shape = 1.0 - d + (n - 0.5) * (0.5 + lick * 0.9);
		float cut = 0.1 + k * 0.66;
		al = smoothstep(cut, cut + 0.12, shape) * 0.95;
		h = clamp((shape - cut) * 2.6 * (1.0 - k * 0.6) + (0.35 - d) * 0.5, 0.0, 1.0);
	} else if (mode == 9) {
		float tw = 0.65 + 0.35 * sin(age * 11.0 + v_seed * 40.0);
		al = pow(max(1.0 - r, 0.0), 1.8) * sqrt(max(sin(k * 3.1416), 0.0)) * tw;
		h = pow(max(1.0 - r, 0.0), 3.0) * 1.4;
	} else if (mode == 10) {
		float cross_ = max(0.0, 1.0 - abs(p.x) * abs(p.y) * 60.0 - r * 0.9);
		float dot_ = pow(max(1.0 - r * 2.4, 0.0), 2.0);
		float tw = 0.6 + 0.4 * sin(age * 9.0 + v_seed * 50.0);
		al = (pow(cross_, 2.0) * tw + dot_) * sqrt(max(sin(k * 3.1416), 0.0));
		h = dot_ + cross_ * 0.5;
		over = hue(v_seed * 3.7 + age * 0.2);
		over_mix = prism * 0.6 * (1.0 - dot_);
	} else if (mode == 11) {
		float inner = max(p2, 0.01);
		float arms = pow(0.5 + 0.5 * sin(a * 3.0 - log(r + 0.04) * 7.0 - age * p1), 2.0);
		float n = ring_noise(a, 3.0, age * 1.5 - r * 4.0);
		float body = smoothstep(inner * 0.9, inner * 1.15, r);
		float fall = pow(max(1.0 - r, 0.0), 1.4);
		float hot_rim = 1.0 - smoothstep(0.0, 0.1, abs(r - inner * 1.25));
		al = body * (fall * (0.25 + 0.9 * arms * (0.5 + n)) + hot_rim);
		h = hot_rim + fall * arms * 0.6;
		over = hue(a / 6.2832 + r - age * 0.2);
		over_mix = prism * 0.4 * (1.0 - hot_rim);
	} else if (mode == 12) {
		float bar = max((1.0 - smoothstep(0.12, 0.2, abs(p.x))) * (1.0 - smoothstep(0.55, 0.65, abs(p.y))), (1.0 - smoothstep(0.12, 0.2, abs(p.y))) * (1.0 - smoothstep(0.55, 0.65, abs(p.x))));
		float soft = pow(max(1.0 - r, 0.0), 2.0) * 0.5;
		al = (bar + soft) * sqrt(max(sin(k * 3.1416), 0.0));
		h = bar;
	} else if (mode == 13) {
		float across = abs(UV.x - 0.5) * 2.0;
		float flick = step(0.3, noise(vec2(age * 34.0, v_seed * 5.0 + floor(UV.y * 3.0))));
		al = (1.0 - smoothstep(0.1, 1.0, across)) * (0.35 + 0.65 * flick) * (1.0 - smoothstep(0.55, 1.0, k));
		h = 1.0 - smoothstep(0.0, 0.5, across);
	} else if (mode == 14) {
		// Fire on a column or a wall: solid at the foot, torn into tongues towards the top.
		float y = 1.0 - UV.y;
		float ax = UV.x * 6.2832;
		vec2 round_ = vec2(cos(ax), sin(ax));
		float n = noise(round_ * max(p2, 0.5) + vec2(v_seed * 5.0, y * 3.0 - age * p1)) * 0.6 + noise(round_ * max(p2, 0.5) * 2.6 + vec2(y * 7.0 - age * p1 * 1.6, v_seed)) * 0.4;
		float body = n * 1.25 - y * 1.05 + 0.18 - k * k * 0.5;
		float foot = smoothstep(0.0, 0.03, y);
		al = smoothstep(0.0, 0.14, body) * foot;
		h = clamp(body * 1.5 + (0.25 - y) * 0.6, 0.0, 1.0);
	}
	vec3 col = mix(c_edge.rgb, c_mid.rgb, smoothstep(0.0, 0.5, h));
	col = mix(col, c_core.rgb, smoothstep(0.5, 1.0, h));
	col = mix(col, over, over_mix);
	float alpha = clamp(al * gain, 0.0, 1.0) * fade * v_on;
	if (alpha < 0.004) {
		discard;
	}
	ALBEDO = col;
	ALPHA = alpha;
}
