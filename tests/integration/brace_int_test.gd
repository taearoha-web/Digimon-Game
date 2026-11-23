extends Node
## เบ่งเลือด (the Defender's "brace"): its party max HP grows with the skill's stars
## (+30% at ★1 .. +50% at ★5) and with the INT the player spent (+0.1% a point, up to
## +30%), and the real cast (Hero._apply_self_fx) puts that number on the hero.
##   godot --headless --path . res://tests/integration/brace_int_test.tscn
var failures: Array[String] = []
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _ready() -> void:
	Game.set_process(false)
	var skill := ClassData.find_skill(&"defender", "brace")
	check(not skill.is_empty(), "brace exists")
	var stars := {1: 0.30, 2: 0.35, 3: 0.40, 4: 0.45, 5: 0.50}
	var ints := {0: 0.0, 50: 0.05, 100: 0.10, 200: 0.20, 300: 0.30, 600: 0.30}
	for r in stars:
		var base := SkillRank.buff_value(skill.fx.buff, "hp", r)
		check(is_equal_approx(base, stars[r]), "★%d hp %.3f" % [r, base])
		for n in ints:
			var buff := SkillRank.with_int_hp(skill, {"hp": base, "guard": 0.1}, n)
			check(is_equal_approx(float(buff.hp), stars[r] + ints[n]), "★%d INT %d -> hp %.3f" % [r, n, float(buff.hp)])
			check(is_equal_approx(float(buff.guard), 0.1), "guard untouched")
	# Other skills get nothing.
	check(SkillRank.int_hp_bonus(ClassData.find_skill(&"defender", "iron_wall"), 300) == 0.0, "iron_wall has no INT bonus")
	# The real cast.
	Game.new_profile(&"defender", "Brace QA", {"gender": 0})
	Game.profile.level = 100
	Game.profile.attrs["int"] = 200
	Game.profile.skills["brace"] = 5
	var hero := Hero.new()
	add_child(hero)
	hero.set_physics_process(false)
	var before := int(hero.stats.max_hp)
	hero._apply_self_fx(hero._ranked(skill))
	var hp_buff := 0.0
	for b in hero._buffs:
		if String((b as Dictionary).get("skill_id", "")) == "brace":
			hp_buff = float((b as Dictionary).get("hp", 0.0))
	check(is_equal_approx(hp_buff, 0.70), "cast at ★5 with 200 INT spent puts +70%% max HP (got %.3f)" % hp_buff)
	print("BRACE INT TEST: %d checks, %d failures (max hp %d before)" % [checks, failures.size(), before])
	get_tree().quit(1 if failures.size() > 0 else 0)
