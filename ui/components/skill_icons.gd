class_name SkillIcons
extends RefCounted
## Shared authored illustrations, keyed by skill identity rather than spell type.
## Godot imports the SVGs once. Drawing never creates images, shaders or nodes.

static var _textures: Dictionary = {}
static var _name_ids: Dictionary = {}


static func for_skill(skill: Dictionary) -> Texture2D:
	return for_id(String(skill.get("id", "")))


static func for_id(id: String) -> Texture2D:
	if _textures.has(id):
		return _textures[id] as Texture2D
	if id.is_empty() or not id.is_valid_identifier():
		return null
	var path := "res://assets/icons/skills/%s.svg" % id
	var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_textures[id] = texture
	return texture


static func for_name(display_name: String) -> Texture2D:
	# Buffs received from party members carry the display name. Build the
	# cross-class index once, so their timer uses the same art as the source.
	if _name_ids.is_empty():
		var families: Array[StringName] = [&"vagabond"]
		families.append_array(ClassData.IDS)
		for family in families:
			for skill in ClassData.pool(family):
				_name_ids[String(skill.name)] = String(skill.id)
	return for_id(String(_name_ids.get(display_name, "")))


static func portrait(skill: Dictionary, extent := 64.0) -> TextureRect:
	var view := UIUtil.texture_rect(for_skill(skill), Vector2.ONE * extent)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return view
