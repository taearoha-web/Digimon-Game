class_name DialogueData
extends Resource
## A reusable conversation. Kept out of gameplay scripts so writers can edit
## dialogue as data (res://data/dialogue/*.tres).

@export var id: StringName
@export var lines: Array[DialogueLine] = []
## Whether the player may skip the remaining lines.
@export var skippable: bool = true
