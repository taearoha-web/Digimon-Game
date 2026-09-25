class_name StarterRoster
extends Resource
## Data-driven list of starter choices. Add a species id here (and its
## species resource) to offer another starter — no code changes needed.

@export var starter_ids: Array[StringName] = []
@export var starting_level: int = 5
## species id -> short tagline shown on the starter card.
@export var taglines: Dictionary = {}
## Items given to every new game: item id -> quantity.
@export var starting_items: Dictionary = {}
@export var starting_currency: int = 100
