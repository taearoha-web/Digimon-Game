shader_type spatial;
// The Dark Lord's cape (CapeArt): a cloth grid hanging from the shoulders, UV.x
// across, UV.y down. The vertex stage ripples it, streams it back and up while
// flying (billow) and gathers it up (fold); the fragment stage paints velvet with a
// gold trim, a raven crest on the back, the lining inside and, for the star cape,
// glowing runes and a tattered hem.
render_mode cull_disabled, diffuse_toon, specular_disabled;

uniform vec4 outer_color : source_color = vec4(0.56, 0.11, 0.16, 1.0);
uniform vec4 lining_color : source_color = vec4(0.1, 0.05, 0.06, 1.0);
uniform vec4 trim_color : source_color = vec4(0.91, 0.71, 0.29, 1.0);
uniform float cape_length = 0.76;
uniform float billow = 0.15;
uniform float fold = 0.0;
uniform float star = 0.0;
uniform float crest = 1.0;
uniform float crown = 0.0;
uniform float tatter = 0.0;
uniform float phase = 0.0;

varying vec2 cloth;

void vertex() {
	float u = UV.x;
	float v = UV.y;
	float t = TIME * (1.6 + billow * 2.4) + phase;
	// Gathered up: the cloth rises towards the shoulders and draws in.
	float keep = 1.0 - fold * 0.78;
	VERTEX.y += v * cape_length * (1.0 - keep);
	VERTEX.x *= mix(1.0, 0.55, fold * v);
	// A ripple running down the cloth, stronger near the hem and when flying.
	float wave = sin(t * 2.0 - v * 6.0 + u * 3.0) * 0.5 + sin(t * 3.1 - v * 9.0 - u * 5.0) * 0.25;
	float reach = pow(v, 1.4);
	VERTEX.z -= reach * (0.04 + billow * 0.07) * wave * (1.0 - fold);
	VERTEX.x += reach * 0.015 * sin(t * 1.7 + v * 4.0) * (1.0 - fold);
	// Streaming back and lifting while flying.
	float stream = billow * (1.0 - fold);
	VERTEX.z -= stream * pow(v, 1.3) * cape_length * 0.85;
	VERTEX.y += stream * pow(v, 2.0) * cape_length * 0.45;
	// The hem flares out wider as it streams.
	VERTEX.x *= 1.0 + stream * v * 0.35;
	cloth = UV;
}

// A raven with spread wings, centred at the origin, about 0.5 wide.
float raven(vec2 p) {
	vec2 q = vec2(abs(p.x), p.y);
	float body = length((p - vec2(0.0, -0.02)) / vec2(0.05, 0.11)) - 1.0;
	float head = length(p - vec2(0.0, 0.11)) / 0.045 - 1.0;
	// Each wing: a swept crescent rising from the shoulders.
	vec2 w = q - vec2(0.12, 0.02);
	w = mat2(vec2(0.86, 0.5), vec2(-0.5, 0.86)) * w;
	float wing = max(length(w / vec2(0.15, 0.05)) - 1.0, -(length((w - vec2(0.03, -0.05)) / vec2(0.13, 0.045)) - 1.0));
	// Tail feathers.
	float tail = max(abs(p.x) - (0.02 + (-0.1 - p.y) * 0.5), max(p.y + 0.1, -0.22 - p.y));
	return min(min(body, head), min(wing, tail * 12.0));
}

float hash(float n) {
	return fract(sin(n * 91.3458) * 47453.5453);
}

void fragment() {
	float u = cloth.x;
	float v = cloth.y;
	// Ragged hem for the star cape: notches of uneven depth.
	if (tatter > 0.5) {
		float cell = floor(u * 11.0);
		float depth = 0.05 + hash(cell + 3.0) * 0.07;
		float tooth = abs(fract(u * 11.0) - 0.5) * 2.0;
		if (v > 1.0 - depth * (1.0 - tooth * 0.6)) {
			discard;
		}
	}
	vec3 base = outer_color.rgb;
	// Velvet: darker in the folds of the ripple, lighter on the crests.
	float fold_shade = 0.82 + 0.18 * sin(u * 18.0 + v * 4.0);
	base *= mix(1.0, fold_shade, 0.6) * mix(1.08, 0.78, v);
	float edge = min(min(u, 1.0 - u), 1.0 - v);
	float trim = 1.0 - smoothstep(0.03, 0.05, edge);
	float inner_trim = smoothstep(0.065, 0.075, edge) * (1.0 - smoothstep(0.08, 0.09, edge));
	vec3 trim_col = trim_color.rgb;
	vec3 col = mix(base, trim_col, max(trim, inner_trim * 0.8));
	float glow = 0.0;
	// The crest on the back (seen from behind: the outside of the cape).
	vec2 p = vec2(u - 0.5, 0.36 - v) * vec2(1.0, 0.9);
	float r = raven(p * 1.0);
	float crest_mask = (1.0 - smoothstep(0.0, 0.08, r)) * crest;
	float ring = abs(length(p) - 0.2) - 0.008;
	float ring_mask = (1.0 - smoothstep(0.0, 0.006, ring)) * crest;
	col = mix(col, trim_col * 1.05, max(crest_mask, ring_mask));
	glow += (crest_mask * 0.35 + ring_mask * 0.5) * star;
	// A crown over the raven for the emperor's cape.
	if (crown > 0.5) {
		vec2 c = p - vec2(0.0, 0.25);
		float band = step(abs(c.y), 0.012) * step(abs(c.x), 0.07);
		float spikes = step(abs(fract(c.x * 21.0 + 0.5) - 0.5), 0.18 - c.y * 6.0) * step(0.0, c.y) * step(c.y, 0.05) * step(abs(c.x), 0.07);
		float crown_mask = max(band, spikes);
		col = mix(col, trim_col, crown_mask);
		glow += crown_mask * 0.6;
		// Runes running down both sides of the trim, pulsing.
		float rune_col = step(abs(u - 0.11), 0.018) + step(abs(u - 0.89), 0.018);
		float rune_cell = step(0.45, fract(v * 14.0)) * step(fract(v * 14.0), 0.85);
		float pulse = 0.55 + 0.45 * sin(TIME * 3.0 - v * 10.0);
		float rune = rune_col * rune_cell * step(0.08, v) * step(v, 0.9);
		col = mix(col, trim_col * 1.2, rune);
		glow += rune * pulse * 1.4;
	}
	glow += trim * 0.12 * star;
	if (!FRONT_FACING) {
		// The lining, seen from the hero's side.
		col = mix(lining_color.rgb * mix(1.15, 0.8, v), trim_col, trim * 0.7);
		glow = 0.0;
	}
	ALBEDO = col;
	EMISSION = trim_col * glow;
}
