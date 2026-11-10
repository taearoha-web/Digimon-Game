shader_type spatial;
// God-tier hero objects (GodRangedKit): solid, shaded cartoon bodies with a rim light,
// self-lit parts and optional swarm motion, so one mesh or one MultiMesh is a whole
// dragon arrow, a seraph or a volley. Vertex data: COLOR.rgb the paint, UV.x how self-lit
// the part is, UV.y its opacity (trails fade out), COLOR.a < 1 white-hot, UV2 = (wing side *
// pair, pivot height).
// INSTANCE_CUSTOM (MultiMesh): x = start delay, y = seed, z = travel scale (0: 1).
// WebGL2 / Compatibility safe: no screen or depth reads.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_always, shadows_disabled;
uniform float fade = 1.0;
uniform float age = 0.0;
// 0 still, 1 fall along the piece's own -Y and land at its origin, 2 pop out of the
// ground, 3 drift (feathers, shards in the air).
uniform int motion = 0;
uniform float flight = 0.25;
uniform float travel = 12.0;
uniform float hold = 0.7;
uniform float stick = 1.0;
uniform float accelerate = 0.0;
uniform vec3 drift = vec3(0.0, -1.0, 0.0);
uniform float sway = 0.3;
uniform float tumble = 2.0;
// tint paints the shaded parts, ember the self-lit ones, glow is the rim light.
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 ember : source_color = vec4(1.0);
uniform vec4 glow : source_color = vec4(1.0, 0.85, 0.5, 1.0);
uniform vec4 shadow : source_color = vec4(0.35, 0.22, 0.4, 1.0);
uniform float rim = 0.55;
uniform float heat = 0.0;
uniform float spread = 1.0;
uniform float flap = 0.0;
uniform float flap_rate = 3.0;
varying float v_alpha;
varying float v_emit;
varying vec3 v_wn;
varying vec3 v_local;

mat3 turn(vec3 axis, float a) {
	float c = cos(a);
	float s = sin(a);
	float k = 1.0 - c;
	return mat3(
		vec3(c + axis.x * axis.x * k, axis.y * axis.x * k + axis.z * s, axis.z * axis.x * k - axis.y * s),
		vec3(axis.x * axis.y * k - axis.z * s, c + axis.y * axis.y * k, axis.z * axis.y * k + axis.x * s),
		vec3(axis.x * axis.z * k + axis.y * s, axis.y * axis.z * k - axis.x * s, c + axis.z * axis.z * k));
}

void vertex() {
	v_local = VERTEX;
	v_emit = UV.x;
	v_alpha = UV.y;
	float lt = age - INSTANCE_CUSTOM.x;
	float seed = INSTANCE_CUSTOM.y;
	float pair = abs(UV2.x);
	if (pair > 0.5) {
		// A wing: folds down along the body and beats from its shoulder.
		float side = sign(UV2.x);
		vec3 pivot = vec3(side * 0.16, UV2.y, 0.0);
		vec3 q = VERTEX - pivot;
		float reach = length(q.xy);
		float fold = 1.0 - spread;
		float down = pair < 1.5 ? 1.25 : (pair < 2.5 ? 0.8 : 0.35);
		float a = -side * (fold * down + sin(age * flap_rate - pair * 0.8 - reach * 0.35) * flap * (0.35 + reach * 0.22));
		float c = cos(a);
		float s = sin(a);
		q.xy = vec2(q.x * c - q.y * s, q.x * s + q.y * c);
		q.z += fold * reach * 0.22;
		NORMAL.xy = vec2(NORMAL.x * c - NORMAL.y * s, NORMAL.x * s + NORMAL.y * c);
		VERTEX = q + pivot;
	}
	if (motion == 1) {
		float p = clamp(lt / max(flight, 0.001), 0.0, 1.0);
		float along = mix(p, p * p, accelerate);
		float reach = travel * (INSTANCE_CUSTOM.z > 0.001 ? INSTANCE_CUSTOM.z : 1.0);
		VERTEX.y += reach * (1.0 - along);
		float landed = lt - flight;
		// The trail dies at the landing; the body stays planted, then sinks away.
		if (UV.y < 0.995) {
			v_alpha *= 1.0 - smoothstep(0.0, 0.07, landed);
		}
		float gone = stick > 0.5 ? smoothstep(hold * 0.7, hold, landed) : smoothstep(0.0, 0.03, landed);
		VERTEX *= (1.0 - gone) * step(0.0, lt);
		v_alpha *= step(0.0, lt) * (1.0 - gone);
	} else if (motion == 2) {
		float k = clamp(lt / 0.16, 0.0, 1.0);
		float up = k * (2.3 - 1.3 * k);
		float out_k = smoothstep(hold, hold + 0.3, lt);
		VERTEX *= vec3(mix(0.5, 1.0, k), up, mix(0.5, 1.0, k)) * (1.0 - out_k) * step(0.0, lt);
		v_alpha *= step(0.0, lt);
	} else if (motion == 3) {
		float k = clamp(lt / max(hold, 0.001), 0.0, 1.0);
		float show = smoothstep(0.0, 0.12, k) * (1.0 - smoothstep(0.75, 1.0, k)) * step(0.0, lt);
		vec3 axis = normalize(vec3(sin(seed * 12.9), cos(seed * 7.3), sin(seed * 3.1 + 1.0)) + vec3(0.001));
		mat3 spin = turn(axis, tumble * lt + seed * 6.28);
		VERTEX = spin * VERTEX * show;
		NORMAL = spin * NORMAL;
		vec3 off = drift * lt + vec3(sin(lt * 2.1 + seed * 6.28), 0.0, cos(lt * 1.7 + seed * 9.4)) * sway;
		VERTEX += (vec4(off, 0.0) * MODEL_MATRIX).xyz / max(dot(MODEL_MATRIX[0].xyz, MODEL_MATRIX[0].xyz), 0.0001);
		v_alpha *= show;
	}
	v_wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 n = normalize(v_wn);
	vec3 to_eye = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	if (dot(n, to_eye) < 0.0) {
		n = -n;
	}
	float d = dot(n, normalize(vec3(-0.35, 0.8, 0.45)));
	float lit = smoothstep(-0.15, 0.1, d) * 0.62 + smoothstep(0.5, 0.62, d) * 0.38;
	vec3 base = COLOR.rgb * tint.rgb;
	vec3 col = mix(mix(base, shadow.rgb, 0.62) * 0.9, base, lit);
	float edge = pow(1.0 - clamp(dot(n, to_eye), 0.0, 1.0), 2.6);
	col += glow.rgb * edge * rim;
	// COLOR.a below 1 marks the white-hot parts of a self-lit piece (a meteor's head).
	col = mix(col, mix(vec3(1.0, 1.0, 0.96), COLOR.rgb * ember.rgb * 1.06, COLOR.a), v_emit);
	col = mix(col, vec3(1.0, 0.97, 0.86), heat);
	float grain = 0.5 + 0.5 * sin(v_local.x * 23.0 + v_local.y * 17.0) * sin(v_local.z * 19.0 - v_local.y * 13.0);
	// Tails and sheaths of fire thin out towards their silhouette instead of ending in a hard tube.
	float soft = v_alpha < 0.995 ? mix(0.25, 1.0, clamp(dot(n, to_eye) * 1.4, 0.0, 1.0)) : 1.0;
	float a = v_alpha * soft * smoothstep(0.0, 0.25, fade) * smoothstep((1.0 - fade) * 1.1 - 0.1, (1.0 - fade) * 1.1 + 0.08, grain);
	if (a < 0.03) {
		discard;
	}
	ALBEDO = col;
	ALPHA = a;
}
