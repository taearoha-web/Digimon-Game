shader_type spatial;
// Living plants that grow: everything past `growth` along the mesh's UV.y is
// cut away, so a vine winds out of the ground and its thorns and leaves appear
// as it reaches them. Colours come from the vertex colours (bark, leaf, flower).
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform float growth : hint_range(0.0, 1.0) = 1.0;
uniform float wither : hint_range(0.0, 1.0) = 0.0;
varying vec3 plant_position;

void vertex() {
	plant_position = VERTEX;
	// A little movement through the growing tips gives the plant a living form.
	float flex = UV.y * UV.y * (1.0 - wither) * growth;
	VERTEX.x += sin(TIME * 1.8 + VERTEX.y * 1.6 + VERTEX.z) * 0.035 * flex;
	VERTEX.z += cos(TIME * 1.4 + VERTEX.y * 1.3 + VERTEX.x) * 0.025 * flex;
}

void fragment() {
	if (UV.y > growth) {
		discard;
	}
	vec3 col = COLOR.rgb;
	// Soft pigment variation follows the plant, without dark zebra-like stripes.
	float grain = sin(plant_position.y * 18.0 + plant_position.x * 7.0 + plant_position.z * 5.0);
	col *= 0.95 + 0.05 * grain;
	float green = smoothstep(0.015, 0.16, COLOR.g - COLOR.r);
	float vein = 1.0 - smoothstep(0.018, 0.055, abs(UV.x - 0.5));
	col = mix(col, vec3(0.7, 0.84, 0.43), vein * green * 0.18);
	col = mix(col, vec3(0.48, 0.37, 0.28), wither * 0.68);
	ALBEDO = col;
	// A brief pale green growing edge, gone once the plant reaches full height.
	float sap = (1.0 - smoothstep(0.0, 0.06, abs(UV.y - growth))) * (1.0 - step(0.995, growth));
	EMISSION = vec3(0.42, 0.65, 0.27) * sap * (1.0 - wither) * 0.14;
	ROUGHNESS = 0.82;
}
