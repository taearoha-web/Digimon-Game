shader_type sky;
// Soft pastel "digital world" sky: gradient, sun glow and a faint data grid
// on the upper dome.

uniform vec4 top_color : source_color = vec4(0.28, 0.55, 0.95, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.85, 0.9, 1.0, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.45, 0.62, 0.85, 1.0);
uniform vec4 grid_color : source_color = vec4(0.6, 0.95, 1.0, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.92, 0.75, 1.0);
uniform float grid_strength = 0.18;

void sky() {
	vec3 d = normalize(EYEDIR);
	float t = d.y;
	vec3 col = mix(horizon_color.rgb, top_color.rgb, smoothstep(0.0, 0.55, t));
	col = mix(col, bottom_color.rgb, smoothstep(0.0, -0.25, t));
	if (t > 0.08) {
		vec2 uv = d.xz / t * 1.4 + vec2(TIME * 0.01, 0.0);
		vec2 g = abs(fract(uv) - 0.5);
		float line = smoothstep(0.47, 0.5, max(g.x, g.y));
		col += grid_color.rgb * line * grid_strength * smoothstep(0.08, 0.5, t) * (1.0 - smoothstep(0.7, 1.0, t));
	}
	float sun = max(dot(d, LIGHT0_DIRECTION), 0.0);
	col += sun_color.rgb * (pow(sun, 400.0) * 1.5 + pow(sun, 12.0) * 0.25);
	COLOR = col;
}
