shader_type spatial;
// Actual faceted, spinning volcanic rock. The fissures stay attached to the
// stone; broad dark plates keep the silhouette readable in bright daylight.
render_mode cull_back, diffuse_burley, specular_schlick_ggx, shadows_disabled;

uniform float heat : hint_range(0.0, 2.0) = 1.0;
uniform float seed = 0.0;
uniform float fracture : hint_range(0.0, 1.0) = 0.0;
varying vec3 stone_position;

float grain(vec3 p) {
	return sin(p.x * 2.7 + sin(p.y * 3.1)) * sin(p.y * 2.3 + sin(p.z * 3.8)) * sin(p.z * 2.9 + sin(p.x * 3.3));
}

void vertex() { stone_position = VERTEX; }

void fragment() {
	vec3 p = stone_position * 2.65 + vec3(seed, seed * 0.13, 0.0);
	float plates = abs(grain(p));
	float fissure = 1.0 - smoothstep(0.017, 0.095 + fracture * 0.08, plates);
	float fine = 1.0 - smoothstep(0.005, 0.025, abs(grain(p * 2.0 + vec3(1.2))));
	float pulse = 0.86 + 0.14 * sin(TIME * 4.0 + p.y * 3.0);
	vec3 stone = mix(vec3(0.09, 0.038, 0.044), vec3(0.29, 0.105, 0.065), clamp(plates * 2.0, 0.0, 1.0));
	vec3 molten = mix(vec3(0.96, 0.17, 0.035), vec3(1.0, 0.79, 0.27), pow(fissure, 4.0));
	ALBEDO = mix(stone, molten, fissure * min(heat, 1.0) * 0.92);
	EMISSION = molten * (fissure * 1.3 + fine * 0.16) * heat * pulse;
	ROUGHNESS = 0.84 - fissure * 0.35;
	SPECULAR = 0.2;
}
