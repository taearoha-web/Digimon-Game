shader_type spatial;
// +15 god look B · เสาแสงสวรรค์ (EnhanceFx._god, GOD_STYLE 1): a column of heaven's light in
// the outfit's colour from the ground through the body up into the sky. One mesh
// (EnhanceFx._god_pillar_mesh), one draw:
//   kind 0  the column (an open cylinder, UV.x round, UV.y up): bright streaming edges,
//           bands of light climbing it, a clear middle in front of the face and a brighter
//           back wall behind the body; fading out high in the sky
//   kind 1  the ring of light at the feet: a bright ring, a turning ring of glyph dashes
//           and waves running out
//   kind 2  sparkle motes and kind 3 light petals spiralling up the column
// Animated from TIME, no script runs per frame.
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/enhance_god.gdshaderinc"

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float energy = 1.0;
uniform float height = 6.5;
// 0: the crowd's cheap dress (no petals, half the motes).
uniform float rich = 1.0;

varying float v_kind;
varying vec2 v_p;
varying float v_fade;
varying float v_turn;

void vertex() {
	v_kind = floor(COLOR.r * 8.0 + 0.5);
	v_fade = 1.0;
	v_turn = 0.0;
	if (v_kind < 1.5) {
		v_p = v_kind < 0.5 ? UV : (UV - 0.5) * UV2;
		POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	} else {
		float s = COLOR.g;
		float sp = 0.13 + 0.1 * g_hash(vec2(s, 1.7));
		float ph = fract(TIME * sp + s * 5.37);
		float ang = s * 37.0 + ph * TAU * 1.25;
		float rad = 0.5 + 0.25 * g_hash(vec2(s, 4.1)) + 0.12 * ph;
		vec3 at = vec3(cos(ang) * rad, 0.05 + ph * 3.6, sin(ang) * rad);
		v_fade = smoothstep(0.0, 0.1, ph) * smoothstep(1.0, 0.6, ph) * g_face_guard(MODEL_MATRIX, INV_VIEW_MATRIX, at);
		v_turn = ph * TAU * 1.5 + s * 9.0;
		v_p = UV * 2.0 - 1.0;
		vec2 off = (UV - 0.5) * UV2 * (0.7 + 0.5 * sin(ph * PI));
		if (rich < 0.5 && (v_kind > 2.5 || COLOR.b > 0.5)) {
			off = vec2(0.0);
		}
		POSITION = PROJECTION_MATRIX * vec4(g_card(MODEL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, at, off, 0.0, false), 1.0);
	}
}

void fragment() {
	float t = TIME;
	vec3 white = vec3(1.0, 0.98, 0.94);
	vec3 col;
	float g;
	float alpha_k = 0.55;
	if (v_kind < 0.5) {
		float y = v_p.y * height;
		float f = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
		float edge = pow(f, 1.5);
		float around = v_p.x * TAU;
		float s1 = g_noise(vec2(v_p.x * 22.0, y * 0.55 - t * 1.5));
		float s2 = g_noise(vec2(v_p.x * 48.0 + 7.0, y * 1.3 - t * 2.6));
		float streak = smoothstep(0.3, 0.9, s1 * 0.6 + s2 * 0.4);
		float band = pow(0.5 + 0.5 * sin(y * 2.0 - t * 3.0 + sin(around * 3.0) * 0.6), 10.0);
		float base = 1.0 + 1.6 * exp(-y * 2.2);
		float fall = smoothstep(height, height * 0.3, y) * smoothstep(0.0, 0.06, y);
		if (FRONT_FACING) {
			// In front of the body: only the column's edges stream; the middle stays clear.
			float rim = smoothstep(0.5, 1.0, f);
			g = (rim * rim * (0.7 + 1.2 * streak) + band * rim * 0.8 + 0.015) * base;
		} else {
			// Behind the body: a lit wall glowing round the outline, streaming upwards.
			g = (0.16 + edge * 0.7 + streak * 0.55 + band * 0.55) * base;
		}
		g *= fall * (0.9 + 0.1 * sin(t * 2.0));
		col = mix(color.rgb, white, clamp(0.12 + 0.55 * edge * streak + band * 0.35, 0.0, 0.8));
		alpha_k = 0.5;
	} else if (v_kind < 1.5) {
		vec2 p = v_p;
		float r = length(p);
		float a = atan(p.y, p.x);
		float ring = exp(-pow((r - 0.74) / 0.035, 2.0)) * 1.6;
		float outer = exp(-pow((r - 1.02) / 0.02, 2.0));
		float dash = smoothstep(0.35, 0.5, abs(fract(a / TAU * 24.0 + t * 0.08) - 0.5) * 2.0);
		float glyph = exp(-pow((r - 0.9) / 0.05, 2.0)) * dash;
		float wave_t = fract(t * 0.45);
		float wave = exp(-pow((r - 0.74 - wave_t * 0.5) / 0.04, 2.0)) * (1.0 - wave_t);
		float pool = smoothstep(0.78, 0.0, r) * 0.55;
		g = (ring + outer * 0.8 + glyph * 0.9 + wave * 0.9 + pool) * smoothstep(1.25, 1.1, r) * (0.88 + 0.12 * sin(t * 2.0));
		col = mix(color.rgb, white, clamp(ring * 0.4 + pool * 0.5, 0.0, 0.8));
		alpha_k = 0.6;
	} else if (v_kind < 2.5) {
		vec2 q = v_p;
		float d2 = dot(q, q);
		float tw = 0.7 + 0.3 * sin(t * 9.0 + v_turn * 3.0);
		float cross_ = (exp(-abs(q.x) * 30.0) + exp(-abs(q.y) * 30.0)) * exp(-d2 * 3.0) * 0.6;
		g = (exp(-d2 * 9.0) * 1.2 + exp(-d2 * 40.0) * 1.2 + cross_) * v_fade * tw;
		col = mix(color.rgb, white, exp(-d2 * 30.0));
		alpha_k = 0.6;
	} else {
		// A petal / feather of light, turning as it rises.
		float cs = cos(v_turn);
		float sn = sin(v_turn);
		vec2 q = mat2(vec2(cs, sn), vec2(-sn, cs)) * v_p;
		float lens = max(length(q - vec2(0.5, 0.0)), length(q + vec2(0.5, 0.0))) - 0.66;
		float body = smoothstep(0.06, -0.06, lens);
		float vein = exp(-abs(q.x) * 18.0) * smoothstep(0.8, 0.0, abs(q.y));
		float halo = exp(-max(lens, 0.0) * 9.0) * 0.4;
		g = (body * (0.65 + 0.35 * (1.0 - abs(q.y))) + vein * 0.7 + halo) * v_fade;
		col = mix(color.rgb, white, clamp(vein * 0.8 + body * 0.3, 0.0, 0.9));
		alpha_k = 0.75;
	}
	if (g <= 0.003) {
		discard;
	}
	ALBEDO = col * g * energy;
	ALPHA = clamp(g * alpha_k, 0.0, 0.92);
}
