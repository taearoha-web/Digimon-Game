shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// The village floor (VillageGround): warm dark-gray Japanese stone paving, drawn per
// pixel from world position, with no textures. UV is world x/z in metres; UV2.x is the
// distance to the nearest street centre line, UV2.y the signed distance to the paving's
// edge (> 0 stone, < 0 grass); COLOR.rg carries |direction| of the nearest street.
// Streets: running-bond setts laid along the street between warm granite kerbs. The
// rest: square plates. The plaza: a fan pattern (扇張り) of small granite setts inside a
// granite ring. A muted yellow tactile strip runs along the main street.
// Every joint, speck and per-stone tone fades by its size in pixels (screen derivatives),
// so the paving stays calm in the distance instead of shimmering.

// Warm charcoal (never blue-gray): streets darkest, the walks a step lighter, the plaza's
// setts and the granite kerbs warmer still.
uniform vec4 street_color : source_color = vec4(0.30, 0.272, 0.255, 1.0);
uniform vec4 walk_color : source_color = vec4(0.39, 0.355, 0.325, 1.0);
uniform vec4 sett_color : source_color = vec4(0.45, 0.40, 0.355, 1.0);
uniform vec4 joint_color : source_color = vec4(0.17, 0.152, 0.138, 1.0);
uniform vec4 kerb_color : source_color = vec4(0.68, 0.615, 0.53, 1.0);
uniform vec4 inlay_color : source_color = vec4(0.25, 0.215, 0.195, 1.0);
uniform vec4 guide_color : source_color = vec4(0.71, 0.56, 0.27, 1.0);
uniform vec4 grass_shadow : source_color = vec4(0.42, 0.53, 0.36, 1.0);
uniform vec4 grass_sun : source_color = vec4(0.60, 0.69, 0.50, 1.0);
uniform vec4 accent_color : source_color = vec4(0.64, 0.75, 0.48, 1.0);
uniform float accent_amount = 0.4;
uniform float street_half = 2.3;
// Plaza centre x, z and radius (radius 0: no plaza).
uniform vec3 plaza = vec3(0.0);
// Tactile strip: from (x, y) to (z, w), offset to one side of that line.
uniform vec4 guide_line = vec4(0.0);
uniform float guide_offset = 1.4;
// 0 on low quality and in the safe picture: no wear, grain, ridges or flower specks.
uniform float detail = 1.0;

const float KERB = 0.3;
const float JOINT = 0.011;
const float FAN_R = 1.05;

float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise21(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), f.x), f.y);
}

// Rectangular stones of size s (metres), every other row shifted by `shift` of a stone.
// Returns (distance to the nearest joint in metres, stone hash, second stone hash).
vec3 bond(vec2 p, vec2 s, float shift) {
	vec2 q = p / s;
	q.x += mod(floor(q.y), 2.0) * shift;
	vec2 cell = floor(q);
	vec2 f = fract(q);
	float e = min(min(f.x, 1.0 - f.x) * s.x, min(f.y, 1.0 - f.y) * s.y);
	return vec3(e, hash21(cell + 7.1), hash21(cell.yx + 31.7));
}

// The fan of row j that may hold p: (offset from its centre, its id).
vec4 fan_of(vec2 p, float j) {
	float off = mod(j, 2.0) * FAN_R;
	float cx = round((p.x - off) / (2.0 * FAN_R)) * 2.0 * FAN_R + off;
	return vec4(p - vec2(cx, j * FAN_R * 0.5), cx, j);
}

// Fan (seigaiha) paving: overlapping fans, each a set of concentric arcs of small setts.
// Returns (joint distance m, sett hash, 1 on the fan's outer arc, fan hash).
vec4 fans(vec2 p) {
	// The lowest row whose fan holds p lies on top; the fans of the rows before it, which
	// do not hold p, lie over it and cut its lower edge. Five rows always settle it.
	float j0 = ceil((p.y - FAN_R) / (FAN_R * 0.5)) - 1.0;
	vec4 pick = vec4(0.0);
	float found = 0.0;
	float cut = 9.0;
	for (int k = 0; k < 5; k++) {
		vec4 f = fan_of(p, j0 + float(k));
		float l = length(f.xy);
		if (found < 0.5) {
			if (l < FAN_R) {
				pick = f;
				found = 1.0;
			} else {
				cut = min(cut, l - FAN_R);
			}
		}
	}
	float rr = length(pick.xy);
	// Five rings of setts; along each ring, setts about 0.2 m long, staggered.
	float rw = FAN_R / 5.0;
	float ring = floor(rr / rw);
	float fr = fract(rr / rw);
	float arc = atan(pick.x, pick.y) * (ring + 0.5) * rw / 0.2 + ring * 0.5;
	float fa = fract(arc);
	float e = min(min(fr, 1.0 - fr) * rw, min(fa, 1.0 - fa) * 0.2);
	e = min(e, abs(cut));
	vec2 id = vec2(floor(arc), ring) + pick.zw * 3.7;
	return vec4(e, hash21(id + 3.3), step(4.0, ring), hash21(pick.zw + 0.5));
}

vec3 grass(vec2 p, float footprint) {
	float broad = noise21(p * 0.085);
	float patch = noise21(p * 0.31 + broad * 1.8);
	float brush = noise21(p * 1.8);
	float drift = noise21(p * 0.042 + 7.3);
	float brush_fade = 1.0 - smoothstep(0.22, 0.65, footprint);
	float mixv = smoothstep(0.18, 0.82, clamp(broad * 0.64 + patch * 0.36, 0.0, 1.0));
	vec3 color = mix(grass_shadow.rgb, grass_sun.rgb, mixv);
	float accent_mask = smoothstep(0.50, 0.72, drift + (patch - 0.5) * 0.22 + (brush - 0.5) * 0.08);
	color = mix(color, accent_color.rgb, accent_mask * accent_amount);
	if (detail > 0.5) {
		float open = 1.0 - smoothstep(0.035, 0.12, footprint);
		vec2 cell = floor(p * 2.6);
		float bloom = step(0.965, hash21(cell + 17.0)) * (1.0 - smoothstep(0.08, 0.16, length(fract(p * 2.6) - 0.5)));
		vec3 bloom_color = mix(vec3(0.95, 0.78, 0.82), vec3(0.98, 0.92, 0.62), hash21(cell + 5.0));
		color = mix(color, bloom_color, bloom * open * 0.9);
	}
	return color * (1.0 + (brush - 0.5) * 0.14 * brush_fade);
}

void fragment() {
	vec2 p = UV;
	// Metres per pixel along the worse screen axis.
	float px = max(max(length(dFdx(p)), length(dFdy(p))), 0.0005);
	float sdf = UV2.y;
	float street_d = UV2.x;
	float edge_aa = max(fwidth(sdf), 0.002);
	float on_stone = smoothstep(-edge_aa * 0.5, edge_aa * 0.5, sdf);
	vec3 lawn = vec3(0.0);
	vec3 stone = vec3(0.0);
	float rough = 0.9;
	if (sdf < edge_aa) {
		lawn = grass(p, px);
		// The kerb stands a little proud: a soft shadow on the grass beside it.
		lawn *= 1.0 - 0.22 * (1.0 - smoothstep(-0.3, 0.0, sdf));
	}
	if (sdf > -edge_aa) {
		// Joints read while they are at least ~1 px wide, then fade to their average.
		float joint_show = 1.0 - smoothstep(0.016, 0.05, px);
		float along_x = step(COLOR.g, COLOR.r);
		vec2 sp = mix(p.yx, p, along_x);
		float plaza_d = plaza.z > 0.0 ? length(p - plaza.xy) : 999.0;
		vec3 base;
		vec3 pat;
		float size;
		float rim = 0.0;
		if (plaza_d < plaza.z) {
			vec4 fp = fans(p - plaza.xy);
			pat = fp.xyz;
			base = sett_color.rgb * (0.94 + fp.w * 0.12);
			size = 0.2;
			rim = fp.z * (1.0 - smoothstep(0.08, 0.3, px));
			// A dark stone inlay ring inside the plaza's edge.
			float inlay = step(abs(plaza_d - plaza.z + 1.5), 0.13);
			if (inlay > 0.5) {
				pat = vec3(0.13 - abs(plaza_d - plaza.z + 1.5), fp.y, 0.5);
				base = inlay_color.rgb;
				rim = 0.0;
			}
			// A granite ring round the plaza and another round the tree's planter.
			float ring_band = step(plaza.z - 0.55, plaza_d) + step(plaza_d, 3.4) * step(2.8, plaza_d);
			if (ring_band > 0.5) {
				float ring_e = min(min(abs(plaza_d - plaza.z), abs(plaza_d - plaza.z + 0.55)), min(abs(plaza_d - 2.8), abs(plaza_d - 3.4)));
				vec3 rb = bond(vec2(atan(p.x - plaza.x, p.y - plaza.y) * plaza_d, plaza_d), vec2(0.9, 9.0), 0.0);
				pat = vec3(min(ring_e, rb.x), rb.y, rb.z);
				base = kerb_color.rgb * 0.9;
				size = 0.55;
				rim = 0.0;
			}
		} else if (street_d < street_half) {
			pat = bond(sp, vec2(0.42, 0.21), 0.5);
			base = street_color.rgb;
			size = 0.21;
		} else if (street_d < street_half + KERB) {
			// Kerb stones along the street, 0.9 m long.
			pat = bond(vec2(sp.x, 4.5), vec2(0.9, 9.0), 0.0);
			pat.x = min(pat.x, min(street_d - street_half, street_half + KERB - street_d));
			base = kerb_color.rgb;
			size = 0.3;
		} else {
			pat = bond(p, vec2(0.45, 0.45), 0.0);
			base = walk_color.rgb;
			size = 0.45;
		}
		// Per-stone tone: most a touch apart, a few clearly darker or lighter.
		// (gone by ~5 px a stone, before it turns into a pixel checker)
		float tone_show = 1.0 - smoothstep(size * 0.05, size * 0.2, px);
		float tone = (pat.y - 0.5) * 0.18 + (step(0.9, pat.z) * -0.13) + step(pat.z, 0.06) * 0.09;
		vec3 color = base * (1.0 + tone * tone_show);
		color = mix(color, kerb_color.rgb * 0.9, rim * 0.6);
		// Garden kerb where the paving meets grass.
		float kerb = 1.0 - step(KERB, sdf);
		if (kerb > 0.5) {
			float kh = hash21(floor(p / 0.9) + 2.0);
			color = kerb_color.rgb * (1.0 + (kh - 0.5) * 0.12 * tone_show);
			pat.x = KERB - sdf;
		}
		// Worn, smoother patches where feet pass; lighter, a little polished.
		float wear = 0.5;
		float grain = 0.0;
		if (detail > 0.5) {
			wear = noise21(p * 0.33 + 11.0);
			grain = (hash21(floor(p * 34.0)) - 0.5) * (1.0 - smoothstep(0.006, 0.02, px));
			// Broad patina: some stretches a shade darker and cooler, others sun-warmed.
			float patina = noise21(p * 0.065 + 3.0);
			color *= mix(vec3(0.9, 0.9, 0.92), vec3(1.07, 1.03, 0.97), patina);
		}
		color *= 0.93 + wear * 0.14 + grain * 0.16;
		// Joints: anti-aliased line, and a slight chamfer darkening the stone beside it.
		float line = 1.0 - smoothstep(JOINT - px * 0.5, JOINT + px * 0.5, pat.x);
		float chamfer = 1.0 - smoothstep(JOINT, JOINT + 0.035, pat.x);
		color *= 1.0 - chamfer * 0.12 * joint_show;
		color = mix(color, joint_color.rgb, line * joint_show);
		color *= 1.0 - (1.0 - joint_show) * (JOINT * 4.0 / size) * 0.6;
		// Tactile guide strip (点字ブロック) along the main street, off the plaza.
		vec2 ga = guide_line.xy;
		vec2 gd = guide_line.zw - ga;
		float glen = length(gd);
		if (glen > 0.1 && plaza_d > plaza.z + 0.3) {
			vec2 dir = gd / glen;
			float t = dot(p - ga, dir);
			float s = dot(p - ga, vec2(-dir.y, dir.x)) - guide_offset;
			float inside = step(abs(s), 0.15) * step(0.0, t) * step(t, glen);
			if (inside > 0.5) {
				vec2 tile = vec2(t, s + 0.15) / 0.3;
				vec2 tf = fract(tile);
				float ridge_show = (1.0 - smoothstep(0.012, 0.035, px)) * detail;
				// Four raised bars along the way; dots near both ends.
				float bars = smoothstep(0.3, 0.45, abs(fract(tf.y * 4.0) - 0.5) * 2.0);
				float dots = 1.0 - smoothstep(0.22, 0.32, length(fract(tf * 5.0) - 0.5) * 2.0);
				float raised = mix(bars, dots, step(t, 0.9) + step(glen - 0.9, t));
				vec3 g = guide_color.rgb * (0.9 + raised * 0.16 * ridge_show);
				float te = min(min(tf.x, 1.0 - tf.x), min(tf.y, 1.0 - tf.y)) * 0.3;
				g = mix(g, guide_color.rgb * 0.55, (1.0 - smoothstep(0.006 - px * 0.5, 0.006 + px * 0.5, te)) * joint_show);
				color = g * (0.93 + wear * 0.1);
			}
		}
		stone = color;
		// Stone has a faint sheen that varies stone to stone and is smoother where worn,
		// so low sun and lantern light glint across it.
		rough = clamp(0.78 + (pat.y - 0.5) * 0.18 * tone_show - wear * 0.16 + line * 0.15, 0.5, 0.95);
	}
	ALBEDO = mix(lawn, stone, on_stone);
	ROUGHNESS = mix(1.0, rough, on_stone);
	SPECULAR = mix(0.0, 0.42, on_stone);
}
