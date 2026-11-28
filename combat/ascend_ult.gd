class_name AscendUlt
extends RefCounted
## The Ascension's ultimates (★500) that play by mechanics of their own instead of their
## god skill's four waves and finale. Each lives in its own script (SCRIPTS), a Node:
##
##   static func lead(skill: Dictionary) -> float
##       (optional) how long after the release the hero's cast stays locked; default LEAD.
##   func begin_hero(hero: Hero, skill: Dictionary, aim: Vector3, target: Mob) -> void
##       the hero's cast, called at the release with the node already under hero.field.
##   func begin_rival(rival: Rival, skill: Dictionary, aim: Vector3, target: Node3D) -> void
##       (optional) an AI player's cast (guild war, duels); without it the AI plays the
##       skill by its shape like any other.
##
## The node owns its own clock, damage (Hero._deal / Rival._hit) and art, and frees
## itself when done; it must stop at once when its caster is gone (freed, dead, left).
## The cast's art up to the release is the skill's god_art script (GodSkillArt.telegraph).
const LEAD := 0.5
const SCRIPTS := {
	"emperor_heavensword": "res://combat/ascend_ult/emperor_heavensword.gd",
	"starfall_emperor_arrow": "res://combat/ascend_ult/starfall_emperor_arrow.gd",
	"dragon_emperor_lance": "res://combat/ascend_ult/dragon_emperor_lance.gd",
	"cosmos_genesis": "res://combat/ascend_ult/cosmos_genesis.gd",
	"eternal_dawn_judgment": "res://combat/ascend_ult/eternal_dawn_judgment.gd",
	"primordial_beast_court": "res://combat/ascend_ult/primordial_beast_court.gd",
	"eternal_bastion_fall": "res://combat/ascend_ult/eternal_bastion_fall.gd",
	"timeless_night_execution": "res://combat/ascend_ult/timeless_night_execution.gd",
	"heaven_hell_sovereign": "res://combat/ascend_ult/heaven_hell_sovereign.gd",
	"universe_hymn": "res://combat/ascend_ult/universe_hymn.gd",
}
static var _cache := {}


static func script_for(skill: Dictionary) -> Script:
	var id := String(skill.get("id", ""))
	if not SCRIPTS.has(id):
		return null
	if not _cache.has(id):
		var path: String = SCRIPTS[id]
		_cache[id] = load(path) if ResourceLoader.exists(path) else null
	return _cache[id]


## A ★500 ultimate with its own script.
static func handles(skill: Dictionary) -> bool:
	return AscendSkillData.is_ult(skill) and script_for(skill) != null


static func lead(skill: Dictionary) -> float:
	var script := script_for(skill)
	if script != null:
		for m in script.get_script_method_list():
			if String(m.name) == "lead":
				return float(script.call("lead", skill))
	return LEAD


## The hero's cast at its release (StarSkillSequence).
static func hero_cast(hero: Hero, skill: Dictionary, aim: Vector3, target: Mob) -> Node:
	var script := script_for(skill)
	if script == null or not is_instance_valid(hero) or not is_instance_valid(hero.field):
		return null
	var node: Node = script.new()
	node.name = "AscendUlt_" + String(skill.id)
	hero.field.add_child(node)
	node.call("begin_hero", hero, skill, aim, target)
	return node


## An AI player's cast; false when the script has none (the AI then plays it by shape).
static func rival_cast(rival: Node3D, skill: Dictionary, aim: Vector3, target: Node3D) -> bool:
	var script := script_for(skill)
	if script == null or not is_instance_valid(rival):
		return false
	var node: Node = script.new()
	if not node.has_method("begin_rival"):
		node.free()
		return false
	var field := rival.get_parent()
	if not is_instance_valid(field):
		node.free()
		return false
	node.name = "AscendUlt_" + String(skill.id)
	field.add_child(node)
	node.call("begin_rival", rival, skill, aim, target)
	return true
