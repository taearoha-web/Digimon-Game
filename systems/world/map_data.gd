class_name MapData
extends Resource
## Registry entry for a world map / zone.

@export var id: StringName
@export var display_name: String = ""
@export_file("*.tscn") var scene_path: String = ""
@export var default_spawn_id: StringName = &"start"
@export var music_id: StringName = &"field"
@export_multiline var description: String = ""
