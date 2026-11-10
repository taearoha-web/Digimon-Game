shader_type spatial;
// God-tier melee debris (combat/god_art/_kit_melee.gd): rock chunks, dust, embers, dragon
// scales, shield fragments and falling feathers, a whole burst in one mesh and one draw.
// Every vertex sits on its piece's start point and carries the piece's flight: NORMAL is
// the corner's direction from the piece's centre and COLOR.a its distance (of `piece`),
// UV = velocity x/z, UV2 = (velocity y, delay). The vertex stage throws, spins, sways and
// lands the pieces. Pre-multiplied blend: `add` 1 is light (embers), 0 is solid matter.
render_mode unshaded, cull_disabled, depth_draw_never, blend_premul_alpha, fog_disabled;
uniform float fade = 1.0;
uniform float age = 0.0;
uniform float t0 = 0.0;
uniform float life = 1.2;
uniform float speed = 1.0;
uniform float gravity = 9.0;
uniform float drag = 0.0;
uniform float piece = 0.3;
uniform float spin = 6.0;
uniform float sway = 0.0;
uniform float floor_y = -100.0;
uniform float shrink = 0.7;
uniform float swell = 1.0;
uniform float alpha = 1.0;
uniform float add = 0.0;
uniform vec4 hot : source_color = vec4(1.0, 0.6, 0.2, 0.0);
varying float v_p;
varying float v_shade;

void vertex() {
	float lt = age - t0 - UV2.y;
	float p = lt / max(life, 0.01);
	v_p = lt < 0.0 ? 2.0 : p;
	vec3 vel = vec3(UV.x, UV2.x, UV.y) * speed;
	float h = fract(sin(dot(vel.xz + VERTEX.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float tt = max(lt, 0.0);
	vec3 pos = VERTEX + (drag > 0.0 ? vel * (1.0 - exp(-drag * tt)) / drag : vel * tt);
	pos.y -= 0.5 * gravity * tt * tt;
	pos.x += sin(tt * (2.0 + h * 2.0) + h * 6.28) * sway;
	pos.z += cos(tt * (1.7 + h * 2.0) + h * 4.0) * sway;
	float rest = step(pos.y, floor_y);
	pos.y = max(pos.y, floor_y);
	float ang = spin * (0.5 + h) * tt * (1.0 - rest) + h * 6.28;
	vec3 off = NORMAL * COLOR.a * piece;
	float c = cos(ang);
	float s = sin(ang);
	off = vec3(off.x, off.y * c - off.z * s, off.y * s + off.z * c);
	float c2 = cos(ang * 0.7);
	float s2 = sin(ang * 0.7);
	off = vec3(off.x * c2 + off.z * s2, off.y, -off.x * s2 + off.z * c2);
	float sc = (1.0 - smoothstep(shrink, 1.0, p)) * mix(1.0, swell, clamp(p, 0.0, 1.0));
	VERTEX = pos + off * sc;
	v_shade = 0.82 + 0.18 * sin(ang * 1.3 + h * 5.0);
}

void fragment() {
	if (v_p < 0.0 || v_p > 1.0) {
		discard;
	}
	float cool = 1.0 - v_p;
	vec3 col = COLOR.rgb * v_shade + hot.rgb * hot.a * cool * cool;
	float a = clamp(alpha * fade * mix(1.0, cool, add), 0.0, 1.0);
	ALBEDO = col * a;
	ALPHA = a * (1.0 - add);
}
