extends Node
## Runs every tests/unit/test_*.gd script and prints a report.
## Usage: godot --headless --path . res://tests/test_runner.tscn
## Exit code = number of failed tests (0 = success).

const UNIT_DIR := "res://tests/unit"


func _ready() -> void:
	# Keep tests away from real player saves.
	await get_tree().process_frame
	# Assertions compare English text; translation tests switch locale themselves.
	TestCase.use_locale("en")
	var total_tests := 0
	var total_failures := 0
	var total_assertions := 0
	var failed_names: Array[String] = []
	var dir := DirAccess.open(UNIT_DIR)
	var files: Array[String] = []
	if dir:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if f.begins_with("test_") and f.ends_with(".gd"):
				files.append(f)
			f = dir.get_next()
		dir.list_dir_end()
	files.sort()
	for file in files:
		var script := load(UNIT_DIR.path_join(file)) as GDScript
		if script == null or not script.can_instantiate():
			print("  [ERROR] cannot load ", file)
			total_failures += 1
			failed_names.append(file)
			continue
		var methods: Array[String] = []
		for m in script.get_script_method_list():
			var method_name := str(m.name)
			if method_name.begins_with("test_") and not methods.has(method_name):
				methods.append(method_name)
		print("%s (%d tests)" % [file, methods.size()])
		for method_name in methods:
			var tc: TestCase = script.new()
			tc.current_test = "%s.%s" % [file.get_basename(), method_name]
			tc.before_each()
			tc.call(method_name)
			tc.after_each()
			total_tests += 1
			total_assertions += tc.assertions
			if tc.failures.is_empty():
				print("  ok   ", method_name)
			else:
				total_failures += 1
				failed_names.append(tc.current_test)
				print("  FAIL ", method_name)
				for failure in tc.failures:
					print("       - ", failure)
	print("")
	print("==== %d tests, %d assertions, %d failed ====" % [total_tests, total_assertions, total_failures])
	for n in failed_names:
		print("FAILED: ", n)
	get_tree().quit(total_failures)
