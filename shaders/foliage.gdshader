shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
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
uniform float canopy_light = 0.76;

varying vec3 inst_tint;
varying float rel_height;
varying vec3 foliage_position;
varying float up_facing;

void vertex() {
	inst_tint = pow(COLOR.rgb, vec3(2.2));
	rel_height = clamp(VERTEX.y / height_ref, 0.0, 1.0);
	vec3 origin = MODEL_MATRIX[3].xyz;
	foliage_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	up_facing = normalize(mat3(MODEL_MATRIX) * NORMAL).y;
	float gust = sin(TIME * 0.42 + origin.x * 0.07 + origin.z * 0.11);
	float wave = sin(TIME * wind_speed + origin.x * 0.31 + origin.z * 0.27 + VERTEX.y) * (0.72 + gust * 0.28);
	VERTEX.x += wave * sway * rel_height * rel_height;
	VERTEX.z += cos(TIME * wind_speed * 0.8 + origin.z * 0.29) * sway * 0.6 * rel_height * rel_height;
}

void fragment() {
	float crown = smoothstep(0.08, 0.95, rel_height);
	vec3 gradient = mix(base_color.rgb, top_color.rgb, crown * canopy_light);
	// Broad painterly lobes and cool leaf undersides give imported low-poly
	// crowns volume without a texture or a second draw call.
	float leaves = sin(foliage_position.x * 2.1 + foliage_position.z * 0.7)
		* sin(foliage_position.z * 1.7 + foliage_position.y * 2.2);
	gradient *= 0.95 + leaves * 0.045 + max(up_facing, 0.0) * 0.07;
	// Flower instance colours stay pastel instead of blowing out above 1.0.
	ALBEDO = mix(gradient, gradient * inst_tint, tint_strength);
	ROUGHNESS = 1.0;
}
