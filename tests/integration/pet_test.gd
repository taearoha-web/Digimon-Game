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
	check(is_equal_approx(float(high.atk), float(high_owner.atk) * 0.40) and int(high.max_hp) == int(round(float(high_owner.max_hp) * 0.45)), "fire pet ATK 40%% / HP 45%% of the hero")
	for id in PetData.ORDER:
		var s := PetData.stats_for(id, high_owner, 80)
		check(float(s.atk) < float(high_owner.atk) * 0.5 and int(s.max_hp) <= int(high_owner.max_hp) * 0.7, "%s helps without out-hitting the hero" % id)
	check(not PetData.allowed_in(ZoneData.get_zone(&"pvp")) and not PetData.allowed_in(ZoneData.get_zone(&"guildwar")) and PetData.allowed_in(ZoneData.get_zone(&"tower")) and PetData.allowed_in(ZoneData.get_zone(&"meadow")) and PetData.allowed_in(ZoneData.get_zone(&"town")), "pets stay out of the guild war and 1v1 duels, nowhere else")


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


## It follows the hero, fights the monster near it, falls and comes back.
func _follow_fight_respawn() -> void:
	var hero := _hero(30, "fire")
	var pet := _pet(hero)
	await wait(0.3)
	check(pet.is_in_group("summons") and pet.is_in_group("pets"), "the pet joins the summons (monsters target it, buffs reach it)")
	check(int(pet.pstats.level) == 30 and pet.max_hp == int(round(float(hero.stats.max_hp) * 0.45)), "pet Lv.30 with 45% of the hero's HP")
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
