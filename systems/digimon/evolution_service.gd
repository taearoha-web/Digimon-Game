class_name EvolutionService
extends RefCounted
## Checks and applies data-driven evolutions.
##
## Requirement checks receive an explicit context so they are testable:
## { "inventory": Inventory, "quest_log": QuestLog, "flags": Dictionary }


static func describe_requirements(path: EvolutionPath) -> PackedStringArray:
	var parts := PackedStringArray()
	if path.min_level > 1:
		parts.append(L10n.t("Reach Lv %d") % path.min_level)
	if path.required_item_id != &"":
		parts.append(L10n.t("Have %s") % _item_name(path.required_item_id))
	if path.min_friendship > 0:
		parts.append(L10n.t("Friendship %d+") % path.min_friendship)
	if path.required_quest_id != &"":
		parts.append(L10n.t("Complete \"%s\"") % _quest_title(path.required_quest_id))
	if path.required_flag != &"":
		parts.append(L10n.t("Story progress: %s") % String(path.required_flag).capitalize())
	for stat in path.min_stats.keys():
		parts.append(L10n.t("%s %d+") % [DigimonStats.display_name(StringName(stat)), int(path.min_stats[stat])])
	return parts


## Returns human-readable descriptions of unmet requirements (empty = ready).
static func get_unmet_requirements(inst: DigimonInstance, path: EvolutionPath, ctx: Dictionary) -> PackedStringArray:
	var unmet := PackedStringArray()
	if inst == null or path == null:
		unmet.append(L10n.t("Invalid evolution"))
		return unmet
	if inst.level < path.min_level:
		unmet.append(L10n.t("Reach Lv %d") % path.min_level)
	if path.required_item_id != &"":
		var inventory: Inventory = ctx.get("inventory")
		if inventory == null or not inventory.has_item(path.required_item_id):
			unmet.append(L10n.t("Have %s") % _item_name(path.required_item_id))
	if inst.friendship < path.min_friendship:
		unmet.append(L10n.t("Friendship %d+") % path.min_friendship)
	if path.required_quest_id != &"":
		var quest_log: QuestLog = ctx.get("quest_log")
		if quest_log == null or quest_log.get_state(path.required_quest_id) < QuestLog.State.COMPLETED:
			unmet.append(L10n.t("Complete \"%s\"") % _quest_title(path.required_quest_id))
	if path.required_flag != &"":
		var flags: Dictionary = ctx.get("flags", {})
		if not flags.get(path.required_flag, false):
			unmet.append(L10n.t("Story progress: %s") % String(path.required_flag).capitalize())
	for stat in path.min_stats.keys():
		if inst.get_stat(StringName(stat)) < int(path.min_stats[stat]):
			unmet.append(L10n.t("%s %d+") % [DigimonStats.display_name(StringName(stat)), int(path.min_stats[stat])])
	return unmet


## Status of every evolution path of [param inst]'s species.
## Each entry: { path, target: DigimonSpecies, unmet: PackedStringArray, ready: bool }
static func get_paths_status(inst: DigimonInstance, ctx: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var species := inst.get_species() if inst else null
	if species == null:
		return result
	for path in species.evolutions:
		if path == null:
			continue
		var target := _species(path.target_species_id)
		if target == null:
			continue
		var unmet := get_unmet_requirements(inst, path, ctx)
		result.append({"path": path, "target": target, "unmet": unmet, "ready": unmet.is_empty()})
	return result


static func get_ready_paths(inst: DigimonInstance, ctx: Dictionary) -> Array[EvolutionPath]:
	var ready: Array[EvolutionPath] = []
	for status in get_paths_status(inst, ctx):
		if status.ready:
			ready.append(status.path)
	return ready


static func can_evolve(inst: DigimonInstance, ctx: Dictionary) -> bool:
	return not get_ready_paths(inst, ctx).is_empty()


## Evolves [param inst] along [param path]. Level, EXP, friendship, skills and
## HP ratio are preserved. Returns a summary for the Evolution UI:
## { ok, from_species, to_species, before, after, learned }
static func evolve(inst: DigimonInstance, path: EvolutionPath, ctx: Dictionary) -> Dictionary:
	var unmet := get_unmet_requirements(inst, path, ctx)
	if not unmet.is_empty():
		return {"ok": false, "reason": ", ".join(unmet)}
	var target := _species(path.target_species_id)
	if target == null:
		return {"ok": false, "reason": L10n.t("Unknown species")}
	var from_species := inst.species_id
	var hp_ratio := inst.get_hp_ratio()
	var sp_ratio := float(inst.current_sp) / float(maxi(1, inst.get_max_sp()))
	var before := inst.get_all_stats()

	if path.required_item_id != &"" and path.consume_item:
		var inventory: Inventory = ctx.get("inventory")
		if inventory:
			inventory.remove_item(path.required_item_id, 1)

	inst.evolution_history.append(from_species)
	inst.species_id = target.id
	var learned: Array[StringName] = []
	for skill_id in target.get_skills_up_to(inst.level):
		if inst.learn_skill(skill_id):
			learned.append(skill_id)
	inst.current_hp = maxi(1, int(round(inst.get_max_hp() * hp_ratio))) if not inst.is_fainted() else 0
	inst.current_sp = int(round(inst.get_max_sp() * sp_ratio))
	inst.clamp_vitals()
	inst.add_friendship(10)
	return {
		"ok": true,
		"from_species": from_species,
		"to_species": target.id,
		"before": before,
		"after": inst.get_all_stats(),
		"learned": learned,
	}


static func _registry() -> Node:
	var loop := Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("GameData") if loop is SceneTree else null


static func _species(species_id: StringName) -> DigimonSpecies:
	var reg := _registry()
	return reg.get_species(species_id) if reg else null


static func _item_name(item_id: StringName) -> String:
	var reg := _registry()
	var item: ItemData = reg.get_item(item_id) if reg else null
	return item.display_name if item else String(item_id)


static func _quest_title(quest_id: StringName) -> String:
	var reg := _registry()
	var quest: QuestData = reg.get_quest(quest_id) if reg else null
	return quest.title if quest else String(quest_id)
