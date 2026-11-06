// Shared particle card for the skill layer stack (SkillLayers). One quad per
// CPUParticles3D particle, faced to the camera here (no per-particle nodes):
//   stretch > 0  a streak along the particle's velocity (sparks, rain, wisps;
//                the emitter sets particle_flag_align_y)
//   dissolve     the card breaks up into noise islands as it ages (smoke, mist)
//   hot          a white-hot centre that cools with age (embers, sparks)
// Age comes from CPUParticles3D's custom data (y = time / lifetime), the spin
// from custom.x. WebGL2 / Compatibility safe: no screen or depth reads.
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float stretch = 0.0;
uniform float dissolve = 0.0;
uniform float hot = 0.0;
uniform float energy = 1.0;
uniform float alpha_gain = 1.0;
varying float v_life;
varying float v_seed;

float layer_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float layer_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(layer_hash(i), layer_hash(i + vec2(1.0, 0.0)), f.x),
		mix(layer_hash(i + vec2(0.0, 1.0)), layer_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec3 pos = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 back = normalize(INV_VIEW_MATRIX[2].xyz);
	mat4 world;
	if (stretch > 0.0) {
		vec3 up = MODEL_MATRIX[1].xyz;
		up = length(up) > 0.0001 ? normalize(up) : normalize(INV_VIEW_MATRIX[1].xyz);
		vec3 right = cross(up, back);
		right = length(right) > 0.001 ? normalize(right) : normalize(INV_VIEW_MATRIX[0].xyz);
		world = mat4(vec4(right * s, 0.0), vec4(up * s * stretch, 0.0), vec4(back * s, 0.0), vec4(pos, 1.0));
	} else {
		float c = cos(INSTANCE_CUSTOM.x);
		float sn = sin(INSTANCE_CUSTOM.x);
		vec3 r = normalize(INV_VIEW_MATRIX[0].xyz);
		vec3 u = normalize(INV_VIEW_MATRIX[1].xyz);
		world = mat4(vec4((r * c + u * sn) * s, 0.0), vec4((u * c - r * sn) * s, 0.0), vec4(back * s, 0.0), vec4(pos, 1.0));
	}
	MODELVIEW_MATRIX = VIEW_MATRIX * world;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_life = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);
	v_seed = fract(INSTANCE_CUSTOM.x * 0.1591 + INSTANCE_CUSTOM.z * 0.37 + pos.x * 0.13 + pos.z * 0.07);
}

void fragment() {
	vec4 t = texture(tex, UV);
	float a = t.a * COLOR.a * alpha_gain;
	if (dissolve > 0.0) {
		float n = layer_noise(UV * 4.5 + v_seed * 17.0) * 0.62 + layer_noise(UV * 10.0 - v_seed * 9.0) * 0.38;
		float cut = smoothstep(0.2, 1.0, v_life) * dissolve;
		a *= smoothstep(cut, cut + 0.2, n);
	}
	vec3 col = COLOR.rgb * mix(vec3(1.0), t.rgb, 0.4);
	float centre = 1.0 - smoothstep(0.0, 0.42, length(UV - vec2(0.5)));
	col = mix(col, vec3(1.0, 0.98, 0.92), centre * hot * (1.0 - v_life));
	ALBEDO = col * energy;
	ALPHA = clamp(a, 0.0, 1.0);
}
