extends TestCase
## Equipment chips (EquipmentService) and shops (ShopService).


func test_chip_bonus_applies_and_serializes() -> void:
	var inv := Inventory.new()
	inv.add_item(&"power_chip", 1)
	var inst := DigimonInstance.create(&"agumon", 5)
	var base_atk := inst.get_stat(DigimonStats.ATTACK)
	var r := EquipmentService.equip(inst, &"power_chip", inv)
	check(r.ok, "equip ok")
	check_eq(inst.held_item_id, &"power_chip", "held id")
	check_eq(inv.count(&"power_chip"), 0, "chip leaves the bag")
	check_eq(inst.get_stat(DigimonStats.ATTACK), base_atk + 6, "+6 ATK while held")
	check_eq(inst.get_equipment_bonus(DigimonStats.DEFENSE), 0, "no DEF bonus")
	var copy := DigimonInstance.from_dict(JSON.parse_string(JSON.stringify(inst.to_dict())))
	check_eq(copy.held_item_id, &"power_chip", "held chip survives save/load")
	check_eq(copy.get_stat(DigimonStats.ATTACK), base_atk + 6, "bonus after load")
	r = EquipmentService.unequip(inst, inv)
	check(r.ok, "unequip ok")
	check_eq(inv.count(&"power_chip"), 1, "chip returns to the bag")
	check_eq(inst.get_stat(DigimonStats.ATTACK), base_atk, "bonus removed")
	check(not EquipmentService.unequip(inst, inv).ok, "nothing to remove")


func test_equip_rules_and_swaps() -> void:
	var inv := Inventory.new()
	inv.add_item(&"guard_chip", 1)
	inv.add_item(&"vital_chip", 1)
	inv.add_item(&"small_patch", 1)
	var inst := DigimonInstance.create(&"gabumon", 6)
	check(not EquipmentService.equip(inst, &"small_patch", inv).ok, "consumables can't be equipped")
	check(not EquipmentService.equip(inst, &"power_chip", inv).ok, "can't equip a chip you don't own")
	check(EquipmentService.equip(inst, &"guard_chip", inv).ok, "equip guard")
	check(not EquipmentService.equip(inst, &"guard_chip", inv).ok, "already holding it")
	# Swap: the old chip goes back, the new one is held.
	check(EquipmentService.equip(inst, &"vital_chip", inv).ok, "swap to vital")
	check_eq(inv.count(&"guard_chip"), 1, "guard returned on swap")
	check_eq(inv.count(&"vital_chip"), 0, "vital taken")
	var roster := DigimonRoster.new()
	roster.add_digimon(inst)
	check_eq(EquipmentService.holders_of(&"vital_chip", roster).size(), 1, "holders_of finds the holder")


func test_vital_chip_keeps_hp_ratio() -> void:
	var inv := Inventory.new()
	inv.add_item(&"vital_chip", 1)
	var inst := DigimonInstance.create(&"patamon", 5)
	var max_before := inst.get_max_hp()
	check_eq(inst.current_hp, max_before, "starts full")
	EquipmentService.equip(inst, &"vital_chip", inv)
	check_eq(inst.get_max_hp(), max_before + 20, "+20 max HP")
	check_eq(inst.current_hp, inst.get_max_hp(), "still full after equip")
	inst.take_damage(inst.get_max_hp() / 2)
	var ratio := inst.get_hp_ratio()
	EquipmentService.unequip(inst, inv)
	check_near(inst.get_hp_ratio(), ratio, 0.05, "ratio kept on unequip")
	check(inst.current_hp <= inst.get_max_hp(), "hp clamped")


func test_shop_buy_and_sell() -> void:
	var shop := GameData.get_shop(&"plaza_shop")
	check_not_null(shop, "plaza shop exists")
	var profile := PlayerProfile.new()
	var inv := Inventory.new()
	profile.add_currency(100)
	var patch := GameData.get_item(&"small_patch")
	var price := ShopService.get_buy_price(shop, patch)
	check_eq(price, patch.buy_price, "price from item data")
	check_eq(ShopService.max_affordable(shop, patch, profile, inv), 100 / price, "max affordable")
	var r := ShopService.buy(shop, &"small_patch", 2, profile, inv)
	check(r.ok, "buy ok")
	check_eq(profile.currency, 100 - price * 2, "coins spent")
	check_eq(inv.count(&"small_patch"), 2, "items received")
	r = ShopService.buy(shop, &"small_patch", 99, profile, inv)
	check(not r.ok, "can't overspend")
	check_eq(inv.count(&"small_patch"), 2, "nothing added on failure")
	check(not ShopService.buy(shop, &"medium_patch", 1, profile, inv).ok, "not in this shop's stock")
	check(not ShopService.buy(shop, &"small_patch", 0, profile, inv).ok, "quantity must be positive")
	var coins := profile.currency
	r = ShopService.sell(&"small_patch", 1, profile, inv)
	check(r.ok, "sell ok")
	check_eq(profile.currency, coins + patch.sell_price, "sell price paid")
	check_eq(inv.count(&"small_patch"), 1, "item removed")
	check(not ShopService.sell(&"small_patch", 5, profile, inv).ok, "can't sell more than owned")
	inv.add_item(&"gate_pass", 1)
	check(not ShopService.can_sell(GameData.get_item(&"gate_pass")), "key items can't be sold")
	check(not ShopService.sell(&"gate_pass", 1, profile, inv).ok, "selling a key item fails")


func test_shop_price_multiplier_and_stack_limit() -> void:
	var shop := ShopData.new()
	shop.id = &"test_shop"
	var stock: Array[StringName] = [&"reboot_chip"]
	shop.stock = stock
	shop.price_multiplier = 1.5
	var chip := GameData.get_item(&"reboot_chip")
	check_eq(ShopService.get_buy_price(shop, chip), int(round(chip.buy_price * 1.5)), "multiplier applied")
	var profile := PlayerProfile.new()
	profile.add_currency(1000000)
	var inv := Inventory.new()
	inv.add_item(&"reboot_chip", chip.max_stack - 1)
	check_eq(ShopService.max_affordable(shop, chip, profile, inv), 1, "limited by stack space")
	check(not ShopService.buy(shop, &"reboot_chip", 2, profile, inv).ok, "can't exceed max stack")
	check(ShopService.buy(shop, &"reboot_chip", 1, profile, inv).ok, "fills the stack")
