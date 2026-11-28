extends RefCounted
## Summoner Ascension ultimate (★500): หลอมรวมอสูร. Its wind-up only (cosmetic): the summoner
## invokes on a turning court seal under the court's emblem, every summon it has out flares
## with its own colour as the call reaches it, and a fusion sigil opens over the aimed point
## where they will meet. From the release the rush, the chimera and its one blow are its own
## (combat/ascend_ult/primordial_beast_court.gd, AscendUlt): no waves, no dragons, no finale.
const ID := "primordial_beast_court"
const ULT := preload("res://combat/ascend_ult/primordial_beast_court.gd")


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	if not is_instance_valid(art) or not is_instance_valid(caster):
		return true
	var c := AscendSkillArt.look(skill)
	var r := AscendSkillArt._radius(skill)
	var parent := art.get_parent() as Node3D
	art.add("court", c, Vector3(0, 3.0, -0.2), Vector3.ONE * 1.2, Vector3.ZERO, time + 0.1, {"initial": 0.3, "grow_time": 0.5, "fade_in": 0.15, "decay": 0.96, "face_camera": true, "pulse": true, "opacity": 0.85})
	art.add("celestial", c, Vector3.UP * 0.07, Vector3.ONE * 2.6, Vector3.ZERO, time, {"initial": 0.3, "grow_time": 0.6, "spin": 0.8, "decay": 0.97})
	art._draw()
	# The call reaches every summon that will be fed.
	var list: Variant = caster.get("_summons")
	if list is Array and is_instance_valid(parent):
		for s in list:
			if s is Node3D and is_instance_valid(s) and not (s as Node).has_meta(ULT.KEEP_META):
				var kind: Variant = s.get("_kind")
				var colour: Color = (kind as Dictionary).get("color", ULT.JADE) if kind is Dictionary else ULT.JADE
				VfxArt.motes(parent, (s as Node3D).global_position + Vector3.UP * 1.2, colour, "star", 10, 0.9, 1.4, minf(time, 1.2))
				VfxKit.ground_circle(parent, (s as Node3D).global_position + Vector3.UP * 0.05, colour, 1.4, time)
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var gate := AscendSkillArt._root(parent, Vector3(point.x, 0, point.z), time + 0.3, "StarAscendGate_" + ID, caster.global_position, art)
	if gate:
		gate.add("god_halo", c, Vector3.UP * 0.09, Vector3.ONE * r * 0.9, Vector3.ZERO, time + 0.3, {"initial": 0.05, "grow_time": 0.85, "fade_in": 0.12, "spin": 0.6, "decay": 0.97, "opacity": 0.8, "veil": 0.5, "priority": -2})
		gate.add("wolf", c, Vector3.UP * ULT.MEET_HEIGHT, Vector3.ONE * 1.8, Vector3.ZERO, time + 0.3, {"initial": 0.2, "grow_time": 0.8, "fade_in": 0.2, "decay": 0.95, "face_camera": true, "pulse": true, "opacity": 0.8, "priority": -1})
		gate._draw()
	return true


static func wave(_art: StarSkillArt, _parent: Node3D, _skill: Dictionary, _index: int, _point: Vector3, _source: Vector3) -> bool:
	return true


static func finale(_art: StarSkillArt, _parent: Node3D, _skill: Dictionary, _point: Vector3, _source: Vector3) -> bool:
	return true
