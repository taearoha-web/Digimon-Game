class_name FieldCombat
extends Node
## Real-time combat in the open world.
##
## The player walks around; the lead partner Digimon fights. Its equipped
## skills sit on the HUD skill bar (right side). Tapping a skill sends the
## partner at the locked-on monster and fires it there:
##   SINGLE  hits the target,
##   BLAST   explodes on the target and hits everything near it,
##   BURST   shockwave around the partner that hits everything close to it,
##   self    heals / buffs the partner.
## Monsters hit back (see [WildDigimon]); rewards use [FieldRewards].
## Damage and effects come from [FieldSkillResolver] / [DamageCalculator], so
## every number still follows the one formula used everywhere.

signal target_changed(target: WildDigimon)
signal skill_cast(skill: SkillData)
signal enemy_defeated(wild: WildDigimon)
signal partner_hurt()
signal partner_fainted(instance: DigimonInstance)
signal party_wiped()

const AUTO_TARGET_RANGE := 18.0
## Real-time hits land far more often than turn-based ones, so both sides'
## damage is scaled down to keep a fight at ~10-20 seconds.
const PLAYER_DAMAGE_SCALE := 0.42
const GLOBAL_COOLDOWN := 0.4
const CAST_TIMEOUT := 4.0
const CAST_DELAY := 0.2
## Fractions of max per second.
const SP_REGEN := 0.025
const SP_REGEN_RESTING := 0.06
const HP_REGEN_RESTING := 0.008
const REST_AFTER_SECONDS := 7.0

var world: Node3D
var player: Node3D
var partner: PartnerFollower
var combatant: BattleCombatant
var target: WildDigimon
## True while a dialogue / menu owns the screen: nothing fights.
var paused := false
var rng := RandomNumberGenerator.new()
var chart: TypeChart

var _cooldowns: Dictionary = {}
var _pending: Dictionary = {}
var _gcd := 0.0
var _since_combat := 99.0
var _sp_carry := 0.0
var _hp_carry := 0.0
var _fainting := false


func _ready() -> void:
	add_to_group("field_combat")
	rng.randomize()
	chart = GameData.type_chart
	process_priority = 5


func setup(p_world: Node3D, p_player: Node3D) -> void:
	world = p_world
	player = p_player


## Called by the world whenever the partner node is (re)created.
func set_partner(p_partner: PartnerFollower) -> void:
	partner = p_partner
	_pending.clear()
	_fainting = false
	if partner and partner.instance:
		combatant = BattleCombatant.new(partner.instance, BattleCombatant.PLAYER_SIDE)
		partner.disengage()
	else:
		combatant = null
	_cooldowns.clear()
	_gcd = 0.0


func register(wild: WildDigimon) -> void:
	if not wild.died.is_connected(_on_enemy_died):
		wild.died.connect(_on_enemy_died)


func partner_alive() -> bool:
	return partner != null and is_instance_valid(partner) and combatant != null and not combatant.is_fainted() and not _fainting


# ---------------------------------------------------------------------------
# Skills
# ---------------------------------------------------------------------------

## The (up to 4) skills shown on the skill bar.
func get_skills() -> Array[SkillData]:
	var result: Array[SkillData] = []
	if combatant == null:
		return result
	for skill in combatant.get_equipped_skills():
		result.append(skill)
		if result.size() >= 4:
			break
	return result


func cooldown_left(skill: SkillData) -> float:
	return maxf(0.0, float(_cooldowns.get(skill.id, 0.0)))


## 0 = ready, 1 = just used.
func cooldown_ratio(skill: SkillData) -> float:
	var total := maxf(skill.cooldown, 0.1)
	return clampf(cooldown_left(skill) / total, 0.0, 1.0)


func is_pending(skill: SkillData) -> bool:
	return not _pending.is_empty() and _pending.skill == skill


## "" when the skill can be used now, otherwise a reason id:
## cooldown | sp | no_target | busy | fainted | stunned
func can_use(skill: SkillData) -> StringName:
	if not partner_alive():
		return &"fainted"
	if FieldSkillResolver.is_disabled(combatant):
		return &"stunned"
	if _gcd > 0.0:
		return &"busy"
	if cooldown_left(skill) > 0.0:
		return &"cooldown"
	if not combatant.can_afford(skill):
		return &"sp"
	if skill.target == SkillData.Target.ENEMY and _pick_target_for_cast() == null:
		return &"no_target"
	return &""


## Starts a skill. Returns the failure reason (see [method can_use]) or "".
func use_skill(skill: SkillData) -> StringName:
	if skill == null or paused:
		return &"busy"
	var reason := can_use(skill)
	if reason != &"":
		_explain(reason)
		return reason
	_gcd = GLOBAL_COOLDOWN
	if skill.target == SkillData.Target.SELF:
		_cast(skill, null)
		return &""
	var tgt := _pick_target_for_cast()
	set_target(tgt)
	_pending = {"skill": skill, "target": tgt, "time": 0.0}
	partner.engage(tgt, skill.get_engage_range())
	return &""


func _explain(reason: StringName) -> void:
	match reason:
		&"sp":
			_float_on_partner(L10n.t("Not enough SP!"), UIPalette.SP, 0.8)
		&"no_target":
			EventBus.toast("No monster nearby.", &"info")
		&"stunned":
			_float_on_partner(L10n.t("Stunned!"), UIPalette.WARNING, 0.8)


func _pick_target_for_cast() -> WildDigimon:
	if target and is_instance_valid(target) and not target.is_dead() and _distance_to_partner(target) <= AUTO_TARGET_RANGE:
		return target
	return _nearest_enemy()


# ---------------------------------------------------------------------------
# Targeting
# ---------------------------------------------------------------------------

func get_enemies() -> Array[WildDigimon]:
	var result: Array[WildDigimon] = []
	for node in get_tree().get_nodes_in_group("wild_digimon"):
		var wild := node as WildDigimon
		if wild and is_instance_valid(wild) and not wild.is_dead():
			result.append(wild)
	return result


func set_target(wild: WildDigimon) -> void:
	if wild == target:
		return
	if target and is_instance_valid(target):
		target.set_targeted(false)
	target = wild
	if target:
		target.set_targeted(true)
		_show_first_hint()
	var rig = world.get("camera_rig") if world else null
	if rig:
		rig.combat_focus = target
	target_changed.emit(target)


## Locks onto the next closest monster (cycles on repeated calls).
func cycle_target() -> void:
	var enemies := _enemies_in_range()
	if enemies.is_empty():
		set_target(null)
		return
	var index := enemies.find(target)
	set_target(enemies[(index + 1) % enemies.size()])


func _nearest_enemy() -> WildDigimon:
	var enemies := _enemies_in_range()
	return enemies[0] if not enemies.is_empty() else null


## Monsters within targeting range, hostile ones first, then by distance.
func _enemies_in_range() -> Array[WildDigimon]:
	var enemies: Array[WildDigimon] = []
	for wild in get_enemies():
		if _distance_to_partner(wild) <= AUTO_TARGET_RANGE:
			enemies.append(wild)
	enemies.sort_custom(func(a: WildDigimon, b: WildDigimon) -> bool:
		if a.hostile != b.hostile:
			return a.hostile
		return _distance_to_partner(a) < _distance_to_partner(b))
	return enemies


func _distance_to_partner(wild: Node3D) -> float:
	var origin: Vector3 = (partner.global_position if partner else player.global_position)
	var d := wild.global_position - origin
	d.y = 0.0
	return d.length()


func _show_first_hint() -> void:
	if GameState.get_flag(&"field_combat_hint", false):
		return
	GameState.set_flag(&"field_combat_hint", true)
	EventBus.toast("Tap a skill on the right to attack — area skills hit every monster nearby!", &"info")


# ---------------------------------------------------------------------------
# Frame update
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if paused or combatant == null:
		return
	if combatant.is_fainted() and not _fainting:
		# E.g. a save with a fainted lead: hand over to the next member (or wake at the terminal).
		_on_partner_down(true)
		return
	_gcd = maxf(0.0, _gcd - delta)
	_since_combat += delta
	for skill_id in _cooldowns.keys():
		_cooldowns[skill_id] = maxf(0.0, float(_cooldowns[skill_id]) - delta)
	if target and (not is_instance_valid(target) or target.is_dead() or _distance_to_partner(target) > AUTO_TARGET_RANGE + 4.0):
		set_target(null)
	if target == null:
		var hostile_enemy := _nearest_hostile()
		if hostile_enemy:
			set_target(hostile_enemy)
	if not partner_alive():
		return
	_tick_partner(delta)
	_tick_pending(delta)
	_regenerate(delta)


func _nearest_hostile() -> WildDigimon:
	for wild in _enemies_in_range():
		if wild.hostile:
			return wild
	return null


func _tick_partner(delta: float) -> void:
	for event in FieldSkillResolver.tick(combatant, delta):
		if event.type == "status_damage":
			_float_on_partner(str(int(event.amount)), StatusEffects.get_color(event.status_id), 0.8)
			_since_combat = 0.0
			_refresh_hud()
			if event.killed:
				_on_partner_down()
				return


func _tick_pending(delta: float) -> void:
	if _pending.is_empty():
		return
	var skill: SkillData = _pending.skill
	var tgt: WildDigimon = _pending.target
	if tgt == null or not is_instance_valid(tgt) or tgt.is_dead():
		_cancel_pending()
		return
	_pending.time += delta
	var reach := skill.get_engage_range() + 0.55
	if _distance_to_partner(tgt) <= reach:
		_pending.clear()
		partner.disengage()
		_cast(skill, tgt)
	elif _pending.time > CAST_TIMEOUT:
		_cancel_pending()
		_float_on_partner(L10n.t("Too far!"), UIPalette.TEXT_DIM, 0.8)


func _cancel_pending() -> void:
	_pending.clear()
	if partner:
		partner.disengage()


func _regenerate(delta: float) -> void:
	var resting := _since_combat > REST_AFTER_SECONDS
	var instance := combatant.instance
	_sp_carry += float(instance.get_max_sp()) * (SP_REGEN_RESTING if resting else SP_REGEN) * delta
	if _sp_carry >= 1.0:
		var whole := int(_sp_carry)
		_sp_carry -= whole
		instance.restore_sp(whole)
	if resting and instance.current_hp < instance.get_max_hp():
		_hp_carry += float(instance.get_max_hp()) * HP_REGEN_RESTING * delta
		if _hp_carry >= 1.0:
			var hp := int(_hp_carry)
			_hp_carry -= hp
			instance.heal(hp)


# ---------------------------------------------------------------------------
# Casting
# ---------------------------------------------------------------------------

func _cast(skill: SkillData, tgt: WildDigimon) -> void:
	var instance := combatant.instance
	instance.current_sp = maxi(0, instance.current_sp - skill.sp_cost)
	_cooldowns[skill.id] = skill.cooldown
	_since_combat = 0.0
	skill_cast.emit(skill)
	AudioManager.play_sfx(skill.sfx)
	partner.play_action(skill.animation if skill.animation in [&"attack", &"skill"] else &"skill")
	var origin := partner.global_position + Vector3(0, 0.8, 0)
	if skill.target == SkillData.Target.SELF:
		partner.face_towards(partner.global_position + Vector3(0, 0, 1))
		BattleVfx.play_impact(world, skill.vfx, origin, 1.0)
		_apply_to_partner(skill, FieldSkillResolver.resolve(combatant, combatant, skill, rng, chart))
		_refresh_hud()
		return
	partner.face_towards(tgt.global_position)
	var impact_center := tgt.global_position
	var delay := CAST_DELAY
	if skill.projectile and skill.shape != SkillData.Shape.BURST:
		delay = clampf(origin.distance_to(tgt.get_hit_point()) / 16.0, 0.18, 0.55)
		BattleVfx.projectile(world, skill.vfx, origin, tgt.get_hit_point(), delay)
	elif skill.shape == SkillData.Shape.BURST:
		BattleVfx.ring(world, partner.global_position + Vector3(0, 0.15, 0), BattleVfx.preset_color(skill.vfx), skill.area_radius * 1.2)
	get_tree().create_timer(delay).timeout.connect(func(): _land(skill, tgt, impact_center), CONNECT_ONE_SHOT)


func _land(skill: SkillData, tgt: WildDigimon, last_center: Vector3) -> void:
	if not partner_alive():
		return
	var center := partner.global_position if skill.shape == SkillData.Shape.BURST else \
			(tgt.global_position if tgt and is_instance_valid(tgt) else last_center)
	var hits: Array[WildDigimon] = []
	if skill.shape == SkillData.Shape.SINGLE:
		if tgt and is_instance_valid(tgt) and not tgt.is_dead():
			hits.append(tgt)
	else:
		for wild in get_enemies():
			var d := wild.global_position - center
			d.y = 0.0
			if d.length() <= skill.area_radius + 0.4:
				hits.append(wild)
		if skill.shape == SkillData.Shape.BLAST:
			BattleVfx.ring(world, center + Vector3(0, 0.15, 0), BattleVfx.preset_color(skill.vfx), skill.area_radius * 1.2)
	for wild in hits:
		_hit_enemy(skill, wild)
	if not hits.is_empty():
		_shake(0.1 + 0.03 * mini(hits.size(), 4))


func _hit_enemy(skill: SkillData, wild: WildDigimon) -> void:
	var events := FieldSkillResolver.resolve(combatant, wild.combatant, skill, rng, chart, PLAYER_DAMAGE_SCALE)
	var uid := combatant.instance.uid
	var any_damage := false
	for event in events:
		match event.type:
			"miss":
				BattleVfx.floating_text(world, wild.get_top_point(), L10n.t("MISS"), UIPalette.TEXT_DIM, 0.8)
			"damage":
				any_damage = true
				var amount := int(event.amount)
				var mult: float = event.type_multiplier
				var color := UIPalette.GOLD if event.critical else (UIPalette.ORANGE if mult >= 1.2 else (UIPalette.TEXT_DIM if mult <= 0.85 else Color.WHITE))
				BattleVfx.play_impact(world, skill.vfx, wild.get_hit_point(), 1.3 if event.critical else 1.0)
				BattleVfx.floating_text(world, wild.get_top_point(), str(amount) + ("!" if event.critical else ""), color,
					1.3 if event.critical else (1.1 if mult >= 1.2 else 1.0))
				wild.take_damage(amount, uid)
				if not wild.is_dead():
					wild.play_hurt()
					wild.knock_back(partner.global_position, 3.0 if skill.shape == SkillData.Shape.SINGLE else 2.0)
			"stat":
				BattleVfx.stat_arrows(world, wild.get_hit_point() if not event.target_is_user else partner.global_position + Vector3(0, 0.8, 0), event.delta > 0)
			"status":
				BattleVfx.floating_text(world, wild.get_top_point() + Vector3(0, 0.3, 0), StatusEffects.get_display_name(event.status_id),
					StatusEffects.get_color(event.status_id), 0.7)
				wild.provoke()
			"drain":
				_float_on_partner("+%d" % int(event.amount), UIPalette.SUCCESS, 0.8)
				_refresh_hud()
			"heal":
				_float_on_partner("+%d" % int(event.amount), UIPalette.SUCCESS, 0.9)
	if not any_damage and skill.target == SkillData.Target.ENEMY and not wild.is_dead():
		# Debuffs and status skills still wake the monster up.
		BattleVfx.play_impact(world, skill.vfx, wild.get_hit_point())
		wild.provoke()
		if not wild.contributors.has(uid):
			wild.contributors.append(uid)


func _apply_to_partner(skill: SkillData, events: Array[Dictionary]) -> void:
	for event in events:
		match event.type:
			"heal":
				_float_on_partner("+%d" % int(event.amount) if int(event.amount) > 0 else L10n.t("HP full"), UIPalette.SUCCESS, 1.0)
			"stat":
				BattleVfx.stat_arrows(world, partner.global_position + Vector3(0, 0.8, 0), event.delta > 0)
				if event.delta == 0:
					_float_on_partner(L10n.t("Can't go any higher!") if event.delta >= 0 else L10n.t("Can't go any lower!"), UIPalette.TEXT_DIM, 0.7)
			"sp":
				_float_on_partner("+%d SP" % int(event.amount), UIPalette.SP, 0.8)


# ---------------------------------------------------------------------------
# Monsters attacking the partner
# ---------------------------------------------------------------------------

func enemy_attack(wild: WildDigimon, skill: SkillData) -> void:
	if not partner_alive() or paused:
		return
	var reach := (WildDigimon.RANGED_REACH if skill.projectile else WildDigimon.MELEE_REACH) * 1.4
	if _distance_to_partner(wild) > reach:
		return
	if skill.projectile:
		var from := wild.get_hit_point()
		var to := partner.global_position + Vector3(0, 0.8, 0)
		BattleVfx.projectile(world, skill.vfx, from, to, clampf(from.distance_to(to) / 14.0, 0.15, 0.5))
		get_tree().create_timer(clampf(from.distance_to(to) / 14.0, 0.15, 0.5)).timeout.connect(
				func(): _enemy_hit(wild, skill), CONNECT_ONE_SHOT)
	else:
		_enemy_hit(wild, skill)


func _enemy_hit(wild: WildDigimon, skill: SkillData) -> void:
	if not partner_alive() or not is_instance_valid(wild) or wild.is_dead():
		return
	_since_combat = 0.0
	var events := FieldSkillResolver.resolve(wild.combatant, combatant, skill, rng, chart, WildDigimon.DAMAGE_SCALE)
	for event in events:
		match event.type:
			"miss":
				_float_on_partner(L10n.t("MISS"), UIPalette.TEXT_DIM, 0.8)
			"damage":
				BattleVfx.play_impact(world, skill.vfx, partner.global_position + Vector3(0, 0.7, 0), 0.9)
				_float_on_partner(str(int(event.amount)), UIPalette.DANGER, 1.1 if event.critical else 1.0)
				partner.visual.flash(Color(1, 0.4, 0.4))
				if not partner.is_action_playing():
					partner.play_action(&"hurt", 350)
				AudioManager.play_sfx(&"hit_physical")
				_shake(0.12)
				partner_hurt.emit()
			"status":
				_float_on_partner(StatusEffects.get_display_name(event.status_id), StatusEffects.get_color(event.status_id), 0.7)
			"stat":
				BattleVfx.stat_arrows(world, partner.global_position + Vector3(0, 0.8, 0), event.delta > 0)
	_refresh_hud()
	if combatant.is_fainted():
		_on_partner_down()


func _on_partner_down(quiet := false) -> void:
	if _fainting:
		return
	_fainting = true
	_pending.clear()
	partner.disengage()
	partner.play_action(&"defeat", 5000, &"")
	var fallen := combatant.instance
	if not quiet:
		EventBus.toast(L10n.t("%s fainted!") % fallen.get_display_name(), &"warning")
	partner_fainted.emit(fallen)
	set_target(null)
	for wild in get_enemies():
		wild.hostile = false
	get_tree().create_timer(1.3).timeout.connect(_after_faint, CONNECT_ONE_SHOT)


func _after_faint() -> void:
	var party := GameState.roster.get_party()
	var next_index := GameState.roster.first_healthy_party_index()
	if next_index < 0 or next_index >= party.size():
		party_wiped.emit()
		return
	var next := party[next_index]
	GameState.roster.set_lead(next.uid)
	EventBus.toast(L10n.t("%s steps in!") % next.get_display_name(), &"info")


# ---------------------------------------------------------------------------
# Victory
# ---------------------------------------------------------------------------

func _on_enemy_died(wild: WildDigimon) -> void:
	if wild == target:
		set_target(null)
	_since_combat = 0.0
	enemy_defeated.emit(wild)
	var party := GameState.roster.get_party()
	var summary := FieldRewards.apply_victory(wild.instance.get_species(), wild.level, party, wild.contributors, rng,
			GameData.recruitment_config, QuestManager.count_completed())
	EventBus.battle_won.emit(wild.species_id, wild.level)
	var level_ups: Array = []
	for entry in summary.exp_entries:
		if combatant != null and entry.instance == combatant.instance:
			_float_on_partner("+%d EXP" % int(entry.amount), UIPalette.EXP, 0.9)
		if not entry.level_ups.is_empty():
			level_ups.append({"instance": entry.instance, "ups": entry.level_ups})
			EventBus.digimon_leveled_up.emit(entry.instance, entry.instance.level)
	for item_id in summary.drops.keys():
		var qty := int(summary.drops[item_id])
		GameState.inventory.add_item(StringName(item_id), qty)
		var item := GameData.get_item(StringName(item_id))
		EventBus.toast("+%d %s" % [qty, item.display_name if item else String(item_id)], &"item")
	var recruit: DigimonInstance = summary.recruit
	if recruit:
		_add_recruit(recruit)
	GameState.roster.notify_changed()
	_refresh_hud()
	if world and world.get("popups") and not level_ups.is_empty():
		world.popups.show_level_ups(level_ups)


func _add_recruit(recruit: DigimonInstance) -> void:
	var placed := GameState.roster.add_digimon(recruit)
	if placed == &"full":
		EventBus.toast("Your Collection is full.", &"warning")
		return
	EventBus.digimon_recruited.emit(recruit)
	EventBus.toast(L10n.t("%s joined your party!" if placed == &"party" else "%s joined your Collection!") % recruit.get_display_name(), &"success")
	SaveManager.autosave("digimon recruited", true)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _float_on_partner(text: String, color: Color, size := 1.0) -> void:
	if partner and world:
		BattleVfx.floating_text(world, partner.global_position + Vector3(0, partner.visual.model_height + 0.4, 0), text, color, size)


func _refresh_hud() -> void:
	var hud = world.get("hud") if world else null
	if hud:
		hud.refresh_partner()


func _shake(strength: float) -> void:
	var rig = world.get("camera_rig") if world else null
	if rig and rig.has_method("shake"):
		rig.shake(strength)


func _unhandled_input(event: InputEvent) -> void:
	if paused:
		return
	for i in 4:
		if event.is_action_pressed("skill_%d" % (i + 1)):
			var skills := get_skills()
			if i < skills.size():
				use_skill(skills[i])
				get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("target_next"):
		cycle_target()
		get_viewport().set_input_as_handled()
