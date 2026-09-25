extends SceneTree
## Writes the default input map into project.godot (keyboard/mouse fallback
## controls for PC testing). Usage:
##   godot --headless --path . -s res://tools/setup_project_input.gd
## The same defaults are also ensured at runtime by InputSetup.


func _initialize() -> void:
	for action in InputSetup.DEFAULTS.keys():
		var events: Array = []
		for spec in InputSetup.DEFAULTS[action]:
			events.append(InputSetup.make_event(spec))
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})
	ProjectSettings.set_setting("application/config/quit_on_go_back", false)
	var err := ProjectSettings.save()
	print("setup_project_input: ", error_string(err))
	quit()
