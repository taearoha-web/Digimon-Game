// Shared body of melee_art (blend_mix: smears, scorch, dark rims) and
// melee_glow (blend_add: white-hot cores, light, flame). See melee_art.gdshader.
uniform vec4 primary : source_color = vec4(1.0, 0.55, 0.2, 1.0);
uniform vec4 accent : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform vec4 shade : source_color = vec4(0.3, 0.06, 0.04, 1.0);
uniform int mode = 0;
uniform float appear = 1.0;
uniform float gone = 0.0;
uniform float age = 0.0;
uniform float sweep = 1.0;
uniform float tail = 1.0;
uniform float thick = 0.6;
uniform float symmetric = 0.0;
uniform float opacity = 0.9;
uniform float pulse = 0.0;
uniform float veins = 0.0;
uniform float pattern = 0.0;
uniform float wave = 0.0;
uniform float seed = 0.0;
uniform float glow = 1.0;
uniform float narrow = 0.0;
varying vec3 local;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) { return vnoise(p) * 0.55 + vnoise(p * 2.13 + 7.1) * 0.3 + vnoise(p * 4.37 + 3.3) * 0.15; }

// Heat 0..1 -> dark rim, palette, hot core. The core only leans toward the
// accent (never full white) and stays near 1.0: stacked additive layers over a
// bright ground must not blow out.
vec3 heat_colour(float h) {
	vec3 c = mix(shade.rgb, primary.rgb, smoothstep(0.0, 0.45, h));
	c = mix(c, accent.rgb, 0.85 * smoothstep(0.72, 1.0, h));
	return c * (0.84 + 0.16 * glow * smoothstep(0.7, 1.0, h));
}

void vertex() {
	local = VERTEX;
	if (mode == 4 && wave > 0.0) {
		float w = max(VERTEX.x, 0.0);
		VERTEX.z += sin(VERTEX.x * 5.0 - age * 9.0 + VERTEX.y * 2.0) * wave * w;
		VERTEX.y += sin(VERTEX.x * 3.0 - age * 6.0) * wave * 0.3 * w;
	}
}

void fragment() {
	vec2 uv = UV;
	float heat = 0.0;
	float mask = 0.0;
	float n = fbm(uv * vec2(9.0, 3.0) + vec2(seed * 13.7, seed * 5.1));
	if (mode == 0) {
		float head = sweep;
		float rel = (head - uv.x) / max(tail, 0.001);
		float e = symmetric > 0.5 ? 1.0 - abs(uv.y * 2.0 - 1.0) : uv.y;
		float lead = 1.0 - clamp(rel, 0.0, 1.0);
		// The smear narrows and lags toward the tail; the cutting edge stays crisp.
		float w = thick * (0.45 + 0.55 * lead);
		float body = smoothstep(1.0 - w, 1.0 - w * 0.45, e) * smoothstep(1.0, 0.965, e);
		float streak = 0.6 + 0.4 * vnoise(vec2(uv.x * 30.0 - age * 3.0, e * 5.0 + seed * 9.0));
		float along = smoothstep(0.0, 0.025, head - uv.x) * (1.0 - smoothstep(0.75, 1.0, rel));
		mask = body * along * mix(streak, 1.0, lead) * (0.45 + 0.55 * lead);
		mask *= smoothstep(0.0, 0.05, uv.x) * smoothstep(1.0, 0.97, uv.x);
		float edge = smoothstep(1.0 - w * 0.55, 0.97, e);
		heat = clamp(0.18 + 0.82 * pow(lead, 2.2) * (0.3 + 0.7 * edge) + 0.12 * edge, 0.0, 1.0);
	} else if (mode == 1) {
		float s = 1.0 - abs(uv.x * 2.0 - 1.0);
		float behind = sweep - uv.y;
		float front = exp(-max(behind, 0.0) * 9.0);
		float ember = 0.65 + 0.35 * vnoise(vec2(uv.y * 40.0 + seed * 3.0, age * 3.0));
		heat = clamp(front * 0.85 + (0.42 + 0.25 * ember) * pow(s, 1.5) * (1.0 - 0.55 * gone), 0.0, 1.0);
		mask = smoothstep(0.0, 0.3, s) * smoothstep(0.0, 0.02, behind) * smoothstep(1.0, 0.85, uv.y);
		mask *= 0.6 + 0.4 * smoothstep(0.0, 0.5, s * ember);
		mask *= smoothstep(narrow, narrow + 0.3, s);
		heat = mix(heat, clamp(heat + 0.35 * front + 0.2, 0.0, 1.0), step(0.01, narrow));
	} else if (mode == 2) {
		float r = uv.y;
		float lit = clamp((sweep - COLOR.r) * 4.0, 0.0, 1.0);
		float rim = smoothstep(0.78, 0.93, r) * smoothstep(1.0, 0.95, r);
		float ripple = pow(max(0.0, sin(length(local.xy) * 7.0 - age * 11.0)), 6.0) * exp(-age * 1.8);
		float shimmer = pow(max(0.0, sin((local.x + local.y) * 3.0 - age * 6.0 + COLOR.r * 6.0)), 10.0);
		heat = clamp(rim * 0.95 + ripple * 0.6 + shimmer * 0.35 + (1.0 - lit) * rim * 0.4, 0.0, 1.0);
		mask = lit * (rim + 0.3 + 0.15 * n + ripple * 0.35 + shimmer * 0.25);
		heat = mix(heat, 1.0, (1.0 - lit) * step(0.01, lit));
	} else if (mode == 3) {
		float h = uv.y;
		float tongues = fbm(vec2(uv.x * 9.0 + seed * 3.0, h * 2.6 - age * 2.6)) + 0.15 * sin(uv.x * 6.2832 * 4.0 + age * 3.0);
		float beat = pulse;
		// Flame tongues: solid only near the ground, licking up in thin peaks.
		float m = tongues * 1.3 - 0.2 - h * (0.8 - 0.3 * beat);
		mask = smoothstep(-0.05, 0.3, m) * smoothstep(0.0, 0.1, h) * (0.6 + 0.4 * beat);
		heat = clamp(m * 1.8 + 0.2 + beat * 0.3, 0.0, 1.0);
		if (veins > 0.0) {
			float v = abs(vnoise(vec2(uv.x * 14.0 + seed, h * 5.0 - age * 0.6)) - 0.5);
			float line = 1.0 - smoothstep(0.0, 0.035 + 0.025 * beat, v);
			mask = max(mask * 0.4, line * smoothstep(0.0, 0.1, h) * smoothstep(1.0, 0.55, h) * veins * (0.45 + 0.55 * beat));
			heat = max(heat, line * (0.55 + 0.45 * beat));
		}
	} else if (mode == 4) {
		float core = clamp(COLOR.r, 0.0, 1.0);
		float along = uv.x;
		float scales = 0.0;
		if (pattern > 0.0) {
			// Overlapping scale arcs: a thin bright rim on each scale, nothing more.
			vec2 g = vec2(local.x * 16.0, local.y * 16.0 + floor(local.x * 16.0) * 0.5);
			float r = length(fract(g) - vec2(0.5, 0.0));
			scales = smoothstep(0.42, 0.5, r) * smoothstep(0.62, 0.5, r) * pattern;
		}
		float flow = pow(max(0.0, sin(along * 18.0 - age * 10.0)), 8.0) * 0.25;
		heat = clamp(0.22 + core * 0.62 + flow + scales * 0.25, 0.0, 1.0);
		mask = 0.55 + 0.45 * core;
		mask *= smoothstep(0.0, 0.12, sweep - (1.0 - along) * tail);
	} else {
		float e = 1.0 - abs(uv.y * 2.0 - 1.0);
		float turb = 0.6 + 0.4 * vnoise(vec2(uv.x * 30.0 + seed * 7.0, age * 2.5));
		mask = smoothstep(0.0, 0.45, e) * turb;
		heat = clamp(pow(e, 2.0) * (0.55 + 0.45 * turb), 0.0, 1.0);
	}
	vec3 colour = heat_colour(heat);
	if (mode == 3 && veins > 0.0) {
		colour += primary.rgb * pulse * 0.18;
	}
	// The noise dissolve: thin, low-heat parts go first, the core last.
	float d = fbm(local.xz * 2.3 + local.y * 1.7 + seed * 11.0) * 0.8 + heat * 0.25;
	float keep = smoothstep(gone * 1.12 - 0.1, gone * 1.12 + 0.02, d);
	ALBEDO = colour;
	ALPHA = clamp(mask, 0.0, 1.0) * opacity * appear * keep;
}
