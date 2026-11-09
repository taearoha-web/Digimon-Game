shader_type spatial;
// The Legendary Guild Wings (LegendWingArt, meshes from LegendWingMesh): faceted
// golden-crystal blades, unshaded so they shine the same in every zone and at night.
// Each blade carries its own UV (u across, v from root to tip): a gold body that runs
// white-hot toward the flared crystal shoulder (v = 0.6), then a prismatic crystal
// tip; two flat facets either side of a bright ridge; a cartoon outline from
// screen-space derivatives (warm ink on the gold, deep violet on the crystal; no extra
// pass), a prismatic glint sweeping out along the tiers over TIME and star glints
// twinkling all over the blades and sashes. The blade tips
// ripple, the sashes sway and the crest crown bobs in the vertex stage. One shared
// material, no textures, no lights.
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

uniform vec4 gold_deep : source_color = vec4(0.9, 0.4, 0.03, 1.0);
uniform vec4 gold : source_color = vec4(1.0, 0.66, 0.1, 1.0);
uniform vec4 gold_light : source_color = vec4(1.0, 0.92, 0.62, 1.0);
uniform vec4 white_hot : source_color = vec4(1.0, 0.98, 0.9, 1.0);
uniform vec4 ink : source_color = vec4(0.58, 0.24, 0.02, 1.0);
uniform vec4 crystal_ink : source_color = vec4(0.36, 0.18, 0.52, 1.0);
uniform float brightness = 1.2;
uniform float prism = 0.9;
uniform float ripple = 1.0;
uniform float sway = 1.0;
uniform float sparkle = 1.0;

varying float v_row;
varying float v_phase;
varying float v_flex;
varying vec3 v_tint;

vec3 rainbow(float h) {
	return 0.5 + 0.5 * cos(6.2832 * (h + vec3(0.0, 0.33, 0.67)));
}

// Twinkling glints scattered over a strip: `cells` along it (v), one glint each at a
// hashed spot that flares now and then into a four-point star a few pixels wide
// (sized in screen pixels from the derivatives, so it reads near and far).
float twinkle(float u, float v, float du, float dv, float cells, float seed) {
	float ci = floor(v * cells);
	float h1 = fract(sin(ci * 12.9898 + seed * 78.233) * 43758.5453);
	float h2 = fract(h1 * 17.13 + 0.31);
	float h3 = fract(h1 * 7.77 + 0.71);
	vec2 d = vec2((u - (0.28 + 0.44 * h2)) / du, (v - (ci + 0.2 + 0.6 * h3) / cells) / dv);
	float tw = pow(max(0.0, sin(TIME * (1.3 + 1.9 * h1) + h1 * 40.0)), 14.0);
	float r = 1.2 + 8.0 * tw;
	float core = exp(-dot(d, d) / (r * r * 0.25));
	float rays = exp(-abs(d.x) * 0.9 - abs(d.y) / (r * 1.6)) + exp(-abs(d.y) * 0.9 - abs(d.x) / (r * 1.6));
	return (core + rays * 0.8) * tw;
}

void vertex() {
	v_row = floor(UV2.x);
	v_phase = fract(UV2.x);
	v_flex = UV2.y;
	v_tint = COLOR.rgb;
	if (v_row < 1.5) {
		// Blade tips ripple, each on its own phase.
		float f = v_flex * v_flex;
		float w = sin(TIME * 2.1 + v_phase * 6.2832 + v_flex * 3.0);
		VERTEX.z += ripple * f * 0.08 * w;
		VERTEX.y += ripple * f * 0.03 * sin(TIME * 1.5 + v_phase * 6.2832);
	} else if (v_row < 3.5) {
		// The sashes sway like cloth in a breeze, more toward their ends.
		float t = UV.y;
		float a = t * t;
		VERTEX.x += sway * a * 0.1 * sin(TIME * 1.3 + v_phase * 6.2832 - t * 3.5);
		VERTEX.z += sway * a * (0.16 * sin(TIME * 0.9 + v_phase * 4.0 - t * 2.6) - 0.05);
	} else {
		// The crest crown floats.
		VERTEX.y += 0.03 * sin(TIME * 1.4);
	}
}

void fragment() {
	vec3 n = normalize(NORMAL);
	if (dot(n, VIEW) < 0.0) {
		n = -n;
	}
	float facing = clamp(dot(n, VIEW), 0.0, 1.0);
	float u = UV.x;
	float v = clamp(UV.y, 0.0, 1.0);
	float du = max(fwidth(u), 1e-4);
	float lit = 0.82 + 0.26 * clamp(dot(n, normalize(vec3(-0.35, 0.7, 0.62))), -1.0, 1.0);
	vec3 col;
	if (v_row > 5.5 && v_row < 6.5) {
		// Gems: the guild's colour, facets catching a white glint, a slow twinkle.
		float tw = pow(0.5 + 0.5 * sin(TIME * 2.1 + v_flex * 9.0), 4.0);
		col = v_tint * (0.7 + 0.5 * facing) + vec3(1.0) * (pow(facing, 10.0) * 0.8 + tw * 0.3 * step(0.7, v_flex));
		ALBEDO = col * brightness;
	} else if (v_row > 4.5 && v_row < 5.5) {
		// The crest's enamel: deep jewel tone with a soft gloss sliding across.
		float r = 1.0 - 2.0 * u;
		float gloss = smoothstep(0.12, 0.0, abs(fract(UV.y * 0.6 + r * 0.3 - TIME * 0.12) - 0.5));
		col = v_tint * (0.85 + 0.35 * (1.0 - r)) + v_tint * gloss * 0.25;
		float line = 1.0 - smoothstep(du * 1.1, du * 2.5, u);
		col = mix(col, ink.rgb * 0.6, line * 0.9);
		ALBEDO = col * brightness;
	} else if (v_row > 6.5) {
		// Crown trim (the circlet and the crest's rim): white-gold, inked.
		col = mix(gold.rgb, gold_light.rgb, 0.55) * lit;
		col += white_hot.rgb * pow(1.0 - facing, 2.0) * 0.3;
		float e = min(u, 1.0 - u);
		float line = 1.0 - smoothstep(du * 1.1, du * 2.5, e);
		col = mix(col, ink.rgb, line * 0.92);
		ALBEDO = col * brightness;
	} else if (v_row > 2.5 && v_row < 3.5) {
		// Sashes of golden light: a white-gold hem, light flowing down them.
		col = mix(gold.rgb, gold_light.rgb, 0.35);
		float hem = smoothstep(0.2, 0.1, min(u, 1.0 - u));
		col = mix(col, white_hot.rgb, hem * 0.7);
		float flow = smoothstep(0.55, 1.0, sin(v * 9.0 - TIME * 2.4 + v_phase * 6.0));
		col += gold_light.rgb * flow * 0.35;
		col = mix(col, rainbow(v * 0.8 + TIME * 0.1 + v_phase), smoothstep(0.75, 1.0, v) * prism * 0.3);
		col *= lit;
		float e = min(u, 1.0 - u);
		float line = 1.0 - smoothstep(du * 1.1, du * 2.5, e);
		col = mix(col, ink.rgb, line * 0.85);
		col += white_hot.rgb * twinkle(u, v, du, max(fwidth(v), 1e-4), 6.0, v_phase * 9.0 + 3.0) * sparkle;
		ALBEDO = col * brightness;
	} else {
		// A crystal blade (wing blades, arm shards, crown spikes).
		float dv = max(fwidth(v), 1e-4);
		float crys = smoothstep(0.6 - dv, 0.6 + dv, v);
		// The gold body: deep at the root, bright, then white-hot at the shoulder.
		vec3 body = mix(gold_deep.rgb, gold.rgb, smoothstep(0.0, 0.3, v));
		body = mix(body, gold_light.rgb, smoothstep(0.3, 0.5, v) * 0.6);
		body = mix(body, white_hot.rgb, smoothstep(0.48, 0.6, v) * 0.85);
		if (v_row > 0.5 && v_row < 1.5) {
			body = mix(body, gold_light.rgb, 0.2);
		}
		// The crystal tip: prismatic, its hue shifting with the facet, the view and time.
		float side = step(0.5, u);
		vec3 hue = rainbow(0.1 + v * 0.9 + side * 0.22 + facing * 0.5 + TIME * 0.08 + v_phase * 0.6);
		// Saturated jewel colour at the shoulder, clearing to a white-hot point.
		vec3 crystal = mix(hue, white_hot.rgb, 0.38 + 0.45 * smoothstep(0.8, 1.0, v));
		crystal = mix(crystal, gold_light.rgb, 0.12);
		col = mix(body, crystal, crys);
		// Facets: the two halves of the blade lit apart, a bright ridge between them.
		col *= mix(0.84, 1.06, side) * lit;
		float ridge = 1.0 - smoothstep(du * 0.6, du * 1.8, abs(u - 0.5));
		col = mix(col, white_hot.rgb * 1.1, ridge * 0.6);
		// The prismatic glint sweeping out along the tiers, blade by blade.
		float band = fract(v_flex * 1.1 + v * 0.12 - TIME * 0.22 + v_phase * 0.05);
		float core = smoothstep(0.09, 0.0, abs(band - 0.2));
		col += white_hot.rgb * core * prism * 0.5;
		// A pearl shimmer on the grazing edges.
		col += mix(gold_light.rgb, hue, 0.5) * pow(1.0 - facing, 2.2) * 0.35;
		// The girdle across the shoulder, then the outline: warm ink on the gold,
		// violet on the crystal.
		float girdle = 1.0 - smoothstep(dv * 0.8, dv * 2.0, abs(v - 0.6));
		vec3 line_ink = mix(ink.rgb, crystal_ink.rgb, crys);
		col = mix(col, ink.rgb, girdle * 0.8);
		float e = min(u, 1.0 - u);
		float line = 1.0 - smoothstep(du * 1.1, du * 2.5, e);
		col = mix(col, line_ink, line * 0.92);
		// Glints twinkling all over the blades, so the whole set shimmers.
		float glint = twinkle(u, v, du, dv, 5.0, v_phase * 13.0 + v_row * 3.1);
		col += mix(white_hot.rgb, hue, 0.25 * crys) * glint * sparkle * 1.3;
		ALBEDO = col * brightness;
	}
}
