class_name CharacterAppearance
extends RefCounted
## The player's (or an NPC's) look. One shared model for every body type —
## body-type differences are proportions/defaults, never separate logic.

var body_type: StringName = &"male"
var hair_style: StringName = &"spiky"
var hair_color: Color = Color("5a3a26")
var face: StringName = &"cheerful"
var eye_color: Color = Color("3b6fd1")
var skin_tone: Color = Color("f6d2b3")
var top: StringName = &"t_shirt"
var top_color: Color = Color("ff7a45")
var bottom: StringName = &"shorts"
var bottom_color: Color = Color("2f4a8a")
var shoes: StringName = &"sneakers"
var shoes_color: Color = Color("f2f2f2")
## Enabled accessory ids (e.g. &"hat", &"glasses", &"backpack").
var accessories: Array[StringName] = []
var accessory_color: Color = Color("ffd166")


static func create_default(body: StringName = &"male") -> CharacterAppearance:
	var a := CharacterAppearance.new()
	a.body_type = body
	if body == &"female":
		a.hair_style = &"ponytail"
		a.hair_color = Color("8a4b2f")
		a.top = &"hoodie"
		a.top_color = Color("ff8fb1")
		a.bottom = &"long_pants"
		a.bottom_color = Color("3a3f6b")
	return a


func has_accessory(accessory_id: StringName) -> bool:
	return accessories.has(accessory_id)


func set_accessory(accessory_id: StringName, enabled: bool) -> void:
	if enabled and not accessories.has(accessory_id):
		accessories.append(accessory_id)
	elif not enabled:
		accessories.erase(accessory_id)


func duplicate_appearance() -> CharacterAppearance:
	return CharacterAppearance.from_dict(to_dict())


## Picks a random value for every slot from [param catalog].
func randomize_from(catalog: CustomizationCatalog, rng: RandomNumberGenerator, keep_body := true) -> void:
	if not keep_body and not catalog.body_types.is_empty():
		body_type = _pick_id(catalog.body_types, rng, body_type)
	hair_style = _pick_id(catalog.hair_styles, rng, hair_style)
	face = _pick_id(catalog.faces, rng, face)
	top = _pick_id(catalog.tops, rng, top)
	bottom = _pick_id(catalog.bottoms, rng, bottom)
	shoes = _pick_id(catalog.shoes, rng, shoes)
	hair_color = _pick_color(catalog.hair_colors, rng, hair_color)
	eye_color = _pick_color(catalog.eye_colors, rng, eye_color)
	skin_tone = _pick_color(catalog.skin_tones, rng, skin_tone)
	top_color = _pick_color(catalog.clothing_colors, rng, top_color)
	bottom_color = _pick_color(catalog.clothing_colors, rng, bottom_color)
	shoes_color = _pick_color(catalog.clothing_colors, rng, shoes_color)
	accessory_color = _pick_color(catalog.clothing_colors, rng, accessory_color)
	accessories.clear()
	for option in catalog.accessories:
		if rng.randf() < 0.35:
			accessories.append(StringName(option.get("id", "")))


func to_dict() -> Dictionary:
	var acc: Array = []
	for a in accessories:
		acc.append(String(a))
	return {
		"body_type": String(body_type),
		"hair_style": String(hair_style),
		"hair_color": hair_color.to_html(false),
		"face": String(face),
		"eye_color": eye_color.to_html(false),
		"skin_tone": skin_tone.to_html(false),
		"top": String(top),
		"top_color": top_color.to_html(false),
		"bottom": String(bottom),
		"bottom_color": bottom_color.to_html(false),
		"shoes": String(shoes),
		"shoes_color": shoes_color.to_html(false),
		"accessories": acc,
		"accessory_color": accessory_color.to_html(false),
	}


static func from_dict(data: Dictionary) -> CharacterAppearance:
	var a := CharacterAppearance.new()
	if data.is_empty():
		return a
	a.body_type = StringName(str(data.get("body_type", a.body_type)))
	a.hair_style = StringName(str(data.get("hair_style", a.hair_style)))
	a.hair_color = _parse_color(data.get("hair_color"), a.hair_color)
	a.face = StringName(str(data.get("face", a.face)))
	a.eye_color = _parse_color(data.get("eye_color"), a.eye_color)
	a.skin_tone = _parse_color(data.get("skin_tone"), a.skin_tone)
	a.top = StringName(str(data.get("top", a.top)))
	a.top_color = _parse_color(data.get("top_color"), a.top_color)
	a.bottom = StringName(str(data.get("bottom", a.bottom)))
	a.bottom_color = _parse_color(data.get("bottom_color"), a.bottom_color)
	a.shoes = StringName(str(data.get("shoes", a.shoes)))
	a.shoes_color = _parse_color(data.get("shoes_color"), a.shoes_color)
	a.accessory_color = _parse_color(data.get("accessory_color"), a.accessory_color)
	a.accessories.clear()
	var acc = data.get("accessories", [])
	if acc is Array:
		for entry in acc:
			a.accessories.append(StringName(str(entry)))
	return a


static func _parse_color(value, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is String and Color.html_is_valid(value):
		return Color.html(value)
	return fallback


static func _pick_id(options: Array[Dictionary], rng: RandomNumberGenerator, fallback: StringName) -> StringName:
	if options.is_empty():
		return fallback
	return StringName(options[rng.randi_range(0, options.size() - 1)].get("id", fallback))


static func _pick_color(palette: PackedColorArray, rng: RandomNumberGenerator, fallback: Color) -> Color:
	if palette.is_empty():
		return fallback
	return palette[rng.randi_range(0, palette.size() - 1)]
