class_name FieldSkillResolver
extends RefCounted
## Applies one skill to one target in real-time field combat and returns what
## happened as plain event dictionaries (no scene access, so it is unit-tested
## and shared by the player's partner and by wild monsters).
##
## Events:
##   { type: "miss" }
##   { type: "damage", amount, critical, type_multiplier, hp, max_hp, killed }
##   { type: "heal",   amount, hp, max_hp }
##   { type: "drain",  amount, hp, max_hp }          (heals the user)
##   { type: "stat",   stat, delta, target_is_user }
##   { type: "status", status_id }
##   { type: "sp",     amount }
## Turn-based "N turns" become seconds here: see [constant SECONDS_PER_TURN].

const SECONDS_PER_TURN := 1.5
const STATUS_TICK_SECONDS := 1.5
## Stat stages from buffs / debuffs wear off after this many seconds.
const STAGE_SECONDS := 25.0


static func resolve(user: BattleCombatant, target: BattleCombatant, skill: SkillData,
		rng: RandomNumberGenerator, chart: TypeChart, damage_scale := 1.0) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if skill == null or user == null:
		return events
	var skill_target := user if skill.target == SkillData.Target.SELF or target == null else target
	if skill.target == SkillData.Target.ENEMY and not DamageCalculator.roll_hit(user, skill, rng):
		events.append({"type": "miss"})
		return events
	var last_damage := 0
	for effect in skill.effects:
		if effect == null:
			continue
		var effect_target := user if effect.target == SkillEffect.EffectTarget.USER else skill_target
		if effect.type != SkillEffect.Type.DAMAGE and effect.chance < 1.0 and rng.randf() >= effect.chance:
			continue
		match effect.type:
			SkillEffect.Type.DAMAGE:
				if skill_target.is_fainted():
					continue
				var result := DamageCalculator.calculate(user, skill_target, skill, rng, chart)
				last_damage = skill_target.instance.take_damage(maxi(1, int(round(result.amount * damage_scale))))
				events.append({
					"type": "damage", "amount": last_damage, "critical": result.critical,
					"type_multiplier": result.type_multiplier, "hp": skill_target.instance.current_hp,
					"max_hp": skill_target.instance.get_max_hp(), "killed": skill_target.is_fainted(),
				})
			SkillEffect.Type.HEAL:
				if effect_target.is_fainted():
					continue
				var healed := effect_target.instance.heal(int(ceil(effect_target.instance.get_max_hp() * effect.amount / 100.0)))
				events.append({"type": "heal", "amount": healed, "hp": effect_target.instance.current_hp,
					"max_hp": effect_target.instance.get_max_hp()})
			SkillEffect.Type.BUFF, SkillEffect.Type.DEBUFF:
				if effect_target.is_fainted():
					continue
				var delta := effect.amount if effect.type == SkillEffect.Type.BUFF else -effect.amount
				var applied := effect_target.modify_stage(effect.stat, delta)
				effect_target.field_stage_time = STAGE_SECONDS
				events.append({"type": "stat", "stat": effect.stat, "delta": applied, "target_is_user": effect_target == user})
			SkillEffect.Type.STATUS:
				if effect_target.is_fainted():
					continue
				if effect_target.apply_status(effect.status_id, effect.duration):
					effect_target.field_status_time = float(effect.duration) * SECONDS_PER_TURN
					effect_target.field_status_tick = 0.0
					events.append({"type": "status", "status_id": effect.status_id})
			SkillEffect.Type.RESTORE_SP:
				effect_target.instance.restore_sp(effect.amount)
				events.append({"type": "sp", "amount": effect.amount})
			SkillEffect.Type.DRAIN:
				if last_damage > 0 and not user.is_fainted():
					var drained := user.instance.heal(int(ceil(last_damage * effect.amount / 100.0)))
					if drained > 0:
						events.append({"type": "drain", "amount": drained, "hp": user.instance.current_hp,
							"max_hp": user.instance.get_max_hp()})
	return events


## Advances status and stat-stage timers. Returns events:
##   { type: "status_damage", amount, status_id, killed } and { type: "status_end", status_id }
static func tick(combatant: BattleCombatant, delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if combatant.field_stage_time > 0.0:
		combatant.field_stage_time -= delta
		if combatant.field_stage_time <= 0.0:
			combatant.stages.clear()
	if combatant.status_id == &"" or combatant.is_fainted():
		return events
	var def := StatusEffects.get_def(combatant.status_id)
	combatant.field_status_time -= delta
	combatant.field_status_tick += delta
	if combatant.field_status_tick >= STATUS_TICK_SECONDS:
		combatant.field_status_tick -= STATUS_TICK_SECONDS
		var percent := int(def.get("damage_percent", 0))
		if percent > 0:
			var amount := combatant.instance.take_damage(maxi(1, int(ceil(combatant.instance.get_max_hp() * percent / 100.0))))
			events.append({"type": "status_damage", "amount": amount, "status_id": combatant.status_id,
				"killed": combatant.is_fainted()})
	if combatant.field_status_time <= 0.0 and not combatant.is_fainted():
		events.append({"type": "status_end", "status_id": combatant.status_id})
		combatant.clear_status()
	return events


## Stun-like statuses stop a combatant from acting.
static func is_disabled(combatant: BattleCombatant) -> bool:
	return combatant.status_id != &"" and float(StatusEffects.get_def(combatant.status_id).get("skip_chance", 0.0)) > 0.0


## Movement-speed multiplier from Speed stages and statuses (1.0 = normal).
static func speed_factor(combatant: BattleCombatant) -> float:
	var base := float(combatant.instance.get_stat(DigimonStats.SPEED))
	return clampf(combatant.get_effective_stat(DigimonStats.SPEED) / maxf(base, 1.0), 0.4, 1.6)
