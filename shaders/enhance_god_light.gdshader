shader_type spatial;
// +15 god look A · แสงเทพเจิดจ้า (EnhanceFx._god, GOD_STYLE 0): the body itself radiates in
// the outfit's colour. One mesh (EnhanceFx._god_light_mesh), one draw:
//   kind 0  a card standing just behind the body: a white-hot glow hugging the outline,
//           a soft bloom round it, fine rays of light streaming out past the outline and
//           four-point stars twinkling round it (the body hides it in front of the face)
//   kind 1  a shell hugging the body: a bright fresnel rim flowing upwards
//   kind 2  a soft pool of light on the ground
// Animated from TIME (a slow breath), no script runs per frame.
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/enhance_god.gdshaderinc"

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float energy = 1.0;
// 0: the crowd's cheap dress (no stars, no rays' flicker).
uniform float rich = 1.0;

varying float v_kind;
varying vec2 v_p;

const vec2 STARS[8] = vec2[8](vec2(-0.78, 1.78), vec2(0.82, 1.52), vec2(-0.66, 0.72), vec2(0.72, 0.98),
	vec2(-0.3, 2.16), vec2(0.4, 2.08), vec2(-0.9, 1.22), vec2(0.86, 0.42));

void vertex() {
	v_kind = floor(COLOR.r * 8.0 + 0.5);
	if (v_kind < 0.5) {
		vec2 off = (UV - 0.5) * UV2;
		v_p = off + vec2(0.0, VERTEX.y);
		POSITION = PROJECTION_MATRIX * vec4(g_card(MODEL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, VERTEX, off, 0.32, true), 1.0);
	} else {
		v_p = v_kind < 1.5 ? UV : (UV - 0.5) * UV2;
		POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	}
}

float star(vec2 q, float size) {
	q /= size;
	float arms = exp(-abs(q.x) * 70.0) * exp(-abs(q.y) * 7.0) + exp(-abs(q.y) * 70.0) * exp(-abs(q.x) * 7.0);
	return arms + exp(-dot(q, q) * 500.0) * 1.5;
}

void fragment() {
	float t = TIME;
	float breath = 0.86 + 0.14 * sin(t * 1.7);
	vec3 white = vec3(1.0, 0.98, 0.94);
	vec3 col;
	float g;
	if (v_kind < 0.5) {
		vec2 p = v_p;
		float d = g_body(p);
		float od = max(d, 0.0);
		float hug = exp(-od * 8.0);
		float bloom = exp(-od * 2.4);
		// Rays from the chest: many fine ones and a few broad ones, slowly turning, light
		// streaming outwards along them.
		vec2 c = p - vec2(0.0, 1.05);
		float a = atan(c.x, c.y);
		float r = length(c);
		float fine = pow(0.5 + 0.5 * sin(a * 31.0 + sin(a * 3.0 + t * 0.3) * 2.0), 10.0);
		float broad = pow(0.5 + 0.5 * sin(a * 8.0 - t * 0.21), 5.0);
		float flick = mix(0.8, 0.45 + 0.55 * g_noise(vec2(a * 5.0 + 20.0, t * 0.8)), rich);
		float stream = 0.7 + 0.3 * sin(r * 7.0 - t * 2.6);
		float rays = (fine * 0.95 + broad * 0.6) * flick * stream * exp(-od * 1.15) * smoothstep(2.1, 1.0, r);
		float stars = 0.0;
		if (rich > 0.5) {
			for (int i = 0; i < 8; i++) {
				float tw = pow(max(sin(t * 1.5 + float(i) * 2.3), 0.0), 3.0);
				stars += star(p - STARS[i], 0.6 + 0.6 * tw) * tw;
			}
		}
		vec2 edge = smoothstep(vec2(0.5), vec2(0.38), abs(UV - 0.5));
		g = ((hug * 1.35 + bloom * 0.45 + rays * 1.1) * breath + stars * 1.3) * edge.x * edge.y;
		col = mix(color.rgb, white, clamp(hug * 0.65 + stars * 0.8, 0.0, 0.9));
		ALPHA = clamp(g * 0.62, 0.0, 0.95);
	} else if (v_kind < 1.5) {
		float f = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
		float rim = smoothstep(0.45, 1.0, f);
		float flow = 0.6 + 0.4 * sin(v_p.x * TAU * 9.0 + sin(v_p.y * 11.0 - t * 2.2) * 1.6);
		g = rim * rim * flow * 1.5 * smoothstep(0.0, 0.1, v_p.y) * smoothstep(1.0, 0.82, v_p.y) * breath;
		g *= FRONT_FACING ? 1.0 : 0.45;
		col = mix(color.rgb, white, rim * 0.55);
		ALPHA = clamp(g * 0.55, 0.0, 0.9);
	} else {
		float r = length(v_p);
		float ring = exp(-pow((r - 0.62) / 0.045, 2.0));
		g = (exp(-r * r * 3.0) * 0.75 + ring * 0.6) * breath * smoothstep(1.2, 0.9, r);
		col = mix(color.rgb, white, exp(-r * r * 8.0) * 0.5);
		ALPHA = clamp(g * 0.5, 0.0, 0.8);
	}
	if (g <= 0.003) {
		discard;
	}
	ALBEDO = col * g * energy;
}
