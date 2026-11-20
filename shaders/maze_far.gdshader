shader_type spatial;
render_mode world_vertex_coords, diffuse_toon, specular_disabled, cull_disabled, fog_disabled;
// The world round เขาวงกตหนึ่งในใต้หล้า (MazeArena): the isle's cliffs, the sea of cloud,
// the far ranges, the floating isles with their prang towers and their falls. Opaque,
// vertex-coloured, no textures, no lights.
// Far pieces are drawn hundreds of metres out, past the play camera's far plane: each
// vertex is slid along its own line of sight to within `keep` + `span` metres of the
// camera, which changes nothing on screen but the depth (a direction from the eye is all
// a perspective picture keeps), so the panorama is never cut by the far plane. The air
// between is put back by hand: a haze by the true distance (the zone's fog is off here).
//   mode 0  lit rock, grass and stone
//   mode 1  cloud: self-lit, a rose shade underneath
//   mode 2  falling water: streaks of foam run down UV.y
//   mode 3  glow: unlit, bright (tower tips, windows, gems)
uniform int mode = 0;
uniform float keep = 190.0;
uniform float span = 55.0;
uniform vec4 haze : source_color = vec4(0.95, 0.7, 0.66, 1.0);
uniform float haze_start = 150.0;
uniform float haze_range = 700.0;
uniform float haze_max = 0.8;
varying float true_dist;
varying float wup;

void vertex() {
	vec3 eye = INV_VIEW_MATRIX[3].xyz;
	vec3 rel = VERTEX - eye;
	float d = length(rel);
	true_dist = d;
	if (d > keep) {
		float nd = keep + span * (1.0 - exp(-(d - keep) / (span * 4.0)));
		VERTEX = eye + rel * (nd / d);
	}
	wup = NORMAL.y;
	if (mode == 1) {
		VERTEX.y += sin(TIME * 0.35 + dot(VERTEX.xz, vec2(0.013, 0.021))) * 0.25;
	}
}

void fragment() {
	vec3 col = COLOR.rgb;
	float h = clamp((true_dist - haze_start) / haze_range, 0.0, 1.0);
	h = pow(h, 0.75) * haze_max;
	if (mode == 0) {
		ALBEDO = col * (1.0 - h);
		EMISSION = haze.rgb * h + col * 0.06;
	} else if (mode == 1) {
		float up = wup * 0.5 + 0.5;
		col *= mix(vec3(0.82, 0.68, 0.82), vec3(1.0), smoothstep(0.2, 0.8, up));
		ALBEDO = col * 0.62 * (1.0 - h);
		EMISSION = col * 0.32 * (1.0 - h) + haze.rgb * h;
	} else if (mode == 2) {
		float lane = floor(UV.x * 7.0);
		float k = fract(sin(lane * 91.7 + 3.1) * 43758.5453);
		float run = fract(UV.y * (1.4 + k * 1.6) - TIME * (0.55 + k * 0.5) + k);
		float streak = smoothstep(0.0, 0.3, run) * (1.0 - smoothstep(0.3, 1.0, run));
		col = mix(col, vec3(1.0), streak * 0.55);
		ALBEDO = col * 0.6 * (1.0 - h);
		EMISSION = col * 0.45 * (1.0 - h) + haze.rgb * h;
	} else {
		ALBEDO = vec3(0.0);
		EMISSION = col * (1.6 - h);
	}
	ROUGHNESS = 1.0;
}
