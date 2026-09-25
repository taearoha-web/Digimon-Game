class_name TestCase
extends RefCounted
## Minimal unit-test base class. Test methods start with "test_" and use the
## assert helpers; failures are collected, not thrown.

var failures: Array[String] = []
var current_test := ""
var assertions := 0


## Switches UI + data language for a test ("en" is the default for tests so
## assertions on English text stay stable).
static func use_locale(code: String) -> void:
	TranslationServer.set_locale(code)
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return
	var root := (loop as SceneTree).root
	var settings := root.get_node_or_null("Settings")
	if settings:
		settings.language = code # in memory only, so Settings.apply() agrees
	var registry := root.get_node_or_null("GameData")
	if registry:
		registry.apply_locale()


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func check(condition: bool, message := "") -> bool:
	assertions += 1
	if not condition:
		failures.append("%s: %s" % [current_test, message if message != "" else "assertion failed"])
	return condition


func check_eq(actual: Variant, expected: Variant, message := "") -> bool:
	assertions += 1
	if typeof(actual) != typeof(expected) and not (_is_number(actual) and _is_number(expected)):
		failures.append("%s: %s expected %s (%s) got %s (%s)" % [current_test, message, str(expected), type_string(typeof(expected)), str(actual), type_string(typeof(actual))])
		return false
	if actual != expected:
		failures.append("%s: %s expected %s got %s" % [current_test, message, str(expected), str(actual)])
		return false
	return true


func check_near(actual: float, expected: float, tolerance := 0.001, message := "") -> bool:
	assertions += 1
	if absf(actual - expected) > tolerance:
		failures.append("%s: %s expected %.4f got %.4f" % [current_test, message, expected, actual])
		return false
	return true


func check_not_null(value: Variant, message := "") -> bool:
	return check(value != null, message if message != "" else "value is null")


func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


## Fresh game state for tests that touch GameState.
func reset_game(starter: StringName = &"agumon", player_name := "Tester") -> void:
	var draft := NewGameDraft.new()
	draft.player_name = player_name
	draft.starter_species_id = starter
	GameState.start_new_game(draft)


func seeded_rng(seed_value := 1) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
