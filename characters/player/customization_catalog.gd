class_name CustomizationCatalog
extends Resource
## Every option the character creator offers. Pure data: add entries here to
## offer new body types, hairstyles, clothes or colours without touching logic.
##
## Option entries are dictionaries with at least {"id": StringName, "name": String}.
## Body type entries also carry proportion parameters read by [ChibiAvatar].

@export var body_types: Array[Dictionary] = []
@export var hair_styles: Array[Dictionary] = []
@export var faces: Array[Dictionary] = []
@export var tops: Array[Dictionary] = []
@export var bottoms: Array[Dictionary] = []
@export var shoes: Array[Dictionary] = []
@export var accessories: Array[Dictionary] = []

@export var hair_colors: PackedColorArray = PackedColorArray()
@export var eye_colors: PackedColorArray = PackedColorArray()
@export var skin_tones: PackedColorArray = PackedColorArray()
@export var clothing_colors: PackedColorArray = PackedColorArray()


func get_options(slot: StringName) -> Array[Dictionary]:
	match slot:
		&"body_type": return body_types
		&"hair_style": return hair_styles
		&"face": return faces
		&"top": return tops
		&"bottom": return bottoms
		&"shoes": return shoes
		&"accessory": return accessories
	return []


func get_palette(slot: StringName) -> PackedColorArray:
	match slot:
		&"hair_color": return hair_colors
		&"eye_color": return eye_colors
		&"skin_tone": return skin_tones
		&"top_color", &"bottom_color", &"shoes_color", &"accessory_color":
			return clothing_colors
	return PackedColorArray()


func find_option(slot: StringName, option_id: StringName) -> Dictionary:
	for option in get_options(slot):
		if StringName(option.get("id", "")) == option_id:
			return option
	return {}


func index_of_option(slot: StringName, option_id: StringName) -> int:
	var options := get_options(slot)
	for i in options.size():
		if StringName(options[i].get("id", "")) == option_id:
			return i
	return -1


static func index_of_color(palette: PackedColorArray, color: Color) -> int:
	var best := -1
	var best_distance := INF
	for i in palette.size():
		var c := palette[i]
		var d := Vector3(c.r - color.r, c.g - color.g, c.b - color.b).length_squared()
		if d < best_distance:
			best_distance = d
			best = i
	return best
