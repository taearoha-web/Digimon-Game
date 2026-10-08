extends SceneTree
## Headless visual-assembly regressions:
## godot --headless --path . -s tests/integration/character_finish_test.gd

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _run() -> void:
	GameSettings.quality = 1
	for gender in 2:
		for style in FaceKit.option_count("hair", gender):
			var look := FaceKit.default_look()
			look.gender = gender
			look.hair = style
			look.skin = style % FaceKit.SKINS.size()
			var head := FaceKit.build_head(look) as FaceExpression
			_check(head != null and head.eyes.size() == 2, "Custom heads retain two animated eyes")
			var hair := head.get_node("Hair")
			_check(hair.get_child_count() <= 4, "Hair uses a bounded number of material batches")
			head.phase = 0.08
			head._process(0.0)
			_check(head.eyes[0].scale.y < 0.1, "Blink closes both eyes without changing the head bone")
			head.phase = 1.0
			head._process(0.0)
			_check(is_equal_approx(head.eyes[0].scale.y, 1.0), "Eyes reopen after blinking")
			head.free()
	for eye_style in FaceKit.option_count("eyes", 0):
		var look := FaceKit.default_look()
		look.eyes = eye_style
		var head := FaceKit.build_head(look) as FaceExpression
		_check(head.eyes.size() == (0 if eye_style == 3 else 2), "Happy closed eyes stay closed; open styles retain blinking")
		head.free()
	var lock_arrays := FaceKit._hair_lock().surface_get_arrays(0)
	var normals: PackedVector3Array = lock_arrays[Mesh.ARRAY_NORMAL]
	_check(normals[0].x > 0.0, "Hair lock normals face outward rather than showing the dark outline interior")
	var cache_size := 0
	for i in 8:
		var visual := MonsterVisual.new()
		root.add_child(visual)
		visual.setup("blob/GreenBlob", 1.2)
		if i == 0:
			cache_size = StorybookFinish._materials.size()
		else:
			_check(StorybookFinish._materials.size() == cache_size, "Reloading the same creature reuses material resources")
		visual.free()
		await process_frame
	var tint := StorybookFinish.balanced_tint(Color(2.4, 1.0, 0.6))
	_check(tint.r <= 1.22001 and is_equal_approx(tint.r / tint.g, 2.4), "Bright variants retain their hue without clipping")
	for i in StorybookFinish.CACHE_LIMIT + 12:
		var source := StandardMaterial3D.new()
		source.albedo_color = Color(float(i) / 400.0, 0.5, 0.5)
		StorybookFinish.material(source)
	_check(StorybookFinish._materials.size() <= StorybookFinish.CACHE_LIMIT, "Generated materials obey the cache bound")
	print("Character finish checks: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)
