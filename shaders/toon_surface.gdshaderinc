// Vertex-coloured toon surfaces with shared detail textures (SurfaceKit.vertex_material):
// the village's and the castle's batched buildings, and the castle's dressed stone. The
// vertex colour's alpha carries the surface kind (SurfaceKit.tag); `default_kind` covers
// meshes without one (MultiMesh instance colours). UV is in metres along each face
// (JapanKit.Batch), so planks, tiles and courses follow the building, not the world.
#include "res://shaders/surface_detail.gdshaderinc"

uniform bool srgb_colors = true;
uniform int default_kind = 0;
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec3 c = COLOR.rgb;
	// As BaseMaterial3D's vertex_color_is_srgb: only where the output is linear (not in the
	// Compatibility renderer, which shades in sRGB).
	if (srgb_colors && !OUTPUT_IS_SRGB) {
		c = mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
	}
	if (surface_amount > 0.0) {
		int kind = int(round((1.0 - COLOR.a) * 16.0));
		if (kind == 0) {
			kind = default_kind;
		}
		if (kind == 1) {
			c = sd_apply(c, sd_tex(UV / 1.7, SD_WOOD), 0.8);
		} else if (kind == 2) {
			// Plaster: a faint trowelled mottle only.
			c = sd_apply(c, sd_box(world_pos, world_normal, SD_ROCK, 4.0), 0.15);
		} else if (kind == 3) {
			c = sd_apply(c, sd_tex(UV / 2.4, SD_STONE_WALL), 0.85);
		} else if (kind == 4) {
			c = sd_apply(c, sd_tex(UV / 2.2, SD_ROOF), 0.9);
		} else if (kind == 5) {
			// Dressed castle blocks: the geometry already draws the courses; the stone
			// only takes a weathered grain, bolder on the faces than on the tops.
			c = sd_apply(c, sd_box(world_pos, world_normal, SD_ROCK, 3.0), 0.4);
		} else if (kind == 6) {
			// Natural ground: rock on the slopes, packed earth where it levels out.
			float level = smoothstep(0.55, 0.85, world_normal.y);
			vec3 rock = sd_box(world_pos, world_normal, SD_ROCK, 2.6);
			vec3 earth = sd_tex(world_pos.xz / 3.0, SD_DIRT);
			c = sd_apply(c, mix(rock, earth, level), 0.8);
		}
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
