class_name EvolutionPath
extends Resource
## One data-driven evolution route from a species to [member target_species_id].
##
## All requirements are optional and combined with AND. The checks themselves
## live in [EvolutionService] so this resource stays plain data.

@export var target_species_id: StringName
@export var min_level: int = 1
## Item needed in the inventory (e.g. an evolution shard). Empty = none.
@export var required_item_id: StringName = &""
@export var consume_item: bool = true
@export var min_friendship: int = 0
## Quest that must be at least COMPLETED. Empty = none.
@export var required_quest_id: StringName = &""
## World/story flag that must be set. Empty = none.
@export var required_flag: StringName = &""
## stat id (StringName) -> minimum value.
@export var min_stats: Dictionary = {}
## Optional flavour text shown in UI.
@export var hint: String = ""
