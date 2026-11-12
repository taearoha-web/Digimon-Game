// The reward-shop costume pieces (CostumeArt): one vertex-colour mesh per bone.
// COLOR.rgb is the piece's sRGB colour; UV2.x is how free a vertex is to move
// (0 fixed to the body, 1 the tip of a tail or the hem of a cape) and UV2.y the
// phase of its piece, so tails, ribbons and capes sway on the GPU with no script.
// UV is the cloth's own (0..1 across and down) for the patterned sheets.
// Shared by costume_solid / costume_sheet and the outline pass (COSTUME_OUTLINE).

uniform vec3 sway_amp = vec3(0.0);
uniform float sway_speed = 1.6;
uniform float sway_lag = 2.0;

vec3 costume_sway(vec3 v, vec2 data, float time) {
	float f = data.x;
	if (f <= 0.0) {
		return v;
	}
	float t = time * sway_speed + data.y;
	float w = f * f;
	vec3 o = vec3(sin(t - f * sway_lag), sin(t * 1.3 - f * sway_lag + 1.1), sin(t * 0.85 - f * sway_lag + 2.0));
	return v + o * sway_amp * w;
}

#ifdef COSTUME_OUTLINE

uniform float width = 0.0045;
uniform vec4 line_color : source_color = vec4(0.188, 0.169, 0.275, 1.0);

void vertex() {
	VERTEX = costume_sway(VERTEX, UV2, TIME) + NORMAL * width;
}

void fragment() {
	ALBEDO = line_color.rgb;
}

#else

// The share of the colour that glows (1 = a lit gem or a halo).
uniform float glow = 0.0;
// Sheets: 0 plain, 1 night sky (twinkling star specks), 2 starlit (gold stars),
// 3 royal velvet; trim_width > 0 draws a border down the sides and along the hem.
uniform float pattern = 0.0;
uniform vec4 trim_color : source_color = vec4(1.0, 0.85, 0.4, 1.0);
uniform float trim_width = 0.0;
// Ermine (white fur with black tufts) inside the trim instead of a plain band.
uniform float ermine = 0.0;
uniform vec4 lining_color : source_color = vec4(0.2, 0.1, 0.15, 1.0);
uniform vec4 speck_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

varying vec3 tint;
varying vec2 cloth;

float costume_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	tint = pow(COLOR.rgb, vec3(2.2));
	cloth = UV;
	VERTEX = costume_sway(VERTEX, UV2, TIME);
}

void fragment() {
	vec3 c = tint;
	float lit = glow;
	if (pattern > 0.5) {
		// Specks on a grid, one in a few cells, twinkling.
		vec2 g = cloth * vec2(15.0, 22.0);
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		float h = costume_hash(id);
		vec2 o = vec2(costume_hash(id + 1.7), costume_hash(id + 5.3)) - 0.5;
		float d = length(f - o * 0.5);
		float tw = 0.55 + 0.45 * sin(TIME * (1.5 + h * 2.5) + h * 30.0);
		float keep = pattern < 1.5 ? step(0.62, h) : (pattern < 2.5 ? step(0.72, h) : 0.0);
		float star = smoothstep(0.16, 0.02, d) * keep * tw;
		float rays = smoothstep(0.045, 0.0, min(abs(f.x - o.x * 0.5), abs(f.y - o.y * 0.5))) * smoothstep(0.4, 0.0, d) * step(0.9, h) * tw;
		star = clamp(star + rays, 0.0, 1.0);
		c = mix(c, speck_color.rgb, star);
		lit += star * 1.2;
		if (pattern > 2.5) {
			// Velvet: a soft damask of diamonds.
			vec2 q = abs(fract(cloth * vec2(6.0, 9.0) + vec2(cloth.y * 6.0, 0.0)) - 0.5);
			c *= 1.0 - smoothstep(0.06, 0.0, abs(q.x + q.y - 0.42)) * 0.18;
		}
	}
	if (trim_width > 0.0) {
		float e = min(min(cloth.x, 1.0 - cloth.x) * 0.6, 1.0 - cloth.y);
		float band = 1.0 - smoothstep(trim_width - 0.006, trim_width, e);
		vec3 trim = trim_color.rgb;
		if (ermine > 0.5) {
			vec2 eg = cloth * vec2(9.0, 16.0);
			vec2 ef = fract(eg + vec2(0.5 * mod(floor(eg.y), 2.0), 0.0)) - 0.5;
			float tuft = smoothstep(0.12, 0.05, length(ef * vec2(1.6, 0.8)));
			trim = mix(trim, vec3(0.03), tuft);
		} else {
			lit += band * 0.15;
		}
		c = mix(c, trim, band);
	}
	if (!FRONT_FACING && pattern > 0.0) {
		c = mix(lining_color.rgb, c, 0.15);
		lit *= 0.3;
	}
	// A velvet sheen towards the edges of the view.
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	c *= 0.95 + 0.35 * fres;
	ALBEDO = c;
	EMISSION = c * lit;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	RIM = 0.25;
	RIM_TINT = 0.6;
}

#endif
