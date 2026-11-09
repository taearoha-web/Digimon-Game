// Shared toon surface detail (SurfaceKit, assets/textures/surfaces/surface_detail.jpg):
// one Texture2DArray of simplified, grey-centred detail layers drawn from CC0 photos. A
// texel of 0.5 leaves the painted colour as it is, so each zone keeps its own tint and the
// texture only adds the grain of grass, earth, stone, tiles and wood. SurfaceKit sets
// surface_amount to 0 (and binds no texture) on low quality: nothing is sampled then.

uniform sampler2DArray surface_detail : filter_linear_mipmap, repeat_enable;
uniform float surface_amount = 0.0;

const float SD_GRASS = 0.0;
const float SD_DIRT = 1.0;
const float SD_SAND = 2.0;
const float SD_COBBLE = 3.0;
const float SD_STONE_WALL = 4.0;
const float SD_ROOF = 5.0;
const float SD_WOOD = 6.0;
const float SD_ROCK = 7.0;

// The detail multiplier (1.0 on average) of `layer` at uv (in tiles).
vec3 sd_tex(vec2 uv, float layer) {
	return texture(surface_detail, vec3(uv, layer)).rgb * 2.0;
}

// A big floor: the layer at `scale` metres a tile, and again turned and at another scale
// where the low-frequency `mask` (0..1) says, so the repeat never lines up into a grid.
vec3 sd_ground(vec2 p, float layer, float scale, float mask) {
	vec3 a = sd_tex(p / scale, layer);
	vec2 q = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p / (scale * 1.37) + vec2(0.31, 0.57);
	vec3 b = sd_tex(q, layer);
	return mix(a, b, mask);
}

// One projection, picked by the dominant axis of the world normal: walls take the
// vertical planes, floors and tops the ground plane (one sample, cheap on phones).
vec3 sd_box(vec3 world_pos, vec3 world_normal, float layer, float scale) {
	vec3 n = abs(world_normal);
	vec2 uv = world_pos.xz;
	if (n.x > n.y && n.x > n.z) {
		uv = vec2(world_pos.z, -world_pos.y);
	} else if (n.z > n.y) {
		uv = vec2(world_pos.x, -world_pos.y);
	}
	return sd_tex(uv / scale, layer);
}

// colour times the detail, by `strength` (0..1) of the shared amount.
vec3 sd_apply(vec3 color, vec3 detail, float strength) {
	return color * mix(vec3(1.0), detail, clamp(strength * surface_amount, 0.0, 1.0));
}
