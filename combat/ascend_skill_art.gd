class_name AscendSkillArt
extends RefCounted
## The Ascension skills' presentation (AscendSkillData, ★500). Cosmetic ONLY: the
## StarSkillSequence owns every contact; this only dresses the beats it already plays.
##
## An ultimate (combat/god_art/<id>.gd calls ult_*) plays its class's god art (the god
## skill named by its "art", GodSkillArt.signature) and opens the Ascension's heavens over
## it: a gate of three counter-turning god seals over the target in the ultimate's own
## palette (AscendSkillData.COLORS), the class's emblem high in the sky, a crown and an
## aureole over the caster; every wave flares a seal where it lands, and the finale raises
## a pantheon of light with a sunburst and a shock of feathers. A buff (combat/star_art/
## <id>.gd calls buff_*) plays its class's support star art when it has one, under a crown
## of the Ascension. Every extra root goes through GodSkillArt.extra_roots (none at low
## quality or under memory pressure) and StarSkillArt's own 2/4/6 layer cap, and is named
## after the skill so GodSkillArt.bind_roots ties it to its cast.

const SKY := 9.0
## The emblem each class raises over its Ascension (StarGeometry kinds).
const EMBLEM := {
	&"warrior": "lion", &"archer": "constellation", &"lancer": "drill", &"mage": "planets", &"priest": "seraph_plumes",
	&"summoner": "court", &"defender": "titan_shield", &"assassin": "moon", &"darklord": "crown", &"bard": "lyre", &"muaythai": "sunrise",
}
## The support star art each buff plays under its crown ("" none: its own layers only).
const BUFF_BASE := {
	&"warrior": "royal_vanguard", &"archer": "sylph_step", &"lancer": "aegis_formation", &"mage": "", &"priest": "seraph_aegis",
	&"summoner": "spirit_court", &"defender": "eternal_aegis", &"assassin": "veil_of_night", &"darklord": "lords_dominion",
	&"bard": "celestial_stage", &"muaythai": "",
}


static func look(skill: Dictionary) -> Dictionary:
	var colors: Array = AscendSkillData.COLORS.get(String(skill.get("id", "")), ["fff0b0", "ffffff", "6a4a2a"])
	return {"primary": Color(colors[0]), "accent": Color(colors[1]), "shade": Color(colors[2])}


static func _cls(skill: Dictionary) -> StringName:
	return StringName(String(skill.get("class", "warrior")))


static func _radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 10.0)), 4.0, 11.0)


static func _base_ult(skill: Dictionary) -> GDScript:
	var id := String(skill.get("art", ""))
	return GodSkillArt.signature(id) if id != "" else null


static func _root(parent: Node3D, at: Vector3, seconds: float, label: String, source: Vector3, owner: StarSkillArt) -> StarSkillArt:
	if not is_instance_valid(parent):
		return null
	return GodSkillArt._extra(parent, at, seconds, label, source, owner)


# ---------------------------------------------------------------------------
# Ultimates (★500): the god art of the class under the Ascension's heavens.
# ---------------------------------------------------------------------------

static func ult_telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var base := _base_ult(skill)
	if base != null and base.has_method("telegraph"):
		base.telegraph(art, caster, skill, point, time)
	if not is_instance_valid(art) or not is_instance_valid(caster):
		return true
	var id := String(skill.id)
	var c := look(skill)
	var r := _radius(skill)
	var parent := art.get_parent() as Node3D
	var origin := caster.global_position
	var grow := {"initial": 0.05, "grow_time": 0.85, "fade_in": 0.12, "decay": 0.97, "opacity": 0.82, "veil": 0.5, "priority": -2}
	var extras := GodSkillArt.extra_roots(2)
	if extras < 1:
		return true
	# The gate of the heavens over the target: three seals turning against each other.
	var gate := _root(parent, Vector3(point.x, 0, point.z), time + 0.2, "StarAscendGate_" + id, origin, art)
	if gate:
		gate.add("god_halo", c, Vector3.UP * 0.09, Vector3.ONE * r * 1.15, Vector3.ZERO, time + 0.2, grow.merged({"spin": -0.45}, true))
		gate.add("celestial", c, Vector3.UP * 0.12, Vector3.ONE * r * 0.7, Vector3.ZERO, time + 0.2, grow.merged({"spin": 0.7}, true))
		var top := minf(SKY, GodSkillArt.headroom(gate, gate.global_position) - 1.0)
		gate.add(String(EMBLEM.get(_cls(skill), "god_halo")), c, Vector3.UP * maxf(4.0, top), Vector3.ONE * 2.6, Vector3(GodSkillArt.TILT, 0, 0), time + 0.2, {"initial": 0.2, "grow_time": 0.7, "fade_in": 0.2, "decay": 0.97, "face_camera": true, "pulse": true, "opacity": 0.85, "priority": -1})
		gate.add("god_halo", c, Vector3.UP * maxf(4.5, top + 0.4), Vector3.ONE * r * 0.5, Vector3.ZERO, time + 0.2, {"initial": 0.2, "grow_time": 0.8, "fade_in": 0.15, "spin": 0.9, "decay": 0.97, "opacity": 0.7, "veil": 0.55, "priority": -1})
		gate._draw()
	if extras < 2:
		return true
	# The crown of the Ascension over the caster, an aureole behind its shoulders.
	var crown := _root(parent, origin, time + 0.1, "StarAscendCrown_" + id, point, art)
	if crown:
		crown.add("crown", c, Vector3.UP * 3.1, Vector3.ONE * 0.8, Vector3.ZERO, time + 0.1, {"initial": 0.3, "grow_time": 0.5, "fade_in": 0.15, "spin": 1.1, "decay": 0.96, "front": true, "travel": Vector3.DOWN * 0.4})
		crown.add("aureole", c, Vector3(0, 2.2, -0.5), Vector3.ONE * 1.6, Vector3.ZERO, time + 0.1, {"initial": 0.2, "grow_time": 0.5, "fade_in": 0.1, "decay": 0.97, "face_camera": true, "pulse": true, "opacity": 0.75})
		crown._draw()
	return true


static func ult_wave(art: StarSkillArt, parent: Node3D, skill: Dictionary, index: int, point: Vector3, source: Vector3) -> bool:
	var base := _base_ult(skill)
	if base != null and base.has_method("wave"):
		base.wave(art, parent, skill, index, point, source)
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var c := look(skill)
	var r := _radius(skill)
	var spot := Vector3(point.x, 0, point.z) + GodSkillArt._spot(index, r)
	var flare := _root(parent, spot, 0.9, "StarAscendWave_%s_%d" % [String(skill.id), index], source, art)
	if flare:
		flare.add("god_halo", c, Vector3.UP * 0.1, Vector3.ONE * (2.2 + 0.5 * index), Vector3.ZERO, 0.75, {"initial": 0.15, "grow_time": 0.3, "fade_in": 0.02, "spin": 1.6, "decay": 0.45, "veil": 0.4})
		flare.add("shards", c, Vector3.UP * 0.2, Vector3(1.6, 2.8, 1.6), Vector3.ZERO, 0.8, {"initial": 0.5, "travel": Vector3.UP * 0.9, "decay": 0.5, "veil": 0.5, "priority": 0})
		flare._draw()
	return true


static func ult_finale(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, source: Vector3) -> bool:
	var base := _base_ult(skill)
	if base != null and base.has_method("finale"):
		base.finale(art, parent, skill, point, source)
	var extras := GodSkillArt.extra_roots(2)
	if extras < 1:
		return true
	var id := String(skill.id)
	var c := look(skill)
	var r := _radius(skill)
	var at := Vector3(point.x, 0, point.z)
	# The pantheon of light rises round the finale; a sunburst opens over it.
	var hall := _root(parent, at, 2.2, "StarAscendPantheon_" + id, source, art)
	if hall:
		hall.add("pantheon", c, Vector3.ZERO, Vector3(r * 0.85, 3.4, r * 0.85), Vector3.ZERO, 2.0, {"initial": 0.2, "grow_time": 0.35, "fade_in": 0.05, "spin": 0.25, "decay": 0.75, "opacity": 0.7, "veil": 0.6, "priority": -2})
		hall.add("god_halo", c, Vector3.UP * 0.1, Vector3.ONE * r * 1.3, Vector3.ZERO, 1.2, {"initial": 0.1, "grow_time": 0.45, "fade_in": 0.02, "spin": -1.2, "decay": 0.4})
		hall.add("sunrise", c, Vector3.UP * 0.15, Vector3.ONE * r * 0.9, Vector3.ZERO, 1.6, {"initial": 0.2, "grow_time": 0.5, "fade_in": 0.03, "spin": 0.5, "decay": 0.55, "veil": 0.5})
		hall._draw()
	if extras < 2:
		return true
	var sky := _root(parent, at, 2.0, "StarAscendSky_" + id, source, art)
	if sky:
		sky.add("feathers", c, Vector3.UP * 0.4, Vector3(r * 0.8, 4.0, r * 0.8), Vector3.ZERO, 1.8, {"initial": 0.6, "travel": Vector3.UP * 1.4, "decay": 0.7, "veil": 0.45})
		sky.add(String(EMBLEM.get(_cls(skill), "god_halo")), c, Vector3.UP * 5.5, Vector3.ONE * 3.2, Vector3(GodSkillArt.TILT, 0, 0), 1.6, {"initial": 0.4, "grow_time": 0.2, "fade_in": 0.02, "decay": 0.6, "face_camera": true, "front": true})
		sky._draw()
	return true


# ---------------------------------------------------------------------------
# Buffs (★500): the class's support star art under the Ascension's crown.
# ---------------------------------------------------------------------------

static func _base_buff(skill: Dictionary) -> GDScript:
	var id := String(BUFF_BASE.get(_cls(skill), ""))
	return StarSignature.script_for(id) if id != "" else null


static func buff_telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var base := _base_buff(skill)
	if base != null and base.has_method("telegraph"):
		base.telegraph(art, caster, skill, point, time)
	var c := look(skill)
	if is_instance_valid(art):
		# Its own wind-up when the class has no support art: a seal and the rising emblem.
		if base == null:
			art.add("god_halo", c, Vector3.UP * 0.07, Vector3.ONE * 3.6, Vector3.ZERO, time + 0.1, {"initial": 0.1, "grow_time": 0.7, "fade_in": 0.1, "spin": 0.8, "decay": 0.95})
			art.add(String(EMBLEM.get(_cls(skill), "aureole")), c, Vector3.UP * 2.6, Vector3.ONE * 1.3, Vector3.ZERO, time + 0.1, {"initial": 0.2, "grow_time": 0.6, "fade_in": 0.2, "decay": 0.95, "face_camera": true, "travel": Vector3.UP * 0.6})
	if GodSkillArt.extra_roots(1) < 1 or not is_instance_valid(art) or not is_instance_valid(caster):
		return true
	var crown := _root(art.get_parent() as Node3D, caster.global_position, time + 0.2, "StarAscendCrown_" + String(skill.id), point, art)
	if crown:
		crown.add("crown", c, Vector3.UP * 3.4, Vector3.ONE * 0.7, Vector3.ZERO, time + 0.2, {"initial": 0.3, "grow_time": 0.5, "fade_in": 0.2, "spin": 1.3, "decay": 0.96, "travel": Vector3.DOWN * 0.5, "front": true})
		crown.add("celestial", c, Vector3.UP * 0.08, Vector3.ONE * 4.2, Vector3.ZERO, time + 0.2, {"initial": 0.2, "grow_time": 0.6, "fade_in": 0.1, "spin": -0.6, "decay": 0.95, "veil": 0.55, "priority": -2})
		crown._draw()
	return true


static func buff_strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var base := _base_buff(skill)
	if base != null and base.has_method("strike"):
		base.strike(art, parent, skill, point, index, source)
	var c := look(skill)
	if is_instance_valid(art) and base == null:
		art.add("aureole", c, Vector3(0, 2.2, -0.4), Vector3.ONE * 1.8, Vector3.ZERO, 1.8, {"initial": 0.3, "grow_time": 0.2, "fade_in": 0.02, "decay": 0.7, "face_camera": true, "pulse": true})
		art.add("god_halo", c, Vector3.UP * 0.1, Vector3.ONE * 6.0, Vector3.ZERO, 0.9, {"initial": 0.1, "grow_time": 0.6, "fade_in": 0.02, "spin": 1.4, "decay": 0.4})
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var hall := _root(parent, point, 1.8, "StarAscendBlessing_" + String(skill.id), source, art)
	if hall:
		hall.add("pantheon", c, Vector3.ZERO, Vector3(3.6, 2.6, 3.6), Vector3.ZERO, 1.6, {"initial": 0.2, "grow_time": 0.3, "fade_in": 0.04, "spin": 0.4, "decay": 0.7, "opacity": 0.7, "veil": 0.6, "priority": -2})
		hall.add("feathers", c, Vector3.UP * 0.3, Vector3(3.0, 3.4, 3.0), Vector3.ZERO, 1.6, {"initial": 0.6, "travel": Vector3.UP * 1.1, "decay": 0.7, "veil": 0.45})
		hall._draw()
	return true
