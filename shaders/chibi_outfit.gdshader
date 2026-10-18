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

// Hero looks (ChibiLook): skin tone anywhere, hair colour and eye colour inside
// the baked mask (R hair area, G eye area). Off unless a look sets them.
uniform bool look_enabled = false;
uniform sampler2D look_mask : filter_linear_mipmap;
uniform vec4 skin_color : source_color = vec4(1.0);
uniform vec4 hair_color : source_color = vec4(1.0);
uniform vec4 eye_color : source_color = vec4(1.0);
uniform float skin_amount : hint_range(0.0, 1.0) = 0.0;
uniform float hair_amount : hint_range(0.0, 1.0) = 0.0;
uniform float eye_amount : hint_range(0.0, 1.0) = 0.0;
// The texture's own skin, which a chosen tone replaces by ratio (keeps shading).
const vec3 SKIN_REF = vec3(0.96, 0.76, 0.64);

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

vec3 apply_look(vec3 base, float skin_texel, vec2 uv) {
	vec2 area = texture(look_mask, uv).rg;
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	float mx = max(base.r, max(base.g, base.b));
	float mn = min(base.r, min(base.g, base.b));
	float sat = mx > 0.0 ? (mx - mn) / mx : 0.0;
	// R: 1 = hair and brows for sure, 0.5 = the rest of the head (scalp or face).
	float pure_hair = smoothstep(0.7, 0.85, area.r);
	float head = max(smoothstep(0.25, 0.4, area.r), smoothstep(0.25, 0.4, area.g));
	// On the head the texture is dark hair, dark eyes or light skin: a light, warm
	// texel there is skin even in shadow or blush, where skin_likeness() is strict.
	float warm = step(base.b, base.g + 0.03) * step(base.g, base.r + 0.03);
	// Near-white texels (the eye whites, highlights) are never skin.
	float face_skin = head * warm * smoothstep(0.42, 0.56, lum) * (1.0 - smoothstep(0.55, 0.7, sat)) * smoothstep(0.07, 0.13, sat);
	// Bang and brow geometry also covers some forehead and brow edges: only light
	// skin counts there (hair highlights stay below lum 0.6).
	float light_skin = face_skin * smoothstep(0.56, 0.64, lum);
	float skin = mix(max(skin_texel, face_skin), max(skin_texel, light_skin), pure_hair);
	skin *= 1.0 - smoothstep(0.25, 0.4, area.g) * (1.0 - smoothstep(0.08, 0.14, sat));
	vec3 c = base;
	// Hair: hair and brow geometry, and the dark texels of the scalp. Its shading
	// keeps the strands: light colours lift the dark source, highlights stay.
	float hair = smoothstep(0.25, 0.4, area.r) * (1.0 - skin) * (1.0 - smoothstep(0.25, 0.4, area.g)) * hair_amount;
	c = mix(c, hair_color.rgb * clamp(0.38 + lum * 2.3, 0.0, 1.35), hair);
	// Iris: the coloured part of the eye area, dark at the top and lighter below
	// (that lower glow is warm and light like skin, but amber rather than pink).
	// The white, the highlights and the near-black lashes and outline stay.
	float dark_iris = (1.0 - smoothstep(0.32, 0.5, lum)) * (1.0 - skin);
	// Measured on both bodies: eye-area skin is light (lum 0.6+) with blue at 60-70%
	// of red; the iris glow is darker (lum 0.4-0.55) with blue at 40-60% of red.
	float blue_ratio = base.b / max(base.r, 0.01);
	float glow_iris = (1.0 - smoothstep(0.58, 0.64, blue_ratio)) * smoothstep(0.2, 0.3, sat) * (1.0 - smoothstep(0.56, 0.63, lum));
	// G: 1 = the iris core, 0.5 = the rest of the eye (lids). The light glow only
	// counts in the core, where the lid's similar shading cannot be.
	float eye_area = smoothstep(0.25, 0.4, area.g);
	glow_iris *= smoothstep(0.7, 0.85, area.g);
	float iris = eye_area * max(dark_iris, glow_iris) * smoothstep(0.05, 0.12, lum) * eye_amount;
	skin *= 1.0 - glow_iris;
	c = mix(c, eye_color.rgb * (0.3 + lum * 2.0), iris);
	// Skin tone by ratio to the texture's own skin, keeping its shading.
	c = mix(c, min(base / SKIN_REF * skin_color.rgb, vec3(1.0)), skin * skin_amount);
	return c;
}

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	float skin_texel = skin_likeness(base);
	float cloth_texel = 1.0 - skin_texel;
	if (look_enabled) {
		base = apply_look(base, skin_texel, UV);
	}
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
