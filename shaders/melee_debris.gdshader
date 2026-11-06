shader_type spatial;
// MeleeArt debris (rock chips, earth clods, steel shards) in one MultiMesh.
// Toon-lit stone; instance COLOR.rgb is the stone tint and COLOR.a the heat:
// freshly torn chips glow at the cracks and cool to plain rock as they fall.
render_mode cull_back, depth_draw_opaque, shadows_disabled;
uniform vec4 glow_colour : source_color = vec4(1.0, 0.55, 0.2, 1.0);
varying vec3 local;

void vertex() { local = VERTEX; }

void fragment() {
	float heat = clamp(COLOR.a, 0.0, 1.0);
	float vein = pow(max(0.0, sin(local.x * 23.0 + local.y * 17.0) * sin(local.z * 19.0 - local.y * 11.0)), 3.0);
	ALBEDO = COLOR.rgb;
	EMISSION = glow_colour.rgb * heat * (0.25 + vein * 1.2);
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}

void light() {
	float l = smoothstep(0.0, 0.08, dot(NORMAL, LIGHT));
	DIFFUSE_LIGHT += (0.5 + 0.5 * l) * LIGHT_COLOR * ATTENUATION;
}
