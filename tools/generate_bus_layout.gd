extends SceneTree
## Writes res://default_bus_layout.tres with the Master/Music/SFX/UI buses.
## Usage: godot --headless --path . -s res://tools/generate_bus_layout.gd


func _initialize() -> void:
	for bus_name in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")
	var err := ResourceSaver.save(AudioServer.generate_bus_layout(), "res://default_bus_layout.tres")
	print("generate_bus_layout: ", error_string(err))
	quit()
