shader_type spatial;
render_mode diffuse_burley, specular_disabled, cull_disabled;
// Opaque, level floors. Metre-scale wear is shared by the special arenas;
// their geometry and collision surfaces never move.
uniform int surface_kind = 0; // 0 tower stone, 1 garden sand, 2 existing PvP floor
uniform vec4 base_color : source_color = vec4(0.36, 0.34, 0.44, 1.0);
uniform vec4 accent_color : source_color = vec4(0.64, 0.58, 0.71, 1.0);
varying vec2 world_xz;

float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
float noise21(vec2 p) {
	vec2 c = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(c), hash21(c + vec2(1.0, 0.0)), f.x),
		mix(hash21(c + vec2(0.0, 1.0)), hash21(c + vec2(1.0)), f.x), f.y);
}
float band(float distance_from_origin, float radius, float width) {
	float aa = max(fwidth(distance_from_origin), 0.025);
	return 1.0 - smoothstep(width, width + aa, abs(distance_from_origin - radius));
}
void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	vec2 p = world_xz;
	float broad = noise21(p * 0.12);
	float wear = noise21(p * 0.73 + broad * 0.5);
	float grain = noise21(p * 5.2);
	float near_detail = 1.0 - smoothstep(0.10, 0.55, length(fwidth(p)));
	float radius = length(p);
	vec3 color = base_color.rgb * (0.86 + broad * 0.20 + wear * 0.045);
	if (surface_kind == 0) {
		// Unequal radial paving courses and deliberately broken narrow inlay.
		float course = floor(radius / 4.8);
		float angle = atan(p.y, p.x);
		float ring_line = band(mod(radius + 2.4, 4.8), 2.4, 0.027);
		float divisions = 16.0 + course * 4.0;
		float spoke_distance = abs(sin(angle * divisions * 0.5 + mod(course, 2.0) * 1.57)) * max(radius / divisions, 0.2);
		float joints = max(ring_line, 1.0 - smoothstep(0.018, 0.055 + fwidth(spoke_distance), spoke_distance));
		color *= 1.0 - joints * 0.15;
		float tile = hash21(vec2(course, floor(angle * divisions / 6.28318)));
		color *= 0.95 + tile * 0.10;
		float inlay = max(max(band(radius, 11.5, 0.065), band(radius, 27.0, 0.11)), band(radius, 46.5, 0.17));
		float interrupted = smoothstep(0.22, 0.44, wear);
		color = mix(color, accent_color.rgb, inlay * interrupted * 0.65);
		// A quiet six-point compass star is etched into the center stones.
		float ray = pow(abs(cos(angle * 3.0)), 14.0);
		float star = ray * smoothstep(1.8, 3.0, radius) * (1.0 - smoothstep(7.5, 9.0, radius));
		color = mix(color, accent_color.rgb, star * 0.18);
	} else if (surface_kind == 1) {
		// Bare fighting sand grows into moss and creeping plants at the margin.
		float margin = smoothstep(41.0 + broad * 7.0, 54.0, radius);
		color = mix(color, accent_color.rgb * (0.80 + wear * 0.18), margin * 0.92);
		float sweep = sin(radius * 1.8 + broad * 8.0) * 0.015 * near_detail;
		color *= 1.0 + sweep;
		// Worn fragments of the old boundary, far from the central encounter.
		float border = band(radius + wear * 0.22, 40.0, 0.045);
		color = mix(color, base_color.rgb * 0.68, border * smoothstep(0.36, 0.68, wear) * 0.35);
	}
	color *= 1.0 + (grain - 0.5) * 0.05 * near_detail;
	ALBEDO = clamp(color, vec3(0.0), vec3(0.90));
	ROUGHNESS = 0.96;
}
