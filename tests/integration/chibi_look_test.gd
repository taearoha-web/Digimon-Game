extends Node3D
## Hero looks: a hero's look is {gender, body} (ChibiBodies: four characters per
## gender); old saves' and old clients' style, hair / eye / skin colours and accessory
## are dropped and never rendered. Rivals keep the original body in one of its three
## ready-made colourings (ChibiLook styles); world players wear the character body each
## picked (the roster's "body", any of its gender's ChibiBodies), the original one in a colouring.
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
		var p0 := ChibiLook.paint({"gender": g, "style": 0})
		check(int(p0.skin_tone) == 0 and int(p0.hair_tint) == 0 and int(p0.eye_tint) == 0 and int(p0.acc) == 0, "style 0 of body %d is the original" % g)
		for s in range(1, 3):
			var look := {"gender": g}
			ChibiLook.apply_style(look, s)
			var p := ChibiLook.paint(look)
			check(int(look.style) == s and int(p.hair_tint) > 0 and int(p.eye_tint) > 0, "style %d of body %d recolours hair and eyes" % [s, g])

	# A hero's look is only its gender and character body.
	check(FaceKit.hero_look({}) == {"gender": 0, "body": 0}, "a new hero has the default look")
	var custom := {"gender": 1, "style": 2, "skin": 3, "hair": 2, "hair_color": 4, "eyes": 1, "eye_color": 2, "outfit": 3,
		"skin_tone": 5, "hair_tint": 7, "eye_tint": 1, "acc": 3}
	check(FaceKit.hero_look(custom) == {"gender": 1, "body": 0}, "an old style, custom colours, hair, eyes and accessory are dropped: the original body")
	check(ChibiLook.paint(FaceKit.hero_look(custom)) == ChibiLook.paint({"gender": 1, "style": 0}), "an old save's style shows the original body's own look")
	var wild := FaceKit.hero_look({"gender": 9, "body": -3, "hair_tint": "x"})
	check(wild == {"gender": 1, "body": 0}, "out-of-range values are clamped (%s)" % wild)
	check(FaceKit.hero_look({"gender": 1, "body": 99}) == {"gender": 1, "body": 0}, "an unknown body (a newer game's) is the original")
	check(FaceKit.hero_look({"gender": 1, "body": 3}) == {"gender": 1, "body": 3}, "a known body is kept")
	check(FaceKit.hero_look({"gender": "girl", "body": INF}) == {"gender": 0, "body": 0}, "non-numbers fall back")
	check(FaceKit.hero_look(null) == {"gender": 0, "body": 0}, "a missing look is the default")
	check(not "hair_tint" in FaceKit.default_look() and not "acc" in FaceKit.repair({"acc": 2}), "FaceKit looks carry no colour keys")

	# A new hero created with an old-style look keeps only its body and character.
	Game.new_profile(&"warrior", "ลุคเก่า", custom)
	check(Game.profile.look == {"gender": 1, "body": 0}, "new_profile keeps only gender and body (%s)" % Game.profile.look)
	Game.new_profile(&"warrior", "ค่าเดิม", FaceKit.default_look())
	check(Game.profile.look == {"gender": 0, "body": 0}, "a default new hero has the default look")
	check(Game.save_code_roundtrip(), "the default look round-trips through the save code")

	# An old save with custom colours loads, renders its character's look, saves without them.
	Game.new_profile(&"warrior", "ทดสอบลุค", FaceKit.default_look())
	Game.profile["look"] = custom.duplicate()
	var code := Game.export_code()
	Game.new_profile(&"warrior", "อื่น", FaceKit.default_look())
	check(Game.import_code(code), "an old save with custom colours imports")
	var back: Dictionary = Game.profile.get("look", {})
	check(back == {"gender": 1, "body": 0}, "the loaded look is stripped to gender and body (%s)" % back)
	var again := Game.export_code()
	Game.new_profile(&"warrior", "อื่นอีก", FaceKit.default_look())
	check(Game.import_code(again) and not Game.profile.look.has("hair_tint") and not Game.profile.look.has("acc"), "it saves without the old keys")
	check(not PlayerLook.of_profile(Game.profile).face.has("hair_tint"), "the online look sends no colours")

	# Remote looks: without and with old fields, the default of the character applies.
	check(PlayerLook.clean({"class": "mage"}).face == {"gender": 0, "body": 0}, "a remote look without a face is the default")
	check(PlayerLook.clean({"class": "mage", "face": custom}).face == {"gender": 1, "body": 0}, "a remote look's old colours are dropped")
	check(PlayerLook.clean({"class": "mage", "face": {"hair_tint": [1], "acc": {"x": 1}, "gender": "1"}}).face == {"gender": 0, "body": 0}, "a broken remote face does not crash and is the default")
	check(PlayerLook.clean({"class": "mage", "face": "oops"}).face == {"gender": 0, "body": 0}, "a non-dictionary remote face is the default")
	check(PlayerLook.clean({"class": "mage", "face": {"gender": 1, "body": 2}}).face == {"gender": 1, "body": 2}, "a remote player's character body comes through")
	check(PlayerLook.clean({"class": "mage", "face": {"gender": 0, "body": 7}}).face == {"gender": 0, "body": 0}, "a remote body this game does not know is the original")

	# The body material: original look sets nothing, a style sets the uniforms.
	var plain := HeroVisual.new()
	add_child(plain)
	plain.setup(ClassData.LEGACY, "", false, {}, FaceKit.default_look())
	var plain_mat := _body_material(plain)
	check(plain_mat != null and plain_mat.get_shader_parameter("look_enabled") != true, "the original look leaves the shader off")
	check(_accessory(plain) == null, "the original look has no accessory")
	# Hits landing while the last red flash still fades leave no tint behind (a half-faded
	# flash was kept as a lasting overlay: heroes stayed red until a map change).
	var piece := plain.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	for i in 4:
		plain.flash(Color(1, 0.35, 0.35), 0.2)
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(0.4).timeout
	check(piece.material_overlay == null, "no hit flash is left on after quick hits (%s)" % piece.material_overlay)
	var lasting := MeshKit.toon(Color.WHITE)
	piece.material_overlay = lasting
	for i in 3:
		plain.flash(Color(1, 0.35, 0.35), 0.2)
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(0.4).timeout
	check(piece.material_overlay == lasting, "a lasting overlay comes back after quick hits")
	piece.material_overlay = null
	for g in 2:
		for s in range(1, 3):
			var look := {"gender": g, "style": s}
			var p := ChibiLook.paint(look)
			var v := HeroVisual.new()
			add_child(v)
			v.setup(ClassData.LEGACY, "", false, {}, look)
			var mat := _body_material(v)
			check(mat != null and mat.get_shader_parameter("look_enabled") == true and mat.get_shader_parameter("look_mask") != null, "style %d/%d turns the look shader on" % [g, s])
			check(float(mat.get_shader_parameter("hair_amount")) == 1.0 and (mat.get_shader_parameter("hair_color") as Color).is_equal_approx(ChibiLook.tint("hair_tint", int(p.hair_tint))), "style %d/%d hair colour" % [g, s])
			check((_accessory(v) != null) == (int(p.acc) > 0), "style %d/%d accessory present only with its character" % [g, s])
			# Gear changes keep the look.
			v.equip = {"armor": ItemData.generate(20, ClassData.LEGACY, Game.rng, 2, "armor")}
			v.refresh()
			var after := _body_material(v)
			check(after != null and after.get_shader_parameter("look_enabled") == true, "style %d/%d survives an armour change" % [g, s])
			v.queue_free()
	# Old custom keys on a hero's look are not rendered: the original body stays plain.
	var old_look := HeroVisual.new()
	add_child(old_look)
	old_look.setup(ClassData.LEGACY, "", false, {}, {"gender": 0, "skin_tone": 5, "hair_tint": 7, "eye_tint": 1, "acc": 3})
	var old_mat := _body_material(old_look)
	check(old_mat != null and old_mat.get_shader_parameter("look_enabled") != true and _accessory(old_look) == null, "old hair / eye / skin colours and accessory are not rendered")
	old_look.queue_free()
	# The fairy guide (an NPC) keeps her own design.
	for g in 2:
		var npc := HeroVisual.new()
		add_child(npc)
		npc.setup(ClassData.LEGACY, "", false, {}, {"gender": g, ChibiLook.PAINT_KEY: {"hair_tint": 6, "eye_tint": 5, "skin_tone": 2, "acc": 2}})
		var npc_mat := _body_material(npc)
		check(npc_mat != null and npc_mat.get_shader_parameter("look_enabled") == true and _accessory(npc) != null, "an NPC paint renders on body %d" % g)
		npc.queue_free()

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

	# World players wear the character body each picked (WorldPlayers.ROSTER "body", any of
	# its gender's ChibiBodies; one without a "body" draws one from its name); the original
	# body comes in one of its three colourings, the others in their own texture.
	var world_styles := {}
	var world_bodies := [{}, {}]
	for i in mini(WorldPlayers.size(), 60):
		var wl := WorldPlayers.look(i)
		var e := WorldPlayers.entry(i)
		var g := int(wl.get("gender", -1))
		var body := int(wl.get("body", -1))
		check(g == int(e.gender) and body >= 0 and body < ChibiBodies.count(g) and (not e.has("body") or body == int(e.body)), "world player %d wears its own body (%d, roster %s)" % [i, body, str(e.get("body", "-"))])
		check(int(wl.get("style", -1)) >= 0 and int(wl.get("style", -1)) < ChibiLook.count("style"), "world player %d has a colouring" % i)
		if g < 0 or g > 1 or body < 0:
			continue
		world_bodies[g][body] = true
		if body == 0:
			world_styles[int(wl.get("style", 0))] = true
		else:
			check(ChibiLook.paint(wl) == {"skin_tone": 0, "hair_tint": 0, "eye_tint": 0, "acc": 0}, "world player %d on another body is not recoloured" % i)
	check((world_bodies[0] as Dictionary).size() == ChibiBodies.count(0) and (world_bodies[1] as Dictionary).size() == ChibiBodies.count(1), "world players wear every character of both genders (%s)" % [world_bodies])
	check(world_styles.size() == 3, "world players on the original body wear all three colourings (%s)" % [world_styles.keys()])
	# A colouring is for the original body only (its masks fit that texture).
	check(int(ChibiLook.paint({"gender": 0, "style": 1, "body": 2}).hair_tint) == 0, "another body is never recoloured")

	# The creator: gender buttons and the gender's four character cards; no colour /
	# hair / eye / skin / accessory controls and no random look.
	var screen := ClassSelect.new()
	add_child(screen)
	await get_tree().process_frame
	check(screen._body_cards.size() == 4, "the creator shows four character cards")
	check(screen._gender_buttons.size() == 2, "the creator shows the two genders")
	screen._set_gender(1)
	screen.set_body(1)
	check(screen._body_cards[1].disabled and screen._body_names[1].text == ChibiBodies.body_name(1, 1), "the chosen character is marked")
	check(screen.look == {"gender": 1, "body": 1}, "the creator's look is gender and character only (%s)" % screen.look)
	var texts: PackedStringArray = []
	for node in screen.find_children("*", "", true, false):
		if node is Button or node is Label:
			texts.append(String(node.text))
	var joined := " | ".join(texts)
	for banned in ["สีผม", "สีผิว", "สีตา", "ประดับ", "ทรงผม", "สุ่มลุค", "ปรับสี", "◀", "▶"]:
		check(not banned in joined, "the creator has no %s control" % banned)
	for method in ["_randomize", "_step", "_option_row", "_value_text"]:
		check(not screen.has_method(method), "the creator has no %s" % method)
	var got := []
	screen.confirmed.connect(func(c, n, l): got.append(l))
	screen._on_confirm()
	check(got.size() == 1 and got[0] == {"gender": 1, "body": 1}, "the creator confirms gender and character only (%s)" % [got])
	screen.queue_free()

	print("chibi_look_test: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
