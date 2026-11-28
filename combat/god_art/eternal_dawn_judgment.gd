extends RefCounted
## Priest Ascension ultimate (★500): เทวทูตคุ้มชีวิต. Its wind-up only (cosmetic): the priest
## prays under an aureole and seraph plumes on a turning seal, while over the aimed point the
## heavens part (a seal of light on the ground, a rising sun high above, feathers drifting
## down) where the guardian angel will land. From the release the angel, its burst and its
## ward are its own (combat/ascend_ult/eternal_dawn_judgment.gd, AscendUlt): no waves, no
## finale here.
const ID := "eternal_dawn_judgment"


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	if not is_instance_valid(art) or not is_instance_valid(caster):
		return true
	var c := AscendSkillArt.look(skill)
	var r := AscendSkillArt._radius(skill)
	art.add("aureole", c, Vector3(0, 2.3, -0.5), Vector3.ONE * 1.5, Vector3.ZERO, time + 0.1, {"initial": 0.2, "grow_time": 0.5, "fade_in": 0.1, "decay": 0.96, "face_camera": true, "pulse": true, "opacity": 0.8})
	art.add("seraph_plumes", c, Vector3(0, 1.7, -0.45), Vector3.ONE * 1.7, Vector3.ZERO, time + 0.1, {"initial": 0.3, "grow_time": 0.6, "fade_in": 0.15, "decay": 0.95, "face_camera": true, "opacity": 0.85})
	art.add("celestial", c, Vector3.UP * 0.07, Vector3.ONE * 2.4, Vector3.ZERO, time, {"initial": 0.3, "grow_time": 0.6, "spin": 0.5, "decay": 0.97})
	art._draw()
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var parent := art.get_parent() as Node3D
	var gate := AscendSkillArt._root(parent, Vector3(point.x, 0, point.z), time + 0.35, "StarAscendGate_" + ID, caster.global_position, art)
	if gate:
		var top := minf(AscendSkillArt.SKY, GodSkillArt.headroom(gate, gate.global_position) - 1.0)
		gate.add("god_halo", c, Vector3.UP * 0.09, Vector3.ONE * r * 0.95, Vector3.ZERO, time + 0.35, {"initial": 0.05, "grow_time": 0.85, "fade_in": 0.12, "spin": -0.4, "decay": 0.97, "opacity": 0.8, "veil": 0.5, "priority": -2})
		gate.add("sunrise", c, Vector3.UP * maxf(4.5, top), Vector3.ONE * 2.8, Vector3(GodSkillArt.TILT, 0, 0), time + 0.35, {"initial": 0.2, "grow_time": 0.7, "fade_in": 0.2, "decay": 0.97, "face_camera": true, "pulse": true, "opacity": 0.85, "priority": -1})
		gate.add("feathers", c, Vector3.UP * maxf(3.5, top - 1.0), Vector3(2.4, 3.0, 2.4), Vector3.ZERO, time + 0.35, {"initial": 0.6, "travel": Vector3.DOWN * 2.6, "fade_in": 0.1, "decay": 0.85, "veil": 0.5})
		gate._draw()
	return true


static func wave(_art: StarSkillArt, _parent: Node3D, _skill: Dictionary, _index: int, _point: Vector3, _source: Vector3) -> bool:
	return true


static func finale(_art: StarSkillArt, _parent: Node3D, _skill: Dictionary, _point: Vector3, _source: Vector3) -> bool:
	return true
