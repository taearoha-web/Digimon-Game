shader_type spatial;
// The soft glow of an enhanced (+7 up) weapon (EnhanceWeaponFx): an additive overlay
// (material_overlay) in the weapon's own colour. A faint fill keeps the model readable
// (it tints, never whites out) and a fresnel rim lights the silhouette; a slow breath
// and, from +10, a light band sliding up the weapon. No script runs per frame.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(0.6, 0.85, 1.0);
uniform float fill = 0.04;
uniform float rim = 0.45;
uniform float rim_power = 2.4;
// Breath: relative swing and radians a second.
uniform float breath = 0.25;
uniform float speed = 1.6;
// The sliding band's strength (0 none).
uniform float shimmer = 0.0;

varying float along;

void vertex() {
	along = VERTEX.y;
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float f = pow(1.0 - facing, rim_power);
	float b = 1.0 + breath * sin(TIME * speed);
	float band = shimmer * pow(0.5 + 0.5 * sin(along * 9.0 - TIME * 2.6), 10.0);
	ALBEDO = tint * (fill + rim * f + band * (0.35 + f)) * b;
	ALPHA = 1.0;
}
