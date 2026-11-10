shader_type spatial;
// God-tier melee set pieces (combat/god_art/_kit_melee.gd): solid, cel-shaded bodies with a
// rim light and glowing inlays: the god-sword, the dragon-spear, the god-shields, the scythe.
// Opaque (it writes depth, so a body never shows its own back through its front) and
// unshaded with a fixed key light, so a cast looks the same in every field and hour.
// Each piece of a formation falls or rises on its own clock (UV2.x delay, UV2.y distance)
// in the vertex stage: one mesh, one draw. No screen or depth texture reads.
render_mode unshaded, cull_disabled;
uniform float fade = 1.0;
uniform float age = 0.0;
uniform float t0 = 0.0;
uniform float drop = 0.0;
// A piece may also arrive from this offset (model space), e.g. a shield driven along the ground.
uniform vec3 from = vec3(0.0);
uniform float flight = 0.25;
uniform float ease = 0.0;
uniform vec4 rim_color : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float rim = 0.7;
uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.4, 1.0);
uniform float heat = 0.0;
uniform float dim = 1.0;
// > 0: the mesh is a StarGeometry / MartialGeometry sculpture (COLOR.r = its inlay), painted from tone_a to tone_b.
uniform float remap = 0.0;
uniform vec4 tone_a : source_color = vec4(0.5, 0.3, 0.1, 1.0);
uniform vec4 tone_b : source_color = vec4(1.0, 0.85, 0.4, 1.0);
varying float v_lt;
varying vec3 v_local;
varying vec3 v_wn;
varying vec3 v_wp;

void vertex() {
	float lt = age - t0 - UV2.x;
	v_lt = lt;
	float p = clamp(lt / max(flight, 0.001), 0.0, 1.0);
	float k = mix(1.0 - p * p, pow(1.0 - p, 3.0) - 0.1 * sin(p * 3.14159) * p, ease);
	v_local = VERTEX;
	VERTEX += (vec3(0.0, drop, 0.0) + from) * UV2.y * k;
	v_wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (v_lt < 0.0) {
		discard;
	}
	// Dissolve cells of a hand's width in the world, whatever the piece's scale.
	float grain = fract(sin(dot(floor((v_wp - NODE_POSITION_WORLD) * 7.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	if (grain > fade * 1.02) {
		discard;
	}
	vec3 n = normalize(v_wn);
	if (!FRONT_FACING) {
		n = -n;
	}
	vec3 v = normalize(CAMERA_POSITION_WORLD - v_wp);
	vec3 l = normalize(vec3(-0.35, 0.8, 0.5));
	float d = dot(n, l) * 0.5 + 0.5;
	float band = 0.5 + smoothstep(0.36, 0.44, d) * 0.3 + smoothstep(0.68, 0.76, d) * 0.24;
	vec3 base = mix(COLOR.rgb, mix(tone_a.rgb, tone_b.rgb, clamp(COLOR.r, 0.0, 1.0)), remap);
	float shine = mix(COLOR.a, 0.5, remap);
	vec3 col = base * band * dim;
	// A cool bounce from below, a hard specular glint on the polished parts (COLOR.a).
	col += base * vec3(0.10, 0.12, 0.2) * max(-n.y, 0.0);
	float spec = pow(max(dot(reflect(-l, n), v), 0.0), 18.0);
	col += vec3(1.0, 0.98, 0.9) * smoothstep(0.35, 0.6, spec) * shine * 0.55;
	float fres = pow(1.0 - abs(dot(n, v)), 2.5);
	col += rim_color.rgb * fres * rim;
	float inlay = clamp(UV.x, 0.0, 1.0) * (1.0 - remap);
	float pulse = 0.85 + 0.15 * sin(age * 7.0 + v_local.y * 4.0);
	col = mix(col, glow_color.rgb * 1.25 * pulse, inlay);
	// White-hot for a moment where it has just struck.
	float land = v_lt - flight;
	col += glow_color.rgb * heat * step(0.0, land) * exp(-max(land, 0.0) * 5.0);
	// The last of it burns away along the dissolve front.
	col += glow_color.rgb * smoothstep(fade * 1.02 - 0.12, fade * 1.02, grain) * step(fade, 0.95);
	ALBEDO = col;
}
