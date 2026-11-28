extends RefCounted
## Bard Ascension ultimate (★500): ระบำสะกดใจ, an enchanting dance tune (AscendUlt plays it:
## combat/ascend_ult/universe_hymn.gd owns the stage, the charm, the dance and the finale).
## This is its wind-up only, cosmetic: the bard strikes up the tune. A golden lyre over the
## bard, notes swirling up round it, and where it aimed the stage being chalked out: a
## rose ring the size of the skill's radius, a turning gold rune circle inside it and
## hearts drifting up off the floor. No orchestra, no sound waves: the release and
## everything after are the script's.
const ID := "universe_hymn"
const PINK := Color("ff5aa8")
const GOLD := Color("e0b04a")


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D if is_instance_valid(art) else null
	if parent == null or not is_instance_valid(caster):
		return true
	var c := StarSkillArt.look(skill)
	var stage := Vector3(point.x, 0, point.z)
	var radius := clampf(float(skill.get("radius", 10.0)), 4.0, 12.0)
	# The tune: a lyre over the bard, notes swirling up round it.
	art.add("lyre", c, Vector3(0, 2.6, 0.5), Vector3.ONE * 1.0, Vector3.ZERO, time + 0.1,
		{"initial": 0.2, "grow_time": 0.75, "fade_in": 0.12, "decay": 0.97, "face_camera": true, "pulse": true, "opacity": 0.92})
	art.add("note_swirl", c, Vector3.UP * 0.2, Vector3(1.5, 2.4, 1.5), Vector3.ZERO, time + 0.1,
		{"initial": 0.3, "grow_time": 0.7, "fade_in": 0.1, "spin": 1.6, "decay": 0.96, "opacity": 0.85})
	VfxArt.motes(parent, caster.global_position, PINK, "heart", 8, 0.9, 1.2, maxf(time, 0.8))
	# The stage where it aimed.
	VfxKit.ground_circle(parent, stage, PINK, radius, time)
	VfxArt.rune_circle(parent, stage, GOLD, radius * 0.7, time, 0.8)
	VfxArt.motes(parent, stage, PINK, "heart", 14, radius * 0.5, 0.2, maxf(time, 0.9))
	return true


## The waves and the finale are the script's (AscendUlt): nothing shared draws them.
static func wave(_art: StarSkillArt, _parent: Node3D, _skill: Dictionary, _index: int, _point: Vector3, _source: Vector3) -> bool:
	return true


static func finale(_art: StarSkillArt, _parent: Node3D, _skill: Dictionary, _point: Vector3, _source: Vector3) -> bool:
	return true
