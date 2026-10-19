extends Node
## The AI companion keeps levelling past Lv.100: it earns ★ up to 200 from the
## EXP of every kill, grows stronger with them, wears the matching star set,
## and the ★ survive a save round trip.
##   godot --headless --path . res://tests/integration/companion_stars_test.tscn
var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _member() -> Dictionary:
	return Game.party()[0]


func _ready() -> void:
	for cls in ClassData.IDS:
		Game.new_profile(cls, "Companion stars QA")
		Game.recruit(&"mage" if cls == &"priest" else &"priest", false)
		Game.profile.level = 100
		Game.profile.adv = 4
		var buddy := _member()
		buddy["level"] = 100
		buddy["exp"] = 0
		check(Game.party_stars(buddy) == 0, "a companion starts with no stars")
		# Kills at Lv.100 give EXP to the party; past the cap it becomes ★.
		var previous_hp := 0
		var previous_atk := 0
		var last_gear := 0
		for target in [1, 25, 49, 50, 100, 150, 200]:
			while Game.party_stars(buddy) < target:
				Game.party_add_exp(HeroStats.exp_to_next(100))
			var stats := HeroStats.compute(Game.party_profile(buddy))
			check(int(stats.max_hp) > previous_hp, "%s: health grows with stars (%d at %d*)" % [cls, int(stats.max_hp), target])
			check(int(stats.atk) > previous_atk, "%s: attack grows with stars (%d at %d*)" % [cls, int(stats.atk), target])
			previous_hp = int(stats.max_hp)
			previous_atk = int(stats.atk)
			var tier := Game.party_gear_tier(buddy)
			check(tier >= last_gear, "gear tier never drops")
			last_gear = tier
			var weapon: Dictionary = Game.party_equip(buddy).weapon
			check((int(weapon.get("star_tier", 0)) == tier), "%s: wears the %d* set at %d*" % [cls, tier, target])
		check(Game.party_stars(buddy) == 200, "%s: reaches 200 stars" % cls)
		check(Game.party_star_need(buddy) == 0, "no EXP needed past 200")
		Game.party_add_exp(HeroStats.exp_to_next(100) * 50)
		check(Game.party_stars(buddy) == 200, "stars stop at 200")
		check(Game._valid_profile(Game.profile.duplicate(true)), "%s: a save with a 200-star companion is valid" % cls)
		var broken: Dictionary = Game.profile.duplicate(true)
		broken.party[0]["stars"] = 201
		check(not Game._valid_profile(broken), "201 stars is rejected")
	# Catching up: a companion left behind follows the hero's stars.
	Game.new_profile(&"warrior", "Catch-up QA")
	Game.recruit(&"priest", false)
	Game.profile.level = 100
	Game.profile.paragon = {"level": 120, "exp": 0, "points": 120, "spent": 0, "alloc": {}}
	var late := _member()
	late["level"] = 100
	late["stars"] = 10
	Game.party_catch_up()
	check(Game.party_stars(late) == 118, "a companion catches up to two stars below the hero (%d)" % Game.party_stars(late))
	Game.profile.level = 60
	late["level"] = 60
	late["stars"] = 0
	Game.party_catch_up()
	check(Game.party_stars(late) == 0, "below Lv.100 nobody has stars")
	print("COMPANION STARS: ", "PASS" if failures == 0 else "FAIL", " | ", checks, " checks, ", failures, " failures")
	get_tree().quit(failures)
