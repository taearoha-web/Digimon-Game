shader_type spatial;
render_mode unshaded, cull_back;
// Floating digital cubes (MultiMesh). Bobbing and spinning happen in the
// vertex shader, so thousands of cubes cost no CPU time.

uniform vec4 base_color : source_color = vec4(0.25, 0.9, 1.0, 1.0);
uniform float bob_height = 0.35;

void vertex() {
	vec3 world_origin = MODEL_MATRIX[3].xyz;
	float phase = world_origin.x * 0.37 + world_origin.z * 0.23;
	float angle = TIME * 0.8 + phase;
	mat3 spin = mat3(vec3(cos(angle), 0.0, -sin(angle)), vec3(0.0, 1.0, 0.0), vec3(sin(angle), 0.0, cos(angle)));
	VERTEX = spin * VERTEX;
	VERTEX.y += sin(TIME * 1.3 + phase) * bob_height / max(length(MODEL_MATRIX[1].xyz), 0.001);
}

void fragment() {
	// BoxMesh packs its faces in a 3x2 UV atlas.
	vec2 e = abs(fract(UV * vec2(3.0, 2.0)) - 0.5) * 2.0;
	float edge = smoothstep(0.75, 0.95, max(e.x, e.y));
	vec3 tint = base_color.rgb * pow(COLOR.rgb, vec3(2.2));
	ALBEDO = mix(tint * 0.55, vec3(1.0), edge * 0.7) + tint * 0.3;
}
