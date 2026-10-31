class_name GuildWarMatch
extends Node
## One guild war, a castle siege (SiegeArena): the hero and everyone in its guild against
## everyone in the other guild for 30 minutes. Each guild comes from its camp (ours on the left, theirs on the
## right), they meet on the plaza and cross the bridge to the castle, where three gates
## (CastleGate) must be broken one after the other; broken gates stay broken. Behind them
## is the throne room: whoever stands on the altar for CAPTURE_TIME seconds without falling
## takes the castle for its guild, and the other guild may take it back the same way. The
## guild holding the castle at the bell wins (with no holder, the most falls; a tie goes to
## sudden death). The fallen come back at their camp after a few seconds and walk back.
## Each guild's AI makes its own plan from how the war stands (plan_for): rush the gate,
## hold the bridge and strike back, pull back and regroup, storm the altar, split to block
## the way in while one takes the altar, or defend the castle; plans are told in the feed.

signal finished(result: Dictionary)
signal feed(text: String, team: int)
signal hero_down(seconds: float)
signal hero_back()

## Each guild lines up in rows of six at its camp (ours behind the hero's spot), this far
## apart sideways and front to back, so fifty fighters never overlap.
const ROW_SLOTS := 6
const ROW_GAP := 3.2
const ROW_DEPTH := 3.4
## Our rows stand this much behind the hero's spot, the hero at the front and centre.
const ALLY_SETBACK := 2.4
const COUNTDOWN := 4.2
## Seconds on the altar to take the castle.
const CAPTURE_TIME := 60.0
## A gate holds out about this long against both whole guilds hitting it at once (its HP is
## set from all the fighters' strength, so more or stronger fighters meet a stronger door),
## each gate harder than the one before.
const GATE_SECONDS := 110.0
const GATE_TOUGHNESS: Array[float] = [1.0, 1.25, 1.5]
## How often a guild looks again at its plan (and at once when a gate falls or the altar changes).
const PLAN_EVERY := 12.0
const PLAN_NAMES := {
	"rush": "รวมพลบุกตีประตู",
	"hold": "ตั้งรับที่หัวสะพาน รอสวนกลับ",
	"regroup": "ถอยมารวมพลที่ลานกลาง รอเพื่อนเกิดแล้วค่อยบุก",
	"storm": "ทั้งกิลด์บุกห้องบัลลังก์ ยึดแท่น",
	"split": "แบ่งทีม: ครึ่งหนึ่งขวางทางหน้าห้องบัลลังก์ อีกครึ่งคุ้มกันคนยึดแท่น",
	"defend": "ล้อมแท่นปราสาท ตั้งรับ",
	"forward": "ตั้งแนวรับหน้าห้องบัลลังก์ ไม่ให้ใครเข้าใกล้แท่น",
}
const NEUTRAL_COLOR := Color("fff1b8")
## Parties (ปาร์ตี้): everyone in the war fights in a party of at most PARTY_SIZE. The hero
## picks up to PARTY_SIZE - 1 teammates before the war (GuildWarScreen); everybody else on
## both sides is dealt into random parties as even in size as can be. A buff (any buff
## skill: attack, guard, shield, songs...) reaches only the caster's own party; heals
## reach everyone near as before.
const PARTY_SIZE := 5
## The hero's party; the other parties of our guild count up from it, the rival guild's
## from ENEMY_PARTY_BASE.
const HERO_PARTY := 0
const ENEMY_PARTY_BASE := 100
## Name tags and HUD cells of the hero's party members.
const PARTY_COLOR := Color("7dff7a")

## The war being fought (null outside the guild war): only then do buffs stop at the party.
static var current: GuildWarMatch
## Fighters farther than this from the camera are not drawn (low / medium / high quality):
## fifty heroes in gear on one field would otherwise cost a phone too much.
const DRAW_RADIUS := [46.0, 56.0, 70.0]

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
## Each guild's plan now (PLAN_NAMES keys; [ours, theirs]).
var plans: Array[String] = ["", ""]
var _plan_timer := 0.0

## Seed of the line-ups: the same seed brings the same two guilds back after a resume.
var roll_seed := 0
var resumed := false
## Our roster's indices the player picked for its party, and whether it picked at all
## (it did not: the hero is dealt into a random party like everybody else).
var party_picks: Array[int] = []
var party_chosen := false
## Both guilds' parties as roster indices (-1 is the hero), [ours, theirs]; ours[0] is the hero's.
var party_plan: Array = [[], []]

const CHECKPOINT_EVERY := 10.0
var _ckpt_timer := CHECKPOINT_EVERY
var _timer := COUNTDOWN
var _count := 4
var _end_timer := 0.0
var _objective_timer := 0.0
var _cull_timer := 0.0
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
	_take_picks(saved)
	var party_rng := RandomNumberGenerator.new()
	party_rng.seed = hash("gw_party|%d" % roll_seed)
	party_plan = roll_parties(roster.ally.size(), roster.enemy.size(), party_picks, party_chosen, party_rng)
	BurstGuard.clear()
	# Each guild stands in its camp party by party (the hero's party in the front row).
	for team in [GuildFighter.TEAM_ALLY, GuildFighter.TEAM_ENEMY]:
		var lineup: Array = roster.ally if team == GuildFighter.TEAM_ALLY else roster.enemy
		var slot := 0
		for p in (party_plan[team] as Array).size():
			for i in party_plan[team][p]:
				if int(i) < 0:
					continue
				var pid := p if team == GuildFighter.TEAM_ALLY else ENEMY_PARTY_BASE + p
				var fighter := _spawn(lineup[i], team, spawn_slot(team, slot, lineup.size()), ally_name if team == GuildFighter.TEAM_ALLY else enemy_name, pid)
				(allies if team == GuildFighter.TEAM_ALLY else enemies).append(fighter)
				slot += 1
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
	Game.say("ชิงปราสาท %d นาที (หลุดกลับเข้าต่อได้ภายใน %d นาที): กิลด์ %s %d คน ปะทะกิลด์ %s %d คน — ข้ามสะพาน ทำลายประตูปราสาท 3 ชั้น แล้วยืนบนแท่นในห้องบัลลังก์ให้ครบ %d วินาทีโดยไม่ล้มเพื่อยึดปราสาท กิลด์ที่ยึดปราสาทไว้ได้ตอนหมดเวลาชนะ" % [int(GuildWarData.DURATION / 60.0), Game.GW_CKPT_LIFETIME / 60, ally_name, roster.ally.size() + 1, enemy_name, roster.enemy.size(), int(CAPTURE_TIME)], &"quest")


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
	Game.guildwar_save_checkpoint(roll_seed, time_left, overtime, score, hero_kills, hero_deaths, started_at, {"gates": left, "owner": castle_owner, "picks": party_picks, "chosen": party_chosen})


# ---------------------------------------------------------------------------
# Parties
# ---------------------------------------------------------------------------

## The player's picks: from the checkpoint on a resume, else the names chosen on the
## party screen (Game.guildwar_party_picks) found in our roster, at most PARTY_SIZE - 1.
func _take_picks(saved: Dictionary) -> void:
	party_picks.clear()
	if not saved.is_empty():
		party_chosen = bool(saved.get("chosen", false))
		for i in saved.get("picks", []):
			if int(i) >= 0 and int(i) < roster.ally.size() and not party_picks.has(int(i)) and party_picks.size() < PARTY_SIZE - 1:
				party_picks.append(int(i))
		return
	party_chosen = Game.guildwar_party_chosen
	# A pick is for one war: the next war asks again (the names stay to be offered again).
	Game.guildwar_party_chosen = false
	if not party_chosen:
		return
	for i in roster.ally.size():
		if party_picks.size() < PARTY_SIZE - 1 and Game.guildwar_party_picks.has(String(roster.ally[i].member.name)):
			party_picks.append(i)


## Splits `members` into ceil(n / PARTY_SIZE) parties in random order, their sizes at
## most one apart (13 -> 5 4 4; 8 -> 4 4).
static func split_parties(members: Array, rng: RandomNumberGenerator) -> Array:
	var pool := members.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var keep: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = keep
	var out: Array = []
	if pool.is_empty():
		return out
	var count := ceili(float(pool.size()) / float(PARTY_SIZE))
	for p in count:
		out.append([])
	for i in pool.size():
		(out[i % count] as Array).append(pool[i])
	return out


## Both guilds' parties as roster indices, [ours, theirs], the hero (-1) in our first.
## With the player's choice the hero's party is exactly the hero and its picks (a party
## left short stays short) and the rest of our guild is dealt into random parties; with
## no choice the hero is dealt with everybody else. The rival guild is always dealt.
static func roll_parties(ally_count: int, enemy_count: int, picks: Array, chosen: bool, rng: RandomNumberGenerator) -> Array:
	var ours: Array = []
	if chosen:
		var mine: Array = [-1]
		for i in picks:
			if int(i) >= 0 and int(i) < ally_count and not mine.has(int(i)) and mine.size() < PARTY_SIZE:
				mine.append(int(i))
		ours.append(mine)
		var rest: Array = []
		for i in ally_count:
			if not mine.has(i):
				rest.append(i)
		ours.append_array(split_parties(rest, rng))
	else:
		var everyone: Array = [-1]
		for i in ally_count:
			everyone.append(i)
		ours = split_parties(everyone, rng)
		for p in ours.size():
			if (ours[p] as Array).has(-1):
				var hers: Array = ours[p]
				ours.remove_at(p)
				hers.erase(-1)
				hers.push_front(-1)
				ours.push_front(hers)
				break
	var everyone_else: Array = []
	for i in enemy_count:
		everyone_else.append(i)
	return [ours, split_parties(everyone_else, rng)]


## The party a body in the war belongs to: the hero's (HERO_PARTY) for the hero, a
## fighter's own, a summon its summoner's; -1 for anything else.
static func party_of(node: Variant) -> int:
	if node == null or not is_instance_valid(node):
		return -1
	if node is Hero:
		return HERO_PARTY
	if node is GuildFighter:
		return (node as GuildFighter).party
	if node is Summon:
		return party_of((node as Summon).summoner)
	if node is SummonMob:
		return party_of((node as SummonMob).caster)
	return -1


## True while a guild war is being fought (buffs then keep to the party).
static func in_war() -> bool:
	return current != null and is_instance_valid(current)


## Whether a buff cast by `caster` reaches `receiver`: always outside the guild war, in it
## only inside the caster's party (the caster's own buff is always its own).
static func buff_reaches(caster: Variant, receiver: Variant) -> bool:
	if not in_war() or caster == receiver:
		return true
	var party := party_of(caster)
	return party >= 0 and party == party_of(receiver)


## The fighters in the hero's party (the hero not counted), in party order.
func hero_party_members() -> Array[GuildFighter]:
	var out: Array[GuildFighter] = []
	for f in allies:
		if is_instance_valid(f) and f.party == HERO_PARTY:
			out.append(f)
	return out


## Everyone in a party (fighters; the hero for HERO_PARTY is not listed).
func party_members(party: int) -> Array[GuildFighter]:
	var out: Array[GuildFighter] = []
	for f in all_fighters():
		if is_instance_valid(f) and f.party == party:
			out.append(f)
	return out


## The party ids of a side, in order.
func parties_of(team: int) -> Array[int]:
	var out: Array[int] = []
	for p in (party_plan[team] as Array).size():
		out.append(p if team == GuildFighter.TEAM_ALLY else ENEMY_PARTY_BASE + p)
	return out


func _spawn(info: Dictionary, team: int, at: Vector3, guild: String, party := -1) -> GuildFighter:
	var fighter := GuildFighter.new()
	fighter.setup_fighter(info, team, hero, at, "[%s]" % guild)
	fighter.party = party
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


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


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
				_make_plans()
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
	_plan_timer -= delta
	if _plan_timer <= 0.0:
		_plan_timer = PLAN_EVERY
		_make_plans()
	_objective_timer -= delta
	if _objective_timer <= 0.0:
		_objective_timer = 0.5
		_assign_objectives()
	_tick_capture(delta)
	_pulse_crystal(delta)
	_cull_timer -= delta
	if _cull_timer <= 0.0:
		_cull_timer = 0.25
		_cull_far()


## Only fighters near the camera are drawn (they keep fighting either way).
func _cull_far() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var limit: float = DRAW_RADIUS[clampi(GameSettings.quality, 0, 2)]
	var from := camera.global_position
	for f in all_fighters():
		if is_instance_valid(f.visual):
			f.visual.visible = f.global_position.distance_squared_to(from) < limit * limit


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
	var gate_hp := maxf(200000.0, GATE_SECONDS * (ours + theirs) * GuildWarData.damage_scale)
	var left: Array = saved.get("gates", [])
	for k in SiegeArena.GATE_Z.size():
		var gate := CastleGate.new()
		gate.setup_gate(k, Vector3(0, 0, SiegeArena.GATE_Z[k]), int(gate_hp * GATE_TOUGHNESS[k]), hero)
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
	# Its own copy: the cached toon material is shared with anything else of that colour.
	_crystal_mat = (MeshKit.toon(NEUTRAL_COLOR, {"emission": 1.2}) as StandardMaterial3D).duplicate()
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
	_make_plans()
	var text := "ประตูปราสาทชั้นที่ %d พังแล้ว!" % (gate.gate_index + 1)
	if front_gate() == null:
		text = "ประตูชั้นสุดท้ายพัง! บุกห้องบัลลังก์ ยืนบนแท่น %d วินาทีเพื่อยึดปราสาท" % int(CAPTURE_TIME)
	zone.banner_requested.emit(text)
	feed.emit(text, -1)
	_assign_objectives()
	save_checkpoint()


## How many of a side are standing, and how many it has (our side counts the hero).
func _strength(team: int) -> Vector2i:
	var side := allies if team == GuildFighter.TEAM_ALLY else enemies
	var up := 0
	for f in side:
		up += 0 if f.is_dead() else 1
	var total := side.size()
	if team == GuildFighter.TEAM_ALLY:
		total += 1
		up += 1 if is_instance_valid(hero) and not hero.is_dead() else 0
	return Vector2i(up, maxi(1, total))


## A guild's plan from how the war stands: with the gates up it rushes the gate, or holds
## the bridge when the other guild has many more standing; with the gates down it storms
## or splits (one group blocks the way into the throne room) while it does not hold the
## castle, defends it (on the altar, or forward at the throne room's door when stronger)
## while it does; it pulls back to regroup when most of it has fallen, until most are back.
func plan_for(team: int) -> String:
	var mine := _strength(team)
	var theirs := _strength(1 - team)
	var share := float(mine.x) / float(mine.y)
	var was := plans[team]
	var holding := castle_owner == team
	var rival_taking := not capture.is_empty() and int(capture.team) != team
	if not holding and not rival_taking and (share < 0.4 or (was == "regroup" and share < 0.7)):
		return "regroup"
	if front_gate() != null:
		return "hold" if float(mine.x) < float(theirs.x) * 0.7 else "rush"
	if holding:
		return "forward" if mine.x >= theirs.x and not rival_taking else "defend"
	if rival_taking or mine.x < 6:
		return "storm"
	return "split" if mine.x >= theirs.x else "storm"


func _make_plans() -> void:
	for team in [GuildFighter.TEAM_ALLY, GuildFighter.TEAM_ENEMY]:
		var plan := plan_for(team)
		if plan != plans[team]:
			plans[team] = plan
			if state == "fight":
				feed.emit("กิลด์ %s วางแผน: %s" % [team_name(team), PLAN_NAMES[plan]], team)


## A spot round `center`: fighter k of a group spread on a ring (or a line across the hall).
static func _spot(center: Vector3, k: int, radius: float, phase := 0.0) -> Vector3:
	var angle := TAU * float(k % 10) / 10.0 + phase
	var ring := radius + float(k / 10) * 1.6
	return center + Vector3(cos(angle) * ring, 0, sin(angle) * ring * 0.6)


## Who goes where under each guild's plan (and who of a guild not holding the castle is
## sent onto the altar).
func _assign_objectives() -> void:
	var gate := front_gate()
	var throne_door := Vector3(0, 0, SiegeArena.GATE_Z[2] - 3.0)
	for team in [GuildFighter.TEAM_ALLY, GuildFighter.TEAM_ENEMY]:
		var side := allies if team == GuildFighter.TEAM_ALLY else enemies
		var plan := plans[team] if plans[team] != "" else plan_for(team)
		var toward := -1.0 if team == GuildFighter.TEAM_ALLY else 1.0
		var k := 0
		for f in side:
			f.capture_role = false
			f.hold_range = 0.0
			f.objective = gate
			match plan:
				"regroup":
					f.objective = null
					f.hold_range = 14.0
					f.goal_point = _spot(SiegeArena.PLAZA + Vector3(toward * 16.0, 0, 6.0), k, 4.0)
				"hold":
					# Most hold the bridge foot on the plaza; one in four keeps at the gate.
					if k % 4 != 0:
						f.objective = null
						f.hold_range = 16.0
						f.goal_point = _spot(Vector3(toward * 6.0, 0, -1.0), k, 3.0, PI * 0.5)
					else:
						f.goal_point = SiegeArena.gate_front(gate.gate_index) + Vector3(float(k % 5 - 2) * 1.6, 0, 0) if gate != null else SiegeArena.ALTAR
				"rush":
					f.goal_point = SiegeArena.gate_front(gate.gate_index) + Vector3(float(k % 7 - 3) * 1.3, 0, float(k / 7) * 1.8) if gate != null else SiegeArena.ALTAR
				"split":
					# Party by party (a party keeps together, so its buffs reach it), one by one
					# when the guild is one party.
					var half := (f.party % ENEMY_PARTY_BASE) % 2 if (party_plan[team] as Array).size() > 1 else k % 2
					if half == 0:
						f.hold_range = 10.0
						f.goal_point = throne_door + Vector3(float(k % 9 - 4) * 1.4, 0, 0)
					else:
						f.goal_point = _spot(SiegeArena.ALTAR, k, SiegeArena.ALTAR_RADIUS + 2.5)
				"forward":
					f.hold_range = 12.0
					f.goal_point = throne_door + Vector3(float(k % 9 - 4) * 1.4, 0, float(k / 9) * -1.6) if k % 3 != 0 else _spot(SiegeArena.ALTAR, k, SiegeArena.ALTAR_RADIUS + 1.5)
				"defend":
					f.hold_range = 12.0
					f.goal_point = _spot(SiegeArena.ALTAR, k, SiegeArena.ALTAR_RADIUS + 2.0, 0.0 if team == GuildFighter.TEAM_ALLY else PI / 10.0)
				_:
					f.goal_point = _spot(SiegeArena.ALTAR, k, SiegeArena.ALTAR_RADIUS + 2.5)
			k += 1
	if gate != null:
		return
	for team in [GuildFighter.TEAM_ALLY, GuildFighter.TEAM_ENEMY]:
		if castle_owner == team or plans[team] == "regroup":
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
			var d := f._flat_distance(SiegeArena.ALTAR) + (25.0 if f.is_healer() or f.sings() else 0.0)
			if d < best:
				best = d
				runner = f
		if runner != null:
			runner.capture_role = true
			runner.hold_range = 0.0


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
	_make_plans()
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
	_make_plans()
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


## The altar's crystal and the castle's banners take the holder's colour.
func _color_crystal() -> void:
	if _crystal_mat != null:
		_crystal_mat.albedo_color = _owner_color()
		_crystal_mat.emission = _owner_color()
	var banner: Variant = zone.get_meta(SiegeArena.BANNER_META, null) if zone != null else null
	if banner is StandardMaterial3D:
		var tint := _owner_color().lerp(Color.WHITE, 0.35) if castle_owner < 0 else _owner_color()
		(banner as StandardMaterial3D).albedo_color = tint
		(banner as StandardMaterial3D).emission = tint


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


## The HUD's second line: who is standing on each side and our guild's plan.
func sides_status() -> String:
	var ours := _strength(GuildFighter.TEAM_ALLY)
	var theirs := _strength(GuildFighter.TEAM_ENEMY)
	var plan := String(PLAN_NAMES.get(plans[GuildFighter.TEAM_ALLY], ""))
	return "ยืนอยู่ %d/%d : %d/%d%s" % [ours.x, ours.y, theirs.x, theirs.y, (" · แผนเรา: " + plan) if plan != "" else ""]


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
