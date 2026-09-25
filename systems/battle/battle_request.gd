class_name BattleRequest
extends RefCounted
## Describes a battle to start. Created by the world, consumed by BattleScene.

var enemy_species_id: StringName = &""
var enemy_level: int = 3
var is_wild: bool = true
var can_escape: bool = true
var can_befriend: bool = true
## Map to return to afterwards.
var return_map_id: StringName = &"starter_zone"
## Identifier of the world spawner slot, so the world can remove that Digimon.
var source_id: String = ""
var arena_theme: StringName = &"digital_field"
var music_id: StringName = &"battle"


static func wild(species_id: StringName, level: int) -> BattleRequest:
	var req := BattleRequest.new()
	req.enemy_species_id = species_id
	req.enemy_level = level
	return req
