shader_type spatial;
// The glowing core of the Defender's taunt chain (TauntChain): a soft line of
// light along the chain (UV.y 0 at the foe -> 1 at the shield, UV.x across)
// with pulses that leave the shield every `period` seconds and race down to
// the foe, a bright head with a cooling tail, flaring where they arrive.
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
uniform vec4 primary : source_color = vec4(1.0, 0.42, 0.2, 1.0);
uniform vec4 accent : source_color = vec4(1.0, 0.88, 0.66, 1.0);
uniform float age = 0.0;
uniform float fade = 1.0;
uniform float span = 4.0;
uniform float period = 0.9;

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float core = pow(across, 2.2);
	float along = UV.y;
	float head = 1.0 - fract(age / period);
	// Metres from the pulse head: ahead of it (toward the foe) < 0, its tail > 0.
	float d = (along - head) * span;
	float pulse = exp(-d * d * 7.0) + 0.55 * exp(-max(d, 0.0) * 2.2) * step(0.0, d);
	// The arrival flare at the foe's end as each pulse lands.
	float land = exp(-along * span * 2.5) * smoothstep(0.25, 0.0, head);
	float flicker = 0.85 + 0.15 * sin(along * span * 9.0 - age * 14.0);
	float glow = core * 0.3 * flicker + across * (pulse * 0.75 + land * 0.8);
	vec3 c = mix(primary.rgb, accent.rgb, clamp(core * (0.25 + 0.6 * pulse), 0.0, 0.85));
	ALBEDO = c * 0.9;
	ALPHA = clamp(glow, 0.0, 1.0) * fade * smoothstep(0.0, 0.04, along) * smoothstep(1.0, 0.96, along);
}
