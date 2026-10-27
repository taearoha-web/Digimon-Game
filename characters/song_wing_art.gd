class_name SongWingArt
extends RefCounted
## Dresses the Bard's wing models (tools/make_bard_gear.py) with animated shaders:
## the feathers get song_wing.gdshader (Lv.100: ivory vanes blushing to rose gold at
## the tips; star: pearl shifting through rose and violet, twinkling with starlight in
## a gold filigree; both edged and shafted in gold with sound rippling out from the
## shoulders), and the staff ribbons, the star pair's circular staff and the notes
## drifting off the wing tips get song_wing_glow.gdshader. Parts are found by their
## glTF material name; bones, the clef, the lyre and the notes on the staff keep their
## imported materials. The materials are shared by every pair (their motion runs on
## TIME), so dressing adds no per-frame work; on the lowest quality nothing moves.

const WING_SHADER := preload("res://shaders/song_wing.gdshader")
const GLOW_SHADER := preload("res://shaders/song_wing_glow.gdshader")
## Everywhere the wings and their drifting notes reach, spread, flapping or folded
## (model space): the drift carries notes past the mesh's own bounds.
const BOUNDS := AABB(Vector3(-1.4, -0.6, -1.3), Vector3(2.8, 2.6, 1.7))
const GOLD := Color("f2c45a")
## Per part: draw order among the pair's see-through layers and shader parameters
## for the Lv.100 pair ("song") and the star pair ("star").
const PARTS := {
	"primary": {"song": {"root_color": Color("fff4e8"), "tip_color": Color("eaa58c"), "edge_color": GOLD, "tip_from": 0.3, "glow": 0.32, "lift": 0.28},
		"star": {"root_color": Color("fbf6ff"), "tip_color": Color("f2a0cc"), "deep_color": Color(0.56, 0.42, 0.92, 0.85), "edge_color": Color("ffd36b"),
			"tip_from": 0.25, "glow": 0.45, "irid": 0.55, "sparkle": 1.0, "filigree": 1.0}},
	"secondary": {"song": {"root_color": Color("fff6ec"), "tip_color": Color("f1b9a4"), "edge_color": GOLD, "tip_from": 0.4, "glow": 0.3, "lift": 0.28},
		"star": {"root_color": Color("f9f4ff"), "tip_color": Color("eaa6d8"), "deep_color": Color(0.62, 0.48, 0.94, 0.7), "edge_color": Color("ffd36b"),
			"tip_from": 0.35, "glow": 0.42, "irid": 0.5, "sparkle": 1.0, "filigree": 1.0}},
	"covert": {"song": {"root_color": Color("fff8f0"), "tip_color": Color("f6d6c2"), "edge_color": GOLD, "tip_from": 0.45, "edge_width": 0.2, "glow": 0.3, "lift": 0.3},
		"star": {"root_color": Color("fefaff"), "tip_color": Color("f6d4ec"), "edge_color": Color("ffd36b"), "tip_from": 0.4, "edge_width": 0.2,
			"glow": 0.4, "irid": 0.35, "sparkle": 0.6, "filigree": 1.0}},
	"aurora": {"star": {"root_color": Color("f4c4ea"), "tip_color": Color("9c82f0"), "deep_color": Color(0.36, 0.3, 0.86, 0.9), "edge_color": Color("ffd36b"),
		"tip_from": 0.2, "glow": 0.55, "irid": 0.6, "sparkle": 1.0}},
	"staff": {"priority": 1, "glow": true, "song": {"line_color": Color("ffd36b"), "glow_color": Color("ffb6d6")},
		"star": {"line_color": Color("ffe08a"), "glow_color": Color("d2b0ff")}},
	"wheel": {"priority": 1, "glow": true, "star": {"line_color": Color("ffe08a"), "glow_color": Color("d2b0ff"), "ends": 0.0, "opacity": 0.9}},
	"drift": {"priority": 2, "glow": true, "song": {"kind": 2.0, "glow_color": Color("ff9ad2")}, "star": {"kind": 2.0, "glow_color": Color("c6a6ff")}},
}
static var _materials: Dictionary = {}


static func dress(root: Node3D, star: bool) -> void:
	var still := GameSettings.quality == 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var dressed := false
		for i in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(i)
			if source != null and PARTS.has(source.resource_name) and PARTS[source.resource_name].has("star" if star else "song"):
				mi.set_surface_override_material(i, material(source.resource_name, star, still))
				dressed = true
		if dressed:
			mi.custom_aabb = BOUNDS


## Draws the feather and the glow shader once, out of sight, so the first Bard with wings
## to walk in (a world player, a guild-war fighter) does not compile them mid-fight.
static func warm_up(parent: Node3D, at: Vector3) -> void:
	var still := GameSettings.quality == 0
	for part in ["primary", "staff"]:
		var sample := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * 0.01
		sample.mesh = quad
		sample.material_override = material(part, false, still)
		sample.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sample.position = at
		parent.add_child(sample)
		sample.create_tween().tween_interval(0.4).finished.connect(sample.queue_free, CONNECT_ONE_SHOT)


static func material(part: String, star: bool, still := false) -> ShaderMaterial:
	var key := "%s_%s_%s" % [part, "star" if star else "song", "still" if still else "moving"]
	if not _materials.has(key):
		var spec: Dictionary = PARTS[part]
		var mat := ShaderMaterial.new()
		mat.shader = GLOW_SHADER if spec.get("glow", false) else WING_SHADER
		mat.render_priority = int(spec.get("priority", 0))
		var params: Dictionary = spec["star" if star else "song"]
		for name in params:
			mat.set_shader_parameter(name, params[name])
		mat.set_shader_parameter("motion", 0.0 if still else 1.0)
		_materials[key] = mat
	return _materials[key]
