// The class signature sheets of the Archer, the Assassin and the Dark Lord
// (SignatureKit): one quad drawn as a procedural shape. Colour hierarchy:
// white-hot core (accent) -> palette mid (primary) -> dark rim (shade).
// shape: 0 soft glow, 1 shock ring, 2 torn crescent, 3 crit X, 4 streak,
// 5 rune ring, 6 dark disc, 7 flame tongue, 8 bolt strand, 9 feather fan.
// billboard: 0 none (plane XY of the node), 1 facing the camera, 2 turning
// round its Y axis toward the camera (streaks, bolts).
uniform vec4 primary : source_color = vec4(0.6, 0.4, 1.0, 1.0);
uniform vec4 accent : source_color = vec4(1.0, 0.95, 0.9, 1.0);
uniform vec4 shade : source_color = vec4(0.08, 0.04, 0.14, 1.0);
uniform int shape = 0;
uniform int billboard = 0;
uniform float fade = 1.0;
uniform float progress = 0.0;
uniform float opacity = 0.85;
uniform float seed = 0.0;
uniform float roll = 0.0;
uniform float count = 12.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.13) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	vec2 v = VERTEX.xy;
	float c = cos(roll);
	float s = sin(roll);
	if (billboard == 1) {
		VERTEX = vec3(v.x * c - v.y * s, v.x * s + v.y * c, VERTEX.z);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
	} else if (billboard == 2) {
		vec3 axis = MODEL_MATRIX[1].xyz;
		vec3 origin = MODEL_MATRIX[3].xyz;
		vec3 eye = normalize(INV_VIEW_MATRIX[3].xyz - origin);
		vec3 side = cross(normalize(axis), eye);
		side = length(side) > 0.0001 ? normalize(side) : INV_VIEW_MATRIX[0].xyz;
		vec3 normal = cross(side, normalize(axis));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(side * length(MODEL_MATRIX[0].xyz), 0.0), vec4(axis, 0.0), vec4(normal, 0.0), MODEL_MATRIX[3]);
	}
}

vec3 heat(float i) {
	vec3 col = mix(shade.rgb, primary.rgb, smoothstep(0.0, 0.3, i));
	return mix(col, accent.rgb, smoothstep(0.62, 1.0, i));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float r = length(p);
	float a = atan(p.y, p.x);
	float i = 0.0;
	float alpha = 0.0;
	vec3 col = vec3(0.0);
	if (shape == 0) {
		// Soft glow with a hot core.
		i = exp(-r * r * 5.0) * 0.8 + exp(-r * r * 40.0) * 0.5;
		alpha = i;
		col = heat(i);
	} else if (shape == 1) {
		// Shock ring: a band that thins as it travels out, broken a little.
		float w = mix(0.2, 0.035, progress);
		float band = exp(-pow((r - 0.86) / w, 2.0));
		float grain = 0.72 + 0.28 * noise(vec2(a * 6.0, progress * 3.0));
		i = band * grain;
		alpha = i;
		col = heat(i * 0.95);
	} else if (shape == 2) {
		// A crescent cut that tears like cloth: ragged fibres on its edges, the
		// tear opening along the arc as it fades.
		float outer = smoothstep(0.98, 0.9, r);
		float d2 = length(p - vec2(0.0, -0.42));
		float inner = smoothstep(0.86, 0.98, d2);
		float ends = smoothstep(-0.25, 0.35, p.y + 0.1 * abs(p.x));
		float body = outer * inner * ends;
		float fibre = noise(vec2(a * 34.0, r * 5.0)) * 0.6 + noise(vec2(a * 90.0, seed)) * 0.4;
		float rag = smoothstep(progress * 1.05 - 0.05, progress * 1.05 + 0.12, fibre);
		float edge = exp(-pow((d2 - 0.95) / 0.035, 2.0)) * outer * ends;
		i = clamp(body * 0.7 + edge * 0.9, 0.0, 1.0) * rag;
		alpha = i;
		col = heat(i);
	} else if (shape == 3) {
		// The red X of a critical: two tapered bars.
		float d1 = abs(p.x - p.y) * 0.7071;
		float d2 = abs(p.x + p.y) * 0.7071;
		float taper = smoothstep(1.25, 0.2, r);
		float w = 0.09 * taper + 0.01;
		float bars = max(exp(-pow(d1 / w, 2.0)), exp(-pow(d2 / w, 2.0)));
		i = bars * taper + exp(-r * r * 18.0) * 0.35;
		alpha = i;
		col = heat(i);
	} else if (shape == 4) {
		// Streak: the head at the top, the tail thinning out below, fluttering.
		float along = UV.y;
		float width = mix(0.9, 0.1, along);
		float flutter = 0.12 * sin(along * 16.0 - progress * 40.0 + seed * 6.0) * along;
		float across = abs(p.x + flutter) / width;
		i = exp(-across * across * 3.5) * pow(1.0 - along, 0.9) * smoothstep(0.0, 0.1, along);
		alpha = i;
		col = heat(i);
	} else if (shape == 5) {
		// Rune ring: two thin circles and a band of glyphs between them.
		float lines = exp(-pow((r - 0.95) / 0.03, 2.0)) + exp(-pow((r - 0.64) / 0.025, 2.0)) * 0.85;
		float cell = (a / 6.2831853 + 0.5) * count;
		float id = floor(cell);
		vec2 g = vec2(fract(cell) * 2.0 - 1.0, (r - 0.795) / 0.12);
		float h1 = fract(sin(id * 12.989 + seed) * 43758.5);
		float h2 = fract(sin(id * 78.233 + seed) * 12543.1);
		float glyph = 0.0;
		glyph = max(glyph, step(abs(g.x - (h1 - 0.5) * 0.8), 0.16) * step(abs(g.y), 0.8));
		glyph = max(glyph, step(abs(g.y - (h2 - 0.5) * 1.0), 0.12) * step(abs(g.x), 0.6));
		glyph = max(glyph, step(abs(g.x + g.y * (h2 > 0.5 ? 0.6 : -0.6)), 0.12) * step(abs(g.y), 0.7) * step(0.35, h1));
		glyph *= step(abs(g.y), 1.0) * step(abs(g.x), 0.75);
		i = clamp(lines + glyph * 0.9, 0.0, 1.0) * (0.85 + 0.15 * sin(progress * 30.0 + id));
		alpha = i;
		col = heat(i * 0.92);
	} else if (shape == 6) {
		// Dark disc: darkens the ground under an eclipse, soft edged.
		i = smoothstep(1.0, 0.45, r) * (0.85 + 0.15 * noise(p * 3.0 + vec2(progress * 2.0)));
		alpha = i;
		col = shade.rgb;
	} else if (shape == 7) {
		// Flame tongue: wide at the root, licking up to a point; a dark body
		// (shade) with hot edges (accent) round a palette glow.
		float h = 1.0 - UV.y;
		float lick = noise(vec2(p.x * 2.5 + seed * 3.0, h * 3.0 - progress * 7.0));
		float width = (1.0 - h) * 0.85 * (0.7 + 0.6 * lick) + 0.03;
		float x = abs(p.x + (lick - 0.5) * 0.45 * h);
		float m = smoothstep(width, width * 0.3, x) * smoothstep(0.0, 0.1, h) * smoothstep(1.0, 0.75, h + 0.25 * lick);
		float rim = smoothstep(0.0, 0.14, m) * (1.0 - smoothstep(0.3, 0.7, m));
		i = m;
		alpha = smoothstep(0.0, 0.12, m);
		col = mix(primary.rgb * 1.3, shade.rgb, smoothstep(0.55, 1.0, m) * 0.85);
		col = mix(col, accent.rgb, clamp(rim * 1.4, 0.0, 1.0));
	} else if (shape == 8) {
		// Bolt strand: UV.x runs across the strand; a hot thread with a halo.
		float x = abs(UV.x * 2.0 - 1.0);
		i = exp(-x * x * 30.0) + exp(-x * x * 4.0) * 0.35;
		alpha = i;
		col = heat(i);
	} else {
		// Feather vane: barbs off a shaft, broad near the root, a hot shaft.
		float shaft = exp(-pow(p.x / 0.04, 2.0)) * smoothstep(1.0, 0.75, abs(p.y));
		float span = 0.85 * sqrt(max(0.0, 1.0 - p.y * p.y)) * (1.0 - 0.2 * p.y) + 0.02;
		float vane = smoothstep(1.0, 0.75, abs(p.x) / span);
		float barbs = 0.55 + 0.45 * sin((p.y * 1.4 - abs(p.x)) * 34.0 + seed);
		float tips = smoothstep(0.0, 0.25, span - abs(p.x));
		i = clamp(shaft * 0.9 + vane * mix(barbs, 1.0, tips * 0.5) * 0.75, 0.0, 1.0);
		alpha = i * smoothstep(1.0, 0.85, abs(p.y));
		col = heat(i);
	}
	ALBEDO = col;
	ALPHA = clamp(alpha * fade * opacity, 0.0, 1.0);
}
