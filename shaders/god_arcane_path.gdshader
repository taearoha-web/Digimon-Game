shader_type spatial;
// A long solid body that travels a spline: the Celestial Dragon Emperor, whipping
// chains, a ribbon of staff lines. The mesh lies along +Z (0 = the head); the vertex
// stage lays it on the path behind the head, whose distance along the path follows a
// small table of (time, metres) keys.
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;
#include "god_arcane.gdshaderinc"
const int MAX_PTS = 72;
uniform vec3 pts[72];
uniform int count = 2;
// Metres between two path points (they are resampled evenly).
uniform float spacing = 2.0;
uniform float key_t[8];
uniform float key_h[8];
uniform int keys = 2;
uniform vec3 ref_up = vec3(0.0, 1.0, 0.0);
uniform vec3 ref_alt = vec3(0.0, 0.0, -1.0);
uniform float wave_amp = 0.0;
uniform float wave_len = 9.0;
uniform float wave_speed = 6.0;
uniform float girth = 1.0;
// Scale pattern on the vertices flagged by UV2.y.
uniform float scales = 0.0;
varying vec3 wn;
varying vec3 wp;
varying vec3 lp;
varying vec2 info;

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
	float lt = age - t0;
	float h = key_h[0];
	for (int i = 0; i < keys - 1; i++) {
		if (lt >= key_t[i]) {
			h = mix(key_h[i], key_h[i + 1], clamp((lt - key_t[i]) / max(0.0001, key_t[i + 1] - key_t[i]), 0.0, 1.0));
		}
	}
	float s = VERTEX.z;
	float a = h - s;
	float p = a / spacing;
	vec3 c = path_at(p);
	vec3 T = normalize(path_at(p + 0.3) - path_at(p - 0.3));
	vec3 up = normalize(mix(ref_up, ref_alt, smoothstep(0.72, 0.96, abs(T.y))));
	vec3 S = normalize(cross(up, T) + vec3(0.0001, 0.0, 0.0));
	vec3 N = cross(T, S);
	float body = smoothstep(0.4, 4.5, s);
	float ph = a * 6.2832 / wave_len;
	c += (N * sin(ph - age * wave_speed) + S * cos(ph * 0.7 - age * wave_speed * 0.8) * 0.6) * wave_amp * body;
	lp = VERTEX;
	vec3 n = normalize(S * NORMAL.x + N * NORMAL.y - T * NORMAL.z);
	VERTEX = c + (S * VERTEX.x + N * VERTEX.y) * girth;
	NORMAL = n;
	wn = normalize((MODEL_MATRIX * vec4(n, 0.0)).xyz);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	info = UV2;
}

void fragment() {
	float g = god_grain(lp * 1.7);
	float edge = fade * 1.25 - 0.12;
	if (fade < 0.995 && g > edge) discard;
	vec3 base = COLOR.rgb;
	if (scales > 0.0) {
		vec2 q = vec2(UV.x * 2.6, UV.y * 14.0);
		q.x += 0.5 * floor(q.y);
		vec2 f = fract(q) - vec2(0.38, 0.5);
		float sc = smoothstep(0.34, 0.56, length(f));
		base = mix(base * 1.16 + 0.03, base * 0.66, sc * info.y * scales);
	}
	vec3 v = normalize(CAMERA_POSITION_WORLD - wp);
	vec3 col = god_toon(base, normalize(wn), v, info.x);
	if (fade < 0.995) col = mix(col, rim_color.rgb, smoothstep(edge - 0.16, edge, g));
	ALBEDO = col;
}
