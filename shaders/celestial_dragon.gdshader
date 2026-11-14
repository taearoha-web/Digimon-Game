shader_type spatial;
// The isle's dragons, the Dragon God and the sky dragon mount (CelestialDragon): the
// same long-bodied eastern dragon as the Summoner's god skill จักรพรรดิมังกรสวรรค์ (one
// mesh along +Z, 0 = the nose, laid on a spline in the vertex stage), standing in a
// fixed pose (pts) and animated by a handful of scalars the script tweens: the head
// slides along its body (reach), rears (rise), the body ripples (wave, clock), wings
// beat (vertices whose COLOR.a < 1), a hit flash (glow). Toon lit with a rim, like
// the god skill; "prism" turns the scales to rainbow crystal (the rare dragon).
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;
uniform vec3 pts[72];
uniform int count = 2;
uniform float spacing = 0.5;
// Where the nose sits along the path (metres from pts[0]).
uniform float head = 10.0;
uniform float reach = 0.0;
uniform float rise = 0.0;
uniform float wave_amp = 0.2;
uniform float wave_len = 7.0;
uniform float wave_speed = 2.0;
// The dragon's own clock (CelestialDragonVisual: it runs faster on the move).
uniform float clock = 0.0;
// From this far along the body back to calm_end the wave dies out (a rider's saddle).
uniform float calm_from = -1.0;
uniform float calm_to = -1.0;
uniform float girth = 1.0;
uniform float flap = 0.0;
uniform float flap_rate = 3.0;
uniform float scales = 1.0;
uniform float prism = 0.0;
uniform vec4 rim_color : source_color = vec4(0.84, 1.0, 0.94, 1.0);
uniform float rim = 0.5;
uniform vec4 shadow_tint : source_color = vec4(0.48, 0.55, 0.74, 1.0);
uniform float glow = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0);
// The mouth's light while breathing (vertices flagged with UV2.x = 2).
uniform float breath = 0.0;
uniform vec4 breath_color : source_color = vec4(1.0, 0.85, 0.4, 1.0);
varying vec3 wn;
varying vec3 wp;
varying vec2 info;
varying float along;

vec3 path_at(float p) {
	float last = float(count - 1);
	float pc = clamp(p, 0.0, last);
	int i = min(int(floor(pc)), count - 2);
	float f = pc - float(i);
	vec3 p0 = pts[max(i - 1, 0)];
	vec3 p1 = pts[i];
	vec3 p2 = pts[i + 1];
	vec3 p3 = pts[min(i + 2, count - 1)];
	vec3 c = 0.5 * ((2.0 * p1) + (p2 - p0) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f + (3.0 * p1 - p0 - 3.0 * p2 + p3) * f * f * f);
	if (p < 0.0) c += (pts[0] - pts[1]) * (-p);
	if (p > last) c += (pts[count - 1] - pts[count - 2]) * (p - last);
	return c;
}

void vertex() {
	float t = clock;
	float s = VERTEX.z;
	float a = head + reach - s;
	float p = a / spacing;
	vec3 c = path_at(p);
	vec3 T = normalize(path_at(p + 0.3) - path_at(p - 0.3));
	vec3 up = normalize(mix(vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, -1.0), smoothstep(0.72, 0.96, abs(T.y))));
	vec3 S = normalize(cross(up, T) + vec3(0.0001, 0.0, 0.0));
	vec3 N = cross(T, S);
	float body = smoothstep(0.6, 4.0, s);
	if (calm_to > calm_from) body *= 1.0 - smoothstep(calm_from - 1.5, calm_from, s) * (1.0 - smoothstep(calm_to, calm_to + 1.5, s));
	float ph = a * 6.2832 / wave_len;
	c += (N * sin(ph - t * wave_speed) + S * cos(ph * 0.7 - t * wave_speed * 0.8) * 0.6) * wave_amp * body;
	// Rearing: the neck lifts (and leans back) over its first few metres.
	float neck = 1.0 - smoothstep(0.0, 6.0, s);
	c += vec3(0.0, 1.0, 0.0) * rise * neck * neck;
	vec3 local = VERTEX;
	// Wings and fins beat along the body's normal (COLOR.a below 1 is the share).
	float beat = (1.0 - COLOR.a) * flap;
	local.y += sin(t * flap_rate) * beat * abs(local.x);
	vec3 n = normalize(S * NORMAL.x + N * NORMAL.y - T * NORMAL.z);
	VERTEX = c + (S * local.x + N * local.y) * girth;
	NORMAL = n;
	wn = normalize((MODEL_MATRIX * vec4(n, 0.0)).xyz);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	info = UV2;
	along = s;
}

vec3 hue(float h) {
	return clamp(abs(fract(h + vec3(0.0, 0.6667, 0.3333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	vec3 base = COLOR.rgb;
	vec3 nn = normalize(wn);
	vec3 v = normalize(CAMERA_POSITION_WORLD - wp);
	float sc = 0.0;
	if (scales > 0.0) {
		vec2 q = vec2(UV.x * 3.4, UV.y * 16.0);
		q.x += 0.5 * floor(q.y);
		vec2 f = fract(q) - vec2(0.38, 0.5);
		sc = smoothstep(0.34, 0.56, length(f)) * info.y * scales;
		base = mix(base * 1.1 + 0.03, base * 0.76, sc);
	}
	if (prism > 0.0) {
		float band = dot(nn, vec3(0.37, 0.61, 0.7)) * 1.2 + wp.y * 0.18 + along * 0.05 + TIME * 0.12;
		vec3 rainbow = hue(band);
		float facing = abs(dot(nn, v));
		vec3 glass = mix(vec3(0.9, 0.97, 1.0), rainbow, 0.55) * (0.62 + 0.38 * facing);
		base = mix(base, glass * (1.0 - 0.3 * sc) + rainbow * pow(1.0 - facing, 2.0) * 0.5, prism);
	}
	float l = dot(nn, normalize(vec3(0.25, 0.9, 0.1) + v * 0.55)) * 0.5 + 0.5;
	vec3 col = mix(base * shadow_tint.rgb, base, smoothstep(0.42, 0.54, l));
	col += base * smoothstep(0.82, 0.92, l) * 0.2;
	float fr = pow(1.0 - abs(dot(nn, v)), 2.5);
	col = mix(col, rim_color.rgb, clamp(fr * rim, 0.0, 1.0));
	float emit = clamp(info.x, 0.0, 1.0);
	col = mix(col, base * 1.2 + 0.08, emit);
	if (info.x > 1.5) col = mix(col, breath_color.rgb * 1.4, breath);
	ALBEDO = mix(col, glow_color.rgb, glow);
}
