class_name DivineGearArt
extends RefCounted
## The supplied 200-star wardrobe, with deformation transferred onto the existing
## boy/girl hero rigs. No per-frame script, lights, particles or mesh rebuilding.
const DIR := "res://assets/models/divine_gear/"
const KINDS := {"warrior":"sword", "archer":"bow", "lancer":"spear", "mage":"staff", "priest":"wand", "summoner":"lantern", "defender":"greatshield"}
const COLORS := {"warrior":Color("eceaff"),"archer":Color("438954"),"lancer":Color("991f28"),"mage":Color("242b6b"),"priest":Color("eee7e0"),"summoner":Color("613965"),"defender":Color("2a3f74")}
const KAY_BONES := {"Hips":"hips","Spine":"spine","Chest":"chest","Neck":"head","Head":"head",
	"LeftShoulder":"upperarm.l","RightShoulder":"upperarm.r","LeftUpperArm":"upperarm.l","RightUpperArm":"upperarm.r",
	"LeftLowerArm":"lowerarm.l","RightLowerArm":"lowerarm.r","LeftHand":"wrist.l","RightHand":"wrist.r",
	"LeftUpperLeg":"upperleg.l","RightUpperLeg":"upperleg.r","LeftLowerLeg":"lowerleg.l","RightLowerLeg":"lowerleg.r",
	"LeftFoot":"foot.l","RightFoot":"foot.r","LeftToes":"toes.l","RightToes":"toes.r"}
static var _wear_cache: Dictionary = {}


## Dropped when a zone is left (Main._clear_zone): the next wearer rebuilds its entry.
static func release_cache() -> void:
	_wear_cache.clear()

static func cloth(cls: String) -> Color:
	return COLORS.get(cls, COLORS.warrior)

static func build_weapon(cls: String) -> Node3D:
	return _held(cls, String(KINDS.get(cls,"sword")))

static func offhand(cls: String) -> Node3D:
	match cls:
		"warrior": return _held(cls,"shield")
		"priest": return _held(cls,"book")
		"summoner": return _held(cls,"tome")
	return Node3D.new()

static func build(look: String) -> Node3D:
	var bits := look.split("_")
	if bits.size() != 4:
		return Node3D.new()
	return _held(String(bits[2]), String(bits[1]))

static func _held(cls: String, kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Divine_" + cls + "_" + kind
	var path := DIR + cls + "_" + kind + ".glb"
	if not ResourceLoader.exists(path): return root
	var model := (load(path) as PackedScene).instantiate() as Node3D
	root.add_child(model)
	var size := {"sword":1.45,"bow":1.28,"spear":1.4,"staff":1.28,"wand":1.65,"lantern":1.9,"shield":0.9,"book":1.5,"tome":1.5,"greatshield":1.15}
	model.scale = Vector3.ONE * float(size.get(kind,1.0))
	# Source lantern bulb is on +X; face it forward (+Z) around its shaft.
	if kind == "lantern": model.rotation.y = -PI * 0.5
	# Uploaded grimoires open flat with pages towards +Y. Held convention is +Z.
	if kind in ["book","tome"]:
		model.rotation.x = PI * 0.5
		model.position = Vector3(0,0.045,-0.15) * model.scale.x
	# Shield source handle sits behind its face.
	if kind == "shield": model.position.z = 0.074 * model.scale.x
	_prepare(model)
	root.set_meta("divine_gear",true)
	root.set_meta("weapon_kind",kind)
	return root

static func _prepare(root: Node3D) -> void:
	for child in root.find_children("*","MeshInstance3D",true,false):
		var mi := child as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("no_outline",true)
		mi.set_meta("divine_gear",true)
		mi.set_meta("polished",true)
	for child in root.find_children("*","AnimationPlayer",true,false):
		var anim := child as AnimationPlayer
		for clip in anim.get_animation_list():
			if String(clip).get_slice("/",String(clip).get_slice_count("/")-1) == "Idle":
				anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				anim.play(clip)
				break

## Returns cleanup nodes for HeroVisual._body_nodes. The pieces share the hero's
## real skeleton, so sleeves, gloves, pants and boots follow each action pose.
static func attach_slot(skeleton: Skeleton3D, cls: String, gender: int, slot: String, chibi := true) -> Array:
	var key := "%s_%s_%s" % [cls,"girl" if gender == 1 else "boy",slot]
	var path := DIR + key + ".glb"
	if skeleton == null or not ResourceLoader.exists(path): return []
	var cache_key := key + ("_chibi" if chibi else "_kaykit")
	if not _wear_cache.has(cache_key):
		var packed := (load(path) as PackedScene).instantiate() as Node3D
		var source_skeleton := packed.find_child("Skeleton3D",true,false) as Skeleton3D
		var entries: Array = []
		for child in packed.find_children("*","MeshInstance3D",true,false):
			var src := child as MeshInstance3D
			if src.skin == null or src.mesh == null: continue
			var skin := src.skin.duplicate() as Skin
			var remaps: Array[Transform3D] = []
			for i in skin.get_bind_count():
				var bone := String(skin.get_bind_name(i))
				if bone.is_empty() and source_skeleton != null:
					bone = source_skeleton.get_bone_name(skin.get_bind_bone(i))
				var dest := bone if chibi else _kay_bone(bone)
				var index := skeleton.find_bone(dest)
				if index < 0:
					dest = "Chest" if chibi else "chest"
					index = skeleton.find_bone(dest)
				skin.set_bind_name(i,dest)
				skin.set_bind_bone(i,index)
				if not chibi:
					var rest := skeleton.get_bone_global_rest(index)
					var source_rest := skin.get_bind_pose(i).affine_inverse()
					# Rig bone roll conventions differ; keep the authored world-up shape.
					var offset := rest.origin-source_rest.origin*2.2
					if slot == "helm": offset.y += 0.3
					remaps.append(Transform3D(Basis.from_scale(Vector3.ONE * 2.2),offset))
					skin.set_bind_pose(i,rest.affine_inverse())
			var mesh: Mesh = src.mesh if chibi else _retarget_mesh(src.mesh,remaps)
			entries.append({"mesh":mesh,"skin":skin})
		packed.free()
		_wear_cache[cache_key] = entries
	var root := Node3D.new()
	root.name = "DivineWear_" + slot
	skeleton.add_child(root)
	for entry in _wear_cache[cache_key]:
		var mi := MeshInstance3D.new()
		mi.name = "Divine_" + slot
		mi.mesh = entry.mesh
		mi.skin = entry.skin
		root.add_child(mi)
		mi.skeleton = mi.get_path_to(skeleton)
	_prepare(root)
	return [root]

static func _kay_bone(bone: String) -> String:
	if KAY_BONES.has(bone): return KAY_BONES[bone]
	if bone.begins_with("Left"): return "wrist.l"
	if bone.begins_with("Right"): return "wrist.r"
	if bone.begins_with("Skirt"): return "hips"
	return "head" if bone.begins_with("Hair") else "chest"

## Bounded one-time fallback conversion for the stock KayKit rig. Each uploaded
## vertex is moved from its source bind pose to the destination bind pose; skin
## weights then keep that silhouette attached during the existing animations.
static func _retarget_mesh(source: Mesh, maps: Array[Transform3D]) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var count := int(bones.size()/maxi(vertices.size(),1))
		for i in vertices.size():
			var point := Vector3.ZERO
			var normal := Vector3.ZERO
			for j in count:
				var at := i*count+j
				if weights[at] <= 0.0: continue
				var transform := maps[bones[at]]
				point += (transform * vertices[i])*weights[at]
				if not normals.is_empty(): normal += (transform.basis * normals[i])*weights[at]
			vertices[i] = point
			if not normals.is_empty(): normals[i] = normal.normalized()
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		# Regenerate/imported tangent frames do not survive a different bind pose.
		arrays[Mesh.ARRAY_TANGENT] = null
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(surface,source.surface_get_material(surface))
	return mesh
