extends Node3D
var checks := 0
var failures := 0
var output := "/workspace/toon-artifacts/buffs-v076"
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
func settle() -> void:
	for i in 4:
		await get_tree().process_frame
func cast_buff(hero: Hero, id: String, ally := false) -> void:
	for family in ClassData.IDS:
		var skill := ClassData.find_skill(family, id)
		if not skill.is_empty():
			hero.receive_buff(skill.fx.buff, skill.color, skill.name, ally, id)
			return
func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.quality = 2
	Game.new_profile(&"mage", "Buff Identity QA", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.hp = 99999
	Game.profile.mp = 99999
	var list: Array[Dictionary] = []
	for ally in [false, true]:
		for id in (["a", "b"] if ally else ["a", "b", "x"]):
			list = BuffBook.insert(list, {"atk": 0.2, "def": 0.3, "speed": 0.1, "secs": 60}, Color.WHITE, id, ally, id, 100)
	check(list.size() == 5, "independent three self plus two friend slots")
	list = BuffBook.insert(list, {"atk": 0.6, "secs": 60}, Color.WHITE, "c", false, "c", 200)
	check(not BuffBook.contains(list, "a", false, 200) and BuffBook.contains(list, "a", true, 200), "fourth self removes only oldest self")
	list = BuffBook.insert(list, {"atk": 0.5, "secs": 60}, Color.WHITE, "c", true, "c", 300)
	check(BuffBook.contains(list, "a", true, 300) and BuffBook.contains(list, "c", true, 300) and BuffBook.group_count(list, true, 300) == 3, "friends' buffs have no limit: a third friend buff keeps the first two")
	for extra in ["f1", "f2", "f3"]:
		list = BuffBook.insert(list, {"atk": 0.1, "secs": 60}, Color.WHITE, extra, true, extra, 300)
	check(BuffBook.group_count(list, true, 300) == 6 and BuffBook.group_count(list, false, 300) == 3, "six friend buffs kept beside the three own slots")
	list = BuffBook.insert(list, {"atk": 0.5, "secs": 60}, Color.WHITE, "c", true, "c", 300)
	check(BuffBook.group_count(list, true, 300) == 6, "the same friend skill again refreshes, never doubles")
	list = list.filter(func(b): return not (bool(b.ally) and String(b.skill_id) in ["c", "f1", "f2", "f3"]))
	list = BuffBook.insert(list, {"atk": 0.9, "secs": 90}, Color.WHITE, "renamed", false, "b", 400)
	check(list.size() == 5 and list.back().until == 90400 and list.back().atk == 0.9, "refresh by stable skill id updates potency and duration once")
	list = BuffBook.insert(list, {"secs": 60}, Color.WHITE, "d", false, "d", 500)
	check(BuffBook.contains(list, "b", false, 500) and BuffBook.contains(list, "c", false, 500) and not BuffBook.contains(list, "x", false, 500), "refreshed skill becomes newest")
	list = BuffBook.insert(list, {"secs": 60}, Color.WHITE, "e", true, "e", 100000)
	check(list.size() == 1, "expired buffs removed before applying limits")
	# AI players bring three buff skills at most (the Defender's เบ่งเลือด always one).
	for cls in [&"warrior", &"archer", &"mage", &"priest", &"summoner", &"lancer", &"defender", &"assassin", &"darklord", &"bard"]:
		var kit := ClassData.ai_buff_kit(cls, 100, "QA Bot")
		# A class with skill lines: only each line's Lv.100 stage is cast, picked by line id.
		var buffs := ClassData.kit(cls, 100, 1 + JobData.adv_for_level(100)).filter(func(sk): return ClassData.is_buff_skill(sk) and int(sk.level) <= 100 and not sk.has("star"))
		# An AI Priest also keeps every heal that buffs (ClassData.AI_ALL_HEALS).
		var heal_buffs := buffs.filter(func(sk): return ClassData.AI_ALL_HEALS.has(cls) and sk.get("fx", {}).has("heal"))
		var picks := kit.filter(func(id): return not heal_buffs.any(func(sk): return ClassData.rank_id(sk) == id))
		check(picks.size() <= ClassData.AI_BUFF_SKILLS, "%s AI brings at most three buff skills: %s" % [cls, kit])
		check(picks.size() == mini(ClassData.AI_BUFF_SKILLS, buffs.size() - heal_buffs.size()), "%s AI fills its buff picks when it can: %s" % [cls, kit])
		for sk in heal_buffs:
			check(kit.has(ClassData.rank_id(sk)), "AI Priest keeps its heal-buff %s" % sk.id)
		for sk in buffs:
			check(ClassData.ai_allows(sk, kit) == kit.has(ClassData.rank_id(sk)), "%s AI casts only its picked buffs (%s)" % [cls, sk.id])
		check(kit == ClassData.ai_buff_kit(cls, 100, "QA Bot"), "%s AI pick is stable per player" % cls)
	check(ClassData.ai_buff_kit(&"defender", 100, "Anyone").has("brace"), "the Defender AI always brings เบ่งเลือด")
	check(ClassData.ai_heal_mult(&"priest") == 0.5 and ClassData.ai_heal_mult(&"warrior") == 1.0, "AI Priest heals at half strength, others in full")
	check(ClassData.pool(&"priest").any(func(sk): return sk.get("fx", {}).has("heal") and sk.get("fx", {}).get("buff") is Dictionary), "the Priest has heals that buff (the rule matters)")
	# The HUD lane overlaps icons once there are many (friends' buffs have no limit).
	check(TimerBars.stack_gap(2, 36.0, 3) == 3 and TimerBars.stack_gap(8, 36.0, 3) < 0, "many buff icons overlap in their lane")
	var lane_long := 36.0 + 7.0 * (36.0 + float(TimerBars.stack_gap(8, 36.0, 3)))
	check(lane_long <= 4.0 * 36.0, "eight buff icons take about three icons of room (%.0f px)" % lane_long)
	# Real hero path: stats, skill identities, aura lifetime and repeated casts.
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	cast_buff(hero, "silraphim")
	cast_buff(hero, "energy_shield")
	cast_buff(hero, "vague")
	cast_buff(hero, "holy_valor", true)
	cast_buff(hero, "forest_blessing", true)
	check(hero._buffs.size() == 5 and hero._auras.size() == 5, "five actual buffs produce five skill-specific auras")
	var old: BuffAura = hero._auras["silraphim:false"]
	cast_buff(hero, "magic_overdrive")
	check(old.is_queued_for_deletion() and not old.visible, "old art hidden immediately on replacement")
	check(not BuffBook.contains(hero._buffs, "silraphim", false), "old self stat entry is removed")
	var expected := Game.stats_now({"atk": BuffBook.stack([0.9, 0.4, 0.12]), "def": BuffBook.stack([0.6, 0.7, 0.3, 0.25]), "crit": 0.15, "speed": 0.2})
	check(hero.stats.atk == expected.atk and hero.stats.def == expected.def, "real computed stats exclude replaced buff and preserve ally effects")
	cast_buff(hero, "energy_shield", true)
	check(hero._buffs.size() == 6 and BuffBook.contains(hero._buffs, "energy_shield", false) and BuffBook.contains(hero._buffs, "energy_shield", true), "same skill from self and ally can coexist in separate groups")
	check(hero._auras.size() == 5 and not hero._auras.has("holy_valor:true"), "only the two newest friends' buffs wear body art (own three always)")
	cast_buff(hero, "energy_shield", true)
	check(hero._buffs.size() == 6, "same ally skill never duplicates across repeated casts")
	var buddy := Companion.new()
	buddy.hero = hero
	buddy.field = field
	buddy.stats = {"atk": 100.0}
	for id in ["silraphim", "energy_shield", "vague", "magic_overdrive"]:
		buddy._apply_self(ClassData.find_skill(&"mage", id))
	check(buddy._book.buffs.size() == 3 and not BuffBook.contains(buddy._book.buffs, "silraphim", false), "companion self casts also cap at three")
	check(BuffBook.group_count(hero._buffs, true) >= 3 and BuffBook.group_count(hero._buffs, false) == 3, "companion casts preserve the hero's own three slots")
	for id in ["forest_blessing", "spirit_link", "gaia_blessing"]:
		var skill := ClassData.find_skill(&"summoner", id)
		buddy.receive_party_buff(skill.fx.buff, skill.color, skill.name, id)
	check(buddy._book.buffs.size() == 6 and BuffBook.group_count(buddy._book.buffs, true) == 3, "companion keeps every friend's buff beside its own three")
	var incoming: Array = []
	for b in buddy._book.buffs:
		incoming.append(float(b.get("atk", 0.0)))
	check(is_equal_approx(buddy._buffed_atk(), 100 * (1 + BuffBook.stack(incoming))), "companion attack uses one common stack without duplicate multipliers")
	buddy.free()
	# Every authored buff has its own cached geometry and matching casting palette.
	var seen := {}
	var count := 0
	for family in ClassData.IDS:
		for skill in ClassData.pool(family):
			if not skill.get("fx", {}).has("buff"):
				continue
			count += 1
			var id := String(skill.id)
			check(BuffArt.RECIPES.has(id), "authored recipe " + id)
			var look := BuffArt.profile(skill)
			var mesh := BuffArt.mesh_for(look)
			check(mesh != null and mesh.get_surface_count() == 1, "one draw cached mesh " + id)
			check(mesh == BuffArt.mesh_for(look), "mesh reuse " + id)
			var fingerprint := hash(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
			check(not seen.has(fingerprint), "distinct silhouette " + id)
			seen[fingerprint] = true
			check(SkillShow.profile_for(skill).primary == look.primary, "cast/aura palette match " + id)
	# Skills that are in no skill line any more may keep their recipe.
	check(count <= BuffArt.RECIPES.size(), "complete buff catalog (%d buffs, %d recipes)" % [count, BuffArt.RECIPES.size()])
	await settle()
	# Five buffs here (three own, the two newest friends'); a Bard song adds one more lane of its own.
	check(VfxBudget.counters().decorations <= 5, "persistent hero art at most five draws plus one song")
	check(VfxBudget.counters().particles == 0 and VfxBudget.counters().lights == 0, "buff persistence adds no particles or lights")
	# HUD geometry at phone and desktop landscape aspect ratios.
	var hud := HUD.new()
	add_child(hud)
	hud.set_process(false)
	hud.hero = hero
	hud._timers.update_entries(hero.timer_status(), 0.1)
	var mob := Mob.new()
	mob.setup(&"forest_orc", 100, Vector3(3, 0, 0), hero)
	field.add_child(mob)
	mob.set_physics_process(false)
	hero.target = mob
	hud._refresh_target()
	hud._update_target_frame()
	for resolution in [Vector2i(1280, 720), Vector2i(1280, 590), Vector2i(1280, 960)]:
		get_window().size = resolution
		get_window().content_scale_size = resolution
		await settle()
		var status_rect: Rect2 = hud._name_label.get_parent().get_parent().get_parent().get_global_rect()
		var buffs_rect := hud._timers.get_global_rect()
		var target_rect := hud._target_panel.get_global_rect()
		check(buffs_rect.position.y >= status_rect.end.y, "buffs below own status " + str(resolution))
		check(target_rect.position.x > buffs_rect.end.x, "enemy bar separated from own buffs " + str(resolution))
		check(target_rect.end.x < resolution.x - 160, "enemy bar clear of minimap " + str(resolution))
		check(hud._timers._rows.self.get_child_count() == 4 and hud._timers._rows.ally.get_child_count() == 1 + BuffBook.group_count(hero._buffs, true), "label plus one chip per buff (own three, every friend buff)")
	var zone := Zone.new()
	hud.zone = zone
	mob.is_boss = true
	mob.hostile = true
	hud._update_boss_bar()
	check(hud._boss_panel.visible and not hud._target_panel.visible, "selected boss has only one central health bar")
	mob.is_boss = false
	hud._refresh_target()
	hud._update_boss_bar()
	check(not hud._boss_panel.visible and hud._target_panel.visible and hud._target_panel.offset_top == 8.0, "ordinary target returns to top row after boss")
	zone.free()
	hud.zone = null
	# Real-render evidence: character with four distinct buffs, HUD labels.
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(5, 5, 9)
	camera.look_at(Vector3(0, 1.1, 0))
	camera.make_current()
	Scenery.environment(self, Color("789bba"), Color("adc2c6"), Color("d9e5f0"), Color("ffe4bf"))
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	hud._name_label.text = "Buff Identity QA"
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("buff-hud.png"))
	hud.queue_free()
	mob.hide()
	await settle()
	camera.position = Vector3(3.8, 3.2, 5.7)
	camera.look_at(Vector3(0, 1.1, 0))
	for id in ["iron_resolve", "energy_shield", "godly_shield", "forest_blessing", "vague", "life_bloom"]:
		hero._buffs.clear()
		hero._sync_auras(Time.get_ticks_msec())
		cast_buff(hero, id)
		await get_tree().create_timer(0.8).timeout
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output.path_join(id + ".png"))
	for buff in hero._buffs:
		buff.until = 0
	hero._sync_auras(Time.get_ticks_msec())
	hero.refresh_stats()
	check(hero._auras.is_empty(), "expired art removed")
	check(hero.stats.atk == Game.stats_now().atk, "expired stats restored")
	field.queue_free()
	await field.tree_exited
	await settle()
	check(VfxBudget.counters().decorations == 0, "cleanup releases every buff reservation")
	print("BUFF IDENTITY: %s | %d checks, %d failures, %d authored buffs" % ["PASS" if failures == 0 else "FAIL", checks, failures, count])
	get_tree().quit(0 if failures == 0 else 1)
