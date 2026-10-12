shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 color : source_color;
uniform vec4 core : source_color;
uniform vec4 shade : source_color;
uniform float age : hint_range(0.0, 1.0) = 0.0;
uniform float motif = 0.0;
uniform float mode = 0.0;
uniform float opacity = 0.9;

float line(float d, float w) { return 1.0 - smoothstep(w, w + 0.008, abs(d)); }

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float turn = a + age * (0.15 + motif * 0.025);
	float petals = 5.0 + motif;
	float ring = line(r - 0.83, 0.008) + line(r - 0.71, 0.004);
	float marks = step(0.60, cos(turn * 24.0)) * line(r - 0.78, 0.027);
	float petal = line(r - (0.39 + 0.20 * cos(turn * petals)), 0.008);
	float stars = pow(max(0.0, cos(turn * petals)), 18.0) * line(r - 0.94, 0.035);
	float shape = clamp(ring + marks + petal + stars, 0.0, 1.0);
	float accent = clamp(petal + stars, 0.0, 1.0);
	if (mode > 0.5 && mode < 1.5) {
		float rays = pow(abs(cos(a * 4.0 + 0.28)), 12.0);
		float reach = 0.20 + rays * 0.78;
		shape = (1.0 - smoothstep(reach * 0.68, reach, r)) * smoothstep(0.015, 0.08, r);
		accent = 1.0 - smoothstep(0.0, reach * 0.65, r);
	} else if (mode > 1.5) {
		shape = clamp(line(r - 0.70, 0.018) * step(-0.50, cos(a * 4.0))
			+ line(p.x, 0.008) * step(0.78, abs(p.y))
			+ line(p.y, 0.008) * step(0.78, abs(p.x)), 0.0, 1.0);
		accent = line(r - 0.70, 0.004);
	}
	float fade = smoothstep(0.0, 0.09, age) * (1.0 - smoothstep(0.56, 1.0, age));
	vec3 ink = mix(color.rgb, core.rgb, accent * 0.92);
	ALBEDO = ink;
	EMISSION = ink * 0.22;
	ALPHA = shape * fade * opacity * (1.0 - smoothstep(0.98, 1.0, r));
}
