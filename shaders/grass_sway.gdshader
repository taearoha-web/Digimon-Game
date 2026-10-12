shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
// Wind-swayed grass tufts (MultiMesh with per-instance colour).

uniform vec4 tip_color : source_color = vec4(0.62, 0.92, 0.45, 1.0);
uniform float sway = 0.075;

varying float meadow_wave;

void vertex() {
	vec3 world_origin = MODEL_MATRIX[3].xyz;
	float h = clamp(VERTEX.y, 0.0, 1.0);
	float wave = sin(TIME * 1.8 + world_origin.x * 0.35 + world_origin.z * 0.27);
	meadow_wave = sin(world_origin.x * 0.18 + world_origin.z * 0.13 + TIME * 0.6);
	VERTEX.x += wave * sway * h * h;
	VERTEX.z += cos(TIME * 1.3 + world_origin.z * 0.31) * sway * 0.6 * h * h;
}

void fragment() {
	float h = clamp(UV.y, 0.0, 1.0);
	// Instance colours are sRGB; convert to linear like source_color uniforms.
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	// Slightly darker roots anchor each blade to the ground; luminous tips
	// remain matte. Whole patches share the same slow breeze.
	ALBEDO = mix(mix(tip_color.rgb, base, 0.25), base * 0.84, h);
	ALBEDO *= 0.98 + meadow_wave * 0.025;
	ROUGHNESS = 1.0;
}
