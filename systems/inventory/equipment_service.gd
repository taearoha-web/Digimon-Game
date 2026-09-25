class_name EquipmentService
extends RefCounted
## Equips / removes Digi-Chips (EQUIPMENT items). One chip per Digimon; the
## chip leaves the inventory while held and returns when removed.


static func equip(inst: DigimonInstance, item_id: StringName, inventory: Inventory) -> Dictionary:
	var item := _item(item_id)
	if inst == null or item == null or not item.is_equipment():
		return {"ok": false, "message": L10n.t("That can't be equipped.")}
	if not inventory.has_item(item_id):
		return {"ok": false, "message": L10n.t("You don't have %s.") % item.display_name}
	if inst.held_item_id == item_id:
		return {"ok": false, "message": L10n.t("%s already holds %s.") % [inst.get_display_name(), item.display_name]}
	var hp_ratio := inst.get_hp_ratio()
	# Take the new chip out first so a full stack of the old one can go back.
	inventory.remove_item(item_id, 1)
	if inst.held_item_id != &"":
		var removed := unequip(inst, inventory)
		if not removed.ok:
			inventory.add_item(item_id, 1)
			return removed
	inst.held_item_id = item_id
	_keep_ratio(inst, hp_ratio)
	return {"ok": true, "message": L10n.t("%s equipped %s (%s).") % [inst.get_display_name(), item.display_name, item.describe_bonuses()]}


static func unequip(inst: DigimonInstance, inventory: Inventory) -> Dictionary:
	if inst == null or inst.held_item_id == &"":
		return {"ok": false, "message": L10n.t("Nothing equipped.")}
	var hp_ratio := inst.get_hp_ratio()
	var item_id := inst.held_item_id
	if inventory.add_item(item_id, 1) <= 0:
		return {"ok": false, "message": L10n.t("Your bag is full.")}
	inst.held_item_id = &""
	_keep_ratio(inst, hp_ratio)
	return {"ok": true, "message": L10n.t("Chip returned to your bag.")}


## Every Digimon in [param roster] currently holding [param item_id].
static func holders_of(item_id: StringName, roster: DigimonRoster) -> Array[DigimonInstance]:
	var out: Array[DigimonInstance] = []
	for inst in roster.get_all():
		if inst.held_item_id == item_id:
			out.append(inst)
	return out


static func _keep_ratio(inst: DigimonInstance, hp_ratio: float) -> void:
	if not inst.is_fainted():
		inst.current_hp = maxi(1, int(round(inst.get_max_hp() * hp_ratio)))
	inst.clamp_vitals()


static func _item(item_id: StringName) -> ItemData:
	var loop := Engine.get_main_loop()
	var registry: Node = (loop as SceneTree).root.get_node_or_null("GameData") if loop is SceneTree else null
	return registry.get_item(item_id) if registry else null
