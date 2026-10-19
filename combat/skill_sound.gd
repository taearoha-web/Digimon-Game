class_name SkillSound
extends RefCounted
## Which dedicated sound a skill plays: the Defender's shield arts by family, the
## star skills by their star flag. Everything else keeps the generic skill_start /
## hit sounds, and a missing file falls back the same way (AudioManager.has_sound),
## so sound choice never changes gameplay timing.

## Defender skill ids by sound family (tools/generate_skill_sfx.py renders the files).
const FAMILIES := {
	&"shield_bash": ["shield_bash", "shield_slam", "aegis_strike", "bastion_crush", "bulwark_charge", "shield_wave"],
	&"shield_quake": ["ground_quake", "quake_slam", "titan_quake", "shockwave_wall", "meteor_shield", "titan_shieldbreak", "heavens_bulwark"],
	&"shield_taunt": ["provoke", "grand_provoke"],
	&"shield_throw": ["shield_toss", "rebound_storm", "judgment_rebound"],
	&"shield_holy": ["holy_rampart", "judgment_shield", "world_bastion", "guardian_oath", "aegis_of_ages", "sanctuary_wall", "eternal_aegis"],
}
static var _family_of: Dictionary = {}


static func family(skill_id: String) -> StringName:
	if _family_of.is_empty():
		for fam in FAMILIES:
			for id in FAMILIES[fam]:
				_family_of[id] = fam
	return _family_of.get(skill_id, &"")


## The wind-up sound: a rising shimmer for star skills, the horn call for a taunt
## (the call is the skill), the generic skill_start for everything else.
static func cast(skill: Dictionary) -> StringName:
	if skill.has("star"):
		return _or(&"star_charge", &"skill_start")
	if family(String(skill.get("id", ""))) == &"shield_taunt":
		return _or(&"shield_taunt", &"skill_start")
	return &"skill_start"


## The sound when a shield art lands (clang, quake, ring, holy chime); empty for other skills.
static func landing(skill: Dictionary) -> StringName:
	var fam := family(String(skill.get("id", "")))
	if fam == &"" or fam == &"shield_taunt":
		return &""
	return _or(fam, &"")


## Star skill contacts: the big release on the first beat, a lighter hit on each later beat.
static func star_beat(index: int) -> StringName:
	return _or(&"star_release" if index == 0 else &"star_beat", &"")


static func _or(preferred: StringName, fallback: StringName) -> StringName:
	return preferred if AudioManager.has_sound(preferred) else fallback
