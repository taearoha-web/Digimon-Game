shader_type spatial;
// God-tier melee light and shadow (combat/god_art/_kit_melee.gd): shockwaves, fissures of
// light, slashes, coronas, beams, scorch and shadow discs. Pre-multiplied blend, so one
// mesh carries both: bright colours add their light, dark ones cover what is behind
// (a black slash with a white-hot edge is one draw). UV.x runs across a stroke (0.5 is
// its hot centre), UV.y along it (the reveal sweeps that way). UV.y below zero marks a plain
// fill that keeps its own colour (no hot core); it then runs -1 .. -2 along the stroke.
// UV2 = (delay, fall: above zero the piece travels, below zero it is a flash).
render_mode unshaded, cull_disabled, depth_draw_never, blend_premul_alpha, fog_disabled;
uniform float fade = 1.0;
uniform float age = 0.0;
uniform float t0 = 0.0;
uniform float drop = 0.0;
// A piece may also arrive from this offset (model space), e.g. a shield driven along the ground.
uniform vec3 from = vec3(0.0);
uniform float flight = 0.25;
uniform float ease = 0.0;
uniform float after = 0.0;
uniform float flash = 0.25;
uniform float sweep = 0.0;
uniform float tail = 0.0;
uniform float soft = 1.5;
uniform float core = 0.6;
uniform vec4 hot : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float gain = 1.0;
uniform float flow = 0.0;
uniform float flick = 0.0;
uniform float add = 0.5;
varying float v_lt;
varying float v_fall;

void vertex() {
	float lt = age - t0 - UV2.x;
	v_lt = lt;
	float p = clamp(lt / max(flight, 0.001), 0.0, 1.0);
	float k = mix(1.0 - p * p, pow(1.0 - p, 3.0) - 0.1 * sin(p * 3.14159) * p, ease);
	VERTEX += (vec3(0.0, drop, 0.0) + from) * UV2.y * k;
	v_fall = UV2.y;
}

void fragment() {
	if (v_lt < 0.0) {
		discard;
	}
	float prof = clamp(1.0 - abs(UV.x * 2.0 - 1.0), 0.0, 1.0);
	float along = UV.y < 0.0 ? -UV.y - 1.0 : UV.y;
	float a = pow(prof, soft) * COLOR.a;
	if (sweep > 0.0) {
		float head = v_lt / sweep;
		a *= smoothstep(0.0, 0.05, head - along);
		if (tail > 0.0) {
			a *= 1.0 - smoothstep(tail * 0.3, tail, head - along);
		}
	}
	if (after > 0.0 && v_fall > 0.001) {
		// What travels with a falling piece (its trail) goes out once it has landed.
		a *= 1.0 - smoothstep(0.0, after, v_lt - flight);
	}
	if (v_fall < -0.001) {
		// A flash (negative fall): bright at its start, gone `flash` seconds later.
		a *= 1.0 - smoothstep(0.0, flash, v_lt);
	}
	if (flow != 0.0) {
		vec2 q = vec2(UV.x * 5.0, UV.y * 9.0 - age * flow);
		float n = sin(q.x * 2.3 + sin(q.y * 1.7)) * sin(q.y * 2.1 + sin(q.x * 3.1 + age));
		a *= clamp(0.6 + 0.8 * n, 0.0, 1.4);
	}
	a *= 1.0 + flick * sin(age * 31.0 + UV.y * 17.0);
	a = clamp(a * fade, 0.0, 1.0);
	vec3 col = mix(COLOR.rgb, hot.rgb, smoothstep(core, 1.0, prof) * hot.a * step(-0.5, UV.y)) * gain;
	float light = smoothstep(0.12, 0.55, max(col.r, max(col.g, col.b))) * add;
	ALBEDO = col * a;
	ALPHA = a * (1.0 - light);
}
