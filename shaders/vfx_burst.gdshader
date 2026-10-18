shader_type spatial;
// A whole particle burst in one mesh and one draw call: every quad carries a
// random seed in COLOR, and the vertex shader moves and billboards it from
// `progress` (0 -> 1, driven by one tween). Nothing is simulated on the CPU.
// mode 0 = burst outwards with gravity (sparks, embers, leaves),
// mode 1 = rise from a disc and sway (motes, petals, light), mode 2 = fall (snow).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float progress = 0.0;
uniform int mode = 0;
uniform float speed = 4.0;
uniform float radius = 1.0;
uniform float size = 0.35;
uniform float gravity = 4.0;
uniform float rise = 0.4;
// Extra velocity shared by every card (debris thrown on along a blow).
uniform vec3 push = vec3(0.0);

varying float fade;

void vertex() {
	vec3 seed = COLOR.rgb * 2.0 - 1.0;
	float r = COLOR.a;
	// Each quad lives a slightly different share of the burst.
	float t = clamp(progress / (0.55 + 0.45 * r), 0.0, 1.0);
	vec3 p;
	if (mode == 0) {
		vec3 dir = normalize(seed + vec3(0.0, rise, 0.0) + vec3(0.0001));
		float s = speed * (0.45 + 0.55 * fract(r * 7.13));
		p = dir * s * (t - 0.5 * t * t) * 1.6 - vec3(0.0, gravity * t * t, 0.0) + push * (t - 0.5 * t * t) * 1.6;
	} else if (mode == 1) {
		vec2 disc = seed.xz * radius;
		float h = speed * t * (0.5 + r);
		p = vec3(disc.x + sin(t * 6.0 + r * 20.0) * 0.25, h, disc.y + cos(t * 5.0 + r * 13.0) * 0.25);
	} else {
		vec2 disc = seed.xz * radius;
		p = vec3(disc.x + sin(t * 4.0 + r * 9.0) * 0.4, speed * (1.0 - t) * (0.6 + 0.4 * r), disc.y);
	}
	vec3 center = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
	float grow = smoothstep(0.0, 0.12, t) * (1.0 - 0.45 * t);
	vec2 corner = (UV - 0.5) * size * (0.7 + 0.6 * fract(r * 3.7)) * grow;
	// Spin each card a little so they do not read as a grid.
	float a = r * 6.2831 + t * (r - 0.5) * 6.0;
	corner = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * corner;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(center + right * corner.x + up * corner.y, 1.0);
	fade = (1.0 - smoothstep(0.55, 1.0, t)) * step(0.001, t);
}

void fragment() {
	float a = texture(tex, UV).a;
	ALBEDO = color.rgb;
	ALPHA = a * fade * color.a;
}
