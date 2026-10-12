shader_type spatial;
// A stylised flame tongue on a quad that always faces the camera around Y:
// Copper edges, an apricot middle and a honey core retain their hue when flames
// overlap. This uses alpha blending, so a crowded fire spell never turns white.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 inner : source_color = vec4(1.0, 0.85, 0.43, 1.0);
uniform vec4 mid : source_color = vec4(0.98, 0.51, 0.25, 1.0);
uniform vec4 outer : source_color = vec4(0.62, 0.19, 0.16, 1.0);
uniform float life : hint_range(0.0, 1.0) = 1.0;
uniform float speed = 2.4;
uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) { return noise(p) * 0.62 + noise(p * 2.2 + 3.7) * 0.38; }

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float y = 1.0 - UV.y;
	float t = TIME * speed + seed;
	// Two noise layers: big licks that sway, small ones that tear the edge.
	float n = fbm(vec2(UV.x * 2.4 + seed, y * 2.0 - t));
	float n2 = noise(vec2(UV.x * 7.0 - seed, y * 6.0 - t * 1.7));
	float sway = sin(t * 1.15 + y * 4.0) * 0.1;
	float x = (UV.x - 0.5) * 2.0 + ((n - 0.5) * 0.72 + sway) * y;
	// A teardrop: round, full belly near the base, a licking point at the top.
	float belly = sin(3.14159 * pow(clamp(y, 0.0, 1.0), 0.55));
	float half_width = 0.95 * belly * pow(max(1.0 - y, 0.0), 0.35);
	float shape = (half_width - abs(x)) + (n2 - 0.5) * 0.26 * (0.3 + y);
	shape *= smoothstep(0.0, 0.06, y);
	float erode = (1.0 - life) * 0.75;
	float a = smoothstep(erode, erode + 0.06, shape);
	if (a < 0.02) {
		discard;
	}
	float heat = clamp(shape * 1.35 * (1.15 - y * 0.6), 0.0, 1.0);
	vec3 col = mix(outer.rgb, mid.rgb, smoothstep(0.05, 0.3, heat));
	col = mix(col, inner.rgb, smoothstep(0.42, 0.75, heat));
	// A restrained warm stroke inside the larger silhouette, like painted fire.
	float lick = 1.0 - smoothstep(0.025, 0.09, abs(x + sin(y * 7.0 - t) * 0.1));
	col = mix(col, inner.rgb, lick * (1.0 - smoothstep(0.18, 0.72, y)) * 0.18);
	ALBEDO = col;
	ALPHA = a * clamp(life * 1.6, 0.0, 0.93);
}
