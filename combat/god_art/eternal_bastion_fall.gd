extends RefCounted
## Defender Ascension ultimate (★500): กำแพงโล่ถล่ม. Its wind-up only: the seal of the
## heavens under the defender and the ghosts of the wall's shields rising in a row in front
## of it, facing the way it will drive. From the release on the wall itself is the cast's
## (combat/ascend_ult/eternal_bastion_fall.gd, an AscendUlt): no waves, no finale here.
const ID := "eternal_bastion_fall"


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, _point: Vector3, time: float) -> bool:
	if not is_instance_valid(art) or not is_instance_valid(caster):
		return true
	var c := StarSkillArt.look(skill)
	var yaw := _yaw(caster)
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var side := Vector3(cos(yaw), 0, -sin(yaw))
	var turn := yaw - art.global_rotation.y
	var at := caster.global_position
	var grow := {"initial": 0.2, "grow_time": 0.7, "fade_in": 0.15, "decay": 0.97, "opacity": 0.7, "veil": 0.55}
	art.add("celestial", c, Vector3.UP * 0.07, Vector3.ONE * 2.6, Vector3.ZERO, time, {"initial": 0.3, "grow_time": 0.6, "spin": 0.6, "decay": 0.97})
	# The wall to come: its middle shield first, then its wings (as the layer cap allows).
	for k: float in [0.0, -1.0, 1.0]:
		var spot: Vector3 = at + fwd * 1.4 + side * k * 2.2
		art.add("titan_shield", c, art.to_local(spot) + Vector3.UP * 0.2, Vector3.ONE * (1.5 if k == 0.0 else 1.2), Vector3(0, turn, 0), time,
			grow.merged({"travel": Vector3.UP * 0.9, "delay": absf(k) * 0.18, "front": true}, true))
	return true


## Nothing after the release: the AscendUlt owns the wall.
static func wave(_art: StarSkillArt, _parent: Node3D, _skill: Dictionary, _index: int, _point: Vector3, _source: Vector3) -> bool:
	return true


static func finale(_art: StarSkillArt, _parent: Node3D, _skill: Dictionary, _point: Vector3, _source: Vector3) -> bool:
	return true


static func _yaw(caster: Node3D) -> float:
	if caster.has_method("facing"):
		return float(caster.call("facing"))
	var y: Variant = caster.get("_yaw")
	return float(y) if y is float else caster.global_rotation.y
