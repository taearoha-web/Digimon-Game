shader_type canvas_item;
// Cartoon title background: sky gradient, drifting puffy clouds, rolling hills.

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float cloud(vec2 uv, vec2 c, float s) {
	vec2 d = (uv - c) / s;
	d.y *= 1.8;
	float r = length(d);
	r = min(r, length(d - vec2(0.55, -0.05)) * 1.15);
	r = min(r, length(d + vec2(0.55, 0.05)) * 1.15);
	return smoothstep(0.5, 0.42, r);
}

void fragment() {
	vec2 uv = UV;
	float aspect = 16.0 / 9.0;
	vec3 top = vec3(0.208, 0.392, 0.467);
	vec3 low = vec3(0.580, 0.788, 0.773);
	vec3 col = mix(top, low, smoothstep(0.0, 0.75, uv.y));
	vec2 p = vec2(uv.x * aspect, uv.y);
	float sun_distance = length((uv - vec2(0.76, 0.24)) * vec2(aspect, 1.0));
	col = mix(col, vec3(1.0, 0.89, 0.69), 0.24 * exp(-sun_distance * 6.0));
	col = mix(col, vec3(1.0, 0.94, 0.79), 0.86 * (1.0 - smoothstep(0.056, 0.063, sun_distance)));
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float x = mod(hash(vec2(fi, 1.0)) * 3.0 + TIME * (0.012 + 0.006 * fi), 3.2) - 0.7;
		float y = 0.12 + hash(vec2(fi, 2.0)) * 0.42;
		col = mix(col, vec3(1.0, 0.969, 0.902), cloud(p, vec2(x, y), 0.16 + 0.05 * hash(vec2(fi, 3.0))) * 0.65);
	}
	float far = 0.72 + sin(uv.x * 5.0 + 1.0) * 0.035 + sin(uv.x * 11.0) * 0.012;
	float near = 0.82 + sin(uv.x * 4.0 + 3.0) * 0.03 + sin(uv.x * 9.0 + 2.0) * 0.012;
	float distant = 0.65 + sin(uv.x * 7.0 - 0.8) * 0.035;
	col = mix(col, vec3(0.49, 0.66, 0.64), smoothstep(distant, distant + 0.004, uv.y));
	col = mix(col, vec3(0.396, 0.537, 0.510), smoothstep(far, far + 0.003, uv.y));
	col = mix(col, vec3(0.247, 0.404, 0.373), smoothstep(near, near + 0.003, uv.y));
	COLOR = vec4(col, 1.0);
}
