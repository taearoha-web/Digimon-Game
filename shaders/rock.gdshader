shader_type spatial;
render_mode diffuse_burley, specular_disabled;
// Stylised rocks: flat stone colour with moss on the upward-facing parts.

uniform vec4 stone_color : source_color = vec4(0.42, 0.45, 0.55, 1.0);
uniform vec4 moss_color : source_color = vec4(0.36, 0.62, 0.34, 1.0);
uniform float moss_amount = 0.55;

varying vec3 inst_tint;
varying float up_facing;
varying vec3 stone_position;

void vertex() {
	inst_tint = pow(COLOR.rgb, vec3(2.2));
	up_facing = normalize(mat3(MODEL_MATRIX) * NORMAL).y;
	stone_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float veins = sin(stone_position.x * 2.8 + stone_position.z * 1.3)
		* sin(stone_position.z * 3.1 - stone_position.y * 2.4);
	float moss = smoothstep(0.38, 0.88, up_facing + veins * 0.22) * moss_amount;
	vec3 stone = stone_color.rgb * mix(vec3(1.0), inst_tint, 0.18);
	stone *= 0.94 + veins * 0.075;
	// Irregular mineral bands follow the rock rather than forming a flat cap.
	float band = sin(stone_position.y * 8.0 + veins * 1.3);
	stone *= 1.0 + band * 0.022;
	ALBEDO = mix(stone, moss_color.rgb, moss);
	ROUGHNESS = 1.0;
}
