class_name NatureKit
extends RefCounted
## Places the Quaternius "Stylized Nature" models (CC0, assets/models/nature)
## as MultiMeshes. The pack's glTF files carry no textures, so every material
## is replaced here by a stylised one chosen from the material's name and a
## colour theme (see [constant THEMES]).
##
## Placements are split into square chunks so the GPU only draws what is near
## the camera (each chunk is culled / hidden by distance on its own).

const DIR := "res://assets/models/nature/"
const CHUNK := 36.0
const VIEW_DISTANCE := 85.0

## Per theme: leaf colours by material-name prefix, bark and rock colours.
const THEMES := {
	&"meadow": {
		"PineTree_Leaves": [Color("2c6b45"), Color("5fa66a")],
		"MapleTree_Leaves": [Color("4f9a3c"), Color("c5d65a")],
		"NormalTree_Leaves": [Color("3a8a45"), Color("8fd05e")],
		"BirchTree_Leaves": [Color("5aa44a"), Color("b4e36a")],
		"Bush_Leaves": [Color("2f7d3e"), Color("79c75a")],
		"PalmTree_Leaves": [Color("3a9a4a"), Color("8fe070")],
		"Grass": [Color("3f9a44"), Color("86d46a")],
		"Bark": Color("7a5236"), "BirchBark": Color("d8d2c4"), "PalmBark": Color("9a7448"),
		"Rock": [Color("9aa3b8"), Color("5ea35a")],
		"Flowers": [Color("ffffff"), Color("ffffff")],
	},
	&"digital": {
		"PineTree_Leaves": [Color("1f6b6a"), Color("55d6b4")],
		"MapleTree_Leaves": [Color("5a4aa8"), Color("b08aff")],
		"NormalTree_Leaves": [Color("23805f"), Color("6fe0a0")],
		"BirchTree_Leaves": [Color("3a8fa8"), Color("8fe8ff")],
		"Bush_Leaves": [Color("1f7f55"), Color("5fd6a0")],
		"PalmTree_Leaves": [Color("2a8f8a"), Color("7ff0d0")],
		"Grass": [Color("237a43"), Color("7fd89a")],
		"Bark": Color("5a4a6e"), "BirchBark": Color("a99cc4"), "PalmBark": Color("6e5a8a"),
		"Rock": [Color("7f86a8"), Color("57c7a4")],
		"Flowers": [Color("ffffff"), Color("ffffff")],
	},
	&"desert": {
		"PineTree_Leaves": [Color("8a8a3a"), Color("c9c36a")],
		"MapleTree_Leaves": [Color("a8803a"), Color("e0c070")],
		"NormalTree_Leaves": [Color("8a8a3a"), Color("c0c060")],
		"BirchTree_Leaves": [Color("9a8a40"), Color("d8c878")],
		"Bush_Leaves": [Color("7f8a3a"), Color("bdbf5a")],
		"PalmTree_Leaves": [Color("2f8a3a"), Color("8ad060")],
		"Grass": [Color("a89a50"), Color("e0cc78")],
		"Bark": Color("8a6a40"), "BirchBark": Color("d8c8a0"), "PalmBark": Color("a07a48"),
		"Rock": [Color("c9a878"), Color("b09060")],
		"Flowers": [Color("ffffff"), Color("ffffff")],
	},
	&"snow": {
		"PineTree_Leaves": [Color("2f6a58"), Color("eef6ff")],
		"MapleTree_Leaves": [Color("6f98b0"), Color("f0f8ff")],
		"NormalTree_Leaves": [Color("5a8aa0"), Color("eaf4ff")],
		"BirchTree_Leaves": [Color("7aa8c0"), Color("f4fbff")],
		"Bush_Leaves": [Color("4f8088"), Color("e0f0f8")],
		"PalmTree_Leaves": [Color("4f8088"), Color("e0f0f8")],
		"Grass": [Color("a8c8d8"), Color("f0faff")],
		"Bark": Color("6a5a58"), "BirchBark": Color("d8dce4"), "PalmBark": Color("7a6a68"),
		"Rock": [Color("a8b8d0"), Color("f4fbff")],
		"Flowers": [Color("ffffff"), Color("ffffff")],
	},
	&"volcano": {
		"PineTree_Leaves": [Color("3a2a2a"), Color("8a4a30")],
		"MapleTree_Leaves": [Color("5a2a20"), Color("c05a30")],
		"NormalTree_Leaves": [Color("4a2a24"), Color("a04a2a")],
		"BirchTree_Leaves": [Color("5a3028"), Color("b85a30")],
		"Bush_Leaves": [Color("4a2a20"), Color("a04a28")],
		"PalmTree_Leaves": [Color("4a2a20"), Color("a04a28")],
		"Grass": [Color("3a2a28"), Color("c0502a")],
		"Bark": Color("2a2020"), "BirchBark": Color("4a3a38"), "PalmBark": Color("3a2a28"),
		"Rock": [Color("403838"), Color("d0502a")],
		"Flowers": [Color("ffffff"), Color("ffffff")],
	},
}

static var _cache: Dictionary = {}
static var _foliage_shader: Shader
static var _rock_shader: Shader


## Mesh parts of a model: [{ "mesh": ArrayMesh, "xform": Transform3D }].
static func get_parts(model: String, theme: StringName = &"meadow") -> Array:
	var key := "%s|%s" % [model, theme]
	if _cache.has(key):
		return _cache[key]
	var parts: Array = []
	var packed := load(DIR + model + ".gltf") as PackedScene
	if packed:
		var root := packed.instantiate() as Node3D
		for node in root.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null:
				continue
			var mesh := mi.mesh.duplicate() as ArrayMesh
			var model_height := maxf(mesh.get_aabb().size.y, 0.1)
			for i in mesh.get_surface_count():
				var source := mi.mesh.surface_get_material(i)
				mesh.surface_set_material(i, _material_for(source.resource_name if source else "", theme, model_height))
			var xform := Transform3D.IDENTITY
			var n: Node = mi
			while n != null and n != root:
				if n is Node3D:
					xform = (n as Node3D).transform * xform
				n = n.get_parent()
			parts.append({"mesh": mesh, "xform": xform})
		root.free()
	else:
		push_warning("NatureKit: missing model %s" % model)
	_cache[key] = parts
	return parts


## Adds a node [param node_name] to [param parent] holding the chunked
## MultiMeshes for [param transforms] (placement transforms; the model's own
## node transform is applied on top). [param colors] = optional instance tint.
static func place(parent: Node3D, node_name: String, model: String, theme: StringName,
		transforms: Array[Transform3D], colors: Array[Color] = [], shadows := true, view_distance := VIEW_DISTANCE) -> Node3D:
	var holder := parent.get_node_or_null(node_name) as Node3D
	if holder == null:
		holder = Node3D.new()
		holder.name = node_name
		parent.add_child(holder)
	if transforms.is_empty():
		return holder
	var chunks: Dictionary = {}
	for i in transforms.size():
		var o := transforms[i].origin
		var cell := Vector2i(floori(o.x / CHUNK), floori(o.z / CHUNK))
		if not chunks.has(cell):
			chunks[cell] = []
		chunks[cell].append(i)
	var parts := get_parts(model, theme)
	for cell in chunks:
		var indices: Array = chunks[cell]
		for part in parts:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = not colors.is_empty()
			mm.mesh = part.mesh
			mm.instance_count = indices.size()
			for j in indices.size():
				mm.set_instance_transform(j, transforms[indices[j]] * (part.xform as Transform3D))
				if mm.use_colors:
					mm.set_instance_color(j, colors[indices[j]])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%d_%d" % [model, cell.x, cell.y]
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = view_distance * GameSettings.view_scale()
			mmi.custom_aabb = AABB(Vector3(cell.x * CHUNK - 8.0, -30.0, cell.y * CHUNK - 8.0), Vector3(CHUNK + 16.0, 80.0, CHUNK + 16.0))
			holder.add_child(mmi)
	return holder


static func _material_for(material_name: String, theme: StringName, model_height: float) -> Material:
	var colors: Dictionary = THEMES.get(theme, THEMES[&"meadow"])
	if material_name == "Rock":
		var rock := ShaderMaterial.new()
		rock.shader = _get_rock_shader()
		rock.set_shader_parameter("stone_color", colors.Rock[0])
		rock.set_shader_parameter("moss_color", colors.Rock[1])
		return rock
	if material_name.ends_with("Bark") or material_name.ends_with("Trunk"):
		var tone: Color = colors.BirchBark if material_name.begins_with("Birch") else (colors.PalmBark if material_name.begins_with("Palm") else colors.Bark)
		return MeshKit.toon(tone)
	var key := material_name if colors.has(material_name) else ("Bush_Leaves" if material_name.begins_with("Bush") else "NormalTree_Leaves")
	if material_name == "Flowers":
		key = "Flowers"
	var pair: Array = colors[key]
	var mat := ShaderMaterial.new()
	mat.shader = _get_foliage_shader()
	mat.set_shader_parameter("base_color", pair[0])
	mat.set_shader_parameter("top_color", pair[1])
	mat.set_shader_parameter("height_ref", model_height)
	var is_flower := material_name == "Flowers"
	mat.set_shader_parameter("tint_strength", 1.0 if is_flower else 0.2)
	mat.set_shader_parameter("sway", 0.02 if material_name.begins_with("Bush") or is_flower else 0.06)
	return mat


static func _get_foliage_shader() -> Shader:
	if _foliage_shader == null:
		_foliage_shader = load("res://shaders/foliage.gdshader")
	return _foliage_shader


static func _get_rock_shader() -> Shader:
	if _rock_shader == null:
		_rock_shader = load("res://shaders/rock.gdshader")
	return _rock_shader
