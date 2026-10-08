class_name StorybookFinish
extends RefCounted
## Shared satin finish for the game's characters and creatures. The imported
## textures, transparency and skinning stay intact in the Compatibility renderer.

static var _materials: Dictionary = {}
static var _outlines: Dictionary = {}
const CACHE_LIMIT := 384


## Several older outfit/monster palettes used HDR tints. Keep their hue while
## preventing bright coloured fabric from turning into a featureless white patch.
static func balanced_tint(tint: Color) -> Color:
	var peak := maxf(tint.r, maxf(tint.g, tint.b))
	var divisor := maxf(1.0, peak / 1.22)
	return Color(tint.r / divisor, tint.g / divisor, tint.b / divisor, tint.a)


static func outline(width := 0.012) -> StandardMaterial3D:
	var key := snappedf(width, 0.0001)
	if not _outlines.has(key):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color("302b46")
		mat.cull_mode = BaseMaterial3D.CULL_FRONT
		mat.grow = true
		mat.grow_amount = width
		if _outlines.size() >= 128:
			_outlines.erase(_outlines.keys()[0])
		_outlines[key] = mat
	return _outlines[key]


static func material(source: StandardMaterial3D, tint := Color.WHITE, width := 0.0, glossy := false) -> StandardMaterial3D:
	if source == null:
		return null
	# Imported scenes are released when a zone unloads. Their subresource paths
	# remain stable even when Godot assigns new instance IDs on the next visit.
	var identity := source.resource_path
	if identity.is_empty():
		identity = String(source.get_meta("storybook_key", ""))
	if identity.is_empty():
		identity = "generated:%d" % source.get_instance_id()
	var key := "%s|%s|%.4f|%s" % [identity, str(tint), width, glossy]
	if _materials.has(key):
		return _materials[key]
	var mat := source.duplicate() as StandardMaterial3D
	mat.albedo_color = source.albedo_color * balanced_tint(tint)
	if source.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
		# Broad soft highlights give the small forms volume without wet/plastic glare.
		mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		mat.metallic_specular = 0.3 if glossy else 0.16
		mat.roughness = 0.4 if glossy else 0.78
		mat.rim_enabled = true
		mat.rim = 0.18
		mat.rim_tint = 0.75
		if width > 0.0 and source.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
			mat.next_pass = outline(width)
	# Retained materials stay alive on their meshes after eviction. This also
	# bounds generated gear/appearance combinations during long play sessions.
	if _materials.size() >= CACHE_LIMIT:
		_materials.erase(_materials.keys()[0])
	mat.set_meta("storybook_key", key)
	_materials[key] = mat
	return mat
