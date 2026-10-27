class_name SkillSound
extends RefCounted
## Which dedicated sound a skill plays: the Defender's shield arts, the
## Assassin's dagger arts and the Bard's lute, songs and drums by family, the star skills by their star flag. Everything else keeps the generic skill_start /
## hit sounds, and a missing file falls back the same way (AudioManager.has_sound),
## so sound choice never changes gameplay timing.

## Defender, Assassin, Dark Lord and Bard skill ids by sound family (tools/generate_skill_sfx.py renders the files).
const FAMILIES := {
	&"shield_bash": ["shield_bash", "shield_slam", "aegis_strike", "bastion_crush", "bulwark_charge", "shield_wave"],
	&"shield_quake": ["ground_quake", "quake_slam", "titan_quake", "shockwave_wall", "meteor_shield", "titan_shieldbreak", "heavens_bulwark", "earthshake", "earth_dominion", "chaos_inferno"],
	&"shield_taunt": ["provoke", "grand_provoke"],
	&"shield_throw": ["shield_toss", "rebound_storm", "judgment_rebound"],
	&"shield_holy": ["holy_rampart", "judgment_shield", "world_bastion", "guardian_oath", "aegis_of_ages", "sanctuary_wall", "eternal_aegis", "critical_damage", "iron_defense", "commanders_aura", "lord_of_command", "emperors_command", "lords_dominion", "imperial_judgment"],
	&"blade_swish": ["twin_fang", "crimson_cut", "blade_flurry", "night_raid", "thousand_cuts", "shadow_dance", "eclipse_fang", "umbral_lacerate", "shadow_execution"],
	&"blade_throw": ["fan_of_knives", "phantom_daggers", "phantom_legion", "eclipse_requiem", "birds", "raven_storm", "raven_sovereign"],
	&"shadow_vanish": ["shadow_veil", "shadow_step", "smoke_bomb", "shadow_clone", "veil_of_night", "summon"],
	&"venom_hiss": ["venom_edge", "deadly_venom"],
	&"shadow_dark": ["killing_focus", "backstab", "throat_slit", "death_mark", "night_lord", "abyss_vortex", "midnight_execution", "shadow_sovereign", "oblivion_requiem", "force", "force_wave", "chaos_strike", "chaotic_diseier", "royal_crush", "dark_comet", "chaos_sovereign"],
	&"lute_strum": ["staccato_shot", "resonance", "sorrow_note", "triad_chord", "echo_chain", "heartstring", "cascade", "aria_of_ruin", "eternal_echo", "heartbreak_sonata"],
	&"song_rise": ["valor_march", "iron_ballad", "virtuoso", "heroic_anthem", "slumber_lullaby", "sanctuary_serenade", "maestro_fervor", "hymn_of_legends", "celestial_stage"],
	&"song_discord": ["discord", "lament", "shattering_rhapsody", "grand_dissonance"],
	&"drum_boom": ["war_drum", "fortissimo", "thunder_crescendo", "grand_finale", "starlight_overture", "cosmic_encore"],
}
static var _family_of: Dictionary = {}


static func family(skill_id: String) -> StringName:
	if _family_of.is_empty():
		for fam in FAMILIES:
			for id in FAMILIES[fam]:
				_family_of[id] = fam
	return _family_of.get(skill_id, &"")


## The wind-up sound: a rising shimmer for star skills, the horn call for a taunt
## (the call is the skill), a pluck of the lute as a Bard's song begins (it swells
## at the release), the generic skill_start for everything else.
static func cast(skill: Dictionary) -> StringName:
	if skill.has("star"):
		return _or(&"star_charge", &"skill_start")
	var fam := family(String(skill.get("id", "")))
	if fam == &"shield_taunt":
		return _or(&"shield_taunt", &"skill_start")
	if fam == &"song_rise":
		return _or(&"lute_strum", &"skill_start")
	return &"skill_start"


## The sound when a shield or dagger art lands (clang, quake, ring, chime, swish, smoke); empty for other skills.
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
