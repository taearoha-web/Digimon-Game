class_name GuildWarMatch
extends Node
## One guild war, a castle siege (SiegeArena): the hero and its guild against the other
## guild for 30 minutes. Each guild comes from its camp (ours on the left, theirs on the
## right), they meet on the plaza and cross the bridge to the castle, where three gates
## (CastleGate) must be broken one after the other; broken gates stay broken. Behind them
## is the throne room: whoever stands on the altar for CAPTURE_TIME seconds without falling
## takes the castle for its guild, and the other guild may take it back the same way. The
## guild holding the castle at the bell wins (with no holder, the most falls; a tie goes to
## sudden death). The fallen come back at their camp after a few seconds and walk back.

signal finished(result: Dictionary)
signal feed(text: String, team: int)
signal hero_down(seconds: float)
signal hero_back()

## Each guild lines up in rows of four at its camp (ours: four in front, three behind the
## hero's row), this far apart sideways and front to back, so sixteen fighters never overlap.
const ROW_SLOTS := 4
const ROW_GAP := 4.0
const ROW_DEPTH := 3.4
## Our rows stand this much behind the hero's spot, the hero at the front and centre.
const ALLY_SETBACK := 1.8
const COUNTDOWN := 4.2
## Seconds on the altar to take the castle.
const CAPTURE_TIME := 60.0
## A gate holds out about this long against a whole guild hitting it (its HP is set from
## the fighters' strength, so a war of weaker members takes as long as one of stronger).
const GATE_SECONDS := 36.0
const NEUTRAL_COLOR := Color("fff1b8")

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
## Unix time the war began (the guild members' progress is taken at this moment).
var started_at := 0
var hero_kills := 0
var hero_deaths := 0
var hero_respawn_left := 0.0
var roster: Dictionary = {}
## The castle's gates in order, its holder (-1 nobody, else the team) and the capture going
## on: {team, who (the hero or a fighter), progress (seconds)} or {}.
var gates: Array[CastleGate] = []
var castle_owner := -1
var capture: Dictionary = {}

## Seed of the line-ups: the same seed brings the same two guilds back after a resume.
var roll_seed := 0
var resumed := false

const CHECKPOINT_EVERY := 10.0
var _ckpt_timer := CHECKPOINT_EVERY
var _timer := COUNTDOWN
var _count := 4
var _end_timer := 0.0
var _objective_timer := 0.0
var _crystal: MeshInstance3D
var _crystal_mat: StandardMaterial3D
var _hero_killer: GuildFighter
var _result: Dictionary = {}


func setup(p_zone: Node3D, p_hero: Hero) -> void:
	zone = p_zone
	hero = p_hero


## Rolls both guilds, raises the castle's gates and stands everybody in their camps. With a
## SceneTree it yields between fighters so a zone change does not stall (see FrameSlicer).
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
	# The hero's guild fights the other one with its real members (as they were when the
	# war began); a hero without a guild (or no rival yet) gets two guilds of hired fighters.
	started_at = int(saved.get("t0", 0)) if not saved.is_empty() and int(saved.get("t0", 0)) > 0 else int(WorldPresence.clock())
	if Game.guild() > 0:
		roster = GuildWarData.roll_guild_match(rng, Game.guild(), float(started_at))
	if roster.is_empty():
		roster = GuildWarData.roll_match(rng)
	ally_name = roster.ally_name
	enemy_name = roster.enemy_name
	BurstGuard.clear()
	for i in roster.ally.size():
		var fighter := _spawn(roster.ally[i], GuildFighter.TEAM_ALLY, spawn_slot(GuildFighter.TEAM_ALLY, i, roster.ally.size()), ally_name)
		allies.append(fighter)
		await FrameSlicer.pace(tree)
	for i in roster.enemy.size():
		var fighter := _spawn(roster.enemy[i], GuildFighter.TEAM_ENEMY, spawn_slot(GuildFighter.TEAM_ENEMY, i, roster.enemy.size()), enemy_name)
		enemies.append(fighter)
		await FrameSlicer.pace(tree)
	_raise_castle(saved)
	Game.guildwar_issue_supply()
	if not saved.is_empty():
		_restore(saved)
	else:
		Game.guildwar_clear_checkpoint()
	zone.banner_requested.emit("สงครามกิลด์ · %s ปะทะ %s" % [ally_name, enemy_name])
	if resumed:
		Game.say("ต่อสงครามเดิม: %s · เหลือเวลา %d นาที — ศึกถูกเก็บไว้ทุก 10 วินาที" % [siege_status(), int(ceil(time_left / 60.0))], &"quest")
		return
	Game.say("ชิงปราสาท 30 นาที: กิลด์ %s %d คน ปะทะกิลด์ %s %d คน — ข้ามสะพาน ทำลายประตูปราสาท 3 ชั้น แล้วยืนบนแท่นในห้องบัลลังก์ให้ครบ %d วินาทีโดยไม่ล้มเพื่อยึดปราสาท กิลด์ที่ยึดปราสาทไว้ได้ตอนหมดเวลาชนะ" % [ally_name, roster.ally.size() + 1, enemy_name, roster.enemy.size(), int(CAPTURE_TIME)], &"quest")


## Where fighter `index` of a guild of `count` stands in its camp: rows of ROW_SLOTS across
## the field's z axis, the first row nearest the castle side, each row centred on the camp.
## Our guild stands behind the hero's spot at (-BASE_X, BASE_Z), the rivals from BASE_X outwards.
static func spawn_slot(team: int, index: int, count: int) -> Vector3:
	var row := index / ROW_SLOTS
	var col := index % ROW_SLOTS
	var in_row := mini(ROW_SLOTS, count - row * ROW_SLOTS)
	var z := SiegeArena.BASE_Z + (float(col) - (float(in_row) - 1.0) * 0.5) * ROW_GAP
	var depth := float(row) * ROW_DEPTH + (ALLY_SETBACK if team == GuildFighter.TEAM_ALLY else 0.0)
	var x := -(SiegeArena.BASE_X + depth) if team == GuildFighter.TEAM_ALLY else SiegeArena.BASE_X + depth
	return Vector3(x, 0.3, z)


## Where the hero comes back.
static func hero_camp() -> Vector3:
	return Vector3(-SiegeArena.BASE_X, 0.3, SiegeArena.BASE_Z)


## Picks up a war that was cut off: the clock, the score, the broken gates and the castle's
## holder come back, everybody starts again from their camp after a short countdown.
func _restore(saved: Dictionary) -> void:
	resumed = true
	time_left = clampf(float(saved.time_left), 1.0, GuildWarData.DURATION)
	overtime = bool(saved.overtime)
	score = [int(saved.us), int(saved.them)]
	hero_kills = int(saved.kills)
	hero_deaths = int(saved.deaths)
	_timer = 3.2
	_count = 3


func save_checkpoint() -> void:
	var left: Array = []
	for g in gates:
		left.append(0 if g.is_dead() else int(ceil(1000.0 * float(g.hp) / float(maxi(1, g.max_hp)))))
	Game.guildwar_save_checkpoint(roll_seed, time_left, overtime, score, hero_kills, hero_deaths, started_at, {"gates": left, "owner": castle_owner})


func _spawn(info: Dictionary, team: int, at: Vector3, guild: String) -> GuildFighter:
	var fighter := GuildFighter.new()
	fighter.setup_fighter(info, team, hero, at, "[%s]" % guild)
	fighter.siege = self
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
				_assign_objectives()
				zone.banner_requested.emit("บุก!!")
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
			if castle_owner < 0 and score[0] == score[1]:
				overtime = true
				zone.banner_requested.emit("เสมอ! ต่อเวลา — ใครยึดปราสาทหรือล้มศัตรูก่อนชนะ")
				Game.say("ต่อเวลาพิเศษ: ฝ่ายแรกที่ยึดปราสาทได้หรือล้มศัตรูได้ชนะสงคราม", &"quest")
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
	_objective_timer -= delta
	if _objective_timer <= 0.0:
		_objective_timer = 0.5
		_assign_objectives()
	_tick_capture(delta)
	_pulse_crystal(delta)


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
	if overtime and castle_owner < 0 and score[0] != score[1]:
		_end()


func _respawn_hero() -> void:
	var stats := Game.stats_now()
	Game.profile.hp = stats.max_hp
	Game.profile.mp = stats.max_mp
	hero.revive()
	hero.global_position = hero_camp()
	BurstGuard.forget(hero.get_instance_id())
	VfxKit.flash(zone, hero.global_position + Vector3(0, 1.0, 0), Color("bfe8ff"), 1.8)
	hero_back.emit()


# ---------------------------------------------------------------------------
# The castle: three gates, then the altar
# ---------------------------------------------------------------------------

## The gates (their strength set from the fighters', the same for each) and the altar's
## crystal; after a resume, broken gates stay broken and the holder keeps the castle.
func _raise_castle(saved: Dictionary) -> void:
	var ours := float(Game.stats_now().atk)
	var theirs := 0.0
	for f in allies:
		ours += float(f.rstats.atk)
	for f in enemies:
		theirs += float(f.rstats.atk)
	var gate_hp := int(maxf(50000.0, GATE_SECONDS * (ours + theirs) * 0.5 * GuildWarData.damage_scale))
	var left: Array = saved.get("gates", [])
	for k in SiegeArena.GATE_Z.size():
		var gate := CastleGate.new()
		gate.setup_gate(k, Vector3(0, 0, SiegeArena.GATE_Z[k]), gate_hp, hero)
		gate.position = Vector3(0, 0, SiegeArena.GATE_Z[k])
		zone.add_child(gate)
		gate.broken.connect(_on_gate_broken)
		if k < left.size():
			if int(left[k]) <= 0:
				gate.set_broken_quietly()
			else:
				gate.hp = clampi(int(ceil(float(gate.max_hp) * float(left[k]) / 1000.0)), 1, gate.max_hp)
		gates.append(gate)
	castle_owner = clampi(int(saved.get("owner", -1)), -1, 1)
	var holder := Node3D.new()
	holder.name = "AltarCrystal"
	holder.position = SiegeArena.ALTAR
	zone.add_child(holder)
	_crystal_mat = MeshKit.toon(NEUTRAL_COLOR, {"emission": 1.2}) as StandardMaterial3D
	_crystal = MeshKit.part(holder, MeshKit.sphere_low(), _crystal_mat, Vector3(0, 2.2, 0), Vector3(1.2, 2.4, 1.2))
	_crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_color_crystal()
	_update_breakable()


## The first gate still standing (null once all three are down).
func front_gate() -> CastleGate:
	for g in gates:
		if is_instance_valid(g) and not g.is_dead():
			return g
	return null


func gates_left() -> int:
	var n := 0
	for g in gates:
		n += 0 if g.is_dead() else 1
	return n


func _update_breakable() -> void:
	var front := front_gate()
	for g in gates:
		g.breakable = g == front and state != "ending"


func _on_gate_broken(gate: CastleGate) -> void:
	_update_breakable()
	var text := "ประตูปราสาทชั้นที่ %d พังแล้ว!" % (gate.gate_index + 1)
	if front_gate() == null:
		text = "ประตูชั้นสุดท้ายพัง! บุกห้องบัลลังก์ ยืนบนแท่น %d วินาทีเพื่อยึดปราสาท" % int(CAPTURE_TIME)
	zone.banner_requested.emit(text)
	feed.emit(text, -1)
	_assign_objectives()
	save_checkpoint()


## Who goes where: at a gate, everyone to its front (fighting whoever is there); in the
## throne room the castle's holder stands round the altar and the other guild sends one
## fighter onto it while the rest clear the way.
func _assign_objectives() -> void:
	var gate := front_gate()
	for side in [allies, enemies]:
		var k := 0
		for f in side:
			f.objective = gate
			f.capture_role = false
			var spread := float(k % 5 - 2) * 1.6
			if gate != null:
				f.goal_point = SiegeArena.gate_front(gate.gate_index) + Vector3(spread, 0, float(k / 5) * 2.0)
			else:
				var angle := TAU * float(k) / 8.0 + (0.0 if f.team == GuildFighter.TEAM_ALLY else PI / 8.0)
				f.goal_point = SiegeArena.ALTAR + Vector3(cos(angle), 0, sin(angle)) * (SiegeArena.ALTAR_RADIUS + 2.5)
			k += 1
	if gate != null:
		return
	for team in [GuildFighter.TEAM_ALLY, GuildFighter.TEAM_ENEMY]:
		if castle_owner == team:
			continue
		if not capture.is_empty() and int(capture.team) == team:
			if capture.who is GuildFighter:
				(capture.who as GuildFighter).capture_role = true
			continue
		# Our guild leaves the altar to the hero while the hero is in the throne room.
		if team == GuildFighter.TEAM_ALLY and is_instance_valid(hero) and not hero.is_dead() and SiegeArena.section(hero.global_position) == 4:
			continue
		var runner: GuildFighter = null
		var best := INF
		for f in (allies if team == GuildFighter.TEAM_ALLY else enemies):
			if f.is_dead():
				continue
			var d := f._flat_distance(SiegeArena.ALTAR) + (25.0 if f.is_healer() else 0.0)
			if d < best:
				best = d
				runner = f
		if runner != null:
			runner.capture_role = true


## The fighter or hero standing on the altar to take it (null when nobody is).
func capturer() -> Node3D:
	if capture.is_empty():
		return null
	var who: Variant = capture.who
	return who as Node3D if is_instance_valid(who) else null


func capture_progress() -> float:
	return 0.0 if capture.is_empty() else clampf(float(capture.progress) / CAPTURE_TIME, 0.0, 1.0)


## True when the hero stands on the altar and may start taking the castle.
func hero_can_capture() -> bool:
	return state == "fight" and front_gate() == null and capture.is_empty() and castle_owner != GuildFighter.TEAM_ALLY \
		and is_instance_valid(hero) and not hero.is_dead() and SiegeArena.on_altar(hero.global_position)


func start_hero_capture() -> void:
	if hero_can_capture():
		_start_capture(GuildFighter.TEAM_ALLY, hero)


func _tick_capture(delta: float) -> void:
	if front_gate() != null:
		return
	if capture.is_empty():
		for f in all_fighters():
			if f.capture_role and not f.is_dead() and f.team != castle_owner and SiegeArena.on_altar(f.global_position):
				_start_capture(f.team, f)
				break
		return
	var who := capturer()
	if who == null or bool(who.call("is_dead")) or not SiegeArena.on_altar(who.global_position):
		_cancel_capture()
		return
	capture["progress"] = float(capture.progress) + delta
	if float(capture.progress) >= CAPTURE_TIME:
		_complete_capture()


func _start_capture(team: int, who: Node3D) -> void:
	capture = {"team": team, "who": who, "progress": 0.0}
	if who is GuildFighter:
		(who as GuildFighter).capturing = true
	var who_name := "คุณ" if who == hero else (who as GuildFighter).rival_name
	feed.emit("%s เริ่มยึดแท่นปราสาท! (%d วินาที)" % [who_name, int(CAPTURE_TIME)], team)
	zone.banner_requested.emit("%s กำลังยึดแท่นปราสาท!" % team_name(team))
	AudioManager.play_sfx(&"star_charge", -4.0)


func _cancel_capture() -> void:
	var who: Variant = capture.get("who")
	if who is GuildFighter and is_instance_valid(who):
		(who as GuildFighter).capturing = false
	feed.emit("การยึดแท่นของกิลด์ %s ถูกขัด!" % team_name(int(capture.team)), 1 - int(capture.team))
	capture = {}


func _complete_capture() -> void:
	var team := int(capture.team)
	var who: Variant = capture.get("who")
	if who is GuildFighter and is_instance_valid(who):
		(who as GuildFighter).capturing = false
	capture = {}
	castle_owner = team
	_color_crystal()
	VfxKit.pillar(zone, SiegeArena.ALTAR, _owner_color(), 14.0, 1.6, 1.6)
	VfxKit.shockwave(zone, SiegeArena.ALTAR + Vector3(0, 0.3, 0), _owner_color(), 9.0)
	zone.banner_requested.emit("กิลด์ %s ยึดปราสาทได้!" % team_name(team))
	feed.emit("กิลด์ %s ยึดปราสาทได้!" % team_name(team), team)
	AudioManager.play_sfx(&"star_release", -2.0)
	_assign_objectives()
	save_checkpoint()
	if overtime:
		_end()


func _owner_color() -> Color:
	if castle_owner < 0:
		return NEUTRAL_COLOR
	var guild := Game.guild() if castle_owner == GuildFighter.TEAM_ALLY else WorldPlayers.other_guild(Game.guild())
	if Game.guild() > 0 and bool(roster.get("guilds", false)):
		return WorldPlayers.GUILD_COLORS.get(guild, NEUTRAL_COLOR)
	return Color("4a8cff") if castle_owner == GuildFighter.TEAM_ALLY else Color("ff5a4a")


func _color_crystal() -> void:
	if _crystal_mat != null:
		_crystal_mat.albedo_color = _owner_color()
		_crystal_mat.emission = _owner_color()


func _pulse_crystal(delta: float) -> void:
	if _crystal == null:
		return
	_crystal.rotation.y += delta * (3.0 if not capture.is_empty() else 0.8)
	_crystal.position.y = 2.2 + 0.25 * sin(Time.get_ticks_msec() * 0.003)


## One line for the HUD: the gates, the holder and a capture in progress.
func siege_status() -> String:
	var parts: PackedStringArray = []
	var gate := front_gate()
	if gate != null:
		parts.append("ประตูชั้นที่ %d/3 · %d%%" % [gate.gate_index + 1, int(ceil(100.0 * float(gate.hp) / float(maxi(1, gate.max_hp))))])
	else:
		parts.append("ประตูพังครบ 3 ชั้น")
	parts.append("ปราสาท: %s" % ("ยังไม่มีใครยึด" if castle_owner < 0 else "กิลด์ %s ยึดอยู่" % team_name(castle_owner)))
	if not capture.is_empty():
		parts.append("กิลด์ %s กำลังยึด %d/%d วิ" % [team_name(int(capture.team)), int(capture.progress), int(CAPTURE_TIME)])
	return " · ".join(parts)


# ---------------------------------------------------------------------------
# The bell
# ---------------------------------------------------------------------------

func _end() -> void:
	if state != "fight":
		return
	state = "ending"
	_end_timer = 3.0
	_update_breakable()
	if not capture.is_empty():
		var who: Variant = capture.get("who")
		if who is GuildFighter and is_instance_valid(who):
			(who as GuildFighter).capturing = false
		capture = {}
	for f in all_fighters():
		f.stop_fight()
	var won := castle_owner == GuildFighter.TEAM_ALLY if castle_owner >= 0 else score[0] > score[1]
	var rows: Array = [{"name": "คุณ", "class": String(Game.class_id()), "team": GuildFighter.TEAM_ALLY, "kills": hero_kills, "deaths": hero_deaths, "assists": 0, "grade": -1}]
	for f in all_fighters():
		rows.append({"name": f.rival_name, "class": String(f.member["class"]), "team": f.team, "kills": f.kills, "deaths": f.deaths, "assists": f.assists, "grade": f.grade, "tag": f.tag})
	_result = Game.guildwar_finish(won, score[0], score[1], hero_kills, hero_deaths, ally_name, enemy_name)
	_result["rows"] = rows
	_result["overtime"] = overtime
	_result["castle"] = team_name(castle_owner) if castle_owner >= 0 else ""
	_result["castle_ours"] = castle_owner == GuildFighter.TEAM_ALLY
	zone.banner_requested.emit("ชนะสงคราม! ยึดปราสาทได้" if won and castle_owner == GuildFighter.TEAM_ALLY else ("ชนะสงคราม!" if won else "พ่ายแพ้สงคราม"))
	if won and is_instance_valid(hero):
		hero.level_up_fx()
		AudioManager.play_sfx(&"quest_complete")
