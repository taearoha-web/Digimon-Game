extends TestCase


func test_inventory_add_remove_stack() -> void:
	var inv := Inventory.new()
	check_eq(inv.add_item(&"small_patch", 3), 3, "add")
	check_eq(inv.count(&"small_patch"), 3, "count")
	check(inv.remove_item(&"small_patch", 2), "remove")
	check_eq(inv.count(&"small_patch"), 1, "after remove")
	check(not inv.remove_item(&"small_patch", 5), "cannot remove more than owned")
	var cap := GameData.get_item(&"gate_pass").max_stack
	inv.add_item(&"gate_pass", 10)
	check_eq(inv.count(&"gate_pass"), cap, "stack cap respected")
	check_eq(inv.add_item(&"not_an_item", 1), 0, "unknown items rejected")
	var consumables := inv.get_entries(ItemData.Category.CONSUMABLE)
	check_eq(consumables.size(), 1, "category filter")
	var copy := Inventory.new()
	copy.load_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	check_eq(copy.count(&"small_patch"), 1, "serialization")


func test_item_service_effects() -> void:
	var inv := Inventory.new()
	inv.add_item(&"small_patch", 2)
	inv.add_item(&"reboot_chip", 1)
	inv.add_item(&"sp_capsule", 1)
	var inst := DigimonInstance.create(&"agumon", 5)
	var r := ItemService.use_item(&"small_patch", inst, inv)
	check(not r.ok, "cannot heal full HP")
	check_eq(inv.count(&"small_patch"), 2, "not consumed on failure")
	inst.take_damage(50)
	r = ItemService.use_item(&"small_patch", inst, inv)
	check(r.ok and int(r.hp_restored) == 40, "heals 40")
	inst.take_damage(9999)
	check(ItemService.get_block_reason(GameData.get_item(&"small_patch"), inst, false) != "", "cannot heal fainted")
	r = ItemService.use_item(&"reboot_chip", inst, inv)
	check(r.ok and not inst.is_fainted(), "revived")
	inst.current_sp = 0
	r = ItemService.use_item(&"sp_capsule", inst, inv)
	check(r.ok and inst.current_sp > 0, "sp restored")
	check(ItemService.get_block_reason(GameData.get_item(&"friend_treat"), inst, false) != "", "treat is battle-only")


func test_roster_party_rules() -> void:
	var roster := DigimonRoster.new()
	var a := DigimonInstance.create(&"agumon", 5)
	var b := DigimonInstance.create(&"palmon", 4)
	var c := DigimonInstance.create(&"kunemon", 3)
	var d := DigimonInstance.create(&"biyomon", 4)
	check_eq(roster.add_digimon(a), &"party", "a party")
	check_eq(roster.add_digimon(b), &"party", "b party")
	check_eq(roster.add_digimon(c), &"party", "c party")
	check_eq(roster.add_digimon(d), &"storage", "d storage (party max 3)")
	check_eq(roster.get_lead(), a, "starter is lead")
	check(roster.move_party_member(2, 0), "reorder")
	check_eq(roster.get_lead(), c, "new lead")
	check(roster.swap_with_storage(b.uid, d.uid), "swap with storage")
	check(roster.is_in_party(d.uid) and not roster.is_in_party(b.uid), "swapped")
	check(roster.remove_from_party(c.uid), "remove")
	check(roster.remove_from_party(a.uid), "remove again")
	check(not roster.remove_from_party(d.uid), "party keeps at least one")
	var copy := DigimonRoster.new()
	copy.load_dict(JSON.parse_string(JSON.stringify(roster.to_dict())))
	check_eq(copy.size(), 4, "all owned restored")
	check_eq(copy.party.size(), roster.party.size(), "party restored")
	check_eq(copy.get_lead().uid, roster.get_lead().uid, "lead restored")


func test_roster_capacity() -> void:
	var roster := DigimonRoster.new()
	roster.capacity = 2
	roster.add_digimon(DigimonInstance.create(&"agumon", 5))
	roster.add_digimon(DigimonInstance.create(&"agumon", 5))
	check_eq(roster.add_digimon(DigimonInstance.create(&"agumon", 5)), &"full", "capacity enforced")


func test_name_validation() -> void:
	check(NameValidator.validate("") != "", "blank rejected")
	check(NameValidator.validate("   ") != "", "spaces rejected")
	check(NameValidator.validate("ThisNameIsWayTooLong") != "", "too long rejected")
	check_eq(NameValidator.validate("Hikaru"), "", "normal name ok")
	check_eq(NameValidator.validate("Mei-Ling"), "", "hyphen ok")
	check_eq(NameValidator.validate("ひかる"), "", "unicode letters ok")
	check_eq(NameValidator.sanitize("[b]Ren[/b]"), "bRen/b".replace("/", ""), "markup stripped")
	check_eq(NameValidator.sanitize("  A   B  "), "A B", "whitespace collapsed")
	check_eq(NameValidator.sanitize("Bad\u0007Name"), "BadName", "control chars stripped")
	check(NameValidator.validate("...") != "", "needs a letter")
	check_eq(TextVars.escape("[x]"), "[lb]x]", "bbcode escaped")


func test_appearance_roundtrip() -> void:
	var a := CharacterAppearance.create_default(&"female")
	a.set_accessory(&"glasses", true)
	a.hair_color = Color("8a5ad6")
	var b := CharacterAppearance.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	check_eq(b.body_type, &"female", "body")
	check_eq(b.hair_style, a.hair_style, "hair")
	check(b.has_accessory(&"glasses"), "accessory")
	check(b.hair_color.is_equal_approx(a.hair_color), "colour")
	var rng := seeded_rng(3)
	var catalog := GameData.customization_catalog
	for i in 10:
		a.randomize_from(catalog, rng)
		check(catalog.index_of_option(&"hair_style", a.hair_style) >= 0, "random hair valid")
		check(catalog.index_of_option(&"top", a.top) >= 0, "random top valid")
		check_eq(a.body_type, &"female", "randomize keeps body")
