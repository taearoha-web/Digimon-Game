shader_type spatial;
// ดินแดนเทวาลัย's winged Himmapan folk, the กินรี and the ครุฑน้อยเทวาลัย (HeavenBird,
// HeavenBirdVisual): one code-built mesh posed by the shared vertex stage
// (heaven_bird_pose.gdshaderinc). Toon lit in two bands under a key light fixed to the
// view with a warm rim (it reads on the realm's white marble), and painted from the vertex
// data: COLOR.rgb the tone, COLOR.a the finish (1 plain, 0.875 body feathers in scallops,
// 0.75 a feather's vane and shaft, 0.5 engraved gold in a ประจำยาม lattice, 0.25 cloth
// strewn with gold), UV2.x the light (1 lit, 2 the ribbon and the nails, alight with the
// charge). fade dissolves it into gold from the edges of soft blotches (the death);
// glow is the hit flash. No textures.
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

#include "res://shaders/heaven_bird_pose.gdshaderinc"

uniform vec4 rim_color : source_color = vec4(1.0, 0.94, 0.76, 1.0);
uniform float rim = 0.3;
uniform vec4 shadow_tint : source_color = vec4(0.8, 0.68, 0.76, 1.0);
uniform vec4 line_color : source_color = vec4(0.55, 0.26, 0.06, 1.0);
uniform vec4 beam_color : source_color = vec4(1.0, 0.86, 0.42, 1.0);
uniform float charge = 0.0;
uniform float glow = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0);
uniform float fade = 1.0;
// 0 at the lowest quality: plain tones, no painted patterns.
uniform float detail = 1.0;
varying vec3 wn;
varying vec3 wp;
varying vec3 rest;
varying vec3 rest_n;
varying vec2 info;

void vertex() {
	rest = VERTEX;
	rest_n = NORMAL;
	vec3 p = VERTEX;
	vec3 n = NORMAL;
	bird_pose(p, n, CUSTOM0, CUSTOM1);
	VERTEX = p;
	NORMAL = normalize(n);
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	info = UV2;
}

float bird_hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float bird_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(bird_hash(i), bird_hash(i + vec3(1, 0, 0)), f.x), mix(bird_hash(i + vec3(0, 1, 0)), bird_hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(bird_hash(i + vec3(0, 0, 1)), bird_hash(i + vec3(1, 0, 1)), f.x), mix(bird_hash(i + vec3(0, 1, 1)), bird_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// The rest position seen from the side the surface faces (front/back or left/right).
vec2 bird_plane() {
	vec3 an = abs(rest_n);
	return an.x > an.z ? vec2(rest.z, rest.y) : vec2(rest.x, rest.y);
}

void fragment() {
	float edge = 1.0;
	if (fade < 0.999) {
		float nz = bird_noise(rest * 6.0) * 0.7 + bird_noise(rest * 15.0) * 0.3;
		edge = nz - (1.0 - fade) * 1.2 + 0.1;
		if (edge < 0.0) {
			discard;
		}
	}
	vec3 base = COLOR.rgb;
	float m = COLOR.a;
	if (detail > 0.5) {
		if (m > 0.81 && m < 0.94) {
			// Body feathers: rows of scallops, each lit at its heart and lined at its rim.
			vec2 q = bird_plane() * vec2(11.0, 15.0);
			float row = floor(q.y);
			vec2 f = vec2(fract(q.x + 0.5 * mod(row, 2.0)) - 0.5, fract(q.y));
			float d = length(vec2(f.x * 1.1, f.y * 0.9 - 0.05));
			base *= mix(1.1, 0.86, smoothstep(0.25, 0.55, d));
			base = mix(base, line_color.rgb * 0.9 + base * 0.3, smoothstep(0.5, 0.56, d) * 0.3);
		} else if (m > 0.62 && m < 0.81) {
			// A feather: a pale shaft down the middle, the vane darkening to its edges, barbs.
			float across = abs(UV.x - 0.5) * 2.0;
			base *= mix(1.06, 0.8, smoothstep(0.45, 1.0, across));
			base = mix(base, base * 1.2 + vec3(0.1, 0.09, 0.06), (1.0 - smoothstep(0.03, 0.09, abs(UV.x - 0.5))) * 0.8 * (1.0 - UV.y * 0.6));
			base *= 1.0 - 0.07 * step(0.55, fract(UV.y * 10.0 - across * 1.5));
		} else if (m > 0.38 && m < 0.62) {
			// Engraved gold: the ประจำยาม lattice, a four-petal flower in each diamond.
			vec2 q = bird_plane() * 16.0;
			vec2 r = vec2(q.x + q.y, q.x - q.y) * 0.7071;
			vec2 c = fract(r) - 0.5;
			float dia = max(abs(c.x), abs(c.y));
			float petal = abs(c.x) + abs(c.y);
			base = mix(base, line_color.rgb, smoothstep(0.43, 0.48, dia) * 0.75);
			base = mix(base, base * 1.22 + 0.05, (1.0 - smoothstep(0.16, 0.22, petal)) * 0.8);
			base = mix(base, line_color.rgb, (1.0 - smoothstep(0.03, 0.07, length(c))) * 0.8);
		} else if (m > 0.12 && m < 0.38) {
			// Cloth: little gold flowers strewn over the weave.
			vec2 q = bird_plane() * 13.0;
			vec2 c = fract(vec2(q.x + 0.5 * mod(floor(q.y), 2.0), q.y)) - 0.5;
			float star = abs(c.x) + abs(c.y);
			base = mix(base, vec3(1.0, 0.8, 0.32), (1.0 - smoothstep(0.12, 0.17, star)) * 0.85);
		}
	}
	vec3 nn = normalize(wn);
	if (!FRONT_FACING) {
		nn = -nn;
	}
	vec3 v = normalize(CAMERA_POSITION_WORLD - wp);
	float l = dot(nn, normalize(vec3(0.25, 0.9, 0.1) + v * 0.55)) * 0.5 + 0.5;
	vec3 col = mix(base * shadow_tint.rgb, base, smoothstep(0.4, 0.52, l));
	col += base * smoothstep(0.82, 0.92, l) * 0.18;
	float fr = pow(1.0 - abs(dot(nn, v)), 2.5);
	col = mix(col, rim_color.rgb, clamp(fr * rim, 0.0, 1.0));
	float emit = info.x;
	col = mix(col, base * 1.15 + 0.08, clamp(emit, 0.0, 1.0));
	if (emit > 1.5) {
		// The ribbon of light and the gold nails: white-hot at the core, alight with the charge.
		float core = 1.0 - abs(UV.x - 0.5) * 2.0;
		vec3 hot = mix(beam_color.rgb, vec3(1.0, 0.99, 0.92), smoothstep(0.2, 0.8, core));
		col = mix(base * 1.1 + 0.06, hot * (1.0 + 0.35 * charge), clamp(charge * 1.4, 0.0, 1.0));
	}
	if (fade < 0.999) {
		// The dissolving edge burns gold.
		col = mix(col, vec3(1.0, 0.86, 0.4) * 1.3, 1.0 - smoothstep(0.0, 0.12, edge));
	}
	ALBEDO = mix(col, glow_color.rgb, glow);
}
