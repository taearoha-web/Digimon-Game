shader_type spatial;
// The Assassin's star-wing light (ShadowWingArt): the phantom double of each wing
// (a faint violet veil, light flowing outward, a bright torn hem and drifting
// motes) and, with flame = 1, the eclipse halo's corona, its flames flickering
// and turning slowly about the halo's centre. Blended, not
// added, so the colours hold on bright day maps; it never writes depth, so the
// real wing in front always covers its ghost.
// UV.x = wrist -> trailing edge (flames: base -> tip), UV.y = across.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform vec4 primary : source_color = vec4(0.42, 0.23, 0.75, 1.0);
uniform vec4 accent : source_color = vec4(1.0, 0.36, 0.54, 1.0);
uniform float intensity = 1.0;
uniform float flame = 0.0;
uniform vec3 centre = vec3(0.0, 0.84, -0.3);
uniform float spin = 0.35;
varying vec3 local;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	if (flame > 0.5) {
		float t = TIME * spin;
		vec2 d = VERTEX.xy - centre.xy;
		VERTEX.xy = centre.xy + vec2(d.x * cos(t) - d.y * sin(t), d.x * sin(t) + d.y * cos(t));
	}
	local = VERTEX;
}

void fragment() {
	float r = clamp(UV.x, 0.0, 1.0);
	float a = UV.y;
	vec3 col;
	float alpha;
	if (flame > 0.5) {
		float across = 1.0 - pow(abs(a - 0.5) * 2.0, 1.5);
		float flicker = 0.75 + 0.25 * sin(TIME * 9.0 + local.x * 40.0 + local.y * 31.0);
		col = mix(vec3(1.0, 0.9, 0.94), accent.rgb, smoothstep(0.0, 0.5, r));
		alpha = across * (1.0 - r * r) * flicker;
	} else {
		float flow = pow(0.5 + 0.5 * sin(r * 9.0 - TIME * 1.8 + a * 5.0), 6.0);
		float hem = smoothstep(0.8, 1.0, r);
		col = mix(primary.rgb, accent.rgb, hem) + vec3(0.25, 0.2, 0.35) * flow * r;
		alpha = (0.2 + 0.22 * flow * r) * smoothstep(0.05, 0.45, r) + hem * 0.6;
		vec2 cell = local.xy * 22.0 + vec2(0.0, TIME * 0.35);
		vec2 id = floor(cell);
		float h = hash(id);
		float mote = step(0.9, h) * smoothstep(0.2, 0.0, length(fract(cell) - 0.5)) * (0.5 + 0.5 * sin(TIME * 3.0 + h * 50.0));
		col = mix(col, vec3(0.97, 0.92, 1.0), mote);
		alpha = max(alpha, mote * smoothstep(0.1, 0.4, r));
	}
	ALBEDO = col;
	ALPHA = clamp(alpha * intensity, 0.0, 1.0);
}
