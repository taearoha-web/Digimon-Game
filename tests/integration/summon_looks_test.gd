extends Node3D
## Summon looks: every summon kind loads its model, the archer, mage and priest
## summons wear their new looks and the summoner's stay as they were.
##   godot --headless --path . res://tests/integration/summon_looks_test.tscn
var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _kind_of(class_id: StringName, skill_id: String) -> String:
	var entry := ClassData.find_skill(class_id, skill_id)
	return String(entry.get("summon", {}).get("kind", ""))


func _ready() -> void:
	await get_tree().process_frame
	# Every kind with a model loads and builds a visual.
	for kind in Summon.KINDS:
		var k: Dictionary = Summon.KINDS[kind]
		if bool(k.get("proc", false)):
			continue
		var model := String(k.model)
		var v := MonsterVisual.new()
		add_child(v)
		v.setup(model, float(k.height), float(k.hover), k.tint)
		check(v.model != null, "%s: model %s loads" % [kind, model])
		if v.model != null:
			var box := MonsterVisual._bounds(v.model)
			if box.size.y < 0.05:
				box = MonsterVisual._bone_bounds(v.model, box)
			check(box.size.y > 0.3, "%s: model has a measurable body (%.2f m)" % [kind, box.size.y])
		v.queue_free()

	# Archer, mage and priest picked up their new looks.
	check(_kind_of(&"archer", "golden_falcon") == "falcon", "Golden Falcon is still the falcon")
	check(_kind_of(&"archer", "recall_wolverine") == "spirit_wolf", "Recall Wolverine summons the big spirit wolf")
	check(_kind_of(&"archer", "force_of_nature") == "cactus", "Force of Nature summons cacti")
	check(_kind_of(&"mage", "spirit_elemental") == "elemental", "Spirit Elemental is still the elemental")
	check(Summon.KINDS.elemental.has("eye_fire"), "the Spirit Elemental burns with blue eye fire")
	check(_kind_of(&"mage", "dancing_sword") == "sword" and bool(Summon.KINDS.sword.get("real_sword", false)), "Dancing Sword uses real sword models")
	check(String(Summon.KINDS.fire_elemental.model) == "summon/ChibiDemon", "Fire Elemental is the Chibi Demon")
	check(String(Summon.KINDS.muspell.model) == "cute/Penguin", "Muspell is the penguin")
	var wolf_height := float(Summon.KINDS.spirit_wolf.height)
	check(is_equal_approx(wolf_height, 4.5) and bool(Summon.KINDS.spirit_wolf.get("giant", false)), "the spirit wolf is three times the 1.5 m preview wolf and the one marked giant (%.1f)" % wolf_height)
	for kind in Summon.KINDS:
		if kind != "spirit_wolf":
			check(not bool(Summon.KINDS[kind].get("giant", false)), "%s is not a giant" % kind)

	# The summoner's star skills call the two legends (hand-made models, rigged and animated).
	check(_kind_of(&"summoner", "moonwolf_pact") == "wind_king", "the 50-star summon is the Wind Monkey King")
	check(_kind_of(&"summoner", "eclipse_sovereign") == "poseidon", "the 200-star summon is Poseidon")
	for legend in ["wind_king", "poseidon"]:
		var lv := MonsterVisual.new()
		add_child(lv)
		var lk: Dictionary = Summon.KINDS[legend]
		lv.setup(String(lk.model), float(lk.height), float(lk.hover), lk.tint)
		check(bool(lk.get("legend", false)), "%s is marked a legend" % legend)
		for key in ["idle", "walk", "run", "attack", "hurt", "die"]:
			check(lv._clips.has(key), "%s has a %s clip" % [legend, key])
		var tris := 0
		for mi in lv.model.find_children("*", "MeshInstance3D", true, false):
			tris += (mi as MeshInstance3D).mesh.get_faces().size() / 3
		check(tris > 0 and tris <= 22000, "%s stays within the phone budget (%d triangles)" % [legend, tris])
		check(lv.model.find_children("*", "Skeleton3D", true, false).size() == 1, "%s is rigged" % legend)
		lv.queue_free()

	# The summoner keeps every look it had.
	var kept := {"wolf_pack": "wolf", "giant_frog": "frog", "forest_guardian": "guardian", "alpha_wolves": "wolf", "ancient_treant": "treant", "wind_drake": "drake", "primal_legion": "beast", "elder_dragon": "elder_dragon", "spirit_cat": "cat"}
	for id in kept:
		check(_kind_of(&"summoner", id) == kept[id], "summoner %s keeps its %s" % [id, kept[id]])
	check(String(Summon.KINDS.wolf.model) == "blob/Dog" and String(Summon.KINDS.beast.model) == "big/Dino", "the summoner's wolf and beast models are untouched")

	# The Chibi Demon moves: idle, walk, run and attack clips exist and the attack is sped up.
	var demon := MonsterVisual.new()
	add_child(demon)
	demon.setup("summon/ChibiDemon", 2.15, 0.5, Color.WHITE)
	for key in ["idle", "walk", "run", "attack"]:
		check(demon._clips.has(key), "the Chibi Demon has a %s clip" % key)
	demon.action("attack", 200)
	check(demon.anim != null and demon.anim.speed_scale > 2.0, "the Chibi Demon's punch plays fast (x%.1f)" % (demon.anim.speed_scale if demon.anim else 0.0))
	var box := MonsterVisual._bounds(demon.model)
	check(box.size.y < 0.05, "the Chibi Demon rig reports centimetre bounds, so bones are measured instead")
	check(demon.height > 2.5 and demon.height < 2.8, "the Chibi Demon stands %.1f m with its hover" % demon.height)
	demon.queue_free()

	# Real swords: three different models, each pointing down and centred.
	Game.new_profile(&"mage", "t")
	var hero := Hero.new()
	add_child(hero)
	var seen := {}
	for slot in 3:
		var s := Summon.new()
		s.setup(hero, "dancing_sword", {"kind": "sword", "count": 3}, 1.0, slot, 3, 1)
		add_child(s)
		check(s._blade != null and s._blade.get_child_count() == 1 and s._blade.get_child(0).scale.x > 0.0, "sword %d is a real model" % slot)
		seen[SWORD_NAME(s)] = true
		s.queue_free()
	check(seen.size() == 3, "the three Dancing Swords are three different models (%d)" % seen.size())
	# Eye fire exists on the elemental, twice.
	var spirit := Summon.new()
	spirit.setup(hero, "spirit_elemental", {"kind": "elemental", "count": 1}, 1.0, 0, 1, 1)
	add_child(spirit)
	await get_tree().process_frame
	check(spirit.find_children("EyeFire*", "Node3D", true, false).size() == 2, "the Spirit Elemental has two burning eyes")
	spirit.queue_free()
	hero.queue_free()
	print("SUMMON LOOKS: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func SWORD_NAME(s: Summon) -> String:
	var m := s._blade.get_child(0)
	return String(m.scene_file_path) if m.scene_file_path != "" else String(m.name)
