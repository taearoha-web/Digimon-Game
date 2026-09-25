extends SceneTree
## Loads every GDScript / scene / resource in the project and reports failures.
## Usage: godot --headless --path . -s res://tools/check_scripts.gd

var _failures := 0
var _checked := 0


func _initialize() -> void:
	_scan("res://")
	print("check_scripts: %d files checked, %d failures" % [_checked, _failures])
	quit(1 if _failures > 0 else 0)


func _scan(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var path := dir_path.path_join(name)
		if dir.current_is_dir():
			if name != "addons" and name != "tests_output":
				_scan(path)
		elif name.ends_with(".gd"):
			_checked += 1
			var script := load(path) as GDScript
			if script == null or not script.can_instantiate():
				_failures += 1
				printerr("FAILED: ", path)
		elif name.ends_with(".tscn") or name.ends_with(".tres"):
			_checked += 1
			var res := load(path)
			if res == null:
				_failures += 1
				printerr("FAILED: ", path)
		name = dir.get_next()
	dir.list_dir_end()
