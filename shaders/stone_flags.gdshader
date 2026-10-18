shader_type spatial;
render_mode diffuse_toon, specular_disabled;
// Flagstones for the village plaza: offset rows of warm stone slabs with dark
// mortar, a few darker slabs and a worn centre. UV is in world metres.

uniform vec4 stone_color : source_color = vec4(0.80, 0.75, 0.66, 1.0);
uniform vec4 mortar_color : source_color = vec4(0.52, 0.48, 0.42, 1.0);
uniform vec4 moss_color : source_color = vec4(0.55, 0.62, 0.40, 1.0);
uniform float slab = 1.3;

float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void fragment() {
	vec2 p = UV / slab;
	float row = floor(p.y);
	p.x += fract(row * 0.5);
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float h = hash21(cell);
	float gap = 0.07 + h * 0.03;
	float mortar = 1.0 - smoothstep(gap, gap + 0.04, min(min(f.x, 1.0 - f.x) * 0.62, min(f.y, 1.0 - f.y)));
	vec3 slab_color = stone_color.rgb * (0.84 + h * 0.3);
	slab_color = mix(slab_color, slab_color * 0.78, step(0.86, hash21(cell + 9.0)));
	slab_color = mix(slab_color, moss_color.rgb, step(0.9, hash21(cell + 3.0)) * 0.5);
	vec3 color = mix(slab_color, mortar_color.rgb, mortar);
	float chip = hash21(floor(UV * 7.0));
	ALBEDO = color * (0.96 + chip * 0.08);
	ROUGHNESS = 1.0;
}
