class_name QuestObjective
extends Resource
## One step of a quest. Objectives are completed in order.

enum Type {
	TALK_TO_NPC,      ## target_id = npc id
	REACH_AREA,       ## target_id = area trigger id
	WIN_BATTLES,      ## target_id = species id, or empty for any
	RECRUIT_DIGIMON,  ## target_id = species id, or empty for any
	COLLECT_ITEM,     ## target_id = item id (counts items obtained while active)
	REACH_LEVEL,      ## required_count = level any party member must reach
}

@export var type: Type = Type.TALK_TO_NPC
@export var target_id: StringName = &""
@export var required_count: int = 1
@export var description: String = ""
## Dialogue played when a TALK_TO_NPC objective is completed.
@export var dialogue_id: StringName = &""
## World node id the HUD should point at while this objective is active.
@export var waypoint_id: StringName = &""
