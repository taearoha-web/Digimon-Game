shader_type spatial;
// The Legendary Guild Wings (LegendWingArt): a star wing model re-skinned in gold whose
// surface shifts through a prismatic sheen with the view angle and the time, a warm rim
// and slow twinkling sparks. Cheap enough for phones: no textures, one sin per channel.
render_mode cull_disabled, specular_disabled, diffuse_lambert;
uniform vec4 gold : source_color = vec4(0.98, 0.78, 0.30, 1.0);
uniform vec4 deep : source_color = vec4(0.62, 0.38, 0.10, 1.0);
uniform vec4 rim : source_color = vec4(1.0, 0.95, 0.78, 1.0);
uniform float prism = 0.55;
uniform float sparkle = 0.8;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

vec3 rainbow(float h) {
	return 0.5 + 0.5 * cos(6.2832 * (h + vec3(0.0, 0.33, 0.67)));
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float edge = pow(1.0 - facing, 2.5);
	// Gold deepening away from the eye, a prismatic band sliding over it.
	vec3 base = mix(deep.rgb, gold.rgb, 0.35 + 0.65 * facing);
	float band = fract(UV.x * 1.5 + UV.y * 0.7 + facing * 0.8 + TIME * 0.08);
	vec3 sheen = rainbow(band);
	base = mix(base, base * (0.6 + 0.8 * sheen), prism * (0.25 + 0.75 * edge));
	// Twinkling sparks on a fixed grid, each with its own phase.
	vec2 cell = UV * 26.0;
	vec2 id = floor(cell);
	float h = hash(id);
	float d = length(fract(cell) - 0.5 - (vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5) * 0.6);
	float twinkle = pow(max(0.5 + 0.5 * sin(TIME * 1.7 + h * 50.0), 0.0), 6.0);
	float spark = step(0.9, h) * smoothstep(0.12, 0.0, d) * twinkle * sparkle;
	ALBEDO = base + rim.rgb * edge * 0.45 + spark * rim.rgb;
	EMISSION = base * (0.18 + 0.22 * edge) + rim.rgb * edge * 0.35 + spark * rim.rgb * 1.5;
	ROUGHNESS = 0.35;
	METALLIC = 0.6;
}
