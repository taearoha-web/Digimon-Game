extends Node
## Enhancing to +15 and the set aura: the forge goes to ItemData.MAX_PLUS (15) with
## harder steps from +10, purple, pink and chaos jewels (ENHANCE_HIGH); every piece glows by its own +, and the body
## aura (nine steps, EnhanceFx.AURA_STEPS) comes only from the whole set's lowest +
## (weapon, armour, helm, boots; wings are not counted).
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


func _ready() -> void:
	Game.set_process(false)

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

	check(EnhanceFx.aura_step(4) == 0 and EnhanceFx.aura_step(5) == 1 and EnhanceFx.aura_step(6) == 1 and EnhanceFx.aura_step(7) == 2 and EnhanceFx.aura_step(10) == 4 and EnhanceFx.aura_step(15) == 9, "nine aura steps at +5 +7 +9 +10 .. +15")
	var names := {}
	for p in EnhanceFx.AURA_STEPS:
		names[EnhanceFx.look_name(p)] = true
	check(names.size() == 9, "each step has its own name")
	# The whole set decides the aura: its lowest +, a missing piece counts +0.
	check(EnhanceFx.set_plus(_gear({"weapon": 15, "armor": 12, "helm": 12, "boots": 11, "wings": 3})) == 11, "the set's lowest + (11), wings not counted")
	check(EnhanceFx.set_plus(_gear({"weapon": 15, "armor": 15, "helm": 15, "boots": 15, "wings": null})) == 15, "no wings needed for the aura")
	check(EnhanceFx.set_plus(_gear({"weapon": 15, "armor": 15, "helm": null, "boots": 15})) == 0, "a missing helm counts +0")
	check(EnhanceFx.set_plus(_gear({"weapon": 15, "armor": 0})) == 0, "one piece at +15 alone gives no aura")

	# Built on a hero: SetAura only with a full set at +5 or more; pieces glow on their own.
	for case in [[{"weapon": 15}, false], [{"weapon": 5, "armor": 5, "helm": 5, "boots": 5}, true],
			[{"weapon": 12, "armor": 12, "helm": 12, "boots": 12}, true], [{"weapon": 15, "armor": 15, "helm": 15, "boots": 15}, true]]:
		var h := HeroVisual.new()
		add_child(h)
		h.setup(&"warrior", "", true, _gear(case[0]), FaceKit.default_look())
		await get_tree().process_frame
		var aura := h.find_child("SetAura", true, false)
		check((aura != null) == bool(case[1]), "set %s -> aura %s" % [case[0], case[1]])
		if case[0].size() == 4 and int(case[0].weapon) == 12:
			check(aura != null and aura.get_child_count() > 0, "+12 builds its wings")
		if case[0].size() == 4 and int(case[0].weapon) == 15:
			check(aura != null and aura.get_child_count() >= 6, "+15 builds its sun, wings, crown and rings")
		h.queue_free()
		await get_tree().process_frame
	# The Dark Lord wears a cape, not wings: from +12 his light comes as a cape of light.
	for plus in [12, 13, 14, 15]:
		var lord := HeroVisual.new()
		add_child(lord)
		lord.setup(&"darklord", "", true, _gear({"weapon": plus, "armor": plus, "helm": plus, "boots": plus}), FaceKit.default_look())
		await get_tree().process_frame
		var aura := lord.find_child("SetAura", true, false)
		check(aura != null and aura.find_child("LightCape", true, false) != null, "Dark Lord +%d: a cape of light" % plus)
		lord.queue_free()
		var knight := HeroVisual.new()
		add_child(knight)
		knight.setup(&"warrior", "", true, _gear({"weapon": plus, "armor": plus, "helm": plus, "boots": plus}), FaceKit.default_look())
		await get_tree().process_frame
		var light := knight.find_child("SetAura", true, false)
		check(light != null and light.find_child("LightCape", true, false) == null, "warrior +%d: wings of light, no cape" % plus)
		knight.queue_free()
		await get_tree().process_frame
	# Jewels and feathers fly to the hero from anywhere in the field.
	var src := FileAccess.get_file_as_string("res://world/loot_drop.gd")
	check(src.contains("func _lift_off") and src.contains("_magnet = true") and not src.contains("PICKUP_RADIUS"), "jewel and feather drops (every drop) fly to the hero from anywhere")
	print("ENHANCE AURA: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
