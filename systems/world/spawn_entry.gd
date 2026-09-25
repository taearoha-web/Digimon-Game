class_name SpawnEntry
extends Resource
## One possible wild Digimon in an [EncounterTable].

@export var species_id: StringName
@export var min_level: int = 2
@export var max_level: int = 4
## Relative spawn weight (higher = more common).
@export var weight: float = 1.0
