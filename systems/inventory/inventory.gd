class_name Inventory
extends RefCounted
## Item stacks owned by the player. Item definitions come from GameData.

signal changed()
signal item_added(item_id: StringName, amount: int)
signal item_removed(item_id: StringName, amount: int)

var _items: Dictionary = {} # StringName -> int


## Adds up to [param amount] items respecting the max stack.
## Returns how many were actually added.
func add_item(item_id: StringName, amount: int = 1) -> int:
	if amount <= 0 or item_id == &"":
		return 0
	var item := _get_item(item_id)
	if item == null:
		push_warning("Inventory: unknown item '%s'" % item_id)
		return 0
	var current := count(item_id)
	var added := mini(amount, maxi(0, item.max_stack - current))
	if added <= 0:
		return 0
	_items[item_id] = current + added
	item_added.emit(item_id, added)
	changed.emit()
	return added


func remove_item(item_id: StringName, amount: int = 1) -> bool:
	if amount <= 0 or count(item_id) < amount:
		return false
	var remaining := count(item_id) - amount
	if remaining <= 0:
		_items.erase(item_id)
	else:
		_items[item_id] = remaining
	item_removed.emit(item_id, amount)
	changed.emit()
	return true


func count(item_id: StringName) -> int:
	return int(_items.get(item_id, 0))


func has_item(item_id: StringName, amount: int = 1) -> bool:
	return count(item_id) >= amount


func is_empty() -> bool:
	return _items.is_empty()


func clear() -> void:
	_items.clear()
	changed.emit()


## Entries of { "item": ItemData, "quantity": int } for one category,
## sorted by display name. Pass -1 for every category.
func get_entries(category: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id in _items.keys():
		var item := _get_item(item_id)
		if item == null:
			continue
		if category >= 0 and item.category != category:
			continue
		result.append({"item": item, "quantity": int(_items[item_id])})
	result.sort_custom(func(a, b): return a.item.display_name < b.item.display_name)
	return result


func get_usable_entries(in_battle: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in get_entries():
		if entry.item.is_usable(in_battle):
			result.append(entry)
	return result


func to_dict() -> Dictionary:
	var out := {}
	for key in _items.keys():
		out[String(key)] = int(_items[key])
	return out


func load_dict(data: Dictionary) -> void:
	_items.clear()
	for key in data.keys():
		var qty := int(data[key])
		if qty > 0:
			_items[StringName(str(key))] = qty
	changed.emit()


func _get_item(item_id: StringName) -> ItemData:
	var loop := Engine.get_main_loop()
	var reg: Node = (loop as SceneTree).root.get_node_or_null("GameData") if loop is SceneTree else null
	return reg.get_item(item_id) if reg else null
