class_name ShadowWingArt
extends RefCounted
## Dresses the Assassin's wing models (tools/make_assassin_gear.py) with animated
## shaders: the membranes, the under wing and the shadow tendrils get
## shadow_wing.gdshader, the star pair's phantom double and eclipse corona get
## shadow_wing_glow.gdshader. Parts are found by their glTF material
## name; bones, blades, hems and gems keep their imported materials. The
## materials are shared by every pair (their motion runs on TIME), so dressing
## adds no per-frame work.

const WING_SHADER := preload("res://shaders/shadow_wing.gdshader")
const GLOW_SHADER := preload("res://shaders/shadow_wing_glow.gdshader")
## The star halo's centre in wing model space (HALO_CENTRE in make_assassin_gear.py).
const HALO_CENTRE := Vector3(0.0, 0.84, -0.3)
## Per part: draw order among the pair's see-through layers and shader parameters
## for the Lv.100 pair ("night") and the star pair ("star").
const PARTS := {
	"phantom": {"priority": -3, "glow": true, "night": {}, "star": {"primary": Color("7b45e0"), "accent": Color("ff5c8a"), "intensity": 0.9}},
	"under": {"priority": -2, "night": {"core": Color("07040d"), "mid": Color("2e1660"), "edge": Color("8f5cff"), "opacity": 0.95},
		"star": {"core": Color("0a040f"), "mid": Color("4a1650"), "edge": Color("ff4f8f"), "opacity": 0.95}},
	"membrane": {"priority": -1, "night": {"core": Color("140b26"), "mid": Color("3d1f78"), "edge": Color("b58cff")},
		"star": {"core": Color("0d0412"), "mid": Color("4b1f86"), "edge": Color("ff6f9c"), "spark": Color("ffe6f0")}},
	"wisp": {"priority": 1, "night": {"mid": Color("6a2fd0"), "edge": Color("d6b8ff"), "opacity": 0.92, "wisp": 1.0},
		"star": {"mid": Color("8a2a9e"), "edge": Color("ff8fb6"), "opacity": 0.95, "wisp": 1.0}},
	"flare": {"priority": 2, "glow": true, "night": {}, "star": {"accent": Color("ff3a6e"), "flame": 1.0, "centre": HALO_CENTRE}},
}
static var _materials: Dictionary = {}


static func dress(root: Node3D, star: bool) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(i)
			if source != null and PARTS.has(source.resource_name):
				mi.set_surface_override_material(i, material(source.resource_name, star))


static func material(part: String, star: bool) -> ShaderMaterial:
	var key := "%s_%s" % [part, "star" if star else "night"]
	if not _materials.has(key):
		var spec: Dictionary = PARTS[part]
		var mat := ShaderMaterial.new()
		mat.shader = GLOW_SHADER if spec.get("glow", false) else WING_SHADER
		mat.render_priority = int(spec.priority)
		var params: Dictionary = spec["star" if star else "night"]
		for name in params:
			mat.set_shader_parameter(name, params[name])
		_materials[key] = mat
	return _materials[key]
