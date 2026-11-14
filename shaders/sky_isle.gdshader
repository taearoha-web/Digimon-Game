shader_type spatial;
render_mode diffuse_burley, specular_disabled, cull_disabled;

// The moving pieces of เกาะลอยฟ้าเทพมังกร (SkyIsleArt), all opaque: no screen or depth
// texture, no transparency, no extra lights.
//   mode 0  a waterfall sheet: streaks of foam run down UV.y in lanes across UV.x
//   mode 1  the sea of cloud: lit a little by itself so the undersides stay bright
//   mode 2  a wind streamer: the strip flutters along UV.x (0 at the pole)
//   mode 3  the sky far below the clouds: its own colour, unlit
uniform int mode = 0;
varying float wup;

void vertex() {
	float phase = dot(MODEL_MATRIX[3].xz, vec2(0.37, 0.61));
	wup = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
	if (mode == 2) {
		float t = UV.x;
		VERTEX.z += sin(TIME * 3.3 + t * 7.0 + phase) * 0.16 * t;
		VERTEX.y += cos(TIME * 2.1 + t * 4.6 + phase) * 0.22 * t;
	} else if (mode == 1) {
		VERTEX.y += sin(TIME * 0.4 + phase) * 0.012;
	}
}

void fragment() {
	vec3 col = COLOR.rgb;
	if (mode == 0) {
		float lane = floor(UV.x * 9.0);
		float h = fract(sin(lane * 91.7 + 3.1) * 43758.5453);
		float run = fract(UV.y * (1.6 + h * 1.7) - TIME * (0.5 + h * 0.45) + h);
		float streak = smoothstep(0.0, 0.3, run) * (1.0 - smoothstep(0.3, 1.0, run));
		float side = abs(fract(UV.x * 9.0) - 0.5) * 2.0;
		col = mix(col, vec3(1.0), streak * 0.6 * (1.0 - side * 0.65));
		ALBEDO = col;
		EMISSION = col * 0.3;
	} else if (mode == 1) {
		// Sunlit tops, a rose shade underneath.
		float up = wup * 0.5 + 0.5;
		col *= mix(vec3(0.86, 0.74, 0.8), vec3(1.0), smoothstep(0.25, 0.75, up));
		ALBEDO = col;
		EMISSION = col * 0.3;
	} else if (mode == 3) {
		ALBEDO = vec3(0.0);
		EMISSION = col;
	} else {
		ALBEDO = col;
		EMISSION = col * 0.1;
	}
	ROUGHNESS = 1.0;
}
