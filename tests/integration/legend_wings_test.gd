extends Node
## The Legendary Guild Wings (LegendWings, ปีกตำนานแห่งกิลด์): a season's close mints exactly
## one pair for the League Champion's leader (the hero when it leads); a streak week hands
## the new pair to a member (the hero as leader picks one in the guild screen, itself only
## while it holds none; an AI leader gives it to the strongest member without one, the
## hero among them by the same score); receiving wears it at once and it comes off only
## for another pair; it is never sold, traded or set out on a stall; it rides the shared
## storage to another character of any class and is worn from Lv.1; every stat beats the
## best 100★ pair at +15 and the aura lifts the wearer; the save and the item validate,
## a tampered pair is refused; the look is the gold pair with budget-safe sparkles.
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --path . res://tests/integration/legend_wings_test.tscn
var failures := 0
var checks := 0
var awarded: Array = []
const W0 := LegendWings.FROM_WEEK


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func pin(t: float) -> void:
	WorldPresence.clock_offset = t - WorldPlayers.now()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.set_process(false)
	GameSettings.load_settings()
	WorldEvents.festival_enabled = false
	WorldPlayers.clear_bonus()
	Game.legend_wings_awarded.connect(func(item: Dictionary, text: String): awarded.append({"item": item, "text": text}))
	_reset()
	_item_and_stats()
	_validation()
	_look()
	_hero_leader()
	await _streak_hero_picks()
	_ai_leader_and_hero()
	_refusals()
	_storage_other_class()
	await _league_view()
	WorldPresence.clock_offset = 0.0
	Game.has_profile = false
	print("LEGEND WINGS: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


## No hero, no saves, an empty shared storage.
func _reset() -> void:
	Game.has_profile = false
	for i in range(1, Game.SLOT_COUNT + 1):
		Game.delete_save(i)
	SharedStorage.items().clear()
	SharedStorage.migrated().clear()
	SharedStorage.store()
	Game.slot = 1
	awarded.clear()


## A Lv.100 hero with `stars` in guild g (at ★300 in the whole divine set at +10: as
## strong as anyone can be).
func _hero(g: int, stars := 300, cls := &"warrior", hero_name := "Legend QA") -> void:
	Game.new_profile(cls, hero_name, FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.paragon()["level"] = stars
	if stars >= Game.PARAGON_MAX:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for slot in DivineGearData.SLOTS:
			var piece := DivineGearData.item(Game.class_id(), slot, rng)
			piece["plus"] = 10
			Game.profile.equip[slot] = piece
	if g > 0:
		Game.join_guild(g)


## Guild g wins every round of season w on the hero's own record (GuildLeague.record_round):
## first place and the captures each round, so it is the League Champion for sure.
func _crown(g: int, w: int) -> void:
	pin(GuildLeague.week_start(w) + 3600.0)
	var others: Array = []
	for other in WorldPlayers.GUILDS:
		if other != g:
			others.append(other)
	for r in GuildLeague.schedule(w):
		GuildLeague.record_round([g] + others, [6, 0, 0, 0], [120, 10, 10, 10], 0, float(r.at), g)
	pin(GuildLeague.week_end(w) + 60.0)
	check(GuildLeague.league_champion_of(w, GuildLeague.real_wars(w)) == g, "%s is season %d's League Champion on the record" % [WorldPlayers.guild_name(g), w])


## Every pair the hero has anywhere (bag, worn, old storage) and the shared storage.
func _pairs() -> Array:
	var out: Array = []
	for piece in Game.profile.inv + Game.profile.storage + Game.profile.equip.values() + SharedStorage.items():
		if LegendWings.is_item(piece):
			out.append(piece)
	return out


func _item_and_stats() -> void:
	var pair := LegendWings.item(W0, WorldPlayers.ALPHA)
	check(LegendWings.is_item(pair) and int(pair.legend_week) == W0 and int(pair.legend_guild) == 1, "a pair carries its season and guild")
	check(int(pair.level) == 1 and String(pair["class"]) == "" and ItemData.gear_class(pair) == "", "Lv.1, locked to no class")
	check(String(pair.name).begins_with(LegendWings.NAME) and pair.name.contains("Alpha"), "named for the guild (%s)" % pair.name)
	check(ItemData.sell_price(pair) == 0 and ItemData.unit_sell_price(pair) == 0, "it has no sale price")
	check(ItemData.color_of(pair) == LegendWings.COLOR, "its own gold colour")
	check(ItemData.detail_lines(pair).any(func(l: String): return l.contains("ออร่าตำนาน")) and ItemData.detail_lines(pair).any(func(l: String): return l.contains("ถอดไม่ได้")), "the tooltip tells of the aura and the lock")
	check(ItemLook.look_of(pair).begins_with(LegendWings.LOOK), "its own look (%s)" % ItemLook.look_of(pair))
	# Every stat above the best 100★ pair of every class at the mythic roll's top and +15.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for cls in StarWingData.INFO:
		var star := StarWingData.item(String(cls), rng, 4)
		for key in StarWingData.INFO[cls].stats:
			var top: float = float(StarWingData.INFO[cls].stats[key][1]) * 1.08
			star.stats[key] = snappedf(top, 0.001) if key == "crit" else int(ceil(top))
		star["plus"] = ItemData.MAX_PLUS
		var best := HeroStats.gear_bonus({"equip": {"wings": star}, "class": String(cls)})
		var mine := HeroStats.gear_bonus({"equip": {"wings": pair}, "class": String(cls)})
		for key in star.stats:
			check(float(mine[key]) > float(best[key]), "%s: legend %s %.3f > best 100★ +15 %.3f" % [cls, key, float(mine[key]), float(best[key])])
	# The aura on the wearer: every stat a tenth more.
	Game.new_profile(&"mage", "Aura QA", FaceKit.default_look())
	var bare := HeroStats.compute(Game.profile)
	Game.profile.equip["wings"] = pair
	var worn := HeroStats.compute(Game.profile)
	check(bool(worn.legend_aura) and not bool(bare.get("legend_aura", false)), "the aura is on while worn")
	Game.profile.equip.erase("wings")
	var plain := ItemData.wings(rng, "mage", 4)
	plain["stats"] = pair.stats.duplicate()
	Game.profile.equip["wings"] = plain
	var same_stats := HeroStats.compute(Game.profile)
	for key in ["atk", "def", "max_hp", "max_mp"]:
		check(is_equal_approx(float(worn[key]) / maxf(1.0, float(same_stats[key])), 1.0 + LegendWings.AURA) or absf(float(worn[key]) - float(same_stats[key]) * (1.0 + LegendWings.AURA)) <= 2.0, "%s +%d%% over the same stats without the aura (%s vs %s)" % [key, int(LegendWings.AURA * 100.0), str(worn[key]), str(same_stats[key])])
	check(Game.equip_problem(pair) == "", "a Lv.1 mage may wear it")


func _validation() -> void:
	Game.new_profile(&"archer", "Valid QA", FaceKit.default_look())
	var pair := LegendWings.item(W0 + 2, WorldPlayers.TITAN)
	check(Game._valid_item(pair) and LegendWings.valid_item(pair), "a minted pair validates")
	for bad in [{"stats": {"atk": 9999}}, {"class": "mage"}, {"level": 100}, {"rarity": 3}, {"legend_week": W0 - 1}, {"legend_guild": 5}, {"wing": "darklord"}, {"star_tier": 100}, {"stats": {"speed": 1.0}}]:
		var copy := pair.duplicate(true)
		for key in bad:
			if key == "stats":
				copy.stats.merge(bad[key], true)
			else:
				copy[key] = bad[key]
		check(not Game._valid_item(copy), "a tampered pair is refused (%s)" % [bad])
	Game.profile.inv.append(pair)
	Game.profile.equip["wings"] = LegendWings.item(W0, WorldPlayers.ALPHA)
	Game.profile[LegendWings.KEY] = {"done": W0 + 1, "hold": {str(W0): {"g": 1, "n": "", "s": 1}, str(W0 + 1): {"g": 1, "n": "Kaito", "s": 2}}, "hand": {str(W0 + 1): "Kaito"}}
	check(Game._valid_profile(Game.profile.duplicate(true)), "a save with pairs and the record is valid")
	var json: Variant = JSON.parse_string(JSON.stringify(Game.profile))
	check(json is Dictionary and Game._valid_profile(json), "and after a JSON round trip")
	var fixed := Game._repair(json)
	check(fixed[LegendWings.KEY].done is int and fixed[LegendWings.KEY].hold[str(W0)].g is int and int(fixed.equip.wings.legend_week) == W0 and fixed.equip.wings.stats.atk is int, "the record and the pair come back as ints")
	check(Game.save_code_roundtrip(), "the save code round trip holds the pair")
	for bad in [{"done": "x"}, {"hold": {str(W0): {"g": 5, "n": "", "s": 1}}}, {"hold": {"abc": {"g": 1, "n": "", "s": 1}}}, {"hand": {str(W0): 5}}, {"other": 1}]:
		var broken: Dictionary = Game.profile.duplicate(true)
		broken[LegendWings.KEY] = bad
		check(not Game._valid_profile(broken), "a broken record is refused (%s)" % [bad])
	var dropped: Dictionary = Game.profile.duplicate(true)
	dropped[LegendWings.KEY] = {"done": "x"}
	LegendWings.repair(dropped)
	check(not dropped.has(LegendWings.KEY), "repair drops a broken record")


func _look() -> void:
	var pair := LegendWings.item(W0, WorldPlayers.LNW)
	GameSettings.quality = 2
	MemoryGuard.pressure = 0
	var art := LegendWingArt.build(pair)
	add_child(art)
	check(art.name.begins_with("Wings_legend_") and art is LegendWingArt, "its own built pair of wings, named as a pair (%s)" % art.name)
	var meshes := art.find_children("*", "MeshInstance3D", true, false)
	var gold := true
	var tris := 0
	for m in meshes:
		var mi := m as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			gold = gold and mi.get_surface_override_material(i) == LegendWingArt.material()
		gold = gold and bool(mi.get_meta("no_outline", false)) and mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tris += LegendWingMesh.triangles(mi.mesh)
	check(meshes.size() == 5 and gold, "two great wings, two lower wings and the halo in the one shared gold shader, no outline pass, no shadow (%d meshes)" % meshes.size())
	check(tris > 1500 and tris < 6000, "phone-sized: %d triangles" % tris)
	check(art.find_child("WingR", true, false).mesh == art.find_child("WingL", true, false).mesh and LegendWingMesh.wing() == art.find_child("WingR", true, false).mesh,
		"the left wing mirrors the right one's shared mesh")
	var rows := {}
	var arrays := LegendWingMesh.wing().surface_get_arrays(0)
	for uv2 in arrays[Mesh.ARRAY_TEX_UV2]:
		rows[int(floor((uv2 as Vector2).x))] = true
	check(rows.has(LegendWingMesh.ROW_PRIMARY) and rows.has(LegendWingMesh.ROW_SECONDARY) and rows.has(LegendWingMesh.ROW_COVERT), "three rows of feathers: primaries, secondaries, coverts")
	check(LegendWingMesh.halo(WorldPlayers.LNW) != LegendWingMesh.halo(WorldPlayers.TITAN), "the halo's gems wear the guild's colour")
	var player := art.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clips := true
	for clip in ["Idle", "Flap", "Glide", "Fold", "Unfold"]:
		clips = clips and player.has_animation(clip)
	check(clips and player.current_animation == "Idle", "it answers to the wing clips and idles")
	var open_basis: Basis = art.find_child("WingR", true, false).transform.basis
	art.fold = 1.0
	check(not art.find_child("WingR", true, false).transform.basis.is_equal_approx(open_basis), "folding moves the wings")
	art.fold = 0.0
	var motes := art.find_child("LegendSparkles", true, false) as CPUParticles3D
	check(motes != null and motes.amount <= LegendWingArt.SPARKLES, "drifting motes on the full quality setting, VfxBudget-sized")
	art.queue_free()
	MemoryGuard.pressure = 2
	var tight := LegendWingArt.build(pair)
	check(tight.find_child("LegendSparkles", true, false) == null, "no motes under memory pressure 2")
	tight.free()
	MemoryGuard.pressure = 0
	GameSettings.quality = 0
	var low := LegendWingArt.build(pair)
	check(low.find_child("LegendSparkles", true, false) == null, "no motes on the low quality setting")
	low.free()
	GameSettings.quality = 2
	var crowd := LegendWingArt.build(pair, true)
	check(crowd.find_child("LegendSparkles", true, false) == null, "the light dress of a crowd has none")
	crowd.free()
	var fresh := LegendWingArt.build(pair, false, true)
	add_child(fresh)
	check(fresh.fold > 0.5 and fresh.find_children("*", "CPUParticles3D", true, false).size() >= 2, "a fresh pair arrives folded and bursts open in gold")
	fresh.queue_free()
	for w in range(W0, W0 + LegendWings.MODELS.size()):
		check(LegendWings.MODELS.has(LegendWings.model_of(w)) and LegendWings.model_of(w) != "darklord", "season %d keeps a valid wing field" % w)


## Season one: the hero leads Alpha, Alpha is champion, the hero gets exactly one pair,
## worn at once over its old wings, for good.
func _hero_leader() -> void:
	_reset()
	_hero(WorldPlayers.ALPHA)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var old := StarWingData.item("warrior", rng, 4)
	Game.profile.equip["wings"] = old
	check(Game.hero_leads_guild(WorldPlayers.ALPHA), "the hero leads Alpha by default")
	_crown(WorldPlayers.ALPHA, W0)
	check(LegendWings.tick(), "the season's close mints the pair")
	var worn: Variant = Game.profile.equip.get("wings")
	check(LegendWings.is_item(worn) and int(worn.legend_week) == W0 and int(worn.legend_guild) == WorldPlayers.ALPHA, "the hero wears season %d's pair of Alpha" % W0)
	check(_pairs().size() == 1, "exactly one pair was minted (%d)" % _pairs().size())
	check(Game.profile.inv.has(old), "the old wings went to the bag")
	check(LegendWings.hold_of(W0) == {"g": WorldPlayers.ALPHA, "n": "", "s": 1}, "the record names the hero as the holder (%s)" % [LegendWings.hold_of(W0)])
	check(awarded.size() == 1 and awarded[0].text.contains("หัวหน้ากิลด์") and awarded[0].text.contains(LegendWings.LOCK_TEXT), "the letter popup came once, in Thai")
	check(not LegendWings.tick() and _pairs().size() == 1, "a second tick mints nothing more")
	check(LegendWings.line_now().contains("Alpha") and LegendWings.line_now().contains("(คุณ)"), "the line names Alpha and the hero (%s)" % LegendWings.line_now())
	# The lock: it never comes off, except for another pair.
	check(not Game.unequip("wings") and LegendWings.is_item(Game.profile.equip.get("wings")), "it cannot be taken off")
	var at: int = Game.profile.inv.find(old)
	check(at >= 0 and not Game.equip_from_bag(at) and LegendWings.is_item(Game.profile.equip.get("wings")) and Game.profile.inv.has(old), "other wings cannot replace it")
	var other := LegendWings.item(W0 + 5, WorldPlayers.TITAN)
	Game.profile.inv.append(other)
	check(Game.equip_from_bag(Game.profile.inv.find(other)) and Game.profile.equip.wings == other and Game.profile.inv.has(worn), "another pair of these wings replaces it, the first to the bag")
	Game.profile.inv.erase(other)
	Game.profile.inv.erase(worn)
	Game.profile.equip["wings"] = worn
	check(Game._valid_profile(Game.profile.duplicate(true)) and Game.save(), "the hero with its pair saves")
	# A full bag: the old wings go to the shared storage instead.
	var second := LegendWings.item(W0 + 6, WorldPlayers.ALPHA)
	while Game.profile.inv.size() < Game.bag_size():
		Game.profile.inv.append(ItemData.potion("hp_l", 1))
	LegendWings.give_to_hero(second)
	check(Game.profile.equip.wings == second and SharedStorage.items().has(worn) and not Game.profile.inv.has(worn), "with a full bag the replaced pair goes to the shared storage")
	SharedStorage.items().erase(worn)
	Game.profile.equip["wings"] = worn
	Game.profile.inv = Game.profile.inv.filter(func(i): return i.get("kind", "") == "equip")
	Game.save()


## Season two: Alpha champion again; the hero as leader must hand the new pair to a member
## in the guild screen (not itself: it holds one of this streak); the member then wears it
## for real (WorldGear) and the hero still has one pair.
func _streak_hero_picks() -> void:
	_crown(WorldPlayers.ALPHA, W0 + 1)
	check(not LegendWings.tick(), "a streak week waits for the leader's choice")
	var pending := LegendWings.pending()
	check(pending == {"w": W0 + 1, "g": WorldPlayers.ALPHA, "s": 2}, "season %d's pair is pending (%s)" % [W0 + 1, pending])
	var choices := LegendWings.hand_choices(W0 + 1)
	var close := GuildLeague.week_end(W0 + 1)
	check(choices.size() == WorldPlayers.members_at(WorldPlayers.ALPHA, close).size() and not choices.any(func(c): return bool(c.me)), "every Alpha member may be chosen, the hero (holding one) not")
	check(LegendWings.hand_to(W0 + 1, "") != "ok" and LegendWings.hand_to(W0 + 1, "ไม่มีคนนี้") != "ok", "itself and a stranger are refused")
	# The guild screen: the line, the button, the dialog, the choice.
	var screen := GuildScreen.new()
	add_child(screen)
	await _frames(1)
	screen.open_roster()
	await _frames(2)
	var line := screen.find_child("LegendLine", true, false) as Label
	check(line != null and line.text.contains("Alpha") and line.text.contains("(คุณ)"), "the guild screen shows this week's holder (%s)" % (line.text if line else "-"))
	var note := screen.find_child("LegendPending", true, false) as Label
	check(note != null and note.text.contains("ติดต่อกัน 2 สัปดาห์"), "and that the leader must hand the streak's pair on")
	var hand := screen.find_child("HandLegend", true, false) as Button
	check(hand != null, "the hand-on button is there")
	if hand == null:
		screen.queue_free()
		return
	hand.pressed.emit()
	await _frames(2)
	var picker := screen.find_child("LegendPicker", true, false)
	check(picker != null, "the Thai dialog opens")
	var buttons: Array = []
	if picker != null:
		for b in picker.find_children("Hand_*", "Button", true, false):
			buttons.append(b)
	check(buttons.size() == choices.size() and not buttons.any(func(b): return String(b.get_meta("pick")) == ""), "it lists the members, never the hero itself")
	var want := String(choices[0].name)
	var target: Button = null
	for b in buttons:
		if String(b.get_meta("pick")) == want:
			target = b
	check(target != null, "the strongest member is offered (%s)" % want)
	if target != null:
		target.pressed.emit()
		await _frames(2)
	check(LegendWings.hold_of(W0 + 1) == {"g": WorldPlayers.ALPHA, "n": want, "s": 2}, "the chosen member holds season %d's pair (%s)" % [W0 + 1, LegendWings.hold_of(W0 + 1)])
	check(LegendWings.pending().is_empty() and screen.find_child("LegendPicker", true, false) == null, "nothing pending, the dialog closed")
	check(_pairs().size() == 1 and int(Game.profile.equip.wings.legend_week) == W0, "the hero still has its one pair")
	var i := WorldPlayers.index_of(want)
	var t := WorldPresence.clock()
	var gear := WorldGear.gear(i, t)
	check(int(gear.wings.tier) == 3 and String(gear.wings.name).begins_with(LegendWings.NAME), "the member's real gear shows the pair (%s)" % [gear.wings])
	var equip := WorldGear.equip_at_work(i, WorldPlayers.work_at(i, t))
	check(LegendWings.is_item(equip.get("wings")) and int(equip.wings.legend_week) == W0 + 1, "and it wears the item itself")
	check(PlayerCard.gear_lines(i, t).contains(LegendWings.NAME), "the player card tells the truth")
	check(LegendWings.ai_holds(i) and WorldGear.signature_at_work(i, WorldPlayers.work_at(i, t)).contains("legend:%d" % (W0 + 1)), "the name plate tag and the dress signature know it")
	check(LegendWings.streak_holders().size() == 2 and LegendWings.line_now().contains("ติดต่อกัน 2 สัปดาห์"), "the streak reads two weeks")
	await _frames(1)
	line = screen.find_child("LegendLine", true, false) as Label
	check(line != null and line.text.contains(want), "the guild screen now names the member (%s)" % (line.text if line else "-"))
	screen.queue_free()
	await _frames(1)


## An AI leads Neverdie: season one the leader holds the pair; season two (a streak) the
## strongest member without one gets it — the hero when it is the strongest, with the
## letter; a weak hero is passed over for a world player: a real chance, never forced.
func _ai_leader_and_hero() -> void:
	_reset()
	_hero(WorldPlayers.NEVERDIE, 300, &"mage", "Strong QA")
	var close := GuildLeague.week_end(W0)
	var leader := WorldPlayers.guild_leader(WorldPlayers.NEVERDIE, close)
	check(Game.set_guild_leader(WorldPlayers.NEVERDIE, leader) and Game.guild_war_leader(WorldPlayers.NEVERDIE, close) == leader, "a member leads Neverdie (%s)" % leader)
	_crown(WorldPlayers.NEVERDIE, W0)
	check(LegendWings.tick() and LegendWings.hold_of(W0) == {"g": WorldPlayers.NEVERDIE, "n": leader, "s": 1}, "the AI leader holds season %d's pair (%s)" % [W0, LegendWings.hold_of(W0)])
	check(_pairs().is_empty() and awarded.is_empty(), "the hero got nothing")
	var li := WorldPlayers.index_of(leader)
	check(LegendWings.ai_holds(li) and int(WorldGear.gear(li, WorldPresence.clock()).wings.tier) == 3, "the leader's gear shows it")
	_crown(WorldPlayers.NEVERDIE, W0 + 1)
	var members := LegendWings.members(WorldPlayers.NEVERDIE, GuildLeague.week_end(W0 + 1))
	check(not members.is_empty() and String(members[0].name) == "", "the ★300 hero is the guild's strongest member")
	check(LegendWings.tick() and LegendWings.hold_of(W0 + 1) == {"g": WorldPlayers.NEVERDIE, "n": "", "s": 2}, "the leader hands the streak's pair to the hero (%s)" % [LegendWings.hold_of(W0 + 1)])
	check(LegendWings.is_item(Game.profile.equip.get("wings")) and int(Game.profile.equip.wings.legend_week) == W0 + 1 and _pairs().size() == 1, "worn at once, one pair")
	check(awarded.size() == 1 and awarded[0].text.contains("ติดต่อกัน 2 สัปดาห์") and awarded[0].text.contains(leader), "the letter names the leader who handed it on")
	check(LegendWings.ai_holds(li) and not LegendWings.ai_item(li).is_empty() and int(LegendWings.ai_item(li).legend_week) == W0, "the leader keeps its own first pair")
	# A weak hero: the strongest world member without a pair is chosen instead.
	_reset()
	_hero(WorldPlayers.NEVERDIE, 0, &"mage", "Weak QA")
	Game.set_guild_leader(WorldPlayers.NEVERDIE, leader)
	_crown(WorldPlayers.NEVERDIE, W0)
	LegendWings.tick()
	_crown(WorldPlayers.NEVERDIE, W0 + 1)
	members = LegendWings.members(WorldPlayers.NEVERDIE, GuildLeague.week_end(W0 + 1))
	var expected := ""
	for m in members:
		if String(m.name) != leader and String(m.name) != "" and expected == "":
			expected = String(m.name)
	check(String(members[0].name) != "" and expected != "", "a ★0 hero is not the strongest")
	check(LegendWings.tick() and LegendWings.hold_of(W0 + 1) == {"g": WorldPlayers.NEVERDIE, "n": expected, "s": 2}, "the strongest member without a pair gets it (%s)" % [LegendWings.hold_of(W0 + 1)])
	check(_pairs().is_empty() and awarded.is_empty(), "the weak hero got nothing: the chance is real, not forced")
	# Season three: the hero's guild lost; nothing for Neverdie, Titan's leader holds it.
	_crown(WorldPlayers.TITAN, W0 + 2)
	check(LegendWings.tick() and int(LegendWings.hold_of(W0 + 2).g) == WorldPlayers.TITAN and int(LegendWings.hold_of(W0 + 2).s) == 1 and LegendWings.hold_of(W0 + 2).n == WorldPlayers.guild_leader(WorldPlayers.TITAN, GuildLeague.week_end(W0 + 2)), "another champion starts its own streak with its leader")
	# One pair a season an account: a pair of season W0+3 already in the shared storage
	# (another character's) keeps this hero from a second one.
	Game.set_guild_leader(WorldPlayers.NEVERDIE, "")
	SharedStorage.items().append(LegendWings.item(W0 + 3, WorldPlayers.NEVERDIE))
	_crown(WorldPlayers.NEVERDIE, W0 + 3)
	check(LegendWings.tick() and LegendWings.hold_of(W0 + 3).n == "" and _pairs().size() == 1 and not LegendWings.is_item(Game.profile.equip.get("wings")), "a season's pair already on the account is not minted twice")
	SharedStorage.items().clear()


func _refusals() -> void:
	_reset()
	_hero(0, 0, &"lancer", "Refuse QA")
	var pair := LegendWings.item(W0, WorldPlayers.ALPHA)
	Game.profile.inv.append(pair)
	var at: int = Game.profile.inv.find(pair)
	var gold := int(Game.profile.gold)
	Game.sell_item(at)
	check(Game.profile.inv.has(pair) and int(Game.profile.gold) == gold, "the merchant refuses to buy it")
	check(not StallStock.sell(at) and Game.profile.inv.has(pair), "a stall keeper refuses to buy it")
	check(not StallStock.consign(at) and Game.profile.inv.has(pair), "and to take it on consignment")
	check(PlayerStall.list_item(at, 1000) == -1 and Game.profile.inv.has(pair) and PlayerStall.lots().is_empty(), "the hero's own stall refuses it")
	check(not OnlineTrade.tradable(pair), "a trade refuses it")
	check(Game.auto_sell_indices(31, 0).is_empty(), "the bulk sale leaves it")
	var toasts: Array = []
	var hook := func(text: String, _k: StringName): toasts.append(text)
	Game.toast.connect(hook)
	Game.sell_item(at)
	PlayerStall.list_item(at, 1000)
	Game.toast.disconnect(hook)
	check(toasts.has(LegendWings.SELL_TEXT) and toasts.has(LegendWings.STALL_TEXT), "each refusal is told in Thai (%s)" % [toasts])


## The pair rides the shared storage to a Lv.1 character of another class, who wears it.
func _storage_other_class() -> void:
	_reset()
	Game.slot = 1
	_hero(WorldPlayers.ALPHA, 300, &"warrior", "Depositor")
	var pair := LegendWings.item(W0, WorldPlayers.ALPHA)
	Game.profile.inv.append(pair)
	check(Game.deposit_item(Game.profile.inv.find(pair)) and SharedStorage.items().has(pair), "deposited in the shared storage")
	Game.save()
	Game.slot = 2
	Game.new_profile(&"priest", "Newcomer", FaceKit.default_look())
	check(int(Game.profile.level) == 1 and Game.storage_lock(pair) == "", "a Lv.1 priest may take it out (no class lock)")
	var index := SharedStorage.items().find(pair)
	check(index >= 0 and Game.withdraw_item(index) and Game.profile.inv.has(pair), "withdrawn")
	check(Game.equip_problem(pair) == "", "worn from Lv.1 by any class")
	check(Game.equip_from_bag(Game.profile.inv.find(pair)) and Game.profile.equip.wings == pair, "and worn")
	check(not Game.unequip("wings"), "locked on the newcomer too")
	check(Game._valid_profile(Game.profile.duplicate(true)) and Game.save(), "its save is valid")
	check(LegendWings.account_weeks().has(W0), "the account knows it holds season %d's pair" % W0)
	# One pair a character: a second pair only replaces the first.
	var second := LegendWings.item(W0 + 1, WorldPlayers.ALPHA)
	Game.profile.inv.append(second)
	check(Game.equip_from_bag(Game.profile.inv.find(second)) and Game.profile.equip.wings == second and Game.profile.inv.has(pair), "a second pair swaps in; one worn at a time")
	Game.slot = 1


func _league_view() -> void:
	_reset()
	_hero(WorldPlayers.ALPHA)
	_crown(WorldPlayers.ALPHA, W0)
	LegendWings.tick()
	var root := Control.new()
	root.size = Vector2(1280, 720)
	add_child(root)
	LeagueView.build(root, func(): pass)
	await _frames(1)
	var line := root.find_child("LegendLine", true, false) as Label
	check(line != null and line.text.begins_with("ปีกตำนานสัปดาห์นี้: กิลด์ Alpha → ") and line.text.contains("(คุณ)"), "the league view shows ปีกตำนานสัปดาห์นี้: <guild> → <holder> (%s)" % (line.text if line else "-"))
	root.queue_free()
