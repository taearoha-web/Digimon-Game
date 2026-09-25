class_name PlayerProfile
extends RefCounted
## The human player's identity and wallet.

signal currency_changed(amount: int)

var player_name: String = ""
var appearance: CharacterAppearance = CharacterAppearance.new()
var starter_species_id: StringName = &""
var currency: int = 0
var play_time_seconds: float = 0.0
var created_at: int = 0


func add_currency(amount: int) -> void:
	currency = maxi(0, currency + amount)
	currency_changed.emit(currency)


func spend_currency(amount: int) -> bool:
	if amount > currency:
		return false
	currency -= amount
	currency_changed.emit(currency)
	return true


func to_dict() -> Dictionary:
	return {
		"player_name": player_name,
		"appearance": appearance.to_dict(),
		"starter_species_id": String(starter_species_id),
		"currency": currency,
		"play_time_seconds": play_time_seconds,
		"created_at": created_at,
	}


func load_dict(data: Dictionary) -> void:
	player_name = NameValidator.sanitize(str(data.get("player_name", "")))
	if player_name == "":
		player_name = "Tamer"
	var app = data.get("appearance", {})
	appearance = CharacterAppearance.from_dict(app if app is Dictionary else {})
	starter_species_id = StringName(str(data.get("starter_species_id", "")))
	currency = maxi(0, int(data.get("currency", 0)))
	play_time_seconds = maxf(0.0, float(data.get("play_time_seconds", 0.0)))
	created_at = int(data.get("created_at", 0))
