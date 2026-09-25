class_name QuestData
extends Resource
## Data-driven quest definition. Runtime progress is stored in [QuestLog].

@export var id: StringName
@export var title: String = ""
@export_multiline var summary: String = ""
## NPC that offers the quest. Empty + auto_start = starts on its own.
@export var giver_npc_id: StringName = &""
## NPC to return to once every objective is done. Empty = auto reward.
@export var turn_in_npc_id: StringName = &""
@export var auto_start: bool = false
@export var sort_order: int = 0

@export_group("Requirements")
@export var prerequisite_quest_ids: Array[StringName] = []
@export var required_flag: StringName = &""

@export_group("Objectives")
@export var objectives: Array[QuestObjective] = []

@export_group("Dialogue")
@export var offer_dialogue_id: StringName = &""
@export var in_progress_dialogue_id: StringName = &""
@export var turn_in_dialogue_id: StringName = &""
@export var after_dialogue_id: StringName = &""

@export_group("Rewards")
## EXP granted to every party Digimon.
@export var reward_exp: int = 0
@export var reward_currency: int = 0
## item id (StringName) -> quantity
@export var reward_items: Dictionary = {}
## Flags set in WorldState when rewarded (e.g. &"gateway_unlocked").
@export var reward_flags: Array[StringName] = []
