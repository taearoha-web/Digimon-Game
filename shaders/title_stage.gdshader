shader_type spatial;
// The character select's painted platform (TitleStage). The selected hero's rune
// circle and its number crystal turn from blue to gold: inside those two shapes the
// painting's blue glow is re-tinted gold at the same brightness, so the stone floor,
// the sky and the white sparkle cores keep their colours. A second set fades the
// previously selected circle back to blue.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;

uniform sampler2D image : source_color, filter_linear;
// Where the painting lies on the backdrop quad (which covers the whole screen), in the
// quad's UV: offset, size. Outside it the painting is mirrored, so a screen wider or
// taller than the painting shows its own edges instead of flat bands.
uniform vec4 image_uv = vec4(0.0, 0.0, 1.0, 1.0);
// Circle centre and half-size in UV, crystal centre and half-size in UV, 0..1 blend.
uniform vec2 circle_centre = vec2(-1.0);
uniform vec2 circle_half = vec2(0.07, 0.02);
uniform vec2 gem_centre = vec2(-1.0);
uniform vec2 gem_half = vec2(0.016, 0.035);
uniform float amount = 0.0;
uniform vec2 old_circle_centre = vec2(-1.0);
uniform vec2 old_circle_half = vec2(0.07, 0.02);
uniform vec2 old_gem_centre = vec2(-1.0);
uniform vec2 old_gem_half = vec2(0.016, 0.035);
uniform float old_amount = 0.0;
uniform vec3 gold = vec3(1.0, 0.72, 0.24);

float spot_mask(vec2 uv, vec2 c, vec2 h, vec2 gc, vec2 gh) {
	// The circle: an ellipse with a soft rim. The crystal: a diamond.
	// Slightly past the painted rim, so its soft blue halo on the stone turns gold too.
	float ring = 1.0 - smoothstep(1.0, 1.22, length((uv - c) / h));
	vec2 g = abs(uv - gc) / gh;
	float gem = 1.0 - smoothstep(0.85, 1.05, g.x + g.y);
	return max(ring, gem);
}

vec3 to_gold(vec3 c, float pulse) {
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	// White cores stay hot; mid glow becomes saturated gold.
	vec3 tinted = gold * lum * (1.38 + pulse) + vec3(0.16 * lum * lum);
	return clamp(tinted, 0.0, 1.0);
}

vec2 mirrored(vec2 p) {
	return vec2(1.0) - abs(vec2(1.0) - mod(abs(p), vec2(2.0)));
}

uniform vec3 sky = vec3(0.31, 0.61, 0.9);

void fragment() {
	vec2 img = (UV - image_uv.xy) / image_uv.zw;
	// Sideways the painting mirrors (towers, islands, sky); above and below (a tall
	// window) it fades into the sky instead of standing on its head.
	vec2 at = vec2(mirrored(vec2(img.x, 0.0)).x, clamp(img.y, 0.0, 1.0));
	vec3 c = texture(image, at).rgb;
	// The fade starts a little inside the painting so no stretched edge row shows.
	float beyond = max(-img.y, img.y - 1.0);
	c = mix(c, sky, smoothstep(-0.07, 0.01, beyond));
	// How much of this pixel is the painting's blue magic light (not stone, not white).
	float blue = smoothstep(0.06, 0.26, c.b - c.r) * smoothstep(0.35, 0.6, c.b);
	float pulse = 0.08 * sin(TIME * 3.0);
	float now = spot_mask(img, circle_centre, circle_half, gem_centre, gem_half) * amount;
	float before = spot_mask(img, old_circle_centre, old_circle_half, old_gem_centre, old_gem_half) * old_amount;
	float k = clamp(max(now, before) * blue, 0.0, 1.0);
	ALBEDO = mix(c, to_gold(c, pulse), k);
}
