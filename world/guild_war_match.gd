class_name GuildWarMatch
extends Node
## One guild war, a castle siege (SiegeArena) of two to four guilds (teams; team 0 is the
## hero's when it fights): a practice war is two hired guilds, a league round all four
## guilds at once, every guild against every other (everyone not of a fighter's team is its
## enemy: SiegeFighter, hostiles). Each guild comes from its own camp out on the field
## (SiegeArena.CAMPS, all as far from the castle's approach), they meet on the plaza and
## cross the bridge to the castle, where three tiers of gates (CastleGate; the first two
## tiers have a left and a right gate, either one broken opens the tier) must be broken one
## after the other; broken gates stay broken. Behind them is the throne room: whoever stands
## on the altar for CAPTURE_TIME seconds without falling takes the castle for its guild, and
## another guild may take it the same way. The guild holding the castle at the bell places
## first; the others (and all of them with no holder) by points: falls dealt /
## GuildLeague.KILLS_PER_POINT + captures * GuildLeague.CAPTURE (placement; a tie at the top
## with no holder goes to sudden death). The fallen come back at their camp after a few
## seconds and walk back.
## Each guild's AI makes its own plan from how the war stands (plan_for): rush the gate,
## hold the bridge and strike back, pull back and regroup, storm the altar, split to block
## the way in while one takes the altar, or defend the castle; plans are told in the feed.
## One switch stands on the throne room's left side (SiegeArena.SWITCH): the first guild to
## stand in its circle while it is free takes it and keeps it while one living member of it
## is inside, however many others come in (the next guild must clear them all out of the
## circle); the altar is shut behind a barrier for every guild but the one holding it.
## While the barrier is up a leader cannot start taking the altar and a count going on
## waits where it is, until its guild holds the switch again.

signal finished(result: Dictionary)
signal feed(text: String, team: int)
signal hero_down(seconds: float)
signal hero_back()

## Each guild lines up in rows of six at its camp facing the castle (ours behind the hero's
## spot), this far apart sideways and front to back, so eighty fighters never overlap.
const ROW_SLOTS := 6
const ROW_GAP := 3.2
const ROW_DEPTH := 3.4
## Our rows stand this much behind the hero's spot, the hero at the front and centre.
const ALLY_SETBACK := 2.4
const COUNTDOWN := 4.2
## Seconds on the altar to take the castle. Shorter than a fallen defender's way back
## twice over (GuildWarData.RESPAWN at its camp, then the long walk up through the three
## gates), so an assault that wins the fight at the altar can finish the count before the
## second wave arrives; at 60 s seeded AI wars mostly ran the whole 20 minutes without a
## capture (guild_war_capture_test).
const CAPTURE_TIME := 45.0
## A gate holds out about this long against both whole guilds hitting it at once (its HP is
## set from all the fighters' strength, so more or stronger fighters meet a stronger door),
## each gate harder than the one before.
const GATE_SECONDS := 60.0
const GATE_TOUGHNESS: Array[float] = [1.0, 1.25, 1.5]
## How often a guild looks again at its plan (and at once when a gate falls or the altar changes).
const PLAN_EVERY := 12.0
## Nobody holding the castle: no guild holds back at the bridge foot past this many seconds
## of fighting (plan_for); the two strongest never do.
const HOLD_MAX := 150.0
const PLAN_NAMES := {
	"rush": "รวมพลบุกตีประตู",
	"hold": "ตั้งรับที่หัวสะพาน รอสวนกลับ",
	"regroup": "ถอยมารวมพลที่ลานกลาง รอเพื่อนเกิดแล้วค่อยบุก",
	"storm": "ทั้งกิลด์บุกห้องบัลลังก์ ยึดแท่น",
	"split": "แบ่งทีม: ครึ่งหนึ่งขวางทางหน้าห้องบัลลังก์ อีกครึ่งคุ้มกันคนยึดแท่น",
	"defend": "ล้อมแท่นปราสาท ตั้งรับ",
	"forward": "ตั้งแนวรับหน้าห้องบัลลังก์ ไม่ให้ใครเข้าใกล้แท่น",
	"gates": "ผู้ครองปราสาทออกมาตั้งรับหน้าประตูทั้งสองบาน",
}
const NEUTRAL_COLOR := Color("fff1b8")
## Parties (ปาร์ตี้): everyone in the war fights in a party of at most PARTY_SIZE. The hero
## picks up to PARTY_SIZE - 1 teammates before the war (GuildWarScreen); everybody else on
## both sides is dealt into random parties as even in size as can be. A buff (any buff
## skill: attack, guard, shield, songs...) reaches only the caster's own party; heals
## reach everyone near as before.
const PARTY_SIZE := 5
## The hero's party; the other parties of our guild count up from it, team t's (t >= 1)
## from ENEMY_PARTY_BASE * t.
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
## Seconds fought in this session of the war (game time; a resume starts it again).
var fight_clock := 0.0
var overtime := false
## Falls dealt by each team (one entry a team).
var score: Array[int] = [0, 0]
## Each team's fighters (Array[GuildFighter] per team), names and league guild ids (0 for a
## hired guild); team 0 is ours (the hero's) when the hero fights.
var sides: Array = []
var team_names: Array[String] = []
var team_guilds: Array[int] = []
## Each team's AI leader (a GuildFighter or null: team 0's is null while the hero leads).
var leaders: Array = []
## Team 0 and team 1 (older callers and the two-guild war).
var allies: Array[GuildFighter]:
	get:
		return side(0)
var enemies: Array[GuildFighter]:
	get:
		return side(1)
var ally_name: String:
	get:
		return team_names[0] if team_names.size() > 0 else ""
	set(v):
		_ensure_teams(2)
		team_names[0] = v
var enemy_name: String:
	get:
		return team_names[1] if team_names.size() > 1 else ""
	set(v):
		_ensure_teams(2)
		team_names[1] = v
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
## Team 1's leader (หัวหน้ากิลด์): the only one of its side who may take the altar. Ours is
## the hero, or the member the player picked (ally_leader). See leaders for every team.
var enemy_leader: GuildFighter:
	get:
		return _lead_at(1)
	set(v):
		_ensure_teams(2)
		leaders[1] = v
## Our guild's leader when the player picked one of its members (Game.guild_leader_name);
## null when the hero leads.
var ally_leader: GuildFighter:
	get:
		return _lead_at(0)
	set(v):
		_ensure_teams(2)
		leaders[0] = v
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
## Every team's parties as roster indices (-1 is the hero), team by team; ours[0] is the hero's.
var party_plan: Array = [[], []]

## Watching (GuildWarSpectate): the watched war's match_info ({} while the hero fights).
## Both guilds are AI, the hero is out of the war (hidden, unhurt, never a target),
## nothing is saved, paid or counted for the hero; the end goes to GuildWarSpectate.report.
var spectate: Dictionary = {}
## The spectator's camera and board (a child of the zone), while watching.
var spectator: GuildWarSpectate
## Every guild's colour while watching (team by team).
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

## The castle's switch: who holds it now (-1 nobody, else the team), read every
## SWITCH_EVERY seconds (read_switches, switch_next); fought over while another guild
## stands in the circle with the holder (switch_challenger: the one with most there).
const SWITCH_EVERY := 0.25
## The light pillar over the switch, this tall.
const SWITCH_BEAM_H := 16.0
var switch_owner := -1
var switch_contested := false
var switch_challenger := -1
## Tests and tools: the switch reads as held by this guild (-1: as the field stands).
var switch_pin := -1
## The hero's party sent to hold the switch (the HUD's button).
var party_switch := false
var _switch_left := 0.0
var _switch_parts: Dictionary = {}
## Readings of the circle so far, and the reading each team's stay in it began (the first
## come takes a free switch on a level count).
var _switch_seq := 0
var _switch_arrival: Dictionary = {}
## A resumed war: the switch stays with its saved holder until somebody steps in.
var _switch_resumed := false
var _switch_pulse := 0.0
var _switch_fight_at := -100000
var _barrier: MeshInstance3D
var _barrier_mat: StandardMaterial3D
var _barrier_hint := false
var _switch_banner_at := -100000
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
	_ensure_teams(2)
	SiegeArena.lane_open = [[false, false], [false, false]]


## How many guilds fight in this war.
func team_count() -> int:
	return sides.size()


## Whether the castle's holder starts and comes back inside the castle (KEEP_CAMP): the
## league's war of three or four guilds. A two-guild war keeps both guilds in their own
## camps, as before (the holder still walks through its own gates).
func holds_keep() -> bool:
	return team_count() > 2


## Team `t`'s fighters (an empty list for a team that is not in the war).
func side(t: int) -> Array[GuildFighter]:
	if t >= 0 and t < sides.size():
		return sides[t]
	var none: Array[GuildFighter] = []
	return none


func _lead_at(t: int) -> GuildFighter:
	if t < 0 or t >= leaders.size():
		return null
	var v: Variant = leaders[t]
	return v as GuildFighter if v != null and is_instance_valid(v) else null


## Sizes every per-team list for `n` teams (keeping what is there), and one commander per
## team (the same brain for every guild).
func _ensure_teams(n: int) -> void:
	while sides.size() < n:
		var list: Array[GuildFighter] = []
		sides.append(list)
	while team_names.size() < n:
		team_names.append("")
	while team_guilds.size() < n:
		team_guilds.append(0)
	while leaders.size() < n:
		leaders.append(null)
	while score.size() < n:
		score.append(0)
	while captures.size() < n:
		captures.append(0)
	while plans.size() < n:
		plans.append("")
	while party_plan.size() < n:
		party_plan.append([])
	while commanders.size() < n:
		commanders.append(GuildWarCommander.new(self, commanders.size()))


## Cuts every per-team list to `n` teams (a war of fewer guilds than the lists were made for).
func _set_teams(n: int) -> void:
	_ensure_teams(n)
	sides.resize(n)
	team_names.resize(n)
	team_guilds.resize(n)
	leaders.resize(n)
	score.resize(n)
	captures.resize(n)
	plans.resize(n)
	party_plan.resize(n)
	commanders.resize(n)
	for c in commanders:
		c.spread(n)


# --- Who is whose enemy (the commanders' lists, worked out once a frame) ------------
# (The fighters read their own shared view: GuildFighter._foes.)

var _lists_frame := -1
var _foes: Array = []


func _refresh_lists() -> void:
	var frame := Engine.get_physics_frames() * 4096 + Engine.get_process_frames() % 4096
	if frame == _lists_frame and _foes.size() == sides.size():
		return
	_lists_frame = frame
	_foes.clear()
	for t in sides.size():
		var foe_list: Array[GuildFighter] = []
		for o in sides.size():
			if o != t:
				foe_list.append_array(sides[o])
		_foes.append(foe_list)


## Every fighter of the other teams (standing or not). Shared: callers must not change it.
func foes_of(t: int) -> Array[GuildFighter]:
	_refresh_lists()
	if t >= 0 and t < _foes.size():
		return _foes[t]
	var none: Array[GuildFighter] = []
	return none


## Rolls the guilds, raises the castle's gates and stands everybody in their camps. With a
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
	# A league round (GuildLeague: the round the hero registered for and made the line-up
	# of) is fought by every guild's real strongest members as they were when the round
	# began, the castle held by the guild that held it after the round before (it defends
	# from inside); anything else is a practice war of hired guilds (no league points).
	started_at = int(saved.get("t0", 0)) if not saved.is_empty() and int(saved.get("t0", 0)) > 0 else int(WorldPresence.clock())
	var league := league_order(Game.guildwar_league)
	Game.guildwar_league = {}
	GuildLeague.current_match = {}
	start_owner = -1
	if not next_roster.is_empty():
		# Tests and tools: the line-ups given (a practice war, no league points).
		roster = next_roster
		next_roster = {}
		league = {}
		start_owner = int(roster.get("owner", -1))
	elif not saved.is_empty():
		var order: Array = saved.get("league", [])
		league = {"guilds": order, "at": started_at} if order.size() >= 2 else {}
	if not league.is_empty() and int((league.guilds as Array)[0]) == Game.guild():
		started_at = int(league.at)
		roster = GuildWarData.roll_guild_war(rng, league.guilds, float(started_at))
		if not roster.is_empty():
			var playing: Array = []
			for sd in roster.sides:
				playing.append(int(sd.guild))
			var held := GuildLeague.start_holder(started_at)
			start_owner = playing.find(held) if held > 0 else -1
			GuildLeague.current_match = {"guilds": playing, "at": started_at, "owner": held if start_owner >= 0 else 0}
			# The hero on the field always holds one of the GUILD_SIDE places.
			if (roster.ally as Array).size() >= GuildWarData.GUILD_SIDE:
				(roster.ally as Array).resize(GuildWarData.GUILD_SIDE - 1)
			# A late arrival joins the round as it runs: the bell rings on the round's time.
			if saved.is_empty():
				time_left = clampf(GuildWarData.DURATION - (WorldPresence.clock() - float(started_at)), 60.0, GuildWarData.DURATION)
	if roster.is_empty():
		roster = GuildWarData.roll_match(rng)
	_take_roster()
	# Who leads each side (the player picks, Game.guild_war_leader): a picked member is
	# always in its line-up. Another guild's default leader (its strongest member) leads
	# when in the line-up, else its best tank does, as always. One of the player's other
	# characters picked to lead is not in the war: the default leads instead (told below).
	var lead_names: Array[String] = []
	lead_names.resize(team_count())
	lead_names.fill("")
	stand_ins.clear()
	if bool(roster.get("guilds", false)):
		var t0 := float(started_at)
		for t in team_count():
			var g := team_guilds[t]
			if g <= 0:
				continue
			lead_names[t] = Game.guild_war_leader(g, t0)
			var lineup: Array = _lineup(t)
			if t == GuildFighter.TEAM_ALLY:
				ensure_member(lineup, lead_names[t], t0, rng)
			elif String(Game.guild_leader_of(g, t0).kind) == "member" and Game.guild_leader_pick(g) == lead_names[t]:
				ensure_member(lineup, lead_names[t], t0, rng)
			var chosen := Game.guild_leader_of(g, t0)
			if String(chosen.kind) == "alt":
				stand_ins[g] = String(chosen.name)
	_take_picks(saved)
	var party_rng := RandomNumberGenerator.new()
	party_rng.seed = hash("gw_party|%d" % roll_seed)
	party_plan = roll_parties_n(_lineup_sizes(), party_picks, party_chosen, party_rng)
	BurstGuard.clear()
	# Every other guild's leader plays a tank's build of its own points (GuildWarData.tank_build),
	# and so does ours when the player picked one of the members instead of the hero. Its
	# leader is its toughest member (GuildWarData.leader_index) unless the player picked one.
	var lead_at: Array[int] = []
	for t in team_count():
		var lineup: Array = _lineup(t)
		var at := -1
		if t == GuildFighter.TEAM_ALLY:
			if lead_names[t] != "":
				for i in lineup.size():
					if String(lineup[i].member.get("name", "")) == lead_names[t]:
						at = i
						break
		else:
			var pick := lead_names[t] if team_guilds[t] > 0 and Game.guild_leader_pick(team_guilds[t]) != "" else ""
			at = GuildWarData.leader_index(lineup, pick)
		if at >= 0:
			lineup[at] = GuildWarData.tank_build(lineup[at])
		lead_at.append(at)
	var leads: Array = await _spawn_lineups(lead_at, tree)
	for t in team_count():
		var lead: GuildFighter = leads[t]
		if lead == null and t != GuildFighter.TEAM_ALLY:
			lead = pick_leader(side(t))
		leaders[t] = lead
		if lead != null:
			lead.make_leader()
	# Our leader: the member the player picked (the same crown, the altar is theirs), else
	# the hero (with its own stats, like everyone).
	if leaders[0] == null and is_instance_valid(hero):
		LeaderMark.attach(hero, LeaderMark.guild_color(GuildFighter.TEAM_ALLY))
	_tell_stand_ins()
	_raise_castle(saved)
	Game.guildwar_issue_supply()
	if not saved.is_empty():
		_restore(saved)
	else:
		Game.guildwar_clear_checkpoint()
	if castle_owner == GuildFighter.TEAM_ALLY and is_instance_valid(hero):
		hero.global_position = hero_camp_now()
	zone.banner_requested.emit("สงครามกิลด์ · %s" % " ปะทะ ".join(team_names))
	if resumed:
		Game.say("ต่อสงครามเดิม: %s · เหลือเวลา %d นาที — ศึกถูกเก็บไว้ทุก 10 วินาที" % [siege_status(), int(ceil(time_left / 60.0))], &"quest")
		return
	var counts: PackedStringArray = []
	for t in team_count():
		counts.append("กิลด์ %s %d คน" % [team_names[t], side(t).size() + (1 if t == GuildFighter.TEAM_ALLY else 0)])
	Game.say("ชิงปราสาท %d นาที (หลุดกลับเข้าต่อได้ภายใน %d นาที): %s — ข้ามสะพาน ทำลายประตูปราสาท 3 ชั้น (ชั้น 1 และ 2 มีประตูซ้ายและขวา พังบานไหนก็ผ่านได้) ยึดสวิตช์ในห้องบัลลังก์ (ใครยืนในวงก่อนได้ไป กิลด์อื่นต้องไล่ออกจากวงให้หมดก่อน) บาเรียจะเปิดให้กิลด์ที่ถือสวิตช์ แล้วหัวหน้ากิลด์ยืนบนแท่นให้ครบ %d วินาทีโดยไม่ล้มเพื่อยึดปราสาท กิลด์ที่ยึดปราสาทไว้ได้ตอนหมดเวลาได้อันดับ 1" % [int(GuildWarData.DURATION / 60.0), Game.GW_CKPT_LIFETIME / 60, " · ".join(counts), int(CAPTURE_TIME)], &"quest")
	Game.say(owner_briefing(), &"quest")


## The camps' colours (team order) for the war the zone is about to hold: a watched war's
## sides (GuildWarSpectate's pending match_info), a league round's guilds
## (Game.guildwar_league, or the checkpoint's on a resume), else a practice war's two.
static func arena_colors() -> Array:
	var out: Array = []
	if GuildWarSpectate.is_pending():
		var info := GuildWarSpectate._pending
		var n := (info.sides as Array).size() if info.get("sides") is Array else 2
		for t in clampi(n, 2, 4):
			out.append(GuildWarSpectate.side_color(info, t))
		return out
	var order: Array = league_order(Game.guildwar_league).get("guilds", [])
	if order.is_empty() and Game.guildwar_resuming:
		order = Game.guildwar_checkpoint().get("league", [])
	if order.size() >= 2 and Game.guild() > 0:
		for g in order:
			out.append(WorldPlayers.GUILD_COLORS.get(int(g), Color.WHITE))
		return out
	return [HIRED_COLORS[0], HIRED_COLORS[1]]


## The guild that held the castle when the war began (a team, -1 nobody): it starts and
## comes back inside the castle (SiegeArena.KEEP_CAMP) and defends.
var start_owner := -1


## The league war to fight in team order {guilds: [ours, ...], at} from Game.guildwar_league
## ({guilds, at} of GuildLeague.enter_match, or an older {ours, theirs, at}); {} for none.
static func league_order(league: Dictionary) -> Dictionary:
	if league.is_empty():
		return {}
	if league.has("guilds"):
		var order: Array = []
		for g in league.guilds:
			order.append(int(g))
		return {"guilds": order, "at": int(league.get("at", 0))} if order.size() >= 2 else {}
	if league.has("ours") and league.has("theirs"):
		return {"guilds": [int(league.ours), int(league.theirs)], "at": int(league.get("at", 0))}
	return {}


## The roster's sides (roll_guild_war's "sides", or the older ally / enemy pair) into the
## per-team lists: names, guild ids and line-ups.
func _take_roster() -> void:
	if not roster.has("sides"):
		roster["sides"] = [
			{"lineup": roster.get("ally", []), "name": String(roster.get("ally_name", "")), "guild": int(roster.get("ally_guild", 0)), "power": float(roster.get("ally_power", 0.0))},
			{"lineup": roster.get("enemy", []), "name": String(roster.get("enemy_name", "")), "guild": int(roster.get("enemy_guild", 0)), "power": float(roster.get("enemy_power", 0.0))},
		]
	var list: Array = roster.sides
	_set_teams(clampi(list.size(), 2, SiegeArena.CAMPS.size()))
	for t in team_count():
		var sd: Dictionary = list[t]
		team_names[t] = String(sd.get("name", ""))
		team_guilds[t] = int(sd.get("guild", 0)) if bool(roster.get("guilds", false)) else 0
	# The first two sides are the roster's ally / enemy too (the same arrays).
	roster["ally"] = list[0].lineup
	roster["enemy"] = list[1].lineup
	start_owner = clampi(start_owner, -1, team_count() - 1)


## Team t's line-up (roster entries; the arrays the fighters are built from).
func _lineup(t: int) -> Array:
	return (roster.sides as Array)[t].lineup


func _lineup_sizes() -> Array[int]:
	var out: Array[int] = []
	for t in team_count():
		out.append(_lineup(t).size())
	return out


## The desk and the war's briefing line about the castle: ours to defend, another guild's,
## or nobody's.
func owner_briefing() -> String:
	if castle_owner < 0:
		return "ยังไม่มีใครครองปราสาท — ทุกกิลด์เริ่มจากค่ายนอกปราสาท"
	if castle_owner == GuildFighter.TEAM_ALLY and not spectating():
		return "กิลด์ของคุณครองปราสาท — ป้องกันประตูและแท่นประทับ"
	return "ปราสาทเป็นของกิลด์ %s — เริ่มอยู่ในปราสาทและป้องกันประตู" % team_name(castle_owner)


## Each guild stands in its camp party by party (the hero's party in the front row): the
## castle's holder inside the castle (KEEP_CAMP), the others in their own camps. Returns
## every team's leader fighter (lead_at: its roster index; null when not spawned).
func _spawn_lineups(lead_at: Array[int], tree: SceneTree) -> Array:
	var out: Array = []
	out.resize(team_count())
	for team in team_count():
		var lineup: Array = _lineup(team)
		var slot := 0
		var inside := team == start_owner and holds_keep()
		for p in (party_plan[team] as Array).size():
			for i in party_plan[team][p]:
				if int(i) < 0:
					continue
				var pid := p if team == GuildFighter.TEAM_ALLY else ENEMY_PARTY_BASE * team + p
				var fighter := _spawn(lineup[i], team, spawn_slot(team, slot, lineup.size(), inside), team_names[team], pid)
				side(team).append(fighter)
				if int(i) == lead_at[team]:
					out[team] = fighter
				slot += 1
				await FrameSlicer.pace(tree)
	return out


# ---------------------------------------------------------------------------
# Watching a war (GuildWarSpectate)
# ---------------------------------------------------------------------------

## True while this war is watched, not fought (spectate holds the match_info).
func spectating() -> bool:
	return not spectate.is_empty()


## Seconds the war had run when the watcher came in (0..DURATION - 1).
func watch_elapsed() -> float:
	return clampf(float(spectate.get("elapsed", 0.0)), 0.0, GuildWarData.DURATION - 1.0)


## The watched war: every guild from the match_info (its "sides", or the older ally /
## enemy pair), AI on all sides (each led by its toughest member, GuildWarData.leader_index),
## the hero out of it, the castle with the guild that held it when the round began
## ("owner": a side, -1 nobody), the clock at what is left of the war and the field as it
## plausibly stands by now (_apply_late).
func _build_spectate(tree: SceneTree) -> void:
	var info := spectate
	var rng := RandomNumberGenerator.new()
	var names: PackedStringArray = []
	if info.get("sides") is Array:
		for sd in info.sides:
			names.append(String(sd.get("name", "")))
	else:
		names = [String(info.get("ally_name", "")), String(info.get("enemy_name", ""))]
	rng.seed = hash("gw_watch|%d|%s" % [int(info.get("slot_start", 0)), "|".join(names)])
	roll_seed = int(rng.seed & 0x7fffffff)
	started_at = int(info.get("slot_start", 0)) if int(info.get("slot_start", 0)) > 0 else int(WorldPresence.clock())
	roster = {"guilds": bool(info.get("guilds", false))}
	if info.get("sides") is Array:
		roster["sides"] = (info.sides as Array).duplicate(true)
	else:
		roster.merge({
			"ally": (info.get("ally", []) as Array).duplicate(true), "enemy": (info.get("enemy", []) as Array).duplicate(true),
			"ally_name": String(info.get("ally_name", "")), "enemy_name": String(info.get("enemy_name", "")),
			"ally_power": float(info.get("ally_power", 0.0)), "enemy_power": float(info.get("enemy_power", 0.0)),
			"ally_guild": int(info.get("ally_guild", 0)), "enemy_guild": int(info.get("enemy_guild", 0)),
		})
	start_owner = int(info.get("owner", -1))
	_take_roster()
	_watch_colors.clear()
	for t in team_count():
		_watch_colors.append(GuildWarSpectate.side_color(info, t))
	party_picks.clear()
	# The hero's party is the hero alone (out of the war): every fighter is dealt.
	party_chosen = true
	var party_rng := RandomNumberGenerator.new()
	party_rng.seed = hash("gw_party|%d" % roll_seed)
	party_plan = roll_parties_n(_lineup_sizes(), [], true, party_rng)
	BurstGuard.clear()
	var lead_at: Array[int] = []
	for t in team_count():
		var lineup: Array = _lineup(t)
		var at := GuildWarData.leader_index(lineup)
		if at >= 0:
			lineup[at] = GuildWarData.tank_build(lineup[at])
		lead_at.append(at)
	_leave_war(hero)
	var leads: Array = await _spawn_lineups(lead_at, tree)
	for t in team_count():
		var lead: GuildFighter = leads[t] if leads[t] != null else pick_leader(side(t))
		leaders[t] = lead
		if lead != null:
			lead.make_leader()
	_raise_castle({})
	time_left = clampf(GuildWarData.DURATION - watch_elapsed(), 1.0, GuildWarData.DURATION)
	_apply_late(watch_elapsed(), rng)
	spectator = GuildWarSpectate.new()
	spectator.name = "GuildWarSpectate"
	spectator.setup(self)
	zone.add_child(spectator)
	zone.banner_requested.emit("ชมสงครามกิลด์ · %s" % " ปะทะ ".join(team_names))


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


## Gate tiers fall roughly this long into a war (seconds; every guild at the gates, with
## the to-and-fro of a real war): a watcher arriving late finds those already broken (one
## gate of a doubled tier, its lane by the seed).
const LATE_GATE_FALLS: Array[float] = [190.0, 420.0, 660.0]
## About this many falls a minute for each guild: the score a late watcher finds.
const LATE_FALLS_PER_MINUTE := 1.6


## A watcher arriving `elapsed` seconds into the war finds it as it might stand by then:
## the gates that would have fallen are down, each guild has some falls, most fighters
## are already out on the field between their camp and the bridge (the rest just came
## back at their camp) and the countdown is short (the war is on).
func _apply_late(elapsed: float, rng: RandomNumberGenerator) -> void:
	if elapsed <= 0.0:
		return
	for k in SiegeArena.GATE_Z.size():
		if k < LATE_GATE_FALLS.size() and elapsed >= LATE_GATE_FALLS[k]:
			var tier := gates_of_tier(k)
			if not tier.is_empty():
				tier[rng.randi() % tier.size()].set_broken_quietly()
	_update_breakable()
	var minutes := elapsed / 60.0
	for t in team_count():
		score[t] = int(round(minutes * LATE_FALLS_PER_MINUTE * rng.randf_range(0.7, 1.3)))
	if elapsed >= 30.0:
		for f in all_fighters():
			if f.team == castle_owner:
				continue
			if rng.randf() < 0.75:
				var home := SiegeArena.camp(f.team)
				var p := home.lerp(SiegeArena.APPROACH, rng.randf_range(0.55, 0.85)) + Vector3(rng.randf_range(-6.0, 6.0), 0, rng.randf_range(-4.0, 4.0))
				f.position = Vector3(p.x, 0.3, maxf(p.z, SiegeArena.MOAT_SOUTH + 3.0))
	_timer = 1.2
	_count = 2


## Where fighter `index` of a guild of `count` stands in its camp: rows of ROW_SLOTS across
## the camp's way to the castle, the first row nearest the castle, each row centred on the
## camp (ours behind the hero's spot at the camp's middle). `inside`: the castle holder's
## camp in the throne room (SiegeArena.KEEP_CAMP, rows of KEEP_ROW facing the door).
static func spawn_slot(team: int, index: int, count: int, inside := false) -> Vector3:
	var per_row := SiegeArena.KEEP_ROW if inside else ROW_SLOTS
	var row := index / per_row
	var col := index % per_row
	var in_row := mini(per_row, count - row * per_row)
	var fwd := Vector3(0, 0, 1) if inside else SiegeArena.camp_forward(team)
	var across := Vector3(-fwd.z, 0, fwd.x)
	var center := SiegeArena.KEEP_CAMP if inside else SiegeArena.camp(team)
	var lateral := (float(col) - (float(in_row) - 1.0) * 0.5) * ROW_GAP
	var depth := float(row) * ROW_DEPTH + (ALLY_SETBACK if team == GuildFighter.TEAM_ALLY else 0.0)
	var p := center + across * lateral - fwd * depth
	return Vector3(p.x, 0.3, p.z)


## Where the hero comes back in a war it did not start holding the castle in (team 0's camp).
static func hero_camp() -> Vector3:
	var c := SiegeArena.camp(GuildFighter.TEAM_ALLY)
	return Vector3(c.x, 0.3, c.z)


## Where the hero comes back now: inside the castle while our guild holds it, else our camp.
func hero_camp_now() -> Vector3:
	return home_of(GuildFighter.TEAM_ALLY) + Vector3(0, 0.3, 0)


## Team t's camp now (where it comes back): the keep while it holds the castle, else its own.
func home_of(t: int) -> Vector3:
	if t == castle_owner and castle_owner >= 0 and holds_keep():
		return SiegeArena.KEEP_CAMP
	return SiegeArena.camp(t)


## Picks up a war that was cut off: the clock, the score, the broken gates and the castle's
## holder come back, everybody starts again from their camp after a short countdown.
func _restore(saved: Dictionary) -> void:
	resumed = true
	time_left = clampf(float(saved.time_left), 1.0, GuildWarData.DURATION)
	overtime = bool(saved.overtime)
	var scores: Array = saved.get("scores", [int(saved.us), int(saved.them)])
	for t in team_count():
		score[t] = int(scores[t]) if t < scores.size() else 0
	hero_kills = int(saved.kills)
	hero_deaths = int(saved.deaths)
	# The switch's holder (an older checkpoint of two switches: the left one's); it keeps
	# the switch until somebody steps into the circle (read_switches).
	var sw: Variant = saved.get("switch", -1)
	if sw is Array:
		sw = (sw as Array)[0] if not (sw as Array).is_empty() else -1
	var holder := clampi(int(sw), -1, team_count() - 1)
	if holder >= 0:
		_switch_resumed = true
		_set_switch(holder)
	_timer = 3.2
	_count = 3


func save_checkpoint() -> void:
	if mirror or spectating():
		return
	var left: Array = []
	for g in gates:
		left.append(0 if g.is_dead() else int(ceil(1000.0 * float(g.hp) / float(maxi(1, g.max_hp)))))
	var order: Array = GuildLeague.current_match.get("guilds", []) if not GuildLeague.current_match.is_empty() else []
	Game.guildwar_save_checkpoint(roll_seed, time_left, overtime, score, hero_kills, hero_deaths, started_at, {"gates": left, "owner": castle_owner, "picks": party_picks, "chosen": party_chosen,
		"league": order, "teams": team_count(), "switch": switch_owner})


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


## Every team's parties (team by team, ours first as roll_parties deals them; each further
## team dealt like the second).
static func roll_parties_n(counts: Array[int], picks: Array, chosen: bool, rng: RandomNumberGenerator) -> Array:
	var out := roll_parties(counts[0], counts[1] if counts.size() > 1 else 0, picks, chosen, rng)
	for t in range(2, counts.size()):
		var everyone: Array = []
		for i in counts[t]:
			everyone.append(i)
		out.append(split_parties(everyone, rng))
	return out


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
		out.append(p if team == GuildFighter.TEAM_ALLY else ENEMY_PARTY_BASE * team + p)
	return out


func _spawn(info: Dictionary, team: int, at: Vector3, guild: String, party := -1) -> GuildFighter:
	var fighter := SiegeFighter.new()
	fighter.setup_fighter(info, team, hero, at, "[%s]" % guild)
	fighter.party = party
	fighter.siege = self
	fighter.position = at
	zone.add_child(fighter)
	var fwd := Vector3(0, 0, 1) if team == start_owner and holds_keep() else SiegeArena.camp_forward(team)
	fighter.visual.rotation.y = atan2(fwd.x, fwd.z)
	fighter._yaw = fighter.visual.rotation.y
	fighter.fell.connect(_on_fell)
	fighter.slew_hero.connect(func(by: GuildFighter): _hero_killer = by)
	return fighter


func all_fighters() -> Array[GuildFighter]:
	var out: Array[GuildFighter] = []
	for list in sides:
		out.append_array(list)
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
	for g in stand_ins:
		var team := maxi(0, team_guilds.find(int(g)))
		var lead := leader_of(team)
		var who := "คุณ" if lead == hero else (String((lead as GuildFighter).member.get("name", "")) if lead is GuildFighter else "ไม่มีใคร")
		out.append("หัวหน้ากิลด์ %s ไม่ได้ลงสนาม (ตัวละครของคุณที่ไม่ได้เล่นอยู่) — %s นำทัพ %s แทน" % [String(stand_ins[g]), who, WorldPlayers.guild_name(int(g))])
	return out


func _tell_stand_ins() -> void:
	for line in stand_in_lines():
		Game.say(line, &"quest")
		feed.emit(line, GuildFighter.TEAM_ALLY)


## A guild's leader: the hero for ours (or the member picked to lead it), every other
## guild's chosen one for it.
func leader_of(team: int) -> Node3D:
	if team == GuildFighter.TEAM_ALLY and hero_leads():
		return hero if is_instance_valid(hero) else null
	return ai_leader(team)


## True when the hero leads our guild (no member was picked to lead it).
func hero_leads() -> bool:
	return ally_leader == null


## A side's AI leader (a GuildFighter), null when the hero leads ours or it is gone.
func ai_leader(team: int) -> GuildFighter:
	return _lead_at(team)


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
	if team_count() > 2 and not (team == GuildFighter.TEAM_ALLY and not spectating()):
		speaker = "หัวหน้ากิลด์ %s" % team_name(team)
	feed.emit("[%s] %s" % [speaker, text], team)
	_trace("[%s] %s" % [speaker, text])
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
	_fit_switch_label()
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
	fight_clock += delta
	_ckpt_timer -= delta
	if _ckpt_timer <= 0.0:
		_ckpt_timer = CHECKPOINT_EVERY
		save_checkpoint()
	if not overtime:
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			if castle_owner < 0 and _top_tied():
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
		Game.say(barrier_text(GuildFighter.TEAM_ALLY), &"warning")
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
	return team_names[team] if team >= 0 and team < team_names.size() else ""


## Tests and tools: every tactical call and leader trace line, in order (kept short).
var trace: Array[String] = []


func _trace(line: String) -> void:
	trace.append(line)
	if trace.size() > 400:
		trace.remove_at(0)


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

## The team a blow came from (-1 unknown): a fighter's, a summon's summoner's, the hero
## and its summons and the online party (team 0), a fighter's creatures its own.
func team_of(who: Variant) -> int:
	if who == null or not is_instance_valid(who):
		return -1
	if who is GuildFighter:
		return (who as GuildFighter).team
	if who is Hero:
		return GuildFighter.TEAM_ALLY
	if who is Summon:
		return team_of((who as Summon).summoner)
	if who is SummonMob:
		return team_of((who as SummonMob).caster)
	if (who as Node).is_in_group("remote_players"):
		return GuildFighter.TEAM_ALLY
	return -1


## True when a blow by `attacker` on a castle gate comes from the guild holding the castle
## (its own gates: the hit does nothing). A blow with no attacker is the hero's.
static func owner_hit(attacker: Variant) -> bool:
	if not in_war() or current.castle_owner < 0:
		return false
	var t := GuildFighter.TEAM_ALLY if attacker == null or not is_instance_valid(attacker) else current.team_of(attacker)
	if t < 0 and attacker != null:
		return false
	return t == current.castle_owner


## Blows fighter on fighter by guild pair (blows[attacker * 4 + victim]), for the siege's
## measurements and tests (who the attackers really fight).
var blows := PackedInt32Array()


func note_blow(by: int, on: int) -> void:
	if by < 0 or by > 3 or on < 0 or on > 3:
		return
	if blows.size() < 16:
		blows.resize(16)
	blows[by * 4 + on] += 1


func _on_fell(fighter: GuildFighter, killer: Node) -> void:
	if state != "fight" or mirror:
		return
	var scoring := team_of(killer)
	var by := "ไม่ทราบ"
	if killer is GuildFighter:
		by = (killer as GuildFighter).rival_name
		(killer as GuildFighter).kills += 1
	elif killer != null and is_instance_valid(killer) and EntitySync.name_of(killer) != "":
		# A party member of ours playing online (its RemotePlayer struck the blow).
		by = EntitySync.name_of(killer)
	elif spectating():
		scoring = -1  # a watched war: the hero struck nobody
	elif fighter.team != GuildFighter.TEAM_ALLY and (killer == hero or killer == null or (killer is Summon and (killer as Summon).summoner == hero)):
		by = "คุณ"
		hero_kills += 1
		scoring = GuildFighter.TEAM_ALLY
	if scoring < 0 and team_count() == 2:
		scoring = 1 - fighter.team
	if scoring == fighter.team:
		scoring = -1
	if scoring >= 0:
		score[scoring] += 1
	_tell_commanders(fighter.team, scoring)
	feed.emit("%s ล้ม %s" % [by, fighter.rival_name], scoring)
	_after_score()


func _on_hero_died() -> void:
	if state != "fight":
		return
	hero_deaths += 1
	var killer := _hero_killer if _hero_killer != null and is_instance_valid(_hero_killer) else null
	var scoring := killer.team if killer != null else (1 if team_count() == 2 else -1)
	if scoring >= 0 and scoring != GuildFighter.TEAM_ALLY:
		score[scoring] += 1
	_tell_commanders(GuildFighter.TEAM_ALLY, scoring)
	var by := killer.rival_name if killer != null else "ศัตรู"
	if killer != null:
		killer.kills += 1
	_hero_killer = null
	feed.emit("%s ล้มคุณ" % by, scoring)
	hero_respawn_left = GuildWarData.RESPAWN
	hero_down.emit(hero_respawn_left)
	_after_score()


## A fall of `team` (to `by`, -1 unknown): its commander remembers a loss, the killer's a
## kill, and every other guild sees the two trade (a lost fight makes a guild fall back,
## GuildWarCommander.pick_tactic; a fight between two others is a chance, its leader_timing).
func _tell_commanders(team: int, by := -1) -> void:
	if team >= 0 and team < commanders.size():
		commanders[team].on_loss()
	if by < 0 and team_count() == 2:
		by = 1 - team
	if by >= 0 and by < commanders.size() and by != team:
		commanders[by].on_kill()
		for c in commanders:
			if c.team != team and c.team != by:
				c.on_others_trade(team, by)


func _after_score() -> void:
	if mirror:
		return
	save_checkpoint()
	if overtime and castle_owner < 0 and not _top_tied():
		_end()


# ---------------------------------------------------------------------------
# Placement (the league's points of a war)
# ---------------------------------------------------------------------------

## A team's war points: falls dealt / GuildLeague.KILLS_PER_POINT + captures * CAPTURE.
func war_points(t: int) -> int:
	return GuildLeague.round_points(score[t], captures[t])


## Every team, best first: the castle's holder at the bell, then by war points, then falls
## dealt, then the lower team.
func placement() -> Array[int]:
	var order: Array[int] = []
	for t in team_count():
		order.append(t)
	order.sort_custom(func(a, b):
		if (a == castle_owner) != (b == castle_owner):
			return a == castle_owner
		if war_points(a) != war_points(b):
			return war_points(a) > war_points(b)
		if score[a] != score[b]:
			return score[a] > score[b]
		return a < b)
	return order


## With nobody holding the castle, the best two teams are level (sudden death).
func _top_tied() -> bool:
	var order := placement()
	if order.size() < 2:
		return false
	var a := order[0]
	var b := order[1]
	return war_points(a) == war_points(b) and score[a] == score[b]


func _respawn_hero() -> void:
	var stats := Game.stats_now()
	Game.profile.hp = stats.max_hp
	Game.profile.mp = stats.max_mp
	hero.revive()
	hero.global_position = hero_camp_now()
	BurstGuard.forget(hero.get_instance_id())
	VfxKit.flash(zone, hero.global_position + Vector3(0, 1.0, 0), Color("bfe8ff"), 1.8)
	hero_back.emit()


# ---------------------------------------------------------------------------
# The castle: three tiers of gates (two on each of the first two), then the altar
# ---------------------------------------------------------------------------

## A gate of a doubled tier is this share of a single gate's strength (the guilds split
## between the two, and either one opens the tier).
const LANE_TOUGHNESS := 0.6


## The gates (their strength set from the fighters', tier by tier) and the altar's crystal;
## after a resume, broken gates stay broken and the holder keeps the castle. The castle's
## holder (start_owner, or the checkpoint's) walks through its own gates (_gate_pass).
func _raise_castle(saved: Dictionary) -> void:
	var total := 0.0 if spectating() else float(Game.stats_now().atk)
	for f in all_fighters():
		total += float(f.rstats.atk)
	# Two guilds' worth of strength (the average guild times two): in a war of four the
	# attackers also fight each other and the holder guards its doors, so the whole field's
	# strength made the doors last past the bell.
	var guilds := maxi(2, team_count())
	var gate_hp := maxf(200000.0, GATE_SECONDS * total * 2.0 / float(guilds) * GuildWarData.damage_scale)
	var left: Array = saved.get("gates", [])
	# A checkpoint from before the doubled gates kept one value a tier: its left gate's.
	var per_tier := left.size() == SiegeArena.GATE_Z.size()
	var k := 0
	for tier in SiegeArena.GATE_Z.size():
		var lanes := SiegeArena.TIER_LANES[tier]
		for lane in lanes:
			var gate := CastleGate.new()
			var at := Vector3(SiegeArena.gate_x(tier, lane), 0, SiegeArena.GATE_Z[tier])
			var hp := gate_hp * GATE_TOUGHNESS[tier] * (LANE_TOUGHNESS if lanes > 1 else 1.0)
			gate.setup_gate(k, at, int(hp), hero, tier, lane)
			gate.position = at
			zone.add_child(gate)
			gate.broken.connect(_on_gate_broken)
			var kept := -1
			if per_tier:
				kept = int(left[tier]) if lane == 0 else 1000
			elif k < left.size():
				kept = int(left[k])
			if kept >= 0:
				if kept <= 0:
					gate.set_broken_quietly()
				else:
					gate.hp = clampi(int(ceil(float(gate.max_hp) * float(kept) / 1000.0)), 1, gate.max_hp)
			gates.append(gate)
			k += 1
	castle_owner = clampi(int(saved.get("owner", start_owner)), -1, team_count() - 1)
	# A resumed war remembers the holder, so at least its one capture (not the one it began
	# with), and the holder starts again inside the castle.
	if castle_owner >= 0 and castle_owner != start_owner:
		captures[castle_owner] = maxi(captures[castle_owner], 1)
		_rehome(castle_owner)
		for f in side(castle_owner):
			f.position = f.spawn_point
		if start_owner >= 0:
			_rehome(start_owner)
			for f in side(start_owner):
				f.position = f.spawn_point
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
	_gate_pass()


## The castle's holder walks through its own gates, both ways (its fighters and, holding it
## ourselves, the hero): each body ignores every gate standing; everyone else meets a door.
## Called again when the castle changes hands (the new holder's gates are its own).
func _gate_pass() -> void:
	var bodies: Array = []
	bodies.append_array(all_fighters())
	if is_instance_valid(hero) and not spectating():
		bodies.append(hero)
	for g in gates:
		if not is_instance_valid(g) or g.is_dead():
			continue
		var blocker: Variant = g._blocker
		for body in bodies:
			if not is_instance_valid(body):
				continue
			var t := GuildFighter.TEAM_ALLY if body == hero else (body as GuildFighter).team
			var through := t == castle_owner and castle_owner >= 0
			for door in [g, blocker]:
				if door == null or not is_instance_valid(door):
					continue
				if through:
					(body as PhysicsBody3D).add_collision_exception_with(door)
				else:
					(body as PhysicsBody3D).remove_collision_exception_with(door)


## Whether `body` walks through the castle's standing gates now (its guild holds the castle).
func passes_gates(body: Node3D) -> bool:
	if castle_owner < 0 or body == null or not is_instance_valid(body):
		return false
	return team_of(body) == castle_owner


## The gates of tier k (the first two tiers have two, left and right).
func gates_of_tier(k: int) -> Array[CastleGate]:
	var out: Array[CastleGate] = []
	for g in gates:
		if is_instance_valid(g) and g.tier == k:
			out.append(g)
	return out


## Whether tier k is open: one of its gates is broken.
func tier_open(k: int) -> bool:
	for g in gates_of_tier(k):
		if g.is_dead():
			return true
	return false


## The first tier still shut (SiegeArena.GATE_Z.size() once every tier is open).
func front_tier() -> int:
	for k in SiegeArena.GATE_Z.size():
		if not tier_open(k):
			return k
	return SiegeArena.GATE_Z.size()


## The front tier's gates still standing (the ones to batter); [] once every tier is open.
func front_gates() -> Array[CastleGate]:
	var k := front_tier()
	var out: Array[CastleGate] = []
	if k >= SiegeArena.GATE_Z.size():
		return out
	for g in gates_of_tier(k):
		if not g.is_dead():
			out.append(g)
	return out


## The first gate of the front tier still standing (null once every tier is open).
func front_gate() -> CastleGate:
	var list := front_gates()
	return list[0] if not list.is_empty() else null


## The gates still standing.
func gates_left() -> int:
	var n := 0
	for g in gates:
		n += 0 if g.is_dead() else 1
	return n


## Only the front tier's gates can be hurt; the way through a doubled tier follows its
## broken gates (SiegeArena.lane_open).
func _update_breakable() -> void:
	var front := front_gates()
	for g in gates:
		g.breakable = front.has(g) and state != "ending"
	var open: Array = []
	for tier in 2:
		var row: Array = []
		for g in gates_of_tier(tier):
			row.append(g.is_dead())
		while row.size() < 2:
			row.append(false)
		open.append(row)
	SiegeArena.lane_open = open


func _on_gate_broken(gate: CastleGate) -> void:
	var opened := not front_gates().has(gate) and front_tier() > gate.tier
	_update_breakable()
	var text := "%s พังแล้ว!" % CastleGate.gate_label(gate.tier, gate.lane)
	if gates_of_tier(gate.tier).size() > 1:
		text += " ทางผ่านชั้นที่ %d เปิด" % (gate.tier + 1)
	if mirror:
		zone.banner_requested.emit(text)
		feed.emit(text, -1)
		return
	_make_plans()
	if front_gate() == null:
		text = "ประตูชั้นสุดท้ายพัง! บุกห้องบัลลังก์ ยึดสวิตช์ให้บาเรียเปิดให้กิลด์เรา แล้วยืนบนแท่น %d วินาทีเพื่อยึดปราสาท" % int(CAPTURE_TIME)
	if opened or front_gate() == null:
		zone.banner_requested.emit(text)
	feed.emit(text, -1)
	_assign_objectives()
	save_checkpoint()


## The front tier's gates as the HUD says them: "ประตูชั้น 1: ซ้าย 40% / ขวา 100%".
func gate_status() -> String:
	var k := front_tier()
	if k >= SiegeArena.GATE_Z.size():
		return "ประตูพังครบ 3 ชั้น"
	var list := gates_of_tier(k)
	if list.size() == 1:
		return "ประตูชั้น %d/3 · %d%%" % [k + 1, _gate_pct(list[0])]
	var parts: PackedStringArray = []
	for g in list:
		parts.append("%s %d%%" % [SiegeArena.LANE_NAMES[g.lane], _gate_pct(g)])
	return "ประตูชั้น %d: %s" % [k + 1, " / ".join(parts)]


static func _gate_pct(g: CastleGate) -> int:
	return 0 if g.is_dead() else int(ceil(100.0 * float(g.hp) / float(maxi(1, g.max_hp))))


## How many of a side are standing, and how many it has (our side counts the hero).
func _strength(team: int) -> Vector2i:
	var up := 0
	var list := side(team)
	for f in list:
		up += 0 if f.is_dead() else 1
	var total := list.size()
	if team == GuildFighter.TEAM_ALLY and not spectating():
		total += 1
		up += 1 if is_instance_valid(hero) and not hero.is_dead() else 0
	return Vector2i(up, maxi(1, total))


## The strongest other guild's standing (x) and size (y).
func _rival_strength(team: int) -> Vector2i:
	var best := Vector2i(0, 1)
	for t in team_count():
		if t != team:
			var s := _strength(t)
			if s.x > best.x:
				best = s
	return best


## A guild's plan from how the war stands: holding the castle with the gates up it comes
## out to guard them (gates); otherwise with the gates up it rushes the gate, or holds
## the bridge when the strongest other guild has many more standing; with the gates down
## it storms or splits (one group blocks the way into the throne room) while it does not
## hold the castle, defends it (on the altar, or forward at the throne room's door when
## stronger) while it does; it pulls back to regroup when most of it has fallen, until most
## are back.
func plan_for(team: int) -> String:
	var mine := _strength(team)
	var siege_on := castle_owner >= 0 and castle_owner != team and front_gate() != null
	var theirs := _rival_strength(team)
	var share := float(mine.x) / float(mine.y)
	var was := plans[team] if team < plans.size() else ""
	var holding := castle_owner == team
	var rival_taking := not capture.is_empty() and int(capture.team) != team
	if holding and front_gate() != null:
		return "gates"
	if not holding and not rival_taking and (share < 0.4 or (was == "regroup" and share < 0.7)):
		return "regroup"
	if front_gate() != null:
		# A holder in the castle: every other guild's business is its gates (no waiting at
		# the bridge foot for the others to wear each other down). Nobody holding it: a guild
		# much weaker than the strongest may hold the bridge foot a while, but never one of
		# the two strongest, and nobody past HOLD_MAX s of the war.
		if siege_on or fight_clock >= HOLD_MAX or _among_strongest(team, 2):
			return "rush"
		return "hold" if float(mine.x) < float(theirs.x) * 0.7 else "rush"
	if holding:
		return "forward" if mine.x >= theirs.x and not rival_taking else "defend"
	if rival_taking or mine.x < 6:
		return "storm"
	return "split" if mine.x >= theirs.x else "storm"


## Whether `team` is one of the `n` guilds with the most standing (ties to the lower team).
func _among_strongest(team: int, n: int) -> bool:
	var mine := _strength(team).x
	var above := 0
	for t in team_count():
		if t == team:
			continue
		var theirs := _strength(t).x
		if theirs > mine or (theirs == mine and t < team):
			above += 1
	return above < n


## The siege's focus: the castle has a holder. Every other guild then goes for the holder's
## gates and fighters, not each other (GuildFighter.holder_team), until the rivalry opens:
## with every tier open the attackers fight each other too, in the throne room, over the
## switches and the altar (GuildFighter.rivalry_open).
func siege_focus() -> bool:
	return castle_owner >= 0


func _make_plans() -> void:
	for team in team_count():
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
## sent onto the altar). Each guild batters the gate its commander picked (target_gate).
func _assign_objectives() -> void:
	var throne_door := Vector3(0, 0, SiegeArena.GATE_Z[2] - 3.0)
	var front := front_gates()
	var focus := castle_owner if siege_focus() else -1
	var open := front.is_empty()
	for team in team_count():
		var list := side(team)
		var plan := plans[team] if plans[team] != "" else plan_for(team)
		var home := SiegeArena.camp(team)
		var back := (home - SiegeArena.APPROACH).normalized()
		var c: GuildWarCommander = commanders[team] if team < commanders.size() else null
		var k := 0
		for f in list:
			var gate: CastleGate = null if team == castle_owner else (c.gate_for(f) if c != null else front_gate())
			f.capture_role = false
			f.keep_back = false
			f.keep_front = Vector3.INF
			f.hold_range = 0.0
			f.objective = gate
			f.holder_team = focus if team != castle_owner else -1
			f.rivalry_open = open
			f.rear_point = Vector3.INF
			match plan:
				"gates":
					# The holder out in front of the front tier's gates, party by party on
					# both; it never batters its own gates.
					f.objective = null
					f.hold_range = 12.0
					if front.is_empty():
						f.goal_point = _spot(SiegeArena.ALTAR, k, SiegeArena.ALTAR_RADIUS + 2.0)
					else:
						var g: CastleGate = c.defend_gate_for(f, front) if c != null else front[0]
						f.goal_point = SiegeArena.gate_front(g.tier, g.lane) + Vector3(float(k % 5 - 2) * 1.6, 0, 1.5 + float(k / 5 % 3) * 1.4)
				"regroup":
					f.objective = null
					f.hold_range = 14.0
					f.goal_point = _spot(home.lerp(SiegeArena.APPROACH, 0.45), k, 4.0)
				"hold":
					# Most hold their side of the bridge foot; one in four keeps at the gate.
					if k % 4 != 0:
						f.objective = null
						f.hold_range = 16.0
						f.goal_point = _spot(SiegeArena.APPROACH + back * 12.0, k, 3.0, PI * 0.5)
					else:
						f.goal_point = SiegeArena.gate_front(gate.tier, gate.lane) + Vector3(float(k % 5 - 2) * 1.6, 0, 0) if gate != null else SiegeArena.ALTAR
				"rush":
					f.goal_point = SiegeArena.gate_front(gate.tier, gate.lane) + Vector3(float(k % 7 - 3) * 1.3, 0, float(k / 7) * 1.8) if gate != null else SiegeArena.ALTAR
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
					f.goal_point = _spot(SiegeArena.ALTAR, k, SiegeArena.ALTAR_RADIUS + 2.0, PI / 10.0 * float(team))
				_:
					f.goal_point = _spot(SiegeArena.ALTAR, k, SiegeArena.ALTAR_RADIUS + 2.5)
			k += 1
		if team < commanders.size():
			commanders[team].apply()
	if front_gate() != null:
		return
	for team in team_count():
		if castle_owner == team or plans[team] == "regroup":
			continue
		if not capture.is_empty() and int(capture.team) == team:
			if capture.who is GuildFighter:
				(capture.who as GuildFighter).capture_role = true
			continue
		# Only a guild's leader takes the altar: the hero presses to take it when it leads
		# ours, an AI leader is sent up while it stands.
		var lead := ai_leader(team)
		if lead == null:
			continue
		# It goes up inside its guard (its commander's escort), not alone; once on the
		# altar it stays.
		if not lead.is_dead():
			var c: GuildWarCommander = commanders[team] if team < commanders.size() else null
			var resting := c != null and c.stepping_off()
			if c == null or c.allows_capture() or c.tactic == "" or (SiegeArena.on_altar(lead.global_position) and not resting):
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
# The switch and the altar's barrier
# ---------------------------------------------------------------------------

## The barrier's warning with the switch free (barrier_text gives the one for a holder).
const BARRIER_TEXT := "บาเรียกันแท่นอยู่ — ต้องยึดสวิตช์ก่อน"


## Who holds the switch after a reading (pure): `counts[t]` living bodies of each team in
## its circle, `owner` the guild holding it before (-1 nobody), `arrival[t]` the reading at
## which team t's present stay in the circle began. The holder keeps it while at least one
## of it is inside, however many others are; with none of it left the guild with the most
## bodies inside takes it, then the one that came in first, then the lower team; an empty
## circle is held by nobody.
static func switch_next(counts: Array, owner: int, arrival: Dictionary = {}) -> int:
	if owner >= 0 and owner < counts.size() and int(counts[owner]) > 0:
		return owner
	var best := -1
	for t in counts.size():
		var c := int(counts[t])
		if c <= 0:
			continue
		if best < 0 or c > int(counts[best]) or (c == int(counts[best]) and int(arrival.get(t, 1 << 30)) < int(arrival.get(best, 1 << 30))):
			best = t
	return best


## Whether `team` holds the switch now.
func holds_switch(team: int) -> bool:
	if switch_pin >= 0:
		return switch_pin == team
	return team >= 0 and switch_owner == team


## The altar's barrier stands for `team` unless it holds the switch: its leader can neither
## start taking the altar nor go on counting.
func barrier_up(team: int) -> bool:
	return not holds_switch(team)


## The living bodies inside the switch's circle, one count a team: fighters, the hero and
## (hosting online) the party members' players on our side.
func count_switch() -> Array[int]:
	var out: Array[int] = []
	out.resize(maxi(2, team_count()))
	out.fill(0)
	for t in team_count():
		for f in side(t):
			if is_instance_valid(f) and not f.is_dead() and SiegeArena.on_switch(f.global_position):
				out[t] += 1
	if not mirror and hero_alive() and SiegeArena.on_switch(hero.global_position):
		out[0] += 1
	if not mirror and is_inside_tree():
		for node in get_tree().get_nodes_in_group("remote_players"):
			if node is Node3D and EntitySync.remote_alive(node) and SiegeArena.on_switch((node as Node3D).global_position):
				out[0] += 1
	return out


## Reads the switch (every SWITCH_EVERY s; the leader's war only, a mirror takes it from
## the leader's status) and pulses its circle while it is fought over.
func _tick_switches(delta: float) -> void:
	_pulse_switch(delta)
	_switch_left -= delta
	if _switch_left > 0.0:
		return
	_switch_left = SWITCH_EVERY
	read_switches()


func read_switches() -> void:
	_switch_seq += 1
	var c := count_switch()
	for t in c.size():
		if c[t] > 0:
			if not _switch_arrival.has(t):
				_switch_arrival[t] = _switch_seq
		else:
			_switch_arrival.erase(t)
	# A resumed war gives the switch back to its holder until somebody steps into the
	# empty circle (everybody starts again from the camps).
	if _switch_resumed:
		if c.max() == 0:
			return
		_switch_resumed = false
	var holder := switch_next(c, switch_owner, _switch_arrival)
	# Fought over: the holder still inside with another guild in the circle; the
	# challenger is the one with the most bodies there.
	var challenger := -1
	if holder >= 0:
		for t in c.size():
			if t != holder and c[t] > 0 and (challenger < 0 or c[t] > c[challenger]):
				challenger = t
	_set_switch(holder, challenger)


## The switch changes hands or its fight starts / ends (told in the feed and a toast,
## recoloured with a flash, the commanders told at once).
func _set_switch(holder: int, challenger := -1) -> void:
	var was := switch_owner
	var was_challenger := switch_challenger
	if holder == was and challenger == was_challenger:
		return
	switch_owner = holder
	switch_challenger = challenger if holder >= 0 else -1
	switch_contested = switch_challenger >= 0
	if not switch_contested:
		_switch_pulse = 0.0
	_color_switch()
	_show_barrier()
	if holder != was and zone != null and is_instance_valid(zone):
		var color := team_color(holder) if holder >= 0 else Color.WHITE
		VfxKit.flash(zone, SiegeArena.SWITCH + Vector3(0, 1.0, 0), color, 4.0, 0.35)
		VfxKit.shockwave(zone, SiegeArena.SWITCH + Vector3(0, 0.3, 0), color, SiegeArena.SWITCH_RADIUS + 1.5)
	if state != "fight":
		return
	if holder >= 0 and holder != was:
		var text := "กิลด์ %s ยึดสวิตช์ได้! บาเรียเปิดให้กิลด์ %s" % [team_name(holder), team_name(holder)]
		if was >= 0:
			text = "กิลด์ %s ไล่กิลด์ %s ออกจากวงสวิตช์ — บาเรียเปิดให้กิลด์ %s" % [team_name(holder), team_name(was), team_name(holder)]
		feed.emit(text, holder)
		# The toast at most every 6 s (a switch fought over may change hands often).
		var now_ms := Time.get_ticks_msec()
		if now_ms - _switch_banner_at > 6000:
			_switch_banner_at = now_ms
			Game.say("กิลด์ %s ยึดสวิตช์ได้! บาเรียเปิดให้กิลด์ %s" % [team_name(holder), team_name(holder)], &"info")
	elif holder < 0 and was >= 0:
		feed.emit("กิลด์ %s ไม่เหลือใครในวงสวิตช์ — สวิตช์ว่าง บาเรียกลับมากันแท่น" % team_name(was), was)
	elif holder >= 0 and switch_challenger >= 0 and was_challenger < 0:
		var now_ms := Time.get_ticks_msec()
		if now_ms - _switch_fight_at > 8000:
			_switch_fight_at = now_ms
			feed.emit("กิลด์ %s บุกวงสวิตช์! กิลด์ %s ยังถือสวิตช์อยู่ — ต้องไล่ออกจากวงให้หมด" % [team_name(switch_challenger), team_name(holder)], -1)
	for c in commanders:
		c.on_switch_change()


## Who holds the switch, for the online status as a party member sees the war (ours or not:
## 0 our guild, 1 any other): -1 nobody, 0 / 1 held, 2 / 3 held and fought over.
func switch_code() -> int:
	if switch_owner < 0:
		return -1
	return mini(switch_owner, 1) + (2 if switch_contested else 0)


## A member's war takes the switch from the leader's code (switch_code); an older leader's
## two codes, one a switch: the left one's.
func apply_switch_code(code: Variant) -> void:
	if code is Array:
		code = (code as Array)[0] if not (code as Array).is_empty() else -1
	var n := clampi(int(code), -2, 3)
	if n < 0:
		_set_switch(-1)
		return
	var holder := n % 2
	_set_switch(holder, (1 - holder) if n >= 2 else -1)


## How the HUD names a holding guild: เรา / ศัตรู in a war of two the hero fights, else its name.
func _holder_word(t: int) -> String:
	if not spectating() and t == GuildFighter.TEAM_ALLY:
		return "เรา"
	if not spectating() and team_count() == 2:
		return "ศัตรู"
	return team_name(t)


## The HUD's chip for the switch: "สวิตช์: <guild>" (ว่าง when free), and the fight in
## its circle.
func switch_text() -> String:
	var holder := switch_owner if switch_pin < 0 else switch_pin
	if holder < 0:
		return "%s: ว่าง" % SiegeArena.SWITCH_NAME
	if switch_contested and switch_pin < 0:
		return "%s: %s · %s กำลังแย่ง" % [SiegeArena.SWITCH_NAME, _holder_word(holder), _holder_word(switch_challenger)]
	return "%s: %s" % [SiegeArena.SWITCH_NAME, _holder_word(holder)]


## Who the barrier is open for: "บาเรียเปิดให้ <guild>", or shut with the switch free.
func barrier_open_text() -> String:
	var holder := switch_owner if switch_pin < 0 else switch_pin
	if holder < 0:
		return "บาเรียปิดแท่น"
	return "บาเรียเปิดให้ %s" % _holder_word(holder)


## The label over the switch in the world: the holder's name (and who is fighting it for
## the switch), seen from the throne room's door and the spectator's camera.
func switch_label() -> String:
	var holder := switch_owner if switch_pin < 0 else switch_pin
	if holder < 0:
		return "%s: ว่าง" % SiegeArena.SWITCH_NAME
	if switch_contested and switch_pin < 0:
		return "%s ถือสวิตช์ · %s กำลังแย่ง" % [team_name(holder), team_name(switch_challenger)]
	return "%s: %s\nบาเรียเปิดให้ %s" % [SiegeArena.SWITCH_NAME, team_name(holder), team_name(holder)]


## The holder's colour (grey when free).
func switch_color() -> Color:
	var holder := switch_owner if switch_pin < 0 else switch_pin
	return Color("c9c9c9") if holder < 0 else team_color(holder)


## The barrier's warning for `team`'s leader: who to clear out of the switch's circle.
func barrier_text(team: int) -> String:
	if switch_owner >= 0 and switch_owner != team and switch_pin < 0:
		return "บาเรียกันแท่นอยู่ — ต้องไล่กิลด์ %s ออกจากวงสวิตช์ก่อน" % team_name(switch_owner)
	return BARRIER_TEXT


## The HUD's warning while our guild's leader waits behind the barrier ("" otherwise).
func barrier_line() -> String:
	if state != "fight" or front_gate() != null or castle_owner == GuildFighter.TEAM_ALLY or not barrier_up(GuildFighter.TEAM_ALLY):
		return ""
	if not capture.is_empty() and int(capture.team) == GuildFighter.TEAM_ALLY and bool(capture.get("barrier", false)):
		return barrier_text(GuildFighter.TEAM_ALLY)
	var lead := leader_of(GuildFighter.TEAM_ALLY)
	if not mirror and lead != null and is_instance_valid(lead) and not bool(lead.call("is_dead")) and SiegeArena.on_altar(lead.global_position):
		return barrier_text(GuildFighter.TEAM_ALLY)
	return ""


## Sends the hero's party to hold the switch (pressed again: back to the guild's plan).
## Returns what to tell the player.
func order_party_switch() -> String:
	if mirror or state not in ["intro", "fight"]:
		return ""
	party_switch = not party_switch
	_assign_objectives()
	return "สั่งปาร์ตี้ไปยืนยึดสวิตช์" if party_switch else "ปาร์ตี้กลับไปตามแผนกิลด์"


## The switch pad (a glowing ring on the floor in the holder's colour, a stone post with a
## lever and a glowing orb, a tall light pillar and the holder's name over it) and the
## barrier dome over the altar. Cheap: unshaded materials recoloured on a change, no light,
## no particles.
func _raise_switches() -> void:
	if zone == null:
		return
	_switch_parts.clear()
	var stone := MeshKit.toon(SiegeArena.STONE)
	var root := Node3D.new()
	root.name = "CastleSwitch"
	root.position = SiegeArena.SWITCH
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
	# The post stands at the circle's edge on the wall side (west).
	var post := Vector3(-SiegeArena.SWITCH_RADIUS * 0.55, 0, 0)
	MeshKit.part(root, MeshKit.cylinder(), stone, post + Vector3(0, 1.2, 0), Vector3(0.8, 2.4, 0.8))
	MeshKit.part(root, MeshKit.box(), MeshKit.toon(SiegeArena.WOOD), post + Vector3(0.35, 2.6, 0), Vector3(0.18, 1.3, 0.18), Vector3(0, 0, -35))
	var orb_mat := (MeshKit.toon(Color.WHITE, {"emission": 1.4}) as StandardMaterial3D).duplicate() as StandardMaterial3D
	var orb := MeshKit.part(root, MeshKit.sphere_low(), orb_mat, post + Vector3(0, 2.75, 0), Vector3(0.75, 0.75, 0.75))
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The light pillar: a tall see-through column in the holder's colour over the circle,
	# seen over the fight from the door and from the spectator's camera.
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.albedo_color = Color(1, 1, 1, 0.08)
	MaterialKeeper.keep(beam_mat)
	var beam := MeshKit.part(root, MeshKit.cylinder(), beam_mat, Vector3(0, SWITCH_BEAM_H * 0.5, 0), Vector3(SiegeArena.SWITCH_RADIUS * 1.1, SWITCH_BEAM_H, SiegeArena.SWITCH_RADIUS * 1.1), Vector3.ZERO, "Beam")
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tag := Label3D.new()
	tag.name = "SwitchLabel"
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.pixel_size = 0.02
	tag.font_size = 64
	tag.outline_size = 18
	tag.outline_modulate = Color(0, 0, 0, 0.85)
	tag.no_depth_test = true
	tag.position = Vector3(0, 6.5, 0)
	root.add_child(tag)
	_switch_parts = {"floor": floor_mat, "ring": ring_mat, "orb": orb_mat, "beam": beam_mat, "tag": tag}
	_color_switch()
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


## The switch's colour on the ground, the orb, the light pillar and the label: the holder's,
## neutral white when free (blended towards the challenger's while fought over, _pulse_switch).
func _color_switch(blend := 0.0) -> void:
	if _switch_parts.is_empty():
		return
	var held := switch_owner >= 0 or switch_pin >= 0
	var color := switch_color() if held else Color("f2f2f2")
	if blend > 0.0 and switch_challenger >= 0:
		color = color.lerp(team_color(switch_challenger), blend)
	(_switch_parts.ring as StandardMaterial3D).albedo_color = color
	(_switch_parts.floor as StandardMaterial3D).albedo_color = Color(color, 0.42 if held else 0.16)
	(_switch_parts.orb as StandardMaterial3D).albedo_color = color
	(_switch_parts.orb as StandardMaterial3D).emission = color
	(_switch_parts.beam as StandardMaterial3D).albedo_color = Color(color, 0.3 if held else 0.06)
	var tag := _switch_parts.tag as Label3D
	tag.text = switch_label()
	tag.modulate = switch_color().lerp(Color.WHITE, 0.2) if held else Color("f2f2f2")


## The tallest the switch's floating label's line may look on screen (logical px).
const SWITCH_LABEL_MAX_PX := 26.0
const SWITCH_LABEL_PIXEL := 0.02
## The lowest the label may sit (a share of the screen height): above the controls.
const SWITCH_LABEL_LOW := 0.7


## The switch's floating label stays a readable, capped size on screen (it shrinks as the
## camera comes close instead of filling the view) and hides while it would sit in the
## top band the guild war's board holds (GuildWarHud.top_band), in the toasts' lane under
## it (ToastLayer.lane_bottom) or off the screen.
func _fit_switch_label() -> void:
	if _switch_parts.is_empty():
		return
	var tag := _switch_parts.tag as Label3D
	if not is_instance_valid(tag) or not tag.is_inside_tree():
		return
	var cam := tag.get_viewport().get_camera_3d()
	if cam == null:
		return
	var depth := -(cam.global_transform.affine_inverse() * tag.global_position).z
	if depth <= 0.5:
		tag.visible = false
		return
	var view := tag.get_viewport().get_visible_rect().size
	var span := 2.0 * depth * tan(deg_to_rad(cam.fov) * 0.5)
	tag.pixel_size = minf(SWITCH_LABEL_PIXEL, SWITCH_LABEL_MAX_PX * span / (view.y * float(tag.font_size)))
	var line_px := float(tag.font_size) * tag.pixel_size / span * view.y
	var p := cam.unproject_position(tag.global_position)
	var top_px := p.y - line_px * 0.5 * float(tag.text.count("\n") + 1)
	# Also clear of the bottom row of controls (joystick, chat, skills).
	tag.visible = top_px > maxf(GuildWarHud.top_band, ToastLayer.lane_bottom) + 12.0 and p.y < view.y * SWITCH_LABEL_LOW and p.x > 0.0 and p.x < view.x


## The switch's floating label now (tests): shown, its line's height and place on screen (px).
func switch_label_screen() -> Dictionary:
	if _switch_parts.is_empty():
		return {}
	var tag := _switch_parts.tag as Label3D
	var cam := tag.get_viewport().get_camera_3d()
	if cam == null:
		return {"visible": tag.visible, "line_px": 0.0, "pos": Vector2.ZERO}
	var depth := maxf(0.01, -(cam.global_transform.affine_inverse() * tag.global_position).z)
	var px := float(tag.font_size) * tag.pixel_size / (2.0 * depth * tan(deg_to_rad(cam.fov) * 0.5)) * tag.get_viewport().get_visible_rect().size.y
	return {"visible": tag.visible, "line_px": px, "pos": cam.unproject_position(tag.global_position)}


## While the switch is fought over its circle flickers between the holder's colour and the
## challenger's (a few materials recoloured, nothing else).
func _pulse_switch(delta: float) -> void:
	if not switch_contested or _switch_parts.is_empty():
		return
	_switch_pulse += delta
	_color_switch(0.5 + 0.5 * sin(_switch_pulse * 7.0))


## The switch's look now (tests): the ring's colour, the label's text and colour, the pillar's.
func switch_look() -> Dictionary:
	if _switch_parts.is_empty():
		return {}
	return {"ring": (_switch_parts.ring as StandardMaterial3D).albedo_color, "beam": (_switch_parts.beam as StandardMaterial3D).albedo_color,
		"label": (_switch_parts.tag as Label3D).text, "label_color": (_switch_parts.tag as Label3D).modulate,
		"barrier": _barrier_mat.albedo_color if _barrier_mat != null else Color.BLACK}


## The dome over the altar: shut (pale blue) with the switch free, tinted the holder's
## colour while it is open for that guild alone (it stays shut for everyone else).
func _show_barrier() -> void:
	if _barrier == null or _barrier_mat == null:
		return
	var holder := switch_owner if switch_pin < 0 else switch_pin
	_barrier_mat.albedo_color = BARRIER_COLOR if holder < 0 else Color(team_color(holder).lerp(Color.WHITE, 0.15), BARRIER_COLOR.a)
	_barrier.visible = true


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
## but for the barrier (our guild does not hold the switch).
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
## barrier down for its guild (it holds the switch). Off the circle, or with the switch
## lost (the barrier is back), the count waits where it was and goes on when the leader
## steps back on / the switch is held again; the leader falling or leaving the throne
## room starts it over. A paused count gives way to the other guild's leader on the circle
## with the barrier down for its own guild.
func _tick_capture(delta: float) -> void:
	if front_gate() != null:
		return
	if capture.is_empty():
		for team in team_count():
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
		# A leader stepping off to be healed (GuildWarCommander.resting) walks, it does not hold.
		(who as GuildFighter).capturing = on and not (team < commanders.size() and commanders[team].stepping_off())
	var blocked := barrier_up(team)
	if not on or blocked:
		if not on and not bool(capture.get("paused", false)):
			feed.emit("%s ออกนอกวงสีเหลือง — หยุดนับไว้ที่ %d/%d วิ" % [_who_name(who), int(capture.progress), int(CAPTURE_TIME)], team)
		if blocked and not bool(capture.get("barrier", false)):
			capture["barrier"] = true
			feed.emit("บาเรียกลับมากันแท่น! กิลด์ %s หยุดนับที่ %d/%d วิ — %s" % [team_name(team), int(capture.progress), int(CAPTURE_TIME), ("ต้องไล่กิลด์ %s ออกจากวงสวิตช์ก่อน" % team_name(switch_owner)) if switch_owner >= 0 else "ต้องยึดสวิตช์คืน"], team)
			if zone != null and is_instance_valid(zone):
				VfxKit.shockwave(zone, SiegeArena.ALTAR + Vector3(0, 0.4, 0), Color(BARRIER_COLOR, 1.0), 5.0)
		capture["paused"] = true
		_offer_altar(team)
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


## A paused count of `team` gives way to another guild's leader standing on the altar
## with the barrier down for its own guild.
func _offer_altar(team: int) -> void:
	for other_team in team_count():
		if other_team == team:
			continue
		var other := ai_leader(other_team)
		if other != null and not other.is_dead() and castle_owner != other_team and not barrier_up(other_team) and SiegeArena.on_altar(other.global_position):
			_cancel_capture()
			_start_capture(other_team, other)
			return


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
		feed.emit("หัวหน้ากิลด์ %s %s — การยึดแท่นต้องนับใหม่!" % [team_name(int(capture.team)), reason], -1)
	else:
		feed.emit("การยึดแท่นของกิลด์ %s ถูกขัด!" % team_name(int(capture.team)), -1)
	capture = {}


func _complete_capture() -> void:
	var team := int(capture.team)
	var who: Variant = capture.get("who")
	if who is GuildFighter and is_instance_valid(who):
		(who as GuildFighter).capturing = false
	capture = {}
	var lost := castle_owner
	castle_owner = team
	captures[team] += 1
	# The castle is the new holder's: its gates let it through, the old holder's no more,
	# and both come back at their new homes (the keep, their own camp).
	_gate_pass()
	_rehome(team)
	if lost >= 0:
		_rehome(lost)
	if team_count() == 2:
		_send_home(1 - team)
	else:
		for t in team_count():
			if t != team:
				_send_home(t, true)
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
## With `in_castle` only those inside the throne room go (a war of more than two: the
## whole field is not swept for one capture).
func _send_home(team: int, in_castle := false) -> void:
	var sent := 0
	for f in side(team):
		if is_instance_valid(f) and not f.is_dead():
			if in_castle and SiegeArena.section(f.global_position) < 4:
				continue
			f.send_home()
			sent += 1
			VfxKit.flash(zone, f.global_position + Vector3(0, 1.0, 0), Color("bfe8ff"), 1.2)
	if team == GuildFighter.TEAM_ALLY and is_instance_valid(hero) and not hero.is_dead() and not spectating() \
			and not (in_castle and SiegeArena.section(hero.global_position) < 4):
		sent += 1
		hero.velocity = Vector3.ZERO
		hero.global_position = hero_camp_now()
		BurstGuard.forget(hero.get_instance_id())
		VfxKit.flash(zone, hero.global_position + Vector3(0, 1.0, 0), Color("bfe8ff"), 1.8)
	if sent > 0 or not in_castle:
		feed.emit("กิลด์ %s ถูกส่งกลับฐาน ต้องบุกขึ้นมายึดแท่นใหม่ %d วินาที" % [team_name(team), int(CAPTURE_TIME)], team)


## Team t's fighters come back at its home now (the keep while it holds the castle).
func _rehome(t: int) -> void:
	var list := side(t)
	var inside := t == castle_owner and holds_keep()
	for i in list.size():
		list[i].spawn_point = spawn_slot(t, i, list.size(), inside)


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
		if spectating():
			return ""
		return "ป้องกันแท่นไว้ อย่าให้กิลด์อื่นยึดได้" if castle_owner == GuildFighter.TEAM_ALLY else "บุกขึ้นไปยึดแท่น %d วิ เพื่อชิงปราสาท" % int(CAPTURE_TIME)
	var who := capturer()
	var who_name := _who_name(who) if who != null else ""
	if bool(capture.get("barrier", false)):
		return "กิลด์ %s หยุดนับที่ %d/%d วิ — %s" % [team_name(int(capture.team)), int(capture.progress), int(CAPTURE_TIME), barrier_text(int(capture.team))]
	if bool(capture.get("paused", false)):
		return "กิลด์ %s หยุดนับที่ %d/%d วิ%s — กลับเข้าวงสีเหลืองเพื่อนับต่อ" % [team_name(int(capture.team)), int(capture.progress), int(CAPTURE_TIME), (" (%s)" % who_name) if who_name != "" else ""]
	return "กิลด์ %s กำลังยึดแท่น%s %d/%d วิ" % [team_name(int(capture.team)), (" (%s)" % who_name) if who_name != "" else "", int(capture.progress), int(CAPTURE_TIME)]


## The holder's colour for the HUD (the crystal's).
func owner_color() -> Color:
	return _owner_color()


func _owner_color() -> Color:
	return NEUTRAL_COLOR if castle_owner < 0 else team_color(castle_owner)


## A guild's colour (its guild colour in a war between real guilds, else blue / red).
## Hired guilds' colours by team (a practice war): blue, red, green, orange.
const HIRED_COLORS: Array[Color] = [Color("4a8cff"), Color("ff5a4a"), Color("4fd36b"), Color("ffa63d")]


func team_color(team: int) -> Color:
	if team < 0:
		return NEUTRAL_COLOR
	# Watching: every guild's own colour (match_info, see GuildWarSpectate.side_color),
	# whatever guild the hero is in.
	if not _watch_colors.is_empty():
		return _watch_colors[clampi(team, 0, _watch_colors.size() - 1)]
	var guild := team_guilds[team] if team < team_guilds.size() else 0
	if guild == 0 and team == GuildFighter.TEAM_ALLY:
		guild = int(roster.get("ally_guild", 0))
	if Game.guild() > 0 and bool(roster.get("guilds", false)) and guild > 0:
		return WorldPlayers.GUILD_COLORS.get(guild, NEUTRAL_COLOR)
	return HIRED_COLORS[team % HIRED_COLORS.size()]


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
	parts.append(gate_status())
	parts.append("ปราสาท: %s" % ("ยังไม่มีใครยึด" if castle_owner < 0 else "กิลด์ %s ยึดอยู่" % team_name(castle_owner)))
	if not capture.is_empty():
		parts.append("กิลด์ %s กำลังยึด %d/%d วิ" % [team_name(int(capture.team)), int(capture.progress), int(CAPTURE_TIME)])
	if gate == null:
		parts.append("%s · %s" % [switch_text(), barrier_open_text()])
	return " · ".join(parts)


## The HUD's second line: who is standing on each side and our guild's plan.
func sides_status() -> String:
	var ours := _strength(GuildFighter.TEAM_ALLY)
	var theirs := _rival_strength(GuildFighter.TEAM_ALLY)
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
	var order := placement()
	var won := order[0] == GuildFighter.TEAM_ALLY if castle_owner >= 0 or team_count() > 2 else score[0] > score[1]
	var place := order.find(GuildFighter.TEAM_ALLY) + 1
	var rows: Array = [{"name": "คุณ", "class": String(Game.class_id()), "team": GuildFighter.TEAM_ALLY, "kills": hero_kills, "deaths": hero_deaths, "assists": 0, "grade": -1}]
	for f in all_fighters():
		rows.append({"name": f.rival_name, "class": String(f.member["class"]), "team": f.team, "kills": f.kills, "deaths": f.deaths, "assists": f.assists, "grade": f.grade, "tag": f.tag})
	var rivals: PackedStringArray = []
	var best_rival := 0
	for t in range(1, team_count()):
		rivals.append(team_name(t))
		best_rival = maxi(best_rival, score[t])
	_result = Game.guildwar_finish(won, score[0], best_rival if team_count() > 2 else score[1], hero_kills, hero_deaths, ally_name, " / ".join(rivals), rows)
	_result["rows"] = rows
	_result["overtime"] = overtime
	_result["castle"] = team_name(castle_owner) if castle_owner >= 0 else ""
	_result["castle_ours"] = castle_owner == GuildFighter.TEAM_ALLY
	_result["placement"] = place
	_result["places"] = _places(order)
	_result["team_names"] = Array(team_names)
	GuildLeague.war_finished(_result, bool(roster.get("guilds", false)), captures, castle_owner, score)
	var head := "ชนะสงคราม!" if won else "พ่ายแพ้สงคราม"
	if team_count() > 2:
		head = "อันดับ 1! ชนะสงคราม" if won else "จบอันดับ %d จาก %d กิลด์" % [place, team_count()]
	zone.banner_requested.emit(head + (" ยึดปราสาทได้" if won and castle_owner == GuildFighter.TEAM_ALLY else ""))
	if won and is_instance_valid(hero):
		hero.level_up_fx()
		AudioManager.play_sfx(&"quest_complete")


## The standings for the boards: [{team, name, place, kills, captures, points, holder}] best first.
func _places(order: Array[int]) -> Array:
	var out: Array = []
	for i in order.size():
		var t := order[i]
		out.append({"team": t, "name": team_name(t), "place": i + 1, "kills": score[t], "captures": captures[t], "points": war_points(t), "holder": t == castle_owner})
	return out


## The bell of a watched war: the placement (the castle's holder, then points), the
## scoreboard and the hook for the league (GuildWarSpectate.report). Nothing is paid.
func _end_watched() -> void:
	var order := placement()
	var winner := order[0]
	if castle_owner < 0 and _top_tied():
		winner = -1
	var rows: Array = []
	for f in all_fighters():
		if is_instance_valid(f):
			rows.append({"name": f.rival_name, "class": String(f.member["class"]), "team": f.team, "kills": f.kills, "deaths": f.deaths, "assists": f.assists, "grade": f.grade, "tag": f.tag})
	_result = {
		"spectated": true, "winner": winner, "winner_name": team_name(winner) if winner >= 0 else "",
		"ally_name": ally_name, "enemy_name": enemy_name, "score": Array(score), "team_names": Array(team_names),
		"captures": Array(captures), "castle_owner": castle_owner, "start_owner": start_owner,
		"castle": team_name(castle_owner) if castle_owner >= 0 else "", "overtime": overtime, "places": _places(order),
		"rows": rows, "league_match": spectate.get("league_match", []), "league_round": spectate.get("league_round", []),
		"slot_start": int(spectate.get("slot_start", 0)),
	}
	GuildWarSpectate.report(spectate, _result)
	zone.banner_requested.emit(("กิลด์ %s ชนะสงคราม!" % team_name(winner)) if winner >= 0 else "สงครามจบลงด้วยผลเสมอ")
	AudioManager.play_sfx(&"quest_complete")


## The HUD's score line: "A 3 : 5 B" for two guilds, "A 3 · B 5 · C 1 · D 2" (the holder crowned) for more.
func score_line() -> String:
	if team_count() <= 2:
		return "%s  %d : %d  %s" % [ally_name, score[0], score[1], enemy_name]
	var parts: PackedStringArray = []
	for t in team_count():
		parts.append("%s%s %d" % [GuildLeague.CROWN if t == castle_owner else "", team_name(t), score[t]])
	return " · ".join(parts)


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
	var holder := clampi(int(d.get("o", castle_owner)), -1, team_count() - 1)
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
	# The switch as the leader reads it (switch_code).
	if d.has("sw"):
		apply_switch_code(d.get("sw"))


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
