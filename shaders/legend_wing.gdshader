shader_type spatial;
// The Legendary Guild Wings (LegendWingArt, meshes from LegendWingMesh): radiant gold
// feathers, unshaded so they shine the same in every zone and at night. Each feather
// carries its own UV (u across, v from root to tip): a warm-ink cartoon outline from
// screen-space derivatives (no extra pass), a white-gold shaft, a tip that glows white,
// and a prismatic band that sweeps out along the feathers over TIME. The tips ripple in
// the vertex stage and the halo's crown of rays turns slowly; one shared material, no
// textures, no lights.
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

uniform vec4 gold_deep : source_color = vec4(0.92, 0.42, 0.04, 1.0);
uniform vec4 gold : source_color = vec4(1.0, 0.66, 0.12, 1.0);
uniform vec4 gold_light : source_color = vec4(1.0, 0.93, 0.68, 1.0);
uniform vec4 ink : source_color = vec4(0.62, 0.27, 0.03, 1.0);
uniform float brightness = 1.25;
uniform float prism = 0.75;
uniform float ripple = 1.0;

varying float v_row;
varying float v_phase;
varying float v_flex;
varying vec3 v_tint;

vec3 rainbow(float h) {
	return 0.5 + 0.5 * cos(6.2832 * (h + vec3(0.0, 0.33, 0.67)));
}

void vertex() {
	v_row = floor(UV2.x);
	v_phase = fract(UV2.x);
	v_flex = UV2.y;
	v_tint = COLOR.rgb;
	if (v_row > 4.5 && v_row < 5.5) {
		// The halo's rays turn slowly round its centre.
		float a = TIME * 0.22;
		VERTEX.xy = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * VERTEX.xy;
	} else if (v_row < 3.5) {
		// Feather tips ripple, each on its own phase.
		float f = v_flex * v_flex;
		float w = sin(TIME * 2.3 + v_phase * 6.2832 + v_flex * 3.0);
		VERTEX.z += ripple * f * 0.07 * w;
		VERTEX.y += ripple * f * 0.025 * sin(TIME * 1.6 + v_phase * 6.2832);
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
	vec3 col;
	if (v_row > 5.5) {
		// Gems: the guild's colour, a white glint and a slow twinkle.
		float tw = pow(0.5 + 0.5 * sin(TIME * 2.1 + v_flex * 9.0), 4.0);
		col = v_tint * (0.75 + 0.45 * facing) + vec3(1.0) * (pow(facing, 10.0) * 0.8 + tw * 0.25);
		ALBEDO = col * brightness;
	} else {
		bool ring = v_row > 3.5;
		// Root to tip: warm gold, bright gold, white-gold.
		col = mix(gold_deep.rgb, gold.rgb, smoothstep(0.0, 0.45, v));
		col = mix(col, gold_light.rgb, smoothstep(0.62, 1.0, v) * 0.8);
		if (v_row > 1.5 && v_row < 2.5) {
			// Coverts: a creamier gold, so the rows read apart.
			col = mix(col, gold_light.rgb, 0.3);
		}
		if (ring) {
			col = mix(gold.rgb, gold_light.rgb, 0.35);
		}
		// Soft cartoon shade from a fixed key light (view space), two sided.
		float lit = 0.8 + 0.28 * clamp(dot(n, normalize(vec3(-0.35, 0.7, 0.62))), -1.0, 1.0);
		col *= lit;
		// The vane: a few soft barb stripes slanting from the shaft.
		float barbs = 0.5 + 0.5 * sin((v * 16.0 - abs(u - 0.5) * 5.0) * 3.1416);
		col *= 1.0 - 0.06 * barbs * (1.0 - v);
		// The shaft: a fine white-gold line down the middle.
		float shaft = 1.0 - smoothstep(du * 0.6, du * 1.8, abs(u - 0.5));
		col = mix(col, gold_light.rgb * 1.08, shaft * 0.75 * (1.0 - 0.6 * v) * (ring ? 0.0 : 1.0));
		// The prismatic sweep: a white-hot glint with rainbow fringes running out along
		// the wing, feather by feather.
		float band = fract(v_flex * 1.1 + v * 0.1 - TIME * 0.2 + v_phase * 0.04);
		float core = smoothstep(0.1, 0.0, abs(band - 0.2));
		float fringe = smoothstep(0.24, 0.06, abs(band - 0.2)) - core * 0.6;
		vec3 hue = rainbow(0.42 + (band - 0.06) * 2.6 + v * 0.25);
		float k = prism * (ring ? 0.5 : 1.0);
		col = mix(col, hue * 1.15, clamp(fringe, 0.0, 1.0) * k * 0.42);
		col += vec3(1.0, 0.98, 0.9) * core * k * 0.55;
		// A pearl shimmer on the grazing edges, a glowing tip.
		float rim = pow(1.0 - facing, 2.2);
		col += mix(gold_light.rgb, rainbow(facing * 1.4 + TIME * 0.06 + v_phase), 0.45) * rim * 0.4;
		col += gold_light.rgb * smoothstep(0.72, 1.0, v) * (ring ? 0.0 : 0.38);
		// Ink outline along both edges (and so round the tip): a constant thin line.
		float e = min(u, 1.0 - u);
		float line = 1.0 - smoothstep(du * 1.1, du * 2.5, e);
		col = mix(col, ink.rgb, line * 0.92);
		ALBEDO = col * brightness;
	}
}
