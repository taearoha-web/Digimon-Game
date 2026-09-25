class_name DigimonRoster
extends RefCounted
## Every Digimon the player owns: the active party (max 3) plus storage.

signal party_changed()
signal roster_changed()

const MAX_PARTY := 3

## uid -> DigimonInstance
var _owned: Dictionary = {}
## Keeps collection order stable (order obtained).
var _order: Array[String] = []
## uids of party members, slot 0 = lead / partner.
var party: Array[String] = []
var capacity: int = 60


func size() -> int:
	return _order.size()


func is_full() -> bool:
	return size() >= capacity


## Adds a Digimon. Returns &"party", &"storage" or &"full".
func add_digimon(inst: DigimonInstance) -> StringName:
	if inst == null:
		return &"full"
	if is_full():
		return &"full"
	_owned[inst.uid] = inst
	_order.append(inst.uid)
	var placed := &"storage"
	if party.size() < MAX_PARTY:
		party.append(inst.uid)
		placed = &"party"
		party_changed.emit()
	roster_changed.emit()
	return placed


func get_digimon(uid: String) -> DigimonInstance:
	return _owned.get(uid)


func has_digimon(uid: String) -> bool:
	return _owned.has(uid)


func get_all() -> Array[DigimonInstance]:
	var result: Array[DigimonInstance] = []
	for uid in _order:
		result.append(_owned[uid])
	return result


func get_party() -> Array[DigimonInstance]:
	var result: Array[DigimonInstance] = []
	for uid in party:
		if _owned.has(uid):
			result.append(_owned[uid])
	return result


func get_storage() -> Array[DigimonInstance]:
	var result: Array[DigimonInstance] = []
	for uid in _order:
		if not party.has(uid):
			result.append(_owned[uid])
	return result


func get_lead() -> DigimonInstance:
	return _owned.get(party[0]) if not party.is_empty() else null


func is_in_party(uid: String) -> bool:
	return party.has(uid)


func get_party_index(uid: String) -> int:
	return party.find(uid)


func move_party_member(from_index: int, to_index: int) -> bool:
	if from_index < 0 or from_index >= party.size() or to_index < 0 or to_index >= party.size():
		return false
	if from_index == to_index:
		return false
	var uid: String = party[from_index]
	party.remove_at(from_index)
	party.insert(to_index, uid)
	party_changed.emit()
	return true


func set_lead(uid: String) -> bool:
	var index := party.find(uid)
	if index <= 0:
		return false
	return move_party_member(index, 0)


func add_to_party(uid: String) -> bool:
	if not _owned.has(uid) or party.has(uid) or party.size() >= MAX_PARTY:
		return false
	party.append(uid)
	party_changed.emit()
	return true


## Moves a party member to storage (the party must keep at least one member).
func remove_from_party(uid: String) -> bool:
	if not party.has(uid) or party.size() <= 1:
		return false
	party.erase(uid)
	party_changed.emit()
	return true


## Swaps a stored Digimon into the party slot of [param party_uid].
func swap_with_storage(party_uid: String, storage_uid: String) -> bool:
	var index := party.find(party_uid)
	if index < 0 or not _owned.has(storage_uid) or party.has(storage_uid):
		return false
	party[index] = storage_uid
	party_changed.emit()
	return true


func heal_all() -> void:
	for inst in get_all():
		inst.full_restore()
	party_changed.emit()


func first_healthy_party_index() -> int:
	var members := get_party()
	for i in members.size():
		if not members[i].is_fainted():
			return i
	return -1


func is_party_defeated() -> bool:
	return first_healthy_party_index() == -1


func count_species(species_id: StringName) -> int:
	var total := 0
	for inst in get_all():
		if inst.species_id == species_id:
			total += 1
	return total


func notify_changed() -> void:
	party_changed.emit()
	roster_changed.emit()


func clear() -> void:
	_owned.clear()
	_order.clear()
	party.clear()


func to_dict() -> Dictionary:
	var owned: Array = []
	for uid in _order:
		owned.append(_owned[uid].to_dict())
	return {"owned": owned, "party": party.duplicate(), "capacity": capacity}


func load_dict(data: Dictionary) -> void:
	clear()
	capacity = int(data.get("capacity", capacity))
	var owned = data.get("owned", [])
	if owned is Array:
		for entry in owned:
			if entry is Dictionary:
				var inst := DigimonInstance.from_dict(entry)
				if inst.get_species() == null:
					push_warning("Roster: skipping Digimon with unknown species '%s'" % inst.species_id)
					continue
				if _owned.has(inst.uid):
					inst.uid = DigimonInstance.generate_uid()
				_owned[inst.uid] = inst
				_order.append(inst.uid)
	var saved_party = data.get("party", [])
	if saved_party is Array:
		for uid in saved_party:
			var key := str(uid)
			if _owned.has(key) and not party.has(key) and party.size() < MAX_PARTY:
				party.append(key)
	# Never allow an empty party when Digimon are owned.
	if party.is_empty() and not _order.is_empty():
		party.append(_order[0])
	notify_changed()
