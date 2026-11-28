extends RefCounted
## Dark Lord Ascension ultimate (★500): สัญญาโลหิต, a blood pact (AscendUlt plays it:
## combat/ascend_ult/heaven_hell_sovereign.gd owns the price, the three blood blasts, the
## blood moon and the drink). This is its wind-up only, cosmetic: the pact being sealed.
## A crimson heart beats over the dark lord, a blood seal turns at its feet inside a rune
## ring, embers of blood rise round it and a thin red ring marks the reach of the blast
## (the skill's radius round the caster, where it will break out). No thrones, no lightning:
## the release and everything after are the script's.
const ID := "heaven_hell_sovereign"
const BLOOD := Color("e0203a")
const DARK := Color("7a0a1c")


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, _point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D if is_instance_valid(art) else null
	if parent == null or not is_instance_valid(caster):
		return true
	var c := StarSkillArt.look(skill)
	var origin := caster.global_position * Vector3(1, 0, 1)
	var radius := clampf(float(skill.get("radius", 10.0)), 4.0, 12.0)
	# The pact: a heart beating over the caster, its seal at the feet.
	art.add("heart", c, Vector3(0, 2.75, 0.25), Vector3.ONE * 0.9, Vector3.ZERO, time + 0.1,
		{"initial": 0.15, "grow_time": 0.8, "fade_in": 0.12, "decay": 0.97, "face_camera": true, "pulse": true, "opacity": 0.92})
	art.add("god_halo", c, Vector3.UP * 0.07, Vector3.ONE * 2.8, Vector3.ZERO, time + 0.1,
		{"initial": 0.3, "grow_time": 0.7, "fade_in": 0.1, "spin": -0.9, "decay": 0.97, "opacity": 0.85})
	VfxArt.rune_circle(parent, origin, DARK, 3.0, time, -1.0)
	VfxArt.motes(parent, origin, BLOOD, "flame", 14, 1.3, 0.2, maxf(time, 0.8))
	# Where the blood will break out: the blast's reach round the caster.
	VfxKit.ground_circle(parent, origin, BLOOD, radius, time)
	return true


## The waves and the finale are the script's (AscendUlt): nothing shared draws them.
static func wave(_art: StarSkillArt, _parent: Node3D, _skill: Dictionary, _index: int, _point: Vector3, _source: Vector3) -> bool:
	return true


static func finale(_art: StarSkillArt, _parent: Node3D, _skill: Dictionary, _point: Vector3, _source: Vector3) -> bool:
	return true
