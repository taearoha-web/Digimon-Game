shader_type spatial;
// The 300-star Dragon God wings (DragonWingArt): membrane, bones, scales and claws of
// one mesh, told apart by UV2 (floor(UV2.x): 0 membrane, 1 bone, 2 scale, 3 claw;
// fract(UV2.x): a phase; UV2.y: how far out the vertex sits, 0 at the shoulder).
// Unshaded, so the pair reads the same in every zone and at night, and opaque: nothing
// is added over the picture. The membrane (UV.x across a panel between two fingers,
// UV.y from the wrist to the trailing edge) runs from the class's deep colour at the
// arm to its glow at the scalloped edge, shaded toward the bones, with veins of light
// fanning from the wrist and a pulse travelling out along them over TIME. The wing
// sways from the shoulder and the membrane flutters in the vertex stage; motion = 0
// holds everything still (the lowest quality, a crowd's light dress).
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

uniform vec4 membrane_deep : source_color = vec4(0.05, 0.25, 0.22, 1.0);
uniform vec4 membrane : source_color = vec4(0.1, 0.55, 0.45, 1.0);
uniform vec4 membrane_edge : source_color = vec4(0.45, 1.0, 0.8, 1.0);
uniform vec4 vein : source_color = vec4(0.8, 1.0, 0.9, 1.0);
uniform vec4 bone : source_color = vec4(0.96, 0.77, 0.32, 1.0);
uniform vec4 bone_light : source_color = vec4(1.0, 0.95, 0.72, 1.0);
uniform vec4 scale_color : source_color = vec4(0.18, 0.78, 0.6, 1.0);
uniform vec4 scale_light : source_color = vec4(0.72, 1.0, 0.9, 1.0);
uniform float motion = 1.0;

varying float v_row;
varying float v_phase;
varying float v_flex;

void vertex() {
	v_row = floor(UV2.x);
	v_phase = fract(UV2.x);
	v_flex = UV2.y;
	float f = v_flex * v_flex;
	// The whole wing sways from the shoulder, the tips the most.
	VERTEX.z += motion * f * 0.16 * sin(TIME * 1.5 + v_flex * 2.6);
	VERTEX.y += motion * f * 0.04 * sin(TIME * 1.1 + 1.0);
	if (v_row < 0.5) {
		// The membrane flutters between its fingers, more toward the free edge.
		float belly = sin(UV.x * 3.14159);
		VERTEX.z += motion * belly * UV.y * 0.05 * sin(TIME * 3.1 + v_phase * 40.0 + UV.y * 5.0);
	}
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float facing = clamp(abs(dot(n, normalize(VIEW))), 0.0, 1.0);
	vec3 col;
	if (v_row < 0.5) {
		float u = UV.x;
		float v = UV.y;
		col = mix(membrane_deep.rgb, membrane.rgb, smoothstep(0.0, 0.55, v));
		col = mix(col, membrane_edge.rgb, smoothstep(0.55, 1.0, v) * 0.85);
		// Stretched skin: darker where it meets a bone, lighter in the belly of a panel.
		float belly = smoothstep(0.0, 0.3, min(u, 1.0 - u));
		col *= mix(0.62, 1.0, belly);
		col += membrane_edge.rgb * 0.1 * sin(u * 3.14159);
		// Veins fan out from the wrist, with fine branches between them.
		float k = u * 4.0 + 0.09 * sin(v * 8.0 + v_phase * 30.0);
		float d = abs(fract(k) - 0.5);
		float w = max(fwidth(k), 0.0005);
		float trunk = (1.0 - smoothstep(0.035, 0.035 + w * 1.5, d)) * smoothstep(0.04, 0.2, v);
		float b = v * 7.0 + d * 3.2;
		float bd = abs(fract(b) - 0.5);
		float bw = max(fwidth(b), 0.0005);
		float branch = (1.0 - smoothstep(0.03, 0.03 + bw * 1.5, bd)) * smoothstep(0.03, 0.12, d) * (1.0 - smoothstep(0.3, 0.5, d)) * smoothstep(0.15, 0.4, v);
		float pulse = 0.5 + 0.5 * sin(v * 7.0 - TIME * 2.4 * motion + v_phase * 12.0);
		pulse = pulse * pulse;
		float light = clamp(trunk * (0.55 + 0.45 * pulse) + branch * (0.2 + 0.4 * pulse), 0.0, 1.0);
		col = mix(col, vein.rgb, light);
		// A hem of gold along the trailing edge.
		float hw = max(fwidth(v), 0.0005);
		float hem = smoothstep(0.955 - hw, 0.955, v);
		col = mix(col, mix(bone.rgb, bone_light.rgb, 0.5 + 0.5 * pulse), hem);
	} else if (v_row < 1.5) {
		// Bone: a lit ridge, inked toward its silhouette.
		col = mix(bone.rgb * 0.62, bone.rgb, smoothstep(0.1, 0.55, facing));
		col = mix(col, bone_light.rgb, smoothstep(0.75, 1.0, facing) * 0.8);
	} else if (v_row < 2.5) {
		// A scale: jade, a pale lit rim at its tip, a dark root under the next one.
		float tip = UV.y;
		float rim = 1.0 - smoothstep(0.0, 0.16, min(UV.x, 1.0 - UV.x) * (1.2 - tip));
		col = mix(scale_color.rgb * 0.38, scale_color.rgb * 0.85, smoothstep(0.0, 0.75, tip));
		float glint = 0.5 + 0.5 * sin(TIME * 1.8 * motion + v_phase * 25.0);
		col = mix(col, scale_light.rgb, clamp(rim * 0.75 + smoothstep(0.8, 1.0, tip) * 0.5 + glint * glint * 0.12, 0.0, 1.0));
	} else {
		// Claws: ivory to a gold root.
		col = mix(bone.rgb, vec3(1.0, 0.98, 0.9), smoothstep(0.0, 0.7, UV.y));
		col *= mix(0.7, 1.0, smoothstep(0.1, 0.6, facing));
	}
	ALBEDO = col;
}
