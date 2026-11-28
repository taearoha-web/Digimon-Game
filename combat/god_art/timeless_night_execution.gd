extends RefCounted
## Assassin Ascension ultimate (★500): ประหารเลือดพร่อง. Its wind-up only: a blood moon
## rises behind the assassin over a fang seal, and the mark of the execution closes on its
## foe. From the release on the vanish, the blink and the one slash are the cast's
## (combat/ascend_ult/timeless_night_execution.gd, an AscendUlt): no waves, no finale here.
const ID := "timeless_night_execution"


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, _point: Vector3, time: float) -> bool:
	if not is_instance_valid(art) or not is_instance_valid(caster):
		return true
	var c := StarSkillArt.look(skill)
	art.add("moon", c, Vector3(0, 3.0, -0.3), Vector3.ONE * 1.2, Vector3(PI / 2, 0, 0), time, {"initial": 0.2, "grow_time": 0.8, "fade_in": 0.2, "decay": 0.96, "opacity": 0.85})
	art.add("fang", c, Vector3.UP * 0.07, Vector3.ONE * 2.2, Vector3.ZERO, time, {"initial": 0.3, "grow_time": 0.6, "spin": -0.8, "decay": 0.96})
	var foe: Variant = caster.get("target")
	if not (foe is Node3D) or not is_instance_valid(foe):
		foe = caster.get("_victim")
	if foe is Node3D and is_instance_valid(foe):
		var spot := art.to_local((foe as Node3D).global_position) + Vector3.UP * 0.08
		art.add("reticle", c, spot, Vector3.ONE * 2.6, Vector3.ZERO, time, {"initial": 1.6, "grow_time": 0.9, "fade_in": 0.2, "spin": 1.2, "decay": 0.97, "opacity": 0.8})
	return true


## Nothing after the release: the AscendUlt owns the execution.
static func wave(_art: StarSkillArt, _parent: Node3D, _skill: Dictionary, _index: int, _point: Vector3, _source: Vector3) -> bool:
	return true


static func finale(_art: StarSkillArt, _parent: Node3D, _skill: Dictionary, _point: Vector3, _source: Vector3) -> bool:
	return true
