shader_type spatial;
// The light of two Ascension ultimates (combat/ascend_ult): the archer's เลนส์ตะวัน (its
// sun beam, golden lens, scorched line) and the mage's ประตูมิติร้อยบาน (its portals).
// Additive and unshaded, so it glows on grass and snow alike and costs one pass.
//   mode 0  beam: an open cylinder (UV.y along it); hot core where it faces the camera,
//           heat scrolling along it
//   mode 1  lens: a flattened sphere (poles on its axis); a gold rim, concentric ripples
//   mode 2  ground strip: a plane (UV.x across, UV.y along); soft edges, smouldering heat
//   mode 3  portal: a quad; a ring of runes round a swirling element core
//   mode 4  glow: a quad (billboard with `billboard`); a soft orb, `rays` sun spikes
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform vec4 core : source_color = vec4(1.0, 1.0, 0.9, 1.0);
uniform vec4 shade : source_color = vec4(0.6, 0.2, 0.05, 1.0);
uniform int mode = 0;
uniform bool billboard = false;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;
uniform float flow = 3.0;
uniform float span = 10.0;
uniform float rays = 0.0;
uniform float strength = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	float t = TIME * flow + seed;
	float a = 0.0;
	vec3 rgb = color.rgb;
	if (mode == 0) {
		float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
		float n = noise(vec2(UV.x * 6.0 + seed, UV.y * span * 0.8 - t)) * 0.6 + noise(vec2(UV.x * 13.0 - seed, UV.y * span * 1.9 - t * 1.6)) * 0.4;
		float body = pow(facing, 1.6);
		float hot = pow(facing, 5.0);
		// Both faces of the open shaft add up: keep each under half.
		a = body * (0.45 + 0.55 * n) * 0.55;
		rgb = mix(color.rgb, core.rgb, clamp(hot * (0.6 + 0.4 * n) * 1.2, 0.0, 1.0));
	} else if (mode == 1) {
		float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
		float rim = pow(1.0 - facing, 2.2);
		float r = 1.0 - abs(UV.y - 0.5) * 2.0;
		float ripple = 0.5 + 0.5 * sin(r * 26.0 - t * 1.6);
		float glint = smoothstep(0.85, 1.0, sin(UV.x * 6.2832 + t * 0.7)) * (1.0 - rim);
		a = 0.12 + rim * 0.75 + ripple * 0.08 + glint * 0.35;
		rgb = mix(core.rgb, color.rgb, clamp(rim * 1.3, 0.0, 1.0));
	} else if (mode == 2) {
		float across = 1.0 - abs(UV.x * 2.0 - 1.0);
		float soft = smoothstep(0.0, 0.7, across);
		float n = noise(vec2(UV.x * 4.0 + seed, UV.y * span * 1.2 - t * 0.5)) * 0.65 + noise(vec2(UV.x * 9.0, UV.y * span * 3.0 + t)) * 0.35;
		a = soft * (0.25 + 0.55 * n) * 0.8;
		rgb = mix(shade.rgb, mix(color.rgb, core.rgb, smoothstep(0.55, 1.0, across * n)), smoothstep(0.2, 0.7, n));
	} else if (mode == 3) {
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		if (r > 1.0) {
			discard;
		}
		float ang = atan(p.y, p.x);
		float swirl = noise(vec2(ang * 2.0 + r * 7.0 - t, r * 5.0 + seed)) * 0.65 + noise(vec2(ang * 5.0 - r * 11.0 + t * 1.4, seed)) * 0.35;
		float ring = smoothstep(0.74, 0.8, r) * (1.0 - smoothstep(0.92, 1.0, r));
		float runes = step(0.55, fract(ang / 6.2832 * 18.0 + t * 0.05)) * smoothstep(0.82, 0.85, r) * (1.0 - smoothstep(0.9, 0.93, r));
		float inner = 1.0 - smoothstep(0.0, 0.78, r);
		float eye = 1.0 - smoothstep(0.0, 0.28, r);
		a = ring * 0.85 + runes * 0.6 + inner * swirl * 0.75 + eye * 0.5;
		rgb = mix(core.rgb, shade.rgb, clamp(inner * swirl * 1.4, 0.0, 1.0));
		rgb = mix(rgb, color.rgb, clamp(ring + runes, 0.0, 1.0));
		rgb = mix(rgb, vec3(1.0), eye * 0.6);
	} else {
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		float orb = pow(max(1.0 - r, 0.0), 2.2);
		float ang = atan(p.y, p.x);
		float spikes = rays * pow(abs(cos(ang * 6.0 + t * 0.1)), 24.0) * max(1.0 - r, 0.0) * 0.8;
		a = orb + spikes;
		rgb = mix(color.rgb, core.rgb, clamp(pow(max(1.0 - r, 0.0), 4.0) * 1.6, 0.0, 1.0));
	}
	ALBEDO = rgb;
	ALPHA = clamp(a * strength, 0.0, 1.0) * fade * color.a;
}
