shader_type spatial;
// The light inside the Dragon God weapons (DragonGearArt): the glow surface's vertex
// colours, unshaded, with a pulse of pale gold running up the weapon over TIME (the
// spines, the mane, the pearl and the blade's edge light up in turn). motion = 0 holds
// it still (the lowest quality). No textures, no lights.
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float motion = 1.0;
uniform float speed = 2.4;
uniform float bands = 4.5;
varying float v_along;

void vertex() {
	v_along = VERTEX.y + VERTEX.x * 0.35;
}

void fragment() {
	float wave = 0.5 + 0.5 * sin(v_along * bands - TIME * speed * motion);
	float pulse = wave * wave * wave;
	float breathe = 0.5 + 0.5 * sin(TIME * 1.3 * motion);
	ALBEDO = COLOR.rgb * (0.8 + 0.12 * breathe + 0.2 * pulse) + vec3(1.0, 0.93, 0.62) * pulse * 0.3;
}
