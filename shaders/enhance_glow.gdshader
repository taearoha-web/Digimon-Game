shader_type spatial;
// The light of an enhanced piece (EnhanceFx.glow_material): an overlay pass on the
// piece's own meshes, in the piece's own colour. A soft rim where the surface turns away
// from the camera, a faint veil over the whole piece and a slow sheen sweeping up it,
// all breathing gently. Premultiplied: the glow partly replaces the colour under it
// instead of only adding to it, so a light piece in daylight never washes out to white.
// strength: +7 about 0.35, +9 0.6, +10 and up 0.75 to 0.9.
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.5, 0.8, 1.0, 1.0);
uniform float strength = 0.5;
uniform float phase = 0.0;

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.0);
	float breathe = 0.84 + 0.16 * sin(TIME * 1.6 + phase);
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// A band of light running over the whole piece (feet to head), from +7 on.
	float sweep = pow(0.5 + 0.5 * sin(world.y * 3.6 - TIME * 3.2 + phase), 10.0);
	float s = clamp(strength, 0.0, 1.0);
	float light = s * (0.18 + 1.3 * rim + 1.4 * sweep) * breathe;
	vec3 tone = mix(color.rgb, vec3(1.0), 0.18 * rim * s);
	ALBEDO = tone * light * 1.15;
	ALPHA = clamp(light * 0.7, 0.0, 0.85);
}
