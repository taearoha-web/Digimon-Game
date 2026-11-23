shader_type spatial;
// +15 god look C · เปลวออร่าพลัง (EnhanceFx._god, GOD_STYLE 2): an anime power-up aura in the
// outfit's colour. One mesh (EnhanceFx._god_flame_mesh), one draw:
//   kind 0  a card standing just behind the body: a big toon flame, flickering upwards to
//           a point above the head, in crisp bands (a deep edge line, the colour, a
//           lighter layer, a white-hot core round the body)
//   kind 1  a card in front of the body: tongues of the same flame licking up its sides
//           (never over the face)
//   kind 2  sparks shooting up
//   kind 3  the glow on the ground
// Animated from TIME, no script runs per frame.
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/enhance_god.gdshaderinc"

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float energy = 1.0;
// 0: the crowd's cheap dress (no front tongues, a third of the sparks).
uniform float rich = 1.0;

varying float v_kind;
varying vec2 v_p;
varying float v_fade;

void vertex() {
	v_kind = floor(COLOR.r * 8.0 + 0.5);
	v_fade = 1.0;
	if (v_kind < 1.5) {
		vec2 off = (UV - 0.5) * UV2;
		v_p = off + vec2(0.0, VERTEX.y);
		if (rich < 0.5 && v_kind > 0.5) {
			off = vec2(0.0);
		}
		POSITION = PROJECTION_MATRIX * vec4(g_card(MODEL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, VERTEX, off, v_kind < 0.5 ? 0.34 : -0.42, true), 1.0);
	} else if (v_kind < 2.5) {
		float s = COLOR.g;
		float sp = 0.55 + 0.35 * g_hash(vec2(s, 2.3));
		float ph = fract(TIME * sp + s * 3.71);
		float ang = s * 41.0;
		float rad = 0.42 + 0.32 * g_hash(vec2(s, 5.9));
		vec3 at = vec3(cos(ang) * rad, 0.1 + ph * 2.9, sin(ang) * rad);
		v_fade = smoothstep(0.0, 0.12, ph) * smoothstep(1.0, 0.55, ph) * g_face_guard(MODEL_MATRIX, INV_VIEW_MATRIX, at);
		v_p = UV * 2.0 - 1.0;
		vec2 off = (UV - 0.5) * UV2;
		if (rich < 0.5 && COLOR.b > 0.34) {
			off = vec2(0.0);
		}
		POSITION = PROJECTION_MATRIX * vec4(g_card(MODEL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, at, off, 0.0, true), 1.0);
	} else {
		v_p = (UV - 0.5) * UV2;
		POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	}
}

// The flame's field at [p] (x across, y up from the feet, metres): > 0 inside, rising
// towards the body; tongues licking upwards, breaking apart near the top.
float flame(vec2 p, float t, float wide) {
	float hn = clamp(p.y / 2.95, 0.0, 1.0);
	// The outline: hugging the legs, widest round the big head, a point above it.
	float w = (0.4 + 0.5 * smoothstep(0.0, 0.5, hn) - 0.9 * smoothstep(0.5, 1.0, hn)) * wide;
	float sway = (g_noise(vec2(p.y * 1.1 - t * 1.3, 3.0)) - 0.5) * 0.28 * hn;
	float x = abs(p.x - sway);
	// Tongues: noise stretched upwards and rising fast pushes the outline out, so the
	// flame breaks into tall licks with narrow tips, most of all near the top.
	float n1 = g_noise(vec2(p.x * 4.6, p.y * 0.95 - t * 2.6));
	float n2 = g_noise(vec2(p.x * 9.0 + 5.0, p.y * 2.5 - t * 4.6));
	float n = n1 * 0.65 + n2 * 0.35;
	return 1.0 - x / max(w, 0.04) + (pow(n, 1.6) - 0.3) * (0.45 + 0.75 * hn);
}

float band(float f, float at, float fw) {
	return smoothstep(at - fw, at + fw, f);
}

void fragment() {
	float t = TIME;
	vec3 white = vec3(1.0, 0.99, 0.95);
	vec3 deep = pow(color.rgb, vec3(1.8)) * 0.62;
	vec3 col;
	float alpha;
	if (v_kind < 1.5) {
		bool front = v_kind > 0.5;
		vec2 p = v_p;
		float f = front ? flame(p * vec2(1.0, 1.05), t + 4.7, 0.93) : flame(p, t, 1.0);
		float fw = max(fwidth(f), 0.004);
		float e0 = band(f, 0.0, fw);
		float e1 = band(f, 0.05, fw);
		float e2 = band(f, 0.24, fw);
		float e3 = band(f, 0.42, fw);
		float streak = 0.85 + 0.3 * g_noise(vec2(p.x * 12.0, p.y * 1.6 - t * 4.5));
		float beat = 0.92 + 0.08 * sin(t * 8.0) * sin(t * 3.1);
		// Lighter up the flame: the colour glows towards its tips.
		float lift = smoothstep(0.2, 2.6, p.y);
		col = deep;
		alpha = 0.85 * e0;
		col = mix(col, color.rgb * (1.2 + 0.3 * lift) * streak, e1);
		alpha = mix(alpha, 0.62, e1);
		col = mix(col, mix(color.rgb, white, 0.5) * 1.6 * streak, e2);
		alpha = mix(alpha, 0.8, e2);
		if (!front) {
			col = mix(col, mix(color.rgb, white, 0.88) * 2.0, e3);
			alpha = mix(alpha, 0.95, e3);
		}
		alpha *= beat * smoothstep(-0.12, 0.08, p.y) * smoothstep(1.4, 1.15, abs(p.x)) * smoothstep(3.1, 2.9, p.y);
		if (front) {
			// Only up the sides: beside the trunk, and well clear of the head.
			float side = p.y < 1.0 ? smoothstep(0.3, 0.42, abs(p.x)) : smoothstep(0.52, 0.66, abs(p.x));
			alpha *= side * 0.85 * (1.0 - e2 * 0.3);
		}
	} else if (v_kind < 2.5) {
		vec2 q = v_p;
		float core = exp(-abs(q.x) * 6.0) * smoothstep(-1.0, 0.5, q.y) * smoothstep(1.0, 0.7, q.y);
		alpha = clamp(core * 1.1, 0.0, 1.0) * v_fade;
		col = mix(color.rgb, white, exp(-abs(q.x) * 12.0) * smoothstep(-0.2, 0.7, q.y)) * 1.8;
	} else {
		float r = length(v_p);
		float a = atan(v_p.y, v_p.x);
		float flick = 0.75 + 0.25 * g_noise(vec2(a * 3.0 + 10.0, t * 4.0));
		float ring = smoothstep(0.06, 0.0, abs(r - 0.78 * flick - 0.1)) * 0.8;
		float pool = exp(-r * r * 3.2);
		alpha = clamp((pool * 0.6 + ring * 0.5) * smoothstep(1.2, 0.95, r), 0.0, 0.85);
		col = mix(color.rgb, white, pool * 0.45) * 1.4;
	}
	if (alpha <= 0.003) {
		discard;
	}
	ALBEDO = col * alpha * energy;
	ALPHA = alpha;
}
