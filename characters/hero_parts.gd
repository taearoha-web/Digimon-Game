class_name HeroParts
extends RefCounted
## Mix-and-match pieces of the KayKit characters. All of them share the same
## 23 core bones, so a body, head, hat or cape taken from one character can be
## put on another one's skeleton.
##
## A part is looked up by [glb file, node name] and comes back as either
##   { kind:"skinned", mesh, skin }                      (body, head, ...)
##   { kind:"attach", mesh, xform, bone }                (hats / capes that were rigid bone attachments)

const DIR := "res://assets/models/characters/"

static var _cache: Dictionary = {}


static func get_part(glb: String, node_name: String) -> Dictionary:
	var key := glb + "|" + node_name
	if _cache.has(key):
		return _cache[key]
	var result := {}
	var packed := load(DIR + glb + ".glb") as PackedScene
	if packed:
		var root := packed.instantiate()
		var skeleton := root.find_child("Skeleton3D", true, false) as Skeleton3D
		var found := root.find_children(node_name, "MeshInstance3D", true, false)
		var node: Node = found[0] if not found.is_empty() else null
		if node is MeshInstance3D and skeleton:
			var mi := node as MeshInstance3D
			if mi.get_parent() is BoneAttachment3D:
				var attach := mi.get_parent() as BoneAttachment3D
				var bone := skeleton.find_bone(attach.bone_name)
				var parent := skeleton.get_bone_parent(bone)
				var rel := skeleton.get_bone_global_rest(parent).affine_inverse() * skeleton.get_bone_global_rest(bone) * mi.transform
				result = {"kind": "attach", "mesh": mi.mesh, "xform": rel, "bone": skeleton.get_bone_name(parent)}
			else:
				result = {"kind": "skinned", "mesh": mi.mesh, "skin": mi.skin}
		root.free()
	_cache[key] = result
	return result


## Adds the part to [param skeleton]; returns the new node (or null).
static func attach(skeleton: Skeleton3D, glb: String, node_name: String, tint := Color.WHITE) -> Node3D:
	var part := get_part(glb, node_name)
	if part.is_empty():
		push_warning("HeroParts: missing part %s/%s" % [glb, node_name])
		return null
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = part.mesh
	if tint != Color.WHITE:
		for i in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if source:
				var copy := source.duplicate() as StandardMaterial3D
				copy.albedo_color = source.albedo_color * tint
				mi.set_surface_override_material(i, copy)
	if part.kind == "skinned":
		# Parts from the 47-bone characters bind to extra (IK/prop) bones that the
		# base rig lacks: add them as inert bones so the skin indices stay valid.
		var skin: Skin = part.skin
		for i in skin.get_bind_count():
			var bind_name := skin.get_bind_name(i)
			if bind_name != "" and skeleton.find_bone(bind_name) < 0:
				skeleton.add_bone(bind_name)
		mi.skin = part.skin
		skeleton.add_child(mi)
		return mi
	var bone_attachment := BoneAttachment3D.new()
	bone_attachment.name = "Att_" + node_name
	bone_attachment.bone_name = part.bone
	skeleton.add_child(bone_attachment)
	mi.transform = part.xform
	bone_attachment.add_child(mi)
	return bone_attachment
