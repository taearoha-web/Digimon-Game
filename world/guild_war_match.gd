class_name GuildWarMatch
extends Node
## One guild war: the hero and four AI allies against five AI rivals for 30 minutes.
## Every fall scores a point for the other guild and the fallen return to their base
## after a few seconds, so everybody keeps fighting. A power orb appears mid-arena
## every minute (both guilds race for it), the base heals, and a tie at the bell goes
## to sudden death: the next fall wins.

signal finished(result: Dictionary)
signal feed(text: String, team: int)
signal hero_down(seconds: float)
signal hero_back()
signal orb_changed(active: bool)

const SPAWN_X := PvpArena.SPAWN_X
const COUNTDOWN := 4.2
const ORB_FIRST := 45.0
const ORB_EVERY := 60.0
const ORB_RADIUS := 2.8
const ORB_BUFF := {"atk": 0.2, "def": 0.15, "speed": 0.0, "crit": 0.0, "secs": 20.0}
const ORB_COLOR := Color("ffd45a")

var zone: Node3D
var hero: Hero
var state := "intro"
var time_left := GuildWarData.DURATION
var overtime := false
var score: Array[int] = [0, 0]
var allies: Array[GuildFighter] = []
var enemies: Array[GuildFighter] = []
var ally_name := ""
var enemy_name := ""
var hero_kills := 0
var hero_deaths := 0
var hero_respawn_left := 0.0
var roster: Dictionary = {}
var orb_position := Vector3.ZERO
var orb_active := false

## Seed of the line-ups: the same seed brings the same two guilds back after a resume.
var roll_seed := 0
var resumed := false

const CHECKPOINT_EVERY := 10.0
var _ckpt_timer := CHECKPOINT_EVERY
var _timer := COUNTDOWN
var _count := 4
var _end_timer := 0.0
var _orb_timer := ORB_FIRST
var _orb_node: Node3D
var _hero_killer: GuildFighter
var _result: Dictionary = {}


func setup(p_zone: Node3D, p_hero: Hero) -> void:
	zone = p_zone
	hero = p_hero


## Rolls both guilds and stands them in their bases. With a SceneTree it yields between
## fighters so a zone change does not stall (see FrameSlicer).
func build(tree: SceneTree = null) -> void:
	var rng := RandomNumberGenerator.new()
	var saved := Game.guildwar_checkpoint() if Game.guildwar_resuming else {}
	Game.guildwar_resuming = false
	if saved.is_empty():
		rng.randomize()
		roll_seed = int(rng.seed & 0x7fffffff)
		rng.seed = roll_seed
	else:
		roll_seed = int(saved.seed)
		rng.seed = roll_seed
	roster = GuildWarData.roll_match(rng)
	ally_name = roster.ally_name
	enemy_name = roster.enemy_name
	BurstGuard.clear()
	for i in roster.ally.size():
		var z := (float(i) - 1.5) * 3.6
		var fighter := _spawn(roster.ally[i], GuildFighter.TEAM_ALLY, Vector3(-SPAWN_X - 1.5, 0.3, z), ally_name)
		allies.append(fighter)
		await FrameSlicer.pace(tree)
	for i in roster.enemy.size():
		var z := (float(i) - 2.0) * 3.6
		var fighter := _spawn(roster.enemy[i], GuildFighter.TEAM_ENEMY, Vector3(SPAWN_X, 0.3, z), enemy_name)
		enemies.append(fighter)
		await FrameSlicer.pace(tree)
	Game.guildwar_issue_supply()
	if not saved.is_empty():
		_restore(saved)
	else:
		Game.guildwar_clear_checkpoint()
	zone.banner_requested.emit("สงครามกิลด์ · %s ปะทะ %s" % [ally_name, enemy_name])
	if resumed:
		Game.say("ต่อสงครามเดิม: คะแนน %d : %d เหลือเวลา %d นาที — ศึกถูกเก็บไว้ทุก 10 วินาที" % [score[0], score[1], int(ceil(time_left / 60.0))], &"quest")
		return
	Game.say("สงครามกิลด์ 30 นาที: ทีมเราคุณ + เพื่อน AI 4 คน สู้กับกิลด์ %s 5 คน — ล้มศัตรูให้ได้คะแนนมากกว่า ล้มแล้วเกิดใหม่ที่ฐานใน %d วินาที" % [enemy_name, int(GuildWarData.RESPAWN)], &"quest")


## Picks up a war that was cut off: the clock and the score come back, everybody starts
## again from their base after a short countdown.
func _restore(saved: Dictionary) -> void:
	resumed = true
	time_left = clampf(float(saved.time_left), 1.0, GuildWarData.DURATION)
	overtime = bool(saved.overtime)
	score = [int(saved.us), int(saved.them)]
	hero_kills = int(saved.kills)
	hero_deaths = int(saved.deaths)
	_timer = 3.2
	_count = 3
	_orb_timer = 20.0


func save_checkpoint() -> void:
	Game.guildwar_save_checkpoint(roll_seed, time_left, overtime, score, hero_kills, hero_deaths)


func _spawn(info: Dictionary, team: int, at: Vector3, guild: String) -> GuildFighter:
	var fighter := GuildFighter.new()
	fighter.setup_fighter(info, team, hero, at, "[%s]" % guild)
	fighter.position = at
	zone.add_child(fighter)
	fighter.visual.rotation.y = PI * 0.5 if team == GuildFighter.TEAM_ALLY else -PI * 0.5
	fighter._yaw = fighter.visual.rotation.y
	fighter.fell.connect(_on_fell)
	fighter.slew_hero.connect(func(by: GuildFighter): _hero_killer = by)
	return fighter


func all_fighters() -> Array[GuildFighter]:
	var out: Array[GuildFighter] = []
	out.append_array(allies)
	out.append_array(enemies)
	return out


func _ready() -> void:
	hero.died.connect(_on_hero_died)


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
				save_checkpoint()
				for f in all_fighters():
					f.start_fight()
				zone.banner_requested.emit("สู้!!")
				AudioManager.play_sfx(&"quest_complete", -2.0)
		"fight":
			_tick_fight(delta)
		"ending":
			_end_timer -= delta
			if _end_timer <= 0.0:
				state = "done"
				finished.emit(_result)


func _tick_fight(delta: float) -> void:
	_ckpt_timer -= delta
	if _ckpt_timer <= 0.0:
		_ckpt_timer = CHECKPOINT_EVERY
		save_checkpoint()
	if not overtime:
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			if score[0] == score[1]:
				overtime = true
				zone.banner_requested.emit("เสมอ! ต่อเวลา — ใครล้มก่อนชนะ")
				Game.say("ต่อเวลาพิเศษ: ฝ่ายแรกที่ล้มศัตรูได้ชนะสงคราม", &"quest")
			else:
				_end()
				return
	for f in all_fighters():
		if f.is_dead() and f.respawn_left <= 0.0:
			f.respawn()
	if hero_respawn_left > 0.0:
		hero_respawn_left -= delta
		if hero_respawn_left <= 0.0:
			_respawn_hero()
	_tick_orb(delta)


func team_name(team: int) -> String:
	return ally_name if team == GuildFighter.TEAM_ALLY else enemy_name


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

func _on_fell(fighter: GuildFighter, killer: Node) -> void:
	if state != "fight":
		return
	var scoring_team := 1 - fighter.team
	score[scoring_team] += 1
	var by := "ไม่ทราบ"
	if killer is GuildFighter:
		by = (killer as GuildFighter).rival_name
		(killer as GuildFighter).kills += 1
	elif killer == hero or killer == null:
		by = "คุณ"
		hero_kills += 1
	feed.emit("%s ล้ม %s" % [by, fighter.rival_name], scoring_team)
	_after_score()


func _on_hero_died() -> void:
	if state != "fight":
		return
	hero_deaths += 1
	score[1] += 1
	var by := _hero_killer.rival_name if _hero_killer != null and is_instance_valid(_hero_killer) else "ศัตรู"
	if _hero_killer != null and is_instance_valid(_hero_killer):
		_hero_killer.kills += 1
	_hero_killer = null
	feed.emit("%s ล้มคุณ" % by, GuildFighter.TEAM_ENEMY)
	hero_respawn_left = GuildWarData.RESPAWN
	hero_down.emit(hero_respawn_left)
	_after_score()


func _after_score() -> void:
	save_checkpoint()
	if overtime and score[0] != score[1]:
		_end()


func _respawn_hero() -> void:
	var stats := Game.stats_now()
	Game.profile.hp = stats.max_hp
	Game.profile.mp = stats.max_mp
	hero.revive()
	hero.global_position = Vector3(-SPAWN_X, 0.3, 0.0)
	BurstGuard.forget(hero.get_instance_id())
	VfxKit.flash(zone, hero.global_position + Vector3(0, 1.0, 0), Color("bfe8ff"), 1.8)
	hero_back.emit()


# ---------------------------------------------------------------------------
# The power orb
# ---------------------------------------------------------------------------

func _tick_orb(delta: float) -> void:
	if orb_active:
		_pulse_orb(delta)
		var taker: Node3D = null
		var best := ORB_RADIUS
		var candidates: Array[Node3D] = []
		for f in all_fighters():
			if not f.is_dead():
				candidates.append(f)
		if hero != null and not hero.is_dead():
			candidates.append(hero)
		for c in candidates:
			var d := Vector2(c.global_position.x - orb_position.x, c.global_position.z - orb_position.z).length()
			if d < best:
				best = d
				taker = c
		if taker != null:
			_take_orb(GuildFighter.TEAM_ENEMY if taker is GuildFighter and (taker as GuildFighter).team == GuildFighter.TEAM_ENEMY else GuildFighter.TEAM_ALLY)
		else:
			_send_runners()
		return
	_orb_timer -= delta
	if _orb_timer <= 0.0:
		_show_orb()


func _show_orb() -> void:
	orb_active = true
	orb_position = Vector3(randf_range(-6.0, 6.0), 0.0, randf_range(-8.0, 8.0))
	_orb_node = Node3D.new()
	_orb_node.position = orb_position
	zone.add_child(_orb_node)
	var ball := MeshKit.part(_orb_node, MeshKit.sphere(), MeshKit.toon(ORB_COLOR, {"emission": 1.4}), Vector3(0, 1.3, 0), Vector3.ONE * 0.9)
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	VfxKit.pillar(zone, orb_position, ORB_COLOR, 9.0, 0.7, 1.2)
	VfxKit.shockwave(zone, orb_position + Vector3(0, 0.15, 0), ORB_COLOR, ORB_RADIUS * 1.5)
	zone.banner_requested.emit("ออร์บพลังปรากฏกลางสนาม!")
	orb_changed.emit(true)


func _pulse_orb(delta: float) -> void:
	if _orb_node == null:
		return
	_orb_node.position.y = 0.25 * sin(Time.get_ticks_msec() * 0.004)
	_orb_node.rotation.y += delta * 1.4


func _take_orb(team: int) -> void:
	orb_active = false
	_orb_timer = ORB_EVERY
	if _orb_node != null:
		VfxKit.shockwave(zone, orb_position + Vector3(0, 0.15, 0), ORB_COLOR, ORB_RADIUS * 2.2)
		VfxKit.sparks(zone, orb_position + Vector3(0, 1.3, 0), ORB_COLOR, 26, 6.0, 0.8)
		_orb_node.queue_free()
		_orb_node = null
	for f in all_fighters():
		f.orb_goal = null
		if f.team == team and not f.is_dead():
			f.receive_party_buff(ORB_BUFF, ORB_COLOR, "ออร์บพลัง", "orb_power")
	if team == GuildFighter.TEAM_ALLY and hero != null and not hero.is_dead():
		hero.receive_buff(ORB_BUFF, ORB_COLOR, "ออร์บพลัง", true, "orb_power")
	feed.emit("กิลด์ %s ได้ออร์บพลัง (+โจมตี +ป้องกัน 20 วินาที)" % team_name(team), team)
	zone.banner_requested.emit("%s ได้ออร์บพลัง!" % team_name(team))
	AudioManager.play_sfx(&"buff")
	orb_changed.emit(false)


## One free fighter per guild (nearest, healthy, not a healer) goes for the orb.
func _send_runners() -> void:
	for team in [GuildFighter.TEAM_ALLY, GuildFighter.TEAM_ENEMY]:
		var runner: GuildFighter = null
		var best := 1.0e9
		for f in (allies if team == GuildFighter.TEAM_ALLY else enemies):
			f.orb_goal = null
			if f.is_dead() or f.is_healer() or f.hp_ratio() < 0.45:
				continue
			var d := f._flat_distance(orb_position)
			if d < best:
				best = d
				runner = f
		if runner != null and best < 30.0:
			runner.orb_goal = orb_position


# ---------------------------------------------------------------------------
# The bell
# ---------------------------------------------------------------------------

func _end() -> void:
	if state != "fight":
		return
	state = "ending"
	_end_timer = 3.0
	for f in all_fighters():
		f.stop_fight()
	if orb_active and _orb_node != null:
		_orb_node.queue_free()
		_orb_node = null
	orb_active = false
	var won := score[0] > score[1]
	var rows: Array = [{"name": "คุณ", "class": String(Game.class_id()), "team": GuildFighter.TEAM_ALLY, "kills": hero_kills, "deaths": hero_deaths, "assists": 0, "grade": -1}]
	for f in all_fighters():
		rows.append({"name": f.rival_name, "class": String(f.member["class"]), "team": f.team, "kills": f.kills, "deaths": f.deaths, "assists": f.assists, "grade": f.grade})
	_result = Game.guildwar_finish(won, score[0], score[1], hero_kills, hero_deaths, ally_name, enemy_name)
	_result["rows"] = rows
	_result["overtime"] = overtime
	zone.banner_requested.emit("ชนะสงคราม!" if won else "พ่ายแพ้สงคราม")
	if won and is_instance_valid(hero):
		hero.level_up_fx()
		AudioManager.play_sfx(&"quest_complete")
