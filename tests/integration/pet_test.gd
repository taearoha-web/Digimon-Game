extends Node3D
## The pets (PetData / Pet / PetPen / PetScreen): three pets with eight skills each on
## the level ladder, chosen once and kept, saved and validated (old saves without a pet
## stay valid), following the hero and fighting, falling and coming back, scaling with
## the hero's level, buffing / healing the hero through its buff list, the village pen
## with its ten pets and the keeper, the selection screen, the duel rule and no leaked
## nodes over zone changes.
##   XDG_DATA_HOME=/tmp/x godot --headless --audio-driver Dummy --path . res://tests/integration/pet_test.tscn
var checks := 0
var failures := 0
var main: Node


## A monster that counts the hits it takes and never dies.
class Dummy:
	extends Mob
	var hits := 0
	var taken := 0
	var stuns := 0
	var slows := 0
	func _ready() -> void:
		add_to_group("mobs")
		visual = MonsterVisual.new()
		add_child(visual)
		set_physics_process(false)
	func set_targeted(_on: bool) -> void:
		pass
	func take_hit(amount: int, _crit: bool, _color := Color.WHITE, _attacker: Node = null) -> bool:
		hits += 1
		taken += amount
		return false
	func apply_stun(seconds: float) -> void:
		stuns += 1
		_stun = seconds
	func apply_slow(seconds: float) -> void:
		slows += 1
		_slow = seconds


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", note)


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func dummy(at: Vector3, def := 0.0) -> Dummy:
	var d := Dummy.new()
	d.template = MonsterData.get_monster(&"forest_orc")
	d.stats = {"hp": 1000000, "atk": 10, "def": def, "exp": 0, "gold": 0}
	d.hp = 1000000
	d.max_hp = 1000000
	d.hostile = true
	add_child(d)
	d.global_position = at
	return d


func _ready() -> void:
	Game.set_process(false)
	Game.slot = 1
	await get_tree().process_frame
	_data()
	_choose_once_and_save()
	_scaling()
	await _stages()
	await _toughness()
	await _follow_fight_respawn()
	await _owner_support()
	await _every_skill()
	await _screen()
	await _village_and_zones()
	Game.has_profile = false
	print("PET TEST: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("PASS")
	get_tree().quit(1 if failures > 0 else 0)


## Three pets, eight skills each on the level ladder, models with every clip.
func _data() -> void:
	check(PetData.ORDER == ["fire", "water", "earth"] and PetData.PETS.size() == 3, "three pets: fire, water, earth")
	check(PetData.UNLOCK_LEVELS == [1, 10, 20, 35, 50, 65, 80, 100], "skills unlock at Lv.1/10/20/35/50/65/80/100")
	var ids := {}
	for id in PetData.ORDER:
		var pet := PetData.get_pet(id)
		check(String(pet.element) == id and String(pet.name) != "" and String(pet.element_name).begins_with("ธาตุ"), "%s: element and Thai names" % id)
		check((pet.skills as Array).size() == 8, "%s has eight skills" % id)
		for i in (pet.skills as Array).size():
			var skill: Dictionary = pet.skills[i]
			check(not ids.has(skill.id) and String(skill.name) != "" and String(skill.desc) != "", "%s skill %d has an id and Thai name / description" % [id, i])
			ids[skill.id] = true
			check(float(skill.cd) > 0.0, "%s: %s has a cooldown" % [id, skill.name])
		check(bool((pet.skills[7] as Dictionary).get("ultimate", false)), "%s: the eighth skill is the ultimate" % id)
		check(PetData.unlocked(id, 1).size() == 1 and PetData.unlocked(id, 35).size() == 4 and PetData.unlocked(id, 99).size() == 7 and PetData.unlocked(id, 100).size() == 8, "%s: skills unlock with the hero's level" % id)
		check(ResourceLoader.exists(String(pet.model)), "%s: model %s exists" % [id, pet.model])
		if String(pet.skin) != "":
			check(ResourceLoader.exists(String(pet.skin)), "%s: skin exists" % id)
		var v := MonsterVisual.new()
		add_child(v)
		var skin: Texture2D = load(String(pet.skin)) as Texture2D if String(pet.skin) != "" else null
		v.setup(String(pet.model), float(pet.height), 0.0, pet.tint, skin)
		for key in ["idle", "walk", "run", "attack", "skill1", "skill2", "hurt", "die"]:
			check(v._clips.has(key), "%s has a %s clip" % [id, key])
		var tris := 0
		for mi in v.model.find_children("*", "MeshInstance3D", true, false):
			tris += (mi as MeshInstance3D).mesh.get_faces().size() / 3
		check(tris > 500 and tris < 10000, "%s: %d triangles (phone budget)" % [id, tris])
		v.free()
	check(PetData.PETS.fire.skin != "" and String(PetData.PETS.earth.model).ends_with("GroveDruid.glb"), "fire wears its flame skin, earth is the grove druid")


## A pet is chosen once (per character), saved, and validated.
func _choose_once_and_save() -> void:
	Game.new_profile(&"warrior", "เลี้ยงสัตว์")
	check(Game.pet_id() == "" and String(Game.profile.get("pet", "x")) == "", "a new hero has no pet")
	check(not Game.choose_pet("dragon"), "an unknown pet cannot be chosen")
	# The starter quest รับสัตว์เลี้ยงคู่ใจ: open after the tutorial (or for older heroes).
	check(not PetData.quest_open(Game.profile), "a brand-new hero gets the pet quest only after the tutorial")
	Game.profile.flags[Tutorial.FLAG] = Tutorial.DONE
	check(PetData.quest_open(Game.profile), "after the tutorial the pet quest is open")
	var older := {"level": Tutorial.SKIP_AT, "flags": {}, "pet": ""}
	check(PetData.quest_open(older) and not PetData.quest_open({"level": 40, "flags": {}, "pet": "fire"}), "older characters without a pet get the quest too, not those with one")
	var gold := int(Game.profile.gold)
	var potions: int = Game.profile.inv.filter(func(i): return String(i.get("id", "")) == "hp_s").reduce(func(a, i): return a + int(i.count), 0)
	check(Game.choose_pet("water") and Game.pet_id() == "water", "the water pet is chosen")
	var potions_after: int = Game.profile.inv.filter(func(i): return String(i.get("id", "")) == "hp_s").reduce(func(a, i): return a + int(i.count), 0)
	check(int(Game.profile.gold) == gold + PetData.QUEST_GOLD and potions_after == potions + 5 and int(Game.profile.flags.get(PetData.QUEST_FLAG, 0)) == 1, "choosing completes the quest: +%d gold and potions" % PetData.QUEST_GOLD)
	check(not PetData.quest_open(Game.profile), "the quest closes once the pet is chosen")
	check(not Game.choose_pet("fire") and not Game.choose_pet("water") and Game.pet_id() == "water", "a chosen pet can never be changed")
	check(Game.load_game(1) and Game.pet_id() == "water", "the pet is saved and loads back")
	check(not Game.choose_pet("earth"), "still no change after a reload")
	var old := Game.profile.duplicate(true)
	old.erase("pet")
	check(Game._valid_profile(old), "an old save without a pet stays valid")
	check(PetData.chosen(Game._repair(old.duplicate(true))) == "" and String(Game._repair(old.duplicate(true)).pet) == "", "an old save repairs to no pet")
	var with_pet := old.duplicate(true)
	with_pet["pet"] = "earth"
	check(Game._valid_profile(with_pet) and String(Game._repair(with_pet.duplicate(true)).pet) == "earth", "a save with a pet is valid and keeps it")
	for bad in [5, ["fire"], {"id": "fire"}, "x".repeat(17)]:
		var broken := old.duplicate(true)
		broken["pet"] = bad
		check(not Game._valid_profile(broken), "a malformed pet field is refused (%s)" % str(bad))
	var unknown := old.duplicate(true)
	unknown["pet"] = "dragon"
	check(Game._valid_profile(unknown) and String(Game._repair(unknown).pet) == "", "an unknown pet id is dropped on repair")
	# Another slot (another character) chooses its own pet.
	Game.slot = 2
	Game.new_profile(&"mage", "อีกตัว")
	check(Game.pet_id() == "" and Game.choose_pet("fire"), "each character chooses its own pet")
	Game.delete_save(2)
	Game.slot = 1
	check(Game.load_game(1) and Game.pet_id() == "water", "the first character keeps its own pet")


## The pet's level is the hero's and its stats are shares of the hero's.
func _scaling() -> void:
	Game.new_profile(&"warrior", "สเกล")
	Game.profile.level = 10
	var low_owner := Game.stats_now()
	var low := PetData.stats_for("fire", low_owner, 10)
	Game.profile.level = 80
	Game.profile.attrs.str = 300
	Game.profile.attrs.vit = 200
	var high_owner := Game.stats_now()
	var high := PetData.stats_for("fire", high_owner, 80)
	check(int(low.level) == 10 and int(high.level) == 80, "pet level = hero level")
	check(float(high.atk) > float(low.atk) * 2.0 and int(high.max_hp) > int(low.max_hp), "a stronger hero has a stronger pet (ATK %.0f -> %.0f, HP %d -> %d)" % [low.atk, high.atk, low.max_hp, high.max_hp])
	check(is_equal_approx(float(high.atk), float(high_owner.atk) * 0.40) and int(high.max_hp) == int(round(float(high_owner.max_hp) * 1.0)), "fire pet ATK 40%% / HP 100%% of the hero")
	for id in PetData.ORDER:
		var s := PetData.stats_for(id, high_owner, 80)
		check(float(s.atk) < float(high_owner.atk) * 0.5 and float(s.max_hp) <= float(high_owner.max_hp) * 1.5 + 1.0, "%s helps without out-hitting the hero (sturdy, not stronger)" % id)
	check(not PetData.allowed_in(ZoneData.get_zone(&"pvp")) and not PetData.allowed_in(ZoneData.get_zone(&"guildwar")) and PetData.allowed_in(ZoneData.get_zone(&"tower")) and PetData.allowed_in(ZoneData.get_zone(&"meadow")) and PetData.allowed_in(ZoneData.get_zone(&"town")), "pets stay out of the 1v1 duels and the guild war only")


func _hero(level: int, pet_id: String) -> Hero:
	Game.new_profile(&"warrior", "เจ้าของ")
	Game.profile.level = level
	Game.choose_pet(pet_id)
	var hero := Hero.new()
	hero.field = self
	add_child(hero)
	hero.refresh_stats()
	Game.profile.hp = int(hero.stats.max_hp)
	return hero


func _pet(hero: Hero) -> Pet:
	var pet := Pet.new()
	pet.setup_pet(hero, Game.pet_id())
	add_child(pet)
	return pet


## A stand-in AI player (its member sheet and stats) and a stand-in online player.
class FakeOwner:
	extends Node3D
	var member: Dictionary = {}
	var stats: Dictionary = {"atk": 100.0, "max_hp": 1000, "def": 10.0, "crit": 0.1}


class NetOwner:
	extends Node3D
	var player: Dictionary = {}
	var look: Dictionary = {}


## Six forms by the owner's level and ★: young (Lv.1-34), grown (Lv.35-79), full-grown
## (Lv.80+), awakened (Lv.100 ★100), holy (★200), god (★300); each a little bigger; the
## hero's pet wears more layers each form (fewer at low quality / under memory pressure),
## growing while playing announces it, re-dressing leaks nothing; AI players' and other
## players' pets take their owner's level and ★ with the cheap look.
func _stages() -> void:
	var cases := [[1, 0, 0], [34, 0, 0], [34, 300, 0], [35, 0, 1], [79, 0, 1], [80, 0, 2], [99, 300, 2], [100, 0, 2], [100, 99, 2],
		[100, 100, 3], [100, 199, 3], [100, 200, 4], [100, 299, 4], [100, 300, 5]]
	var right := true
	for c in cases:
		if PetData.stage_for(int(c[0]), int(c[1])) != int(c[2]):
			right = false
			printerr("stage_for(%d, %d) = %d, wants %d" % [c[0], c[1], PetData.stage_for(int(c[0]), int(c[1])), c[2]])
	check(right, "six forms at Lv.1 / 35 / 80 and Lv.100 with ★100 / 200 / 300, at every edge")
	check(PetData.stage_for(100) == 2 and PetData.stage_name(100, 300) == "ร่างเทพ" and PetData.STAGE_NAMES.size() == 6 and PetData.STAGE_SCALE.size() == 6, "levels alone stop at the full-grown form; the god form is ร่างเทพ")
	var grows := true
	for i in range(1, PetData.STAGE_SCALE.size()):
		grows = grows and float(PetData.STAGE_SCALE[i]) > float(PetData.STAGE_SCALE[i - 1])
	check(grows and float(PetData.STAGE_SCALE[5]) <= 1.7, "each form is bigger than the last, the god form capped (%s)" % str(PetData.STAGE_SCALE))
	check(PetData.form_requirement(1) == "Lv.35" and PetData.form_requirement(5) == "Lv.100 ★300", "the requirements read Lv.35 .. Lv.100 ★300")
	check(PetData.growth_line("fire", 5).contains("คาอิจูเร็กซ์ ตื่นรู้เป็นร่างเทพ"), "the god form's message (%s)" % PetData.growth_line("fire", 5))
	GameSettings.load_settings()
	var quality := GameSettings.quality
	GameSettings.quality = 2
	MemoryGuard.force(0, get_tree())
	var hero := _hero(20, "earth")
	var pet := _pet(hero)
	await get_tree().process_frame
	check(pet.stage == 0 and is_equal_approx(pet._visual.scale.x, PetData.STAGE_SCALE[0]) and pet.form_root == null, "Lv.20: the young form, no layers")
	Game.profile.level = 50
	pet._refresh_stats()
	check(pet.stage == 1 and is_equal_approx(pet._visual.scale.x, PetData.STAGE_SCALE[1]), "Lv.50: grown")
	Game.profile.level = 90
	pet._refresh_stats()
	check(pet.stage == 2 and is_equal_approx(pet._visual.scale.x, PetData.STAGE_SCALE[2]) and pet._aura != null, "Lv.90: full-grown with its aura")
	check(pet._name_tag.text.contains(PetData.STAGE_NAMES[2]), "the name tag shows the form (%s)" % pet._name_tag.text)
	Game.profile.level = 100
	Game.paragon().level = 99
	pet._refresh_stats()
	check(pet.stage == 2, "Lv.100 ★99: still full-grown")
	var said: Array[String] = []
	var listen := func(text: String, _kind: StringName): said.append(text)
	Game.toast.connect(listen)
	var counts: Array = []
	var budgets: Array = []
	for f in [3, 4, 5]:
		Game.paragon().level = int(PetData.STAGE_STARS[f])
		pet._refresh_stats()
		var names := PetForm.layers(pet.form_root)
		var want: Array = ["PetAura"] + PetForm.AWAKENED_LAYERS
		if f >= 4:
			want += PetForm.HOLY_LAYERS
		if f >= 5:
			want += PetForm.GOD_LAYERS
		var have := true
		for n in want:
			have = have and names.has(n)
		check(pet.stage == f and is_equal_approx(pet._visual.scale.x, PetData.STAGE_SCALE[f]) and have, "★%d: %s with its layers (%s)" % [PetData.STAGE_STARS[f], PetData.STAGE_NAMES[f], str(names)])
		check(not said.is_empty() and said.back() == PetData.growth_line("earth", f), "★%d: growing while playing says so (%s)" % [PetData.STAGE_STARS[f], said.back() if not said.is_empty() else "-"])
		var rim := pet._visual._flash_targets()[0] as MeshInstance3D
		check(rim.material_overlay == PetForm.rim_material("earth", f), "★%d: the model wears the form's rim light" % PetData.STAGE_STARS[f])
		counts.append(names.size())
	Game.toast.disconnect(listen)
	# The growth bursts fade before the budget is counted.
	await wait(2.5)
	check(counts[0] < counts[1] and counts[1] < counts[2], "each star form wears more layers (%s)" % str(counts))
	check(pet._name_tag.text.contains("ร่างเทพ") and pet._name_tag.text.contains(String(PetData.GOD_TITLES.earth)), "the god form's name tag wears its title (%s)" % pet._name_tag.text)
	check(PetForm.layers(pet.form_root).has("Crown") and PetForm.layers(pet.form_root).has("GodHalo"), "the crown and halo ride the head")
	var full := PetForm.layers(pet.form_root).size()
	# Low quality and memory pressure trim the layers (the pet re-dresses by itself).
	GameSettings.quality = 0
	pet._refresh_stats()
	var low := PetForm.layers(pet.form_root)
	check(low.size() < full and not low.has("Wings") and not low.has("Trail") and not low.has("Light") and not low.has("Motes") and low.has("Crown") and low.has("PetAura"), "low quality keeps only the still pieces (%s)" % str(low))
	GameSettings.quality = 2
	MemoryGuard.force(2, get_tree())
	pet._refresh_stats()
	var tight := PetForm.layers(pet.form_root)
	check(tight.size() < full and not tight.has("Wings") and not tight.has("Light"), "memory pressure trims them too (%s)" % str(tight))
	MemoryGuard.force(1, get_tree())
	pet._refresh_stats()
	check(not PetForm.layers(pet.form_root).has("Light") and PetForm.layers(pet.form_root).has("Wings"), "a little pressure drops the light, keeps the wings")
	MemoryGuard.force(0, get_tree())
	pet._refresh_stats()
	await get_tree().process_frame
	# Re-dressing over and over leaks no node and no budget.
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var budget := [VfxBudget._particles, VfxBudget._decorations, VfxBudget._lights]
	for round in 4:
		GameSettings.quality = 0
		pet._refresh_stats(true)
		GameSettings.quality = 2
		pet._refresh_stats(true)
		Game.paragon().level = 0
		pet._refresh_stats(true)
		Game.paragon().level = 300
		pet._refresh_stats(true)
		await get_tree().process_frame
	await get_tree().process_frame
	check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) <= nodes + 2, "re-dressing leaks no nodes (%d -> %d)" % [nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	check([VfxBudget._particles, VfxBudget._decorations, VfxBudget._lights] == budget, "re-dressing leaks no budget (%s -> %s)" % [str(budget), str([VfxBudget._particles, VfxBudget._decorations, VfxBudget._lights])])
	pet.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(VfxBudget._lights == 0 and VfxBudget._particles == 0, "a freed god-form pet gives its light and trail back (%d, %d)" % [VfxBudget._lights, VfxBudget._particles])
	# Another player's pet (PetFollower): its owner's level and ★, the cheap look.
	var looks: Array = []
	for rank in [[1, 0], [90, 0], [100, 300]]:
		var f := PetFollower.new()
		add_child(f)
		f.build("fire")
		var who := FakeOwner.new()
		who.member = {"name": "เจ้าของ", "level": int(rank[0]), "stars": int(rank[1])}
		add_child(who)
		f.attach(who)
		looks.append([f.stage, f.visual.scale.x, PetForm.layers(f.form_root)])
		who.free()
		f.queue_free()
	check(int(looks[0][0]) == 0 and is_equal_approx(float(looks[0][1]), PetData.STAGE_SCALE[0]) and (looks[0][2] as Array).is_empty(), "another player's pet takes its owner's form (Lv.1 owner -> young)")
	check(int(looks[2][0]) == 5 and is_equal_approx(float(looks[2][1]), PetData.STAGE_SCALE[5]), "a Lv.100 ★300 AI player's pet is in its god form")
	var cheap: Array = looks[2][2]
	check(cheap.has("PetAura") and cheap.has("GodHalo") and not cheap.has("Wings") and not cheap.has("Trail") and not cheap.has("Motes") and cheap.size() <= 3, "other players' pets wear the cheap look only (%s)" % str(cheap))
	var remote := NetOwner.new()
	remote.player = {"level": 100, "stars": 200}
	check(PetFollower.owner_rank(remote) == Vector2i(100, 200), "an online player's pet reads its level and ★ (%s)" % str(PetFollower.owner_rank(remote)))
	remote.free()
	# An AI player's fighting pet (lite): its member's level and ★.
	var ai := FakeOwner.new()
	ai.member = {"name": "เอไอ", "level": 100, "stars": 250, "class": "warrior"}
	add_child(ai)
	var lite := Pet.new()
	lite.setup_pet(ai, "water")
	add_child(lite)
	await get_tree().process_frame
	check(lite.lite and lite.stage == 4 and lite.owner_star == 250 and is_equal_approx(lite._visual.scale.x, PetData.STAGE_SCALE[4]), "an AI player's fighting pet takes its owner's level and ★ (form %d)" % lite.stage)
	var lite_layers := PetForm.layers(lite.form_root)
	check(lite_layers.has("PetAura") and lite_layers.has("Ring2") and not lite_layers.has("Wings") and not lite_layers.has("Crown"), "and wears the cheap look (%s)" % str(lite_layers))
	lite.queue_free()
	ai.free()
	hero.queue_free()
	GameSettings.quality = quality
	MemoryGuard.force(-1, get_tree())
	await get_tree().process_frame


## Sturdier pets: hits cut to PetData.TAKEN, and out of the fight it regains its HP.
func _toughness() -> void:
	var hero := _hero(60, "fire")
	var pet := _pet(hero)
	await get_tree().process_frame
	var full := pet.hp
	var raw := float(pet.max_hp) * 0.5
	pet.take_damage(raw)
	var expected := int(round(HeroStats.mitigate(raw, float(pet.pstats.def)) * PetData.TAKEN))
	check(full - pet.hp == maxi(1, expected), "a hit on the pet is cut to %d%% (%d)" % [int(PetData.TAKEN * 100.0), full - pet.hp])
	var low := pet.hp
	for i in int((PetData.REGEN_AFTER + 2.0) * 10.0):
		pet._process(0.1)
	check(pet.hp > low, "out of the fight it catches its breath (%d -> %d)" % [low, pet.hp])
	check(float(pet.max_hp) >= float(hero.stats.max_hp) * 0.99, "the fire pet has its hero's HP (%d vs %d)" % [pet.max_hp, int(hero.stats.max_hp)])
	pet.queue_free()
	hero.queue_free()
	await get_tree().process_frame


## It follows the hero, fights the monster near it, falls and comes back.
func _follow_fight_respawn() -> void:
	var hero := _hero(30, "fire")
	var pet := _pet(hero)
	await wait(0.3)
	check(pet.is_in_group("summons") and pet.is_in_group("pets"), "the pet joins the summons (monsters target it, buffs reach it)")
	check(int(pet.pstats.level) == 30 and pet.max_hp == int(round(float(hero.stats.max_hp) * 1.0)), "pet Lv.30 with 100% of the hero's HP")
	hero.global_position = Vector3(12, 0, 0)
	await wait(2.5)
	check(Vector2(pet.global_position.x - 12, pet.global_position.z).length() < 4.0, "the pet follows the hero (%.1f m away)" % Vector2(pet.global_position.x - 12, pet.global_position.z).length())
	hero.global_position = Vector3(-40, 0, 0)
	await wait(0.2)
	var gap := Vector2(pet.global_position.x - hero.global_position.x, pet.global_position.z - hero.global_position.z).length()
	check(gap < 4.0, "a pet left far behind hops back to the hero (%.1f m)" % gap)
	hero.global_position = Vector3.ZERO
	await wait(0.2)
	var mob := dummy(Vector3(4, 0, 2))
	await wait(4.0)
	check(mob.hits > 0 and pet.dealt > 0, "the pet fights a monster near the hero by itself (%d hits, %d damage)" % [mob.hits, pet.dealt])
	check(int(pet.casts.get("fireball", 0)) + int(pet.casts.get("flame_bite", 0)) + int(pet.casts.get("flame_breath", 0)) > 0, "it casts its unlocked skills by itself (%s)" % str(pet.casts))
	check(not pet.casts.has("inferno") and not pet.casts.has("rally"), "locked skills (Lv.50+) stay unused at Lv.30")
	pet.take_damage(1.0e9)
	check(pet.is_dead() and not pet.is_in_group("summons") and is_equal_approx(pet.respawn_left, PetData.RESPAWN) and PetData.RESPAWN == 30.0, "a fallen pet leaves the fight for 30 s")
	var hits_then := mob.hits
	await wait(1.5)
	check(mob.hits == hits_then, "a fallen pet does not fight")
	pet.respawn_left = 0.2
	await wait(0.6)
	check(not pet.is_dead() and pet.visible and pet.hp == pet.max_hp and pet.is_in_group("summons"), "it comes back with full health")
	mob.queue_free()
	pet.queue_free()
	hero.queue_free()
	await wait(0.2)


## Buffs on the hero go through its buff list (ally slot, Thai label); heals land.
func _owner_support() -> void:
	var hero := _hero(100, "water")
	var pet := _pet(hero)
	await wait(0.2)
	var skills := {}
	for s in PetData.get_pet("water").skills:
		skills[s.id] = s
	Game.profile.hp = int(hero.stats.max_hp * 0.4)
	var before := int(Game.profile.hp)
	pet.cast(skills.owner_heal)
	await wait(0.5)
	check(int(Game.profile.hp) > before, "ฮีลเจ้าของ heals the hero (%d -> %d)" % [before, Game.profile.hp])
	pet.cast(skills.water_shield)
	var shield := hero._buffs.filter(func(b): return String(b.skill_id) == "pet_water_water_shield")
	check(shield.size() == 1 and bool(shield[0].ally) and int(shield[0].get("shield_left", 0)) > 0 and String(shield[0].name) == "เกราะน้ำ · โกเลมน้ำแข็ง", "เกราะน้ำ is an ally buff with a shield and a Thai label")
	before = int(Game.profile.hp)
	Game.profile.hp = int(hero.stats.max_hp * 0.5)
	before = int(Game.profile.hp)
	pet.cast(skills.cleansing_rain)
	await wait(3.2)
	check(int(Game.profile.hp) > before, "ฝนชำระ heals the hero over time")
	pet.queue_free()
	hero.queue_free()
	await wait(0.1)
	hero = _hero(100, "fire")
	pet = _pet(hero)
	await wait(0.2)
	var atk_before := float(hero.stats.atk)
	var rally: Dictionary = PetData.get_pet("fire").skills[4]
	pet.cast(rally)
	check(float(hero.stats.atk) > atk_before * 1.05 and hero._buffs.any(func(b): return String(b.name) == "ปลุกพลัง · คาอิจูเร็กซ์" and bool(b.ally)), "ปลุกพลัง raises the hero's ATK as an ally buff (%.0f -> %.0f)" % [atk_before, hero.stats.atk])
	pet.queue_free()
	hero.queue_free()
	await wait(0.1)
	hero = _hero(100, "earth")
	pet = _pet(hero)
	await wait(0.2)
	pet.cast(PetData.get_pet("earth").skills[2])
	check(hero._buffs.any(func(b): return String(b.skill_id) == "pet_earth_stone_wall" and float(b.get("guard", 0.0)) > 0.0), "กำแพงหิน cuts the damage the hero takes (guard)")
	var mob := dummy(Vector3(3, 0, 0))
	pet._target = mob
	pet.cast(PetData.get_pet("earth").skills[6])
	check(pet._book.total("def") >= 0.5 and mob._victim == pet, "เกราะหิน hardens the pet and taunts monsters onto it")
	mob.queue_free()
	pet.queue_free()
	hero.queue_free()
	await wait(0.1)


## Every skill of every pet casts and the damaging ones hit (no element rules: the same
## dummy, whatever the element).
func _every_skill() -> void:
	for id in PetData.ORDER:
		var hero := _hero(100, id)
		var pet := _pet(hero)
		await wait(0.2)
		for skill in PetData.get_pet(id).skills:
			var mob := dummy(pet.global_position + Vector3(0, 0, 2.5))
			pet._target = mob
			pet.rotation.y = 0.0
			pet.cast(skill)
			await wait(1.8)
			if String(skill.kind) in ["bolt", "bite", "cone", "line", "blast", "pull", "nova"] or float(skill.get("power", 0.0)) > 0.0:
				check(mob.hits > 0, "%s: %s hits (%d)" % [id, skill.name, mob.hits])
			if (skill.get("fx", {}) as Dictionary).has("stun"):
				check(mob.stuns > 0, "%s: %s stuns" % [id, skill.name])
			mob.queue_free()
		pet.queue_free()
		hero.queue_free()
		await wait(0.1)


## The keeper's screen: three pets, a confirm step, then only the hero's own pet.
func _screen() -> void:
	Game.new_profile(&"warrior", "หน้าจอ")
	var screen := PetScreen.new()
	add_child(screen)
	screen.open_screen()
	check(screen.is_open and get_tree().paused, "the pet screen opens (and pauses)")
	screen.show_pet("earth")
	check(screen.shown == "earth" and not screen.confirming, "a tab shows another pet")
	var labels := screen.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	check(labels.any(func(t): return String(t).contains("ดรูอิดป่า")) and labels.any(func(t): return String(t).contains("Lv.100")), "the screen lists the pet and its skill levels")
	check(screen.find_children("*", "SubViewport", true, false).size() == 1, "one 3D preview")
	screen.ask_confirm()
	labels = screen.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	check(screen.confirming and labels.any(func(t): return String(t).contains("เลือกแล้วเปลี่ยนไม่ได้")), "the confirm step says the choice is final")
	check(screen.confirm_choice() and Game.pet_id() == "earth", "confirming chooses the pet")
	check(not screen.confirm_choice() and Game.pet_id() == "earth", "the screen cannot change it afterwards")
	screen.show_pet("fire")
	check(screen.shown == "earth", "after choosing, the screen shows only the hero's pet")
	screen.close_screen()
	check(not get_tree().paused, "closing unpauses")
	screen.queue_free()
	await wait(0.1)


## The village pen and keeper, the pet walking along in the village and fighting in a
## field, and no leaked nodes over zone changes.
func _village_and_zones() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await wait(0.2)
	if main.title_screen:
		main.title_screen.queue_free()
		main.title_screen = null
	Game.delete_save()
	Game.new_profile(&"warrior", "คอก")
	Game.profile.level = 30
	main.hud.visible = true
	main._traveling = false
	await main.go(&"town", true)
	await wait(0.5)
	var town: Zone = main.zone
	check(town.pet_pen != null and town.pet_pen.critters.size() == PetPen.PEN_PETS and PetPen.PEN_PETS == 10, "the pen holds ten pets")
	check(town.pet_pen.count_of("fire") >= 3 and town.pet_pen.count_of("water") >= 3 and town.pet_pen.count_of("earth") >= 3, "all three kinds wander in the pen")
	var inside := true
	for c in town.pet_pen.critters:
		var p: Vector3 = (c.body as Node3D).position
		inside = inside and absf(p.x) < PetPen.HALF.x and absf(p.z) < PetPen.HALF.y
	await wait(2.0)
	for c in town.pet_pen.critters:
		var p: Vector3 = (c.body as Node3D).position
		inside = inside and absf(p.x) < PetPen.HALF.x and absf(p.z) < PetPen.HALF.y
	check(inside, "the pen's pets stay inside the fence")
	var keeper: Npc = null
	for npc in town.npcs:
		if npc.role == "pet":
			keeper = npc
	check(keeper != null and keeper.display_name == "ผู้ดูแลสัตว์เลี้ยง", "the pet keeper stands in the village")
	if keeper:
		check(keeper.global_position.distance_to(PetPen.CENTER) < 10.0, "the keeper stands at the pen")
	check(town.pet == null, "no pet before one is chosen")
	# The starter quest guides the hero to the keeper: the "!" over it and the arrow.
	Game.profile.flags[Tutorial.FLAG] = Tutorial.DONE
	town.hero.global_position = JapanVillage.START + Vector3(0, 0.2, 0)
	await wait(1.2)
	check(keeper != null and keeper.marker.visible, "the pet keeper shows the quest mark")
	check(is_instance_valid(town.pet_quest_arrow) and town.pet_quest_arrow.visible, "an arrow points the hero to the keeper")
	if is_instance_valid(town.pet_quest_arrow):
		var way := (PetPen.KEEPER - town.hero.global_position).normalized()
		var arrow_dir := Vector3(sin(town.pet_quest_arrow.rotation.y), 0, cos(town.pet_quest_arrow.rotation.y))
		check(arrow_dir.dot(Vector3(way.x, 0, way.z).normalized()) > 0.95, "the arrow points at the keeper")
	# Talk to the keeper: the dialog, then the screen; choose the fire pet.
	main._on_npc("pet")
	check(main.dialog.is_open, "the keeper talks")
	main.dialog.close()
	main.pet_screen.open_screen()
	main.pet_screen.show_pet("fire")
	main.pet_screen.ask_confirm()
	check(main.pet_screen.confirm_choice(), "the hero chooses its pet at the keeper")
	main.pet_screen.close_screen()
	await wait(0.3)
	check(is_instance_valid(town.pet) and town.pet.pet_id == "fire", "the chosen pet comes out at once in the village")
	await wait(0.7)
	check(keeper != null and not keeper.marker.visible and not (is_instance_valid(town.pet_quest_arrow) and town.pet_quest_arrow.visible), "the quest mark and arrow go once the pet is chosen")
	main.hud._refresh()
	check(main.hud.pet_card_text().contains("คาอิจูเร็กซ์"), "the HUD shows the pet's chip (%s)" % main.hud.pet_card_text())
	# Zone changes: one pet each time, nothing left behind.
	var counts: Array[int] = []
	for round in 3:
		await main.go(&"meadow", true)
		await wait(1.5)
		var field: Zone = main.zone
		check(get_tree().get_nodes_in_group("pets").size() == 1 and is_instance_valid(field.pet), "round %d: one pet in the field" % round)
		await main.go(&"town", true)
		await wait(1.0)
		check(get_tree().get_nodes_in_group("pets").size() == 1, "round %d: one pet back in the village" % round)
		await wait(0.5)
		counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	check(counts[2] <= counts[1] + 60, "no nodes leak over zone changes (%s)" % str(counts))
	# In the field the pet fights the meadow's monsters.
	await main.go(&"meadow", true)
	await wait(0.6)
	var meadow: Zone = main.zone
	var hero: Hero = meadow.hero
	var near := dummy(hero.global_position + Vector3(3, 0, 3))
	near.reparent(meadow)
	await wait(4.0)
	check(is_instance_valid(meadow.pet) and meadow.pet.dealt > 0, "the pet fights in a field (%d damage)" % (meadow.pet.dealt if is_instance_valid(meadow.pet) else -1))
	# The ranked duel: no pet.
	await main.go(&"pvp", true, true)
	await wait(0.6)
	check(main.zone.pet == null and get_tree().get_nodes_in_group("pets").is_empty(), "no pet in a 1v1 duel")
	await main.go(&"town", true)
	await wait(0.3)
	# The god form over zone changes: its layers come and go with the pet, nothing left.
	Game.profile.level = 100
	Game.paragon().level = 300
	var god_counts: Array[int] = []
	for round in 3:
		await main.go(&"meadow", true)
		await wait(1.5)
		check(is_instance_valid(main.zone.pet) and main.zone.pet.stage == PetData.GOD_STAGE and main.zone.pet.form_root != null, "round %d: the god-form pet comes along dressed" % round)
		await main.go(&"town", true)
		await wait(1.5)
		check(VfxBudget._lights <= 1, "round %d: at most the pet's one light (%d)" % [round, VfxBudget._lights])
		god_counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	check(god_counts[2] <= god_counts[1] + 60, "the god form leaks no nodes over zone changes (%s)" % str(god_counts))
