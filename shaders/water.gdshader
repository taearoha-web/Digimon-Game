shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, specular_disabled;
// Stylised river: flowing stripes, soft foam at the edges (UV.x across,
// UV.y along the river) and a light digital shimmer.

uniform vec4 deep_color : source_color = vec4(0.12, 0.45, 0.78, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.35, 0.82, 0.95, 1.0);
uniform vec4 foam_color : source_color = vec4(0.92, 0.98, 1.0, 1.0);
uniform float flow_speed = 0.25;
uniform float alpha = 0.82;

void vertex() {
	VERTEX.y += sin(VERTEX.x * 0.6 + TIME * 1.4) * 0.03 + cos(VERTEX.z * 0.5 + TIME * 1.1) * 0.03;
}

void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, smoothstep(0.2, 1.0, across));
	float stripes = sin(UV.y * 60.0 - TIME * flow_speed * 40.0 + sin(UV.x * 9.0) * 1.5);
	col += foam_color.rgb * smoothstep(0.85, 1.0, stripes) * 0.18;
	float edge = smoothstep(0.78, 0.98, across);
	col = mix(col, foam_color.rgb, edge * 0.7);
	float grid = step(0.97, fract(UV.y * 40.0 + TIME * 0.2)) * 0.08;
	col += vec3(0.4, 0.95, 1.0) * grid;
	ALBEDO = col;
	ROUGHNESS = 0.2;
	ALPHA = mix(alpha, 1.0, edge * 0.5);
}
