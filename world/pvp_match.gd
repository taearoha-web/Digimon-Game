class_name PvpMatch
extends Node
## One ranked duel: matchmaking, the 3-2-1 countdown, the fight with a time
## limit, and the verdict.

signal finished(result: Dictionary)

var zone: Node3D
var hero: Hero
var rival: Rival
var state := "intro"
var time_left := PvpData.TIME_LIMIT
var opponent_name := ""

var _timer := 4.2
var _count := 4
var _info: Dictionary = {}
var _result: Dictionary = {}
var _end_timer := 0.0


func setup(p_zone: Node3D, p_hero: Hero) -> void:
	zone = p_zone
	hero = p_hero


func _ready() -> void:
	var rp := Game.pvp_rp()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_info = PvpData.make_opponent(int(Game.profile.level), rp, rng, Game.class_id())
	# Both fighters start at full strength.
	var stats := Game.stats_now()
	Game.profile.hp = stats.max_hp
	Game.profile.mp = stats.max_mp
	rival = Rival.new()
	var tier := PvpData.tier_of(rp)
	rival.setup_rival(_info, Vector3.ZERO, hero, "[%s]" % tier.name)
	rival.position = Vector3(PvpArena.SPAWN_X, 0.3, 0.0)
	zone.add_child(rival)
	rival.visual.rotation.y = -PI * 0.5
	opponent_name = rival.rival_name
	zone.banner_requested.emit("ลีกจัดอันดับ · %s" % PvpData.rank_name(rp))
	Game.say("คู่ต่อสู้: %s (Lv.%d) — ใช้ยาในสนามไม่ได้ เวลา %d วินาที" % [opponent_name, int(rival.level), int(PvpData.TIME_LIMIT)], &"quest")


func _process(delta: float) -> void:
	match state:
		"intro":
			_timer -= delta
			var shown := ceili(_timer)
			if shown < _count and shown >= 1:
				_count = shown
				zone.banner_requested.emit(str(shown))
				AudioManager.play_sfx(&"coin", -2.0)
			if _timer <= 0.0:
				state = "fight"
				rival.start_fight()
				zone.banner_requested.emit("สู้!!")
				AudioManager.play_sfx(&"quest_complete", -2.0)
		"fight":
			time_left -= delta
			if rival.is_dead():
				_end(true, false)
			elif hero.is_dead():
				_end(false, false)
			elif time_left <= 0.0:
				_end(false, true)
		"ending":
			_end_timer -= delta
			if _end_timer <= 0.0:
				state = "done"
				finished.emit(_result)


func _end(won: bool, timeout: bool) -> void:
	state = "ending"
	_end_timer = 2.2
	if is_instance_valid(rival):
		rival.stop_fight()
	_result = Game.pvp_finish(won, timeout, _info, opponent_name)
	zone.banner_requested.emit("ชนะ!" if won else ("หมดเวลา" if timeout else "พ่ายแพ้"))
	if won and is_instance_valid(hero):
		hero.level_up_fx()
		AudioManager.play_sfx(&"quest_complete")
