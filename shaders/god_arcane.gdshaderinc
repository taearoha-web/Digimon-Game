// Shared by the god-tier signature art (combat/god_art): one clock (age, set by
// StarSkillArt every frame), per-piece motion in the vertex stage (wing flaps, a slide
// into place, a burst of debris / notes / petals) and a toon light with a rim.
uniform float fade = 1.0;
uniform float age = 0.0;
// The layer's own start on the root's clock.
uniform float t0 = 0.0;
// UV2.y weighs a vertical flap (wings, bobbing instruments); COLOR.a is its phase.
uniform float flap = 0.0;
uniform float flap_rate = 6.0;
// Burst: CUSTOM0 = velocity (xyz) and the piece's delay (w), CUSTOM1 = pivot (xyz) and tumble rate (w).
uniform float burst = 0.0;
uniform float gravity = 9.0;
uniform float drag = 1.5;
uniform float life = 1.2;
// The whole mesh arrives from this offset: slide_ease > 0 accelerates (a fall),
// < 0 eases out (a rise that settles).
uniform vec3 slide = vec3(0.0);
uniform float slide_time = 0.3;
uniform float slide_ease = 2.0;

vec3 god_rot(vec3 v, vec3 ax, float a) {
	return v * cos(a) + cross(ax, v) * sin(a) + ax * dot(ax, v) * (1.0 - cos(a));
}

void god_move(inout vec3 vtx, inout vec3 nrm, vec4 col, vec2 uv2, vec4 c0, vec4 c1) {
	float lt = max(0.0, age - t0);
	vtx.y += sin(age * flap_rate + col.a * 6.2832) * uv2.y * flap;
	if (burst > 0.5) {
		float bt = max(0.0, lt - c0.w);
		vec3 ax = normalize(cross(vec3(0.0, 1.0, 0.0), c0.xyz) + vec3(0.001, 0.0, 0.002));
		float ang = c1.w * bt;
		float grow = smoothstep(0.0, 0.05, bt) * (1.0 - smoothstep(life * 0.55, life, bt));
		vec3 rel = god_rot(vtx - c1.xyz, ax, ang) * grow;
		nrm = god_rot(nrm, ax, ang);
		vec3 d = c0.xyz * (1.0 - exp(-drag * bt)) / max(0.01, drag);
		d.y -= 0.5 * gravity * bt * bt;
		vtx = c1.xyz + rel + d;
	}
	float st = clamp(lt / max(0.001, slide_time), 0.0, 1.0);
	float left = slide_ease > 0.0 ? 1.0 - pow(st, slide_ease) : pow(1.0 - st, -slide_ease);
	vtx += slide * left;
}

uniform vec4 rim_color : source_color = vec4(1.0);
uniform float rim = 0.5;
uniform vec4 shadow_tint : source_color = vec4(0.5, 0.45, 0.65, 1.0);
// A flash of light over the whole piece (0..1).
uniform float glow = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0);

vec3 god_toon(vec3 base, vec3 n, vec3 v, float emit) {
	float l = dot(n, normalize(vec3(0.25, 0.9, 0.1) + v * 0.55)) * 0.5 + 0.5;
	vec3 col = mix(base * shadow_tint.rgb, base, smoothstep(0.42, 0.54, l));
	col += base * smoothstep(0.82, 0.92, l) * 0.2;
	float fr = pow(1.0 - abs(dot(n, v)), 2.5);
	col = mix(col, rim_color.rgb, clamp(fr * rim, 0.0, 1.0));
	col = mix(col, base * 1.2 + 0.08, clamp(emit, 0.0, 1.0));
	return mix(col, glow_color.rgb, glow);
}

float god_grain(vec3 p) {
	return 0.5 + 0.5 * sin(p.x * 7.0 + p.y * 5.0) * sin(p.z * 6.0 - p.y * 4.0);
}
