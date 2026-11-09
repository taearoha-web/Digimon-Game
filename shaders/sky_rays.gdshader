shader_type spatial;
// Light shafts (SkyArt): a unit quad per instance stretched along a slanted axis and
// turned about it to face the camera. Additive, soft at the sides, fading in from the
// top and out before the ground, and fading away as the camera comes near, so a shaft
// never fills the screen. Instance COLOR: tint, alpha = strength.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, world_vertex_coords;

uniform vec3 axis = vec3(0.3, -1.0, 0.2);
varying float v_fade;
varying float v_phase;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float width = length(MODEL_MATRIX[0].xyz);
	float len = length(MODEL_MATRIX[1].xyz);
	vec3 ax = normalize(axis);
	vec3 to_cam = CAMERA_POSITION_WORLD - origin;
	vec3 side = normalize(cross(ax, normalize(to_cam)));
	// world_vertex_coords: VERTEX arrives already moved by MODEL_MATRIX; rebuild it
	// from the quad's own corner (UV) instead.
	vec2 corner = vec2(UV.x - 0.5, 0.5 - UV.y);
	VERTEX = origin + side * corner.x * width - ax * corner.y * len;
	v_fade = smoothstep(8.0, 22.0, length(to_cam));
	v_phase = origin.x * 0.37 + origin.z * 0.23;
}

void fragment() {
	float across = sin(UV.x * 3.14159);
	across *= across;
	float along = smoothstep(0.0, 0.3, UV.y) * (1.0 - smoothstep(0.6, 1.0, UV.y));
	float pulse = 0.8 + 0.2 * sin(TIME * 0.5 + v_phase);
	ALBEDO = COLOR.rgb * (COLOR.a * across * along * pulse * v_fade);
}
