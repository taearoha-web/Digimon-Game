shader_type spatial;
// Solid god-tier set pieces (a throne, a crown, clouds, instruments, shards): opaque,
// depth-written, vertex-coloured, toon-lit with a rim; they dissolve in and out.
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;
#include "god_arcane.gdshaderinc"
varying vec3 wn;
varying vec3 wp;
varying vec3 lp;
varying float emit;

void vertex() {
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	lp = v;
	god_move(v, n, COLOR, UV2, CUSTOM0, CUSTOM1);
	VERTEX = v;
	NORMAL = n;
	wn = normalize((MODEL_MATRIX * vec4(n, 0.0)).xyz);
	wp = (MODEL_MATRIX * vec4(v, 1.0)).xyz;
	emit = UV2.x;
}

void fragment() {
	float g = god_grain(lp * 1.7);
	float edge = fade * 1.25 - 0.12;
	if (fade < 0.995 && g > edge) discard;
	vec3 v = normalize(CAMERA_POSITION_WORLD - wp);
	vec3 col = god_toon(COLOR.rgb, normalize(wn), v, emit);
	if (fade < 0.995) col = mix(col, rim_color.rgb, smoothstep(edge - 0.16, edge, g));
	ALBEDO = col;
}
