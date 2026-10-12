shader_type spatial;
render_mode diffuse_burley, specular_disabled;
// A single opaque, texture-free material for all walkable terrain. UV is in
// world metres; UV2 carries distance to the trail and the soft clearing mask.
// Colour detail never displaces the floor or changes the collision surface.

uniform vec4 ground_shadow : source_color = vec4(0.34, 0.48, 0.28, 1.0);
uniform vec4 ground_sun : source_color = vec4(0.58, 0.66, 0.41, 1.0);
uniform vec4 soil_color : source_color = vec4(0.66, 0.57, 0.40, 1.0);
uniform float path_width = 2.8;
uniform float seed_offset = 0.0;
// 0 grass, 1 sand, 2 snow, 3 ash, 4 marsh, 5 weathered ground, 6 twilight.
uniform int surface_kind = 0;

float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise21(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV + vec2(seed_offset, seed_offset * 0.37);
	float broad = noise21(p * 0.085);
	float patch = noise21(p * 0.31 + broad * 1.8);
	float brush = noise21(p * 1.8);
	float grain = noise21(p * 10.5);
	float footprint = length(fwidth(UV));
	float detail_fade = 1.0 - smoothstep(0.035, 0.12, footprint);
	float brush_fade = 1.0 - smoothstep(0.22, 0.65, footprint);
	float ground_mix = clamp(broad * 0.64 + patch * 0.36, 0.0, 1.0);
	vec3 ground = mix(ground_shadow.rgb, ground_sun.rgb, ground_mix);
	// Broken, feathered edges create a worn trail instead of a painted stripe.
	float edge = (patch - 0.5) * 0.75 + (brush - 0.5) * 0.16;
	float trail = 1.0 - smoothstep(path_width * 0.40, path_width + edge, UV2.x);
	float worn = max(trail, UV2.y * 0.34);
	float earth = smoothstep(0.68, 0.92, patch) * (1.0 - trail) * 0.14;
	ground = mix(ground, soil_color.rgb, earth);
	vec3 soil = soil_color.rgb * (0.89 + patch * 0.16 + brush * 0.06);
	vec3 color = mix(ground, soil, worn * 0.89);
	float texture_light = (brush - 0.5) * 0.075 * brush_fade + (grain - 0.5) * 0.035 * detail_fade;
	if (surface_kind == 1) {
		// Wind-combed sand, broad warm dunes, tiny low-contrast grains.
		float ripple = sin(p.x * 5.0 + p.y * 1.7 + broad * 9.0);
		texture_light += ripple * 0.032 * detail_fade;
	} else if (surface_kind == 2) {
		// Cool hollows and wind-packed snow; intentionally no white emission.
		color = mix(color, ground_shadow.rgb, smoothstep(0.55, 0.9, patch) * 0.15);
		texture_light *= 0.58;
	} else if (surface_kind == 3) {
		float strata = smoothstep(0.34, 0.42, brush) - smoothstep(0.43, 0.53, brush);
		texture_light -= strata * 0.075;
	} else if (surface_kind == 4) {
		color *= 0.94 + smoothstep(0.25, 0.8, patch) * 0.10;
		texture_light *= 0.65;
	} else if (surface_kind == 5) {
		texture_light += (smoothstep(0.74, 0.9, grain) - 0.08) * 0.06 * detail_fade;
	} else if (surface_kind == 6) {
		color = mix(color, ground_sun.rgb, smoothstep(0.75, 0.94, patch) * 0.16);
	}
	ALBEDO = clamp(color * (1.0 + texture_light), vec3(0.0), vec3(0.92));
	ROUGHNESS = 1.0;
}
