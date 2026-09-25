class_name NewGameDraft
extends RefCounted
## Choices collected across the New Game screens before the save exists.
## Passed from screen to screen through SceneManager params so Back works.

var appearance: CharacterAppearance = CharacterAppearance.create_default()
var starter_species_id: StringName = &""
var player_name: String = ""


func is_complete() -> bool:
	return appearance != null and starter_species_id != &"" and NameValidator.validate(player_name) == ""
