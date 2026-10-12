shader_type spatial;
// The chibi heroes' body: their own texture, with the outfit recoloured by the
// worn armour tier. Vertex colour R marks where recolouring is allowed (not the
// head, hair or hands) and skin-coloured texels are always left alone.
render_mode diffuse_lambert_wrap, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 outfit_color : source_color = vec4(1.0);
uniform float outfit_amount : hint_range(0.0, 1.0) = 0.0;
uniform float sheen : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// Opt-in channel masks keep every existing Lv1-100 appearance identical.
// The new drop collection can recolour the original outfit's parts separately.
uniform bool part_masks_enabled = false;
uniform vec4 gloves_color : source_color = vec4(1.0);
uniform vec4 pants_color : source_color = vec4(1.0);
uniform vec4 boots_color : source_color = vec4(1.0);
uniform float gloves_amount : hint_range(0.0, 1.0) = 0.0;
uniform float pants_amount : hint_range(0.0, 1.0) = 0.0;
uniform float boots_amount : hint_range(0.0, 1.0) = 0.0;

varying float outfit_area;
varying vec3 part_areas;

void vertex() {
	outfit_area = COLOR.r;
	part_areas = COLOR.gba;
}

float skin_likeness(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = mx > 0.0 ? (mx - mn) / mx : 0.0;
	// Warm, light and moderately saturated, red above green above blue.
	float warm = step(c.b, c.g) * step(c.g, c.r);
	float light = smoothstep(0.52, 0.68, mx);
	float soft = 1.0 - smoothstep(0.42, 0.6, sat);
	float some = smoothstep(0.08, 0.16, sat);
	return warm * light * soft * some;
}

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	float cloth_texel = 1.0 - skin_likeness(base);
	float mask = outfit_area * cloth_texel * outfit_amount;
	vec3 active_parts = vec3(0.0);
	vec3 parts = vec3(0.0);
	if (part_masks_enabled) {
		active_parts = part_areas * step(vec3(0.0001), vec3(gloves_amount, pants_amount, boots_amount));
		parts = part_areas * cloth_texel;
		// A separately equipped part owns its colour, so torso dye cannot
		// change the boots/gloves/trousers underneath that override.
		mask *= 1.0 - clamp(active_parts.r + active_parts.g + active_parts.b, 0.0, 1.0);
	}
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	// Keep the folds and seams: the new colour follows the old brightness.
	vec3 dyed = outfit_color.rgb * (0.35 + lum * 1.45);
	ALBEDO = mix(base, dyed, mask);
	if (part_masks_enabled) {
		float glove = parts.r * gloves_amount;
		float pants = parts.g * pants_amount * (1.0 - active_parts.b);
		float boots = parts.b * boots_amount;
		ALBEDO = mix(ALBEDO, gloves_color.rgb * (0.35 + lum * 1.45), glove);
		ALBEDO = mix(ALBEDO, pants_color.rgb * (0.35 + lum * 1.45), pants);
		ALBEDO = mix(ALBEDO, boots_color.rgb * (0.35 + lum * 1.45), boots);
		mask = max(mask, max(glove, max(pants, boots)));
	}
	ROUGHNESS = mix(0.8, 0.35, sheen * mask);
	METALLIC = 0.0;
	SPECULAR = mix(0.16, 0.55, sheen * mask);
	RIM = 0.18;
	RIM_TINT = 0.75;
	EMISSION = glow_color.rgb * mask * lum;
}
