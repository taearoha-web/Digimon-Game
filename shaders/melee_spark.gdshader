shader_type spatial;
// MeleeArt particles in one MultiMesh: sparks, embers, wind motes and mirror
// shards. The quad is stretched along the velocity on the CPU; UV.y runs tail 0
// -> head 1. Instance COLOR carries the tint (rgb) and life (a). Additive, with
// a white-hot head that cools to the tint toward the tail.
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
uniform float shard = 0.0;
uniform float age = 0.0;

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float head = UV.y;
	float life = clamp(COLOR.a, 0.0, 1.0);
	float core = pow(across, 2.0) * pow(head, 1.5);
	vec3 c = mix(COLOR.rgb * 0.75, vec3(1.0, 0.97, 0.9), core * life * 0.75);
	float m = smoothstep(0.0, 0.5, across) * smoothstep(0.0, 0.35, head) * smoothstep(1.0, 0.85, head);
	if (shard > 0.5) {
		// A mirror facet: a flat plate with a glint that runs across it.
		float glint = pow(max(0.0, sin((UV.x + UV.y) * 6.0 - age * 9.0 + COLOR.r * 20.0)), 12.0);
		c = mix(COLOR.rgb * 0.55, vec3(1.0), glint * 0.8 + 0.1);
		m = 0.55 + glint * 0.45;
	}
	ALBEDO = c * 0.95;
	ALPHA = m * life;
}
