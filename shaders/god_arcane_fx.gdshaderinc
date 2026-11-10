// Body of the god-tier light and smoke layers (god_glow adds, god_veil mixes): the
// mesh carries colour and opacity per vertex; noise scrolling over the UVs breaks it
// into fire, mist or sound, a radial falloff makes a soft sprite.
#include "god_arcane.gdshaderinc"
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity = 1.0;
uniform vec2 noise_scale = vec2(3.0, 2.0);
uniform vec2 flow = vec2(0.0, -1.5);
uniform float noise_amt = 0.0;
uniform float bias = 0.2;
uniform float taper = 1.3;
uniform float radial = 0.0;
uniform float fres = 0.0;
uniform vec4 hot : source_color = vec4(1.0);
uniform float heat = 0.0;
// The ragged edges the noise eats glow with the hot colour (fire).
uniform float edge_heat = 0.0;
uniform float flicker = 0.0;
uniform float sway = 0.0;
uniform bool billboard = false;
varying vec3 wn;
varying vec3 wp;

float fx_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float fx_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(fx_hash(i), fx_hash(i + vec2(1.0, 0.0)), u.x), mix(fx_hash(i + vec2(0.0, 1.0)), fx_hash(i + vec2(1.0)), u.x), u.y);
}

void vertex() {
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	god_move(v, n, vec4(COLOR.rgb, 0.0), UV2, CUSTOM0, CUSTOM1);
	float w = UV.y * UV.y * sway;
	v.x += sin(UV.y * 7.0 - age * 6.0 + UV.x * 19.0) * w;
	v.z += cos(UV.y * 6.0 - age * 5.2 + UV.x * 13.0) * w;
	VERTEX = v;
	NORMAL = n;
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
	wn = normalize((MODEL_MATRIX * vec4(n, 0.0)).xyz);
	wp = (MODEL_MATRIX * vec4(v, 1.0)).xyz;
}

void fragment() {
	float a = COLOR.a * opacity;
	float ragged = 0.0;
	if (radial > 0.0) a *= pow(clamp(1.0 - length(UV * 2.0 - 1.0), 0.0, 1.0), radial);
	if (noise_amt > 0.0) {
		float n = fx_noise(UV * noise_scale + flow * age) * 0.65 + fx_noise(UV * noise_scale * 2.3 + flow * age * 1.7 + 7.0) * 0.35;
		// Visible where the noise clears a cut that climbs with height: a solid foot, ragged tongues above.
		float m = smoothstep(-0.1, 0.14, n - (UV.y * taper - bias));
		ragged = (1.0 - smoothstep(0.35, 0.95, m)) * edge_heat;
		a *= mix(1.0, m, noise_amt);
	}
	if (fres > 0.0) a *= pow(abs(dot(normalize(wn), normalize(CAMERA_POSITION_WORLD - wp))), fres);
	a *= 1.0 - flicker * step(0.55, fract(age * 19.0 + UV.x * 3.0));
	a = clamp(a * fade, 0.0, 1.0);
	vec3 col = COLOR.rgb * tint.rgb;
	ALBEDO = mix(col, hot.rgb, clamp(heat * a * a + ragged, 0.0, 1.0));
	ALPHA = a;
}
