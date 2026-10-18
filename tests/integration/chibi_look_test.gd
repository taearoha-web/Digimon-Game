extends Node3D
## Hero looks (ChibiLook): six styles on the two chibi bodies, colour parts and
## accessories; old saves keep their exact look.
##   godot --headless --path . res://tests/integration/chibi_look_test.tscn
var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _body_material(v: HeroVisual) -> ShaderMaterial:
	for node in v.model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.skin != null and mi.material_override is ShaderMaterial:
			return mi.material_override
	return null


func _accessory(v: HeroVisual) -> Node:
	return v.model.find_child("ChibiLook", true, false)


func _ready() -> void:
	await get_tree().process_frame
	# Masks exist for both bodies and mark hair, scalp and eyes.
	for g in 2:
		var img := (load(ChibiLook.MASKS[g]) as Texture2D).get_image()
		var hair := 0
		var head := 0
		var eye := 0
		for y in range(0, img.get_height(), 4):
			for x in range(0, img.get_width(), 4):
				var c := img.get_pixel(x, y)
				if c.r > 0.75: hair += 1
				elif c.r > 0.3: head += 1
				if c.g > 0.3: eye += 1
		check(hair > 300 and head > 100 and eye > 5, "mask %d marks hair %d, head %d, eyes %d" % [g, hair, head, eye])

	# Three styles per body, the first the original texture.
	for g in 2:
		check((ChibiLook.STYLES[g] as Array).size() == 3, "three styles for body %d" % g)
		var look := FaceKit.default_look()
		look["gender"] = g
		ChibiLook.apply_style(look, 0)
		check(int(look.skin_tone) == 0 and int(look.hair_tint) == 0 and int(look.eye_tint) == 0 and int(look.acc) == 0, "style 0 of body %d is the original" % g)
		for s in range(1, 3):
			ChibiLook.apply_style(look, s)
			check(int(look.style) == s and int(look.hair_tint) > 0 and int(look.eye_tint) > 0, "style %d of body %d recolours hair and eyes" % [s, g])
			for key in ChibiLook.KEYS:
				check(int(look[key]) >= 0 and int(look[key]) < ChibiLook.count(key), "style %d/%d %s in range" % [g, s, key])
	var silver := FaceKit.default_look()
	ChibiLook.apply_style(silver, 1)
	check(ChibiLook.value_name("hair_tint", int(silver.hair_tint)) == "เงิน" and int(silver.acc) == 0, "the silver-haired boy wears no accessory")

	# Old saves: no look keys -> the original body, nothing else changes.
	var old := {"gender": 1, "skin": 3, "hair": 2, "hair_color": 4, "eyes": 1, "eye_color": 2, "nose": 0, "mouth": 1, "outfit": 0}
	var repaired := FaceKit.repair(old)
	check(int(repaired.style) == 0 and int(repaired.skin_tone) == 0 and int(repaired.hair_tint) == 0 and int(repaired.eye_tint) == 0 and int(repaired.acc) == 0, "an old look repairs to the original body")
	check(int(repaired.skin) == 3 and int(repaired.hair) == 2, "old keys are kept")
	var wild := FaceKit.repair({"gender": 0, "skin_tone": 99, "hair_tint": -7, "eye_tint": 2.0, "acc": 40, "style": -3})
	check(int(wild.skin_tone) == ChibiLook.count("skin_tone") - 1 and int(wild.hair_tint) == 0 and int(wild.eye_tint) == 2 and int(wild.acc) == ChibiLook.count("acc") - 1 and int(wild.style) == 0, "out-of-range values are clamped")
	# Every value a player can pick passes the save validator (no negative numbers).
	var every := FaceKit.default_look()
	for key in ChibiLook.KEYS:
		every[key] = ChibiLook.count(key) - 1
	Game.new_profile(&"vagabond", "ค่าสูงสุด", every)
	check(not Game.preview_import(Game.export_code()).is_empty(), "the highest look values pass the save validator")
	Game.new_profile(&"vagabond", "ค่าเดิม", FaceKit.default_look())
	check(Game.save_code_roundtrip(), "the original look round-trips through the save code")

	# Save round trip through the export code keeps the look.
	var styled := FaceKit.default_look()
	styled["gender"] = 1
	ChibiLook.apply_style(styled, 2)
	styled["eye_tint"] = 1
	Game.new_profile(&"vagabond", "ทดสอบลุค", styled)
	var code := Game.export_code()
	Game.new_profile(&"vagabond", "อื่น", FaceKit.default_look())
	check(Game.import_code(code), "the save code imports")
	var back: Dictionary = Game.profile.get("look", {})
	for key in ["gender", "style", "skin_tone", "hair_tint", "eye_tint", "acc"]:
		check(int(back.get(key, -99)) == int(styled[key]), "look key %s survives the save code" % key)

	# The body material: original look sets nothing, a style sets the uniforms.
	var plain := HeroVisual.new()
	add_child(plain)
	plain.setup(ClassData.START, "", false, {}, FaceKit.default_look())
	var plain_mat := _body_material(plain)
	check(plain_mat != null and plain_mat.get_shader_parameter("look_enabled") != true, "the original look leaves the shader off")
	check(_accessory(plain) == null, "the original look has no accessory")
	for g in 2:
		for s in range(1, 3):
			var look := FaceKit.default_look()
			look["gender"] = g
			ChibiLook.apply_style(look, s)
			var v := HeroVisual.new()
			add_child(v)
			v.setup(ClassData.START, "", false, {}, look)
			var mat := _body_material(v)
			check(mat != null and mat.get_shader_parameter("look_enabled") == true and mat.get_shader_parameter("look_mask") != null, "style %d/%d turns the look shader on" % [g, s])
			check(float(mat.get_shader_parameter("hair_amount")) == 1.0 and (mat.get_shader_parameter("hair_color") as Color).is_equal_approx(ChibiLook.tint("hair_tint", int(look.hair_tint))), "style %d/%d hair colour" % [g, s])
			check((_accessory(v) != null) == (int(look.acc) > 0), "style %d/%d accessory present only when chosen" % [g, s])
			# Gear changes keep the look.
			v.equip = {"armor": ItemData.generate(20, ClassData.START, Game.rng, 2, "armor")}
			v.refresh()
			var after := _body_material(v)
			check(after != null and after.get_shader_parameter("look_enabled") == true, "style %d/%d survives an armour change" % [g, s])
			v.queue_free()
	# Every accessory builds on both bodies.
	for g in 2:
		for acc in range(1, ChibiLook.count("acc")):
			var look := FaceKit.default_look()
			look["gender"] = g
			look["acc"] = acc
			var v := HeroVisual.new()
			add_child(v)
			v.setup(ClassData.START, "", false, {}, look)
			var node := _accessory(v)
			check(node != null and node.find_children("*", "MeshInstance3D", true, false).size() >= 1, "accessory %d builds on body %d" % [acc, g])
			v.queue_free()

	# Rivals: random looks pick a style without drawing extra random numbers.
	var a := RandomNumberGenerator.new()
	a.seed = 77
	var b := RandomNumberGenerator.new()
	b.seed = 77
	var styles := {}
	for i in 30:
		var look := FaceKit.random_look(a)
		styles[int(look.style)] = true
		for key in ["skin", "hair", "hair_color", "eyes", "eye_color", "nose", "mouth", "outfit"]:
			b.randi()
		b.randi()
	check(a.randi() == b.randi(), "random_look draws the same numbers as before")
	check(styles.size() == 3, "rivals wear all three styles")

	# The creator: style buttons and part rows.
	var screen := ClassSelect.new()
	add_child(screen)
	await get_tree().process_frame
	check(screen._style_buttons.size() == 3, "the creator shows three style buttons")
	screen._set_gender(1)
	screen._set_style(1)
	check(screen._style_buttons[1].disabled and screen._style_buttons[1].text == ChibiLook.style_name(1, 1), "the chosen style is marked")
	var before := int(screen.look.hair_tint)
	screen._step("hair_tint", 1)
	check(int(screen.look.hair_tint) == (before + 1) % ChibiLook.count("hair_tint"), "hair colour steps")
	screen.look["hair_tint"] = ChibiLook.count("hair_tint") - 1
	screen._step("hair_tint", 1)
	check(int(screen.look.hair_tint) == 0, "hair colour wraps to the original")
	screen._step("acc", -1)
	screen._step("acc", -1)
	check(int(screen.look.acc) >= 0 and int(screen.look.acc) < ChibiLook.count("acc"), "accessory stays in range")
	for i in 8:
		screen._randomize()
		check(FaceKit.repair(screen.look) == screen.look, "a random look is already valid")
	screen.queue_free()

	print("chibi_look_test: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
