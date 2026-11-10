shader_type spatial;
// A burning sphere (GodRangedKit): the archer's sun, the mage's star, singularity and
// supernova. Opaque: a hot core that darkens to the limb, slow granulation drifting over
// it; it leaves by burning away into noise islands. WebGL2 / Compatibility safe.
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;
uniform vec4 c_core : source_color = vec4(1.0, 0.98, 0.82, 1.0);
uniform vec4 c_mid : source_color = vec4(1.0, 0.74, 0.18, 1.0);
uniform vec4 c_edge : source_color = vec4(0.95, 0.32, 0.06, 1.0);
uniform float fade = 1.0;
uniform float age = 0.0;
uniform float seed = 0.0;
uniform float flow = 1.0;
// 1: the limb is the bright part (a black hole wearing a ring of light).
uniform float invert = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float f = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	// The seam of the sphere's UV is hidden by mirroring the longitude.
	vec2 uv = vec2(abs(UV.x - 0.5) * 24.0, UV.y * 6.0);
	float n = noise(uv + vec2(age * 0.5 * flow + seed, -age * 0.22 * flow)) * 0.6 + noise(uv * 2.3 - vec2(age * 0.8 * flow, seed)) * 0.4;
	float cells = noise(uv * 4.0 + vec2(seed * 3.0, age * 0.6 * flow));
	float cut = (1.0 - fade) * 1.15;
	float body = n * 0.7 + cells * 0.3;
	if (body < cut - 0.05) {
		discard;
	}
	float h = mix(pow(f, 0.8) * 0.72 + n * 0.42 + (cells - 0.5) * 0.14, pow(1.0 - f, 2.2) * 1.5, invert);
	vec3 col = mix(c_edge.rgb, c_mid.rgb, smoothstep(0.22, 0.6, h));
	col = mix(col, c_core.rgb, smoothstep(0.66, 0.98, h));
	// The burning edge of the dissolve.
	col = mix(col, c_core.rgb, (1.0 - smoothstep(cut - 0.05, cut + 0.06, body)) * step(0.01, cut));
	ALBEDO = col;
}
