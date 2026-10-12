shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;
uniform float fade = 1.0;
uniform float pulse = 0.0;
uniform float age = 0.0;
varying vec3 local_pos;
varying vec3 local_normal;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.13, 0.37, 0.61));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float noise3(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1,0,0)), f.x),
		mix(hash3(i + vec3(0,1,0)), hash3(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0,0,1)), hash3(i + vec3(1,0,1)), f.x),
		mix(hash3(i + vec3(0,1,1)), hash3(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
	float roll = sin(VERTEX.x * 13.0 + age * 1.2) * sin(VERTEX.z * 11.0 - age * 0.8);
	VERTEX += NORMAL * roll * 0.018;
}
void fragment() {
	float dissolve = fract(dot(floor(FRAGCOORD.xy), vec2(0.75487766, 0.56984029)));
	if (fade <= dissolve) { discard; }
	vec3 q = local_pos * vec3(4.0, 2.3, 4.0) + vec3(age * 0.09, 0.0, age * -0.07);
	float coarse = noise3(q);
	float detail = noise3(q * 2.7 + coarse);
	float smoke = coarse * 0.72 + detail * 0.28;
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float top = smoothstep(-0.55, 0.9, local_pos.y);
	float lighting = max(0.0, dot(normalize(local_normal), normalize(vec3(-0.4, 0.8, 0.5))));
	float relief = smoothstep(0.26, 0.77, smoke);
	vec3 ink = mix(vec3(0.075, 0.087, 0.11), vec3(0.68, 0.70, 0.73), lighting * 0.52 + relief * 0.30 + top * 0.13);
	ink += rim * vec3(0.12, 0.15, 0.19);
	// Irregular storm veins embedded in the cloud, lit only around a strike.
	float vein = 1.0 - smoothstep(0.006, 0.027, abs(coarse - 0.50 + (detail - 0.5) * 0.28));
	float glow = 1.0 - smoothstep(0.02, 0.15, abs(coarse - 0.50));
	vec3 energy = mix(vec3(0.16, 0.57, 0.90), vec3(1.0, 0.72, 0.20), smoothstep(0.45, 0.7, detail));
	ALBEDO = ink + energy * pulse * (vein * 0.80 + glow * 0.20);
}
