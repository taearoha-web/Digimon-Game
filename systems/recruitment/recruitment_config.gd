class_name RecruitmentConfig
extends Resource
## Tunable recruitment formula (see [RecruitmentService]).

## Base chance per rarity (index = DigimonSpecies.Rarity).
@export var base_chance_by_rarity: PackedFloat32Array = PackedFloat32Array([0.45, 0.30, 0.16, 0.03])
## How strongly missing HP increases the befriend chance (0 = no effect).
@export var hp_weight: float = 1.2
## Chance change per level the player's Digimon is above the target.
@export var level_weight: float = 0.03
## Bonus per completed quest (player progression).
@export var progression_bonus_per_quest: float = 0.03
@export var max_progression_bonus: float = 0.15
## Friendship of the active Digimon (0..100) scaled into a bonus.
@export var friendship_weight: float = 0.001
## Multiplier for the "wants to join after defeat" roll.
@export var post_defeat_multiplier: float = 0.35
@export var min_chance: float = 0.03
@export var max_chance: float = 0.95
## Maximum owned Digimon (party + storage).
@export var roster_capacity: int = 60
