extends Node
## Video memory budget of the UI. Every CanvasLayer owns a set of canvas item
## buffers sized by rendering/gl_compatibility/item_buffer_size; at the engine
## default (16384) that is about 6 MB per layer even when the layer is empty, and
## the game's many layers cost over 100 MB on a phone - enough to get a tab
## killed. The setting stays small (extra buffers are allocated only by a layer
## that really draws that many items).
##   godot --headless --path . res://tests/integration/render_budget_test.tscn
var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	var size := int(ProjectSettings.get_setting("rendering/gl_compatibility/item_buffer_size", 16384))
	check(size <= 4096, "canvas item buffers stay small (%d items per buffer)" % size)
	check(size >= 1024, "canvas item buffers are not starved (%d items per buffer)" % size)
	check(String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")) == "gl_compatibility", "the web build uses the compatibility renderer")
	# The web build has no threads: past this many instances Godot 4.3 splits the cull
	# into thread jobs and most of the scene drops out (the grey village with many
	# players around). The web build must always cull on the main thread.
	var web_cull := int(ProjectSettings.get_setting("rendering/limits/spatial_indexer/threaded_cull_minimum_instances.web", 0))
	check(web_cull >= 100000, "the web build never splits the scene cull into threads (threshold %d)" % web_cull)
	print("RENDER BUDGET: ", "PASS" if failures == 0 else "FAIL", " | ", checks, " checks, ", failures, " failures")
	get_tree().quit(failures)
