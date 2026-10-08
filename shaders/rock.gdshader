shader_type spatial;
render_mode diffuse_burley, specular_disabled;
// Stylised rocks: flat stone colour with moss on the upward-facing parts.

uniform vec4 stone_color : source_color = vec4(0.42, 0.45, 0.55, 1.0);
uniform vec4 moss_color : source_color = vec4(0.36, 0.62, 0.34, 1.0);
uniform float moss_amount = 0.55;

varying vec3 inst_tint;
varying float up_facing;

void vertex() {
	inst_tint = pow(COLOR.rgb, vec3(2.2));
	up_facing = normalize(mat3(MODEL_MATRIX) * NORMAL).y;
}

void fragment() {
	float moss = smoothstep(0.55, 0.9, up_facing) * moss_amount;
	vec3 stone = stone_color.rgb * mix(vec3(1.0), inst_tint, 0.18);
	ALBEDO = mix(stone, moss_color.rgb, moss);
	ROUGHNESS = 1.0;
}
