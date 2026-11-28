shader_type spatial;
// The ★500 melee ultimates' wind (combat/ascend_ult): the Warrior's updraft column
// (ดาบเหินฟ้า) and the Lancer's travelling storm round its thrown lance (หอกพายุบูมเมอแรง).
// An open cylinder or cone (CylinderMesh: UV.x round it, UV.y down it) painted with bands
// of wind that wind round it as a spiral and stream along it; brightest at the silhouette,
// soft at both ends. Additive light only: no texture, no screen or depth read.
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, fog_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform vec4 core : source_color = vec4(0.95, 1.0, 1.0, 1.0);
uniform float age = 0.0;
uniform float fade = 1.0;
// How the bands go round (turns a second) and along (lengths a second), and how steep.
uniform float spin = 1.6;
uniform float rise = 0.8;
uniform float twist = 1.4;
uniform float bands = 6.0;
// Soft ends: the share of the length that fades in at the top and at the bottom.
uniform float top_soft = 0.22;
uniform float foot_soft = 0.3;
uniform float gain = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float u = UV.x;
	float v = UV.y;
	// Two layers of spiral bands, one fast and thin, one slow and broad.
	float s1 = fract((u + v * twist) * bands - age * spin);
	float s2 = fract((u * 0.5 - v * twist * 0.6) * bands * 0.5 - age * spin * 0.55 + 0.37);
	float b1 = smoothstep(0.0, 0.12, s1) * (1.0 - smoothstep(0.18, 0.55, s1));
	float b2 = smoothstep(0.0, 0.3, s2) * (1.0 - smoothstep(0.35, 0.9, s2)) * 0.55;
	// Gusts streaming along the column break the bands up.
	float g = hash(vec2(floor(u * bands * 4.0), floor(v * 7.0 - age * rise * 7.0)));
	float band = max(b1 * (0.55 + 0.45 * g), b2);
	float ends = smoothstep(0.0, top_soft, v) * (1.0 - smoothstep(1.0 - foot_soft, 1.0, v));
	float rim = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))) * 0.55;
	float a = clamp(band * ends * rim * fade * gain, 0.0, 1.0);
	ALBEDO = mix(color.rgb, core.rgb, smoothstep(0.35, 0.95, b1)) * a;
	ALPHA = a;
}
