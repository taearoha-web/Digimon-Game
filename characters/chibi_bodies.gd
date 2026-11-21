class_name ChibiBodies
extends RefCounted
## The hero bodies to pick on the create screen: four per gender, 0 the original chibi
## (chibi_boy / chibi_girl, with its own clips). The others are the owner's sculpts,
## decimated, fitted to the same skeleton and skinned by tools/import_chibi.py; their
## glb holds only the skeleton and the body, and they play the clips of their gender's
## original (clips() — Godot drops the constant bone offsets on import, so the
## fitted bone lengths stay). A body loads only when someone wears it.
##
## look["body"] (FaceKit.hero_look keeps it): the index in BODIES[gender]; an unknown
## index (a newer game's body, a bad save) is the original.

const BODIES := [
	[
		{"name": "ฮีโร่ดั้งเดิม", "path": "res://assets/models/heroes/chibi_boy.glb"},
		{"name": "นักเดินทางผมเงิน", "path": "res://assets/models/heroes/chibi_silver.glb"},
		{"name": "นินจาเงาม่วง", "path": "res://assets/models/heroes/chibi_ninja.glb"},
		{"name": "หนุ่มน้อยผมหยิก", "path": "res://assets/models/heroes/chibi_curly.glb"},
	],
	[
		{"name": "นักผจญภัยดั้งเดิม", "path": "res://assets/models/heroes/chibi_girl.glb"},
		{"name": "ภูตม่วงลาเวนเดอร์", "path": "res://assets/models/heroes/chibi_lavender.glb"},
		{"name": "สาวเปียแดง", "path": "res://assets/models/heroes/chibi_braid.glb"},
		{"name": "สาวผมมวยทอง", "path": "res://assets/models/heroes/chibi_bun.glb"},
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


## The create screen's picture of a character (tools/render_body_cards.gd), or null.
static func card(gender: int, i: int) -> Texture2D:
	var file := "res://assets/ui/portraits/body_%d_%d.png" % [clampi(gender, 0, 1), i]
	return load(file) as Texture2D if ResourceLoader.exists(file) else null


## The original body of the gender (its clips, its weapon poses).
static func base_path(gender: int) -> String:
	return String(BODIES[clampi(gender, 0, 1)][0].path)


## How much smaller (or larger) this body's head is than the original's: head gear
## authored on the original is scaled by it. The pipeline scales the head's own bones
## (hair, face) with the head, so their reach from the head bone measures it.
static func head_scale(look: Dictionary, skeleton: Skeleton3D) -> float:
	if index(look) == 0 or skeleton == null:
		return 1.0
	var head := skeleton.find_bone("Head")
	var tip := skeleton.find_bone(HEAD_PROBE)
	if head < 0 or tip < 0:
		return 1.0
	var reach := (skeleton.get_bone_global_rest(tip).origin - skeleton.get_bone_global_rest(head).origin).length()
	var g := int(look.get("gender", 0))
	var base := (base_rest(g, HEAD_PROBE).origin - base_rest(g, "Head").origin).length()
	return clampf(reach / base, 0.5, 1.5) if base > 0.0001 else 1.0


const HEAD_PROBE := "Hair_Bang_C_1"


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
