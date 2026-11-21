class_name ChibiBodies
extends RefCounted
## The hero bodies to pick on the create screen: four per gender, 0 the original chibi
## (chibi_boy / chibi_girl, with its own clips). The others are the owner's sculpts,
## decimated, fitted to the same skeleton and skinned by tools/import_chibi.py; their
## glb holds only the skeleton and the body, and they play the clips of their gender's
## original (clips() — Godot drops the constant bone offsets on import, so the
## fitted bone lengths stay). A body loads only when someone wears it.
##
## look["body"] (FaceKit.repair keeps it): the index in BODIES[gender]; an unknown
## index (a newer game's body, a bad save) is the original.

const BODIES := [
	[
		{"name": "ฮีโร่ดั้งเดิม", "path": "res://assets/models/heroes/chibi_boy.glb"},
		{"name": "นักเดินทางผมเงิน", "path": "res://assets/models/heroes/chibi_silver.glb", "head": 0.81},
		{"name": "นินจาเงาม่วง", "path": "res://assets/models/heroes/chibi_ninja.glb", "head": 0.76},
		{"name": "หนุ่มน้อยผมหยิก", "path": "res://assets/models/heroes/chibi_curly.glb", "head": 0.84},
	],
	[
		{"name": "นักผจญภัยดั้งเดิม", "path": "res://assets/models/heroes/chibi_girl.glb"},
		{"name": "ภูตม่วงลาเวนเดอร์", "path": "res://assets/models/heroes/chibi_lavender.glb", "head": 0.81},
		{"name": "สาวเปียแดง", "path": "res://assets/models/heroes/chibi_braid.glb", "head": 0.81},
		{"name": "สาวผมมวยทอง", "path": "res://assets/models/heroes/chibi_bun.glb", "head": 0.84},
	],
]

static var _clips: Array = [null, null]
static var _base_rests: Array = [{}, {}]


static func count(gender: int) -> int:
	return (BODIES[clampi(gender, 0, 1)] as Array).size()


## The body index of a look; anything unknown is the original (0).
static func index(look: Dictionary) -> int:
	var i := int(look.get("body", 0))
	return i if i >= 0 and i < count(int(look.get("gender", 0))) else 0


static func info(look: Dictionary) -> Dictionary:
	return BODIES[clampi(int(look.get("gender", 0)), 0, 1)][index(look)]


static func path(look: Dictionary) -> String:
	return String(info(look).path)


static func body_name(gender: int, i: int) -> String:
	var list: Array = BODIES[clampi(gender, 0, 1)]
	return String(list[clampi(i, 0, list.size() - 1)].name)


## The original body of the gender (its clips, its weapon poses).
static func base_path(gender: int) -> String:
	return String(BODIES[clampi(gender, 0, 1)][0].path)


## How much smaller (or larger) this body's head is than the original's: head gear
## authored on the original is scaled by it.
static func head_scale(look: Dictionary) -> float:
	return float(info(look).get("head", 1.0))


## The clips of the gender's original body, shared by its other bodies.
static func clips(gender: int) -> AnimationLibrary:
	var g := clampi(gender, 0, 1)
	if _clips[g] == null:
		_load_base(g)
	return _clips[g]


## The original body's global rest of a bone (art authored on it in model space).
static func base_rest(gender: int, bone: String) -> Transform3D:
	var g := clampi(gender, 0, 1)
	if (_base_rests[g] as Dictionary).is_empty():
		_load_base(g)
	return _base_rests[g].get(bone, Transform3D.IDENTITY)


static func _load_base(g: int) -> void:
	var scene := (load(base_path(g)) as PackedScene).instantiate()
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_clips[g] = player.get_animation_library("")
	var skeleton := scene.find_child("Skeleton3D", true, false) as Skeleton3D
	var rests := {}
	for i in skeleton.get_bone_count():
		rests[skeleton.get_bone_name(i)] = skeleton.get_bone_global_rest(i)
	_base_rests[g] = rests
	scene.free()
