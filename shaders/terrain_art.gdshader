shader_type spatial;
render_mode diffuse_burley, specular_disabled;
// A single opaque, texture-free material for all walkable terrain. UV is in
// world metres; UV2 carries distance to the trail and the soft clearing mask.
// Colour detail never displaces the floor or changes the collision surface.

uniform vec4 ground_shadow : source_color = vec4(0.34, 0.48, 0.28, 1.0);
uniform vec4 ground_sun : source_color = vec4(0.58, 0.66, 0.41, 1.0);
uniform vec4 soil_color : source_color = vec4(0.66, 0.57, 0.40, 1.0);
// A third, low-frequency colour: clover and flower drifts, moss, ash beds,
// blue snow hollows, dark marsh ground. Its glow (0..1) lights lava cracks,
// rune circles and sparkle in the themes that use them.
uniform vec4 accent_color : source_color = vec4(0.52, 0.62, 0.30, 1.0);
uniform float accent_amount = 0.45;
uniform float accent_glow = 0.0;
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

// Thin bright or dark lines along the ridges of a noise field (cracks, veins).
float veins(vec2 p, float width) {
	float n = noise21(p) + noise21(p * 2.3 + 11.0) * 0.35;
	return 1.0 - smoothstep(0.0, width, abs(fract(n * 1.6) - 0.5));
}

void fragment() {
	vec2 p = UV + vec2(seed_offset, seed_offset * 0.37);
	float broad = noise21(p * 0.085);
	float patch = noise21(p * 0.31 + broad * 1.8);
	float brush = noise21(p * 1.8);
	float grain = noise21(p * 10.5);
	float drift = noise21(p * 0.042 + 7.3);
	float footprint = length(fwidth(UV));
	float detail_fade = 1.0 - smoothstep(0.035, 0.12, footprint);
	float brush_fade = 1.0 - smoothstep(0.22, 0.65, footprint);
	float ground_mix = clamp(broad * 0.64 + patch * 0.36, 0.0, 1.0);
	// Wider tonal range: the two input colours now read as sun and shade beds.
	ground_mix = smoothstep(0.18, 0.82, ground_mix);
	vec3 ground = mix(ground_shadow.rgb, ground_sun.rgb, ground_mix);
	// Low-frequency accent drifts, broken up by the brush so they feather out.
	float accent_mask = smoothstep(0.50, 0.72, drift + (patch - 0.5) * 0.22 + (brush - 0.5) * 0.08);
	ground = mix(ground, accent_color.rgb, accent_mask * accent_amount);
	// Broken, feathered edges create a worn trail instead of a painted stripe.
	float edge = (patch - 0.5) * 0.75 + (brush - 0.5) * 0.16;
	float trail = 1.0 - smoothstep(path_width * 0.40, path_width + edge, UV2.x);
	float worn = max(trail, UV2.y * 0.34);
	float earth = smoothstep(0.68, 0.92, patch) * (1.0 - trail) * 0.14;
	ground = mix(ground, soil_color.rgb, earth);
	vec3 soil = soil_color.rgb * (0.89 + patch * 0.16 + brush * 0.06);
	vec3 color = mix(ground, soil, worn * 0.89);
	float texture_light = (brush - 0.5) * 0.14 * brush_fade + (grain - 0.5) * 0.06 * detail_fade;
	vec3 glow = vec3(0.0);
	float open = (1.0 - worn) * detail_fade;
	if (surface_kind == 0) {
		// Clover speckles in the accent drifts and a scatter of tiny blossoms.
		float clover = smoothstep(0.80, 0.90, noise21(p * 5.5 + 3.0)) * accent_mask;
		color = mix(color, accent_color.rgb * 1.18, clover * 0.55 * open);
		vec2 cell = floor(p * 2.6);
		float bloom = step(0.965, hash21(cell + 17.0)) * (1.0 - smoothstep(0.08, 0.16, length(fract(p * 2.6) - 0.5)));
		vec3 bloom_color = mix(vec3(0.95, 0.78, 0.82), vec3(0.98, 0.92, 0.62), hash21(cell + 5.0));
		color = mix(color, bloom_color, bloom * open * 0.9);
	} else if (surface_kind == 1) {
		// Wind-combed sand: two ripple frequencies bent by the dunes, each
		// ripple with a lit crest and a shaded trough.
		float ripple = sin(p.x * 3.2 + p.y * 1.1 + broad * 11.0) * 0.6 + sin(p.x * 7.5 + p.y * 2.6 + patch * 5.0) * 0.4;
		texture_light += ripple * 0.07 * brush_fade;
		color = mix(color, ground_shadow.rgb, smoothstep(0.3, 0.9, -ripple) * 0.12 * brush_fade);
	} else if (surface_kind == 2) {
		// Blue hollows in wind-packed snow and a cold twinkle on the crust.
		float hollow = smoothstep(0.45, 0.85, patch * 0.6 + drift * 0.4);
		color = mix(color, accent_color.rgb, hollow * 0.42);
		texture_light *= 0.5;
		vec2 cell = floor(p * 9.0);
		float twinkle = step(0.93, hash21(cell + 2.0)) * (0.5 + 0.5 * sin(TIME * 2.5 + hash21(cell) * 6.28));
		float spark = twinkle * (1.0 - smoothstep(0.05, 0.14, length(fract(p * 9.0) - 0.5)));
		color += vec3(0.5, 0.56, 0.6) * spark * open;
		glow += vec3(0.6, 0.7, 0.8) * spark * open * accent_glow;
	} else if (surface_kind == 3) {
		// Ash beds over cooled crust; in a few hot patches the crust splits into
		// glowing lava cracks that breathe.
		float hot = smoothstep(0.58, 0.72, drift * 0.75 + patch * 0.25);
		float crack = veins(p * 0.32, 0.03) * hot * (1.0 - trail);
		float strata = smoothstep(0.34, 0.42, brush) - smoothstep(0.43, 0.53, brush);
		texture_light -= strata * 0.09;
		color = mix(color, color * 0.6, hot * 0.35);
		float pulse = 0.7 + 0.3 * sin(TIME * 1.3 + broad * 9.0);
		glow += accent_color.rgb * crack * pulse * (0.5 + accent_glow * 0.7);
		color = mix(color, accent_color.rgb, crack * 0.7);
	} else if (surface_kind == 4) {
		// Still puddles between tussocks, each with a pale wet rim.
		float wet = noise21(p * 0.16 + 4.0) * 0.7 + patch * 0.3;
		float puddle = smoothstep(0.60, 0.66, wet);
		float rim = smoothstep(0.55, 0.60, wet) - puddle;
		color *= 0.94 + smoothstep(0.25, 0.8, patch) * 0.10;
		color = mix(color, accent_color.rgb, puddle * 0.85 * (1.0 - trail));
		color = mix(color, color * 1.25, rim * 0.6);
		float shine = sin(p.x * 2.0 + p.y * 1.4 + TIME * 0.8) * 0.5 + 0.5;
		color += vec3(0.08) * puddle * shine * open;
		texture_light *= 0.65 * (1.0 - puddle);
	} else if (surface_kind == 5) {
		// Cracked, weathered ground: dark fissures and flagstone-like cells.
		float crack = veins(p * 0.9, 0.035);
		color = mix(color, color * 0.62, crack * 0.75 * open);
		texture_light += (smoothstep(0.74, 0.9, grain) - 0.08) * 0.06 * detail_fade;
	} else if (surface_kind == 6) {
		// Twilight ground: pale patches and faint rune rings that glow.
		color = mix(color, ground_sun.rgb, smoothstep(0.75, 0.94, patch) * 0.16);
		// One rune circle in about a third of the 7 m cells: an outer ring, an
		// inner ring and four marks, each fading in and out on its own beat.
		vec2 cell = floor(p / 7.0);
		float seed = hash21(cell + 31.0);
		vec2 local = (fract(p / 7.0) - 0.5) * 7.0 + (vec2(hash21(cell + 2.0), hash21(cell + 4.0)) - 0.5) * 1.6;
		float dist = length(local);
		float rune = 1.0 - smoothstep(0.0, 0.14, abs(dist - 2.0));
		rune += 1.0 - smoothstep(0.0, 0.1, abs(dist - 1.2));
		rune += step(0.78, abs(sin(atan(local.y, local.x) * 2.0))) * (1.0 - smoothstep(0.0, 0.12, abs(dist - 1.6)));
		rune *= step(0.62, seed) * (1.0 - trail) * open;
		float pulse = 0.55 + 0.45 * sin(TIME * 1.1 + seed * 20.0);
		color = mix(color, accent_color.rgb, rune * 0.6);
		glow += accent_color.rgb * rune * pulse * (0.6 + accent_glow * 0.9);
	}
	ALBEDO = clamp(color * (1.0 + texture_light), vec3(0.0), vec3(0.92));
	EMISSION = glow;
	ROUGHNESS = 1.0;
}
