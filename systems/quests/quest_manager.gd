extends Node
## Autoload "QuestManager": quest rules.
##
## Quest definitions come from GameData (QuestData resources); progress is
## stored in GameState.quest_log. Gameplay code never edits quest progress
## directly — it emits EventBus events that this manager interprets.

signal tracked_quest_changed()

const State := QuestLog.State


func _ready() -> void:
	EventBus.npc_talked.connect(_on_npc_talked)
	EventBus.area_entered.connect(_on_area_entered)
	EventBus.battle_won.connect(_on_battle_won)
	EventBus.digimon_recruited.connect(_on_digimon_recruited)
	EventBus.item_obtained.connect(_on_item_obtained)
	EventBus.digimon_leveled_up.connect(_on_digimon_leveled_up)
	EventBus.flag_changed.connect(_on_flag_changed)


func quest_log() -> QuestLog:
	return GameState.quest_log


func get_state(quest_id: StringName) -> int:
	return quest_log().get_state(quest_id)


## Unlocks quests whose prerequisites are met (and auto-starts some).
func refresh_availability() -> void:
	for quest in GameData.get_all_quests():
		if get_state(quest.id) == State.LOCKED and _prerequisites_met(quest):
			quest_log().set_state(quest.id, State.AVAILABLE)
			if quest.auto_start:
				start_quest(quest.id)
	tracked_quest_changed.emit()


func start_quest(quest_id: StringName) -> bool:
	var quest := GameData.get_quest(quest_id)
	if quest == null or get_state(quest_id) != State.AVAILABLE:
		return false
	quest_log().set_state(quest_id, State.ACTIVE)
	quest_log().set_step(quest_id, 0, 0)
	EventBus.quest_started.emit(quest_id)
	EventBus.toast("New Quest: %s" % quest.title, &"quest")
	AudioManager.play_ui(&"quest_start")
	_check_passive_objectives(quest)
	tracked_quest_changed.emit()
	return true


func get_current_objective(quest_id: StringName) -> QuestObjective:
	var quest := GameData.get_quest(quest_id)
	if quest == null or get_state(quest_id) != State.ACTIVE:
		return null
	var step := quest_log().get_step(quest_id)
	return quest.objectives[step] if step < quest.objectives.size() else null


## Generic progress entry point used by every event handler.
func notify_progress(objective_type: int, target_id: StringName, amount := 1) -> void:
	for quest in GameData.get_all_quests():
		if get_state(quest.id) != State.ACTIVE:
			continue
		var objective := get_current_objective(quest.id)
		if objective == null or objective.type != objective_type:
			continue
		if objective.target_id != &"" and objective.target_id != target_id:
			continue
		var progress := quest_log().get_progress(quest.id) + amount
		if progress >= objective.required_count:
			_advance(quest)
		else:
			quest_log().set_progress(quest.id, progress)
			EventBus.quest_updated.emit(quest.id)
			tracked_quest_changed.emit()


## Grants the rewards of a COMPLETED quest. Returns a summary for the UI:
## { quest_id, exp, currency, items: {id: qty}, level_ups: [{instance, ups}] }
func grant_rewards(quest_id: StringName) -> Dictionary:
	var quest := GameData.get_quest(quest_id)
	if quest == null or get_state(quest_id) != State.COMPLETED:
		return {}
	var summary := {
		"quest_id": quest_id,
		"title": quest.title,
		"exp": quest.reward_exp,
		"currency": quest.reward_currency,
		"items": quest.reward_items.duplicate(),
		"level_ups": [],
	}
	if quest.reward_exp > 0:
		for inst in GameState.roster.get_party():
			var ups := Leveling.grant_exp(inst, quest.reward_exp)
			if not ups.is_empty():
				summary.level_ups.append({"instance": inst, "ups": ups})
				EventBus.digimon_leveled_up.emit(inst, inst.level)
	if quest.reward_currency > 0:
		GameState.profile.add_currency(quest.reward_currency)
	for item_id in quest.reward_items.keys():
		GameState.inventory.add_item(StringName(item_id), int(quest.reward_items[item_id]))
	for flag in quest.reward_flags:
		GameState.set_flag(flag, true)
	quest_log().set_state(quest_id, State.REWARDED)
	EventBus.quest_rewarded.emit(quest_id, summary)
	AudioManager.play_ui(&"quest_complete")
	refresh_availability()
	SaveManager.autosave("quest rewarded: %s" % quest_id, true)
	tracked_quest_changed.emit()
	return summary


## Decides what an NPC says. Returns { action, quest_id, dialogue_id }.
## action: &"turn_in", &"talk_objective", &"offer", &"in_progress", &"after", &"default"
func resolve_npc_interaction(npc_id: StringName) -> Dictionary:
	var npc := GameData.get_npc(npc_id)
	var default_dialogue := npc.default_dialogue_id if npc else &""
	var quests := GameData.get_all_quests()
	for quest in quests:
		if get_state(quest.id) == State.COMPLETED and quest.turn_in_npc_id == npc_id:
			return _npc_result(&"turn_in", quest.id, quest.turn_in_dialogue_id)
	for quest in quests:
		var objective := get_current_objective(quest.id)
		if objective and objective.type == QuestObjective.Type.TALK_TO_NPC and objective.target_id == npc_id:
			return _npc_result(&"talk_objective", quest.id, objective.dialogue_id)
	for quest in quests:
		if get_state(quest.id) == State.AVAILABLE and quest.giver_npc_id == npc_id and not quest.auto_start:
			return _npc_result(&"offer", quest.id, quest.offer_dialogue_id)
	for quest in quests:
		var state := get_state(quest.id)
		if (state == State.ACTIVE or state == State.COMPLETED) and quest.giver_npc_id == npc_id:
			return _npc_result(&"in_progress", quest.id, quest.in_progress_dialogue_id)
	var after_quest: QuestData = null
	for quest in quests:
		if get_state(quest.id) == State.REWARDED and quest.giver_npc_id == npc_id and quest.after_dialogue_id != &"":
			after_quest = quest
	if after_quest:
		return _npc_result(&"after", after_quest.id, after_quest.after_dialogue_id)
	return _npc_result(&"default", &"", default_dialogue)


## Applies the consequence of an NPC conversation after its dialogue ended.
## Returns a reward summary for &"turn_in", otherwise {}.
func apply_npc_action(result: Dictionary, npc_id: StringName) -> Dictionary:
	var rewards := {}
	match result.get("action", &"default"):
		&"offer":
			start_quest(result.quest_id)
		&"turn_in":
			rewards = grant_rewards(result.quest_id)
	EventBus.npc_talked.emit(npc_id)
	return rewards


## &"turn_in", &"available" or &"" — used for the marker above NPC heads.
func get_npc_marker(npc_id: StringName) -> StringName:
	var marker := &""
	for quest in GameData.get_all_quests():
		var state := get_state(quest.id)
		if state == State.COMPLETED and quest.turn_in_npc_id == npc_id:
			return &"turn_in"
		var objective := get_current_objective(quest.id)
		if objective and objective.type == QuestObjective.Type.TALK_TO_NPC and objective.target_id == npc_id:
			return &"turn_in"
		if state == State.AVAILABLE and quest.giver_npc_id == npc_id and not quest.auto_start:
			marker = &"available"
	return marker


## The quest shown in the HUD tracker.
func get_tracked_quest() -> QuestData:
	var available: QuestData = null
	for quest in GameData.get_all_quests():
		var state := get_state(quest.id)
		if state == State.ACTIVE or state == State.COMPLETED:
			return quest
		if state == State.AVAILABLE and available == null:
			available = quest
	return available


func get_objective_text(quest_id: StringName) -> String:
	var quest := GameData.get_quest(quest_id)
	if quest == null:
		return ""
	match get_state(quest_id):
		State.AVAILABLE:
			return "Talk to %s" % _npc_name(quest.giver_npc_id) if quest.giver_npc_id != &"" else quest.summary
		State.ACTIVE:
			var objective := get_current_objective(quest_id)
			if objective == null:
				return ""
			var text := TextVars.format(objective.description, {}, false)
			if objective.required_count > 1 and objective.type != QuestObjective.Type.REACH_LEVEL:
				text += " (%d/%d)" % [quest_log().get_progress(quest_id), objective.required_count]
			return text
		State.COMPLETED:
			return "Return to %s" % _npc_name(quest.turn_in_npc_id)
		State.REWARDED:
			return "Completed"
	return ""


## World node id the HUD compass should point at, or &"".
func get_objective_waypoint(quest_id: StringName) -> StringName:
	var quest := GameData.get_quest(quest_id)
	if quest == null:
		return &""
	match get_state(quest_id):
		State.AVAILABLE:
			return quest.giver_npc_id
		State.ACTIVE:
			var objective := get_current_objective(quest_id)
			if objective:
				if objective.waypoint_id != &"":
					return objective.waypoint_id
				if objective.type == QuestObjective.Type.TALK_TO_NPC:
					return objective.target_id
		State.COMPLETED:
			return quest.turn_in_npc_id
	return &""


func count_completed() -> int:
	return quest_log().count_in_state(State.COMPLETED)


func _advance(quest: QuestData) -> void:
	var step := quest_log().get_step(quest.id) + 1
	if step >= quest.objectives.size():
		_complete(quest)
		return
	quest_log().set_step(quest.id, step, 0)
	EventBus.quest_updated.emit(quest.id)
	EventBus.toast("Objective: %s" % TextVars.format(quest.objectives[step].description, {}, false), &"quest")
	AudioManager.play_ui(&"quest_update")
	_check_passive_objectives(quest)
	tracked_quest_changed.emit()


func _complete(quest: QuestData) -> void:
	quest_log().set_step(quest.id, quest.objectives.size(), 0)
	quest_log().set_state(quest.id, State.COMPLETED)
	EventBus.quest_completed.emit(quest.id)
	tracked_quest_changed.emit()
	if quest.turn_in_npc_id == &"":
		grant_rewards(quest.id)
	else:
		EventBus.toast("Quest ready! Return to %s." % _npc_name(quest.turn_in_npc_id), &"quest")
		AudioManager.play_ui(&"quest_update")


## Objectives that may already be satisfied when they become current.
func _check_passive_objectives(quest: QuestData) -> void:
	var objective := get_current_objective(quest.id)
	if objective == null:
		return
	if objective.type == QuestObjective.Type.REACH_LEVEL:
		for inst in GameState.roster.get_party():
			if inst.level >= objective.required_count:
				_advance(quest)
				return


func _prerequisites_met(quest: QuestData) -> bool:
	for prereq in quest.prerequisite_quest_ids:
		if get_state(prereq) < State.REWARDED:
			return false
	if quest.required_flag != &"" and not GameState.get_flag(quest.required_flag, false):
		return false
	return true


func _npc_result(action: StringName, quest_id: StringName, dialogue_id: StringName) -> Dictionary:
	return {"action": action, "quest_id": quest_id, "dialogue_id": dialogue_id}


func _npc_name(npc_id: StringName) -> String:
	var npc := GameData.get_npc(npc_id)
	return npc.display_name if npc else String(npc_id).capitalize()


func _on_npc_talked(npc_id: StringName) -> void:
	notify_progress(QuestObjective.Type.TALK_TO_NPC, npc_id)


func _on_area_entered(area_id: StringName, _display_name: String) -> void:
	notify_progress(QuestObjective.Type.REACH_AREA, area_id)


func _on_battle_won(enemy_species_id: StringName, _enemy_level: int) -> void:
	notify_progress(QuestObjective.Type.WIN_BATTLES, enemy_species_id)


func _on_digimon_recruited(instance: DigimonInstance) -> void:
	notify_progress(QuestObjective.Type.RECRUIT_DIGIMON, instance.species_id)


func _on_item_obtained(item_id: StringName, amount: int) -> void:
	notify_progress(QuestObjective.Type.COLLECT_ITEM, item_id, amount)


func _on_digimon_leveled_up(_instance: DigimonInstance, _level: int) -> void:
	for quest in GameData.get_all_quests():
		if get_state(quest.id) == State.ACTIVE:
			_check_passive_objectives(quest)


func _on_flag_changed(_flag: StringName, _value: Variant) -> void:
	if GameState.is_game_active:
		refresh_availability()
