shader_type spatial;
// Living plants that grow: everything past `growth` along the mesh's UV.y is
// cut away, so a vine winds out of the ground and its thorns and leaves appear
// as it reaches them. Colours come from the vertex colours (bark, leaf, flower).
render_mode cull_disabled, diffuse_toon, specular_disabled;

uniform float growth : hint_range(0.0, 1.0) = 1.0;
uniform float wither : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	if (UV.y > growth) {
		discard;
	}
	vec3 col = COLOR.rgb;
	// Bark rings along the stem; withering browns and darkens it.
	col *= 0.88 + 0.12 * sin(UV.y * 90.0);
	col = mix(col, vec3(0.42, 0.33, 0.2), wither * 0.7);
	ALBEDO = col;
	ROUGHNESS = 0.9;
}
