shader_type spatial;
// A pooled shockwave ring of the skill layer stack (SkillLayers): one flat quad
// on the ground, drawn from UV. It expands with an ease-out, its band thins and
// its wobbling edge fades as it goes; `gather` runs it inward (a wind-up that
// pulls light in), `ripples` adds trailing echoes (sound rings, tide foam).
// The leading edge is the palette's hot core, the trailing side its mid colour.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.6, 0.3, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform float progress = 0.0;
uniform float width = 0.16;
uniform float intensity = 0.85;
uniform float ripples = 0.0;
uniform float gather = 0.0;
uniform float seed = 0.0;

float band_at(float r, float rad, float w) {
	float d = r - rad;
	return exp(-(d * d) / max(w * w, 0.00001));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float t = clamp(progress, 0.0, 1.0);
	float e = gather > 0.5 ? 1.0 - t * t : 1.0 - pow(1.0 - t, 3.0);
	float rad = gather > 0.5 ? mix(0.95, 0.08, 1.0 - e) : mix(0.18, 0.95, e);
	float w = width * mix(0.55, 0.12, t);
	float ang = atan(p.y, p.x);
	float wobble = 0.03 * sin(ang * 7.0 + seed * 6.28 + t * 5.0) * sin(ang * 3.0 - seed * 3.0);
	float band = band_at(r + wobble, rad, w);
	float lead = smoothstep(-w, w * 0.6, (r + wobble - rad) * (gather > 0.5 ? -1.0 : 1.0));
	float echo = 0.0;
	if (ripples > 0.0) {
		for (int k = 1; k <= 2; k++) {
			float fk = float(k);
			echo += band_at(r + wobble, rad - fk * 0.17 * (gather > 0.5 ? -1.0 : 1.0), w * 0.7) * (0.55 / fk);
		}
		echo *= ripples;
	}
	float broken = 0.82 + 0.18 * sin(ang * 5.0 + seed * 11.0) * sin(ang * 3.0 - seed * 7.0 + t * 3.0);
	vec3 col = mix(color.rgb, core.rgb, lead * 0.65);
	float fade = pow(1.0 - t, 1.5) * smoothstep(0.0, 0.06, t + (gather > 0.5 ? 0.06 : 0.0));
	ALBEDO = col * intensity;
	ALPHA = clamp((band * broken + echo) * fade, 0.0, 1.0) * (1.0 - smoothstep(0.97, 1.0, r));
}
