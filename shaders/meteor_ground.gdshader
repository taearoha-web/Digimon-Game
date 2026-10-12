shader_type spatial;
// Ground warning resolves into a scorched, branching starburst. Everything
// fades; no collision, terrain mutation, or permanent decal is introduced.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform bool warning = false;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float branch = abs(sin(a * 8.0 + sin(r * 18.0 + a * 3.0) * 0.48));
	float thin = 1.0 - smoothstep(0.035, 0.15, branch);
	float scar = thin * smoothstep(0.09, 0.22, r) * (1.0 - smoothstep(0.65, 0.94, r));
	float ring = (1.0 - smoothstep(0.012, 0.028, abs(r - 0.88))) * (0.62 + 0.38 * sin(a * 24.0 + TIME * 1.8));
	float center = 1.0 - smoothstep(0.1, 0.6, r);
	float ripple = (1.0 - smoothstep(0.008, 0.035, abs(r - progress * 0.9))) * (1.0 - progress);
	if (warning) {
		float spokes = (1.0 - smoothstep(0.035, 0.1, abs(sin(a * 8.0)))) * smoothstep(0.76, 0.82, r) * (1.0 - smoothstep(0.9, 0.95, r));
		ALBEDO = mix(vec3(0.2, 0.035, 0.045), vec3(1.0, 0.4, 0.08), max(ring, spokes));
		ALPHA = (center * 0.24 + ring * 0.82 + spokes * 0.76 + ripple * 0.55) * fade;
	} else {
		float earth = (1.0 - smoothstep(0.24, 0.89, r)) * 0.45;
		ALBEDO = mix(vec3(0.065, 0.025, 0.035), vec3(1.0, 0.31, 0.035), scar);
		ALPHA = (earth + scar * 0.88) * fade;
	}
}
