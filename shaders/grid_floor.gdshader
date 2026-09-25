shader_type spatial;
render_mode diffuse_toon, specular_disabled;
// Glowing digital grid for plazas / platforms.

uniform vec4 base_color : source_color = vec4(0.36, 0.44, 0.7, 1.0);
uniform vec4 line_color : source_color = vec4(0.2, 0.88, 1.0, 1.0);
uniform float cells = 10.0;
uniform float pulse_speed = 0.6;

void fragment() {
	vec2 uv = UV * cells;
	vec2 g = abs(fract(uv) - 0.5);
	float line = smoothstep(0.46, 0.5, max(g.x, g.y));
	float r = length(UV - 0.5);
	float pulse = smoothstep(0.03, 0.0, abs(fract(r * 2.0 - TIME * pulse_speed) - 0.5) - 0.45);
	ALBEDO = base_color.rgb;
	EMISSION = line_color.rgb * (line * 0.7 + pulse * line * 1.2);
}
