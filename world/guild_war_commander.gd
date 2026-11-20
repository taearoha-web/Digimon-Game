class_name GuildWarCommander
extends RefCounted
## One guild's war chief in the castle siege (GuildWarMatch keeps one per guild, two to
## four, and every guild runs this same brain, so none plays smarter by design). Everyone
## not of its guild is a foe (GuildWarMatch.foes_of); the castle's holder defends against
## all of them. The guild's plan
## (GuildWarMatch.plan_for: rush, hold, regroup, storm, split, defend, forward) says where
## the war is fought; the commander says how, every THINK_EVERY seconds of war time:
##   gather   (รวมพล)  wait for the guild at a rally point before a gate or the throne room,
##             instead of trickling in one by one, then push together, buffed;
##   push     (บุก)    hit the gate together, tanks in front, ranged and healers behind;
##   escort   (คุ้มกัน) the assault on the altar. With an AI leader the members go in first
##             (บุกก่อน หัวกิลตามหลัง): onto the altar to clear it while the leader comes
##             right behind them (LEADER_GAP) with its healers; it goes up inside its guard
##             once the way is clear (leader_may_go). With the hero leading ours they go a
##             step ahead of the hero (the player is never moved);
##   guard    (ป้องกันหัวหน้า) the leader is taking the altar or is hurt: tanks peel the
##             attackers off it, healers stay at its side; an AI leader nearly down steps
##             off behind the altar to be healed (its count waits, a fall would reset it);
##   defend   (ตั้งรับ) the other guild is taking the altar (everyone at the one on it) or
##             the plan is to hold a line;
##   fallback (ถอย)    a lost fight: pull back to the last rally point, wait for the fallen
##             to come back, then go again.
## The castle has no switches: with the gates down the altar is open to every guild, and a
## leader standing on it CAPTURE_TIME s takes the castle. While the leader is on the altar
## half of the tanks and fighters screen the throne room's door.
## The AI leader is its guild's toughest fighter and comes with it, never waiting at the
## camp while its guild fights (หัวกิลบุกพร้อมทัพ, _leader_post): the damage dealers and
## tanks lead, it stands LEADER_GAP behind its front line (_front_post) with its healers
## and bard at its sides, fights what comes within LEADER_REACH (and batters the gate its
## guild pushes); hurt it stands LEADER_HURT_BACK farther back, badly hurt it falls back
## to heal like anyone (GuildFighter.retreat_below); with enemies swarming it, behind its
## own (_cover_point). Holding the castle it stands behind its defenders out in front of
## the gate pressed harder, and by the altar once the gates are down.
## The gates: of a doubled tier it batters the weaker or less defended gate, or splits the
## push party by party when both are alike and it is big enough (gate_for); holding the
## castle it comes out in front of both gates, more on the one pressed harder
## (defend_gate_for), and falls back tier by tier as they break.
## The leader's capture plan (leader_timing, _leader_orders): with the gates down it
## picks its moment (it waits while two other guilds trade blows round the altar, strikes
## when they have worn each other down or their leaders are down), sends its vanguard to
## clear the altar, keeps its healers and a Defender at its side and
## a screen between it and the nearest foes; on the altar it reads the wave coming (a
## stronger group on its way: it steps off, the count waiting, and comes back when it has
## passed: evading). Another guild's leader on the altar: the main body goes for it (the
## only way to stop its count) and the leader goes up to take over. The holder counter-pushes
## the guild nearest to taking the castle (counter_team). Its moves are told in the feed
## (GuildWarMatch.trace too). The leader's wait for a clash is TIMING_MAX s at most, and
## not again within TIMING_REST s.
## The siege's focus (GuildWarMatch.siege_focus: the castle has a holder): every other
## guild's business is the castle and the holder. It marks only the holder's fighters (its
## called target, its assassins' dive: _siege_mark), picks the gate less defended by the
## holder's own, gathers out of the holder's reach in the yards (SIEGE_RALLY) and sends its
## hurt back to just behind its leader rather than its far camp; the other attacking guilds are
## rivals again only in the throne room with every gate down (_rival_open).
## It also calls a focus target for the whole guild (whoever takes the altar, then a healer
## or bard, an exposed leader, the weak), sends its assassins round to the back line, keeps
## stuns from landing on a target that is already stunned, and shouts short callouts in the
## war chat (rate limited). Cheap: nothing runs per frame but a clock; it thinks every
## 1.5 s and lays out the formation with the match's objectives (every 0.5 s).

const THINK_EVERY := 1.5

## Roles by class: where a fighter stands in the formation and how it picks targets.
enum { ROLE_TANK, ROLE_MELEE, ROLE_ASSASSIN, ROLE_RANGED, ROLE_BARD, ROLE_HEALER, ROLE_LEADER }
const ROLE_NAMES := ["แนวหน้า", "ประชิด", "นักฆ่า", "ระยะไกล", "บาร์ด", "ฮีลเลอร์", "หัวหน้า"]
const TANK_CLASSES: Array[StringName] = [&"defender", &"warrior", &"lancer"]
const RANGED_CLASSES: Array[StringName] = [&"archer", &"mage", &"summoner"]
## Metres behind the formation's front line per role: tanks in front, healers last; the
## leader stands among its ranged and healers (LEADER_BACK when hurt).
const ROLE_DEPTH: Array[float] = [0.0, 1.0, 0.6, 3.0, 4.6, 5.2, 4.0]
const LEADER_BACK := 6.5
## The AI leader comes with its guild (บุกพร้อมทัพ, the damage dealers lead): its post is
## LEADER_GAP m behind its front line, the member with FRONT_SHARE of its guild out there
## (at least FRONT_MIN) as near the front as it or nearer (_front_post). It fights what
## comes within LEADER_REACH of that post (and the gate its guild pushes) and walks back
## to it; under LEADER_HURT of its HP its post is LEADER_HURT_BACK m farther back.
const LEADER_GAP := 3.5
const FRONT_SHARE := 0.25
const FRONT_MIN := 2
const LEADER_REACH := 7.0
const LEADER_HURT := 0.5
const LEADER_HURT_BACK := 7.0
## Out of the altar fight the leader falls back to heal under LEADER_RETREAT of its HP (a
## little sooner than its members: GuildWarDoctrine.retreat_for), a fall costing its guild
## the one who can take the castle.
const LEADER_RETREAT := 0.35
## Under the siege's focus the hurt fall back REAR_STEP m behind the leader's post (its
## healers are there), not to the far camp.
const REAR_STEP := 6.0
## The leader goes onto the altar only with the gates down and the
## way clear: at least the escort's worth of its guild within VANGUARD_RADIUS of the altar
## and at most ALTAR_CLEAR_FOES of the other guild there (or twice as many of ours), or one
## of its own up there with the altar empty. After LEADER_WAIT_MAX s
## it goes anyway inside its guard (two or more of its guild at the altar or round it), or
## alone once the altar is nearly clear, so a capture is never put off for good.
## While the members go in first they turn only on enemies within ASSAULT_HOLD.
const VANGUARD_RADIUS := 10.0
const ALTAR_CLEAR_FOES := 2
const LEADER_WAIT_MAX := 25.0
const ASSAULT_HOLD := 7.0
## A leader with enemies within LEADER_THREAT_RADIUS, LEADER_SWAMP more than its guild
## round it (or any while it is hurt), steps back behind its own (LEADER_COVER m behind
## their middle); the toughest of its guild, it holds its ground against fewer.
const LEADER_THREAT_RADIUS := 7.0
const LEADER_COVER := 4.0
const LEADER_SWAMP := 2
## Another guild's leader taking the altar: this leader goes up to contest it only with
## this many of its own within 9 m of the altar (allows_capture).
const CONTEST_GUARD := 3
## Taking the altar, an AI leader under LEADER_REST of its HP with enemies on it steps off
## behind the altar (REST_BACK m, still in the throne room, so its count waits instead of
## starting over when it would fall) and its healers patch it up; it steps back on at
## LEADER_RESTED, or when the count is all but done (REST_FINISH s left) it holds on.
const LEADER_REST := 0.4
const LEADER_RESTED := 0.8
const REST_BACK := 7.0
const REST_FINISH := 6.0
## Holding the castle, the leader stands this far behind the altar (away from the door),
## its defenders in front; with half its guild or more farther than HOLD_FOLLOW m from the
## altar (out fighting) it goes with them (_holder_out_post).
const HOLD_BACK := 4.5
const HOLD_FOLLOW := 22.0
const SLOT_GAP := 1.7
const ROW_WIDTH := 6
const ROW_STEP := 1.2

const GATHER := "gather"
const PUSH := "push"
const ESCORT := "escort"
const GUARD := "guard"
const DEFEND := "defend"
const FALLBACK := "fallback"
const TACTIC_NAMES := {
	"gather": "รวมพล", "push": "บุกพร้อมกัน", "escort": "คุ้มกันหัวหน้าไปยึดแท่น",
	"guard": "คุ้มกันหัวหน้า", "defend": "ตั้งรับ", "fallback": "ถอยรวมตัวใหม่",
}
## Picking the moment (a war of more than two): two other guilds that traded at least
## CLASH_HEAT falls lately (each fading over HEAT_MEMORY s) are busy with each other; the
## leader waits for them at most TIMING_MAX s.
const CLASH_HEAT := 2.0
const TIMING_MAX := 6.0
const TIMING_REST := 20.0
## Reading the wave on the altar: foes within WAVE_RADIUS of the altar, at least WAVE_MIN
## and WAVE_EDGE more than its guard within GUARD_RADIUS: the leader steps off (at most
## EVADE_MAX s at a time) and comes back once they are no more than its guard.
## The wave is one other guild's (the biggest group of one guild near the altar: in a war
## of four the throne room is never empty). Back on, it does not step off again for
## EVADE_REST s (no dancing on the circle's edge).
const WAVE_RADIUS := 16.0
const GUARD_RADIUS := 12.0
const WAVE_MIN := 6
const WAVE_EDGE := 4
const EVADE_MAX := 14.0
const EVADE_REST := 10.0
## A doubled tier: the gate scores (its HP share, plus DEFENDED_WEIGHT a defender near its
## front) are this close and the guild has SPLIT_MIN standing: it splits the push.
const DEFENDED_WEIGHT := 0.06
const SPLIT_GAP := 0.12
const SPLIT_MIN := 12

## Gathering ends when this share of the guild stands at the rally point (or after
## GATHER_MAX seconds, or when the other guild comes to the rally point: then it fights).
const GATHER_SHARE := 0.5
const GATHER_MAX := 10.0
const GATHER_RADIUS := 12.0
## Under the siege's focus (a holder behind its gates) a guild gathers out of the holder's
## reach, SIEGE_RALLY m before the gate of a tier inside the castle (in the yard, not at the
## holder's keep), and waits for its fallen a little longer (they come back from far).
const SIEGE_RALLY := 24.0
const SIEGE_GATHER_MAX := 20.0
## Pushing: after PUSH_MIN seconds with less than TRICKLE_SHARE of the guild at the front
## (the rest dead or strung out on the way) it gathers again.
const PUSH_MIN := 30.0
const PUSH_HOLD := 14.0
const TRICKLE_SHARE := 0.25
const FRONT_RADIUS := 14.0
## A lost fight: LOSING_HEAT falls remembered (each fades over HEAT_MEMORY s) and two more
## than it dealt, with under RETREAT_SHARE of the guild standing. It pulls back at least
## FALLBACK_MIN s and comes again once REENGAGE_SHARE stand (or after FALLBACK_MAX s).
const HEAT_MEMORY := 12.0
const LOSING_HEAT := 3.0
const RETREAT_SHARE := 0.7
const FALLBACK_MIN := 5.0
const FALLBACK_MAX := 15.0
const REENGAGE_SHARE := 0.75
## The leader under this share of HP with an enemy close: the guild guards it.
const LEADER_LOW := 0.35
## An AI leader goes for the altar with at least this many of its guild round it.
const ESCORT_NEED := 3
const ESCORT_RADIUS := 11.0
## The focus target is picked within this far of the guild's front; assassins dive this far.
const FOCUS_RANGE := 30.0
const DIVE_RANGE := 34.0
const FLANKERS := 2
## Callouts: at most one every CALL_GAP s per guild, the same kind not within CALL_REPEAT s
## (all the focus calls are one kind).
const CALL_GAP := 8.0
const CALL_REPEAT := 25.0

enum { KIND_OTHER, KIND_HEALER, KIND_BARD, KIND_LEADER }

var team := 0
var war: GuildWarMatch
var tactic := ""
## Seconds in the current tactic, and the commander's own war clock.
var since := 0.0
var clock := 0.0
var focus: Node3D
var dive: Node3D
var rally := Vector3.ZERO
var fallback_point := Vector3.ZERO
var forward := Vector3(0, 0, -1)
var loss_heat := 0.0
var kill_heat := 0.0
## Callouts said (after the rate limit), and the last snapshot read (tests).
var calls := 0
var said: Array[String] = []
var last_read: Dictionary = {}
## Whether the guild's pre-fight buffs went out (on each push / escort / defence).
var buffs_called := 0

var _think_left := 0.0
var _last_call := -1.0e9
var _said_at: Dictionary = {}
var _cc: Dictionary = {}
var _counts := PackedInt32Array([0, 0, 0, 0, 0, 0, 0])
var _index := PackedInt32Array([0, 0, 0, 0, 0, 0, 0])
## In the assault on the altar: the way is clear and the AI leader goes up (kept until
## the tactic changes), and where it waits meanwhile / steps back to (tests).
var leader_go := false
var leader_post := Vector3.ZERO
var leader_covering := false
## The members whose posts follow the leader's, as of the last apply: instance id -> TIED_*.
var _tied := {}
const TIED_GUARD := 0
const TIED_SCREEN := 1
## The AI leader taking the altar stepped off it to be healed (its count waits; tests).
var resting := false
## The AI leader taking the altar stepped off before a stronger wave (its count waits).
var evading := false
var _evade_since := 0.0
## The doubled tier's gate the guild batters (its lane, -1 none) and whether it splits.
var lane := -1
var split := false
## Holding the castle: the lane pressed harder (-1 alike) for the gate posts.
var hot_lane := -1
## Holding the castle: the guild nearest to taking it (-1 none).
var counter_team := -1
## Other guilds' trading: "a|b" -> heat (falls between them, fading).
var clash := {}
## The leader waits for its moment (tests): since when, and why.
var waiting := false
var _wait_since := -1.0e9
## The guild's war doctrine over this commander (GuildWarDoctrine; null: the old brain alone)
## and its hints for the tactic (merged into read(): engage_now, hold_back, all_in).
var doctrine: GuildWarDoctrine
var hints: Dictionary = {}


func _init(p_war: GuildWarMatch, p_team: int) -> void:
	war = p_war
	team = p_team
	spread(2)


## The guilds think a share of a beat apart (never two in the same frame): `n` guilds.
func spread(n: int) -> void:
	_think_left = 0.2 + THINK_EVERY * float(team) / float(maxi(1, n))


# ---------------------------------------------------------------------------
# Roles
# ---------------------------------------------------------------------------

## A class's role: tanks (defender, warrior, lancer) in front, the priest heals, the bard
## sings, archers, mages and summoners hold the second line, the assassin dives; any other
## class (the Dark Lord) by its reach.
static func role_of(class_id: StringName, ranged: bool) -> int:
	if class_id in TANK_CLASSES:
		return ROLE_TANK
	if class_id == &"priest":
		return ROLE_HEALER
	if class_id == &"bard":
		return ROLE_BARD
	if class_id in RANGED_CLASSES:
		return ROLE_RANGED
	if class_id == &"assassin":
		return ROLE_ASSASSIN
	return ROLE_RANGED if ranged else ROLE_MELEE


## Fighter `index` of `count` with the same role in a formation facing `fwd` with its
## front line through `front`: rows across the push axis, ROLE_DEPTH behind the front.
static func slot(front: Vector3, fwd: Vector3, role: int, index: int, count: int, depth_override := -1.0) -> Vector3:
	var side := Vector3(-fwd.z, 0.0, fwd.x)
	var row := index / ROW_WIDTH
	var in_row := mini(ROW_WIDTH, count - row * ROW_WIDTH)
	var col := index % ROW_WIDTH
	var depth: float = (ROLE_DEPTH[role] if depth_override < 0.0 else depth_override) + float(row) * ROW_STEP
	var lateral := (float(col) - (float(in_row) - 1.0) * 0.5) * SLOT_GAP
	# Assassins stand out on the wings, ready to go round.
	if role == ROLE_ASSASSIN:
		lateral += signf(lateral if absf(lateral) > 0.01 else 1.0) * 3.0
	return Vector3(front.x, 0.0, front.z) - fwd * depth + side * lateral


# ---------------------------------------------------------------------------
# The decision (pure: the same reading always gives the same answer)
# ---------------------------------------------------------------------------

## The tactic after `prev` (held `held` seconds) for a reading `s` of the war (see read()).
static func pick_tactic(prev: String, held: float, s: Dictionary) -> String:
	if bool(s.enemy_capturing):
		return DEFEND
	if bool(s.we_capturing):
		return GUARD
	var plan := String(s.plan)
	if plan == "regroup":
		return FALLBACK
	var share := float(s.alive_share)
	var losing := float(s.loss_heat) >= LOSING_HEAT and float(s.loss_heat) >= float(s.kill_heat) + 2.0
	# The doctrine's hints (GuildWarDoctrine: none for the old brain): all in at the end
	# (no falling back), push at once in the other guild's respawn window, pull back to
	# the rally point while outweighed at the front.
	var all_in := bool(s.get("all_in", false))
	if prev == FALLBACK and held < FALLBACK_MAX and (held < FALLBACK_MIN or share < REENGAGE_SHARE) and not all_in:
		return FALLBACK
	if prev != FALLBACK and losing and share < RETREAT_SHARE and not bool(s.holding) and not all_in:
		return FALLBACK
	if bool(s.leader_alive) and float(s.leader_hp) < LEADER_LOW and int(s.leader_threat) > 0:
		return GUARD
	if plan in ["defend", "forward", "hold", "gates"]:
		return DEFEND
	if not bool(s.gates_up):
		# The doctrine's wave: the guild stages out of reach until most of it is there.
		if bool(s.get("hold_back", false)) and not bool(s.get("leader_on_altar", false)):
			return GATHER
		if bool(s.leader_ai):
			if not bool(s.leader_alive):
				return GATHER
			if prev == ESCORT:
				return ESCORT
			if int(s.escort) >= int(s.escort_need) or (prev == GATHER and (held >= GATHER_MAX or bool(s.get("engage_now", false)))):
				return ESCORT
			return GATHER
		return ESCORT if bool(s.leader_alive) and bool(s.leader_in_castle) else PUSH
	if prev == PUSH:
		if bool(s.get("hold_back", false)) and int(s.enemies_at_rally) == 0:
			return GATHER
		if held >= PUSH_MIN and float(s.at_front) < TRICKLE_SHARE and int(s.enemies_at_rally) == 0:
			return GATHER
		return PUSH
	if prev == GATHER:
		if bool(s.get("hold_back", false)) and int(s.enemies_at_rally) < 2 and held < 30.0:
			return GATHER
		if bool(s.get("engage_now", false)) or float(s.gathered) >= GATHER_SHARE or held >= float(s.get("gather_max", GATHER_MAX)) or int(s.enemies_at_rally) >= 2:
			return PUSH
		return GATHER
	return GATHER


## Whether the AI leader may go onto the altar in an assault for a reading `s` (see
## read()), `held` s into it: the way clear (its vanguard round the altar, few of the
## other guild left there), or, after LEADER_WAIT_MAX s, two of its guild there or round
## the leader. Already on the altar it stays.
static func leader_may_go(s: Dictionary, held: float) -> bool:
	if bool(s.get("leader_on_altar", false)):
		return true
	# A war of more than two: the throne room is never clear (three other guilds fight
	# round the altar), so the leader, waiting close with its guard, goes once one of its
	# own is up there.
	if int(s.get("rivals", 1)) > 1 and int(s.get("vanguard", 0)) >= 1:
		return true
	var van := int(s.get("vanguard", 0))
	var foes := int(s.get("altar_foes", 0))
	if van >= maxi(1, int(s.escort_need)) and (foes <= ALTAR_CLEAR_FOES or van >= foes * 2):
		return true
	# The doctrine's window: the other guild's front is spent (or the bell is near).
	if (bool(s.get("engage_now", false)) or bool(s.get("all_in", false))) and van >= 1 and van + int(s.get("escort", 0)) >= 2 and foes <= ALTAR_CLEAR_FOES + 2:
		return true
	# Its first member up there and nobody (or only the other guild's leader) left round
	# the altar: the way is clear.
	if van >= 1 and foes <= 1:
		return true
	if held < LEADER_WAIT_MAX:
		return false
	return van + int(s.get("escort", 0)) >= mini(2, maxi(1, int(s.escort_need))) or foes <= ALTAR_CLEAR_FOES


## How much the guild wants `kind` (KIND_*) of enemy `dist` m off at `hp` (share) dead:
## whoever takes the altar above all, then a healer, an exposed leader (one or no guard
## near it, or hurt), a bard, the weak; never one fresh from its base.
static func focus_score(dist: float, hp: float, kind: int, escorts: int, guarded: bool, capturing: bool) -> float:
	var score := -0.35 * dist + 10.0 * (1.0 - clampf(hp, 0.0, 1.0))
	if capturing:
		score += 100.0
	match kind:
		KIND_HEALER:
			score += 9.0
		KIND_BARD:
			score += 6.0
		KIND_LEADER:
			score += 12.0 if escorts <= 1 or hp < 0.4 else 2.0
	if guarded:
		score -= 50.0
	return score


# ---------------------------------------------------------------------------
# Running
# ---------------------------------------------------------------------------

func tick(delta: float) -> void:
	clock += delta
	since += delta
	_think_left -= delta
	if _think_left <= 0.0:
		_think_left = THINK_EVERY
		think(THINK_EVERY)


func on_loss() -> void:
	loss_heat += 1.0


func on_kill() -> void:
	kill_heat += 1.0


## Two other guilds traded a fall (a and b): they are busy with each other.
func on_others_trade(a: int, b: int) -> void:
	var key := "%d|%d" % [mini(a, b), maxi(a, b)]
	clash[key] = float(clash.get(key, 0.0)) + 1.0


## The pair of other guilds busiest with each other ([] when none is at CLASH_HEAT).
func busy_pair() -> Array:
	var best: Array = []
	var heat := CLASH_HEAT - 0.001
	for key in clash:
		if float(clash[key]) > heat:
			heat = float(clash[key])
			var parts := String(key).split("|")
			best = [int(parts[0]), int(parts[1])]
	return best


## The AI leader is off the altar for now (healing or before a wave): its count waits.
func stepping_off() -> bool:
	return resting or evading


## A stun of ours landed on `target` for `seconds`: the others hold theirs until it ends.
func note_cc(target: Node, seconds: float) -> void:
	if target != null:
		_cc[target.get_instance_id()] = clock + seconds


func cc_fresh(target: Node) -> bool:
	return target != null and float(_cc.get(target.get_instance_id(), -1.0)) > clock


## Whether the AI leader may go onto the altar now: inside its escort, guarded, or to
## contest the other guild's leader on it (taking over the moment it steps off) - only
## with CONTEST_GUARD of its own round the altar and its HP over LEADER_HURT (alone into
## the other guild's guard it would only fall).
func allows_capture() -> bool:
	if resting or evading:
		return false
	if tactic == ESCORT:
		return leader_go
	if tactic == GUARD:
		# Guarding the one taking the altar (a hurt leader off it steps back behind its
		# guild instead).
		if team == GuildFighter.TEAM_ALLY and war.hero_leads():
			return true
		return bool(last_read.get("we_capturing", false)) or bool(last_read.get("leader_on_altar", false))
	if tactic != DEFEND or not war.capture.has("team") or int(war.capture.team) == team:
		return false
	var lead := _alive_leader() as GuildFighter
	if lead == null:
		return team == GuildFighter.TEAM_ALLY and war.hero_leads()
	return lead.hp_ratio() >= LEADER_HURT and _guard_near(SiegeArena.ALTAR, lead) >= CONTEST_GUARD


func think(dt: float) -> void:
	if war == null or not is_instance_valid(war):
		return
	var fade := exp(-dt / HEAT_MEMORY)
	loss_heat *= fade
	kill_heat *= fade
	for key in clash.keys():
		clash[key] = float(clash[key]) * fade
		if float(clash[key]) < 0.1:
			clash.erase(key)
	if not _cc.is_empty():
		for id in _cc.keys():
			if float(_cc[id]) <= clock:
				_cc.erase(id)
	_pick_lane()
	_place()
	var s := read()
	last_read = s
	_read_counter()
	var next := pick_tactic(tactic, since, s)
	if next != tactic:
		_switch(next, s)
	_leader_orders(s)
	_deny(s)
	var before := focus
	focus = _pick_focus()
	dive = _pick_dive()
	if focus != null and focus != before:
		_call_focus(focus)


## The assault on the altar: the members go in first and the AI leader follows right
## behind them; it goes up once the way is clear (leader_may_go, then kept until the
## tactic changes), called out in the war chat.
func _leader_orders(s: Dictionary) -> void:
	if not bool(s.leader_ai) or not bool(s.leader_alive) or bool(s.gates_up):
		leader_go = false
		return
	if tactic == ESCORT:
		var timing := leader_timing(s)
		if not leader_go and timing != "":
			if timing == "wait":
				if not waiting:
					waiting = true
					_wait_since = clock
				var pair := busy_pair()
				if pair.size() == 2:
					trace_line("wait|%d|%d" % [pair[0], pair[1]], "หัวหน้ากิลด์ %s รอจังหวะ %s กับ %s ปะทะกัน" % [war.team_name(team), war.team_name(pair[0]), war.team_name(pair[1])])
				return
			waiting = false
			leader_go = true
			trace_line("strike", "หัวหน้ากิลด์ %s ฉวยจังหวะ%s ขึ้นแท่น!" % [war.team_name(team), timing])
			callout("leader_go", "ได้จังหวะแล้ว! คุ้มกันหัวกิลขึ้นแท่น")
			return
		waiting = false
		if not leader_go and leader_may_go(s, since):
			leader_go = true
			if not bool(s.get("leader_on_altar", false)):
				callout("leader_go", "ทางโล่งแล้ว! คุ้มกันหัวกิลขึ้นแท่น")
		elif not leader_go:
			callout("vanguard", "บุกก่อน! เคลียร์แท่นให้หัวกิล หัวกิลตามติด")
	elif tactic != GUARD:
		leader_go = false


## The leader's moment in a war of more than two (the gates down, not yet going up):
## "wait" while two other guilds trade blows and the altar is not clear (they wear each
## other down), a reason to strike now (" หัวหน้ากิลด์อื่นล้ม" with every other leader down,
## " หลังสองกิลด์ซัดกันจนอ่อนแรง" when the clash it waited on is over or the altar is
## clear), or "" to decide as always (leader_may_go). Never waits more than TIMING_MAX s.
func leader_timing(s: Dictionary) -> String:
	if war.team_count() <= 2 or bool(s.get("leader_on_altar", false)):
		return ""
	if int(s.get("rivals", 0)) > 0 and int(s.get("rival_leaders_down", 0)) >= int(s.get("rivals", 0)):
		return " หัวหน้ากิลด์อื่นล้มหมด"
	var busy := busy_pair().size() == 2
	var clear := int(s.get("altar_foes", 0)) <= ALTAR_CLEAR_FOES and int(s.get("vanguard", 0)) >= 1
	# One wait at a time, never begun again within TIMING_REST s of the last (the leader
	# never stands back more than TIMING_MAX s in one go for the others to clash).
	if busy and not clear and (waiting and clock - _wait_since < TIMING_MAX or not waiting and clock - _wait_since >= TIMING_REST):
		return "wait"
	if waiting and (clear or not busy):
		return " หลังกิลด์อื่นซัดกันจนอ่อนแรง"
	return ""


## Another guild's leader taking the altar: the main body goes for it (the only way to
## stop its count), told in the feed.
func _deny(s: Dictionary) -> void:
	if not bool(s.enemy_capturing) or tactic != DEFEND:
		return
	var their := int(war.capture.get("team", -1))
	if war.capturer() == null or their < 0:
		return
	trace_line("deny_lead%d" % their, "หัวหน้ากิลด์ %s: ส่งทีมจู่โจมไปล้มหัวหน้ากิลด์ %s บนแท่น!" % [war.team_name(team), war.team_name(their)])


## How many of its own (not `lead`) stand within 9 m of `at`.
func _guard_near(at: Vector3, lead: GuildFighter) -> int:
	var n := 0
	for f in _side():
		if f != lead and not f.is_dead() and _flat(f.global_position, at) < 9.0:
			n += 1
	return n


## The middle of the guild's standing members (INF with none).
func _middle_of_side() -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for f in _side():
		if not f.is_dead():
			sum += f.global_position
			n += 1
	return sum / float(n) if n > 0 else Vector3.INF


## Holding the castle: the guild nearest to taking it (its count, how many it has in the
## throne room) is the one to push back.
func _read_counter() -> void:
	var was := counter_team
	counter_team = -1
	if war.castle_owner != team or war.front_gate() != null:
		return
	var best := 0.0
	var inside: Array[int] = []
	inside.resize(war.team_count())
	inside.fill(0)
	for f in _foes():
		if not f.is_dead() and SiegeArena.section(f.global_position) == 4:
			inside[f.team] += 1
	for t in war.team_count():
		if t == team:
			continue
		var near := float(inside[t]) * 0.5
		if war.capture.has("team") and int(war.capture.team) == t:
			near += 10.0 + float(war.capture.progress) * 0.2
		if near > best:
			best = near
			counter_team = t
	if counter_team >= 0 and counter_team != was and best >= 3.0:
		trace_line("counter%d" % counter_team, "กิลด์ %s (ผู้ครองปราสาท) สวนกลับกิลด์ %s ที่ใกล้ยึดแท่นที่สุด" % [war.team_name(team), war.team_name(counter_team)])


func _switch(next: String, s: Dictionary) -> void:
	var was := tactic
	tactic = next
	since = 0.0
	match next:
		GATHER:
			callout("gather", "ทุกคนรวมพลที่%s!" % place_name())
		PUSH:
			if bool(s.gates_up):
				callout("push", "บุก! ตีประตูพร้อมกัน หัวกิลตามติด!" if bool(s.leader_ai) and bool(s.leader_alive) else "บุก! ตีประตูพร้อมกัน!")
			_buff_up(rally, 18.0)
		ESCORT:
			if not bool(s.leader_ai):
				callout("escort", "คุ้มกันหัวหน้าไปยึดแท่น! นำหน้าไปก่อน")
			else:
				callout("escort", "บุกห้องบัลลังก์! สายดาเมจนำ หัวกิลตามติด")
			_buff_up(front(), 18.0)
		GUARD:
			callout("guard", "คุ้มกันหัวหน้า!")
		DEFEND:
			if bool(s.enemy_capturing):
				callout("stop", "หยุดคนบนแท่น! สตันหัวกิลมัน ล้มให้ได้!")
				_buff_up(SiegeArena.ALTAR, 30.0)
			elif was != "":
				callout("hold", "ตั้งรับ! อย่าให้ผ่าน!")
		FALLBACK:
			callout("fallback", "ถอย! รวมตัวใหม่")


## The rally point before the next gate (our side of the bridge head for the first, the
## yard before the second and third) or inside the throne room's door, where to pull back
## to, and the way forward.
func _place() -> void:
	var toward := _toward()
	var gate := target_gate()
	if gate != null:
		var k := gate.tier
		var x := SiegeArena.gate_x(k, gate.lane)
		forward = Vector3(0, 0, -1)
		if k == 0:
			var home := war.home_of(team)
			var back := home - SiegeArena.APPROACH
			back.y = 0.0
			rally = SiegeArena.APPROACH + back.normalized() * 12.0
			fallback_point = home.lerp(SiegeArena.APPROACH, 0.55)
		else:
			rally = Vector3(x + toward * 4.0, 0, SiegeArena.GATE_Z[k] + (SIEGE_RALLY if _siege_mark() >= 0 else 12.0))
			# Just inside the tier broken last, the far end of the same yard.
			fallback_point = Vector3(x + toward * 4.0, 0, SiegeArena.GATE_Z[k - 1] - 6.0)
	elif war.front_gate() != null:
		# Holding the castle with the gates up: behind the front tier, in the yard.
		var k := war.front_tier()
		forward = Vector3(0, 0, 1)
		rally = Vector3(toward * 4.0, 0, SiegeArena.GATE_Z[k] - 8.0)
		fallback_point = rally
	else:
		rally = Vector3(toward * 6.0, 0, SiegeArena.GATE_Z[2] - 6.0)
		fallback_point = Vector3(toward * 5.0, 0, SiegeArena.GATE_Z[2] + 8.0)
		var to := SiegeArena.ALTAR - rally
		to.y = 0.0
		forward = to.normalized()
	# The doctrine stages a wave out of the throne room's reach (GuildWarDoctrine.stage_point).
	if _staging():
		rally = hints.stage
		fallback_point = rally
		var to: Vector3 = SiegeArena.ALTAR - rally
		to.y = 0.0
		forward = to.normalized()


## Whether the doctrine has the guild wait for its wave at a staging point.
func _staging() -> bool:
	var stage: Variant = hints.get("stage", Vector3.INF)
	return bool(hints.get("hold_back", false)) and stage is Vector3 and (stage as Vector3).is_finite()


func place_name() -> String:
	if _staging():
		return "ลานชั้นใน"
	var gate := target_gate()
	if gate == null:
		return "หน้าห้องบัลลังก์"
	if gate.tier == 0:
		return "หัวสะพาน"
	return "หน้า%s" % CastleGate.gate_label(gate.tier, gate.lane)


## This guild's side of the field (a small sideways offset of its rally points).
func _toward() -> float:
	return [-1.0, 1.0, -0.4, 0.4][team % 4] * 1.2


# ---------------------------------------------------------------------------
# The gates: which of a doubled tier, and the holder's posts
# ---------------------------------------------------------------------------

## The gate the guild batters (null holding the castle or with every tier open).
func target_gate() -> CastleGate:
	if war.castle_owner == team:
		return null
	var front := war.front_gates()
	if front.is_empty():
		return null
	for g in front:
		if g.lane == lane:
			return g
	return front[0]


## The gate `f` batters: split party by party between the two, else the guild's.
func gate_for(f: GuildFighter) -> CastleGate:
	var main := target_gate()
	if main == null or not split:
		return main
	var front := war.front_gates()
	if front.size() < 2:
		return main
	var p := (f.party % GuildWarMatch.ENEMY_PARTY_BASE) if f.party >= 0 else 0
	return front[p % 2]


## How many of the other guilds stand within 12 m of gate g's front (only the holder's
## while it holds the castle: another attacking guild at a gate is no defender of it).
func _defenders_at(g: CastleGate) -> int:
	var at := SiegeArena.gate_front(g.tier, g.lane)
	var holder := war.castle_owner if war.castle_owner != team else -1
	var n := 0
	for f in _foes():
		if holder >= 0 and f.team != holder:
			continue
		if not f.is_dead() and _flat(f.global_position, at) < 12.0:
			n += 1
	return n


## Picks the doubled tier's gate (the weaker or less defended; split when alike and big
## enough), and, holding the castle, the lane pressed harder.
func _pick_lane() -> void:
	var front := war.front_gates()
	hot_lane = -1
	if war.castle_owner == team:
		split = false
		if front.size() >= 2:
			var press := [_defenders_at(front[0]), _defenders_at(front[1])]
			if int(press[0]) >= 2 * int(press[1]) + 2:
				hot_lane = front[0].lane
			elif int(press[1]) >= 2 * int(press[0]) + 2:
				hot_lane = front[1].lane
		return
	if front.size() < 2:
		split = false
		lane = front[0].lane if front.size() == 1 else -1
		return
	var scores: Array[float] = []
	for g in front:
		scores.append(float(g.hp) / float(maxi(1, g.max_hp)) + DEFENDED_WEIGHT * float(_defenders_at(g)))
	var best := 0 if scores[0] <= scores[1] else 1
	var was_lane := lane
	var was_split := split
	# Keep the gate in hand unless the other is clearly better.
	if lane >= 0 and lane != front[best].lane and absf(scores[0] - scores[1]) < SPLIT_GAP * 0.5:
		best = 1 - best
	lane = front[best].lane
	split = absf(scores[0] - scores[1]) < SPLIT_GAP and war._strength(team).x >= SPLIT_MIN and war.team_count() <= 2
	if split and not was_split:
		callout("split", "แบ่งกำลังตีประตูซ้ายและขวาพร้อมกัน!")
	elif not split and lane != was_lane and was_lane >= 0:
		callout("lane", "เปลี่ยนไปตีประตู%sที่อ่อนกว่า!" % SiegeArena.LANE_NAMES[lane])


## Holding the castle with the gates up: the front gate `f` stands before (two parties in
## three on the gate pressed harder, else half and half).
func defend_gate_for(f: GuildFighter, front: Array[CastleGate]) -> CastleGate:
	if front.is_empty():
		return null
	if front.size() == 1:
		return front[0]
	var p := (f.party % GuildWarMatch.ENEMY_PARTY_BASE) if f.party >= 0 else 0
	if hot_lane >= 0:
		var hot: CastleGate = front[0] if front[0].lane == hot_lane else front[1]
		var cold: CastleGate = front[1] if hot == front[0] else front[0]
		return hot if p % 3 != 2 else cold
	return front[p % 2]


## Tells a leader's move in the feed once a while (the same `key` not within CALL_REPEAT s).
func trace_line(key: String, text: String) -> void:
	var k := "trace_" + key
	if _said_at.has(k) and clock - float(_said_at[k]) < CALL_REPEAT:
		return
	_said_at[k] = clock
	war.feed.emit(text, team)
	war._trace(text)


func leader() -> Node3D:
	return war.leader_of(team)


func _alive_leader() -> Node3D:
	var lead := leader()
	if lead == null or not is_instance_valid(lead) or bool(lead.call("is_dead")):
		return null
	return lead


func _side() -> Array[GuildFighter]:
	return war.side(team)


func _foes() -> Array[GuildFighter]:
	return war.foes_of(team)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Where the guild's front is: the gate front while pushing a gate, else the rally point.
func front() -> Vector3:
	var gate := target_gate()
	if tactic == PUSH and gate != null:
		return SiegeArena.gate_front(gate.tier, gate.lane)
	var lead := _alive_leader()
	if (tactic == ESCORT or tactic == GUARD) and lead != null:
		return lead.global_position
	if tactic == DEFEND:
		var who := war.capturer()
		if who == null and war.castle_owner == team and war.front_gate() != null:
			return rally
		return who.global_position if who != null else SiegeArena.ALTAR
	if tactic == FALLBACK:
		return fallback_point
	return rally


## The war as this guild sees it now (numbers only; see pick_tactic).
func read() -> Dictionary:
	var lead := _alive_leader()
	var mine := war._strength(team)
	var alive := 0
	var at_rally := 0
	var at_front := 0
	var escort := 0
	var threat := 0
	var vanguard := 0
	var altar_foes := 0
	var gate := target_gate()
	var front_at := SiegeArena.gate_front(gate.tier, gate.lane) if gate != null else rally
	for f in _side():
		if f.is_dead() or f == lead:
			continue
		alive += 1
		var p := f.global_position
		if _flat(p, rally) < GATHER_RADIUS:
			at_rally += 1
		if _flat(p, front_at) < FRONT_RADIUS:
			at_front += 1
		if lead != null and _flat(p, lead.global_position) < ESCORT_RADIUS:
			escort += 1
		if _flat(p, SiegeArena.ALTAR) < VANGUARD_RADIUS:
			vanguard += 1
	var enemies_at_rally := 0
	# Under the siege's focus only the holder's count at the rally point (the other
	# attackers gathering beside it are no threat to it there).
	var only := _siege_mark()
	for f in _foes():
		if f.is_dead():
			continue
		if _flat(f.global_position, rally) < 16.0 and (only < 0 or f.team == only):
			enemies_at_rally += 1
		if lead != null and _flat(f.global_position, lead.global_position) < 10.0:
			threat += 1
		if _flat(f.global_position, SiegeArena.ALTAR) < VANGUARD_RADIUS + 2.0:
			altar_foes += 1
	if team != GuildFighter.TEAM_ALLY and lead != null and war.hero_alive() and _flat(war.hero.global_position, lead.global_position) < 10.0:
		threat += 1
	if team != GuildFighter.TEAM_ALLY and war.hero_alive() and _flat(war.hero.global_position, SiegeArena.ALTAR) < VANGUARD_RADIUS + 2.0:
		altar_foes += 1
	var leaders_down := 0
	var rivals := 0
	for t in war.team_count():
		if t == team:
			continue
		rivals += 1
		var their := war.leader_of(t)
		if their == null or not is_instance_valid(their) or bool(their.call("is_dead")):
			leaders_down += 1
	var capture := war.capture
	var lead_hp := 1.0
	if lead is GuildFighter:
		lead_hp = (lead as GuildFighter).hp_ratio()
	elif lead == war.hero:
		lead_hp = war.hero_hp_ratio()
	return {
		"plan": war.plans[team] if war.plans[team] != "" else war.plan_for(team),
		"gates_up": war.front_gate() != null,
		"holding": war.castle_owner == team,
		"enemy_capturing": not capture.is_empty() and int(capture.team) != team,
		"we_capturing": not capture.is_empty() and int(capture.team) == team,
		"alive_share": float(mine.x) / float(mine.y),
		"loss_heat": loss_heat,
		"kill_heat": kill_heat,
		"leader_ai": not (team == GuildFighter.TEAM_ALLY and war.hero_leads()),
		"leader_alive": lead != null,
		"leader_hp": lead_hp,
		"leader_threat": threat,
		"leader_in_castle": lead != null and SiegeArena.section(lead.global_position) >= 3,
		"escort": escort,
		"escort_need": mini(ESCORT_NEED, alive),
		"gathered": float(at_rally) / float(maxi(1, alive)),
		"at_front": float(at_front) / float(maxi(1, alive)),
		"enemies_at_rally": enemies_at_rally,
		"gather_max": SIEGE_GATHER_MAX if only >= 0 else GATHER_MAX,
		"rival_leaders_down": leaders_down,
		"rivals": rivals,
		"leader_on_altar": lead != null and SiegeArena.on_altar(lead.global_position),
		"vanguard": vanguard,
		"altar_foes": altar_foes,
	}.merged(hints)


## The focus target: the best of the other guild (the hero too, for theirs) within
## FOCUS_RANGE of our front.
func _pick_focus() -> Node3D:
	var at := front()
	var taker := war.capturer()
	if taker != null and war.capture.has("team") and int(war.capture.team) != team:
		return taker
	var best: Node3D = null
	var best_score := -1.0e9
	var only := _siege_mark()
	for f in _foes():
		if f.is_dead() or (only >= 0 and f.team != only and not _rival_open(f)):
			continue
		var d := _flat(f.global_position, at)
		if d > FOCUS_RANGE or _in_camp(f):
			continue
		var score := focus_score(d, f.hp_ratio(), _kind(f), _escorts(f), f.under_guard(), f.capturing)
		if doctrine != null:
			score += doctrine.focus_extra(f)
		# Holding the castle: the guild nearest to taking it first.
		if counter_team >= 0 and f.team == counter_team:
			score += 6.0
		if score > best_score:
			best_score = score
			best = f
	if team != GuildFighter.TEAM_ALLY and war.hero_alive() and (only < 0 or only == GuildFighter.TEAM_ALLY):
		var hero := war.hero
		var d := _flat(hero.global_position, at)
		if d <= FOCUS_RANGE and not _in_camp(hero):
			var score := focus_score(d, war.hero_hp_ratio(), _kind(hero), _escorts(hero), false, war.capturer() == hero)
			if score > best_score:
				best = hero
	return best


## The assassins' mark: an enemy healer, bard or exposed leader within DIVE_RANGE of our
## front (whoever takes the altar first).
func _pick_dive() -> Node3D:
	var taker := war.capturer()
	if taker != null and war.capture.has("team") and int(war.capture.team) != team:
		return taker
	var at := front()
	var best: Node3D = null
	var best_score := -1.0e9
	var only := _siege_mark()
	for f in _foes():
		if f.is_dead() or f.under_guard() or _in_camp(f) or (only >= 0 and f.team != only and not _rival_open(f)):
			continue
		var kind := _kind(f)
		if kind == KIND_OTHER or (kind == KIND_LEADER and _escorts(f) > 1 and f.hp_ratio() >= 0.4):
			continue
		var d := _flat(f.global_position, at)
		if d > DIVE_RANGE:
			continue
		var score := focus_score(d, f.hp_ratio(), kind, _escorts(f), false, false)
		if score > best_score:
			best_score = score
			best = f
	var hero_kind := _kind(war.hero) if war.hero_alive() and (only < 0 or only == GuildFighter.TEAM_ALLY) else KIND_OTHER
	if team != GuildFighter.TEAM_ALLY and hero_kind != KIND_OTHER and (hero_kind != KIND_LEADER or _escorts(war.hero) <= 1):
		var d := _flat(war.hero.global_position, at)
		if d <= DIVE_RANGE and not _in_camp(war.hero) and focus_score(d, war.hero_hp_ratio(), hero_kind, _escorts(war.hero), false, false) > best_score:
			best = war.hero
	return best


## Under the siege's focus (GuildWarMatch.siege_focus) the holder is the only guild whose
## fighters this guild marks (-1: anyone's), but in the throne room with every gate down.
func _siege_mark() -> int:
	if war.castle_owner == team or not war.siege_focus():
		return -1
	return war.castle_owner


## Another attacking guild's `f` this guild marks all the same: every gate down, it in the
## throne room (the altar is fought over by all).
func _rival_open(f: GuildFighter) -> bool:
	return war.front_gate() == null and SiegeArena.section(f.global_position) == 4


func _kind(f: Node3D) -> int:
	if f == war.hero:
		# The hero is our leader unless the player picked a member to lead; else what its
		# class does.
		if war.hero_leads():
			return KIND_LEADER
		if Game.class_id() == &"priest":
			return KIND_HEALER
		if Game.class_id() == &"bard":
			return KIND_BARD
		return KIND_OTHER
	var g := f as GuildFighter
	if g == null:
		return KIND_OTHER
	if g.is_leader:
		return KIND_LEADER
	if g.is_healer():
		return KIND_HEALER
	if g.sings():
		return KIND_BARD
	return KIND_OTHER


## How many of its own guild stand within 8 m of `who`.
func _escorts(who: Node3D) -> int:
	var n := 0
	for f in war.side(maxi(0, war.team_of(who))):
		if f != who and not f.is_dead() and _flat(f.global_position, who.global_position) < 8.0:
			n += 1
	return n


## Someone of the other guild standing in its own camp (nobody chases it there).
func _in_camp(who: Node3D) -> bool:
	var t := maxi(0, war.team_of(who))
	if t == war.castle_owner and war.holds_keep():
		return GuildFighter.keep_shelters(who)
	return _flat(who.global_position, SiegeArena.camp(t)) < SiegeArena.CAMP_RADIUS


func _call_focus(target: Node3D) -> void:
	if war.capturer() == target:
		return
	match _kind(target):
		KIND_HEALER:
			callout("focus", "โฟกัสนักบวชฝั่งนู้น!")
		KIND_BARD:
			callout("focus", "โฟกัสบาร์ดฝั่งนู้น!")
		KIND_LEADER:
			callout("focus", "หัวหน้าฝั่งนู้นหลุดแถว! รุมเลย!")


## Everyone of the guild within `radius` of `at` casts its ready buffs before the fight
## (the hero's own party waits for the player's บัฟทีม button).
func _buff_up(at: Vector3, radius: float) -> void:
	var any := false
	for f in _side():
		if f.is_dead() or f.in_hero_party() or _flat(f.global_position, at) > radius:
			continue
		if f.cast_team_buffs() > 0:
			any = true
	if any:
		buffs_called += 1


## Says `text` for the guild (war chat, and over the leader's head for the rival guild):
## at most one every CALL_GAP s, the same `key` not again within CALL_REPEAT s. True when said.
func callout(key: String, text: String) -> bool:
	if clock - _last_call < CALL_GAP:
		return false
	if _said_at.has(key) and clock - float(_said_at[key]) < CALL_REPEAT:
		return false
	_last_call = clock
	_said_at[key] = clock
	calls += 1
	said.append(text)
	if said.size() > 12:
		said.remove_at(0)
	war.tactical_call(team, text)
	return true



# ---------------------------------------------------------------------------
# Orders: who stands where (with GuildWarMatch._assign_objectives)
# ---------------------------------------------------------------------------

## Lays the guild out for the tactic on top of the plan's posts: rows by role facing the
## way forward, the AI leader behind its tanks, the focus and dive targets, tanks told
## whom to guard. Nothing changes before the first think (tactic "").
func apply() -> void:
	if tactic != "":
		_apply_tactic()
		if doctrine != null:
			doctrine.apply()
	_apply_order()


func _apply_tactic() -> void:
	var side := _side()
	var lead := _alive_leader()
	var ai_lead := lead as GuildFighter
	_update_rest(ai_lead)
	var at := front()
	var fwd := forward
	# The assault on the altar with an AI leader that has not gone up yet: the members go
	# first, onto the altar to clear it; the leader follows right behind them.
	var assault := (tactic == ESCORT or tactic == GUARD) and ai_lead != null and war.front_gate() == null and not allows_capture()
	if assault:
		at = SiegeArena.ALTAR
	elif tactic == ESCORT and lead != null:
		var to := SiegeArena.ALTAR - lead.global_position
		to.y = 0.0
		fwd = to.normalized() if to.length() > 1.5 else Vector3(0, 0, 1)
		# Its guard a step ahead of it (further ahead of the hero: they go in first).
		at = lead.global_position + fwd * (2.5 if ai_lead != null else 4.0)
	elif tactic == GUARD and lead != null:
		fwd = _threat_dir(lead)
		at = lead.global_position + fwd * 3.0
	_counts.fill(0)
	_index.fill(0)
	for f in side:
		if not f.is_dead() and not f.capture_role:
			_counts[_role(f, ai_lead)] += 1
	# The leader at the altar: half the tanks and fighters screen the throne room's door.
	var screen := (tactic == ESCORT or tactic == GUARD) and lead != null and _flat(lead.global_position, SiegeArena.ALTAR) < 10.0
	var door := Vector3(0, 0, SiegeArena.GATE_Z[2] - 5.0)
	var capturing_foe := war.capturer() != null and int(war.capture.get("team", team)) != team
	leader_post = _leader_post(ai_lead, at, fwd, assault) if ai_lead != null else Vector3.INF
	# In the push and the assault the healers and the bard keep by the leader.
	var guarded_post := leader_post.is_finite() and tactic in [PUSH, ESCORT, GUARD]
	var lead_dir := Vector3(at.x - leader_post.x, 0, at.z - leader_post.z) if guarded_post else Vector3.ZERO
	lead_dir = lead_dir.normalized() if lead_dir.length() > 0.5 else fwd
	var side_k := 0
	# The assault on the altar (the gates down): a Defender at the leader's side and a screen.
	var inside := guarded_post and war.front_gate() == null
	var bodyguard := _bodyguard(side, ai_lead) if inside else null
	var screen_dir := _screen_dir(leader_post) if inside else Vector3.ZERO
	_tied.clear()
	# Under the siege's focus the hurt fall back a little behind the leader (its healers).
	var rear := Vector3.INF
	if leader_post.is_finite() and _siege_mark() >= 0:
		rear = _in_bounds(_back_along(leader_post, at, REAR_STEP))
	for f in side:
		var r := _role(f, ai_lead)
		f.focus = focus
		f.dive = dive if f.role == ROLE_ASSASSIN else null
		f.guard_node = lead if f.role == ROLE_TANK else null
		if f.is_dead() or f.capture_role:
			continue
		if f == ai_lead and leader_post.is_finite():
			# The leader at its post right behind its front line: it fights what comes
			# within LEADER_REACH of it (the gate it pushes too); in the assault on the
			# altar it never steps nearer the altar than its post until it is sent up.
			f.objective = target_gate() if tactic == PUSH else null
			f.keep_back = true
			f.keep_front = SiegeArena.ALTAR if assault and not leader_covering else Vector3.INF
			f.hold_range = LEADER_REACH
			f.goal_point = leader_post
			continue
		if guarded_post and f == bodyguard:
			# A Defender (or the sturdiest tank) at the leader's very side.
			f.objective = null
			f.hold_range = 6.0
			f.goal_point = _in_bounds(leader_post + lead_dir * 1.3 + Vector3(-lead_dir.z, 0, lead_dir.x) * 1.2)
			_tied[f.get_instance_id()] = TIED_GUARD
			continue
		if guarded_post and screen_dir != Vector3.ZERO and (r == ROLE_TANK or r == ROLE_MELEE) and _index[r] % 3 == 2:
			# The screen: between the leader and the nearest foes.
			_index[r] += 1
			f.objective = null
			f.hold_range = 8.0
			f.goal_point = _in_bounds(leader_post + screen_dir * 5.0 + Vector3(-screen_dir.z, 0, screen_dir.x) * (float(side_k % 4) - 1.5) * 1.6)
			side_k += 1
			_tied[f.get_instance_id()] = TIED_SCREEN
			continue
		if guarded_post and (r == ROLE_HEALER or r == ROLE_BARD):
			# The healers and the bard escort the leader: at its sides, half a step behind
			# it (they heal it and the front from there; it is never left alone to be dived).
			f.objective = null
			f.hold_range = 9.0
			var across := Vector3(-lead_dir.z, 0, lead_dir.x) * (2.0 if side_k % 2 == 0 else -2.0) * (1.0 + float(side_k / 2) * 0.6)
			f.goal_point = _in_bounds(leader_post - lead_dir * 0.8 + across)
			side_k += 1
			continue
		var i := _index[r]
		_index[r] += 1
		var depth := -1.0
		if f == ai_lead and f.hp_ratio() < 0.45:
			depth = LEADER_BACK
		match tactic:
			GATHER, FALLBACK:
				f.objective = null
				f.hold_range = 8.0 if tactic == FALLBACK else 12.0
				f.goal_point = slot(at, fwd, r, i, _counts[r], depth)
			PUSH:
				if war.front_gate() != null:
					f.goal_point = slot(at, fwd, r, i, _counts[r], depth)
					# Nobody holding the castle, a war of more than two: the push is for the
					# gate, not a chase after every guild on the field.
					if war.castle_owner < 0 and war.team_count() > 2:
						f.hold_range = PUSH_HOLD
			ESCORT, GUARD:
				f.objective = null
				f.hold_range = ASSAULT_HOLD if assault else 11.0
				if screen and f != ai_lead and (r == ROLE_TANK or r == ROLE_MELEE) and i % 2 == 1:
					f.hold_range = 10.0
					f.goal_point = slot(door, Vector3(0, 0, 1), r, i / 2, maxi(1, _counts[r] / 2))
				else:
					f.goal_point = slot(at, fwd, r, i, _counts[r], depth)
			DEFEND:
				if capturing_foe and war.team_count() > 2 and war.castle_owner != team and i % 3 != 0:
					# A war of more than two: only the strike group (a third) goes for the
					# leader on the altar; the rest hold the throne room's door against the other guilds.
					f.objective = null
					f.hold_range = 9.0
					f.goal_point = slot(Vector3(0, 0, SiegeArena.GATE_Z[2] - 6.0), Vector3(0, 0, 1), r, i / 2, maxi(1, _counts[r] / 2))
				elif capturing_foe:
					f.objective = null
					f.hold_range = 0.0
					f.goal_point = war.capturer().global_position
				elif war.castle_owner == team and war.front_gate() != null and f != ai_lead:
					# Out in front of both gates of the front tier (more on the one pressed harder).
					var front_now := war.front_gates()
					var g := defend_gate_for(f, front_now)
					if g != null:
						f.objective = null
						f.hold_range = 12.0
						f.goal_point = SiegeArena.gate_front(g.tier, g.lane) + Vector3(float(i % 5 - 2) * 1.6, 0, 1.5 + float(i / 5 % 3) * 1.4)
		# The AI leader never charges in alone: it keeps to its place behind the tanks.
		if f == ai_lead and tactic != DEFEND:
			f.hold_range = 8.0 if depth < 0.0 else 5.0
		if rear.is_finite() and f != ai_lead:
			f.rear_point = rear


# ---------------------------------------------------------------------------
# The guild leader's orders (บัญชาการ)
# ---------------------------------------------------------------------------

## Orders the guild's leader gives (the hero leading ours: GuildWarMatch.order_guild). An
## order stands until changed (or until order_until on the commander's clock when given a
## time), and while it stands it decides every fighter's goal after the AI's own plan
## and tactic are laid out (apply), so the AI keeps choosing targets, focus and buffs:
##   gate     (ตีประตู)   everyone at the front tier's gate (order_data.lane: left / right);
##             cleared by itself once every tier is open;
##   escort   (บุกแท่น/คุ้มกัน) a step ahead of the leader on its way to the altar;
##   defend   (ตั้งรับ)   holding the castle: out in front of its gates (both, by the
##             pressure), the gates down: round the altar; else holding the line where the
##             leader stands;
##   rally    (รวมพล)     round the leader, wherever it goes;
##   fallback (ถอย)       back to the guild's camp (the keep for the castle's holder).
## An AI leader keeps its own post except when falling back. "" is the AI's own plan
## (ตามแผน AI).
const ORDER_GATE := "gate"
const ORDER_ESCORT := "escort"
const ORDER_DEFEND := "defend"
const ORDER_RALLY := "rally"
const ORDER_FALLBACK := "fallback"
const ORDERS: Array[String] = [ORDER_GATE, ORDER_ESCORT, ORDER_DEFEND, ORDER_RALLY, ORDER_FALLBACK]
const ORDER_NAMES := {
	"gate": "ตีประตู", "escort": "บุกแท่น/คุ้มกันหัวกิล",
	"defend": "ตั้งรับป้องกัน", "rally": "รวมพลที่หัวกิล", "fallback": "ถอยกลับค่าย",
}

var order := ""
var order_data: Dictionary = {}
## The commander's clock at which the order runs out (< 0: until changed).
var order_until := -1.0


## Gives the guild an order (kind one of ORDERS, "" back to the AI's plan) for `seconds`
## (0: until changed).
func set_order(kind: String, data: Dictionary = {}, seconds := 0.0) -> void:
	order = kind if ORDERS.has(kind) else ""
	order_data = data.duplicate() if order != "" else {}
	order_until = clock + seconds if order != "" and seconds > 0.0 else -1.0


func clear_order() -> void:
	set_order("")


## Whether an order of the leader stands now (one that ran out is cleared).
func has_order() -> bool:
	if order != "" and order_until >= 0.0 and clock >= order_until:
		clear_order()
	return order != ""


## The order as told ("ตีประตูซ้าย", "รวมพลที่หัวกิล"), "" with none.
func order_name() -> String:
	if not has_order():
		return ""
	var text := String(ORDER_NAMES.get(order, order))
	if order == ORDER_GATE and order_data.has("lane"):
		text += SiegeArena.LANE_NAMES[clampi(int(order_data.lane), 0, 1)]
	return text


## The gate the gate order batters now: the front tier's gate of the lane ordered (the
## other one when that one is not standing, the single gate of the third tier).
func order_gate() -> CastleGate:
	if war.castle_owner == team:
		return null
	var front := war.front_gates()
	if front.is_empty():
		return null
	var want := int(order_data.get("lane", -1))
	for g in front:
		if g.lane == want:
			return g
	return front[0]


## Lays the leader's order over the formation (every fighter of the guild but the one
## taking the altar and the dead; see ORDER_GATE).
func _apply_order() -> void:
	if not has_order():
		return
	var gate: CastleGate = null
	if order == ORDER_GATE:
		gate = order_gate()
		if gate == null:
			clear_order()
			war.feed.emit("กิลด์ %s: ไม่มีประตูให้ตีแล้ว — กลับไปตามแผน AI" % war.team_name(team), team)
			return
	var side := _side()
	var lead := leader()
	var ai_lead := _alive_leader() as GuildFighter
	var lead_at: Vector3 = lead.global_position if lead != null and is_instance_valid(lead) else front()
	lead_at.y = 0.0
	var to_altar := SiegeArena.ALTAR - lead_at
	to_altar.y = 0.0
	var fwd := to_altar.normalized() if to_altar.length() > 1.5 else Vector3(0, 0, -1)
	var counts := PackedInt32Array([0, 0, 0, 0, 0, 0, 0])
	var index := PackedInt32Array([0, 0, 0, 0, 0, 0, 0])
	for f in side:
		if not f.is_dead() and not f.capture_role:
			counts[_role(f, ai_lead)] += 1
	var front_now := war.front_gates()
	var home := war.home_of(team)
	var k := 0
	for f in side:
		if f.is_dead() or f.capture_role:
			continue
		if f == ai_lead and order != ORDER_FALLBACK:
			continue
		var r := _role(f, ai_lead)
		var i := index[r]
		index[r] += 1
		f.keep_back = false
		f.keep_front = Vector3.INF
		f.rear_point = Vector3.INF
		match order:
			ORDER_GATE:
				f.objective = gate
				f.hold_range = 0.0
				f.goal_point = SiegeArena.gate_front(gate.tier, gate.lane) + Vector3(float(k % 7 - 3) * 1.3, 0, float(k / 7) * 1.8)
			ORDER_ESCORT:
				f.hold_range = 9.0
				f.goal_point = _in_bounds(slot(lead_at + fwd * 4.0, fwd, r, i, counts[r]))
			ORDER_DEFEND:
				f.objective = null
				f.hold_range = 12.0
				if war.castle_owner == team and not front_now.is_empty():
					var g := defend_gate_for(f, front_now)
					f.goal_point = SiegeArena.gate_front(g.tier, g.lane) + Vector3(float(k % 5 - 2) * 1.6, 0, 1.5 + float(k / 5 % 3) * 1.4)
				elif front_now.is_empty():
					f.goal_point = GuildWarMatch._spot(SiegeArena.ALTAR, k, SiegeArena.ALTAR_RADIUS + 2.0)
				else:
					f.hold_range = 14.0
					f.goal_point = _in_bounds(slot(lead_at, fwd, r, i, counts[r]))
			ORDER_RALLY:
				f.hold_range = 8.0
				f.goal_point = _in_bounds(GuildWarMatch._spot(lead_at, k, 3.0))
			ORDER_FALLBACK:
				f.objective = null
				f.hold_range = 6.0
				f.goal_point = GuildWarMatch._spot(home, k, 3.5)
		k += 1


## Whether the AI leader taking the altar steps off it to be healed (resting): hurt with
## enemies close while its count runs, and not when the count is all but done; back on
## once healed, and never with no count of ours running.
func _update_rest(lead: GuildFighter) -> void:
	var ours: bool = lead != null and war.capture.has("team") and int(war.capture.team) == team and war.capture.get("who") == lead
	if not ours:
		resting = false
		evading = false
		return
	_read_wave(lead)
	var hp := lead.hp_ratio()
	if resting:
		resting = hp < LEADER_RESTED
		return
	if hp < LEADER_REST and float(war.capture.progress) < GuildWarMatch.CAPTURE_TIME - REST_FINISH and _foes_near(lead.global_position, LEADER_THREAT_RADIUS) > 0:
		resting = true
		callout("rest", "หัวกิลเลือดน้อย! ถอยลงหลังแท่นให้ฮีลก่อน แล้วขึ้นนับต่อ")


## On the altar (the count running or waiting): a stronger wave on its way makes the
## leader step off behind the altar, the count waiting, until it has passed (at most
## EVADE_MAX s, and never with the count all but done).
func _read_wave(lead: GuildFighter) -> void:
	var by_team := {}
	for f in _foes():
		if not f.is_dead() and _flat(f.global_position, SiegeArena.ALTAR) < WAVE_RADIUS:
			by_team[f.team] = int(by_team.get(f.team, 0)) + 1
	var incoming := 0
	for t in by_team:
		incoming = maxi(incoming, int(by_team[t]))
	var guard := 0
	for f in _side():
		if f != lead and not f.is_dead() and _flat(f.global_position, SiegeArena.ALTAR) < GUARD_RADIUS:
			guard += 1
	var progress := float(war.capture.get("progress", 0.0))
	if evading:
		if incoming <= guard or clock - _evade_since > EVADE_MAX:
			evading = false
			_evade_since = clock
			trace_line("back", "หัวหน้ากิลด์ %s กลับขึ้นแท่น นับต่อจาก %d/%d วิ" % [war.team_name(team), int(progress), int(GuildWarMatch.CAPTURE_TIME)])
		return
	if clock - _evade_since < EVADE_REST + EVADE_MAX and _evade_since > 0.0 and not evading and clock - _evade_since < EVADE_REST:
		return
	if incoming >= WAVE_MIN and incoming >= guard + WAVE_EDGE and progress < GuildWarMatch.CAPTURE_TIME * 0.7:
		evading = true
		_evade_since = clock
		trace_line("evade", "หัวหน้ากิลด์ %s ถอยลงจากแท่นหลบคลื่นศัตรู %d คน (นับค้างไว้ %d/%d วิ)" % [war.team_name(team), incoming, int(progress), int(GuildWarMatch.CAPTURE_TIME)])


func _foes_near(at: Vector3, radius: float) -> int:
	var n := 0
	for f in _foes():
		if not f.is_dead() and _flat(f.global_position, at) < radius:
			n += 1
	if team != GuildFighter.TEAM_ALLY and war.hero_alive() and _flat(war.hero.global_position, at) < radius:
		n += 1
	return n


## Where the AI leader stands now (Vector3.INF: where the formation or its plan puts it,
## going up to the altar or guarded on it). It comes with its guild, it does not wait at
## the camp (หัวกิลบุกพร้อมทัพ): LEADER_GAP behind its front line (_front_post: the damage
## dealers and tanks lead, it is right behind them, fighting what reaches it and the gate
## it pushes), LEADER_HURT_BACK farther back while hurt; with enemies swarming it, behind
## its own (_cover_point). Holding the castle: out in front of the gate pressed harder
## behind its defenders while the gates stand, by the altar once they are down.
func _leader_post(lead: GuildFighter, at: Vector3, fwd: Vector3, assault: bool) -> Vector3:
	if war.castle_owner == team and war.front_gate() != null:
		leader_covering = false
		return _holder_gate_post(lead)
	if resting or evading:
		leader_covering = false
		return _in_bounds(SiegeArena.ALTAR + forward * REST_BACK)
	var cover := _cover_point(lead, fwd)
	leader_covering = cover.is_finite()
	if leader_covering:
		return _in_bounds(cover)
	# A war of more than two with the gates down: the leader waits close by the altar,
	# behind it and its guard (with three other guilds round it the altar is never clear
	# for long).
	if war.team_count() > 2 and war.front_gate() == null and war.castle_owner != team and tactic in [ESCORT, GATHER, GUARD] and not leader_go:
		var near := SiegeArena.ALTAR + forward * (SiegeArena.ALTAR_RADIUS + 3.5)
		if _guard_near(near, lead) >= 2:
			return _in_bounds(near)
	match tactic:
		DEFEND:
			if war.castle_owner == team and war.front_gate() == null:
				# By the altar while its guild defends it; with its guild out fighting
				# elsewhere (pushing the attackers back out of the throne room) it goes too.
				var out := _holder_out_post(lead)
				return out if out.is_finite() else SiegeArena.ALTAR + forward * HOLD_BACK
			return Vector3.INF
		GUARD, ESCORT:
			if not assault:
				return Vector3.INF
	var p := _front_post(lead, at)
	if not p.is_finite():
		# None of its guild out there yet (all down or at the camp): it waits at the rally
		# point (inside the throne room's door with the gates down), not at the camp.
		p = rally if war.front_gate() != null else _back_along(rally, at, 2.0)
	if lead.hp_ratio() < LEADER_HURT:
		p = _back_along(p, at, LEADER_HURT_BACK)
	return _in_bounds(Vector3(p.x, 0.0, p.z))


## LEADER_GAP behind the guild's front line on its way to `at` (INF with none of it out):
## of its members standing out of the camp (not falling back, not its healers, bard,
## bodyguard or screen, who keep by it), the one with FRONT_SHARE of them (at least
## FRONT_MIN) as near `at` as it or nearer; back from it along the way home.
func _front_post(lead: GuildFighter, at: Vector3) -> Vector3:
	var cands: Array = []
	for f in _side():
		if f == lead or f.is_dead() or f.capture_role or f.is_retreating() or _in_camp(f):
			continue
		if _tied.has(f.get_instance_id()):
			continue
		var r := _role(f, lead)
		if r == ROLE_HEALER or r == ROLE_BARD:
			continue
		cands.append([_flat(f.global_position, at), f.global_position])
	if cands.is_empty():
		return Vector3.INF
	cands.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	var k := clampi(maxi(FRONT_MIN, roundi(float(cands.size()) * FRONT_SHARE)), 1, cands.size()) - 1
	var p := _back_along(cands[k][1], at, LEADER_GAP)
	# Its guild just out of the camp: the post never falls back inside it.
	if _flat(p, war.home_of(team)) < SiegeArena.CAMP_RADIUS:
		p = cands[k][1]
	return p


## Holding the castle with the gates down: its guild out fighting away from the altar (not
## half of its standing members out of the camp within HOLD_FOLLOW m of it), the leader's
## post behind its front towards the foe nearest the guild's middle (INF: it stays by the
## altar).
func _holder_out_post(lead: GuildFighter) -> Vector3:
	var out := 0
	var near := 0
	var mid := Vector3.ZERO
	for f in _side():
		if f == lead or f.is_dead() or f.is_retreating() or _in_camp(f):
			continue
		out += 1
		mid += f.global_position
		if _flat(f.global_position, SiegeArena.ALTAR) < HOLD_FOLLOW:
			near += 1
	if out < FRONT_MIN or near * 2 >= out:
		return Vector3.INF
	mid /= float(out)
	var at := mid
	var best := INF
	for f in _foes():
		if not f.is_dead():
			var d := _flat(f.global_position, mid)
			if d < best:
				best = d
				at = f.global_position
	return _front_post(lead, at)


## Holding the castle with the gates up: the leader stands out in front of the gate
## pressed harder (the one its guild's front is nearer), just behind its defenders there.
func _holder_gate_post(lead: GuildFighter) -> Vector3:
	var front := war.front_gates()
	if front.is_empty():
		return Vector3(0, 0, SiegeArena.GATE_Z[war.front_tier()] - 9.0)
	var g: CastleGate = front[0]
	if front.size() >= 2:
		if hot_lane >= 0:
			g = front[0] if front[0].lane == hot_lane else front[1]
		elif _flat(lead.global_position, SiegeArena.gate_front(front[1].tier, front[1].lane)) < _flat(lead.global_position, SiegeArena.gate_front(front[0].tier, front[0].lane)):
			g = front[1]
	var p := SiegeArena.gate_front(g.tier, g.lane)
	if lead.hp_ratio() < LEADER_HURT:
		# Hurt: behind its own gate (it walks through it), out of the attackers' reach.
		p.z -= 9.0
	return p


## The point `metres` back from `p` along the way to the guild's own camp (through the
## gates, not through a wall).
func _back_along(p: Vector3, front_at: Vector3, metres: float) -> Vector3:
	var at := Vector3(p.x, 0.0, p.z)
	var left := metres
	for step in 6:
		var camp := war.home_of(team)
		if _flat(at, camp) < SiegeArena.CAMP_RADIUS:
			# In its camp already: straight back, away from the front.
			var away := at - Vector3(front_at.x, 0.0, front_at.z)
			return at + (away.normalized() if away.length() > 0.5 else Vector3(0, 0, 1)) * left
		var next := SiegeArena.route(at, camp)
		next.y = 0.0
		var leg := _flat(at, next)
		if leg < 3.0 or leg >= left:
			return at + _back_from(at, front_at) * left
		at = next
		left -= leg
	return at


## The way back from `p` towards the guild's own camp (round the walls, SiegeArena.route),
## or straight away from `front` when already at the camp.
func _back_from(p: Vector3, front_at: Vector3) -> Vector3:
	var camp := war.home_of(team)
	var to := SiegeArena.route(p, camp) - p
	to.y = 0.0
	if to.length() < 3.0:
		to = p - front_at
		to.y = 0.0
	return to.normalized() if to.length() > 0.01 else Vector3(0, 0, 1)


## A post kept off the castle walls: on the bridge, inside the gate halls' width, or the
## throne room's.
static func _in_bounds(p: Vector3) -> Vector3:
	var sec := SiegeArena.section(p)
	if sec == 1:
		p.x = clampf(p.x, -SiegeArena.BRIDGE_HALF + 1.0, SiegeArena.BRIDGE_HALF - 1.0)
	elif sec >= 2 and sec <= 3:
		p.x = clampf(p.x, -SiegeArena.HALL_HALF + 2.0, SiegeArena.HALL_HALF - 2.0)
	elif sec == 4:
		p.x = clampf(p.x, -SiegeArena.THRONE_HALF + 2.0, SiegeArena.THRONE_HALF - 2.0)
		p.z = maxf(p.z, SiegeArena.BACK_Z + 2.0)
	return p


## Where a leader with enemies on it steps back to: LEADER_COVER behind the middle of its
## own within 20 m, away from the enemies (Vector3.INF when it is covered: fewer enemies
## within LEADER_THREAT_RADIUS than its own there, and not hurt).
func _cover_point(lead: GuildFighter, fwd: Vector3) -> Vector3:
	var foes := 0
	var threat_at := Vector3.ZERO
	for f in _foes():
		if not f.is_dead() and _flat(f.global_position, lead.global_position) < LEADER_THREAT_RADIUS:
			foes += 1
			threat_at += f.global_position
	if team != GuildFighter.TEAM_ALLY and war.hero_alive() and _flat(war.hero.global_position, lead.global_position) < LEADER_THREAT_RADIUS:
		foes += 1
		threat_at += war.hero.global_position
	if foes == 0:
		return Vector3.INF
	var mates := 0
	var guards := 0
	var mates_at := Vector3.ZERO
	for f in _side():
		if f == lead or f.is_dead():
			continue
		var d := _flat(f.global_position, lead.global_position)
		if d < 20.0:
			mates += 1
			mates_at += f.global_position
		if d < LEADER_THREAT_RADIUS:
			guards += 1
	if foes < guards + LEADER_SWAMP and lead.hp_ratio() >= LEADER_HURT:
		return Vector3.INF
	threat_at /= float(foes)
	var away := lead.global_position - threat_at
	if mates == 0:
		# Nobody to hide behind: back the way it came.
		away.y = 0.0
		var back := away.normalized() if away.length() > 0.5 else -fwd
		var p := lead.global_position + back * 8.0
		return Vector3(p.x, 0.0, p.z)
	mates_at /= float(mates)
	away = mates_at - threat_at
	away.y = 0.0
	if away.length() < 0.5:
		away = -fwd
	var p := mates_at + away.normalized() * LEADER_COVER
	return Vector3(p.x, 0.0, p.z)


## The leader's bodyguard: a Defender of the guild near it, else its sturdiest tank.
func _bodyguard(side: Array[GuildFighter], ai_lead: GuildFighter) -> GuildFighter:
	if ai_lead == null:
		return null
	var best: GuildFighter = null
	var best_score := -1.0e9
	for f in side:
		if f == ai_lead or f.is_dead() or f.capture_role or _role(f, ai_lead) != ROLE_TANK:
			continue
		var score := (20.0 if f.fighter_class() == &"defender" else 0.0) + 5.0 * f.hp_ratio() - 0.2 * _flat(f.global_position, ai_lead.global_position)
		if score > best_score:
			best_score = score
			best = f
	return best


## From the leader's post towards the nearest group of foes within 22 m (ZERO for none).
func _screen_dir(at: Vector3) -> Vector3:
	if not at.is_finite():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	var n := 0
	for f in _foes():
		if not f.is_dead() and _flat(f.global_position, at) < 22.0:
			sum += f.global_position
			n += 1
	if n == 0:
		return Vector3.ZERO
	var d := sum / float(n) - at
	d.y = 0.0
	return d.normalized() if d.length() > 0.5 else Vector3.ZERO


func _role(f: GuildFighter, ai_lead: GuildFighter) -> int:
	if f.role < 0:
		f.role = role_of(f.fighter_class(), f.is_ranged())
	return ROLE_LEADER if f == ai_lead else f.role


## Where the danger to the leader comes from: the nearest enemy within 16 m, else the
## throne room's door.
func _threat_dir(lead: Node3D) -> Vector3:
	var best := 16.0
	var dir := Vector3(0, 0, 1)
	for f in _foes():
		if f.is_dead():
			continue
		var d := _flat(f.global_position, lead.global_position)
		if d < best and d > 0.5:
			best = d
			dir = Vector3(f.global_position.x - lead.global_position.x, 0, f.global_position.z - lead.global_position.z).normalized()
	return dir
