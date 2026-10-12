shader_type spatial;
render_mode diffuse_burley, specular_disabled, cull_disabled;

// Opaque, shallow storybook water: no refraction, screen copies or particles.
// The shoreline is authored geometry, so this stays inexpensive on WebGL.
uniform vec4 deep_color : source_color = vec4(0.19, 0.40, 0.43, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.46, 0.66, 0.60, 1.0);
uniform float flow_speed = 0.28;
uniform float glow = 0.0;
varying vec2 water_position;

void vertex() {
	water_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float sweep = sin(water_position.x * 2.4 + sin(water_position.y * 1.5) * 0.35 + TIME * flow_speed);
	float ripples = smoothstep(0.92, 1.0, sweep) * 0.13;
	float shoal = smoothstep(0.46, 1.0, UV.y);
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, shoal * 0.65 + ripples);
	ROUGHNESS = 0.78;
	EMISSION = deep_color.rgb * glow;
}
