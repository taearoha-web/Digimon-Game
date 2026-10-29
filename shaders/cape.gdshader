shader_type spatial;
// The Dark Lord's cape (CapeArt). The mesh is only a UV grid: the vertex stage
// builds the cloth from UV (x across, y down) so the pleats, the walk ripple, the
// streaming while flying (billow) and the gathering up (fold) all come with true
// normals, and the toon light shades every pleat. Three kinds of layer:
//   kind 0  the long cape: flaring from the shoulders, deep pleats, a curved hem
//   kind 1  the capelet over the shoulders, its hem cut into feather scallops
//   kind 2  the standing collar behind the neck
// Two styles: 0 royal (Lv.100: crimson velvet, gold filigree, a raven crest) and
// 1 star (100 stars: galaxy cloth with twinkling stars, a crowned raven on a gold
// sunburst, a hem of glowing raven feathers, an indigo feather mantle).
render_mode cull_disabled, diffuse_toon, specular_disabled;

uniform vec4 outer_color : source_color = vec4(0.56, 0.11, 0.16, 1.0);
uniform vec4 outer_deep : source_color = vec4(0.32, 0.05, 0.09, 1.0);
uniform vec4 lining_color : source_color = vec4(0.08, 0.05, 0.06, 1.0);
uniform vec4 trim_color : source_color = vec4(0.91, 0.71, 0.29, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.75, 0.95, 1.0);
uniform float kind = 0.0;
uniform float style = 0.0;
uniform float top_y = 0.79;
uniform float back_z = -0.11;
uniform float behind = 0.0;
uniform float top_width = 0.4;
uniform float hem_width = 0.78;
uniform float cape_length = 0.76;
uniform float hem_curve = 0.06;
uniform float wrap = 0.12;
uniform float fold_depth = 0.05;
uniform float folds = 4.5;
uniform float crest = 1.0;
uniform float feather_len = 0.0;
uniform float scallop = 0.0;
uniform float phase = 0.0;
// How much of the flying stream this layer takes (the capelet sits closer).
uniform float stiff = 1.0;
uniform float billow = 0.15;
uniform float fold = 0.0;

varying vec2 cloth;
varying float pleat_shade;



// The cloth surface at a UV point, at time t.
vec3 shape(vec2 uv, float t) {
	float s = uv.x * 2.0 - 1.0;
	float v = uv.y;
	if (kind > 1.5) {
		// The collar: an arc behind the neck, flaring outwards as it rises.
		float a = s * 1.45;
		float rise = 1.0 - v;
		float r = mix(top_width, hem_width, rise * rise);
		vec3 c;
		c.x = sin(a) * r;
		c.z = back_z + 0.1 - cos(a) * r - rise * 0.03;
		c.y = top_y - 0.02 + rise * cape_length * (1.0 - fold * 0.6);
		return c;
	}
	// Stowed: the cloth rolls up towards the shoulders and draws in.
	// The normal is found from neighbours a step past the edges (v < 0 above the
	// shoulders): pow() of a negative number is NaN on Apple GPUs, and a NaN normal
	// broke whole frames on iPhones, so every base below is kept at or above zero.
	float vv = max(v, 0.0) * (1.0 - fold * 0.82);
	float flare = pow(vv, 0.8);
	float half_w = mix(top_width, hem_width, flare) * 0.5 * mix(1.0, 0.62, fold * v);
	float len = cape_length * (1.0 + hem_curve * (1.0 - s * s));
	vec3 p;
	p.x = s * half_w;
	p.y = top_y - vv * len;
	// Hugging the shoulders at the top, hanging clear of the back lower down.
	float hug = 1.0 - smoothstep(0.0, 0.5, vv);
	p.z = back_z - behind + s * s * wrap * hug - (1.0 - s * s) * 0.03 * hug - vv * 0.06 * cape_length;
	// Pleats, deeper towards the hem and swaying slowly.
	float depth = (0.003 + fold_depth * pow(smoothstep(0.08, 1.0, vv), 1.1)) * (1.0 - fold * 0.8);
	float sway = sin(t * 0.7 + vv * 2.4 + phase) * 0.45;
	float pleat = sin((s * 0.5 + 0.5) * folds * 2.0 * PI + sway);
	p.z -= depth * pleat;
	p.y += depth * 0.45 * pleat * smoothstep(0.7, 1.0, vv);
	// A ripple running down the cloth, stronger near the hem and when flying.
	float wave = sin(t * 2.0 - vv * 6.0 + s * 1.5) * 0.5 + sin(t * 3.1 - vv * 9.0 - s * 2.5) * 0.25;
	float reach = pow(vv, 1.4);
	p.z -= reach * (0.02 + billow * 0.06 * stiff) * wave * (1.0 - fold);
	p.x += reach * 0.012 * sin(t * 1.7 + vv * 4.0) * (1.0 - fold);
	// Streaming back and lifting while flying, the hem flaring wider.
	float stream = billow * (1.0 - fold) * stiff;
	// The long cape streams from below the capelet, so it never cuts through it.
	float from = kind < 0.5 ? clamp((vv - 0.2) / 0.8, 0.0, 1.0) : max(vv, 0.0);
	p.z -= stream * pow(from, 1.3) * len * 0.85;
	p.y += stream * pow(from, 2.0) * len * 0.45;
	p.x *= 1.0 + stream * vv * 0.3;
	return p;
}

void vertex() {
	float t = TIME * (1.6 + billow * 2.4);
	vec3 p = shape(UV, t);
	vec3 pu = shape(UV + vec2(0.01, 0.0), t) - shape(UV - vec2(0.01, 0.0), t);
	vec3 pv = shape(UV + vec2(0.0, 0.01), t) - shape(UV - vec2(0.0, 0.01), t);
	VERTEX = p;
	vec3 n = cross(pu, pv);
	NORMAL = dot(n, n) > 1e-12 ? normalize(n) : vec3(0.0, 0.0, -1.0);
	cloth = UV;
	float s = UV.x * 2.0 - 1.0;
	float sway = sin(t * 0.7 + UV.y * 2.4 + phase) * 0.45;
	pleat_shade = kind > 1.5 ? 1.0 : sin((s * 0.5 + 0.5) * folds * 2.0 * PI + sway) * smoothstep(0.0, 0.5, UV.y);
}

float hash1(float n) {
	return fract(sin(n * 91.3458) * 47453.5453);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float a = 0.5;
	float sum = 0.0;
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 4; i++) {
		sum += a * noise(p);
		p = turn * p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return sum / 0.9375;
}

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

// A heraldic raven, displayed: wings raised with five long fingered flight
// feathers each, head turned in profile with a heavy beak and shaggy throat, a
// wedge-shaped tail and open talons. About 0.4 wide, centred on its body;
// negative inside.
float raven(vec2 p) {
	vec2 q = vec2(abs(p.x), p.y);
	float d = (length((p - vec2(0.0, -0.01)) / vec2(0.045, 0.088)) - 1.0) * 0.045;
	d = smin(d, length(p - vec2(0.008, 0.098)) - 0.036, 0.02);
	// The heavy beak, facing right, and the shaggy throat under it.
	d = min(d, seg(p, vec2(0.03, 0.102), vec2(0.074, 0.094)) - 0.013);
	d = min(d, seg(p, vec2(0.074, 0.094), vec2(0.084, 0.088)) - 0.006);
	d = smin(d, seg(p, vec2(0.02, 0.072), vec2(0.03, 0.058)) - 0.012, 0.01);
	// Wings: a raised leading edge with feathers hanging and spreading from it.
	vec2 sh = vec2(0.032, 0.046);
	vec2 tip = vec2(0.158, 0.148);
	float w = seg(q, sh, tip) - 0.024;
	for (int i = 0; i < 6; i++) {
		float k = float(i) / 5.0;
		vec2 root = mix(sh + vec2(0.012, -0.004), tip, k);
		float ang = mix(-1.75, 0.25, k);
		float l = mix(0.1, 0.075, abs(k - 0.55) * 1.6) + k * 0.02;
		vec2 end = root + vec2(cos(ang), sin(ang)) * l;
		w = smin(w, seg(q, root, end) - mix(0.022, 0.016, k), 0.014);
	}
	// Fill the wing between the leading edge and the inner feathers.
	float web = max(seg(q, vec2(0.05, 0.03), vec2(0.12, 0.08)) - 0.045, -(q.y + 0.03));
	w = smin(w, web, 0.02);
	d = smin(d, w, 0.012);
	// The wedge-shaped tail: the middle feathers longest.
	for (int j = 0; j < 5; j++) {
		float a = -PI * 0.5 + (float(j) - 2.0) * 0.16;
		vec2 root = vec2(0.0, -0.08);
		d = min(d, seg(p, root, root + vec2(cos(a), sin(a)) * (0.11 - abs(float(j) - 2.0) * 0.016)) - 0.014);
	}
	// Legs and open talons.
	float leg = seg(q, vec2(0.026, -0.06), vec2(0.056, -0.098)) - 0.009;
	leg = min(leg, seg(q, vec2(0.056, -0.098), vec2(0.082, -0.104)) - 0.005);
	leg = min(leg, seg(q, vec2(0.056, -0.098), vec2(0.06, -0.126)) - 0.005);
	leg = min(leg, seg(q, vec2(0.056, -0.098), vec2(0.038, -0.118)) - 0.005);
	return min(d, leg);
}

// Gold that reads as metal under the toon light: a bright ridge along the middle
// of a band (x 0..1 across it) and darker edges.
vec3 gold(vec3 base, float x) {
	float ridge = 1.0 - abs(x * 2.0 - 1.0);
	return base * (0.62 + 0.62 * pow(max(ridge, 0.0), 0.7));
}

// The star cape's cloth: deep space with drifting nebula and twinkling stars.
vec3 galaxy(vec2 p, out float sparkle) {
	vec2 q = p * vec2(4.0, 3.4);
	// Domain-warped clouds, so the nebula drifts in soft wisps.
	vec2 warp = vec2(fbm(q + vec2(0.0, TIME * 0.04)), fbm(q + vec2(5.2, 1.3) - vec2(TIME * 0.03, 0.0)));
	float n = fbm(q + warp * 1.6);
	vec3 c = mix(outer_deep.rgb, outer_color.rgb, smoothstep(0.2, 0.8, n));
	float neb = smoothstep(0.5, 0.85, fbm(q * 0.8 + warp * 2.2 + vec2(3.0, 0.0)));
	c = mix(c, glow_color.rgb * 0.6, neb * 0.4);
	vec2 g = p * vec2(48.0, 44.0);
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash2(id);
	vec2 o = vec2(hash2(id + 1.3), hash2(id + 7.1)) - 0.5;
	float d = length(f - o * 0.6);
	float tw = 0.45 + 0.55 * sin(TIME * (2.0 + h * 3.0) + h * 40.0);
	sparkle = smoothstep(0.13, 0.0, d) * step(0.78, h) * tw;
	float cross_ray = smoothstep(0.05, 0.0, min(abs(f.x - o.x * 0.6), abs(f.y - o.y * 0.6))) * smoothstep(0.35, 0.0, d) * step(0.95, h) * tw;
	sparkle += cross_ray * 0.8;
	return c;
}

void fragment() {
	float u = cloth.x;
	float v = cloth.y;
	float s = u * 2.0 - 1.0;
	vec3 gold_c = trim_color.rgb;
	vec3 col;
	float glow = 0.0;
	vec3 glow_rgb = gold_c;
	float tw = 0.022;
	if (kind > 1.5) {
		// The collar's top edge rises in points.
		float tooth = pow(abs(fract(u * 7.0) - 0.5) * 2.0, 0.7);
		if (v < 0.22 * tooth) {
			discard;
		}
		// The collar: velvet facing out, gold at the rim and down the edges.
		float rim = smoothstep(0.2, 0.12, v - 0.22 * tooth);
		float edge = 1.0 - smoothstep(0.04, 0.07, min(u, 1.0 - u));
		col = style > 0.5 ? gold(gold_c, v) : outer_deep.rgb * 0.8;
		col = mix(col, gold(gold_c, fract((1.0 - v) * 4.0)), max(rim, edge));
		if (style > 0.5) {
			// Gold plates with a violet gem row.
			float gem = smoothstep(0.03, 0.0, length(vec2(fract(u * 7.0) - 0.5, (v - 0.45) * 2.4)) - 0.12);
			col = mix(col, glow_color.rgb, gem);
			glow += gem * 1.4 + rim * 0.3;
			glow_rgb = mix(gold_c, glow_color.rgb, gem);
		}
		if (!FRONT_FACING) {
			col = mix(lining_color.rgb, gold_c, rim);
			glow = 0.0;
		}
		ALBEDO = col;
		EMISSION = glow_rgb * glow;
	} else {
		float flare = pow(max(v, 0.0), 0.8);
		float width_here = mix(top_width, hem_width, flare);
		float len_here = cape_length * (1.0 + hem_curve * (1.0 - s * s));
		float e_side = min(u, 1.0 - u) * width_here;
		float e_hem = (1.0 - v) * len_here;
		vec2 dp = vec2((u - 0.5) * width_here, -v * len_here);
		// Hem cut-outs: raven feathers for the star cape, rounded scallops for the capelet.
		float band_at = 0.0;
		float feather_paint = 0.0;
		float feather_x = 0.0;
		float feather_h = 1.0;
		if (feather_len > 0.0 || scallop > 0.0) {
			float n = scallop > 0.0 ? scallop : 13.0;
			float cell = u * n;
			float idx = floor(cell);
			float fx = fract(cell) - 0.5;
			float flen = scallop > 0.0 ? 0.055 : feather_len * mix(0.82, 1.08, hash1(idx + 2.0)) * (mod(idx, 2.0) < 0.5 ? 1.0 : 0.86);
			float h = e_hem / flen;
			float hw = scallop > 0.0 ? 0.5 * sqrt(clamp(h * 1.8, 0.0, 1.0)) : 0.5 * pow(clamp(h * 1.25, 0.0, 1.0), 0.55);
			if (h < 1.0 && abs(fx) > hw) {
				discard;
			}
			band_at = scallop > 0.0 ? 0.055 : feather_len * 1.08;
			if (h < 1.0) {
				feather_paint = 1.0;
				feather_x = fx / max(hw, 0.001);
				feather_h = h;
			}
		}
		// The cloth.
		float sparkle = 0.0;
		if (style > 0.5 && kind < 0.5) {
			col = galaxy(dp * 1.6, sparkle);
			glow += sparkle * 1.6;
		} else {
			col = mix(outer_color.rgb * 1.08, outer_deep.rgb, smoothstep(0.0, 1.0, v));
		}
		if (kind > 0.5) {
			// The capelet: rows of feather scales, outlined in gold.
			float rows = 7.0;
			float rv = dp.y * -rows / max(cape_length, 0.01);
			float row = floor(rv);
			float ru = u * scallop + (mod(row, 2.0) < 0.5 ? 0.0 : 0.5);
			vec2 cell_p = vec2(fract(ru) - 0.5, fract(rv));
			float scale_d = length(cell_p * vec2(1.0, 1.25));
			float scale_line = smoothstep(0.07, 0.0, abs(scale_d - 0.5));
			// Each scale lighter towards its rounded lower edge, like a feather catching light.
			col = mix(outer_deep.rgb, outer_color.rgb, smoothstep(0.15, 0.5, scale_d)) * mix(0.8, 1.15, smoothstep(0.0, 1.0, fract(rv)));
			col = mix(col, gold(gold_c, 0.5), scale_line * 0.9);
			glow += scale_line * 0.45 * style;
		}
		// Velvet sheen at grazing angles.
		float fres = pow(max(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 0.0), 2.0);
		col *= 0.92 + 0.5 * fres;
		// Deeper shade inside the pleats.
		col *= mix(0.78, 1.04, pleat_shade * 0.5 + 0.5);
		// Gold trim down the sides (and along the hem, or above the feathers).
		float e_band = band_at > 0.0 ? abs(e_hem - band_at) : e_hem;
		float e = min(e_side, e_band);
		float trim = 1.0 - smoothstep(tw - 0.003, tw, e);
		vec3 trim_col = gold(gold_c, clamp(e / tw, 0.0, 1.0));
		// Filigree inside the trim: a chain of diamonds and dots.
		float fil = 0.0;
		if (kind < 0.5) {
			float band_x = (e_side - (tw + 0.02)) / 0.012;
			float along = fract(-dp.y * 15.0);
			float dia = abs(band_x) + abs(along - 0.5) * 1.6;
			fil = (smoothstep(0.62, 0.52, dia) - smoothstep(0.42, 0.32, dia)) * step(abs(band_x), 1.2);
			fil += smoothstep(0.2, 0.1, length(vec2(band_x * 0.5, (along - 0.0) * 1.2))) * step(abs(band_x), 1.0);
			float hem_x = (e_band - (tw + 0.02)) / 0.012;
			float along_h = fract(dp.x * 15.0);
			float dia_h = abs(hem_x) + abs(along_h - 0.5) * 1.6;
			fil += (smoothstep(0.62, 0.52, dia_h) - smoothstep(0.42, 0.32, dia_h)) * step(abs(hem_x), 1.2) * step(tw * 2.0, e_side);
			fil = clamp(fil, 0.0, 1.0) * step(tw * 1.5, e);
		}
		col = mix(col, gold(gold_c, 0.55), fil * 0.9);
		// A thin dark line where the trim meets the cloth.
		float seam = smoothstep(0.004, 0.0, abs(e - tw)) * (1.0 - trim);
		col = mix(col, trim_col * 0.35, seam);
		col = mix(col, trim_col, trim);
		glow += (trim * 0.28 + fil * 0.45) * style;
		// The raven feathers of the star hem: violet into a glowing tip, a gold shaft and barbs.
		if (feather_paint > 0.5 && kind < 0.5) {
			float tipness = 1.0 - smoothstep(0.0, 0.75, feather_h);
			vec3 fcol = mix(outer_color.rgb * 1.3, glow_color.rgb, tipness);
			float barb = smoothstep(0.25, 0.0, abs(fract(feather_h * 7.0 + abs(feather_x) * 1.6) - 0.5)) * 0.25;
			fcol *= 1.0 - barb;
			float shaft = smoothstep(0.12, 0.0, abs(feather_x));
			float rim = smoothstep(0.75, 1.0, abs(feather_x));
			fcol = mix(fcol, gold_c * 1.1, max(shaft, rim * 0.8));
			col = fcol;
			glow += tipness * 1.3 + shaft * 0.5 + rim * 0.4;
			glow_rgb = mix(gold_c, glow_color.rgb, tipness);
		}
		// Capelet scallop edges, outlined in gold.
		if (feather_paint > 0.5 && kind > 0.5) {
			float rim = smoothstep(0.62, 0.9, abs(feather_x)) + smoothstep(0.35, 0.0, feather_h);
			col = mix(col, gold(gold_c, 0.5), clamp(rim, 0.0, 1.0));
			glow += rim * 0.3 * style;
		}
		// The crest on the back.
		if (crest > 0.5 && kind < 0.5) {
			vec2 c = (dp - vec2(0.0, -0.47 * cape_length)) / 0.72;
			float hd = raven(c);
			float aa = fwidth(hd) * 1.2;
			float body = 1.0 - smoothstep(-aa, aa, hd);
			float outline = smoothstep(aa + 0.004, 0.0, abs(hd + 0.002)) * (1.0 - body * 0.3);
			// Emboss: lit from the upper left.
			vec2 grad = vec2(dFdx(hd), dFdy(hd));
			float lit = clamp(0.5 + dot(normalize(grad + vec2(1e-6)), vec2(-0.6, 0.8)) * 0.5, 0.0, 1.0);
			vec3 raven_col = gold_c * mix(0.72, 1.08, lit) * mix(1.0, 0.82, smoothstep(-0.02, 0.0, hd));
			float ring = abs(length(c - vec2(0.0, 0.02)) - 0.215) - 0.007;
			float ring_mask = 1.0 - smoothstep(0.0, fwidth(ring) * 1.5, ring);
			float dots = smoothstep(0.012, 0.004, length(vec2(fract(atan(c.y - 0.02, c.x) / (2.0 * PI) * 24.0) - 0.5, (length(c - vec2(0.0, 0.02)) - 0.24) * 30.0)));
			if (style > 0.5) {
				// A gold sunburst behind the crowned raven.
				float ang = atan(c.y - 0.02, c.x);
				float rays = smoothstep(0.35, 0.0, abs(fract(ang / (2.0 * PI) * 16.0) - 0.5)) * smoothstep(0.2, 0.06, length(c)) * smoothstep(0.03, 0.08, length(c));
				col = mix(col, gold_c, rays * 0.35);
				glow += rays * 0.4;
				vec2 k = c - vec2(0.006, 0.165);
				float band = step(abs(k.y), 0.009) * step(abs(k.x), 0.042);
				float spikes = step(abs(fract(k.x * 23.8 + 0.5) - 0.5), 0.2 - k.y * 5.0) * step(0.0, k.y) * step(k.y, 0.04) * step(abs(k.x), 0.042);
				float crown_mask = max(band, spikes);
				col = mix(col, gold(gold_c, 0.5), crown_mask);
				glow += crown_mask * 0.8;
			}
			col = mix(col, trim_col * 0.95, ring_mask);
			col = mix(col, gold_c, dots * 0.9);
			col = mix(col, outer_deep.rgb * 0.4, outline * (1.0 - body));
			col = mix(col, raven_col, body);
			glow += (body * 0.45 + ring_mask * 0.6 + dots * 0.5) * style;
		}
		if (!FRONT_FACING) {
			// The lining, seen from the hero's side.
			vec3 lin = lining_color.rgb * mix(1.15, 0.8, v);
			if (style > 0.5) {
				float sp = 0.0;
				vec3 gx = galaxy(dp * 2.1 + 3.0, sp);
				lin = mix(lin, lining_color.rgb * 1.4, 0.3) + gold_c * sp * 0.6;
				glow = sp * 0.8;
			} else {
				// Quilted diamonds in the lining.
				vec2 qd = abs(fract(dp * vec2(14.0, 14.0) + vec2(dp.y * 14.0, 0.0)) - 0.5);
				lin *= 1.0 - smoothstep(0.04, 0.0, min(qd.x, qd.y)) * 0.35;
				glow = 0.0;
			}
			col = mix(lin, trim_col, trim * 0.8);
			if (feather_paint > 0.5 && kind < 0.5) {
				col = mix(col, glow_color.rgb, 1.0 - smoothstep(0.0, 0.7, feather_h));
			}
		}
		ALBEDO = col;
		EMISSION = glow_rgb * glow;
	}
}
