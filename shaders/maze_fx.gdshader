shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// The light of เขาวงกตหนึ่งในใต้หล้า (MazeArena), all additive and unlit, moved only here
// (no particles, no lights, no per-frame scripts):
//   mode 0  beams and veils: an open tube, UV.y 0 at its foot, fading up and at its rims,
//           a slow shimmer climbing it (the landmarks' sky beams, the shrines' veils)
//   mode 1  motes: camera-facing dots of a MultiMesh over the floor; INSTANCE_CUSTOM.x
//           0 fireflies (wander and blink), 1 embers (rise and fade), INSTANCE_CUSTOM.y
//           the phase
//   mode 2  sky lanterns: camera-facing warm lanterns that bob and sway high overhead
//   mode 3  a shrine's veil: an open tube brightest at its rims (a dome of light seen
//           through), a bright band at its foot, rings of light rising up it
uniform int mode = 0;
uniform float strength = 1.0;
varying float fade;
varying float rim;

void vertex() {
	fade = 1.0;
	// Unshaded materials get no NORMAL in fragment(): the tube's rim is worked out here.
	vec3 vn = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 vp = normalize(-(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	rim = abs(dot(vn, vp));
	// POSITION is written below for the camera-facing modes, so it must be written always.
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (mode == 1 || mode == 2) {
		vec3 c = MODEL_MATRIX[3].xyz;
		float s = length(MODEL_MATRIX[0].xyz);
		float ph = INSTANCE_CUSTOM.y * 6.2831853;
		if (mode == 1) {
			if (INSTANCE_CUSTOM.x > 0.5) {
				float t = fract(TIME * 0.16 + INSTANCE_CUSTOM.y);
				c.y += t * 3.2;
				c.x += sin(TIME * 1.3 + ph) * 0.35;
				fade = smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.55, 1.0, t));
			} else {
				c += vec3(sin(TIME * 0.43 + ph) * 1.1, sin(TIME * 0.71 + ph * 1.7) * 0.45, cos(TIME * 0.37 + ph * 0.6) * 1.1);
				fade = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(TIME * 2.1 + ph * 3.0), 2.0);
			}
		} else {
			c.y += sin(TIME * 0.5 + ph) * 1.2;
			c.x += sin(TIME * 0.23 + ph * 2.0) * 0.8;
			fade = 0.85 + 0.15 * sin(TIME * 3.7 + ph * 5.0);
		}
		vec3 right = INV_VIEW_MATRIX[0].xyz;
		vec3 up = INV_VIEW_MATRIX[1].xyz;
		vec3 wp = c + (right * VERTEX.x + up * VERTEX.y) * s;
		POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
	}
}

void fragment() {
	vec3 col = COLOR.rgb;
	float a = COLOR.a * strength;
	if (mode == 0) {
		float up = 1.0 - UV.y;
		float shimmer = 0.75 + 0.25 * sin(UV.y * 18.0 - TIME * 2.2 + UV.x * 6.2831853 * 2.0);
		a *= pow(up, 1.6) * smoothstep(0.0, 0.08, UV.y + 0.02) * pow(rim, 1.2) * shimmer;
	} else if (mode == 1) {
		float r = length(UV - 0.5) * 2.0;
		a *= (1.0 - smoothstep(0.0, 1.0, r)) * (1.0 + 2.0 * (1.0 - smoothstep(0.0, 0.25, r))) * fade;
	} else if (mode == 3) {
		float up = 1.0 - UV.y;
		float edge = 0.3 + 0.7 * pow(1.0 - rim, 2.0);
		float rings = smoothstep(0.75, 1.0, sin(UV.y * 9.0 - TIME * 1.6) * 0.5 + 0.5);
		float foot = 1.0 - smoothstep(0.0, 0.12, UV.y);
		a *= pow(up, 1.3) * (edge + rings * 0.5) + foot * 0.8;
	} else {
		// A paper lantern: a warm oval, brighter at its foot, in a soft halo.
		vec2 p = (UV - 0.5) * 2.0;
		float body = 1.0 - smoothstep(0.32, 0.4, length(p * vec2(1.55, 1.0)));
		float halo = 1.0 - smoothstep(0.0, 1.0, length(p));
		float foot = smoothstep(-0.3, 0.4, p.y);
		a *= (body * (0.75 + foot * 0.6) + halo * halo * 0.35) * fade;
	}
	ALBEDO = col * a;
}
