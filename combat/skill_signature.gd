class_name SkillSignature
extends RefCounted
## Signature art of the regular class skills (Lv.10-100, not the star skills): one script
## per skill id, res://combat/skill_art/<skill id>.gd, the same idea as combat/star_art
## (StarSignature) and combat/god_art (GodSkillArt). Cosmetic ONLY: the hero / companion
## code owns every hit, target, buff and timing; a signature only dresses the beats
## SkillShow already plays.
##
## A signature script exposes static functions, each returning true when it drew its beat:
##   anticipate(parent, skill, origin, duration, aim, visual)   the wind-up
##   play(parent, skill, center, origin, impact_delay)          the release / impact
## (impact_delay: seconds until the landing for meteor / rain skills, else 0; a script
## schedules its own later beats on its own roots.)
## When a skill has one, it owns the whole show (owns, via GodSkillArt.owns): the shared
## class systems (ClassFlourish, ClassSignature, CasterArt, MeleeArt, EliteSkillArt,
## ShadowSkillArt, LordSkillArt, BardSkillArt, SkillTableau and the SkillLayers stack)
## stay out, exactly as they do for a star or god skill with its own art.
## Skills that run their own sequence (armageddon, thunder_storm, judgment_ray) keep it;
## a signature for them dresses SkillShow's beats only.
const DIR := "res://combat/skill_art/%s.gd"
static var _scripts := {}


## The signature script of [param id] (null when it has none). Looked up once.
static func script_for(id) -> GDScript:
	var key := String(id)
	if key == "" or key.begins_with("_"):
		return null
	if not _scripts.has(key):
		var path := DIR % key
		_scripts[key] = load(path) if ResourceLoader.exists(path) else null
	return _scripts[key]


## A regular (non-star) class skill whose signature art draws its show.
static func owns(skill: Dictionary) -> bool:
	if skill.is_empty() or skill.has("star") or StarSkillData.is_god(skill):
		return false
	return script_for(skill.get("id", "")) != null


## The wind-up; true when the signature drew it.
static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim := Vector3.ZERO, visual: HeroVisual = null) -> bool:
	var own := script_for(skill.get("id", ""))
	if own == null or not is_instance_valid(parent) or not own.has_method("anticipate"):
		return false
	return bool(own.anticipate(parent, skill, origin, duration, aim, visual))


## The release / impact; true when the signature drew it.
static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, impact_delay := 0.0) -> bool:
	var own := script_for(skill.get("id", ""))
	if own == null or not is_instance_valid(parent) or not own.has_method("play"):
		return false
	return bool(own.play(parent, skill, center, origin, impact_delay))
