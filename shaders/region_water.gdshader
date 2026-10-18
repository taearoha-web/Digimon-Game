shader_type spatial;
render_mode diffuse_burley, specular_disabled, cull_disabled;

// Opaque, shallow storybook water: no refraction, screen copies or particles.
// The shoreline is authored geometry, so this stays inexpensive on WebGL.
// UV.y runs 0 in the middle to 1 at the shore (ovals) or across a stream.
uniform vec4 deep_color : source_color = vec4(0.19, 0.40, 0.43, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.46, 0.66, 0.60, 1.0);
uniform float flow_speed = 0.28;
uniform float glow = 0.0;
varying vec2 water_position;

void vertex() {
	water_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float t = TIME * flow_speed;
	// Two ripple octaves crossing at an angle, each bent by the other.
	float a = sin(water_position.x * 2.4 + sin(water_position.y * 1.5 + t * 0.7) * 0.35 + t);
	float b = sin(water_position.x * 0.9 - water_position.y * 1.7 + a * 0.4 - t * 1.3);
	float ripples = smoothstep(0.90, 1.0, a) * 0.13 + smoothstep(0.86, 1.0, b) * 0.09;
	float shoal = smoothstep(0.46, 1.0, UV.y);
	// Foam: a bright, broken band that breathes along the shore.
	float foam_edge = 0.86 + sin(water_position.x * 3.1 + water_position.y * 2.3 + t * 1.6) * 0.04;
	float foam = smoothstep(foam_edge, foam_edge + 0.05, UV.y) * (0.55 + 0.45 * sin(water_position.x * 5.0 - t * 2.2 + water_position.y * 4.0));
	// Flat water brightens toward the viewer, like a sky reflection.
	float facing = clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0);
	float sheen = (1.0 - facing) * 0.22;
	vec3 color = mix(deep_color.rgb, shallow_color.rgb, shoal * 0.65 + ripples + sheen);
	color = mix(color, vec3(0.96, 0.98, 0.97), foam * 0.7);
	// Sparkle: a few sun glints that slide with the ripples.
	float glint = pow(max(sin(water_position.x * 6.3 + t * 2.0) * sin(water_position.y * 5.1 - t * 1.4), 0.0), 18.0);
	ALBEDO = clamp(color + vec3(glint * 0.35), vec3(0.0), vec3(1.0));
	ROUGHNESS = 0.78;
	EMISSION = deep_color.rgb * glow + vec3(glint) * glow * 1.5;
}
