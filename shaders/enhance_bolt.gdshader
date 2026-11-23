shader_type spatial;
// Lightning of enhanced gear (EnhanceFx: the set's sparks round the body from +11, the
// weapon's sparks from +10 and the ring round the hand at +15). One shared mesh of
// strips (EnhanceFx._bolt_mesh): each strip is a smooth path; here it becomes a jagged
// bolt that lives a fraction of a second, goes dark, and strikes again somewhere else
// (the path turned round the mesh's Y axis and slid along it), with short forks that
// flash off it. No script runs per frame.
// Per vertex: VERTEX the path point, NORMAL the path's direction, UV (side, t),
// UV2 (path length, the fork's root t on its bolt or -1 for a bolt), COLOR (seed,
// the bolt's seed, colour pick a/b, tier: drawn while tier < density).
// amp and width are world units in the view plane, so the jags look the same at any size.
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

uniform vec4 color_a : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform vec4 color_b : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform float density = 1.0;
uniform float forks = 1.0;
uniform float rate = 6.0;
uniform float duty = 0.6;
uniform float amp = 0.05;
uniform float width = 0.02;
uniform float energy = 1.4;
uniform float segs = 10.0;
uniform float spin = 1.0;
uniform float slide = 0.15;
uniform float seed = 0.0;

varying float v_side;
varying float v_light;
varying float v_pick;

float hash1(float n) {
	return fract(sin(n * 12.9898 + 4.1414) * 43758.5453);
}

vec2 hash2(float n) {
	return fract(sin(vec2(n * 12.9898 + 1.3, n * 78.233 + 2.9)) * 43758.5453);
}

// The jag of point i of a strip in this life, in the view plane (-1..1).
vec2 jag(float s, float i, float life) {
	return hash2(s * 97.13 + i * 7.31 + life * 1.737) * 2.0 - 1.0;
}

// A bolt's offset at point i: pinned at both ends, widest in the middle.
vec2 bolt_off(float s, float i, float life) {
	float e = (i <= 0.0 || i >= segs) ? 0.0 : 0.55 + 0.45 * sin(3.14159 * i / segs);
	return jag(s, i, life) * amp * e;
}

// A fork's offset at point i: from its root on the bolt, wandering off freely.
vec2 fork_off(vec2 root, float s, float i, float life) {
	return root + jag(s, i, life) * amp * 0.85 * min(max(i, 0.0) / segs * 2.5, 1.0);
}

vec3 turn_y(vec3 p, float a) {
	float c = cos(a);
	float sn = sin(a);
	return vec3(c * p.x + sn * p.z, p.y, -sn * p.x + c * p.z);
}

void vertex() {
	float s = COLOR.r;
	float bolt = COLOR.g;
	bool is_fork = UV2.y >= 0.0;
	float speed = rate * (0.7 + 0.6 * hash1(bolt * 31.7 + seed));
	float clock = TIME * speed + bolt * 17.0 + seed * 5.3;
	float life = floor(clock);
	float f = fract(clock);
	float lit = step(hash1(life * 1.37 + bolt * 57.1 + seed), duty) * step(COLOR.a, density - 0.001);
	if (is_fork) {
		lit *= step(hash1(life * 3.11 + s * 23.0), 0.65) * step(f, 0.5) * step(0.5, forks);
	}
	float i = floor(UV.y * segs + 0.5);
	float stp = UV2.x / segs;
	vec3 dir = NORMAL;
	float turn = (hash1(life * 0.913 + bolt * 3.7 + seed) * 2.0 - 1.0) * 3.14159 * spin;
	vec3 lift = vec3(0.0, (hash1(life * 2.31 + bolt * 9.1) - 0.5) * slide, 0.0);
	vec3 v0 = (MODELVIEW_MATRIX * vec4(turn_y(VERTEX, turn) + lift, 1.0)).xyz;
	vec3 va = (MODELVIEW_MATRIX * vec4(turn_y(VERTEX - dir * stp, turn) + lift, 1.0)).xyz;
	vec3 vb = (MODELVIEW_MATRIX * vec4(turn_y(VERTEX + dir * stp, turn) + lift, 1.0)).xyz;
	if (is_fork) {
		vec2 root = bolt_off(bolt, floor(UV2.y * segs + 0.5), life);
		v0.xy += fork_off(root, s, i, life);
		va.xy += fork_off(root, s, i - 1.0, life);
		vb.xy += fork_off(root, s, i + 1.0, life);
	} else {
		v0.xy += bolt_off(s, i, life);
		va.xy += bolt_off(s, i - 1.0, life);
		vb.xy += bolt_off(s, i + 1.0, life);
	}
	vec2 along = vb.xy - va.xy;
	along = length(along) > 0.00001 ? normalize(along) : vec2(0.0, 1.0);
	vec2 across = vec2(-along.y, along.x);
	float taper = is_fork ? 0.75 * (1.0 - 0.75 * UV.y) : 0.6 + 0.4 * sin(3.14159 * UV.y);
	v0.xy += across * (UV.x * 2.0 - 1.0) * width * taper * lit;
	VERTEX = v0;
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_side = UV.x;
	// A flash at the start of each life fading out, and a fast flicker on top.
	float flick = 0.72 + 0.28 * step(0.35, hash1(floor(TIME * 30.0) + s * 91.0));
	v_light = lit * pow(1.0 - f, 0.55) * flick;
	v_pick = COLOR.b;
}

void fragment() {
	if (v_light <= 0.002) {
		discard;
	}
	float d = abs(v_side * 2.0 - 1.0);
	float core = 1.0 - smoothstep(0.0, 0.3, d);
	float halo = 1.0 - smoothstep(0.05, 1.0, d);
	halo *= halo;
	vec3 tint = mix(color_a.rgb, color_b.rgb, v_pick);
	vec3 light = (tint * halo * 0.9 + mix(tint, vec3(1.0), 0.65) * core) * energy * v_light;
	ALBEDO = light;
	ALPHA = clamp((core * 0.7 + halo * 0.35) * v_light, 0.0, 0.9);
}
