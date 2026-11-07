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
## Two switches stand in the throne room's back corners (SiegeArena.SWITCHES): the altar is
## shut behind a barrier for a guild until it holds both (someone of it in each circle,
## nobody of the other guild); while the barrier is up its leader cannot start taking the
## altar and a count going on waits where it is, until both are held again.

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
## Beyond this many metres from the camera a fighter is posed every other frame (_cull_far).
const POSE_NEAR := 18.0

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
## Castle captures of each team this war (the weekly league counts them, GuildLeague).
var captures: Array[int] = [0, 0]
var capture: Dictionary = {}
## The rival guild's leader (หัวหน้ากิลด์): the only one of its side who may take the
## altar. Ours is the hero, or the member the player picked (ally_leader).
var enemy_leader: GuildFighter
## Our guild's leader when the player picked one of its members (Game.guild_leader_name);
## null when the hero leads.
var ally_leader: GuildFighter
## The hero stood on the altar without leading (the hint is said once a visit).
var _altar_hint := false
## Each guild's plan now (PLAN_NAMES keys; [ours, theirs]).
var plans: Array[String] = ["", ""]
var _plan_timer := 0.0
## Each guild's war chief (GuildWarCommander, the same brain for both): how the plan is
## fought (gather, push, escort, guard, defend, fall back), focus targets and callouts.
var commanders: Array[GuildWarCommander] = []

## Our commander's called target, marked for the player too: a red ring on the ground.
var _focus_mark: MeshInstance3D

## Seed of the line-ups: the same seed brings the same two guilds back after a resume.
var roll_seed := 0
var resumed := false
## Our roster's indices the player picked for its party, and whether it picked at all
## (it did not: the hero is dealt into a random party like everybody else).
var party_picks: Array[int] = []
var party_chosen := false
## Both guilds' parties as roster indices (-1 is the hero), [ours, theirs]; ours[0] is the hero's.
var party_plan: Array = [[], []]

## Watching (GuildWarSpectate): the watched war's match_info ({} while the hero fights).
## Both guilds are AI, the hero is out of the war (hidden, unhurt, never a target),
## nothing is saved, paid or counted for the hero; the end goes to GuildWarSpectate.report.
var spectate: Dictionary = {}
## The spectator's camera and board (a child of the zone), while watching.
var spectator: GuildWarSpectate
## Both guilds' colours while watching ([side A, side B]).
var _watch_colors: Array[Color] = []
## Tests and tools: the next war's line-ups (roll_guild_match's shape), taken once by build
## in place of the roll (e.g. 19 members and the hero against 20).
static var next_roster: Dictionary = {}

const CHECKPOINT_EVERY := 10.0
var _ckpt_timer := CHECKPOINT_EVERY
var _timer := COUNTDOWN
var _count := 4
var _end_timer := 0.0
var _objective_timer := 0.0
var _cull_timer := 0.0
var _crystal: MeshInstance3D
var _crystal_mat: StandardMaterial3D

## The castle's switches: who holds each now (-1 nobody, else the team; a switch with both
## guilds inside is contested and held by nobody), read every SWITCH_EVERY seconds.
const SWITCH_EVERY := 0.25
var switch_owner: Array[int] = [-1, -1]
var switch_contested: Array[bool] = [false, false]
## Tests and tools: both switches read as held by this guild (-1: as the field stands).
var switch_pin := -1
## The hero's party sent to hold a switch (the HUD's buttons): its index, -1 for none.
var party_switch := -1
var _switch_left := 0.0
var _switch_parts: Array[Dictionary] = []
var _barrier: MeshInstance3D
var _barrier_mat: StandardMaterial3D
var _barrier_hint := false
var _switch_banner_at := -100000
const CONTESTED_COLOR := Color("ffb15a")
const BARRIER_COLOR := Color(0.55, 0.85, 1.0, 0.26)
var _hero_killer: GuildFighter
var _result: Dictionary = {}

## Online (OnlineGuildWar, EntitySync): a party member's view of its leader's war. No
## fighters of its own (the leader's are mirrored: MirrorFighter), the clock, the score,
## the castle and the end come from the leader; the hero fights on the leader's side.
var mirror := false
## The leader waits for its party (the countdown holds) / a member waits for the leader.
var hold := false
var _hold_age := 0.0
## A member gives up on a leader that has not started after this many seconds.
const MIRROR_WAIT := 45.0


func setup(p_zone: Node3D, p_hero: Hero) -> void:
	zone = p_zone
	hero = p_hero
	commanders = [GuildWarCommander.new(self, GuildFighter.TEAM_ALLY), GuildWarCommander.new(self, GuildFighter.TEAM_ENEMY)]


## Rolls both guilds, raises the castle's gates and stands everybody in their camps. With a
## SceneTree it yields between fighters so a zone change does not stall (see FrameSlicer).
func build(tree: SceneTree = null) -> void:
	if mirror:
		_build_mirror()
		return
	if spectating():
		await _build_spectate(tree)
		return
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
	if not next_roster.is_empty():
		roster = next_roster
		next_roster = {}
	elif Game.guild() > 0:
		roster = GuildWarData.roll_guild_match(rng, Game.guild(), float(started_at))
	if roster.is_empty():
		roster = GuildWarData.roll_match(rng)
	ally_name = roster.ally_name
	enemy_name = roster.enemy_name
	# Who leads each side (the player picks, Game.guild_war_leader): a picked member is
	# always in its line-up. The rival's default leader (its strongest member) leads when
	# in the line-up, else its best tank does, as always. One of the player's other
	# characters picked to lead is not in the war: the default leads instead (told below).
	var ally_lead_name := ""
	var enemy_lead_name := ""
	stand_ins.clear()
	if bool(roster.get("guilds", false)):
		var t0 := float(started_at)
		var ours := Game.guild()
		var rival := WorldPlayers.other_guild(ours)
		ally_lead_name = Game.guild_war_leader(ours, t0)
		enemy_lead_name = Game.guild_war_leader(rival, t0)
		ensure_member(roster.ally, ally_lead_name, t0, rng)
		if String(Game.guild_leader_of(rival, t0).kind) == "member" and Game.guild_leader_pick(rival) == enemy_lead_name:
			ensure_member(roster.enemy, enemy_lead_name, t0, rng)
		for g in [ours, rival]:
			var chosen := Game.guild_leader_of(g, t0)
			if String(chosen.kind) == "alt":
				stand_ins[g] = String(chosen.name)
	_take_picks(saved)
	var party_rng := RandomNumberGenerator.new()
	party_rng.seed = hash("gw_party|%d" % roll_seed)
	party_plan = roll_parties(roster.ally.size(), roster.enemy.size(), party_picks, party_chosen, party_rng)
	BurstGuard.clear()
	# The rival guild's leader plays a tank's build of its own points (GuildWarData.tank_build),
	# and so does ours when the player picked one of the members instead of the hero.
	# The rival's leader is its toughest member (GuildWarData.leader_index) unless the
	# player picked one for that guild.
	var rival_pick := ""
	if bool(roster.get("guilds", false)):
		rival_pick = enemy_lead_name if Game.guild_leader_pick(WorldPlayers.other_guild(Game.guild())) != "" else ""
	var lead_at := GuildWarData.leader_index(roster.enemy, rival_pick)
	if lead_at >= 0:
		roster.enemy[lead_at] = GuildWarData.tank_build(roster.enemy[lead_at])
	var ally_lead_at := -1
	if ally_lead_name != "":
		for i in roster.ally.size():
			if String(roster.ally[i].member.get("name", "")) == ally_lead_name:
				ally_lead_at = i
				break
		if ally_lead_at >= 0:
			roster.ally[ally_lead_at] = GuildWarData.tank_build(roster.ally[ally_lead_at])
	var leads: Array = await _spawn_lineups(lead_at, ally_lead_at, tree)
	var lead_fighter: GuildFighter = leads[0]
	var ally_lead_fighter: GuildFighter = leads[1]
	enemy_leader = lead_fighter if lead_fighter != null else pick_leader(enemies)
	if enemy_leader != null:
		enemy_leader.make_leader()
	# Our leader: the member the player picked (the same crown, the altar is theirs), else
	# the hero (with its own stats, like everyone).
	ally_leader = ally_lead_fighter
	if ally_leader != null:
		ally_leader.make_leader()
	elif is_instance_valid(hero):
		LeaderMark.attach(hero, LeaderMark.guild_color(GuildFighter.TEAM_ALLY))
	_tell_stand_ins()
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
	Game.say("ชิงปราสาท %d นาที (หลุดกลับเข้าต่อได้ภายใน %d นาที): กิลด์ %s %d คน ปะทะกิลด์ %s %d คน — ข้ามสะพาน ทำลายประตูปราสาท 3 ชั้น ยึดสวิตช์ซ้ายและขวาในห้องบัลลังก์ให้ครบเพื่อปลดบาเรีย แล้วหัวหน้ากิลด์ยืนบนแท่นให้ครบ %d วินาทีโดยไม่ล้มเพื่อยึดปราสาท กิลด์ที่ยึดปราสาทไว้ได้ตอนหมดเวลาชนะ" % [int(GuildWarData.DURATION / 60.0), Game.GW_CKPT_LIFETIME / 60, ally_name, roster.ally.size() + 1, enemy_name, roster.enemy.size(), int(CAPTURE_TIME)], &"quest")


## Each guild stands in its camp party by party (the hero's party in the front row).
## Returns [the rival leader's fighter, ours] (roster indices lead_at / ally_lead_at; null
## when not spawned).
func _spawn_lineups(lead_at: int, ally_lead_at: int, tree: SceneTree) -> Array:
	var lead_fighter: GuildFighter = null
	var ally_lead_fighter: GuildFighter = null
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
				if team == GuildFighter.TEAM_ENEMY and int(i) == lead_at:
					lead_fighter = fighter
				elif team == GuildFighter.TEAM_ALLY and int(i) == ally_lead_at:
					ally_lead_fighter = fighter
				slot += 1
				await FrameSlicer.pace(tree)
	return [lead_fighter, ally_lead_fighter]


# ---------------------------------------------------------------------------
# Watching a war (GuildWarSpectate)
# ---------------------------------------------------------------------------

## True while this war is watched, not fought (spectate holds the match_info).
func spectating() -> bool:
	return not spectate.is_empty()


## Seconds the war had run when the watcher came in (0..DURATION - 1).
func watch_elapsed() -> float:
	return clampf(float(spectate.get("elapsed", 0.0)), 0.0, GuildWarData.DURATION - 1.0)


## The watched war: both guilds from the match_info, AI on both sides (each led by its
## toughest member, GuildWarData.leader_index), the hero out of it, the clock at what is
## left of the war and the field as it plausibly stands by now (_apply_late).
func _build_spectate(tree: SceneTree) -> void:
	var info := spectate
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("gw_watch|%d|%s|%s" % [int(info.get("slot_start", 0)), String(info.get("ally_name", "")), String(info.get("enemy_name", ""))])
	roll_seed = int(rng.seed & 0x7fffffff)
	started_at = int(info.get("slot_start", 0)) if int(info.get("slot_start", 0)) > 0 else int(WorldPresence.clock())
	roster = {
		"ally": (info.get("ally", []) as Array).duplicate(true), "enemy": (info.get("enemy", []) as Array).duplicate(true),
		"ally_name": String(info.get("ally_name", "")), "enemy_name": String(info.get("enemy_name", "")),
		"ally_power": float(info.get("ally_power", 0.0)), "enemy_power": float(info.get("enemy_power", 0.0)),
		"guilds": bool(info.get("guilds", false)),
	}
	ally_name = roster.ally_name
	enemy_name = roster.enemy_name
	_watch_colors = [GuildWarSpectate.side_color(info, GuildFighter.TEAM_ALLY), GuildWarSpectate.side_color(info, GuildFighter.TEAM_ENEMY)]
	party_picks.clear()
	# The hero's party is the hero alone (out of the war): every fighter is dealt.
	party_chosen = true
	var party_rng := RandomNumberGenerator.new()
	party_rng.seed = hash("gw_party|%d" % roll_seed)
	party_plan = roll_parties(roster.ally.size(), roster.enemy.size(), [], true, party_rng)
	BurstGuard.clear()
	var lead_at := GuildWarData.leader_index(roster.enemy)
	if lead_at >= 0:
		roster.enemy[lead_at] = GuildWarData.tank_build(roster.enemy[lead_at])
	var ally_lead_at := GuildWarData.leader_index(roster.ally)
	if ally_lead_at >= 0:
		roster.ally[ally_lead_at] = GuildWarData.tank_build(roster.ally[ally_lead_at])
	_leave_war(hero)
	var leads: Array = await _spawn_lineups(lead_at, ally_lead_at, tree)
	enemy_leader = leads[0] if leads[0] != null else pick_leader(enemies)
	if enemy_leader != null:
		enemy_leader.make_leader()
	ally_leader = leads[1] if leads[1] != null else pick_leader(allies)
	if ally_leader != null:
		ally_leader.make_leader()
	_raise_castle({})
	time_left = clampf(GuildWarData.DURATION - watch_elapsed(), 1.0, GuildWarData.DURATION)
	_apply_late(watch_elapsed(), rng)
	spectator = GuildWarSpectate.new()
	spectator.name = "GuildWarSpectate"
	spectator.setup(self)
	zone.add_child(spectator)
	zone.banner_requested.emit("ชมสงครามกิลด์ · %s ปะทะ %s" % [ally_name, enemy_name])


## The hero watches from the stands: hidden, without a body in the field (no collision,
## no physics), read as down by every fighter (Hero.spectating) and never hurt.
static func _leave_war(h: Hero) -> void:
	if h == null or not is_instance_valid(h):
		return
	h.spectating = true
	h.visible = false
	h.velocity = Vector3.ZERO
	h.collision_layer = 0
	h.collision_mask = 0
	h.global_position = hero_camp() + Vector3(0, -40.0, 0)
	h.set_target(null)
	h.process_mode = Node.PROCESS_MODE_DISABLED


## Gates fall roughly this long into a war (seconds; both guilds at the gate, with the
## to-and-fro of a real war): a watcher arriving late finds those already broken.
const LATE_GATE_FALLS: Array[float] = [165.0, 371.0, 619.0]
## About this many falls a minute on each side: the score a late watcher finds.
const LATE_FALLS_PER_MINUTE := 1.6


## A watcher arriving `elapsed` seconds into the war finds it as it might stand by then:
## the gates that would have fallen are down, each guild has some falls, most fighters
## are already out on the plaza (the rest just came back at their camp) and the
## countdown is short (the war is on).
func _apply_late(elapsed: float, rng: RandomNumberGenerator) -> void:
	if elapsed <= 0.0:
		return
	for k in gates.size():
		if k < LATE_GATE_FALLS.size() and elapsed >= LATE_GATE_FALLS[k]:
			gates[k].set_broken_quietly()
	_update_breakable()
	var minutes := elapsed / 60.0
	score = [int(round(minutes * LATE_FALLS_PER_MINUTE * rng.randf_range(0.7, 1.3))), int(round(minutes * LATE_FALLS_PER_MINUTE * rng.randf_range(0.7, 1.3)))]
	if elapsed >= 30.0:
		for f in all_fighters():
			if rng.randf() < 0.75:
				var toward := -1.0 if f.team == GuildFighter.TEAM_ALLY else 1.0
				f.position = Vector3(toward * rng.randf_range(4.0, 20.0), 0.3, SiegeArena.PLAZA.z + rng.randf_range(-6.0, 6.0))
	_timer = 1.2
	_count = 2


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
	if mirror or spectating():
		return
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


## The team-buff button (บัฟทีม, GuildWarHud / HUD): every living fighter of the hero's
## party casts all its buff skills that are ready (GuildFighter.cast_team_buffs), wherever
## it stands; a team buff reaches the hero as always when the caster is within
## GuildFighter.BUFF_REACH. Then the button rests TEAM_BUFF_COOLDOWN seconds.
const TEAM_BUFF_COOLDOWN := 30.0
var team_buff_left := 0.0


## Presses the team-buff button: how many party members buffed (0: nobody could, and
## the button does not rest), or -1 while it rests or the war is over.
func team_buff() -> int:
	if team_buff_left > 0.0 or state not in ["intro", "fight"]:
		return -1
	var buffed := 0
	for f in hero_party_members():
		if not f.is_dead() and f.cast_team_buffs() > 0:
			buffed += 1
	if buffed > 0:
		team_buff_left = TEAM_BUFF_COOLDOWN
	return buffed


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


## The ring under our guild's focus target (hidden when there is none).
func _mark_focus() -> void:
	var target: Node3D = commanders[0].focus if commanders.size() > 0 else null
	var show := target != null and is_instance_valid(target) and target.is_inside_tree() and not bool(target.call("is_dead")) and state == "fight"
	if show and _focus_mark == null and zone != null:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(1.0, 0.25, 0.2, 0.85)
		_focus_mark = MeshKit.part(zone, MeshKit.torus(), MaterialKeeper.keep(mat), Vector3.ZERO, Vector3(2.4, 0.12, 2.4), Vector3.ZERO, "FocusMark")
		_focus_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _focus_mark == null:
		return
	_focus_mark.visible = show
	if show:
		_focus_mark.global_position = target.global_position + Vector3(0, 0.08, 0)


## The player's other characters picked to lead a guild, by guild id: they are not
## being played, so not in the war, and its default leader stands in (stand_in_lines).
var stand_ins := {}


## One line per guild whose picked leader (another character of the player) is not on
## the field: "หัวหน้ากิลด์ X ไม่ได้ลงสนาม — Y นำทัพแทน".
func stand_in_lines() -> Array[String]:
	var out: Array[String] = []
	var ours := Game.guild()
	for g in stand_ins:
		var team := GuildFighter.TEAM_ALLY if int(g) == ours else GuildFighter.TEAM_ENEMY
		var lead := leader_of(team)
		var who := "คุณ" if lead == hero else (String((lead as GuildFighter).member.get("name", "")) if lead is GuildFighter else "ไม่มีใคร")
		out.append("หัวหน้ากิลด์ %s ไม่ได้ลงสนาม (ตัวละครของคุณที่ไม่ได้เล่นอยู่) — %s นำทัพ %s แทน" % [String(stand_ins[g]), who, WorldPlayers.guild_name(int(g))])
	return out


func _tell_stand_ins() -> void:
	for line in stand_in_lines():
		Game.say(line, &"quest")
		feed.emit(line, GuildFighter.TEAM_ALLY)


## A guild's leader: the hero for ours (or the member picked to lead it), the rival
## guild's chosen one for theirs.
func leader_of(team: int) -> Node3D:
	if team == GuildFighter.TEAM_ALLY and hero_leads():
		return hero if is_instance_valid(hero) else null
	return ai_leader(team)


## True when the hero leads our guild (no member was picked to lead it).
func hero_leads() -> bool:
	return ally_leader == null


## A side's AI leader (a GuildFighter), null when the hero leads ours or it is gone.
func ai_leader(team: int) -> GuildFighter:
	var lead := ally_leader if team == GuildFighter.TEAM_ALLY else enemy_leader
	return lead if lead != null and is_instance_valid(lead) else null


## Puts the member named `who` into `lineup` when it is not there (the player picked it
## to lead): in place of the last one of the line-up, or added while there is room.
static func ensure_member(lineup: Array, who: String, t: float, rng: RandomNumberGenerator = null) -> bool:
	if who == "":
		return false
	for info in lineup:
		if String(info.member.get("name", "")) == who:
			return true
	var i := WorldPlayers.index_of(who)
	if i < 0:
		return false
	var info := WorldPlayers.fighter(i, t, rng)
	if lineup.is_empty():
		lineup.append(info)
	else:
		lineup[lineup.size() - 1] = info
	return true


func hero_alive() -> bool:
	return not spectating() and is_instance_valid(hero) and not hero.is_dead()


func hero_hp_ratio() -> float:
	if not is_instance_valid(hero) or not ("stats" in hero) or hero.stats.is_empty():
		return 1.0
	return float(Game.profile.hp) / maxf(float(hero.stats.max_hp), 1.0)


## A commander's callout: in the war chat, and over its leader's head (the rival guild's)
## or one of our fighters' (ours, the hero being the player).
func tactical_call(team: int, text: String) -> void:
	if state != "fight":
		return
	var speaker := "สั่งการ" if team == GuildFighter.TEAM_ALLY and not spectating() else "หัวหน้า %s" % team_name(team)
	feed.emit("[%s] %s" % [speaker, text], team)
	var over: Node3D = null
	var lead := ai_leader(team)
	if lead != null and not lead.is_dead():
		over = lead
	elif team == GuildFighter.TEAM_ALLY:
		for f in allies:
			if not f.is_dead():
				over = f
				break
	if over != null and zone != null:
		BattleVfx.floating_text(zone, over.global_position + Vector3(0, 3.6, 0), text, LeaderMark.guild_color(team).lerp(Color.WHITE, 0.35), 1.0)


func _ready() -> void:
	hero.died.connect(_on_hero_died)


func _process(delta: float) -> void:
	team_buff_left = maxf(0.0, team_buff_left - delta)
	match state:
		"intro":
			if hold:
				# A member whose leader never starts (gone, offline) is not left waiting.
				_hold_age += delta
				if mirror and _hold_age > MIRROR_WAIT:
					mirror_lost()
				return
			_timer -= delta
			var shown := ceili(_timer)
			if shown < _count and shown >= 1:
				_count = shown
				zone.banner_requested.emit(str(shown))
				AudioManager.play_sfx(&"coin", -2.0)
			if _timer <= 0.0:
				state = "fight"
				if mirror:
					zone.banner_requested.emit("บุก!!")
					AudioManager.play_sfx(&"quest_complete", -2.0)
					return
				save_checkpoint()
				for f in all_fighters():
					f.start_fight()
				_make_plans()
				_assign_objectives()
				zone.banner_requested.emit("บุก!!")
				AudioManager.play_sfx(&"quest_complete", -2.0)
		"fight":
			if mirror:
				_tick_mirror(delta)
				return
			_tick_fight(delta)
			_mark_focus()
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
	for c in commanders:
		c.tick(delta)
	_plan_timer -= delta
	if _plan_timer <= 0.0:
		_plan_timer = PLAN_EVERY
		_make_plans()
	_objective_timer -= delta
	if _objective_timer <= 0.0:
		_objective_timer = 0.5
		_assign_objectives()
	_tick_switches(delta)
	_tick_capture(delta)
	_altar_hint_tick()
	_pulse_crystal(delta)
	_cull_timer -= delta
	if _cull_timer <= 0.0:
		_cull_timer = CULL_WATCHING if spectator != null else 0.25
		_cull_far()


## True when the hero stands on the altar with the gates down but does not lead our guild
## (a member was picked to lead it): only the leader may take it.
func hero_on_altar_not_leader() -> bool:
	return not mirror and not hero_leads() and state == "fight" and front_gate() == null \
		and is_instance_valid(hero) and not hero.is_dead() and SiegeArena.on_altar(hero.global_position)


## Tells the player once a visit why the hero cannot take the altar.
func _altar_hint_tick() -> void:
	var on := hero_on_altar_not_leader()
	if on and not _altar_hint:
		var lead := ai_leader(GuildFighter.TEAM_ALLY)
		Game.say("ยึดแท่นได้เฉพาะหัวหน้ากิลด์%s — คุ้มกันหัวหน้าขึ้นแท่นแทน" % ((" (%s)" % String(lead.member.get("name", ""))) if lead != null else ""), &"warning")
	_altar_hint = on
	# The hero leads and stands on the altar behind the barrier: why it cannot press.
	var blocked := hero_blocked_by_barrier()
	if blocked and not _barrier_hint:
		Game.say(BARRIER_TEXT, &"warning")
	_barrier_hint = blocked


## Only fighters near the camera are drawn (they keep fighting either way). Past
## POSE_NEAR the drawn ones are posed every other frame and drop their shadows and
## emitters (HeroVisual.set_anim_lod / set_far, as world players do in the fields): with
## both whole guilds on the field that is most of them, and the phone runs cooler. The
## hero's party stays at full detail. A fighter's mount (GuildFighter.mount) follows its
## rider: hidden with it, posed every other frame and simplified (MountVisual.set_far:
## no small parts, no shadows) past POSE_NEAR, and still past the zone's ANIM_RADIUS,
## where the rider's skeleton stops too.
##
## With twenty a side (forty fighters, their summons and mounts) the drawn ones are also
## only those in the camera's view (SCREEN_MARGIN round it): one off the screen is not
## drawn and is posed every OFF_SCREEN_STEP frames, and a drawn one past POSE_FAR every
## third. Watching (GuildWarSpectate) measures from the middle of the view on the ground
## and draws as far as the view reaches (its camera stands high and far back).
func _cull_far() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var q := clampi(GameSettings.quality, 0, 2)
	var limit: float = DRAW_RADIUS[q]
	var still: float = Zone.ANIM_RADIUS[q]
	var from := camera.global_position
	if spectator != null and is_instance_valid(spectator):
		from = spectator.view_center()
		limit = maxf(limit, spectator.view_radius())
		still = maxf(still, limit)
	var planes := camera.get_frustum()
	for f in all_fighters():
		if not is_instance_valid(f.visual):
			continue
		var d2 := f.global_position.distance_squared_to(from)
		var shown := d2 < limit * limit and in_view(planes, f.global_position + Vector3(0, 1.2, 0), SCREEN_MARGIN)
		f.visual.visible = shown
		var party := f.in_hero_party()
		var far := d2 > POSE_NEAR * POSE_NEAR and not party
		var step := 1
		if not shown:
			step = OFF_SCREEN_STEP
		elif far:
			step = 3 if d2 > POSE_FAR * POSE_FAR else 2
		var model := f.model()
		if model != null:
			model.set_anim_lod(step)
			model.set_far(far or not shown)
		if f.mount != null:
			f.mount.lod_step = mini(step, 3)
			f.mount.set_far(far or not shown)
			f.mount.set_process(shown and d2 < still * still)


## Past this many metres a drawn fighter is posed every third frame (POSE_NEAR: every other).
const POSE_FAR := 34.0
## A fighter this far outside the camera's view still counts as on the screen (its
## weapon, wings and mount reach past its middle; the camera moves between two culls).
const SCREEN_MARGIN := 4.0
## An off-screen fighter (not drawn) is posed every this many frames: it stays in step
## for when it comes into view.
const OFF_SCREEN_STEP := 6
## Watching, the camera is dragged about faster than a hero walks: the view is culled
## this often (seconds) so nobody pops in late at the edge.
const CULL_WATCHING := 0.1


## True when a ball of `margin` round `point` is at least partly inside the view
## (`planes`: Camera3D.get_frustum, their normals pointing out of the view).
static func in_view(planes: Array[Plane], point: Vector3, margin: float) -> bool:
	for plane in planes:
		if plane.distance_to(point) > margin:
			return false
	return true


func team_name(team: int) -> String:
	return ally_name if team == GuildFighter.TEAM_ALLY else enemy_name


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

func _on_fell(fighter: GuildFighter, killer: Node) -> void:
	if state != "fight" or mirror:
		return
	var scoring_team := 1 - fighter.team
	score[scoring_team] += 1
	_tell_commanders(fighter.team)
	var by := "ไม่ทราบ"
	if killer is GuildFighter:
		by = (killer as GuildFighter).rival_name
		(killer as GuildFighter).kills += 1
	elif killer != null and EntitySync.name_of(killer) != "":
		# A party member of ours playing online (its RemotePlayer struck the blow).
		by = EntitySync.name_of(killer)
	elif spectating():
		pass  # a watched war: the hero struck nobody
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
	_tell_commanders(GuildFighter.TEAM_ALLY)
	var by := _hero_killer.rival_name if _hero_killer != null and is_instance_valid(_hero_killer) else "ศัตรู"
	if _hero_killer != null and is_instance_valid(_hero_killer):
		_hero_killer.kills += 1
	_hero_killer = null
	feed.emit("%s ล้มคุณ" % by, GuildFighter.TEAM_ENEMY)
	hero_respawn_left = GuildWarData.RESPAWN
	hero_down.emit(hero_respawn_left)
	_after_score()


## A fall of `team`: its commander remembers a loss, the other a kill (a lost fight
## makes a guild fall back, GuildWarCommander.pick_tactic).
func _tell_commanders(team: int) -> void:
	if commanders.size() == 2:
		commanders[team].on_loss()
		commanders[1 - team].on_kill()


func _after_score() -> void:
	if mirror:
		return
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
	var ours := 0.0 if spectating() else float(Game.stats_now().atk)
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
	# A resumed war remembers the holder, so at least its one capture.
	if castle_owner >= 0:
		captures[castle_owner] = maxi(captures[castle_owner], 1)
	var holder := Node3D.new()
	holder.name = "AltarCrystal"
	holder.position = SiegeArena.ALTAR
	zone.add_child(holder)
	# Its own copy: the cached toon material is shared with anything else of that colour.
	_crystal_mat = (MeshKit.toon(NEUTRAL_COLOR, {"emission": 1.2}) as StandardMaterial3D).duplicate()
	_crystal = MeshKit.part(holder, MeshKit.sphere_low(), _crystal_mat, Vector3(0, 2.2, 0), Vector3(1.2, 2.4, 1.2))
	_crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_raise_switches()
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
	if mirror:
		var said := "ประตูปราสาทชั้นที่ %d พังแล้ว!" % (gate.gate_index + 1)
		zone.banner_requested.emit(said)
		feed.emit(said, -1)
		return
	_make_plans()
	var text := "ประตูปราสาทชั้นที่ %d พังแล้ว!" % (gate.gate_index + 1)
	if front_gate() == null:
		text = "ประตูชั้นสุดท้ายพัง! บุกห้องบัลลังก์ ยึดสวิตช์ซ้าย-ขวาให้ครบเพื่อปลดบาเรีย แล้วยืนบนแท่น %d วินาทีเพื่อยึดปราสาท" % int(CAPTURE_TIME)
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
	if team == GuildFighter.TEAM_ALLY and not spectating():
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
			f.keep_back = false
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
		if commanders.size() > team:
			commanders[team].apply()
	if gate != null:
		return
	for team in [GuildFighter.TEAM_ALLY, GuildFighter.TEAM_ENEMY]:
		if castle_owner == team or plans[team] == "regroup":
			continue
		if not capture.is_empty() and int(capture.team) == team:
			if capture.who is GuildFighter:
				(capture.who as GuildFighter).capture_role = true
			continue
		# Only a guild's leader takes the altar: the hero presses to take it when it leads
		# ours, an AI leader (theirs, or ours when picked) is sent up while it stands.
		var lead := ai_leader(team)
		if lead == null:
			continue
		# It goes up inside its guard (its commander's escort), not alone; once on the
		# altar it stays.
		if not lead.is_dead():
			if commanders.size() < 2 or commanders[team].allows_capture() or commanders[team].tactic == "" or SiegeArena.on_altar(lead.global_position):
				lead.capture_role = true
				lead.hold_range = 0.0


## The fighter or hero standing on the altar to take it (null when nobody is).
func capturer() -> Node3D:
	if capture.is_empty():
		return null
	var who: Variant = capture.who
	return who as Node3D if is_instance_valid(who) else null


func capture_progress() -> float:
	return 0.0 if capture.is_empty() else clampf(float(capture.progress) / CAPTURE_TIME, 0.0, 1.0)


# ---------------------------------------------------------------------------
# The switches and the altar's barrier
# ---------------------------------------------------------------------------

const BARRIER_TEXT := "บาเรียกันแท่นอยู่ ต้องยึดสวิตช์ซ้ายและขวาให้ครบ"


## Who holds a switch with `ours` of our guild and `theirs` of the other inside its
## circle: the guild with more living bodies there; nobody when empty or level (contested;
## read_switches then leaves a level switch with the guild that held it).
## A majority rather than "alone" so two equal squads do not freeze the war: bring more.
static func switch_holder(ours: int, theirs: int) -> int:
	if ours > theirs:
		return GuildFighter.TEAM_ALLY
	if theirs > ours:
		return GuildFighter.TEAM_ENEMY
	return -1


## How many switches `team` holds now (0, 1 or 2).
func switches_held(team: int) -> int:
	if switch_pin >= 0:
		return 2 if switch_pin == team else 0
	var n := 0
	for k in switch_owner.size():
		n += 1 if switch_owner[k] == team else 0
	return n


## The altar's barrier stands for `team` unless it holds both switches: its leader can
## neither start taking the altar nor go on counting.
func barrier_up(team: int) -> bool:
	return switches_held(team) < 2


## The living bodies inside switch `k`'s circle, [ours, theirs]: fighters, the hero and
## (hosting online) the party members' players on our side.
func count_switch(k: int) -> Vector2i:
	var out := Vector2i.ZERO
	for f in allies:
		if is_instance_valid(f) and not f.is_dead() and SiegeArena.on_switch(f.global_position, k):
			out.x += 1
	for f in enemies:
		if is_instance_valid(f) and not f.is_dead() and SiegeArena.on_switch(f.global_position, k):
			out.y += 1
	if not mirror and hero_alive() and SiegeArena.on_switch(hero.global_position, k):
		out.x += 1
	if not mirror and is_inside_tree():
		for node in get_tree().get_nodes_in_group("remote_players"):
			if node is Node3D and EntitySync.remote_alive(node) and SiegeArena.on_switch((node as Node3D).global_position, k):
				out.x += 1
	return out


## Reads both switches (every SWITCH_EVERY s; the leader's war only, a mirror takes them
## from the leader's status).
func _tick_switches(delta: float) -> void:
	_switch_left -= delta
	if _switch_left > 0.0:
		return
	_switch_left = SWITCH_EVERY
	read_switches()


func read_switches() -> void:
	for k in SiegeArena.SWITCHES.size():
		var c := count_switch(k)
		var holder := switch_holder(c.x, c.y)
		# Level numbers in the circle keep it with the guild that held it (the challenger
		# must outnumber the holders); an empty circle is held by nobody.
		if holder < 0 and c.x > 0 and c.x == c.y and switch_owner[k] >= 0:
			holder = switch_owner[k]
		_set_switch(k, holder, c.x > 0 and c.x == c.y)


## A switch changes hands (told in the feed, recoloured, the commanders told at once).
func _set_switch(k: int, holder: int, contested: bool) -> void:
	var was := switch_owner[k]
	if holder == was and contested == switch_contested[k]:
		return
	var had := [switches_held(GuildFighter.TEAM_ALLY), switches_held(GuildFighter.TEAM_ENEMY)]
	switch_owner[k] = holder
	switch_contested[k] = contested
	_color_switch(k)
	_show_barrier()
	if state != "fight":
		return
	var label: String = SiegeArena.SWITCH_NAMES[k]
	if holder >= 0 and holder == was:
		# Only the fight in the circle changed: the holders keep it while they are not outnumbered.
		if contested:
			feed.emit("%s ถูกแย่ง! กิลด์ %s ยังยึดไว้ได้ ต้องมีคนมากกว่าถึงจะชิงได้" % [label, team_name(holder)], 1 - holder)
	elif holder >= 0:
		feed.emit("กิลด์ %s ยึด%sได้" % [team_name(holder), label], holder)
	elif was >= 0:
		feed.emit(("%s ถูกแย่ง! กิลด์ %s เสียการยึด" if contested else "กิลด์ %s เสีย%s") % ([label, team_name(was)] if contested else [team_name(was), label]), 1 - was)
	elif contested:
		feed.emit("สองกิลด์แย่ง%sกันอยู่" % label, -1)
	for team in [GuildFighter.TEAM_ALLY, GuildFighter.TEAM_ENEMY]:
		var now := switches_held(team)
		if now == 2 and int(had[team]) < 2:
			var text := "กิลด์ %s ยึดสวิตช์ครบทั้งสอง — บาเรียแท่นหายไป!" % team_name(team)
			feed.emit(text, team)
			# The banner at most every 10 s (a switch fought over may flip back and forth).
			var now_ms := Time.get_ticks_msec()
			if zone != null and is_instance_valid(zone) and now_ms - _switch_banner_at > 10000:
				_switch_banner_at = now_ms
				zone.banner_requested.emit(text)
		elif now < 2 and int(had[team]) == 2:
			feed.emit("กิลด์ %s เสียสวิตช์ — บาเรียกลับมากันแท่น" % team_name(team), team)
	for c in commanders:
		c.on_switch_change()


## Who holds each switch, for the online status: the team, -1 nobody, -2 contested and
## held by nobody, 2 / 3 contested and still held by team 0 / 1.
func switch_codes() -> Array:
	var out: Array = []
	for k in switch_owner.size():
		out.append((2 + switch_owner[k] if switch_owner[k] >= 0 else -2) if switch_contested[k] else switch_owner[k])
	return out


## The HUD's chip for switch `k`: its name and who holds it.
func switch_text(k: int) -> String:
	var label: String = SiegeArena.SWITCH_NAMES[k]
	var holder := switch_owner[k] if switch_pin < 0 else switch_pin
	if switch_contested[k] and switch_pin < 0:
		if holder >= 0:
			return "%s: %s (แย่งกัน)" % [label, "เรา" if holder == GuildFighter.TEAM_ALLY else "ศัตรู"]
		return "%s: แย่งกัน" % label
	if holder < 0:
		return "%s: ว่าง" % label
	return "%s: %s" % [label, "เรา" if holder == GuildFighter.TEAM_ALLY else "ศัตรู"]


func switch_color(k: int) -> Color:
	if switch_contested[k] and switch_pin < 0:
		return CONTESTED_COLOR
	var holder := switch_owner[k] if switch_pin < 0 else switch_pin
	return Color("c9c9c9") if holder < 0 else team_color(holder)


## The HUD's warning while our guild's leader waits behind the barrier ("" otherwise).
func barrier_line() -> String:
	if state != "fight" or front_gate() != null or castle_owner == GuildFighter.TEAM_ALLY or not barrier_up(GuildFighter.TEAM_ALLY):
		return ""
	if not capture.is_empty() and int(capture.team) == GuildFighter.TEAM_ALLY and bool(capture.get("barrier", false)):
		return BARRIER_TEXT
	var lead := leader_of(GuildFighter.TEAM_ALLY)
	if not mirror and lead != null and is_instance_valid(lead) and not bool(lead.call("is_dead")) and SiegeArena.on_altar(lead.global_position):
		return BARRIER_TEXT
	return ""


## Sends the hero's party to hold switch `k` (pressed again: back to the guild's plan).
## Returns what to tell the player.
func order_party_switch(k: int) -> String:
	if mirror or state not in ["intro", "fight"]:
		return ""
	if party_switch == k:
		party_switch = -1
		_assign_objectives()
		return "ปาร์ตี้กลับไปตามแผนกิลด์"
	party_switch = clampi(k, 0, SiegeArena.SWITCHES.size() - 1)
	_assign_objectives()
	return "สั่งปาร์ตี้ไปยืนยึด%s" % SiegeArena.SWITCH_NAMES[party_switch]


## The two switch pads (a glowing ring on the floor in the holder's colour, a stone post
## with a lever and a glowing orb, the name over it) and the barrier dome over the altar.
func _raise_switches() -> void:
	if zone == null:
		return
	_switch_parts.clear()
	var stone := MeshKit.toon(SiegeArena.STONE)
	for k in SiegeArena.SWITCHES.size():
		var root := Node3D.new()
		root.name = "CastleSwitch%d" % k
		root.position = SiegeArena.SWITCHES[k]
		zone.add_child(root)
		var floor_mat := StandardMaterial3D.new()
		floor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		floor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		floor_mat.albedo_color = Color(1, 1, 1, 0.22)
		var disc := MeshKit.part(root, MeshKit.cylinder(), MaterialKeeper.keep(floor_mat), Vector3(0, 0.08, 0), Vector3(SiegeArena.SWITCH_RADIUS * 2.0, 0.04, SiegeArena.SWITCH_RADIUS * 2.0))
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ring_mat := StandardMaterial3D.new()
		ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_mat.albedo_color = Color.WHITE
		var ring := MeshKit.part(root, MeshKit.torus(), MaterialKeeper.keep(ring_mat), Vector3(0, 0.14, 0), Vector3(SiegeArena.SWITCH_RADIUS * 2.0 + 0.3, 0.3, SiegeArena.SWITCH_RADIUS * 2.0 + 0.3))
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The post stands at the circle's back edge, against the wall side.
		var post := Vector3(0, 0, -SiegeArena.SWITCH_RADIUS * 0.55)
		MeshKit.part(root, MeshKit.cylinder(), stone, post + Vector3(0, 1.2, 0), Vector3(0.8, 2.4, 0.8))
		MeshKit.part(root, MeshKit.box(), MeshKit.toon(SiegeArena.WOOD), post + Vector3(0.35, 2.6, 0), Vector3(0.18, 1.3, 0.18), Vector3(0, 0, -35))
		var orb_mat := (MeshKit.toon(Color.WHITE, {"emission": 1.4}) as StandardMaterial3D).duplicate() as StandardMaterial3D
		var orb := MeshKit.part(root, MeshKit.sphere_low(), orb_mat, post + Vector3(0, 2.75, 0), Vector3(0.75, 0.75, 0.75))
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var tag := Label3D.new()
		tag.text = SiegeArena.SWITCH_NAMES[k]
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.pixel_size = 0.012
		tag.font_size = 56
		tag.outline_size = 14
		tag.position = post + Vector3(0, 4.0, 0)
		root.add_child(tag)
		_switch_parts.append({"floor": floor_mat, "ring": ring_mat, "orb": orb_mat, "tag": tag})
		_color_switch(k)
	var holder := Node3D.new()
	holder.name = "AltarBarrier"
	holder.position = SiegeArena.ALTAR
	zone.add_child(holder)
	_barrier_mat = StandardMaterial3D.new()
	_barrier_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_barrier_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_barrier_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_barrier_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_barrier_mat.albedo_color = BARRIER_COLOR
	MaterialKeeper.keep(_barrier_mat)
	var size := (SiegeArena.ALTAR_RADIUS + 0.9) * 2.0
	_barrier = MeshKit.part(holder, MeshKit.sphere(), _barrier_mat, Vector3(0, 0.6, 0), Vector3(size, 7.5, size), Vector3.ZERO, "Barrier")
	_barrier.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_show_barrier()


func _color_switch(k: int) -> void:
	if k >= _switch_parts.size():
		return
	var parts := _switch_parts[k]
	var held := switch_owner[k] >= 0 or switch_contested[k]
	var color := switch_color(k) if held else Color("f2f2f2")
	(parts.ring as StandardMaterial3D).albedo_color = color
	(parts.floor as StandardMaterial3D).albedo_color = Color(color, 0.32 if held else 0.16)
	(parts.orb as StandardMaterial3D).albedo_color = color
	(parts.orb as StandardMaterial3D).emission = color
	(parts.tag as Label3D).modulate = color.lerp(Color.WHITE, 0.3)


## The dome over the altar stands unless some guild holds both switches.
func _show_barrier() -> void:
	if _barrier != null:
		_barrier.visible = barrier_up(GuildFighter.TEAM_ALLY) and barrier_up(GuildFighter.TEAM_ENEMY)


## The rival guild's leader among spawned fighters: the fighter named `leader_name` (the
## guild's real leader), else the one that holds best (max HP x its defence's worth, a
## defender, warrior or lancer first), never a healer or a singer while anyone else can.
## build() picks it from the line-up instead (GuildWarData.leader_index) so it can play a
## tank's build; this is the fallback.
static func pick_leader(side: Array, leader_name := "") -> GuildFighter:
	var best: GuildFighter = null
	var best_score := -INF
	for f in side:
		var fighter := f as GuildFighter
		if fighter == null:
			continue
		if leader_name != "" and String(fighter.member.get("name", "")) == leader_name:
			return fighter
		var score := float(fighter.max_hp) * (1.0 + float(fighter.rstats.get("def", 0.0)) / 100.0) * (1.5 if fighter.fighter_class() in GuildWarData.TANK_CLASSES else 1.0) - (1.0e12 if fighter.is_healer() or fighter.sings() else 0.0)
		if score > best_score:
			best_score = score
			best = fighter
	return best


## True when the hero (our guild's leader) stands on the altar and may start taking the
## castle: nobody is taking it, or the rivals' leader has stepped off the circle.
func hero_can_capture() -> bool:
	if mirror or not hero_leads():
		return false
	if capture.get("who") == hero:
		return false
	var free := capture.is_empty() or bool(capture.get("paused", false))
	return state == "fight" and front_gate() == null and free and castle_owner != GuildFighter.TEAM_ALLY \
		and not barrier_up(GuildFighter.TEAM_ALLY) \
		and is_instance_valid(hero) and not hero.is_dead() and SiegeArena.on_altar(hero.global_position)


## True when the hero leads, stands on the altar with the gates down and could take it
## but for the barrier (our guild does not hold both switches).
func hero_blocked_by_barrier() -> bool:
	if mirror or not hero_leads() or state != "fight" or front_gate() != null or castle_owner == GuildFighter.TEAM_ALLY:
		return false
	if not is_instance_valid(hero) or hero.is_dead() or not SiegeArena.on_altar(hero.global_position):
		return false
	return barrier_up(GuildFighter.TEAM_ALLY)


func start_hero_capture() -> void:
	if hero_can_capture():
		if not capture.is_empty():
			_cancel_capture()
		_start_capture(GuildFighter.TEAM_ALLY, hero)


## The leader taking the altar counts only while standing in the yellow circle with the
## barrier down for its guild (it holds both switches). Off the circle, or with a switch
## lost (the barrier is back), the count waits where it was and goes on when the leader
## steps back on / both switches are held again; the leader falling or leaving the throne
## room starts it over. A paused count gives way to the other guild's leader on the circle
## with the barrier down for its own guild.
func _tick_capture(delta: float) -> void:
	if front_gate() != null:
		return
	if capture.is_empty():
		for team in [GuildFighter.TEAM_ALLY, GuildFighter.TEAM_ENEMY]:
			var lead := ai_leader(team)
			if lead != null and lead.capture_role and not lead.is_dead() and castle_owner != team and not barrier_up(team) and SiegeArena.on_altar(lead.global_position):
				_start_capture(team, lead)
				return
		return
	var who := capturer()
	if who == null or bool(who.call("is_dead")):
		_cancel_capture("ล้ม")
		return
	if SiegeArena.section(who.global_position) != 4:
		_cancel_capture("ออกจากห้องบัลลังก์")
		return
	var team := int(capture.team)
	var on := SiegeArena.on_altar(who.global_position)
	if who is GuildFighter:
		(who as GuildFighter).capturing = on
	var blocked := barrier_up(team)
	if not on or blocked:
		if not on and not bool(capture.get("paused", false)):
			feed.emit("%s ออกนอกวงสีเหลือง — หยุดนับไว้ที่ %d/%d วิ" % [_who_name(who), int(capture.progress), int(CAPTURE_TIME)], team)
		if blocked and not bool(capture.get("barrier", false)):
			capture["barrier"] = true
			feed.emit("บาเรียกลับมากันแท่น! กิลด์ %s หยุดนับที่ %d/%d วิ — ต้องยึดสวิตช์ซ้ายและขวาให้ครบ" % [team_name(team), int(capture.progress), int(CAPTURE_TIME)], team)
			if zone != null and is_instance_valid(zone):
				VfxKit.shockwave(zone, SiegeArena.ALTAR + Vector3(0, 0.4, 0), Color(BARRIER_COLOR, 1.0), 5.0)
		capture["paused"] = true
		var other_team := 1 - team
		var other := ai_leader(other_team)
		if other != null and not other.is_dead() and castle_owner != other_team and not barrier_up(other_team) and SiegeArena.on_altar(other.global_position):
			_cancel_capture()
			_start_capture(other_team, other)
		return
	if bool(capture.get("barrier", false)):
		capture["barrier"] = false
		feed.emit("บาเรียหายไป! %s นับต่อจาก %d/%d วิ" % [_who_name(who), int(capture.progress), int(CAPTURE_TIME)], team)
	elif bool(capture.get("paused", false)):
		feed.emit("%s กลับเข้าวง — นับต่อจาก %d/%d วิ" % [_who_name(who), int(capture.progress), int(CAPTURE_TIME)], team)
	capture["paused"] = false
	capture["progress"] = float(capture.progress) + delta
	if float(capture.progress) >= CAPTURE_TIME:
		_complete_capture()


func _who_name(who: Node3D) -> String:
	return "คุณ" if who == hero else (String((who as GuildFighter).rival_name) if who is GuildFighter else "")


func _start_capture(team: int, who: Node3D) -> void:
	capture = {"team": team, "who": who, "progress": 0.0, "paused": false, "barrier": false}
	if who is GuildFighter:
		(who as GuildFighter).capturing = true
	var who_name := "คุณ" if who == hero else (who as GuildFighter).rival_name
	feed.emit("%s เริ่มยึดแท่นปราสาท! (%d วินาที)" % [who_name, int(CAPTURE_TIME)], team)
	_make_plans()
	zone.banner_requested.emit("%s กำลังยึดแท่นปราสาท!" % team_name(team))
	AudioManager.play_sfx(&"star_charge", -4.0)


## Ends a capture; with a `reason` (the leader fell or left the throne room) the count
## is lost and must start over.
func _cancel_capture(reason := "") -> void:
	var who: Variant = capture.get("who")
	if who is GuildFighter and is_instance_valid(who):
		(who as GuildFighter).capturing = false
	if reason != "":
		feed.emit("หัวหน้ากิลด์ %s %s — การยึดแท่นต้องนับใหม่!" % [team_name(int(capture.team)), reason], 1 - int(capture.team))
	else:
		feed.emit("การยึดแท่นของกิลด์ %s ถูกขัด!" % team_name(int(capture.team)), 1 - int(capture.team))
	capture = {}


func _complete_capture() -> void:
	var team := int(capture.team)
	var who: Variant = capture.get("who")
	if who is GuildFighter and is_instance_valid(who):
		(who as GuildFighter).capturing = false
	capture = {}
	castle_owner = team
	captures[team] += 1
	_send_home(1 - team)
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


## The guild that lost the castle goes back to its base to regroup (the hero too when it
## is ours): to take it back it must storm up again and hold the altar CAPTURE_TIME anew.
func _send_home(team: int) -> void:
	for f in (allies if team == GuildFighter.TEAM_ALLY else enemies):
		if is_instance_valid(f) and not f.is_dead():
			f.send_home()
			VfxKit.flash(zone, f.global_position + Vector3(0, 1.0, 0), Color("bfe8ff"), 1.2)
	if team == GuildFighter.TEAM_ALLY and is_instance_valid(hero) and not hero.is_dead():
		hero.velocity = Vector3.ZERO
		hero.global_position = hero_camp()
		BurstGuard.forget(hero.get_instance_id())
		VfxKit.flash(zone, hero.global_position + Vector3(0, 1.0, 0), Color("bfe8ff"), 1.8)
	feed.emit("กิลด์ %s ถูกส่งกลับฐาน ต้องบุกขึ้นมายึดแท่นใหม่ %d วินาที" % [team_name(team), int(CAPTURE_TIME)], team)


## The top bar's line: who holds the castle.
func owner_line() -> String:
	return "ยังไม่มีผู้ครองปราสาท" if castle_owner < 0 else "ผู้ครองปราสาท: กิลด์ %s" % team_name(castle_owner)


## The top bar's second line: who is taking the altar while someone stands on it; with
## nobody on it and the castle held, what each side has to do (the holder never takes the
## altar again: it only keeps the other guild off it until the bell).
func capture_line() -> String:
	if capture.is_empty():
		if castle_owner < 0 or front_gate() != null:
			return ""
		return "ป้องกันแท่นไว้ อย่าให้อีกฝั่งยึดได้" if castle_owner == GuildFighter.TEAM_ALLY else "บุกขึ้นไปยึดแท่น %d วิ เพื่อชิงปราสาทคืน" % int(CAPTURE_TIME)
	var who := capturer()
	var who_name := _who_name(who) if who != null else ""
	if bool(capture.get("barrier", false)):
		return "กิลด์ %s หยุดนับที่ %d/%d วิ — บาเรียกันแท่น ต้องยึดสวิตช์ซ้ายและขวาให้ครบ" % [team_name(int(capture.team)), int(capture.progress), int(CAPTURE_TIME)]
	if bool(capture.get("paused", false)):
		return "กิลด์ %s หยุดนับที่ %d/%d วิ%s — กลับเข้าวงสีเหลืองเพื่อนับต่อ" % [team_name(int(capture.team)), int(capture.progress), int(CAPTURE_TIME), (" (%s)" % who_name) if who_name != "" else ""]
	return "กิลด์ %s กำลังยึดแท่น%s %d/%d วิ" % [team_name(int(capture.team)), (" (%s)" % who_name) if who_name != "" else "", int(capture.progress), int(CAPTURE_TIME)]


## The holder's colour for the HUD (the crystal's).
func owner_color() -> Color:
	return _owner_color()


func _owner_color() -> Color:
	return NEUTRAL_COLOR if castle_owner < 0 else team_color(castle_owner)


## A guild's colour (its guild colour in a war between real guilds, else blue / red).
func team_color(team: int) -> Color:
	if _watch_colors.size() == 2:
		return _watch_colors[clampi(team, 0, 1)]
	var guild := Game.guild() if team == GuildFighter.TEAM_ALLY else WorldPlayers.other_guild(Game.guild())
	if Game.guild() > 0 and bool(roster.get("guilds", false)):
		return WorldPlayers.GUILD_COLORS.get(guild, NEUTRAL_COLOR)
	return Color("4a8cff") if team == GuildFighter.TEAM_ALLY else Color("ff5a4a")


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
	if _barrier_mat != null and _barrier != null and _barrier.visible:
		_barrier_mat.albedo_color.a = BARRIER_COLOR.a + 0.08 * sin(Time.get_ticks_msec() * 0.004)


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
	if gate == null:
		parts.append("%s · %s" % [switch_text(0), switch_text(1)])
	return " · ".join(parts)


## The HUD's second line: who is standing on each side and our guild's plan.
func sides_status() -> String:
	var ours := _strength(GuildFighter.TEAM_ALLY)
	var theirs := _strength(GuildFighter.TEAM_ENEMY)
	var plan := String(PLAN_NAMES.get(plans[GuildFighter.TEAM_ALLY], ""))
	var tactic := String(GuildWarCommander.TACTIC_NAMES.get(commanders[0].tactic, "")) if commanders.size() > 0 else ""
	return "ยืนอยู่ %d/%d : %d/%d%s%s" % [ours.x, ours.y, theirs.x, theirs.y, (" · แผนเรา: " + plan) if plan != "" else "", (" (%s)" % tactic) if tactic != "" else ""]


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
	if spectating():
		_end_watched()
		return
	var won := castle_owner == GuildFighter.TEAM_ALLY if castle_owner >= 0 else score[0] > score[1]
	var rows: Array = [{"name": "คุณ", "class": String(Game.class_id()), "team": GuildFighter.TEAM_ALLY, "kills": hero_kills, "deaths": hero_deaths, "assists": 0, "grade": -1}]
	for f in all_fighters():
		rows.append({"name": f.rival_name, "class": String(f.member["class"]), "team": f.team, "kills": f.kills, "deaths": f.deaths, "assists": f.assists, "grade": f.grade, "tag": f.tag})
	_result = Game.guildwar_finish(won, score[0], score[1], hero_kills, hero_deaths, ally_name, enemy_name, rows)
	_result["rows"] = rows
	_result["overtime"] = overtime
	_result["castle"] = team_name(castle_owner) if castle_owner >= 0 else ""
	_result["castle_ours"] = castle_owner == GuildFighter.TEAM_ALLY
	GuildLeague.war_finished(_result, bool(roster.get("guilds", false)), captures, castle_owner, score)
	zone.banner_requested.emit("ชนะสงคราม! ยึดปราสาทได้" if won and castle_owner == GuildFighter.TEAM_ALLY else ("ชนะสงคราม!" if won else "พ่ายแพ้สงคราม"))
	if won and is_instance_valid(hero):
		hero.level_up_fx()
		AudioManager.play_sfx(&"quest_complete")


## The bell of a watched war: who won (the castle's holder, else the most falls), the
## scoreboard and the hook for the league (GuildWarSpectate.report). Nothing is paid.
func _end_watched() -> void:
	var winner := castle_owner
	if winner < 0 and score[0] != score[1]:
		winner = GuildFighter.TEAM_ALLY if score[0] > score[1] else GuildFighter.TEAM_ENEMY
	var rows: Array = []
	for f in all_fighters():
		if is_instance_valid(f):
			rows.append({"name": f.rival_name, "class": String(f.member["class"]), "team": f.team, "kills": f.kills, "deaths": f.deaths, "assists": f.assists, "grade": f.grade, "tag": f.tag})
	_result = {
		"spectated": true, "winner": winner, "winner_name": team_name(winner) if winner >= 0 else "",
		"ally_name": ally_name, "enemy_name": enemy_name, "score": [score[0], score[1]],
		"captures": [captures[0], captures[1]], "castle_owner": castle_owner,
		"castle": team_name(castle_owner) if castle_owner >= 0 else "", "overtime": overtime,
		"rows": rows, "league_match": spectate.get("league_match", []), "slot_start": int(spectate.get("slot_start", 0)),
	}
	GuildWarSpectate.report(spectate, _result)
	zone.banner_requested.emit(("กิลด์ %s ชนะสงคราม!" % team_name(winner)) if winner >= 0 else "สงครามจบลงด้วยผลเสมอ")
	AudioManager.play_sfx(&"quest_complete")


# ---------------------------------------------------------------------------
# Online: a party member in its leader's war (EntitySync mirrors the fighters)
# ---------------------------------------------------------------------------

## The castle and the camps only; the fighters arrive from the leader's game.
func _build_mirror() -> void:
	ally_name = "กิลด์ของหัวหน้าปาร์ตี้"
	enemy_name = "กิลด์คู่แข่ง"
	started_at = int(WorldPresence.clock())
	BurstGuard.clear()
	_raise_castle({})
	Game.guildwar_issue_supply()
	hold = true
	var plan := OnlineGuildWar.take_start()
	if not plan.is_empty():
		mirror_start(plan)
	else:
		zone.banner_requested.emit("สงครามกิลด์กับปาร์ตี้ · รอหัวหน้าปาร์ตี้เริ่ม")
	Game.say("เข้าสงครามกิลด์ฝั่งเดียวกับหัวหน้าปาร์ตี้: ตีศัตรูและประตูปราสาทด้วยกัน หัวหน้าปาร์ตี้เป็นคนยึดแท่น", &"quest")


## The leader's gw_start: the guilds' names, then the same countdown as the leader's.
func mirror_start(plan: Dictionary) -> void:
	if not mirror:
		return
	ally_name = String(plan.get("ally", ally_name))
	enemy_name = String(plan.get("enemy", enemy_name))
	time_left = clampf(float(plan.get("time", GuildWarData.DURATION)), 1.0, GuildWarData.DURATION)
	hold = false
	_timer = COUNTDOWN
	_count = 4
	zone.banner_requested.emit("สงครามกิลด์ · %s ปะทะ %s" % [ally_name, enemy_name])


## The clock between the leader's words, the hero's comeback, the crystal, the far ones.
func _tick_mirror(delta: float) -> void:
	if not overtime:
		time_left = maxf(0.0, time_left - delta)
	if hero_respawn_left > 0.0:
		hero_respawn_left -= delta
		if hero_respawn_left <= 0.0:
			_respawn_hero()
	_pulse_crystal(delta)
	_cull_timer -= delta
	if _cull_timer <= 0.0:
		_cull_timer = 0.25
		_cull_far()


## The leader's war status ("gw") and its end ("gw_end").
func mirror_sync(ev: String, d: Dictionary) -> void:
	if ev == "gw_end":
		_mirror_end(d)
		return
	if state == "intro" and String(d.get("st", "")) == "fight":
		hold = false
		_timer = minf(_timer, 0.01)
	time_left = clampf(float(d.get("tl", time_left)), 0.0, GuildWarData.DURATION)
	overtime = bool(d.get("ot", overtime))
	var s: Variant = d.get("s", [])
	if s is Array and (s as Array).size() >= 2:
		score = [int(s[0]), int(s[1])]
	var holder := clampi(int(d.get("o", castle_owner)), -1, 1)
	if holder != castle_owner:
		castle_owner = holder
		_color_crystal()
		if holder >= 0:
			zone.banner_requested.emit("กิลด์ %s ยึดปราสาทได้!" % team_name(holder))
			feed.emit("กิลด์ %s ยึดปราสาทได้!" % team_name(holder), holder)
	var cp: Variant = d.get("cp", [])
	if cp is Array and (cp as Array).size() >= 3:
		capture = {"team": clampi(int(cp[0]), 0, 1), "who": null, "progress": float(cp[1]), "paused": bool(cp[2]), "barrier": (cp as Array).size() >= 4 and bool(cp[3])}
	else:
		capture = {}
	# The switches as the leader reads them (switch_codes).
	var sw: Variant = d.get("sw", [])
	if sw is Array and (sw as Array).size() == SiegeArena.SWITCHES.size():
		for k in (sw as Array).size():
			var code := clampi(int(sw[k]), -2, 3)
			_set_switch(k, code - 2 if code >= 2 else maxi(code, -1), code == -2 or code >= 2)


## A mirrored fighter fell on the leader's side; the hero's blow counts as its kill.
func mirror_fell(fighter: GuildFighter, killer: String) -> void:
	if state != "fight":
		return
	if killer != "" and killer == Online.my_id():
		hero_kills += 1
		feed.emit("คุณ ล้ม %s" % fighter.rival_name, 1 - fighter.team)


## The leader rang the bell: this hero's own reward and the scoreboard.
func _mirror_end(d: Dictionary) -> void:
	if state in ["ending", "done"]:
		return
	state = "ending"
	_end_timer = 3.0
	capture = {}
	hold = false
	var won := bool(d.get("won", false))
	score = [int(d.get("us", score[0])), int(d.get("them", score[1]))]
	overtime = bool(d.get("ot", overtime))
	var rows: Array = [{"name": "คุณ", "class": String(Game.class_id()), "team": GuildFighter.TEAM_ALLY, "kills": hero_kills, "deaths": hero_deaths, "assists": 0, "grade": -1}]
	for f in all_fighters():
		if is_instance_valid(f):
			rows.append({"name": f.rival_name, "class": String(f.member["class"]), "team": f.team, "kills": f.kills, "deaths": f.deaths, "assists": f.assists, "grade": f.grade, "tag": f.tag})
	_result = Game.guildwar_finish(won, score[0], score[1], hero_kills, hero_deaths, ally_name, enemy_name, rows)
	_result["rows"] = rows
	_result["overtime"] = overtime
	_result["castle"] = String(d.get("castle", ""))
	_result["castle_ours"] = bool(d.get("ours", false))
	var held := 0 if bool(d.get("ours", false)) else (1 if String(d.get("castle", "")) != "" else -1)
	GuildLeague.war_finished(_result, Game.guild() > 0, [0, 0], held, score)
	zone.banner_requested.emit("ชนะสงคราม!" if won else "พ่ายแพ้สงคราม")
	if won and is_instance_valid(hero):
		hero.level_up_fx()
		AudioManager.play_sfx(&"quest_complete")


## The link to the leader broke: this war is over for the hero (counted as lost).
func mirror_lost() -> void:
	if not mirror or state in ["ending", "done"]:
		return
	Game.say("หลุดจากสงครามของหัวหน้าปาร์ตี้", &"warning")
	_mirror_end({"won": false})
