shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;
// Banners, noren curtains and stall awnings batched into one vertex-coloured
// surface. COLOR.a is how free each vertex is to move (0 at the pole or rod,
// 1 at the loose edge), written by JapanKit.Batch when the piece is added.

uniform float sway = 0.14;
uniform float wind_speed = 2.2;

varying vec3 cloth_color;

void vertex() {
	cloth_color = pow(COLOR.rgb, vec3(2.2));
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float free = COLOR.a;
	float front = sin(TIME * 0.3 + world.x * 0.02 + world.z * 0.015) * 0.5 + 0.5;
	float wave = sin(TIME * wind_speed + world.x * 0.8 + world.y * 1.6 + world.z * 0.5);
	float ripple = sin(TIME * wind_speed * 2.3 + world.y * 5.0 + world.x * 2.0) * 0.3;
	float amount = sway * free * free * (0.5 + front * 0.7);
	VERTEX.z += (wave + ripple) * amount;
	VERTEX.x += cos(TIME * wind_speed * 0.7 + world.z * 1.1) * amount * 0.35;
}

void fragment() {
	ALBEDO = cloth_color;
	ROUGHNESS = 1.0;
}
