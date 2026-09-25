extends Node
## Global signal hub for cross-system events.
##
## Emitters do not know who listens (quests, HUD, audio, achievements…).
## Only events that genuinely cross system boundaries belong here.

## UI feedback: a short notification. kind: &"info", &"success", &"warning", &"quest", &"item"
signal toast_requested(text: String, kind: StringName)

## Gameplay events consumed by QuestManager and others.
signal npc_talked(npc_id: StringName)
signal area_entered(area_id: StringName, display_name: String)
signal battle_won(enemy_species_id: StringName, enemy_level: int)
signal digimon_recruited(instance: DigimonInstance)
signal item_obtained(item_id: StringName, amount: int)
signal digimon_evolved(instance: DigimonInstance, from_species_id: StringName)
signal digimon_leveled_up(instance: DigimonInstance, new_level: int)

## Quest notifications.
signal quest_started(quest_id: StringName)
signal quest_updated(quest_id: StringName)
signal quest_completed(quest_id: StringName)
signal quest_rewarded(quest_id: StringName, rewards: Dictionary)

## Game lifecycle.
signal new_game_started()
signal game_loaded(slot: int)
signal game_saved(slot: int, is_autosave: bool)
signal party_changed()
signal flag_changed(flag: StringName, value: Variant)

## Dialogue lifecycle (lets the world freeze input while talking).
signal dialogue_started(dialogue_id: StringName)
signal dialogue_finished(dialogue_id: StringName)


func toast(text: String, kind: StringName = &"info") -> void:
	toast_requested.emit(text, kind)
