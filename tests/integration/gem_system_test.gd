extends Node
## The gem system: gems raise a stat by a share (they matter at every level), five sizes
## fused three into one at the forge (sure up to large, 70% / 40% above, a failed try
## loses one), drills open sockets up to 3 (a fourth at +15), three of one type in a
## piece resonate (+20%), twelve of one stat gem worn give its set (gem_set), special gems
## feed crit damage / lifesteal / cooldown / fortune, and old saves' gem ids stay valid.
##   godot --headless --path . res://tests/integration/gem_system_test.tscn

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _piece(slot: String, gems: Array, sockets := 3) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(slot)
	var item := ItemData.generate(90, &"warrior", rng, 4, slot)
	item["sockets"] = sockets
	item["gems"] = gems
	return item


func _ready() -> void:
	Game.set_process(false)
	Game.new_profile(&"warrior", "อัญมณีQA", FaceKit.default_look())
	Game.profile.level = 90
	# Shares, not flat numbers: a large ruby is +3.5% ATK at any level.
	check(ItemData.GEM_SIZES.size() == 5 and ItemData.GEMS.size() == 9, "five sizes, five stat and four special gems")
	check(is_equal_approx(float(ItemData.gem_info({"id": "ruby_2"}).value), 0.035), "an old large ruby is now +3.5% ATK")
	check(ItemData.gem_effect_text(ItemData.gem_info({"id": "ruby_4"})) == "พลังโจมตี +7%", "legendary ruby reads +7%")
	var base := Game.stats_now()
	Game.profile.equip["weapon"] = _piece("weapon", ["ruby_4", "ruby_4", "ruby_4"])
	var with := Game.stats_now()
	check(float(with.atk) > float(base.atk) * 1.2, "three legendary rubies that resonate add over 20% ATK (%d -> %d)" % [int(base.atk), int(with.atk)])
	Game.profile.equip["weapon"] = _piece("weapon", ["ruby_4", "ruby_4", "emerald_4"])
	check(not ItemData.resonates(Game.profile.equip.weapon), "mixed gems do not resonate")
	check(ItemData.resonates(_piece("armor", ["ruby_0", "ruby_1", "ruby_2"])), "three rubies of any size resonate")
	Game.profile.equip.erase("weapon")
	# Special gems.
	Game.profile.equip["helm"] = _piece("helm", ["onyx_4", "pearl_4", "opal_4"])
	Game.profile.equip["boots"] = _piece("boots", ["tourmaline_4", "opal_4", "opal_4"])
	var sp := Game.stats_now()
	check(is_equal_approx(float(sp.crit_dmg), 0.3) and is_equal_approx(float(sp.lifesteal), 0.035), "onyx crit damage and pearl lifesteal")
	check(is_equal_approx(float(sp.cdr), HeroStats.MAX_CDR), "opal cooldown capped at %d%%" % int(HeroStats.MAX_CDR * 100))
	check(is_equal_approx(float(sp.fortune), 0.2), "tourmaline fortune")
	Game.profile.equip.erase("helm")
	Game.profile.equip.erase("boots")
	# Twelve rubies worn: the ruby set; topaz set adds crit.
	for slot in ["weapon", "armor", "helm", "boots"]:
		Game.profile.equip[slot] = _piece(slot, ["ruby_0", "ruby_0", "ruby_0"])
	check(String(Game.stats_now().gem_set) == "ruby", "12 rubies worn: the ruby set")
	var no_topaz := float(Game.stats_now().crit)
	for slot in ["weapon", "armor", "helm", "boots"]:
		Game.profile.equip[slot] = _piece(slot, ["topaz_0", "topaz_0", "topaz_0"])
	check(String(Game.stats_now().gem_set) == "topaz" and float(Game.stats_now().crit) > no_topaz + HeroStats.GEM_SET_HAWK, "12 topaz: the hawk set's crit")
	for slot in ["weapon", "armor", "helm", "boots"]:
		Game.profile.equip.erase(slot)
	# Fusing.
	Game.profile.gold = 1000000
	Game.add_item(ItemData.gem("ruby", 0, 3))
	check(Game.fuse_gem("ruby_0") == "ok" and _count("ruby_1") == 1 and _count("ruby_0") == 0, "three small rubies fuse into a medium one")
	check(Game.fuse_gem("ruby_1").begins_with("ต้องมี"), "fusing needs three")
	var ok := 0
	var fail := 0
	for i in 60:
		Game.add_item(ItemData.gem("emerald", 3, 3))
		var r := Game.fuse_gem("emerald_3")
		if r == "ok":
			ok += 1
		elif r == "fail":
			fail += 1
		_clear("emerald_3")
	check(ok > 10 and fail > 15, "perfect -> legendary succeeds about 40%% (%d ok, %d fail)" % [ok, fail])
	check(Game.fuse_gem("emerald_4") == "อัญมณีขั้นสูงสุดแล้ว" or _count("emerald_4") < 3, "legendary is the top")
	Game.add_item(ItemData.gem("amethyst", 2, 3))
	Game.rng.seed = 99
	var before := _count("amethyst_2")
	var res := Game.fuse_gem("amethyst_2")
	check((res == "ok" and _count("amethyst_2") == before - 3) or (res == "fail" and _count("amethyst_2") == before - 1), "a failed fuse loses one, a good one uses three (%s)" % res)
	# Drilling.
	var piece := _piece("armor", [], 0)
	check(Game.drill_socket(piece).begins_with("ต้องใช้"), "drilling needs a drill")
	Game.add_item(ItemData.jewel("drill", 5))
	for i in 3:
		Game.drill_socket(piece)
	check(int(piece.sockets) == 3 and Game.drill_socket(piece).begins_with("ช่องเต็ม"), "drills open up to 3 sockets")
	piece["plus"] = 15
	check(Game.drill_socket(piece) == "ok" and int(piece.sockets) == 4, "+15 opens a fourth")
	check(Game._valid_item(piece), "a 4-socket piece is a valid save item")
	check(Game._valid_gem_id("pearl_4") and Game._valid_gem_id("ruby_2") and not Game._valid_gem_id("ruby_5"), "new and old gem ids validate")
	check(Game.drill_socket({"kind": "equip", "slot": "ring", "sockets": 0}) == "เจาะช่องไม่ได้", "rings and amulets cannot be drilled")
	print("GEM SYSTEM: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _count(gem_id: String) -> int:
	var n := 0
	for it in Game.profile.inv:
		if it.get("kind", "") == "gem" and String(it.id) == gem_id:
			n += int(it.get("count", 1))
	return n


func _clear(gem_id: String) -> void:
	for i in range(Game.profile.inv.size() - 1, -1, -1):
		var it: Dictionary = Game.profile.inv[i]
		if it.get("kind", "") == "gem" and String(it.id) == gem_id:
			Game.profile.inv.remove_at(i)
