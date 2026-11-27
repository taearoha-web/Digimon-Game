shader_type spatial;
// ดินแดนเทวาลัย's code-sculpted folk (HeavenFolk, HeavenFolkVisual): one mesh posed by the
// shared vertex stage (heaven_folk_pose.gdshaderinc), toon lit like the isle's kirin with a
// warm rim. Vertex colours carry the palette; UV2 = (glow, pattern):
//   glow 0..1 self-lit share, 2 a charge light (the lantern, the orbs, the seal: they kindle
//   with "charge")
//   pattern 1 tiger skin (broken black stripes), 2 engraved gold, 3 cloud (soft vapour),
//   4 white silk with a gold ลาย lattice, 5 the lantern's paper (gold ribs, a red band),
//   6 skin (a softer, warmer shade); 10 more: the same, without the ink outline
// No textures; the hit flash lights the material; the death burns it away into gold.
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

#include "res://shaders/heaven_folk_pose.gdshaderinc"

uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.82, 1.0);
uniform float rim = 0.3;
uniform vec4 shadow_tint : source_color = vec4(0.76, 0.7, 0.8, 1.0);
uniform vec4 gold : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform vec4 stripe : source_color = vec4(0.16, 0.08, 0.05, 1.0);
uniform vec4 lantern_red : source_color = vec4(0.86, 0.16, 0.18, 1.0);
uniform float glow = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0);
uniform float charge = 0.0;

varying vec3 wn;
varying vec3 wp;
varying vec2 info;
varying float part_id;

void vertex() {
	rest = VERTEX;
	vec3 p = VERTEX;
	vec3 n = NORMAL;
	folk_pose(p, n, CUSTOM1.w, CUSTOM0.w, COLOR.a);
	VERTEX = p;
	NORMAL = normalize(n);
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	info = UV2;
	part_id = CUSTOM1.w;
}

void fragment() {
	float burn = folk_burn(part_id);
	if (burn < 0.0) discard;
	vec3 base = COLOR.rgb;
	float pat = mod(floor(info.y + 0.5), 10.0);
	if (pat == 1.0) {
		// Tiger skin: wavy, broken black stripes round the body.
		float w = rest.y * 34.0 + folk_noise(rest * 4.0) * 6.0 + sin(rest.x * 9.0 + rest.z * 6.0) * 1.6;
		float s = smoothstep(0.55, 0.72, sin(w)) * smoothstep(0.3, 0.5, folk_noise(rest * vec3(7.0, 2.5, 7.0) + 3.0));
		base = mix(base, stripe.rgb, s * 0.92);
	} else if (pat == 2.0) {
		float l = abs(sin((rest.x + rest.y) * 46.0)) * abs(sin((rest.y - rest.x + rest.z) * 46.0));
		base *= 1.0 - (1.0 - smoothstep(0.0, 0.12, l)) * 0.22;
	} else if (pat == 4.0) {
		vec2 q = vec2(rest.x + rest.y * 0.8 + rest.z * 0.5, rest.y * 0.8 - rest.x + rest.z * 0.5) * 13.0;
		float lat = min(abs(fract(q.x) - 0.5), abs(fract(q.y) - 0.5));
		float dotc = length(fract(q + 0.5) - 0.5);
		float line = 1.0 - smoothstep(0.035, 0.075, lat);
		line = max(line, 1.0 - smoothstep(0.07, 0.12, dotc));
		base = mix(base, gold.rgb, line * 0.7);
	} else if (pat == 5.0) {
		float rib = 1.0 - smoothstep(0.04, 0.09, abs(fract(UV.x * 8.0) - 0.5) * -1.0 + 0.5);
		float band = smoothstep(0.36, 0.4, UV.y) * (1.0 - smoothstep(0.6, 0.64, UV.y));
		base = mix(base, lantern_red.rgb * 1.3, band * 0.75);
		base = mix(base, gold.rgb, rib * 0.85);
	}
	vec3 nn = normalize(wn);
	vec3 v = normalize(CAMERA_POSITION_WORLD - wp);
	float l = dot(nn, normalize(vec3(0.25, 0.9, 0.1) + v * 0.55)) * 0.5 + 0.5;
	vec3 col;
	if (pat == 6.0) {
		col = mix(base * vec3(0.86, 0.74, 0.72), base, smoothstep(0.32, 0.5, l));
	} else {
		col = mix(base * shadow_tint.rgb, base, smoothstep(0.42, 0.54, l));
	}
	col += base * smoothstep(0.82, 0.92, l) * (pat == 2.0 ? 0.45 : 0.18);
	float fr = pow(1.0 - abs(dot(nn, v)), 2.5);
	col = mix(col, rim_color.rgb, clamp(fr * rim, 0.0, 1.0));
	float emit = clamp(info.x, 0.0, 1.0);
	col = mix(col, base * 1.15 + 0.06, emit);
	if (pat == 3.0) {
		// Cloud: a wide soft shade, its outline melting into white.
		vec3 vapour = mix(base * vec3(0.86, 0.9, 0.97), base * 1.06 + 0.04, smoothstep(0.15, 0.95, l));
		col = mix(vapour, vec3(1.0), clamp(fr * 1.5, 0.0, 0.8));
		if (emit > 0.5) col = base * 1.15 + 0.06;
	}
	if (info.x > 1.5) {
		// The lantern, the orbs, the seal: alight, kindling with the charge.
		float flicker = 0.06 * sin(TIME * 9.0 + seed * 3.0) + 0.04 * sin(TIME * 23.0);
		float white = part_id > 7.5 ? charge * 0.3 : charge * 0.75;
		col = mix(base * (1.12 + flicker) + 0.08, vec3(1.0, 0.98, 0.86), clamp(white + fr * 0.3, 0.0, 1.0));
	}
	if (dissolve > 0.0) {
		col = mix(col, vec3(1.0, 0.9, 0.5), (1.0 - smoothstep(0.0, 0.09, burn)) * 0.95);
	}
	ALBEDO = mix(col, glow_color.rgb, glow);
}
