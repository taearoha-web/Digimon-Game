class_name BattleController
extends RefCounted
## Turn-based battle rules, completely independent of scenes and UI.
##
## Every call returns an ordered Array of event dictionaries (see EVENT TYPES
## below) that the presentation layer (BattleScene) plays back with
## animations. This keeps the rules unit-testable and the UI replaceable.
##
## EVENT TYPES: message, skill, miss, damage, heal, sp, stat, status,
## status_clear, defend, item, switch, faint, escape, befriend, need_switch,
## victory, defeat, invalid, party_update. Every event may carry "text".

enum Phase { NOT_STARTED, AWAITING_COMMAND, AWAITING_SWITCH, FINISHED }
enum Outcome { NONE, VICTORY, DEFEAT, ESCAPED, RECRUITED }

## Non-skill actions resolve before skills.
const ACTION_PRIORITY := 10
const DEFEND_SP_PERCENT := 15
const PLAYER := BattleCombatant.PLAYER_SIDE
const ENEMY := BattleCombatant.ENEMY_SIDE

var phase: int = Phase.NOT_STARTED
var outcome: int = Outcome.NONE
var request: BattleRequest
var party: Array[DigimonInstance] = []
var player: BattleCombatant
var enemy: BattleCombatant
var inventory: Inventory
var rng: RandomNumberGenerator
var chart: TypeChart
var recruit_config: RecruitmentConfig
var completed_quests := 0
var turn := 0
var escape_attempts := 0
var participant_uids: Array[String] = []
var recruited_instance: DigimonInstance = null

var _announced_faints: Dictionary = {}
var _player_wins_ties := true
var _struggle_skill: SkillData


func setup(p_party: Array[DigimonInstance], enemy_instance: DigimonInstance, p_request: BattleRequest,
		p_inventory: Inventory, p_rng: RandomNumberGenerator = null) -> void:
	party = p_party
	request = p_request if p_request else BattleRequest.new()
	inventory = p_inventory
	rng = p_rng
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var registry := _registry()
	chart = registry.type_chart if registry else TypeChart.new()
	recruit_config = registry.recruitment_config if registry else RecruitmentConfig.new()
	enemy = BattleCombatant.new(enemy_instance, ENEMY)
	var lead_index := 0
	for i in party.size():
		if not party[i].is_fainted():
			lead_index = i
			break
	player = BattleCombatant.new(party[lead_index], PLAYER)
	_mark_participant(player)
	_struggle_skill = SkillData.new()
	_struggle_skill.id = &"struggle"
	_struggle_skill.display_name = "Desperate Tackle"
	_struggle_skill.power = 20
	_struggle_skill.accuracy = 100
	var dmg := SkillEffect.new()
	dmg.type = SkillEffect.Type.DAMAGE
	_struggle_skill.effects = [dmg]


func start() -> Array[Dictionary]:
	phase = Phase.AWAITING_COMMAND
	var events: Array[Dictionary] = []
	if request.is_wild:
		events.append(_msg("A wild %s appeared!" % enemy.get_name()))
	else:
		events.append(_msg("%s wants to battle!" % enemy.get_name()))
	events.append(_msg("Go, %s!" % player.get_name()))
	return events


func is_finished() -> bool:
	return phase == Phase.FINISHED


## Skill buttons for the UI: [{ skill, usable, reason }]
func get_skill_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for skill in player.get_equipped_skills():
		var usable := player.can_afford(skill)
		options.append({"skill": skill, "usable": usable, "reason": "" if usable else "Not enough SP"})
	return options


## Returns "" when [param command] is legal right now, otherwise the reason.
func validate_command(command: Dictionary) -> String:
	if phase != Phase.AWAITING_COMMAND:
		return "Not your turn."
	match str(command.get("type", "")):
		"skill":
			var skill := _get_skill(StringName(command.get("skill_id", "")))
			if skill == null or not player.instance.equipped_skills.has(skill.id):
				return "Unknown skill."
			if not player.can_afford(skill):
				return "Not enough SP!"
		"struggle":
			if not player.get_usable_skills().is_empty():
				return "You still have usable skills."
		"defend":
			pass
		"item":
			var item_id := StringName(command.get("item_id", ""))
			if inventory == null or not inventory.has_item(item_id):
				return "You don't have that item."
			var item: ItemData = _registry().get_item(item_id)
			if item == null or not item.is_usable(true):
				return "That item can't be used in battle."
			if item.use_effect == ItemData.UseEffect.BEFRIEND_BOOST:
				if not request.is_wild:
					return "That only works on wild Digimon."
			else:
				var target := _find_party_member(str(command.get("target_uid", player.instance.uid)))
				var reason := ItemService.get_block_reason(item, target, true)
				if reason != "":
					return reason
		"switch":
			var index := int(command.get("index", -1))
			if index < 0 or index >= party.size():
				return "Invalid party slot."
			if party[index] == player.instance:
				return "%s is already fighting!" % player.get_name()
			if party[index].is_fainted():
				return "%s has no energy left to fight!" % party[index].get_display_name()
		"escape":
			if not request.can_escape:
				return "There's no escaping this battle!"
		"befriend":
			if not request.is_wild or not request.can_befriend:
				return "This Digimon won't listen right now."
		_:
			return "Unknown command."
	return ""


## Executes one full turn (player command + enemy AI) and returns its events.
func submit(command: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var error := validate_command(command)
	if error != "":
		events.append(_msg(error))
		events.append({"type": "invalid"})
		return events
	turn += 1
	player.is_defending = false
	enemy.is_defending = false
	_player_wins_ties = rng.randf() < 0.5
	var actions: Array[Dictionary] = [
		{"actor": player, "cmd": command},
		{"actor": enemy, "cmd": BattleAI.choose_command(enemy, player, rng, chart)},
	]
	actions.sort_custom(_action_goes_first)
	for action in actions:
		if phase != Phase.AWAITING_COMMAND:
			break
		var actor: BattleCombatant = action.actor
		if actor.is_fainted():
			continue
		events.append_array(_execute(actor, action.cmd))
		events.append_array(_check_faints())
	if phase != Phase.FINISHED:
		events.append_array(_end_of_turn())
	return events


## Forced switch after the active Digimon fainted (no enemy action).
func submit_switch(index: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if phase != Phase.AWAITING_SWITCH:
		return events
	if index < 0 or index >= party.size() or party[index].is_fainted():
		events.append(_msg("Choose a Digimon that can still fight."))
		events.append({"type": "invalid"})
		return events
	events.append_array(_switch_to(index, true))
	phase = Phase.AWAITING_COMMAND
	return events


func get_active_party_index() -> int:
	return party.find(player.instance)


func _execute(actor: BattleCombatant, command: Dictionary) -> Array[Dictionary]:
	match str(command.get("type", "")):
		"skill":
			return _use_skill(actor, _get_skill(StringName(command.get("skill_id", ""))))
		"struggle":
			return _use_skill(actor, _struggle_skill)
		"defend":
			return _defend(actor)
		"item":
			return _use_item(StringName(command.get("item_id", "")), str(command.get("target_uid", "")))
		"switch":
			return _switch_to(int(command.get("index", 0)), false)
		"escape":
			return _try_escape()
		"befriend":
			return _try_befriend()
	return []


func _use_skill(user: BattleCombatant, skill: SkillData) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if skill == null:
		return events
	var target := user if skill.target == SkillData.Target.SELF else _opponent_of(user)

	var skip_chance := float(StatusEffects.get_def(user.status_id).get("skip_chance", 0.0))
	if skip_chance > 0.0 and rng.randf() < skip_chance:
		events.append(_msg(StatusEffects.text(user.status_id, "skip_text", user.get_battle_name())))
		return events

	user.instance.current_sp = maxi(0, user.instance.current_sp - skill.sp_cost)
	events.append({
		"type": "skill", "side": user.side, "skill_id": skill.id, "target_side": target.side,
		"text": "%s used %s!" % [user.get_battle_name(), skill.display_name],
	})
	if skill.sp_cost > 0:
		events.append(_sp_event(user))

	if skill.target == SkillData.Target.ENEMY and not DamageCalculator.roll_hit(user, skill, rng):
		events.append({"type": "miss", "side": target.side, "text": "%s's attack missed!" % user.get_battle_name()})
		return events

	var last_damage := 0
	for effect in skill.effects:
		if effect == null:
			continue
		var effect_target := user if effect.target == SkillEffect.EffectTarget.USER else target
		if effect.type != SkillEffect.Type.DAMAGE and effect.chance < 1.0 and rng.randf() >= effect.chance:
			continue
		match effect.type:
			SkillEffect.Type.DAMAGE:
				if target.is_fainted():
					continue
				var result := DamageCalculator.calculate(user, target, skill, rng, chart)
				last_damage = target.instance.take_damage(result.amount)
				events.append({
					"type": "damage", "side": target.side, "amount": last_damage,
					"critical": result.critical, "type_multiplier": result.type_multiplier,
					"hp": target.instance.current_hp, "max_hp": target.instance.get_max_hp(),
					"element": skill.element, "skill_id": skill.id, "category": skill.category,
				})
				if result.critical:
					events.append(_msg("A critical hit!"))
				var eff_text := DamageCalculator.effectiveness_text(result.type_multiplier)
				if eff_text != "":
					events.append(_msg(eff_text))
			SkillEffect.Type.HEAL:
				if effect_target.is_fainted():
					continue
				var healed := effect_target.instance.heal(int(ceil(effect_target.instance.get_max_hp() * effect.amount / 100.0)))
				events.append(_heal_event(effect_target, healed))
				events.append(_msg("%s recovered %d HP!" % [effect_target.get_battle_name(), healed] if healed > 0 else "%s's HP is already full." % effect_target.get_battle_name()))
			SkillEffect.Type.BUFF, SkillEffect.Type.DEBUFF:
				if effect_target.is_fainted():
					continue
				var delta := effect.amount if effect.type == SkillEffect.Type.BUFF else -effect.amount
				var applied := effect_target.modify_stage(effect.stat, delta)
				events.append({"type": "stat", "side": effect_target.side, "stat": effect.stat, "delta": applied})
				events.append(_msg(_stat_text(effect_target, effect.stat, delta, applied)))
			SkillEffect.Type.STATUS:
				if effect_target.is_fainted():
					continue
				if effect_target.apply_status(effect.status_id, effect.duration):
					events.append({"type": "status", "side": effect_target.side, "status_id": effect.status_id})
					events.append(_msg(StatusEffects.text(effect.status_id, "apply_text", effect_target.get_battle_name())))
			SkillEffect.Type.RESTORE_SP:
				effect_target.instance.restore_sp(effect.amount)
				events.append(_sp_event(effect_target))
			SkillEffect.Type.DRAIN:
				if last_damage > 0 and not user.is_fainted():
					var drained := user.instance.heal(int(ceil(last_damage * effect.amount / 100.0)))
					if drained > 0:
						events.append(_heal_event(user, drained))
						events.append(_msg("%s drained %d HP!" % [user.get_battle_name(), drained]))
	return events


func _defend(actor: BattleCombatant) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	actor.is_defending = true
	actor.instance.restore_sp(int(ceil(actor.instance.get_max_sp() * DEFEND_SP_PERCENT / 100.0)))
	events.append({"type": "defend", "side": actor.side, "text": "%s is defending!" % actor.get_battle_name()})
	events.append(_sp_event(actor))
	return events


func _use_item(item_id: StringName, target_uid: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var item: ItemData = _registry().get_item(item_id)
	events.append({"type": "item", "side": PLAYER, "item_id": item_id, "text": "You used %s!" % item.display_name})
	if item.use_effect == ItemData.UseEffect.BEFRIEND_BOOST:
		var boost := ItemService.use_item(item_id, null, inventory, true)
		enemy.befriend_bonus += float(boost.befriend_bonus)
		events.append(_msg(boost.message))
		return events
	var target := _find_party_member(target_uid)
	var result := ItemService.use_item(item_id, target, inventory, true)
	events.append(_msg(result.message))
	if target == player.instance:
		if int(result.hp_restored) > 0:
			events.append(_heal_event(player, int(result.hp_restored)))
		if int(result.sp_restored) > 0:
			events.append(_sp_event(player))
	else:
		events.append({"type": "party_update"})
	return events


func _switch_to(index: int, forced: bool) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var inst := party[index]
	if not forced:
		events.append(_msg("%s, come back!" % player.get_name()))
	player.reset_battle_state()
	player.clear_status()
	player = BattleCombatant.new(inst, PLAYER)
	_mark_participant(player)
	events.append({"type": "switch", "side": PLAYER, "uid": inst.uid, "text": "Go, %s!" % inst.get_display_name()})
	return events


func _try_escape() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	escape_attempts += 1
	var player_speed := player.get_effective_stat(DigimonStats.SPEED)
	var enemy_speed := enemy.get_effective_stat(DigimonStats.SPEED)
	var chance := clampf(0.55 + (player_speed - enemy_speed) / maxf(enemy_speed, 1.0) * 0.5 + 0.12 * (escape_attempts - 1), 0.25, 0.98)
	if rng.randf() < chance:
		outcome = Outcome.ESCAPED
		phase = Phase.FINISHED
		events.append({"type": "escape", "success": true, "text": "Got away safely!"})
	else:
		events.append({"type": "escape", "success": false, "text": "Couldn't get away!"})
	return events


func _try_befriend() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var chance := RecruitmentService.befriend_chance(enemy, player, recruit_config, completed_quests)
	var success := RecruitmentService.roll(chance, rng)
	events.append({
		"type": "befriend", "success": success, "chance": chance,
		"text": "You reach out to %s…" % enemy.get_name(),
	})
	if success:
		recruited_instance = RecruitmentService.create_recruit(enemy.instance.species_id, enemy.get_level(), rng)
		outcome = Outcome.RECRUITED
		phase = Phase.FINISHED
		events.append(_msg("%s wants to join your team!" % enemy.get_name()))
	else:
		var lines := ["%s is wary of you…", "%s turned away!", "%s doesn't trust you yet."]
		events.append(_msg(lines[rng.randi_range(0, lines.size() - 1)] % enemy.get_name()))
		enemy.befriend_bonus += 0.03 # Persistence pays off a little.
	return events


func _check_faints() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if enemy.is_fainted() and not _announced_faints.has(enemy):
		_announced_faints[enemy] = true
		events.append({"type": "faint", "side": ENEMY, "text": "%s fainted!" % enemy.get_battle_name()})
		outcome = Outcome.VICTORY
		phase = Phase.FINISHED
		events.append({"type": "victory"})
		return events
	if player.is_fainted() and not _announced_faints.has(player):
		_announced_faints[player] = true
		events.append({"type": "faint", "side": PLAYER, "text": "%s fainted!" % player.get_name()})
		if _has_healthy_reserve():
			phase = Phase.AWAITING_SWITCH
			events.append({"type": "need_switch", "text": "Choose your next Digimon!"})
		else:
			outcome = Outcome.DEFEAT
			phase = Phase.FINISHED
			events.append(_msg("Your party can't fight any more…"))
			events.append({"type": "defeat"})
	return events


func _end_of_turn() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for combatant in [player, enemy]:
		var c: BattleCombatant = combatant
		if c.is_fainted() or c.status_id == &"":
			continue
		var def := StatusEffects.get_def(c.status_id)
		var percent := int(def.get("damage_percent", 0))
		if percent > 0:
			var dealt := c.instance.take_damage(maxi(1, int(c.instance.get_max_hp() * percent / 100.0)))
			events.append({
				"type": "damage", "side": c.side, "amount": dealt, "critical": false,
				"type_multiplier": 1.0, "hp": c.instance.current_hp, "max_hp": c.instance.get_max_hp(),
				"element": &"neutral", "skill_id": &"", "status_tick": true,
			})
			events.append(_msg(StatusEffects.text(c.status_id, "tick_text", c.get_battle_name())))
		c.status_turns -= 1
		if c.status_turns <= 0 and not c.is_fainted():
			events.append(_msg(StatusEffects.text(c.status_id, "end_text", c.get_battle_name())))
			c.clear_status()
			events.append({"type": "status_clear", "side": c.side})
	events.append_array(_check_faints())
	return events


func _action_goes_first(a: Dictionary, b: Dictionary) -> bool:
	var pa := _priority_of(a.cmd)
	var pb := _priority_of(b.cmd)
	if pa != pb:
		return pa > pb
	var sa: float = a.actor.get_effective_stat(DigimonStats.SPEED)
	var sb: float = b.actor.get_effective_stat(DigimonStats.SPEED)
	if not is_equal_approx(sa, sb):
		return sa > sb
	return (a.actor.side == PLAYER) == _player_wins_ties


func _priority_of(command: Dictionary) -> int:
	match str(command.get("type", "")):
		"skill":
			var skill := _get_skill(StringName(command.get("skill_id", "")))
			return skill.priority if skill else 0
		"struggle":
			return 0
	return ACTION_PRIORITY


func _opponent_of(combatant: BattleCombatant) -> BattleCombatant:
	return enemy if combatant.side == PLAYER else player


func _has_healthy_reserve() -> bool:
	for inst in party:
		if not inst.is_fainted():
			return true
	return false


func _find_party_member(uid: String) -> DigimonInstance:
	for inst in party:
		if inst.uid == uid:
			return inst
	return player.instance


func _mark_participant(combatant: BattleCombatant) -> void:
	if not participant_uids.has(combatant.instance.uid):
		participant_uids.append(combatant.instance.uid)


func _stat_text(target: BattleCombatant, stat: StringName, requested: int, applied: int) -> String:
	var stat_name := DigimonStats.display_name(stat)
	if applied == 0:
		return "%s's %s won't go any %s!" % [target.get_battle_name(), stat_name, "higher" if requested > 0 else "lower"]
	var amount_word := " sharply" if absi(applied) >= 2 else ""
	return "%s's %s%s %s!" % [target.get_battle_name(), stat_name, amount_word, "rose" if applied > 0 else "fell"]


func _msg(text: String) -> Dictionary:
	return {"type": "message", "text": text}


func _sp_event(combatant: BattleCombatant) -> Dictionary:
	return {"type": "sp", "side": combatant.side, "sp": combatant.instance.current_sp, "max_sp": combatant.instance.get_max_sp()}


func _heal_event(combatant: BattleCombatant, amount: int) -> Dictionary:
	return {"type": "heal", "side": combatant.side, "amount": amount, "hp": combatant.instance.current_hp, "max_hp": combatant.instance.get_max_hp()}


func _get_skill(skill_id: StringName) -> SkillData:
	var registry := _registry()
	return registry.get_skill(skill_id) if registry else null


func _registry() -> Node:
	var loop := Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("GameData") if loop is SceneTree else null
