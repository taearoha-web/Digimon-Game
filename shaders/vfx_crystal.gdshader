shader_type spatial;
// Jewel ice: turquoise feet, lavender facets and a pale mint rim. Most of the
// color comes from the material rather than emission, keeping combat readable.
render_mode blend_mix, depth_prepass_alpha, cull_back, diffuse_burley, specular_schlick_ggx, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.29, 0.66, 0.76, 0.82);
uniform vec4 rim_color : source_color = vec4(0.72, 0.93, 0.9, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
varying vec3 crystal_position;
varying vec3 crystal_normal;

void vertex() {
	crystal_position = VERTEX;
	crystal_normal = NORMAL;
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - facing, 2.2);
	float height_tint = smoothstep(-0.1, 0.95, crystal_position.y);
	float facet = smoothstep(-0.35, 0.8, crystal_normal.x + crystal_normal.z * 0.65);
	vec3 body = mix(tint.rgb * 0.78, vec3(0.64, 0.83, 0.88), height_tint * 0.7);
	body = mix(body, vec3(0.57, 0.58, 0.82), facet * 0.22);
	// Thin diagonal inclusions stay fixed in the crystal as it spins.
	float inclusion = 1.0 - smoothstep(0.025, 0.075, abs(sin(crystal_position.y * 16.0 + crystal_position.x * 8.0 + crystal_position.z * 5.0)));
	ALBEDO = mix(body, rim_color.rgb, fres * 0.28 + inclusion * 0.07);
	EMISSION = tint.rgb * 0.045 + rim_color.rgb * fres * 0.14;
	ROUGHNESS = 0.23;
	SPECULAR = 0.62;
	ALPHA = clamp((tint.a + fres * 0.16) * fade, 0.0, 1.0);
}
