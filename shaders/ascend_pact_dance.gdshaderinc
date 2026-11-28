// The light of the Dark Lord's and the Bard's ★500 ultimates (combat/ascend_ult/
// heaven_hell_sovereign.gd: สัญญาโลหิต, universe_hymn.gd: ระบำสะกดใจ), drawn on a few
// plain meshes; ascend_pact_dance.gdshader mixes it (blood reads dark on bright grass),
// ascend_pact_dance_add.gdshader adds it (light). fade is the whole piece's opacity.
//   mode 0  blood tide    a disc quad: a wobbling crimson band at `band` (0..1 of the
//                         radius), a thin pool of blood inside it
//   mode 1  dance floor   a disc quad: tiles of light turning round, rings pulsing out
//                         on the beat, a soft rim
//   mode 2  beam          a cone / cylinder: hot at its core, soft at its edges, fading
//                         towards its foot (UV.y 1)
//   mode 3  blood moon    a sphere: a dark heart under a hot rim, veins crawling over it
//   mode 4  blood seal    a disc quad: a ring of runes (ticks) and a thin inner ring
//   mode 5  mirror ball   a sphere: facets that sparkle one by one
uniform int mode = 0;
uniform vec4 color : source_color = vec4(0.88, 0.12, 0.23, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.7, 0.66, 1.0);
uniform vec4 shade : source_color = vec4(0.16, 0.0, 0.05, 1.0);
uniform float fade = 1.0;
uniform float band = 0.85;
uniform float width = 0.1;
uniform float speed = 1.0;
uniform float seed = 0.0;

float pd_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float pd_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(pd_hash(i), pd_hash(i + vec2(1.0, 0.0)), f.x), mix(pd_hash(i + vec2(0.0, 1.0)), pd_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float t = TIME * speed + seed;
	vec3 col = color.rgb;
	float alpha = 0.0;
	if (mode == 0) {
		float wob = (pd_noise(vec2(a * 2.6 + seed, t * 1.7)) - 0.5) * 0.09;
		float d = abs(r - band + wob);
		float ring = smoothstep(width, 0.0, d);
		float drip = pd_noise(vec2(a * 9.0, r * 7.0 - t * 2.0));
		float pool = smoothstep(band + 0.02, band - 0.3, r) * (0.18 + 0.22 * drip) * step(r, 1.0);
		col = mix(shade.rgb, color.rgb, clamp(pool * 2.5 + ring, 0.0, 1.0));
		col = mix(col, core.rgb, pow(ring, 3.0));
		alpha = max(ring * 0.95, pool);
	} else if (mode == 1) {
		float turn = a + t * 0.6;
		float rays = step(0.5, fract(turn * 12.0 / 6.28318));
		float rings = step(0.5, fract(r * 5.0));
		float tile = abs(rays - rings);
		float pulse = smoothstep(0.08, 0.0, abs(fract(r * 1.2 - t * 0.9) - 0.5) - 0.38);
		col = mix(color.rgb, core.rgb, tile * 0.35 + pulse * 0.5);
		float rim = smoothstep(1.0, 0.95, r) * smoothstep(0.88, 0.96, r);
		alpha = (0.05 + 0.1 * tile + 0.22 * pulse) * smoothstep(1.0, 0.9, r) + rim * 0.55;
		col = mix(col, core.rgb, rim);
	} else if (mode == 2) {
		float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
		float soft = pow(facing, 1.6);
		float foot = 1.0 - UV.y * 0.75;
		col = mix(color.rgb, core.rgb, pow(facing, 4.0));
		alpha = soft * foot * 0.32;
	} else if (mode == 3) {
		float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
		float rim = pow(1.0 - facing, 2.2);
		float veins = smoothstep(0.06, 0.0, abs(pd_noise(UV * vec2(14.0, 7.0) + vec2(t * 0.4, -t * 0.3)) - 0.5));
		col = mix(shade.rgb, color.rgb, 0.35 + 0.65 * rim);
		col = mix(col, core.rgb, rim * rim + veins * 0.6);
		alpha = 0.92;
	} else if (mode == 4) {
		float ticks = step(0.55, fract((a + t * 0.25) * 24.0 / 6.28318)) * smoothstep(0.05, 0.0, abs(r - band));
		float inner = smoothstep(0.025, 0.0, abs(r - band * 0.72));
		float outer = smoothstep(0.02, 0.0, abs(r - band - 0.08));
		col = mix(color.rgb, core.rgb, inner);
		alpha = max(max(ticks, inner), outer) * 0.9;
	} else {
		vec2 cell = floor(UV * vec2(18.0, 9.0));
		float spark = pd_hash(cell + seed);
		float flick = pow(0.5 + 0.5 * sin(t * 6.0 + spark * 40.0), 8.0);
		vec2 g = fract(UV * vec2(18.0, 9.0));
		float grout = step(0.08, g.x) * step(0.08, g.y);
		float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
		col = mix(shade.rgb, color.rgb, 0.45 + 0.55 * spark * facing) * grout;
		col = mix(col, core.rgb, flick * grout);
		alpha = 0.97;
	}
	ALBEDO = col;
	ALPHA = clamp(alpha * fade, 0.0, 1.0);
}
