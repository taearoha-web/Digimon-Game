extends Node
## The guild fighters' brains on a budget (GuildFighter: the shared view and think_cap),
## headless, on a 40 vs 40 field (80 fighters, the size of the four-guild war):
## - the field builds with 80 fighters and runs;
## - the shared view of the field is built once a physics frame, and asked again within
##   the frame it is the same list (no new build);
## - the full decisions (target picks and skill choices) of one physics frame never pass
##   think_cap (a quarter of the field and a few), and the fighters do think;
## - who is a foe is generic: every target of a fighter is of another team (or the hero
##   side's own: hero, summons, online players, for every guild but the hero's), every
##   teammate of its own;
## - and they still fight like people within a short window: they pick targets,
##   keep buffs up, heal, and fell each other (as soon as all is seen the test ends).
##   godot --headless --audio-driver Dummy --path . res://tests/integration/guild_ai_budget_test.tscn
const PER_SIDE := 40
## Physics frames the budget is judged over (at least), and the war seconds at most.
const MIN_FRAMES := 360
const MAX_SECONDS := 50.0
## War speed. The fighters' locks (a cast, a swing, the spawn guard) run on the wall
## clock, so a sped-up war (Engine.time_scale) fights in slow motion: real time it is.
const SPEED := 1.0

var checks := 0
var failures := 0
var _frames := 0
var _seconds := 0.0
var _builds_at := 0
var _thinks_sum := 0
var _thinks_max := 0
var _bad_builds := 0
var _measuring := false


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	InputSetup.ensure_defaults()
	Game.set_process(false)
	GameSettings.load_settings()
	Game.new_profile(&"warrior", "Budget QA")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	Game.profile.hp = Game.stats_now().max_hp
	check(GuildFighter.think_cap(80) == 23, "the cap for 80 fighters is a quarter and three (%d)" % GuildFighter.think_cap(80))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	seed(2024)
	var info := GuildWarSpectate.demo_match(rng, PER_SIDE)
	Game.current_zone = &"guildwar"
	info["elapsed"] = 400.0
	info["league_match"] = ["Alpha", "Neverdie"]
	info["slot_start"] = 1700000000
	GuildWarSpectate._pending = info
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	zone.layout_seed = 77
	add_child(zone)
	var m: GuildWarMatch = zone.gw_match
	var fighters: Array[GuildFighter] = m.all_fighters() if m != null else []
	check(fighters.size() == PER_SIDE * 2, "the field holds %d fighters (%d)" % [PER_SIDE * 2, fighters.size()])
	if m == null or fighters.is_empty():
		_finish()
		return
	var waited := 0
	while m.state != "fight" and waited < 3000:
		waited += 1
		await get_tree().process_frame
	check(m.state == "fight", "the fight starts (%s)" % m.state)
	_generic_teams(fighters)
	# Which skills are buffs and which heal, per class.
	var started := {}
	var buffers := {}
	var heals := 0
	var deaths_at := 0
	for f in fighters:
		deaths_at += f.deaths
	var picked := {}
	get_tree().physics_frame.connect(_on_physics_frame)
	Engine.time_scale = SPEED
	_builds_at = GuildFighter.view_builds
	_measuring = true
	var kills := 0
	while _seconds < MAX_SECONDS:
		await get_tree().process_frame
		for f in fighters:
			if not is_instance_valid(f):
				continue
			if f._up(f._victim):
				picked[f.get_instance_id()] = true
			for skill in f.class_data.get("skills", []):
				var id := String(skill.id)
				var left := float(f.cooldowns.get(id, 0.0))
				var key := "%d:%s" % [f.get_instance_id(), id]
				# A cooldown that rose since the last look: a new cast.
				if left > float(started.get(key, 0.0)) + 0.05:
					var fx: Dictionary = skill.get("fx", {})
					if String(skill.shape) == "self" and fx.get("buff") is Dictionary:
						buffers[f.get_instance_id()] = true
					if fx.has("heal"):
						heals += 1
				started[key] = left
		kills = -deaths_at
		for f in fighters:
			if is_instance_valid(f):
				kills += f.deaths
		if _frames >= MIN_FRAMES and kills >= 4 and heals >= 2 and buffers.size() >= 10 and picked.size() >= fighters.size() / 2:
			break
	_measuring = false
	Engine.time_scale = 1.0
	print("BUDGET %d physics frames (%.0f war s): decisions %.2f a frame, peak %d (cap %d); targets picked by %d, buffers %d, heal casts %d, falls %d" % [_frames, _seconds, float(_thinks_sum) / maxf(_frames, 1), _thinks_max, GuildFighter.think_cap(fighters.size()), picked.size(), buffers.size(), heals, kills])
	check(_frames >= MIN_FRAMES, "the war ran %d physics frames (%d)" % [MIN_FRAMES, _frames])
	check(_bad_builds == 0, "the shared view is built once a physics frame (%d frames built it other than once)" % _bad_builds)
	check(_thinks_max <= GuildFighter.think_cap(fighters.size()), "full decisions per frame stay within the cap (peak %d, cap %d)" % [_thinks_max, GuildFighter.think_cap(fighters.size())])
	check(_thinks_max <= fighters.size() / 4 + 3, "and within a quarter of the field and a few (%d)" % _thinks_max)
	check(_thinks_sum > _frames, "the fighters do think (%d decisions in %d frames)" % [_thinks_sum, _frames])
	check(picked.size() >= fighters.size() / 2, "fighters pick targets (%d of %d)" % [picked.size(), fighters.size()])
	check(buffers.size() >= 10, "fighters keep their buffs up (%d cast one)" % buffers.size())
	check(heals >= 2, "the healers heal (%d heal casts)" % heals)
	check(kills >= 4, "fighters fell each other (%d falls)" % kills)
	# Asked again within one frame, the view is the same list: no new build.
	var f0: GuildFighter = fighters[0]
	var builds := GuildFighter.view_builds
	var first := f0._foes()
	var again := f0._foes()
	check(is_same(first, again) and GuildFighter.view_builds - builds <= 1, "the view is shared within a frame")
	_finish()


## Every target of a fighter is of another team (the hero side for every other guild);
## every teammate is of its own.
func _generic_teams(fighters: Array[GuildFighter]) -> void:
	var bad_targets := 0
	var bad_mates := 0
	for f in fighters:
		for t in f._targets():
			if t is GuildFighter and (t as GuildFighter).team == f.team:
				bad_targets += 1
			if t is Hero and f.team == GuildFighter.TEAM_ALLY:
				bad_targets += 1
		for a in f._teammates():
			if a is GuildFighter and (a as GuildFighter).team != f.team:
				bad_mates += 1
	check(bad_targets == 0, "a fighter's targets are all of another team (%d wrong)" % bad_targets)
	check(bad_mates == 0, "a fighter's teammates are all of its team (%d wrong)" % bad_mates)


## Emitted before the fighters' physics: the previous physics frame is complete.
func _on_physics_frame() -> void:
	if not _measuring:
		return
	var built := GuildFighter.view_builds - _builds_at
	_builds_at = GuildFighter.view_builds
	if _frames > 0 and built != 1:
		_bad_builds += 1
	if _frames > 0:
		_thinks_sum += GuildFighter.thinks
		_thinks_max = maxi(_thinks_max, GuildFighter.thinks)
	_frames += 1
	_seconds += get_physics_process_delta_time()


func _finish() -> void:
	Engine.time_scale = 1.0
	print("GUILD AI BUDGET: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
