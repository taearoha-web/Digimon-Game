shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform vec4 color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform vec4 core : source_color = vec4(0.85, 1.0, 1.0, 1.0);
uniform vec4 shade : source_color = vec4(0.06, 0.18, 0.35, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float pulse = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.92;
uniform float surface_style = 0.0;
varying vec3 local_point;
void vertex() { local_point = VERTEX; }
void fragment() {
	float rim = pow(max(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0), 3.0);
	float facet = dot(normalize(NORMAL), normalize(vec3(-0.4, 0.8, 0.6))) * 0.5 + 0.5;
	vec3 body = mix(shade.rgb, color.rgb, smoothstep(0.12, 0.8, facet));
	vec3 p = local_point;
	float detail = 0.0;
	if (surface_style > 0.5 && surface_style < 1.5) {
		// Stable intersecting fractures; no texture lookup or screen refraction.
		float crack = abs(sin(p.y * 13.0 + p.x * 9.0 + sin(p.z * 7.0)));
		detail = (1.0 - smoothstep(0.02, 0.095, crack)) * 0.65;
	} else if (surface_style < 2.5 && surface_style > 1.5) {
		detail = pow(max(0.5 + 0.5 * sin(p.y * 11.0 - TIME * 4.0 + p.x * 5.0), 0.0), 6.0) * 0.6;
	} else if (surface_style < 3.5 && surface_style > 2.5) {
		detail = (1.0 - smoothstep(0.025, 0.07, abs(p.x + sin(p.y * 6.0) * 0.08))) * 0.45;
	} else if (surface_style > 3.5) {
		detail = pow(max(0.5 + 0.5 * sin(p.y * 17.0 + p.x * 8.0 + pulse), 0.0), 20.0) * 0.35;
	}
	// Dissolve into small painted islands with a narrow coloured edge.
	float grain = 0.5 + 0.5 * sin(p.x * 19.0 + p.y * 11.0) * sin(p.z * 17.0 - p.y * 7.0);
	float cut = (1.0 - fade) * 1.12 - 0.06;
	float dissolve = smoothstep(cut, cut + 0.06, grain);
	float edge = (1.0 - smoothstep(cut + 0.04, cut + 0.12, grain)) * (1.0 - fade);
	body = mix(body, core.rgb, clamp(rim * 0.58 + detail + edge * 0.65, 0.0, 0.83));
	ALBEDO = body;
	EMISSION = body * 0.16;
	ALPHA = opacity * dissolve * smoothstep(0.0, 0.16, fade);
}
