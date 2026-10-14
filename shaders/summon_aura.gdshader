shader_type spatial;
// The sparkle that lives around a summoned spirit, in one mesh and one draw call:
// every card carries a random seed in COLOR and the vertex shader loops it
// forever from TIME, so nothing is simulated on the CPU.
// mode 0 = orbit the body, 1 = rise from the feet, 2 = spiral upwards, 3 = drift down.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform int mode = 0;
uniform float body_height = 1.8;
uniform float body_radius = 0.9;
uniform float base_height = 0.0;
uniform float size = 0.3;
uniform float speed = 1.0;

varying float fade;

void vertex() {
	vec3 seed = COLOR.rgb;
	float r = COLOR.a;
	float t = TIME * speed;
	vec3 p;
	float alpha = 1.0;
	if (mode == 0) {
		float ang = t * (0.8 + 1.2 * seed.x) * (seed.y > 0.5 ? 1.0 : -1.0) + r * 6.2831;
		float rad = body_radius * (0.75 + 0.5 * seed.z);
		float h = base_height + body_height * (0.08 + 0.9 * fract(seed.y * 3.7 + 0.12 * sin(t * 0.7 + r * 9.0)));
		p = vec3(cos(ang) * rad, h, sin(ang) * rad);
		alpha = 0.45 + 0.55 * (0.5 + 0.5 * sin(t * 4.0 + r * 40.0));
	} else if (mode == 1) {
		float life = fract(t * (0.22 + 0.25 * seed.x) + r);
		vec2 disc = (seed.yz * 2.0 - 1.0) * body_radius * 0.8;
		p = vec3(disc.x + sin(life * 6.0 + r * 20.0) * 0.18, base_height + life * body_height * 1.25, disc.y + cos(life * 5.0 + r * 13.0) * 0.18);
		alpha = sin(life * 3.14159);
	} else if (mode == 2) {
		float life = fract(t * (0.18 + 0.12 * seed.x) + r);
		float ang = life * 12.566 + r * 6.2831;
		float rad = body_radius * (0.55 + 0.45 * life) * (0.8 + 0.4 * seed.y);
		p = vec3(cos(ang) * rad, base_height + life * body_height * 1.3, sin(ang) * rad);
		alpha = sin(life * 3.14159);
	} else {
		float life = fract(t * (0.12 + 0.1 * seed.x) + r);
		vec2 disc = (seed.yz * 2.0 - 1.0) * body_radius;
		p = vec3(disc.x + sin(life * 7.0 + r * 11.0) * 0.3, base_height + body_height * 1.4 * (1.0 - life), disc.y + cos(life * 6.0 + r * 17.0) * 0.3);
		alpha = sin(life * 3.14159);
	}
	vec3 center = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
	float scale = length(MODEL_MATRIX[0].xyz);
	vec2 corner = (UV - 0.5) * size * scale * (0.6 + 0.8 * fract(r * 5.3)) * (0.5 + 0.5 * alpha);
	float a = r * 6.2831 + t * (seed.x - 0.5) * 2.0;
	corner = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * corner;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(center + right * corner.x + up * corner.y, 1.0);
	fade = alpha;
}

void fragment() {
	float a = texture(tex, UV).a;
	ALBEDO = color.rgb;
	ALPHA = a * fade * color.a;
}
