shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;
// Stylised leaves / bushes / flowers for the imported nature models.
// Vertical colour gradient, gentle wind sway, optional per-instance tint
// (MultiMesh colours). The pack ships without textures, so colour comes from here.

uniform vec4 base_color : source_color = vec4(0.22, 0.52, 0.28, 1.0);
uniform vec4 top_color : source_color = vec4(0.55, 0.82, 0.36, 1.0);
uniform float height_ref = 5.0;
uniform float sway = 0.05;
uniform float wind_speed = 1.4;
// 0 = ignore the instance colour, 1 = use it as the albedo.
uniform float tint_strength = 0.2;

varying vec3 inst_tint;
varying float rel_height;

void vertex() {
	inst_tint = pow(COLOR.rgb, vec3(2.2));
	rel_height = clamp(VERTEX.y / height_ref, 0.0, 1.0);
	vec3 origin = MODEL_MATRIX[3].xyz;
	float wave = sin(TIME * wind_speed + origin.x * 0.31 + origin.z * 0.27 + VERTEX.y);
	VERTEX.x += wave * sway * rel_height * rel_height;
	VERTEX.z += cos(TIME * wind_speed * 0.8 + origin.z * 0.29) * sway * 0.6 * rel_height * rel_height;
}

void fragment() {
	vec3 gradient = mix(base_color.rgb, top_color.rgb, rel_height);
	ALBEDO = mix(gradient, gradient * inst_tint * 1.6, tint_strength);
	ROUGHNESS = 1.0;
}
