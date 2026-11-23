shader_type spatial;
// The spirit orbs of an enhanced set from +10 (EnhanceFx._orbs): three soft orbs in the
// outfit's colour drifting slowly round the body, rising and sinking between the feet
// and the head, each with a white heart, a wide soft halo and a faint trail of fading
// motes behind it. One shared mesh of camera-facing quads (EnhanceFx._orb_mesh), all
// placed here from TIME: no script runs per frame.
// Per vertex: UV the quad corner, COLOR (orb 0..2 / 2, trail lag 0..1, part: 0 halo,
// 0.5 heart, 1 trail mote).
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

uniform vec4 color : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform float head = 1.85;
uniform float radius = 0.66;
uniform float speed = 1.0;
uniform float trail = 1.0;
uniform float size = 0.21;
uniform float energy = 1.0;
uniform float phase = 0.0;

varying vec2 v_uv;
varying float v_part;
varying float v_fade;
varying float v_twinkle;

vec3 orbit(float k, float t) {
	float ph = k * 2.0944 + phase;
	float a = t * 0.42 + ph;
	float rise = 0.5 + 0.5 * sin(t * (0.31 + 0.06 * k) + ph);
	float y = mix(0.22, head + 0.08, rise);
	// Wider round the big head, so an orb passing in front never sits on the face.
	float r = radius * (0.92 + 0.12 * sin(t * 0.7 + ph * 2.3)) * (1.0 + 0.3 * smoothstep(head * 0.62, head * 0.85, y));
	return vec3(cos(a) * r, y, sin(a) * r);
}

void vertex() {
	float k = floor(COLOR.r * 2.0 + 0.5);
	float lag = COLOR.g;
	float part = floor(COLOR.b * 2.0 + 0.5);
	float t = TIME * speed - lag * 1.1;
	vec3 c = orbit(k, t);
	vec3 v = (MODELVIEW_MATRIX * vec4(c, 1.0)).xyz;
	float sz = part < 0.5 ? size * 3.4 : (part < 1.5 ? size : size * (0.75 - 0.5 * lag) * trail);
	v.xy += (UV - 0.5) * sz;
	VERTEX = v;
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_uv = UV;
	v_part = part;
	v_fade = (1.0 - lag) * (1.0 - lag);
	v_twinkle = 0.86 + 0.14 * sin(TIME * 2.6 + k * 2.1);
}

void fragment() {
	float d = length(v_uv - 0.5) * 2.0;
	float soft = clamp(1.0 - d, 0.0, 1.0);
	vec3 col = color.rgb;
	float glow;
	float cover;
	if (v_part < 0.5) {
		glow = soft * soft * 0.42;
		cover = glow * 0.6;
	} else if (v_part < 1.5) {
		float heart = pow(soft, 3.0);
		glow = pow(soft, 1.3) * 1.1 * v_twinkle;
		col = mix(col, vec3(1.0), 0.75 * heart);
		cover = soft * 0.5;
	} else {
		glow = soft * soft * 0.5 * v_fade;
		cover = glow * 0.5;
	}
	if (glow <= 0.002) {
		discard;
	}
	ALBEDO = col * glow * energy;
	ALPHA = clamp(cover, 0.0, 0.9);
}
