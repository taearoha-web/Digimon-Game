extends Node3D
## The god-tier (300-star) skills: one per class, locked below 300 stars and usable
## at 300, the strongest multiplier of the class, an icon, its five contacts and the
## GodSkillArt roots on a real field at every quality, inside the VFX budget, with
## fewer roots under memory pressure and nothing left behind.
var checks := 0
var failures := 0

class Target:
	extends Mob
	var contacts := 0
	func take_hit(amount: int, crit: bool, color := Color.WHITE, attacker: Node = null) -> bool:
		contacts += 1
		return super.take_hit(amount, crit, color, attacker)


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", note)


func profile(cls: StringName, stars: int) -> void:
	Game.new_profile(cls, "God QA")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.paragon = {"level": stars, "points": stars, "spent": 0, "exp": 0, "alloc": {}}
	Game.profile.look = {"gender": 0}
	Game.profile.party = []
	Game.profile.equip = {}
	for slot in ItemData.EQUIP_SLOTS:
		Game.profile.equip[slot] = StarProgression.item(cls, 100 if slot == "wings" else 200, slot, Game.rng)
	Game.profile.hp = 100000
	Game.profile.mp = 100000
	# The Dark Lord's raven would add its own strikes to the counted contacts.
	if Game.profile.get("flags") is Dictionary:
		Game.profile.flags["raven_attack"] = 0


func god_of(cls: StringName) -> Dictionary:
	for skill in ClassData.pool(cls):
		if int(skill.get("star", 0)) >= StarSkillData.GOD_STAR:
			return skill
	return {}


func _ready() -> void:
	Game.set_process(false)
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	GameSettings.quality = 2
	ZoneData.ensure()
	_catalogue()
	_gates()
	await _casts()
	await _real_field()
	MemoryGuard.force(-1, get_tree())
	GameSettings.quality = 2
	Game.has_profile = false
	print("STAR 300 SKILLS: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(failures)


## One god skill per class, the strongest of its class, with name, shape, art, icon and sound.
func _catalogue() -> void:
	var names := {}
	for cls in ClassData.IDS:
		var gods := ClassData.pool(cls).filter(func(s): return int(s.get("star", 0)) >= StarSkillData.GOD_STAR)
		check(gods.size() == 1, "%s has exactly one 300-star skill (%d)" % [cls, gods.size()])
		var god := god_of(cls)
		if god.is_empty():
			continue
		check(int(god.star) == 300 and StarSkillData.is_god(god), "%s god skill unlocks at 300 stars" % cls)
		check(StarSkillData.pool(cls).size() == 5 and StarSkillData.pool(cls).back().id == god.id, "%s: five star skills, the god one last" % cls)
		check(String(god.name) != "" and not names.has(god.name), "%s god skill has its own name" % cls)
		names[god.name] = true
		# A Thai name and a Thai description (Thai block U+0E00..U+0E7F).
		var thai := func(text: String) -> bool:
			for i in text.length():
				if text.unicode_at(i) >= 0x0E00 and text.unicode_at(i) <= 0x0E7F:
					return true
			return false
		check(thai.call(String(god.name)) and thai.call(String(god.desc)), "%s god skill is named and described in Thai" % cls)
		check(String(god.shape) in ["blast", "burst"] and float(god.radius) >= 9.0, "%s god skill strikes a wide area" % cls)
		var star200: Dictionary = ClassData.pool(cls).filter(func(s): return int(s.get("star", 0)) == 200)[0]
		check(float(god.mult) > float(star200.mult), "%s god %.2f above its 200-star skill %.2f" % [cls, float(god.mult), float(star200.mult)])
		for skill in ClassData.pool(cls):
			if skill.id != god.id:
				check(float(god.mult) > float(skill.mult), "%s god %.2f is stronger than %s %.2f" % [cls, float(god.mult), skill.id, float(skill.mult)])
		check(float(god.mp) > float(star200.mp) and float(god.cd) > float(star200.cd), "%s god skill costs more MP and cooldown than 200 stars" % cls)
		check(ResourceLoader.exists("res://assets/icons/skills/%s.svg" % god.id), "icon file " + String(god.id))
		check(SkillIcons.for_skill(god) != null and SkillIcons.for_name(String(god.name)) == SkillIcons.for_skill(god), "icon loads " + String(god.id))
		check(StarSkillArt.handles(god) and GodSkillArt.handles(god), "god art handles " + String(god.id))
		check(SkillSound.cast(god) == SkillSound.cast(star200), "god skill uses the star wind-up sound " + String(god.id))
		check(SkillRank.table(god).size() >= 2, "Skill Master star table " + String(god.id))
		check(not BuffBook.is_song_skill(god) and not god.get("fx", {}).has("buff"), "the god skill is an attack, never a song " + String(god.id))
	check(names.size() == ClassData.IDS.size(), "ten god skills")


## Locked at 299 stars (press, loadout, rival), usable at 300.
func _gates() -> void:
	for cls in ClassData.IDS:
		var god := god_of(cls)
		if god.is_empty():
			continue
		profile(cls, 299)
		check(not Game.skill_unlocked(god), "%s locked at 299 stars" % cls)
		check(Game.skill_lock_reason(god).contains("300"), "%s lock reason names 300 stars" % cls)
		check(not ClassData.default_loadout(cls, 100, [], 5, 299).has(String(god.id)), "%s god skill stays off a 299-star bar" % cls)
		Game.paragon().level = 300
		check(Game.skill_unlocked(god), "%s unlocked at 300 stars" % cls)
		check(Game.skill_lock_reason(god) == "", "%s no lock reason at 300 stars" % cls)


func _hero_on(field: Node3D, cls: StringName) -> Array:
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	var target := Target.new()
	target.setup(&"dawn_stag", 100, Vector3(0, 0, 3), hero)
	target.position = Vector3(0, 0, 3)
	field.add_child(target)
	target.set_physics_process(false)
	target.hp = 100000000
	target.max_hp = target.hp
	hero.target = target
	return [hero, target]


## Real casts: refused at 299 stars, five contacts at 300 at every quality, the art
## roots appear (fewer under memory pressure), the budget holds and cleanup is total.
func _casts() -> void:
	for pressure in [0, 2]:
		MemoryGuard.force(pressure, get_tree())
		for quality in 3:
			GameSettings.quality = quality
			for cls in ClassData.IDS:
				var god := god_of(cls)
				if god.is_empty():
					continue
				profile(cls, 299)
				var field := Node3D.new()
				add_child(field)
				var pair := _hero_on(field, cls)
				var hero: Hero = pair[0]
				var target: Target = pair[1]
				hero._cast(god)
				check(hero.get_node_or_null("StarCast_" + String(god.id)) == null and int(Game.profile.mp) == 100000, "%s no cast and no MP spent at 299 stars" % cls)
				Game.paragon().level = 300
				hero._cast(god)
				var seq := hero.get_node_or_null("StarCast_" + String(god.id)) as StarSkillSequence
				check(seq != null, "%s god cast starts at 300 stars" % cls)
				if seq:
					check(field.get_node_or_null("StarGodGround_" + String(god.id)) != null, "%s ground sigil and pantheon during the wind-up" % cls)
					var sky := field.get_node_or_null("StarGodSky_" + String(god.id)) != null
					check(sky == (pressure == 0), "%s sky emblem q%d pressure %d" % [cls, quality, pressure])
					var avatar := false
					var temple := false
					var contact_ok := false
					var over_budget := 0
					var over_cap := 0
					var hp0 := target.hp
					# Real frames at triple speed: the art, tweens and timers age as in play.
					Engine.time_scale = 3.0
					var frames := 0
					while is_instance_valid(seq) and not seq.is_queued_for_deletion() and frames < 2000:
						await get_tree().process_frame
						frames += 1
						if int(VfxBudget.counters().decorations) > VfxBudget.decoration_limit():
							over_budget += 1
						avatar = avatar or field.get_node_or_null("StarGodAvatar_" + String(god.id)) != null
						temple = temple or field.get_node_or_null("StarGodTemple_" + String(god.id)) != null
						# Every root keeps the star layer cap; the contact roots (all but the
						# wind-up and the god extras) draw their beats.
						for node in field.get_children():
							var root := node as StarSkillArt
							if root == null:
								continue
							if root.layers.size() > [2, 4, 6][quality]:
								over_cap += 1
							if not String(root.name).begins_with("StarWindup") and not String(root.name).begins_with("StarGod") and not root.layers.is_empty():
								contact_ok = true
					Engine.time_scale = 1.0
					check(over_budget == 0, "%s decorations stay within the budget q%d pressure %d" % [cls, quality, pressure])
					check(target.contacts == StarSkillData.GOD_BEATS.size(), "%s five contacts q%d (%d)" % [cls, quality, target.contacts])
					check(target.hp < hp0, "%s god skill deals damage" % cls)
					check(avatar == (pressure == 0), "%s finale god avatar q%d pressure %d" % [cls, quality, pressure])
					check(temple == (pressure == 0 and quality == 2), "%s finale temple of pillars only at high quality q%d pressure %d" % [cls, quality, pressure])
					check(frames < 2000, "%s cast ends" % cls)
					check(contact_ok, "%s contact art drawn q%d" % [cls, quality])
					check(over_cap == 0, "%s every art root within the layer cap q%d" % [cls, quality])
				field.queue_free()
				await field.tree_exited
				await get_tree().process_frame
				check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "%s cast cleanup q%d pressure %d %s" % [cls, quality, pressure, VfxBudget.counters()])
	MemoryGuard.force(-1, get_tree())


## Each god skill in a real star field (a Zone), cast by the zone's own hero on its
## own monsters, played in real time; then the zone is left with nothing behind.
func _real_field() -> void:
	GameSettings.quality = 2
	for cls in ClassData.IDS:
		var god := god_of(cls)
		if god.is_empty():
			continue
		profile(cls, 300)
		Game.current_zone = &"eclipse_realm"
		var zone := Zone.new()
		zone.zone_id = &"eclipse_realm"
		add_child(zone)
		await get_tree().process_frame
		var hero := zone.hero
		var nearest: Mob = null
		for node in get_tree().get_nodes_in_group("mobs"):
			var mob := node as Mob
			if mob and not mob.is_dead() and (nearest == null or mob.global_position.distance_to(hero.global_position) < nearest.global_position.distance_to(hero.global_position)):
				nearest = mob
		if nearest:
			hero.global_position = nearest.global_position + Vector3(0, 0, 4)
			hero.target = nearest
		Game.profile.mp = 100000
		hero._cast(god)
		var seq := hero.get_node_or_null("StarCast_" + String(god.id)) as StarSkillSequence
		check(seq != null, "%s god cast in a real field" % cls)
		if seq:
			var end := seq.end
			await get_tree().create_timer(end + 0.3).timeout
			check(not is_instance_valid(seq), "%s real-field cast finished" % cls)
		zone.queue_free()
		await zone.tree_exited
		await get_tree().process_frame
		check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "%s real field leaves nothing behind %s" % [cls, VfxBudget.counters()])
