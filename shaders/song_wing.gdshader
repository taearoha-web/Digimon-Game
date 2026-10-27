shader_type spatial;
// The Bard's wing feathers (SongWingArt): toon-lit vanes with fine barbs, blushing
// from the root colour to the tip colour (and deep at the very tip), edged and
// shafted in gold, each feather a shade apart so the rows read. Rings of soft light
// ripple out from the shoulders like sound, the tips flutter, and the star pair's
// pearl shifts through rose and violet with the view and twinkles with starlight
// inside a fine gold filigree. motion = 0 holds everything still.
// UV.x = root -> tip; UV.y = across (0 leading edge, 0.5 shaft, 1 trailing edge)
// plus 2 x the feather's number.
render_mode cull_disabled, diffuse_toon, specular_disabled;
uniform vec4 root_color : source_color = vec4(1.0, 0.97, 0.93, 1.0);
uniform vec4 tip_color : source_color = vec4(0.94, 0.69, 0.56, 1.0);
// The very tip (alpha: how much of it).
uniform vec4 deep_color : source_color = vec4(0.6, 0.45, 0.9, 0.0);
uniform vec4 edge_color : source_color = vec4(0.95, 0.77, 0.35, 1.0);
uniform vec4 pearl_a : source_color = vec4(1.0, 0.97, 1.0, 1.0);
uniform vec4 pearl_b : source_color = vec4(0.97, 0.66, 0.82, 1.0);
uniform vec4 pearl_c : source_color = vec4(0.62, 0.5, 0.95, 1.0);
uniform float tip_from = 0.35;
uniform float edge_width = 0.14;
uniform float glow = 0.3;
// Self-light, so a vane turned from the sun stays ivory instead of greying.
uniform float lift = 0.2;
uniform float irid = 0.0;
uniform float sparkle = 0.0;
uniform float filigree = 0.0;
uniform float motion = 1.0;
varying vec3 local;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	local = VERTEX;
	float t = UV.x;
	VERTEX += NORMAL * sin(TIME * 2.6 + VERTEX.x * 7.0 + VERTEX.y * 5.0) * 0.006 * t * t * motion;
}

void fragment() {
	float t = clamp(UV.x, 0.0, 1.0);
	float number = floor(UV.y * 0.5);
	float across = abs(UV.y - number * 2.0 - 0.5) * 2.0;
	float own = hash(vec2(number, 3.7));
	vec3 col = mix(root_color.rgb, tip_color.rgb, smoothstep(tip_from, 1.0, t));
	col = mix(col, deep_color.rgb, smoothstep(0.7, 1.0, t) * deep_color.a);
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	if (irid > 0.0) {
		float k = fract(t * 0.55 + (1.0 - facing) * 0.7 + own * 0.3 + TIME * 0.04 * motion) * 3.0;
		vec3 pearl = k < 1.0 ? mix(pearl_a.rgb, pearl_b.rgb, k) : (k < 2.0 ? mix(pearl_b.rgb, pearl_c.rgb, k - 1.0) : mix(pearl_c.rgb, pearl_a.rgb, k - 2.0));
		col = mix(col, pearl, irid * (0.35 + 0.4 * t));
	}
	// Each feather a shade apart, darker at the root where the next row covers it.
	col *= (0.93 + 0.1 * own) * mix(0.84, 1.0, smoothstep(0.0, 0.35, t));
	col *= 0.95 + 0.05 * sin(t * 80.0 - across * 18.0);
	float shaft = (1.0 - smoothstep(0.02, 0.055, across)) * (1.0 - 0.85 * t) * 0.75;
	float rim = smoothstep(1.0 - edge_width, 1.0 - edge_width * 0.3, across);
	float lace = filigree * (1.0 - smoothstep(0.02, 0.06, abs(across - 0.62 + 0.08 * sin(t * 26.0)))) * smoothstep(0.2, 0.4, t) * (1.0 - smoothstep(0.78, 0.9, t));
	col = mix(col, edge_color.rgb, clamp(max(shaft * 0.8, rim) + lace * 0.85, 0.0, 1.0));
	vec3 light = edge_color.rgb * (rim + lace * 0.5) * glow;
	if (motion > 0.0) {
		// Sound rippling out from the shoulders.
		float r = length(vec2(abs(local.x), local.y - 0.55));
		float wave = pow(0.5 + 0.5 * sin(r * 11.0 - TIME * 1.8), 16.0) * motion;
		light += mix(tip_color.rgb, edge_color.rgb, 0.4) * wave * 0.18 * smoothstep(0.15, 0.8, t);
	}
	if (sparkle > 0.0) {
		vec2 cell = vec2(t * 14.0, across * 2.0 + number * 5.0);
		vec2 id = floor(cell);
		float h = hash(id);
		float d = length(fract(cell) - 0.5);
		float twinkle = 0.4 + 0.6 * pow(0.5 + 0.5 * sin(TIME * 2.6 * motion + h * 50.0), 3.0);
		light += vec3(1.0, 0.96, 1.0) * step(0.86, h) * smoothstep(0.22, 0.0, d) * twinkle * sparkle * smoothstep(0.2, 0.5, t);
	}
	ALBEDO = col;
	EMISSION = light + col * lift;
}
