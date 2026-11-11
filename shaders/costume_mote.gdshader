shader_type spatial;
// The few drifting motes of a reward-shop costume (CostumeArt.motes): foxfire,
// stars, petals, bubbles, smoke. One mesh of camera-facing quads: every quad's four
// vertices sit on its mote's home (VERTEX), UV is the corner, UV2 = (phase, size in
// metres) and COLOR its colour. The vertex stage moves each mote (orbit, rise or
// fall, bob) and turns it to the camera, so no script runs per frame.
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled;

// Turns a second around the body (radians), scaled a little per mote.
uniform float orbit = 0.6;
// Cycles a second from y_lo to y_hi (negative falls); 0 keeps the home height.
uniform float rise = 0.0;
uniform float y_lo = 0.0;
uniform float y_hi = 1.0;
uniform float bob = 0.03;
// Sideways wander (model units) while rising or falling.
uniform float drift = 0.0;
// Size pulse (0..1) and turning (radians a second) of each quad.
uniform float twinkle = 0.0;
uniform float spin = 0.0;
// 0 soft glow, 1 four-point star, 2 petal, 3 bubble, 4 smoke puff.
uniform float shape = 0.0;
// 1 adds light (glows), 0 covers like paint (petals, smoke).
uniform float additive = 1.0;

varying vec4 tint;
varying float fade;

void vertex() {
	vec3 home = VERTEX;
	float ph = UV2.x;
	float a = atan(home.z, home.x) + TIME * orbit * (0.75 + 0.5 * fract(ph * 7.31));
	float r = length(home.xz);
	float y = home.y;
	fade = 1.0;
	if (rise != 0.0) {
		float k = fract(ph + TIME * rise);
		y = mix(y_lo, y_hi, k);
		fade = sin(k * PI);
		r += sin(TIME * 1.3 + ph * 20.0) * drift;
	}
	y += sin(TIME * 1.7 + ph * 13.0) * bob;
	vec3 p = vec3(cos(a) * r, y, sin(a) * r);
	float s = UV2.y * (1.0 + twinkle * 0.5 * sin(TIME * 4.0 + ph * 31.0));
	float turn = ph * 6.2832 + TIME * spin;
	vec2 corner = (UV - 0.5) * s;
	corner = vec2(corner.x * cos(turn) - corner.y * sin(turn), corner.x * sin(turn) + corner.y * cos(turn));
	vec4 view = MODELVIEW_MATRIX * vec4(p, 1.0);
	view.xy += corner;
	VERTEX = view.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
	tint = vec4(pow(COLOR.rgb, vec3(2.2)), COLOR.a);
}

void fragment() {
	vec2 q = UV - 0.5;
	float d = length(q);
	float a = 0.0;
	vec3 c = tint.rgb;
	if (shape < 0.5) {
		// A soft glow with a white-hot core.
		a = pow(smoothstep(0.5, 0.0, d), 1.6);
		c = mix(c, vec3(1.0), smoothstep(0.16, 0.0, d));
	} else if (shape < 1.5) {
		float rays = max(smoothstep(0.06, 0.0, abs(q.x)) * smoothstep(0.5, 0.0, abs(q.y)), smoothstep(0.06, 0.0, abs(q.y)) * smoothstep(0.5, 0.0, abs(q.x)));
		a = max(rays, pow(smoothstep(0.32, 0.0, d), 2.0));
		c = mix(c, vec3(1.0), smoothstep(0.12, 0.0, d));
	} else if (shape < 2.5) {
		// A petal: an oval with a notch at its tip, paler at the base.
		vec2 e = q / vec2(0.26, 0.46);
		float notch = smoothstep(0.07, 0.0, abs(q.x)) * step(0.3, q.y);
		a = (1.0 - smoothstep(0.85, 1.0, length(e))) * (1.0 - notch);
		c = mix(c, vec3(1.0, 0.96, 0.97), smoothstep(0.1, -0.4, q.y) * 0.6);
	} else if (shape < 3.5) {
		float ring = smoothstep(0.08, 0.0, abs(d - 0.38)) * 0.9 + smoothstep(0.38, 0.0, d) * 0.18;
		float shine = smoothstep(0.09, 0.0, length(q - vec2(-0.14, 0.14)));
		a = clamp(ring + shine, 0.0, 1.0);
		c = mix(c, vec3(1.0), shine);
	} else {
		a = smoothstep(0.5, 0.05, d) * 0.55;
	}
	a *= tint.a * fade;
	ALBEDO = c * a;
	ALPHA = a * (1.0 - additive);
}
