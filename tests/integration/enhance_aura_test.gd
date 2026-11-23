extends Node
## Enhancing to +15 and its looks: the forge goes to ItemData.MAX_PLUS (15) with harder
## steps from +10, purple, pink and chaos jewels (ENHANCE_HIGH). Nothing shows below +7;
## every outfit piece glows by its own + in its own colour from +7 (clearer at +9 and
## +10); the body effects (orbs +10, lightning +11, two colours +13, the aura +15, in
## the armour's colour) come only from the whole set's lowest + (weapon, armour, helm,
## boots; wings are not counted).
##   godot --headless --path . res://tests/integration/enhance_aura_test.tscn

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _gear(plus_by_slot: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var equip := {}
	for slot in ["weapon", "armor", "helm", "boots"]:
		equip[slot] = ItemData.generate(30, &"warrior", rng, 1, slot)
	equip["wings"] = ItemData.wings(rng, "warrior", 2)
	for slot in plus_by_slot:
		if plus_by_slot[slot] == null:
			equip.erase(slot)
		else:
			equip[slot]["plus"] = int(plus_by_slot[slot])
	return equip


func _full_set(plus: int) -> Dictionary:
	return _gear({"weapon": plus, "armor": plus, "helm": plus, "boots": plus})


func _hero(equip: Dictionary, light := false) -> HeroVisual:
	var h := HeroVisual.new()
	h.decor_light = light
	add_child(h)
	h.setup(&"warrior", "", true, equip, FaceKit.default_look())
	return h


func _glowing(h: HeroVisual) -> int:
	var n := 0
	for mi in h.find_children("*", "MeshInstance3D", true, false):
		var ov := (mi as MeshInstance3D).material_overlay
		if ov is ShaderMaterial and (ov as ShaderMaterial).shader == EnhanceFx.GLOW_SHADER:
			n += 1
	return n


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()

	check(ItemData.MAX_PLUS == 15, "the forge goes to +15")
	# Odds and cost: +10 .. +15 take a purple, a pink and a chaos jewel each (one more
	# of each every step) at 50%, 45%, 40%, 35%, 30% and 25%.
	var odds := [0.5, 0.45, 0.4, 0.35, 0.3, 0.25]
	for plus in range(9, 15):
		var n := plus - 8
		check(is_equal_approx(ItemData.enhance_chance(plus), odds[plus - 9]), "+%d at %d%%" % [plus + 1, int(round(ItemData.enhance_chance(plus) * 100.0))])
		check(ItemData.enhance_cost({"plus": plus}) == {"purple": n, "pink": n, "chaos": n}, "+%d costs %d of each jewel (%s)" % [plus + 1, n, ItemData.jewel_cost_text(ItemData.enhance_cost({"plus": plus}))])
	check(ItemData.jewel_cost_text(ItemData.enhance_cost({"plus": 9})).contains("เพชรชาออส 1"), "the cost text names the chaos jewel")
	check(ItemData.enhance_cost({"plus": 8}) == {"purple": 0, "pink": 1} and is_equal_approx(ItemData.enhance_chance(8), 0.5), "+9 unchanged")

	Game.new_profile(&"warrior", "ตีบวกQA", FaceKit.default_look())
	Game.profile.inv.append({"kind": "jewel", "id": "purple", "count": 999})
	Game.profile.inv.append({"kind": "jewel", "id": "pink", "count": 999})
	Game.profile.inv.append({"kind": "jewel", "id": "chaos", "count": 999})
	var sword: Dictionary = _gear({}).weapon
	sword["plus"] = 10
	var tries := 0
	while int(sword.plus) < 15 and tries < 400:
		Game.enhance_item(sword)
		tries += 1
	check(int(sword.plus) == 15, "the forge reaches +15 (%d tries)" % tries)
	check(Game.enhance_item(sword) == "บวกสูงสุดแล้ว", "and no further")

	# The steps and their names.
	check(EnhanceFx.aura_step(6) == 0 and EnhanceFx.aura_step(7) == 1 and EnhanceFx.aura_step(8) == 1 and EnhanceFx.aura_step(9) == 2
		and EnhanceFx.aura_step(10) == 3 and EnhanceFx.aura_step(15) == 8, "eight look steps at +7 +9 +10 .. +15 (+8 looks like +7)")
	var names := {}
	for p in EnhanceFx.AURA_STEPS:
		names[EnhanceFx.look_name(p)] = true
	check(names.size() == 8 and not names.has(""), "each step has its own name")
	check(EnhanceFx.look_name(6) == "" and EnhanceFx.look_name(6, "weapon") == "" and EnhanceFx.look_name(6, "armor") == "", "nothing shows below +7")
	check(EnhanceFx.look_name(10) == "ดวงวิญญาณ" and EnhanceFx.look_name(13) == "อัสนีคู่สี" and EnhanceFx.look_name(15) == "ออร่าเทพ", "the set's looks are named for what they show")
	check(EnhanceFx.look_name(7, "helm") == "เรืองแสงจาง" and EnhanceFx.look_name(9, "boots") == "เรืองแสง" and EnhanceFx.look_name(12, "armor") == "เรืองแสงชัด", "a piece glows faintly at +7, clearer at +9 and +10")
	check(EnhanceFx.glow_strength(6) == 0.0 and EnhanceFx.glow_strength(7) == EnhanceFx.glow_strength(8) and EnhanceFx.glow_strength(9) > EnhanceFx.glow_strength(8)
		and EnhanceFx.glow_strength(10) > EnhanceFx.glow_strength(9), "the glow: none, faint, clearer, clearer still")
	var tip := "\n".join(ItemData.detail_lines(_gear({"armor": 12}).armor))
	check(tip.contains("เรืองแสงชัด") and tip.contains("อัสนีพันสาย"), "the tooltip names the piece's glow and the set's look at its + (%s)" % tip)
	var low_tip := "\n".join(ItemData.detail_lines(_gear({"helm": 5}).helm))
	check(low_tip.contains("ตั้งแต่ +7"), "below +7 the tooltip says the glow starts at +7")
	var old_names := ["ปีกแสงเทพ", "มังกรหยกวิญญาณ", "ตำนานสุริยะรุ้ง", "จักรวาลดารา", "เพลิงแดงขีดสุด", "ทองลุกโชน", "ชีพจรคราม", "อัสนีอเมทิสต์", "เปลวเพลิงโอบอาวุธ"]
	for path in ["res://characters/enhance_fx.gd", "res://data/item_data.gd", "res://ui/game_menu.gd", "res://systems/core/chat_brain.gd", "res://tests/tools/aura_sheets.gd"]:
		var text := FileAccess.get_file_as_string(path)
		for old in old_names:
			check(not text.contains(old), "%s no longer names the old look %s" % [path.get_file(), old])
	# The whole set decides the body effects: its lowest +, a missing piece counts +0.
	check(EnhanceFx.set_plus(_gear({"weapon": 15, "armor": 12, "helm": 12, "boots": 11, "wings": 3})) == 11, "the set's lowest + (11), wings not counted")
	check(EnhanceFx.set_plus(_gear({"weapon": 15, "armor": 15, "helm": 15, "boots": 15, "wings": null})) == 15, "no wings needed for the aura")
	check(EnhanceFx.set_plus(_gear({"weapon": 15, "armor": 15, "helm": null, "boots": 15})) == 0, "a missing helm counts +0")
	check(EnhanceFx.set_plus(_gear({"weapon": 15, "armor": 0})) == 0, "one piece at +15 alone gives no aura")
	# The +13 sparks' second colour is the outfit's complement.
	var green := EnhanceFx.glow_tone(Color("2f7a55"))
	check(absf(fposmod(EnhanceFx.contrast_of(green).h - green.h, 1.0) - 0.5) < 0.02, "the contrast colour is the complement")

	# Built on a hero: nothing on the body below +10; the orbs from +10, the sparks from
	# +11 (two colours from +13), the aura at +15, all in the armour's colour; every
	# piece glows by itself from +7.
	GameSettings.quality = 2
	for case in [[_gear({"weapon": 15}), 0, 0], [_full_set(6), 6, 6], [_full_set(9), 9, 9], [_full_set(10), 10, 10], [_full_set(11), 11, 11], [_full_set(13), 13, 13], [_full_set(15), 15, 15],
			[_gear({"weapon": 15, "armor": 15, "helm": 15, "boots": 12}), 12, 15]]:
		var equip: Dictionary = case[0]
		var whole: int = case[1]
		var h := _hero(equip)
		await get_tree().process_frame
		var aura := h.find_child("SetAura", true, false)
		check((aura != null) == (whole >= 10), "set +%d -> body effects %s" % [whole, whole >= 10])
		check((h.find_child("Orbs", true, false) != null) == (whole >= 10), "set +%d: orbs from +10" % whole)
		var bolts := h.find_child("Lightning", true, false) as MeshInstance3D
		check((bolts != null) == (whole >= 11), "set +%d: lightning from +11" % whole)
		check((h.find_child("GodAura", true, false) != null) == (whole >= 15), "set +%d: the aura at +15" % whole)
		if bolts != null:
			var mat := bolts.material_override as ShaderMaterial
			var a: Color = mat.get_shader_parameter("color_a")
			var b: Color = mat.get_shader_parameter("color_b")
			check(a.is_equal_approx(b) == (whole < 13), "set +%d: one spark colour below +13, two from +13" % whole)
		if aura != null:
			var orbs := h.find_child("Orbs", true, false) as MeshInstance3D
			var c: Color = (orbs.material_override as ShaderMaterial).get_shader_parameter("color")
			var cloth := EnhanceFx.glow_tone(HeroVisual._armor_cloth(h.equip.armor))
			var dh := absf(c.h - cloth.h)
			check(dh < 0.05 or dh > 0.95, "set +%d: the orbs wear the armour's colour" % whole)
			check(aura.find_children("*", "CPUParticles3D", true, false).is_empty(), "set +%d: no particles in the body effects" % whole)
			for mi in aura.find_children("*", "MeshInstance3D", true, false):
				check(not (mi in h._lod_meshes), "set +%d: %s is never flashed or shadowed with the outfit" % [whole, mi.name])
		# None of the old dressing: rings, halos, wings, dragon, sun, crown, cape of light, sparkles.
		for old in ["Dragon", "Spiral", "LightCape", "PieceSparkles", "PieceGlow"]:
			check(h.find_child(old, true, false) == null, "set +%d: no %s" % [whole, old])
		var piece_plus := int(case[2])
		check((_glowing(h) > 0) == (piece_plus >= 7), "set +%d: pieces glow only from +7 (%d glowing meshes)" % [whole, _glowing(h)])
		h.queue_free()
		await get_tree().process_frame
	# The crowd's light dress: no particles, fewer sparks, no forks.
	var crowd := _hero(_full_set(15), true)
	await get_tree().process_frame
	var crowd_bolts := crowd.find_child("Lightning", true, false) as MeshInstance3D
	check(crowd_bolts != null and float((crowd_bolts.material_override as ShaderMaterial).get_shader_parameter("density")) < 0.5
		and float((crowd_bolts.material_override as ShaderMaterial).get_shader_parameter("forks")) == 0.0, "the crowd's +15 wears fewer sparks, no forks")
	var crowd_aura := crowd.find_child("SetAura", true, false)
	check(crowd_aura != null and crowd_aura.find_children("*", "CPUParticles3D", true, false).is_empty(), "the crowd's body effects carry no particles")
	crowd.queue_free()
	# The lowest quality: the pieces' glow only.
	GameSettings.quality = 0
	var low := _hero(_full_set(15))
	await get_tree().process_frame
	check(low.find_child("SetAura", true, false) == null, "the lowest quality: no body effects")
	check(_glowing(low) > 0, "the lowest quality: the pieces still glow")
	low.queue_free()
	GameSettings.quality = 2
	await get_tree().process_frame
	# Shared and pooled: two heroes in the same look share the meshes and materials.
	var one := _hero(_full_set(14))
	var two := _hero(_full_set(14))
	await get_tree().process_frame
	var o1 := one.find_child("Orbs", true, false) as MeshInstance3D
	var o2 := two.find_child("Orbs", true, false) as MeshInstance3D
	check(o1 != null and o2 != null and o1.mesh == o2.mesh and o1.material_override == o2.material_override, "the orbs' mesh and material are shared")
	var l1 := one.find_child("Lightning", true, false) as MeshInstance3D
	var l2 := two.find_child("Lightning", true, false) as MeshInstance3D
	check(l1 != null and l2 != null and l1.mesh == l2.mesh, "the lightning mesh is shared")
	one.queue_free()
	two.queue_free()
	await get_tree().process_frame
	# Jewels and feathers fly to the hero from anywhere in the field.
	var src := FileAccess.get_file_as_string("res://world/loot_drop.gd")
	check(src.contains("func _lift_off") and src.contains("_magnet = true") and not src.contains("PICKUP_RADIUS"), "jewel and feather drops (every drop) fly to the hero from anywhere")
	print("ENHANCE AURA: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
