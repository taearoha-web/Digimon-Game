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
	vec3 top = vec3(0.16, 0.38, 0.80);
	vec3 low = vec3(0.50, 0.78, 0.97);
	vec3 col = mix(top, low, smoothstep(0.0, 0.75, uv.y));
	vec2 p = vec2(uv.x * aspect, uv.y);
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float x = mod(hash(vec2(fi, 1.0)) * 3.0 + TIME * (0.012 + 0.006 * fi), 3.2) - 0.7;
		float y = 0.12 + hash(vec2(fi, 2.0)) * 0.42;
		col = mix(col, vec3(1.0), cloud(p, vec2(x, y), 0.16 + 0.05 * hash(vec2(fi, 3.0))) * 0.9);
	}
	float far = 0.72 + sin(uv.x * 5.0 + 1.0) * 0.035 + sin(uv.x * 11.0) * 0.012;
	float near = 0.82 + sin(uv.x * 4.0 + 3.0) * 0.03 + sin(uv.x * 9.0 + 2.0) * 0.012;
	col = mix(col, vec3(0.30, 0.62, 0.38), step(far, uv.y));
	col = mix(col, vec3(0.20, 0.46, 0.30), step(near, uv.y));
	COLOR = vec4(col, 1.0);
}
