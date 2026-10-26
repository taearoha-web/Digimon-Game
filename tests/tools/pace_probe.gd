extends Node
## How fast a real player levels: a hero of the given level (and stars) hunts on auto in
## the field a player of that level would pick, for a fixed stretch of real time, with
## the gear a player has by then (rare +5 gear of the level; the region's star set on
## star fields) and every skill unlocked so far. Prints the EXP gained per minute; the
## world players (WorldPlayers) level at these rates.
##   godot --headless --path . res://tests/tools/pace_probe.tscn -- SECONDS CLASS SAMPLES
## SAMPLES: comma-separated LEVEL:ZONE or 100*STARS:ZONE, e.g. "3:meadow,100*25:dawn_forest".
var main: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var seconds := float(args[0]) if args.size() > 0 else 60.0
	var cls := StringName(args[1]) if args.size() > 1 else &"warrior"
	var samples := Array(args[2].split(",")) if args.size() > 2 else ["3:meadow"]
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	if main.title_screen:
		main.title_screen.queue_free()
		main.title_screen = null
	main.hud.visible = true
	Engine.time_scale = 1.0
	for sample in samples:
		var parts := String(sample).split(":")
		var head := parts[0].split("*")
		await _measure(cls, int(head[0]), int(head[1]) if head.size() > 1 else 0, StringName(parts[1]), seconds)
	get_tree().quit()


## EXP earned since Lv.1 (levels and stars together).
static func lifetime_exp(profile: Dictionary) -> float:
	var total := float(profile.exp)
	for lv in range(1, int(profile.level)):
		total += HeroStats.exp_to_next(lv)
	var para: Dictionary = profile.get("paragon", {})
	for star in int(para.get("level", 0)):
		total += float(HeroStats.star_need(star))
	return total + float(para.get("exp", 0))


func _measure(cls: StringName, level: int, stars: int, zone_id: StringName, seconds: float) -> void:
	Game.new_profile(cls, "Pace", FaceKit.default_look())
	var p := Game.profile
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + level + stars
	p.level = level
	p.adv = JobData.adv_for_level(level)
	p.points = Game.STAT_POINTS_PER_LEVEL * (level - 1)
	var main_stat := String(JobData.resolve(cls, int(p.adv)).main)
	var points := int(p.points)
	p.attrs[main_stat] = int(p.attrs.get(main_stat, 0)) + points * 2 / 3
	p.attrs["vit"] = int(p.attrs.get("vit", 0)) + points - points * 2 / 3
	p.points = 0
	p.equip = {}
	var tier := 0
	for t in StarProgression.TIERS:
		if stars >= int(t):
			tier = int(t)
	for slot in ItemData.SLOTS:
		var item := StarProgression.item(cls, tier, slot, rng) if tier > 0 else {}
		if item.is_empty():
			item = ItemData.generate(level, cls, rng, 2, slot)
			item.plus = 5
		Game.profile.equip[slot] = item
	var para := Game.paragon()
	para.level = stars
	para.points = 0
	para.alloc = Game.party_star_alloc(stars)
	StarProgression.grant_milestones(p)
	for skill in ClassData.pool(cls) + ClassData.PASSIVES.get(cls, []):
		if int(skill.level) <= level and int(skill.get("star", 0)) <= stars:
			p.skills[String(skill.id)] = SkillRank.MAX
	Game.fill_loadout()
	for member in p.get("party", []):
		member["level"] = maxi(1, level - 1)
		member["stars"] = stars
	await main.go(zone_id, true)
	await get_tree().create_timer(0.8).timeout
	var zone: Node = main.zone
	var hero: Hero = zone.hero
	# The camp a player of this level hunts: the one whose levels fit best.
	var camp: Dictionary = zone._camps[0]
	var best := 1e9
	for c in zone._camps:
		var lv: Array = c.get("levels", [level, level])
		var gap := absf((float(lv[0]) + float(lv[1])) * 0.5 - float(level))
		if gap < best:
			best = gap
			camp = c
	hero.global_position = Vector3(camp.pos.x, 0.2, camp.pos.y) + Vector3(0, 0, 4)
	await get_tree().create_timer(0.3).timeout
	hero.set_auto(true)
	var start := lifetime_exp(Game.profile)
	var kills0 := int(Game.profile.kills)
	var t := 0.0
	while t < seconds:
		await get_tree().create_timer(1.0).timeout
		t += 1.0
		# A player drinks potions and rests; the probe keeps the hero topped up instead.
		Game.profile.hp = hero.stats.max_hp
		Game.profile.mp = hero.stats.max_mp
		if not hero.auto:
			hero.set_auto(true)
	var gained := lifetime_exp(Game.profile) - start
	print("PACE %s Lv%d *%d %s exp/min %.0f kills/min %.1f" % [cls, level, stars, zone_id, gained * 60.0 / seconds, float(int(Game.profile.kills) - kills0) * 60.0 / seconds])
	hero.set_auto(false)
