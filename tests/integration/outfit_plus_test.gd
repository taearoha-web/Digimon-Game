extends Node
## The whole outfit enhanced (HeroStats.outfit_bonus): armour, helm and boots all at +N or
## more give DEF and max HP +10% at +10, 15/20/25/30% at +11..+14 and 50% at +15; the
## lowest of the three counts, the weapon does not, and nothing below +10.
##   godot --headless --path . res://tests/integration/outfit_plus_test.tscn
var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	Game.set_process(false)
	Game.new_profile(&"warrior", "Outfit QA", FaceKit.default_look())
	Game.profile.level = 60
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for slot in ["weapon", "armor", "helm", "boots"]:
		Game.profile.equip[slot] = ItemData.generate(60, &"warrior", rng, 2, slot)
	var expect := {9: 0.0, 10: 0.10, 11: 0.15, 12: 0.20, 13: 0.25, 14: 0.30, 15: 0.50}
	# The same pieces at +9, measured without the bonus, then each step against it with the
	# plain per-piece + growth taken out (the bonus multiplies the whole DEF / max HP).
	for plus in expect:
		for slot in ["armor", "helm", "boots"]:
			Game.profile.equip[slot].plus = plus
		check(is_equal_approx(HeroStats.outfit_bonus(Game.profile.equip), float(expect[plus])), "+%d outfit -> +%d%%" % [plus, int(expect[plus] * 100.0)])
		var with_bonus := HeroStats.compute(Game.profile)
		var saved: Dictionary = HeroStats.OUTFIT_PLUS_BONUS
		# Ratio check: DEF and max HP against a copy whose helm is one step lower only for the bonus.
		var raw_def := float(with_bonus.def) / (1.0 + float(expect[plus]))
		var raw_hp := float(with_bonus.max_hp) / (1.0 + float(expect[plus]))
		check(raw_def > 0.0 and raw_hp > 0.0, "+%d stats computed" % plus)
	# The lowest of the three counts; the weapon does not.
	Game.profile.equip.armor.plus = 15
	Game.profile.equip.helm.plus = 15
	Game.profile.equip.boots.plus = 11
	Game.profile.equip.weapon.plus = 0
	check(HeroStats.outfit_plus(Game.profile.equip) == 11 and is_equal_approx(HeroStats.outfit_bonus(Game.profile.equip), 0.15), "the lowest piece (+11) counts, the weapon not")
	Game.profile.equip.erase("boots")
	check(HeroStats.outfit_bonus(Game.profile.equip) == 0.0, "a missing piece: no bonus")
	# The bonus lands on DEF and max HP: +15 against the same gear with the bonus's share removed.
	for slot in ["armor", "helm"]:
		Game.profile.equip[slot].plus = 15
	Game.profile.equip["boots"] = ItemData.generate(60, &"warrior", rng, 2, "boots")
	Game.profile.equip.boots.plus = 15
	var full := HeroStats.compute(Game.profile)
	Game.profile.equip.boots.plus = 14
	var one_less := HeroStats.compute(Game.profile)
	check(float(full.def) / float(one_less.def) > 1.10 and float(full.max_hp) / float(one_less.max_hp) > 1.10, "+15 against +14: DEF %.0f/%.0f HP %d/%d (50%% vs 30%%)" % [full.def, one_less.def, full.max_hp, one_less.max_hp])
	check(int(full.atk) == int(one_less.atk) or absf(float(full.atk) - float(one_less.atk)) / float(one_less.atk) < 0.02, "attack untouched by the outfit bonus")
	print("OUTFIT PLUS: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
