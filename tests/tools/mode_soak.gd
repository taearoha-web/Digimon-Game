extends Node
## Stability soak through every play mode, in the real game scenes (Main):
##   town (every menu, shop, storage, trainer, warp and lobby opened and closed),
##   hunting fields, a boss field, a star region, the divine region, the tower,
##   a ranked duel, the guild war and the arena, then back to town after each one.
## Each round prints what is still alive in town after every mode (nodes, objects,
## resources, orphans, tweens, static memory, video memory), so anything a mode leaves
## behind shows as growth from one round to the next. PHASE lines mark where engine
## errors printed to stderr came from.
##   godot --headless --path . res://tests/tools/mode_soak.tscn -- [class] [seconds per mode] [rounds] [time scale] [modes,comma,list] [deaths 0/1]
## Web (wasm heap per sample): copy to a folder the Web preset exports, make it the main scene,
## export to build/probe, then  node tests/tools/web_probe.mjs build/probe "args=warrior,40,3,1" 3600
## Exit code 1 when town grows past the tolerance between the first and the last round
## (or a mode could not be entered), so the same scene can run in CI with short numbers.
const NODE_TOLERANCE := 60
const OBJECT_TOLERANCE := 400
const RESOURCE_TOLERANCE := 40
const TWEEN_TOLERANCE := 8
const ALL_MODES := ["town_ui", "meadow", "abyss", "dawn_forest", "lotus_sanctum", "tower", "pvp", "guildwar", "arena"]

var main: Node
var family := &"warrior"
var seconds := 40.0
var rounds := 2
var scale := 3.0
var modes: Array = ALL_MODES.duplicate()
## With deaths on, the hero falls once in every mode (from round 1 on): the field's trip
## back to the village, the end of a tower run or a duel, and the guild war's respawn.
var deaths := false
var falls := 0
var failures: Array[String] = []
var town_samples: Array[Dictionary] = []
var _wall_start := 0
var _round := 0
var _last_usec := 0
var _frame_ms: Array[float] = []


## Wall-clock frame times of the current phase (script work shows up here even headless).
func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_usec > 0:
		_frame_ms.append(float(now - _last_usec) / 1000.0)
	_last_usec = now


func _frame_report(label: String) -> void:
	if _frame_ms.is_empty():
		return
	var sorted := _frame_ms.duplicate()
	sorted.sort()
	var over := 0
	for f in _frame_ms:
		if f > 100.0:
			over += 1
	print("FRAMES %-26s n=%5d p50=%5.1fms p95=%5.1fms max=%6.1fms over100=%d" % [label, sorted.size(), sorted[sorted.size() / 2], sorted[int(sorted.size() * 0.95)], sorted[sorted.size() - 1], over])
	_frame_ms.clear()


func _sample(label: String) -> Dictionary:
	var s := {
		"label": label,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"tweens": get_tree().get_processed_tweens().size(),
		"static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"video_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"mobs": get_tree().get_nodes_in_group("mobs").size(),
		"loot": get_tree().get_nodes_in_group("loot").size(),
		"wasm_mb": _wasm_mb(),
	}
	print("SAMPLE %-28s nodes=%5d objects=%6d resources=%4d orphans=%3d tweens=%3d static=%6.1fMB video=%6.1fMB wasm=%6.1fMB mobs=%3d loot=%3d pressure=%d" % [label, s.nodes, s.objects, s.resources, s.orphans, s.tweens, s.static_mb, s.video_mb, s.wasm_mb, s.mobs, s.loot, MemoryGuard.pressure])
	return s


## The engine's wasm heap on the web (what an iPhone runs out of), 0 elsewhere.
func _wasm_mb() -> float:
	if not OS.has_feature("web"):
		return 0.0
	# Evaluated in the engine's own scope, where Module (the wasm instance) is defined.
	var raw: Variant = JavaScriptBridge.eval("typeof Module !== 'undefined' && Module.HEAPU8 ? Module.HEAPU8.length : (window.toonHeapBytes ? window.toonHeapBytes() : 0)")
	return float(raw) / 1048576.0 if (raw is float or raw is int) else 0.0


func _wait(sim_seconds: float) -> void:
	# Process-always timers keep counting while a result screen pauses the tree.
	await get_tree().create_timer(sim_seconds, true, false, false).timeout


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		# Web probe: ?args=warrior,40,3,1,meadow+guildwar (modes joined with +)
		var query := String(JavaScriptBridge.eval("location.search"))
		args = PackedStringArray()
		for pair in query.trim_prefix("?").split("&"):
			if pair.begins_with("args="):
				for part in pair.substr(5).uri_decode().split(","):
					args.append(part.replace("+", ","))
	if args.size() > 0 and args[0] != "":
		family = StringName(args[0])
	if args.size() > 1:
		seconds = float(args[1])
	if args.size() > 2:
		rounds = int(args[2])
	if args.size() > 3:
		scale = float(args[3])
	if args.size() > 4 and args[4] != "":
		modes = Array(args[4].split(","))
	if args.size() > 5:
		deaths = args[5] == "1"
	_wall_start = Time.get_ticks_msec()
	GameSettings.load_settings()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	Game.delete_save()
	Game.new_profile(family, "Soak", FaceKit.default_look())
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	_make_endgame_hero()
	await main.go(&"town", true)
	await _wait(1.0)
	Engine.time_scale = scale
	for round_no in rounds:
		_round = round_no
		print("ROUND %d" % round_no)
		for mode in modes:
			await _play(String(mode), round_no)
			_frame_report("%s r%d" % [mode, round_no])
			await _back_to_town()
			_sample("town after %s r%d" % [mode, round_no])
		await _wait(2.0)
		town_samples.append(_sample("TOWN r%d" % round_no))
		_census(round_no)
	Engine.time_scale = 1.0
	_judge()
	print("MODE SOAK: %d rounds x %d modes, %.0f s each at %.1fx, %d falls, wall %ds, %d failures" % [rounds, modes.size(), seconds, scale, falls, (Time.get_ticks_msec() - _wall_start) / 1000, failures.size()])
	for f in failures:
		printerr("FAIL: ", f)
	print("PASS" if failures.is_empty() else "FAILED")
	print("PERF done")
	get_tree().quit(1 if failures.size() > 0 else 0)


func _make_endgame_hero() -> void:
	Game.profile["level"] = 100
	Game.profile["adv"] = 4
	Game.paragon().level = 200
	Game.profile["paragon"]["alloc"] = Game.party_star_alloc(200)
	for skill in ClassData.pool(family):
		Game.profile.skills[String(skill.id)] = 5
	for slot in ItemData.SLOTS:
		Game.profile.equip[slot] = StarProgression.item(family, 200, slot, Game.rng)
	Game.profile.equip["wings"] = StarWingData.item(String(family), Game.rng)
	Game.profile.gold = 50000000
	Game.add_item(ItemData.potion("hp_xxl", 99))
	Game.add_item(ItemData.potion("mp_xxl", 99))
	Game.fill_loadout()
	var stats := Game.stats_now()
	Game.profile.hp = stats.max_hp
	Game.profile.mp = stats.max_mp


func _close_screens() -> void:
	for screen in [main.pvp_screen, main.guildwar_screen, main.tower_screen]:
		if screen.is_open:
			screen.close_screen()
	if main.menu.is_open:
		main.menu.close_menu()
	if main.shop.is_open:
		main.shop.close_shop()
	if main.storage.is_open:
		main.storage.close_storage()
	if main.trainer.is_open:
		main.trainer.close_trainer()
	if main.warp.is_open:
		main.warp.close_warp()
	if main.dialog.is_open:
		main.dialog.close()
	get_tree().paused = false


## A trip already under way (the trip home after a fall) finishes first: Main ignores
## a second trip while one is running.
func _settle_travel() -> void:
	var guard := 0
	while main._traveling and guard < 2000:
		await get_tree().process_frame
		guard += 1
	if main._traveling:
		failures.append("a trip never finished (Main stuck travelling)")


func _back_to_town() -> void:
	_close_screens()
	await _settle_travel()
	_close_screens()
	await main.go(&"town", true)
	_close_screens()
	var stats := Game.stats_now()
	Game.profile.hp = stats.max_hp
	Game.profile.mp = stats.max_mp
	await _wait(1.5)


func _play(mode: String, round_no: int) -> void:
	print("PHASE %s r%d" % [mode, round_no])
	_frame_ms.clear()
	match mode:
		"town_ui":
			await _town_ui()
		"tower":
			main._tower_floor = 1
			await _enter(&"tower")
			await _fight(mode, true)
		"pvp", "guildwar":
			await _enter(StringName(mode))
			await _fight(mode, false)
		"arena":
			await _enter(&"arena")
			await _fight(mode, true)
		_:
			await _enter(StringName(mode))
			await _fight(mode, true)
	_close_screens()


func _enter(zone_id: StringName) -> void:
	await _settle_travel()
	await main.go(zone_id, true)
	await _wait(0.5)
	if main.zone == null or main.zone.zone_id != zone_id:
		failures.append("could not enter %s (now in %s)" % [zone_id, main.zone.zone_id if main.zone else &"-"])


## Plays the mode on auto for `seconds`. `keep_alive` refills the hero (fields, tower,
## arena); duels and the guild war let the hero fall and come back as the rules say.
func _fight(label: String, keep_alive: bool) -> void:
	var zone: Zone = main.zone
	if zone == null:
		return
	var hero: Hero = zone.hero
	if is_instance_valid(hero) and not zone._camps.is_empty():
		var camp: Dictionary = zone._camps[0]
		hero.global_position = Vector3(camp.pos.x, 0.2, camp.pos.y)
	var t := 0.0
	var mid_done := false
	while t < seconds:
		await _wait(1.0)
		t += 1.0
		if not is_instance_valid(zone) or main.zone != zone:
			break
		hero = zone.hero
		if is_instance_valid(hero):
			if not hero.auto and not hero.is_dead():
				hero.set_auto(true)
			if keep_alive:
				Game.profile.hp = int(hero.stats.max_hp)
				Game.profile.mp = int(hero.stats.max_mp)
		if not mid_done and t >= seconds * 0.5:
			mid_done = true
			_sample("%s mid" % label)
			if deaths and _round > 0 and is_instance_valid(hero) and not hero.is_dead():
				# One fall per mode; keep_alive pauses until the mode has handled it.
				falls += 1
				print("FALL %s" % label)
				hero._invulnerable_until = 0
				hero.stats["dodge"] = 0.0
				Game.profile.hp = 1
				hero.take_damage(1.0e12)
				keep_alive = false
	_sample("%s end%s" % [label, "" if is_instance_valid(zone) and main.zone == zone else " (zone left early)"])


## Opens and closes every screen in town a few times, every menu tab included.
func _town_ui() -> void:
	for i in 3:
		for tab in GameMenu.TABS:
			main.menu.open_menu(StringName(tab[0]))
			await get_tree().process_frame
			await get_tree().process_frame
		main.menu.close_menu()
		main.menu.forge_mode = true
		main.menu.open_menu(&"inventory")
		await get_tree().process_frame
		main.menu.close_menu()
		main.menu.forge_mode = false
		for pair in [[main.shop, "open_shop", "close_shop"], [main.storage, "open_storage", "close_storage"],
				[main.trainer, "open_trainer", "close_trainer"], [main.warp, "open_warp", "close_warp"],
				[main.pvp_screen, "open_lobby", "close_screen"], [main.guildwar_screen, "open_lobby", "close_screen"],
				[main.tower_screen, "open_lobby", "close_screen"]]:
			pair[0].call(pair[1])
			await get_tree().process_frame
			await get_tree().process_frame
			pair[0].call(pair[2])
			await get_tree().process_frame
		main._on_npc("elder")
		await get_tree().process_frame
		_close_screens()
		main._on_npc("healer")
		await get_tree().process_frame
		_close_screens()
	_sample("town_ui end")


## Nodes under each top-level branch (Main's children and the root's other children),
## to see which part of the game holds what a round left behind.
func _census(round_no: int) -> void:
	var parts: Array[String] = []
	for branch in [main, get_tree().root]:
		for child in branch.get_children():
			if child == main:
				continue
			var count: int = child.find_children("*", "", true, false).size() + 1
			if count >= 20:
				var label := String(child.name)
				if child.get_script() != null and String(child.get_script().get_global_name()) != "":
					label = String(child.get_script().get_global_name())
				parts.append("%s=%d" % [label, count])
	print("CENSUS r%d %s" % [round_no, " ".join(parts)])


func _judge() -> void:
	if town_samples.size() < 2:
		return
	var first: Dictionary = town_samples[0]
	var last: Dictionary = town_samples[town_samples.size() - 1]
	# Round 0 warms every first-visit cache, so growth is measured from round 1 on when there is one.
	if town_samples.size() >= 3:
		first = town_samples[1]
	var checks := [["nodes", NODE_TOLERANCE], ["objects", OBJECT_TOLERANCE], ["resources", RESOURCE_TOLERANCE], ["tweens", TWEEN_TOLERANCE]]
	for c in checks:
		var grow := int(last[c[0]]) - int(first[c[0]])
		print("GROWTH %-10s %+d (round 0 %d -> round %d %d)" % [c[0], grow, int(first[c[0]]), town_samples.size() - 1, int(last[c[0]])])
		if grow > int(c[1]):
			failures.append("town keeps %d more %s after another round of every mode (tolerance %d)" % [grow, c[0], int(c[1])])
	print("GROWTH static_mb %+.1f" % (float(last.static_mb) - float(first.static_mb)))
	if int(last.orphans) > int(first.orphans):
		failures.append("%d more orphan nodes in town" % (int(last.orphans) - int(first.orphans)))
