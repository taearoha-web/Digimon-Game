class_name ItemService
extends RefCounted
## Resolves item use effects. Shared by the field menu and battles.


## Returns an explanation when [param item] cannot be used on [param target], else "".
static func get_block_reason(item: ItemData, target: DigimonInstance, in_battle: bool) -> String:
	if item == null:
		return "Unknown item."
	if not item.is_usable(in_battle):
		return "Can't use that here."
	if target == null:
		return "" if item.use_effect == ItemData.UseEffect.BEFRIEND_BOOST else "No target."
	match item.use_effect:
		ItemData.UseEffect.HEAL_HP, ItemData.UseEffect.HEAL_HP_PERCENT:
			if target.is_fainted():
				return "%s has fainted." % target.get_display_name()
			if target.current_hp >= target.get_max_hp():
				return "%s's HP is already full." % target.get_display_name()
		ItemData.UseEffect.RESTORE_SP:
			if target.current_sp >= target.get_max_sp():
				return "%s's SP is already full." % target.get_display_name()
		ItemData.UseEffect.REVIVE:
			if not target.is_fainted():
				return "%s hasn't fainted." % target.get_display_name()
		ItemData.UseEffect.FULL_RESTORE:
			if target.is_fainted():
				return "%s has fainted." % target.get_display_name()
			if target.current_hp >= target.get_max_hp() and target.current_sp >= target.get_max_sp():
				return "%s is already in top shape." % target.get_display_name()
	return ""


## Uses one [param item_id] from [param inventory] on [param target].
## Returns { ok, message, hp_restored, sp_restored, befriend_bonus }
static func use_item(item_id: StringName, target: DigimonInstance, inventory: Inventory, in_battle := false) -> Dictionary:
	var registry: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameData")
	var item: ItemData = registry.get_item(item_id) if registry else null
	var result := {"ok": false, "message": "", "hp_restored": 0, "sp_restored": 0, "befriend_bonus": 0.0}
	if inventory == null or not inventory.has_item(item_id):
		result.message = "You don't have that item."
		return result
	var reason := get_block_reason(item, target, in_battle)
	if reason != "":
		result.message = reason
		return result
	var target_name := target.get_display_name() if target else ""
	match item.use_effect:
		ItemData.UseEffect.HEAL_HP:
			result.hp_restored = target.heal(item.effect_value)
			result.message = "%s recovered %d HP!" % [target_name, result.hp_restored]
		ItemData.UseEffect.HEAL_HP_PERCENT:
			result.hp_restored = target.heal(int(ceil(target.get_max_hp() * item.effect_value / 100.0)))
			result.message = "%s recovered %d HP!" % [target_name, result.hp_restored]
		ItemData.UseEffect.RESTORE_SP:
			result.sp_restored = target.restore_sp(item.effect_value)
			result.message = "%s recovered %d SP!" % [target_name, result.sp_restored]
		ItemData.UseEffect.REVIVE:
			target.revive(item.effect_value)
			result.hp_restored = target.current_hp
			result.message = "%s was revived!" % target_name
		ItemData.UseEffect.FULL_RESTORE:
			var before_hp := target.current_hp
			var before_sp := target.current_sp
			target.full_restore()
			result.hp_restored = target.current_hp - before_hp
			result.sp_restored = target.current_sp - before_sp
			result.message = "%s is fully restored!" % target_name
		ItemData.UseEffect.BEFRIEND_BOOST:
			result.befriend_bonus = item.effect_value / 100.0
			result.message = "The wild Digimon seems curious about the %s." % item.display_name
		_:
			result.message = "Nothing happened."
			return result
	if item.consumed_on_use:
		inventory.remove_item(item_id, 1)
	result.ok = true
	return result
