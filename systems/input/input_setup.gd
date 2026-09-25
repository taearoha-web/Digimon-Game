class_name InputSetup
extends RefCounted
## Default input map (PC fallback controls). Mirrors project.godot so the game
## still works if the project settings lose an action.

## action -> list of specs: ["key", KEY_*] | ["mouse", MOUSE_BUTTON_*]
const DEFAULTS := {
	"move_forward": [["key", KEY_W], ["key", KEY_UP]],
	"move_back": [["key", KEY_S], ["key", KEY_DOWN]],
	"move_left": [["key", KEY_A], ["key", KEY_LEFT]],
	"move_right": [["key", KEY_D], ["key", KEY_RIGHT]],
	"sprint": [["key", KEY_SHIFT]],
	"interact": [["key", KEY_F], ["key", KEY_SPACE], ["key", KEY_ENTER]],
	"pause_menu": [["key", KEY_ESCAPE], ["key", KEY_TAB]],
	"camera_left": [["key", KEY_Q]],
	"camera_right": [["key", KEY_E]],
	"camera_zoom_in": [["mouse", MOUSE_BUTTON_WHEEL_UP], ["key", KEY_EQUAL]],
	"camera_zoom_out": [["mouse", MOUSE_BUTTON_WHEEL_DOWN], ["key", KEY_MINUS]],
	"open_party": [["key", KEY_P]],
	"open_inventory": [["key", KEY_I]],
	"open_quests": [["key", KEY_J]],
}


static func make_event(spec: Array) -> InputEvent:
	match spec[0]:
		"key":
			var e := InputEventKey.new()
			e.physical_keycode = spec[1]
			return e
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = spec[1]
			return m
	return null


## Adds any missing default action at runtime.
static func ensure_defaults() -> void:
	for action in DEFAULTS.keys():
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for spec in DEFAULTS[action]:
			var event := make_event(spec)
			if event:
				InputMap.action_add_event(action, event)
