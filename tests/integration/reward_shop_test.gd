extends Node
## The reward exchange (RewardShop, RewardShopView, WalkTrail): league coins once a
## round the hero fought (never for a round watched or fought again) and once a week's
## placement bonus; event points from the world boss once a day and from kills in the
## event hours up to the daily cap; the catalogue's prices in both currencies and the
## weekly stone limits; unlocks and the wardrobe through the save code, the save
## validator and the repair; a costume dyes the hero visual and adds its accessory; the
## walk trail obeys VfxBudget and the quality / memory pressure; the name colour on the
## hero's plate and on a remote player's look; the world players' cosmetics by league
## standing; the page, the league card, the keeper and accounts.js accepting the profile.
##   godot --headless --path . res://tests/integration/reward_shop_test.tscn
var failures := 0
var checks := 0
const DAY := 86400.0
## Signal counters (a lambda's own copy of a local never reaches the test).
var _seen := 0
var _rebuilt := 0
var _asked := 0
var _host: Control


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func pin(t: float) -> void:
	WorldPresence.clock_offset = t - WorldPlayers.now()


## A Lv.100 hero in guild g.
func _hero(g := WorldPlayers.NEVERDIE) -> void:
	Game.new_profile(&"warrior", "Reward QA", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = 4
	if g > 0:
		Game.join_guild(g)


func _ready() -> void:
	WorldPlayers.clear_bonus()
	WorldEvents.festival_enabled = false
	GameSettings.load_settings()
	var w := GuildLeague.week_of(float(WorldPlayers.START_UNIX) + 21.0 * DAY)
	_coins(w)
	_week_bonus(w)
	_points(w)
	_catalogue()
	_buying(w)
	_persistence()
	await _costume()
	await _trail()
	await _hero_plate()
	await _remote()
	_world_players(w)
	await _page()
	_keeper()
	_server()
	WorldPresence.clock_offset = 0.0
	GameSettings.quality = 2
	MemoryGuard.pressure = 0
	print("REWARD SHOP: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _coins(w: int) -> void:
	_hero(WorldPlayers.NEVERDIE)
	check(RewardShop.coins() == 0 and RewardShop.points() == 0, "a new hero has no coins and no points")
	var at := GuildLeague.slot_start(WorldEvents.day_of(GuildLeague.week_start(w)) + 2, 1)
	pin(float(at) + GuildWarData.DURATION + 600.0)
	var own := GuildLeague.start_holder(at)
	# The hero's guild (team 0) captures twice and holds the castle at the bell: first place.
	GuildLeague.current_match = {"guilds": [2, 1, 3, 4], "at": at, "owner": own}
	GuildLeague.war_finished({"won": true}, true, [2, 0, 0, 0], 0, [40, 5, 3, 4])
	var want := RewardShop.PLACE_COINS[0] + 2 * RewardShop.CAPTURE_COINS + RewardShop.HOLD_COINS
	check(RewardShop.coins() == want, "first place with two captures and the castle pays %d (%d)" % [want, RewardShop.coins()])
	var e: Dictionary = GuildLeague.real_wars(w)[0]
	check(RewardShop.round_coins(e, WorldPlayers.NEVERDIE) == want and RewardShop.round_coins(e, WorldPlayers.ALPHA) == RewardShop.PLACE_COINS[1], "round_coins by placement for every guild")
	check(RewardShop.round_coins(e, 0) == 0 and RewardShop.round_coins(e, 9) == 0, "no coins for no guild")
	# Fighting the same round again earns nothing twice.
	GuildLeague.current_match = {"guilds": [2, 1, 3, 4], "at": at, "owner": own}
	GuildLeague.war_finished({"won": false}, true, [0, 3, 0, 0], 1, [2, 40, 3, 4])
	check(RewardShop.coins() == want, "the same round fought again pays nothing (%d)" % RewardShop.coins())
	check((RewardShop.data().paid as Dictionary).size() == 1, "one paid round")
	# Another round pays again; a watched round never pays.
	var at2 := GuildLeague.slot_start(WorldEvents.day_of(GuildLeague.week_start(w)) + 2, 2)
	pin(float(at2) + GuildWarData.DURATION + 600.0)
	GuildLeague.current_match = {"guilds": [2, 1, 3, 4], "at": at2, "owner": GuildLeague.start_holder(at2)}
	GuildLeague.war_finished({"won": false}, true, [0, 1, 0, 0], 1, [2, 30, 3, 4])
	var e2: Dictionary = GuildLeague.real_wars(w).filter(func(x): return int(x.at) == at2)[0]
	var second := RewardShop.round_coins(e2, WorldPlayers.NEVERDIE)
	check(second > 0 and second < RewardShop.PLACE_COINS[0] and RewardShop.coins() == want + second, "a second round pays its own coins (%d)" % second)
	var at3 := GuildLeague.slot_start(WorldEvents.day_of(GuildLeague.week_start(w)) + 3, 0)
	pin(float(at3) + GuildWarData.DURATION + 600.0)
	GuildLeague.spectated_result({"slot_start": at3, "league_round": [2, 1, 3, 4], "owner": 0}, {"captures": [3, 0, 0, 0], "score": [30, 1, 1, 1], "castle_owner": 0, "start_owner": 0})
	check(GuildLeague.real_wars(w).size() == 3 and RewardShop.coins() == want + second, "a round only watched is recorded but pays no coins")
	# An old two-guild war pays WIN / LOSS, captures and the castle.
	var old := {"at": 5, "a": 2, "b": 1, "win": 2, "ca": 1, "cb": 0, "held": 2, "ka": 10, "kb": 2}
	check(RewardShop.round_coins(old, 2) == RewardShop.WIN_COINS + RewardShop.CAPTURE_COINS + RewardShop.HOLD_COINS and RewardShop.round_coins(old, 1) == RewardShop.LOSS_COINS, "an old war's coins")
	# The paid list never grows past MAX_PAID.
	for k in RewardShop.MAX_PAID + 5:
		RewardShop.round_fought({"at": 1000 + k, "a": 2, "b": 1, "win": 2, "ca": 0, "cb": 0, "held": 0, "ka": 0, "kb": 0}, 2)
	check((RewardShop.data().paid as Dictionary).size() == RewardShop.MAX_PAID, "the paid rounds are capped at %d" % RewardShop.MAX_PAID)
	check(Game._valid_profile(Game.profile), "the profile with coins stays valid")


func _week_bonus(w: int) -> void:
	_hero(WorldPlayers.NEVERDIE)
	var at := GuildLeague.slot_start(WorldEvents.day_of(GuildLeague.week_start(w)) + 2, 1)
	pin(float(at) + GuildWarData.DURATION + 600.0)
	GuildLeague.current_match = {"guilds": [2, 1, 3, 4], "at": at, "owner": GuildLeague.start_holder(at)}
	GuildLeague.war_finished({"won": true}, true, [2, 0, 0, 0], 0, [40, 5, 3, 4])
	var fought := RewardShop.coins()
	# The week closes: the first look announces and pays the placement bonus once.
	pin(GuildLeague.week_start(w + 1) + 600.0)
	check(GuildLeague.tick(), "the first look after the week announces")
	var rank := GuildLeague.rank_of(w, GuildLeague.real_wars(w), WorldPlayers.NEVERDIE)
	var bonus := int(RewardShop.WEEK_BONUS[rank - 1])
	check(RewardShop.coins() == fought + bonus, "the week's placement bonus for rank %d pays %d once (%d -> %d)" % [rank, bonus, fought, RewardShop.coins()])
	check(not GuildLeague.tick() and RewardShop.week_closed(w) == 0 and RewardShop.coins() == fought + bonus, "never twice")
	check(RewardShop.week_closed(w - 1) == 0, "an older week pays nothing after a newer one was taken")
	# A hero who fought no round that week gets no bonus.
	_hero(WorldPlayers.ALPHA)
	pin(GuildLeague.week_start(w + 1) + 600.0)
	GuildLeague.tick()
	check(RewardShop.coins() == 0 and int(RewardShop.data().get("bonus_week", -1)) == w, "no bonus without a round fought, the week still marked")
	_hero(0)
	check(RewardShop.week_closed(w) == 0, "no bonus outside a guild")


func _points(w: int) -> void:
	_hero(WorldPlayers.NEVERDIE)
	var day_start := GuildLeague.week_start(w) + 2.0 * DAY
	var boss_time := day_start + float(WorldEvents.BOSS_START) + 300.0
	pin(boss_time)
	Game.emit_signal("world_boss_defeated", &"meadow")
	check(RewardShop.points() == RewardShop.BOSS_EP, "the world boss pays %d points (%d)" % [RewardShop.BOSS_EP, RewardShop.points()])
	Game.emit_signal("world_boss_defeated", &"meadow")
	check(RewardShop.points() == RewardShop.BOSS_EP, "once a day")
	pin(boss_time + DAY)
	check(RewardShop.boss_defeated() == RewardShop.BOSS_EP and RewardShop.points() == 2 * RewardShop.BOSS_EP, "the next day's boss pays again")
	# Kills: nothing at noon, KILL_EP each in the evening EXP x2, KILL_CAP a day.
	var before := RewardShop.points()
	pin(day_start + 12.0 * 3600.0)
	check(RewardShop.kill() == 0 and RewardShop.points() == before, "a kill at noon earns no points")
	var evening := day_start + float(WorldEvents.EXP_START) + 600.0
	pin(evening)
	check(WorldEvents.evening_exp(evening) and RewardShop.event_hours(evening), "19:10 Thai time is in the event hours")
	check(RewardShop.kill_left() == RewardShop.KILL_CAP, "the whole cap is left")
	Game.report_kill(&"slime")
	check(RewardShop.points() == before + RewardShop.KILL_EP, "a kill in the event hours pays %d through Game.report_kill" % RewardShop.KILL_EP)
	for k in RewardShop.KILL_CAP + 20:
		RewardShop.kill()
	check(RewardShop.points() == before + RewardShop.KILL_CAP and RewardShop.kill_left() == 0, "capped at %d a day (%d)" % [RewardShop.KILL_CAP, RewardShop.points() - before])
	pin(evening + DAY)
	check(RewardShop.kill_left() == RewardShop.KILL_CAP and RewardShop.kill() == RewardShop.KILL_EP, "the cap resets the next day")
	# The festival counts as event hours too.
	WorldEvents.festival_enabled = true
	pin(float(WorldEvents.FESTIVAL_START) + 3600.0 * 3.0)
	check(RewardShop.event_hours(WorldPresence.clock()) and RewardShop.kill() == RewardShop.KILL_EP, "a festival kill pays")
	WorldEvents.festival_enabled = false
	check(Game._valid_profile(Game.profile), "the profile with points stays valid")


func _catalogue() -> void:
	check(RewardShop.COSTUMES.size() >= 6, "six or more costumes (%d)" % RewardShop.COSTUMES.size())
	check(RewardShop.TRAILS.size() >= 4, "four or more walk trails (%d)" % RewardShop.TRAILS.size())
	check(RewardShop.NAME_COLORS.size() >= 4, "four or more name colours (%d)" % RewardShop.NAME_COLORS.size())
	var both := 0
	var ids := {}
	for tab in ["costume", "trail", "ncol"]:
		for id in RewardShop.catalog(tab):
			var e: Dictionary = RewardShop.catalog(tab)[id]
			check(not ids.has(id), "cosmetic ids are unique (%s)" % id)
			ids[id] = true
			check(int(e.get("lc", 0)) + int(e.get("ep", 0)) > 0 and String(e.name) != "", "%s %s has a price and a Thai name" % [tab, id])
			check(RewardShop.tab_of(String(id)) == tab, "tab_of(%s) = %s" % [id, tab])
			if int(e.get("lc", 0)) > 0 and int(e.get("ep", 0)) > 0:
				both += 1
	check(both >= 4, "some items need both currencies (%d)" % both)
	for e in RewardShop.STONES:
		var item := RewardShop.stone_item(e)
		check(Game._valid_item(item) and ItemData.is_stackable(item), "stone %s is a real stack item" % String(e.id))
		check(int(e.limit) >= 1 and int(e.limit) <= 3 and int(e.get("lc", 0)) + int(e.get("ep", 0)) >= 40, "stone %s is limited and not cheap" % String(e.id))
		check(RewardShop.name_of("stone", String(e.id)).contains("×"), "stone name with its count (%s)" % RewardShop.name_of("stone", String(e.id)))
	check(RewardShop.price_text({"lc": 300, "ep": 60}) == "300 %s + 60 %s" % [RewardShop.COIN_NAME, RewardShop.POINT_NAME], "the price text names both currencies")
	check(RewardShop.entry("costume", "nope").is_empty() and RewardShop.problem("costume", "nope") != "", "an unknown item cannot be bought")
	for tab in RewardShop.TABS:
		check(RewardShop.TABS.size() == 4 and String(tab[1]) != "", "four tabs with Thai names")


func _buying(w: int) -> void:
	_hero(WorldPlayers.NEVERDIE)
	pin(GuildLeague.week_start(w) + 3.0 * DAY)
	var c: Dictionary = RewardShop.COSTUMES["kitsune"]
	check(RewardShop.problem("costume", "kitsune") == "%sไม่พอ" % RewardShop.COIN_NAME, "no coins: cannot buy (%s)" % RewardShop.problem("costume", "kitsune"))
	RewardShop.add_coins(int(c.lc))
	check(RewardShop.problem("costume", "kitsune") == "%sไม่พอ" % RewardShop.POINT_NAME, "coins alone are not enough for an item that needs points")
	RewardShop.add_points(int(c.ep) + 5)
	check(RewardShop.buy("costume", "kitsune") == "ok", "bought the costume")
	check(RewardShop.coins() == 0 and RewardShop.points() == 5, "both prices paid (%d / %d)" % [RewardShop.coins(), RewardShop.points()])
	check(RewardShop.owns("kitsune") and RewardShop.active("costume") == "kitsune", "owned and worn at once (nothing was worn)")
	check(RewardShop.buy("costume", "kitsune") == "มีแล้ว", "an owned cosmetic is never sold twice")
	RewardShop.add_coins(5000)
	RewardShop.add_points(5000)
	check(RewardShop.buy("costume", "sakura") == "ok" and RewardShop.active("costume") == "kitsune", "a second costume is owned, the first stays on")
	_seen = 0
	Game.cosmetics_changed.connect(_count_seen)
	check(RewardShop.wear("costume", "sakura") == "ok" and RewardShop.active("costume") == "sakura" and _seen == 1, "the wardrobe switches the costume and tells the hero")
	check(RewardShop.wear("costume", "royal") != "ok" and RewardShop.active("costume") == "sakura", "a costume not owned cannot be worn")
	check(RewardShop.wear("costume", "") == "ok" and RewardShop.active("costume") == "" and _seen == 2, "taken off")
	check(RewardShop.wear("costume", "") == "ok" and _seen == 2, "taking off nothing says nothing")
	Game.cosmetics_changed.disconnect(_count_seen)
	check(RewardShop.buy("trail", "sparkle") == "ok" and RewardShop.active("trail") == "sparkle", "a trail")
	check(RewardShop.buy("ncol", "sunset") == "ok" and RewardShop.active("ncol") == "sunset", "a name colour")
	check(RewardShop.wear("trail", "sunset") != "ok", "a colour is not a trail")
	# Stones: the item lands in the bag, the weekly limit holds, the week resets it.
	var coins := RewardShop.coins()
	var purple := Game.jewel_count("purple")
	check(RewardShop.buy("stone", "purple5") == "ok" and Game.jewel_count("purple") == purple + 5 and RewardShop.coins() == coins - 40, "five purple jewels for 40 coins")
	check(RewardShop.bought("purple5") == 1, "counted this week")
	check(RewardShop.buy("stone", "purple5") == "ok" and RewardShop.buy("stone", "purple5") == "ok", "up to the limit")
	check(RewardShop.buy("stone", "purple5").begins_with("แลกครบ") and Game.jewel_count("purple") == purple + 15, "the fourth is refused")
	check(RewardShop.buy("stone", "ruby2") == "ok", "a large ruby for points")
	var rubies: Array = Game.profile.inv.filter(func(it): return it.get("kind") == "gem" and String(it.id) == "ruby_2")
	check(rubies.size() == 1 and int(rubies[0].count) == 1, "the ruby is in the bag")
	check(RewardShop.buy("stone", "ruby2") != "ok", "one ruby a week")
	pin(GuildLeague.week_start(w + 1) + 3.0 * DAY)
	check(RewardShop.bought("purple5") == 0 and RewardShop.problem("stone", "purple5") == "", "a new week resets the limits")
	check(RewardShop.buy("stone", "purple5") == "ok" and RewardShop.bought("purple5") == 1 and RewardShop.bought("ruby2") == 0, "the new week's counts start over")
	# Nothing from the shop can be sold: gems and jewels in the bag are the forge's.
	check(ItemData.sell_price(ItemData.gem("ruby", 2)) >= 0 and not RewardShop.COSTUMES.has("sell"), "cosmetics are not items at all")
	check(Game._valid_profile(Game.profile), "the profile after buying stays valid")


func _count_seen() -> void:
	_seen += 1


func _count_asked() -> void:
	_asked += 1


## The page's refresh: rebuilds it in place (what the menu does after a buy).
func _rebuild_page() -> void:
	_rebuilt += 1
	UIUtil.clear(_host)
	RewardShopView.build(_host, _rebuild_page)


func _persistence() -> void:
	var code := Game.export_code()
	var own: Array = (Game.profile[RewardShop.KEY].own as Array).duplicate()
	var coins := RewardShop.coins()
	Game.new_profile(&"mage", "อื่น", FaceKit.default_look())
	check(RewardShop.coins() == 0 and not RewardShop.owns("kitsune"), "a new hero owns nothing")
	check(Game.import_code(code), "the save code imports")
	check(RewardShop.coins() == coins and (Game.profile[RewardShop.KEY].own as Array) == own, "coins and unlocks survive the save code")
	check(RewardShop.active("trail") == "sparkle" and RewardShop.active("ncol") == "sunset" and RewardShop.active("costume") == "", "what is worn survives")
	check(Game.save_code_roundtrip(), "the save round-trips")
	# Broken records are refused; a repair drops unknown ids and clears what is not owned.
	var copy: Dictionary = Game.profile.duplicate(true)
	for bad in [[], {"junk": 1}, {"lc": -5}, {"lc": "x"}, {"own": "sakura"}, {"own": [1]}, {"cos": 7}, {"buy": {"purple5": 1001}}, {"paid": []}]:
		copy[RewardShop.KEY] = bad
		check(not RewardShop.valid(bad) and not Game._valid_profile(copy), "a broken record is refused (%s)" % [bad])
	var loose := {"lc": 12.0, "ep": 3.0, "own": ["sakura", "nope", "sakura"], "cos": "royal", "trail": "", "ncol": "x", "buy": {"purple5": 2.0}, "paid": {"5": 1.0}}
	var p := {RewardShop.KEY: loose}
	RewardShop.repair(p)
	var r: Dictionary = p[RewardShop.KEY]
	check(r.lc is int and r.lc == 12 and r.own == ["sakura"] and r.cos == "" and r.ncol == "" and r.buy.purple5 is int and r.paid["5"] is int, "repair: ints back, unknown ids and unowned wear dropped (%s)" % [r])
	var broken := {RewardShop.KEY: {"lc": -9}}
	RewardShop.repair(broken)
	check(not broken.has(RewardShop.KEY), "an invalid record is dropped on repair")
	check(RewardShop.valid({}) and RewardShop.valid({"lc": 0, "ep": 0, "own": [], "cos": "", "trail": "", "ncol": "", "buy": {}, "paid": {}}), "the empty and the fresh record are valid")


func _body_material(v: HeroVisual) -> ShaderMaterial:
	for node in v.model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.skin != null and mi.material_override is ShaderMaterial:
			return mi.material_override
	return null


func _costume() -> void:
	var v := HeroVisual.new()
	add_child(v)
	v.costume = "royal"
	v.setup(&"warrior", "", true, {}, FaceKit.default_look())
	await get_tree().process_frame
	var mat := _body_material(v)
	var cloth: Color = RewardShop.COSTUMES.royal.cloth
	check(mat != null and mat.get_shader_parameter("outfit_color") == cloth, "the costume dyes the chibi outfit")
	check(float(mat.get_shader_parameter("outfit_amount")) > 0.9 and mat.get_shader_parameter("glow_color") == RewardShop.COSTUMES.royal.glow, "with its sheen and glow")
	var acc := v.model.find_child("ChibiCostume", true, false)
	check(acc != null and acc.get_child_count() > 0, "the costume's head accessory is built (crown)")
	# Over armour the costume still wins; taking it off brings the armour's cloth back.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var armor := ItemData.generate(60, &"warrior", rng, 2, "armor")
	v.set_equipment({"armor": armor})
	await get_tree().process_frame
	mat = _body_material(v)
	check(mat.get_shader_parameter("outfit_color") == cloth, "the costume dyes over armour too")
	v.set_costume("")
	await get_tree().process_frame
	mat = _body_material(v)
	check(mat.get_shader_parameter("outfit_color") == ChibiGear.cloth(ItemLook.tier_of(armor)), "without the costume the armour's cloth shows")
	check(v.model.find_child("ChibiCostume", true, false) == null, "and the accessory is gone")
	# Every costume renders on every class body with its own accessory.
	for id in RewardShop.COSTUMES:
		v.set_costume(String(id))
		check(v.model.find_child("ChibiCostume", true, false) != null and _body_material(v).get_shader_parameter("outfit_color") == RewardShop.COSTUMES[id].cloth, "costume %s renders" % id)
	v.set_costume("sakura")
	for cls in [&"mage", &"priest", &"bard"]:
		var other := HeroVisual.new()
		add_child(other)
		other.costume = "sakura"
		var girl := FaceKit.default_look()
		girl["gender"] = 1
		other.setup(cls, "", true, {}, girl)
		check(_body_material(other).get_shader_parameter("outfit_color") == RewardShop.COSTUMES.sakura.cloth, "costume on a %s" % cls)
		other.queue_free()
	v.queue_free()
	await get_tree().process_frame


func _trail() -> void:
	var body := Node3D.new()
	add_child(body)
	GameSettings.quality = 2
	MemoryGuard.pressure = 0
	var base := int(VfxBudget.counters().particles)
	var t := WalkTrail.attach(body, "sparkle")
	await get_tree().process_frame
	check(t != null and WalkTrail.worn(body) == "sparkle", "a trail at full quality")
	var emitter := body.get_node_or_null("WalkTrail/Emitter") as CPUParticles3D
	check(emitter != null and emitter.amount <= WalkTrail.PARTICLES and int(VfxBudget.counters().particles) == base + emitter.amount, "its particles come from VfxBudget (%d)" % (emitter.amount if emitter else -1))
	check(emitter != null and not emitter.emitting, "standing still it emits nothing")
	t._process(0.1)
	body.global_position += Vector3(0.5, 0, 0)
	t._process(0.1)
	check(emitter.emitting, "walking it emits")
	t._process(0.1)
	check(not emitter.emitting, "stopping it stops")
	check(WalkTrail.attach(body, "petal") != null and WalkTrail.worn(body) == "petal" and body.get_children().filter(func(n): return n is WalkTrail).size() == 1, "a new trail replaces the old one")
	WalkTrail.detach(body)
	await get_tree().process_frame
	check(WalkTrail.worn(body) == "" and int(VfxBudget.counters().particles) == base, "detached: the budget comes back (%d / %d)" % [VfxBudget.counters().particles, base])
	for id in RewardShop.TRAILS:
		check(WalkTrail.attach(body, String(id)) != null, "trail %s builds" % id)
	WalkTrail.detach(body)
	check(WalkTrail.attach(body, "nope") == null and WalkTrail.attach(body, "") == null, "an unknown or empty trail builds nothing")
	GameSettings.quality = 0
	check(not WalkTrail.allowed() and WalkTrail.attach(body, "sparkle") == null and WalkTrail.worn(body) == "", "no trail at the low quality setting")
	GameSettings.quality = 2
	MemoryGuard.pressure = 2
	check(not WalkTrail.allowed() and WalkTrail.attach(body, "flame") == null, "no trail under memory pressure")
	MemoryGuard.pressure = 0
	check(WalkTrail.allowed(), "allowed again")
	body.queue_free()
	await get_tree().process_frame


func _hero_plate() -> void:
	_hero(WorldPlayers.ALPHA)
	RewardShop.add_coins(5000)
	RewardShop.add_points(5000)
	RewardShop.buy("ncol", "rose")
	RewardShop.buy("costume", "midnight")
	RewardShop.buy("trail", "star")
	var field := Node3D.new()
	field.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	await get_tree().process_frame
	check(hero._name_plate.modulate == RewardShop.NAME_COLORS.rose.color and hero._name_plate.outline_modulate == RewardShop.NAME_COLORS.rose.edge, "the hero's plate wears the name colour")
	check(hero.visual.costume == "midnight" and _body_material(hero.visual).get_shader_parameter("outfit_color") == RewardShop.COSTUMES.midnight.cloth, "the hero wears its costume")
	check(WalkTrail.worn(hero) == "star", "the hero has its trail")
	RewardShop.wear("ncol", "")
	RewardShop.wear("costume", "")
	RewardShop.wear("trail", "")
	await get_tree().process_frame
	check(hero._name_plate.modulate == Color("fff4de") and hero.visual.costume == "" and WalkTrail.worn(hero) == "", "taken off everywhere at once")
	RewardShop.wear("ncol", "rose")
	check(hero._name_plate.modulate == RewardShop.NAME_COLORS.rose.color, "put on again")
	var look := Game.hero_look()
	check(String(look.ncol) == "rose" and String(look.cos) == "" and String(look.trail) == "", "the look sent online carries what is worn")
	field.queue_free()
	await get_tree().process_frame


func _remote() -> void:
	GameSettings.quality = 2
	MemoryGuard.pressure = 0
	var clean := PlayerLook.clean({"class": "mage", "cos": "sakura", "trail": "sparkle", "ncol": "rose"})
	check(String(clean.cos) == "sakura" and String(clean.trail) == "sparkle" and String(clean.ncol) == "rose", "a clean look keeps known cosmetics")
	var dirty := PlayerLook.clean({"class": "mage", "cos": "nope", "trail": 5, "ncol": "x".repeat(99)})
	check(String(dirty.cos) == "" and String(dirty.trail) == "" and String(dirty.ncol) == "", "unknown ones become nothing")
	var field := Node3D.new()
	add_child(field)
	var remote := RemotePlayer.new()
	remote.setup({"id": "901", "name": "RealOne", "pos": [1.0, 0.0, 1.0], "look": {"class": "mage", "cos": "sakura", "trail": "sparkle", "ncol": "rose"}})
	field.add_child(remote)
	await get_tree().process_frame
	check(remote.visual.costume == "sakura" and _body_material(remote.visual).get_shader_parameter("outfit_color") == RewardShop.COSTUMES.sakura.cloth, "a remote player wears the costume its look says")
	check(WalkTrail.worn(remote) == "sparkle", "and its trail")
	check(remote._label.modulate == RewardShop.NAME_COLORS.rose.color, "and its name colour")
	remote.apply_look({"class": "mage", "ncol": "sky", "trail": ""})
	check(remote._label.modulate == RewardShop.NAME_COLORS.sky.color and WalkTrail.worn(remote) == "" and remote.visual.costume == "", "a new look changes them")
	remote.set_party(true)
	check(remote._label.modulate == RemotePlayer.PARTY_COLOR, "the party's green still wins")
	field.queue_free()
	await get_tree().process_frame


func _world_players(w: int) -> void:
	_hero(WorldPlayers.NEVERDIE)
	var t := GuildLeague.week_start(w + 1) + 3.0 * DAY
	pin(t)
	var real := GuildLeague.real_wars(w)
	var counts := {}
	var any_trail := false
	var any_color := false
	for g in WorldPlayers.GUILDS:
		var n := 0
		var members := WorldPlayers.members_at(g, t)
		for i in members:
			var c := RewardShop.world_cosmetics(i, t)
			check(c == RewardShop.world_cosmetics(i, t), "fixed for player %d" % i)
			check(String(c.cos) == "" or RewardShop.COSTUMES.has(c.cos), "a real costume id")
			if String(c.cos) != "":
				n += 1
			any_trail = any_trail or String(c.trail) != ""
			any_color = any_color or String(c.ncol) != ""
		counts[g] = float(n) / float(maxi(1, members.size()))
	var first := GuildLeague.league_champion_of(w, real)
	var last: int = GuildLeague.table(w, real, t)[3].g
	# Cosmetics are bought with what each world player really earned in the league rounds
	# (world_wallet): the champion's members earned more than the last guild's.
	var purse := {}
	for g in [first, last]:
		purse[g] = RewardShop.guild_week_coins(g, w, t)
	check(first > 0 and purse[first] > purse[last], "the league champion's members earned more league coins that season (%s, worn %s)" % [purse, counts])
	var rich := WorldPlayers.members_at(first, t)[0]
	var spent := 0
	var worn := RewardShop.world_cosmetics(rich, t)
	for tab in [["costume", "cos"], ["trail", "trail"], ["ncol", "ncol"]]:
		if String(worn[tab[1]]) != "":
			spent += int(RewardShop.entry(tab[0], String(worn[tab[1]])).lc)
	check(spent <= int(RewardShop.world_wallet(rich, t).lc), "a world player only wears what its coins could buy (%d <= %d)" % [spent, int(RewardShop.world_wallet(rich, t).lc)])
	check(any_trail and any_color, "trails and name colours are worn too")
	var low := -1
	for i in WorldPlayers.size():
		if WorldPlayers.level_at(i, t) < Game.GUILD_LEVEL:
			low = i
			break
	check(low >= 0 and RewardShop.world_cosmetics(low, t) == {"cos": "", "trail": "", "ncol": ""}, "a player under Lv.100 owns nothing")
	var i0 := WorldPlayers.members_at(first, t)[0]
	var look := PlayerLook.of_member(WorldPlayers.member(i0, t), i0)
	var c0 := RewardShop.world_cosmetics(i0, t)
	check(String(look.cos) == String(c0.cos) and String(look.ncol) == String(c0.ncol), "a world player's look carries its cosmetics")


func _page() -> void:
	_hero(WorldPlayers.NEVERDIE)
	RewardShop.add_coins(500)
	RewardShop.add_points(400)
	var host := Control.new()
	host.size = Vector2(1200, 700)
	add_child(host)
	_host = host
	_rebuilt = 0
	RewardShopView.tab = "costume"
	RewardShopView.build(host, _rebuild_page)
	await get_tree().process_frame
	var wallet := host.find_child("RewardWallet", true, false) as Label
	check(wallet != null and wallet.text.contains("500") and wallet.text.contains(RewardShop.COIN_NAME) and wallet.text.contains(RewardShop.POINT_NAME), "both currencies on the page (%s)" % (wallet.text if wallet else ""))
	for id in RewardShop.COSTUMES:
		check(host.find_child("Reward_%s" % id, true, false) != null, "a card for costume %s" % id)
	var buy := host.find_child("RewardBuy_sakura", true, false) as Button
	check(buy != null and not buy.disabled, "sakura can be bought")
	var royal := host.find_child("RewardBuy_royal", true, false) as Button
	check(royal != null and royal.disabled and royal.tooltip_text != "", "the royal costume is out of reach (900 coins)")
	buy.pressed.emit()
	await get_tree().process_frame
	check(RewardShop.owns("sakura") and _rebuilt == 1, "bought from the page")
	var wear := host.find_child("RewardWear_sakura", true, false) as Button
	check(wear != null and wear.text == "ถอด", "the owned costume shows the wardrobe button")
	for tab in ["trail", "ncol", "stone"]:
		var b := host.find_child("RewardTab_%s" % tab, true, false) as Button
		check(b != null, "tab button %s" % tab)
		if b:
			b.pressed.emit()
			await get_tree().process_frame
			check(RewardShopView.tab == tab, "the %s tab opens" % tab)
	check(host.find_child("Reward_purple5", true, false) != null and host.find_child("RewardBuy_ruby2", true, false) != null, "the stones' cards")
	host.queue_free()
	# The game menu has the tab; the league page the way in.
	check(GameMenu.TABS.any(func(p): return String(p[0]) == "reward" and String(p[1]) == RewardShop.SHOP_NAME), "the menu's tab")
	var league := Control.new()
	league.size = Vector2(1200, 700)
	add_child(league)
	LeagueView.build(league, _rebuild_page)
	await get_tree().process_frame
	var open := league.find_child("LeagueExchangeOpen", true, false) as Button
	_asked = 0
	Game.reward_shop_requested.connect(_count_asked)
	check(open != null, "the league page opens the exchange")
	if open:
		open.pressed.emit()
	check(_asked == 1, "the way in asks Main for the shop")
	Game.reward_shop_requested.disconnect(_count_asked)
	league.queue_free()
	await get_tree().process_frame


func _keeper() -> void:
	var zone := Zone.new()
	var roles: Array = zone._villagers().map(func(v): return String(v[0]))
	var keeper: Array = zone._villagers().filter(func(v): return String(v[0]) == "reward")
	check(roles.has("reward") and keeper.size() == 1 and String(keeper[0][1]) == RewardShop.KEEPER and String(keeper[0][3]).contains(RewardShop.SHOP_NAME), "the keeper stands in the village")
	check(Npc.LOOKS.has("reward"), "with a look of its own")
	var main := FileAccess.get_file_as_string("res://scenes/main.gd")
	check(main.contains('"reward":') and main.contains("_open_menu(&\"reward\")"), "talking to the keeper opens the shop")
	zone.free()


func _server() -> void:
	var server := FileAccess.get_file_as_string("res://hosting/accounts/server/accounts.js")
	check(server.contains("'rshop' in profile") and server.contains("function validRewardShop"), "accounts.js checks the record")
	var rx := RegEx.create_from_string("const RSHOP_INTS = new Set\\(\\[([^\\]]*)\\]\\)")
	var m := rx.search(server)
	var keys: Array = []
	if m:
		for part in m.get_string(1).split(","):
			keys.append(part.strip_edges().trim_prefix("'").trim_suffix("'"))
	var mine: Array = RewardShop.INT_KEYS.duplicate()
	keys.sort()
	mine.sort()
	check(keys == mine, "accounts.js RSHOP_INTS matches RewardShop.INT_KEYS (%s / %s)" % [keys, mine])
	var rx2 := RegEx.create_from_string("const RSHOP_TEXTS = new Set\\(\\[([^\\]]*)\\]\\)")
	var m2 := rx2.search(server)
	var texts: Array = []
	if m2:
		for part in m2.get_string(1).split(","):
			texts.append(part.strip_edges().trim_prefix("'").trim_suffix("'"))
	var my_texts: Array = RewardShop.TEXT_KEYS.duplicate()
	texts.sort()
	my_texts.sort()
	check(texts == my_texts, "accounts.js RSHOP_TEXTS matches RewardShop.TEXT_KEYS")
	check(server.contains("KEY") or RewardShop.KEY == "rshop", "the record's key is rshop")
