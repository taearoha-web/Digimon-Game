shader_type spatial;
// The Assassin's wing membranes and shadow tendrils (ShadowWingArt). Membranes:
// a near-black core at the wrist deepening to violet, energy pulsing out along
// the panel, fine veins, a glowing torn hem and stars twinkling in the night.
// Tendrils (wisp = 1): a curling ribbon that sways and fades to a bright tip.
// UV.x = wrist -> trailing edge (tendrils: root -> tip), UV.y = across.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_always;
uniform vec4 core : source_color = vec4(0.04, 0.02, 0.08, 1.0);
uniform vec4 mid : source_color = vec4(0.24, 0.12, 0.47, 1.0);
uniform vec4 edge : source_color = vec4(0.71, 0.55, 1.0, 1.0);
uniform vec4 spark : source_color = vec4(0.91, 0.86, 1.0, 1.0);
uniform float opacity = 0.94;
uniform float wisp = 0.0;
varying vec3 local;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	local = VERTEX;
	float s = UV.x * UV.x * wisp;
	VERTEX.x += sin(TIME * 2.1 + UV.x * 5.0 + VERTEX.y * 7.0) * 0.022 * s;
	VERTEX.z += cos(TIME * 1.7 + UV.x * 4.0) * 0.02 * s;
}

void fragment() {
	float r = clamp(UV.x, 0.0, 1.0);
	float a = UV.y;
	float rim = pow(max(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0), 2.0);
	vec3 col;
	float alpha;
	if (wisp > 0.5) {
		float flow = pow(max(0.5 + 0.5 * sin(r * 14.0 - TIME * 3.0), 0.0), 4.0);
		float across = 1.0 - pow(abs(a - 0.5) * 2.0, 2.0);
		col = mix(mid.rgb, edge.rgb, smoothstep(0.3, 1.0, r)) + edge.rgb * flow * 0.4;
		alpha = opacity * across * (1.0 - smoothstep(0.55, 1.0, r) * 0.85) * (0.75 + 0.25 * flow);
	} else {
		col = mix(core.rgb, mid.rgb, smoothstep(0.08, 0.95, r));
		float pulse = pow(max(0.5 + 0.5 * sin(r * 11.0 - TIME * 2.2 + sin(a * 6.2832) * 0.8), 0.0), 10.0);
		col += mid.rgb * pulse * 0.6 * smoothstep(0.15, 0.6, r);
		float vein = pow(abs(sin(a * 3.14159 * 3.0 + r * 1.3)), 36.0) * smoothstep(0.06, 0.45, r);
		float hem = smoothstep(0.84, 1.0, r);
		col += edge.rgb * vein * 0.28 * (1.0 - hem);
		col = mix(col, edge.rgb, hem * 0.8);
		vec2 cell = local.xy * 34.0;
		vec2 id = floor(cell);
		float h = hash(id);
		vec2 jitter = vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5;
		float d = length(fract(cell) - 0.5 - jitter * 0.5);
		float star = step(0.88, h) * smoothstep(0.17, 0.0, d) * (0.35 + 0.65 * pow(max(0.5 + 0.5 * sin(TIME * 2.4 + h * 60.0), 0.0), 4.0));
		col += spark.rgb * star * smoothstep(0.15, 0.45, r);
		col += mid.rgb * rim * 0.4;
		alpha = clamp(opacity * mix(1.0, 0.86, smoothstep(0.3, 0.9, r)) + hem * 0.15 + star, 0.0, 1.0);
	}
	ALBEDO = col;
	ALPHA = alpha;
}
