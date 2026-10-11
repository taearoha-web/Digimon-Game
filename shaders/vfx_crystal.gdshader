shader_type spatial;
// Clear ice: a pale translucent body, bright rims where the faces turn away
// from the camera and a sharp highlight. `fade` (1 -> 0) melts it away.
render_mode blend_mix, depth_draw_always, cull_back, diffuse_toon, specular_schlick_ggx, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.32, 0.64, 0.95, 0.74);
uniform vec4 rim_color : source_color = vec4(0.94, 1.0, 1.0, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - facing, 2.2);
	// Deep blue body, pale facets, white only at the rim.
	ALBEDO = mix(tint.rgb, vec3(0.8, 0.93, 1.0), facing * 0.35);
	EMISSION = tint.rgb * 0.1 + rim_color.rgb * fres * 0.55;
	ROUGHNESS = 0.12;
	SPECULAR = 0.95;
	ALPHA = clamp((tint.a + fres * 0.45) * fade, 0.0, 1.0);
}
