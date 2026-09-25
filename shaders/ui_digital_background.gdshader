shader_type canvas_item;
// Animated "digital world" menu background: gradient, drifting grid,
// scanning light bands and soft floating orbs. Cheap enough for mobile.

uniform vec4 top_color : source_color = vec4(0.07, 0.11, 0.30, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.02, 0.04, 0.12, 1.0);
uniform vec4 grid_color : source_color = vec4(0.2, 0.88, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.48, 0.24, 1.0);
uniform float grid_scale = 18.0;
uniform float speed = 0.04;
uniform float intensity = 1.0;

float grid_line(vec2 uv, float scale) {
	vec2 g = abs(fract(uv * scale) - 0.5);
	float line = min(g.x, g.y);
	return smoothstep(0.03, 0.0, line);
}

void fragment() {
	vec2 uv = UV;
	float aspect = 1.0 / max(SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y, 0.0001);
	vec3 col = mix(top_color.rgb, bottom_color.rgb, uv.y);

	// Perspective-ish floor grid in the lower half.
	float horizon = 0.58;
	if (uv.y > horizon) {
		float depth = (uv.y - horizon) / (1.0 - horizon);
		vec2 floor_uv = vec2((uv.x - 0.5) * aspect / (depth + 0.08), 1.0 / (depth + 0.08) + TIME * speed * 20.0);
		float g = grid_line(floor_uv * 0.08, 1.0);
		col += grid_color.rgb * g * depth * 0.55 * intensity;
	}
	// Faint vertical data grid in the sky.
	vec2 sky_uv = vec2(uv.x * aspect, uv.y) + vec2(0.0, TIME * speed);
	col += grid_color.rgb * grid_line(sky_uv, grid_scale * 0.5) * 0.05 * intensity * (1.0 - uv.y);

	// Horizon glow.
	col += glow_color.rgb * exp(-abs(uv.y - horizon) * 18.0) * 0.35 * intensity;

	// Scanning band.
	float band = fract(TIME * 0.07);
	col += grid_color.rgb * exp(-abs(uv.y - band) * 60.0) * 0.06 * intensity;

	// Floating orbs.
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		vec2 p = vec2(fract(0.13 + fi * 0.27 + sin(TIME * 0.05 + fi) * 0.08), fract(0.2 + fi * 0.19 + TIME * 0.01 * (1.0 + fi * 0.3)));
		vec2 d = (uv - p) * vec2(aspect, 1.0);
		float orb = exp(-dot(d, d) * 220.0);
		col += mix(grid_color.rgb, glow_color.rgb, mod(fi, 2.0)) * orb * 0.35 * intensity;
	}
	// Vignette.
	vec2 v = uv - 0.5;
	col *= 1.0 - dot(v, v) * 0.9;
	COLOR = vec4(col, 1.0);
}
