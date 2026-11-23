shader_type spatial;
// The +15 set's radiance (EnhanceFx._radiance): light pouring out of the body in the
// outfit's colour. One camera-facing quad behind the hero: a bright soft core, slowly
// turning rays that pulse outwards and a wide halo. Animated from TIME, no script.
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float energy = 1.0;

void vertex() {
	// Face the camera, keep the quad's size in world units.
	// Pushed 0.7 m behind the body as the camera sees it, so the hero stands in front of it.
	vec4 centre = MODEL_MATRIX[3];
	vec3 away = normalize(centre.xyz - INV_VIEW_MATRIX[3].xyz);
	centre.xyz += away * 0.7;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], centre);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r >= 1.0) {
		discard;
	}
	float a = atan(p.y, p.x);
	float t = TIME;
	// Two sets of rays turning opposite ways, flaring in and out.
	float rays = pow(0.5 + 0.5 * sin(a * 12.0 + t * 0.6), 6.0) * (0.75 + 0.25 * sin(t * 3.1 + a * 3.0));
	rays += 0.7 * pow(0.5 + 0.5 * sin(a * 7.0 - t * 0.9 + 1.3), 8.0) * (0.7 + 0.3 * sin(t * 2.3));
	float ray_fade = smoothstep(1.0, 0.25, r) * smoothstep(0.05, 0.25, r);
	float core = exp(-r * r * 9.0);
	float halo = exp(-r * r * 2.6) * 0.45;
	float pulse = 0.85 + 0.15 * sin(t * 2.6);
	float g = (core * 0.9 + halo + rays * ray_fade * 1.1) * pulse * energy;
	vec3 col = mix(color.rgb, vec3(1.0), clamp(core * 0.7, 0.0, 0.7));
	ALBEDO = col * g;
	ALPHA = clamp(g * 0.55, 0.0, 0.9);
}
