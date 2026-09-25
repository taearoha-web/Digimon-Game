shader_type spatial;
render_mode diffuse_toon, specular_disabled;
// Softly pulsing crystal / bioluminescent material for MultiMesh props
// (Data Forest canopies, mushroom caps). Colour comes from the instance.

uniform float glow = 0.55;
uniform float pulse_speed = 1.1;
uniform float facet_strength = 0.18;

void fragment() {
	// Instance colours are sRGB; convert to linear like source_color uniforms.
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	vec3 world_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float pulse = 0.75 + 0.25 * sin(TIME * pulse_speed + world_origin.x * 0.3 + world_origin.z * 0.21);
	// Flat-ish facets: brighten faces that point up / towards the camera.
	float facet = clamp(dot(NORMAL, vec3(0.0, 0.0, 1.0)), 0.0, 1.0) * facet_strength;
	ALBEDO = base * (1.0 + facet);
	EMISSION = base * glow * pulse;
}
