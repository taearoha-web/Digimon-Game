class_name EncounterTable
extends Resource
## Configurable wild spawn data for one spawn region.

@export var id: StringName
@export var region_id: StringName
@export var entries: Array[SpawnEntry] = []
## Hard cap of simultaneously alive wild Digimon in this region.
@export var max_active: int = 3
## Probability that a spawn check actually spawns something.
@export_range(0.0, 1.0) var spawn_chance: float = 0.6
## Seconds between spawn checks.
@export var check_interval: float = 3.0
## Seconds before a defeated/removed slot can be refilled.
@export var respawn_delay: float = 10.0


func pick_entry(rng: RandomNumberGenerator) -> SpawnEntry:
	var total := 0.0
	for entry in entries:
		if entry:
			total += maxf(entry.weight, 0.0)
	if total <= 0.0:
		return null
	var roll := rng.randf() * total
	for entry in entries:
		if entry == null:
			continue
		roll -= maxf(entry.weight, 0.0)
		if roll <= 0.0:
			return entry
	return entries.back()
