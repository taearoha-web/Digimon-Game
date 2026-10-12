shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform vec4 color : source_color;
uniform vec4 core : source_color;
uniform vec4 shade : source_color;
uniform float age : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float edge = abs(UV.y - 0.5) * 2.0;
	float bright = pow(1.0 - edge, 9.0);
	float reveal = 1.0 - smoothstep(age * 3.2, age * 3.2 + 0.09, UV.x);
	float erosion = smoothstep(0.0, 0.30, UV.x - max(0.0, age - 0.42));
	float fade = (1.0 - smoothstep(0.55, 1.0, age));
	float threads = pow(0.5 + 0.5 * sin(UV.y * 65.0 + UV.x * 14.0), 14.0);
	float grain = 0.88 + 0.12 * sin(UV.x * 110.0 + UV.y * 16.0);
	vec3 ink = mix(shade.rgb, color.rgb, 1.0 - edge * 0.75);
	ink = mix(ink, core.rgb, bright * 0.85 + threads * 0.12);
	ALBEDO = ink;
	EMISSION = ink * 0.25;
	ALPHA = (1.0 - smoothstep(0.83, 1.0, edge)) * reveal * erosion * fade * grain * 0.88;
}
