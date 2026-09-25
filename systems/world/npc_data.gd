class_name NpcData
extends Resource
## Data for an NPC. Quest logic is resolved by QuestManager using the quests
## that reference this NPC as giver or turn-in target.

@export var id: StringName
@export var display_name: String = ""
## Short title shown under the name, e.g. "Tamer Guide".
@export var title: String = ""
@export var default_dialogue_id: StringName = &""
@export var interaction_radius: float = 2.6
## Serialized [CharacterAppearance] for the chibi avatar.
@export var appearance: Dictionary = {}
## Optional service offered after dialogue (&"heal_party" or empty).
@export var service: StringName = &""
