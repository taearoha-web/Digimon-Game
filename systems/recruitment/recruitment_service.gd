class_name RecruitmentService
extends RefCounted
## Digimon recruitment ("befriending"). Not a capture device: wild Digimon
## choose to join a Tamer they respect. All weights come from
## [RecruitmentConfig] so balancing never touches code.


## Chance for the in-battle "Befriend" action.
static func befriend_chance(target: BattleCombatant, active: BattleCombatant, cfg: RecruitmentConfig,
		completed_quests: int) -> float:
	var species := target.get_species()
	var base := _base_for(species, cfg)
	# Missing HP makes the wild Digimon more willing to listen.
	var missing := 1.0 - target.instance.get_hp_ratio()
	var chance := base * (0.35 + cfg.hp_weight * missing)
	chance += _level_bonus(active.get_level(), target.get_level(), cfg)
	chance += _progress_bonus(completed_quests, cfg)
	chance += float(active.instance.friendship) * cfg.friendship_weight
	chance += target.befriend_bonus
	if target.status_id != &"":
		chance += 0.05
	return clampf(chance, cfg.min_chance, cfg.max_chance)


## Chance that a defeated wild Digimon asks to join afterwards.
static func post_defeat_chance(species: DigimonSpecies, enemy_level: int, active_level: int,
		cfg: RecruitmentConfig, completed_quests: int) -> float:
	var chance := _base_for(species, cfg) * cfg.post_defeat_multiplier
	chance += _level_bonus(active_level, enemy_level, cfg) * 0.5
	chance += _progress_bonus(completed_quests, cfg) * 0.5
	return clampf(chance, cfg.min_chance, cfg.max_chance)


static func roll(chance: float, rng: RandomNumberGenerator) -> bool:
	return rng.randf() < chance


## Builds the Digimon that joins: healed, with some starting friendship.
static func create_recruit(species_id: StringName, level: int, rng: RandomNumberGenerator = null) -> DigimonInstance:
	var inst := DigimonInstance.create(species_id, level, rng)
	inst.origin = &"recruited"
	inst.friendship = 10
	inst.full_restore()
	return inst


static func _base_for(species: DigimonSpecies, cfg: RecruitmentConfig) -> float:
	if species == null:
		return 0.0
	var rarity := clampi(species.rarity, 0, cfg.base_chance_by_rarity.size() - 1)
	return float(cfg.base_chance_by_rarity[rarity]) * species.recruit_modifier


static func _level_bonus(active_level: int, target_level: int, cfg: RecruitmentConfig) -> float:
	return clampf(float(active_level - target_level) * cfg.level_weight, -0.2, 0.2)


static func _progress_bonus(completed_quests: int, cfg: RecruitmentConfig) -> float:
	return minf(float(completed_quests) * cfg.progression_bonus_per_quest, cfg.max_progression_bonus)
