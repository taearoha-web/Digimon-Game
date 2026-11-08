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
##             (บุกก่อน หัวกิลตามหลัง): onto the altar to clear it while the leader waits
##             LEADER_TRAIL behind them with the healers; it goes up inside its guard only
##             with the barrier open and the way clear (leader_may_go). With the hero
##             leading ours they go a step ahead of the hero (the player is never moved);
##   guard    (ป้องกันหัวหน้า) the leader is taking the altar or is hurt: tanks peel the
##             attackers off it, healers stay at its side; an AI leader nearly down steps
##             off behind the altar to be healed (its count waits, a fall would reset it)
##             (committed to the altar the guild holds each switch with two, squad_sizes);
##   defend   (ตั้งรับ) the other guild is taking the altar (everyone at the one on it) or
##             the plan is to hold a line;
##   fallback (ถอย)    a lost fight: pull back to the last rally point, wait for the fallen
##             to come back, then go again;
##   secure   (ยึดสวิตช์) the gates are down but the guild does not hold both castle
##             switches: its switch squads go for them while the main body clears the
##             switch it lacks and the leader waits behind it; with both held (or after
##             SECURE_MAX s) the members go in to clear the altar and the leader follows.
## The castle assault (SiegeArena.SWITCHES, GuildWarMatch.barrier_up) runs beside the
## tactic: with the gates down a guild posts switch squads (_plan_switches): to take them
## (sturdy ones: a tank and a healer each) while it goes for the altar, one more at once
## to retake a switch lost while its leader is on the altar, one more (a damage dealer)
## on a switch the other guild stands in; while securing, the main body rolls from one
## switch it lacks to the other (secure_k) to clear it; to contest them (damage
## dealers to kill the holders: one enemy inside and the switch is not held) while it
## holds the castle, two each while the other guild takes the altar. While the leader is
## on the altar half of the tanks and fighters screen the throne room's door.
## Everywhere else the AI leader comes last too (_leader_post): behind the front line and
## never ahead of the middle of its guild, fighting only what reaches its post; with
## enemies on it and too few of its own round it, it steps back behind them; holding the
## castle it stands behind the altar, its defenders in front.
## The gates: of a doubled tier it batters the weaker or less defended gate, or splits the
## push party by party when both are alike and it is big enough (gate_for); holding the
## castle it comes out in front of both gates, more on the one pressed harder
## (defend_gate_for), and falls back tier by tier as they break.
## The leader's capture plan (leader_timing, _leader_orders): with the barrier open it
## picks its moment (it waits while two other guilds trade blows round the altar, strikes
## when they have worn each other down or their leaders are down), sends its vanguard to
## clear the altar and hold both switches, keeps its healers and a Defender at its side and
## a screen between it and the nearest foes; on the altar it reads the wave coming (a
## stronger group on its way: it steps off, the count waiting, and comes back when it has
## passed: evading). Another guild's leader on the altar: the main body goes for whichever
## is quicker, the leader or a switch its guild holds (deny_k). The holder counter-pushes
## the guild nearest to taking the castle (counter_team). Its moves are told in the feed
## (GuildWarMatch.trace too).
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
## The AI leader goes in last (บุกก่อน หัวกิลตามหลัง): in a push, a gathering or a fall
## back it stands LEADER_TRAIL behind the front line (behind its healers), and in the
## assault on the altar LEADER_TRAIL behind the middle of its guild's body. It fights only
## what comes within LEADER_REACH of that post (never the gate) and walks back to it.
const LEADER_TRAIL := 9.0
const LEADER_REACH := 6.0
## In the assault on the altar, before it is sent up, the AI leader's post is never nearer
## the altar than REAR_GAP m farther than the middle of the members round it (the upper
## median of their distances to the altar: behind at least half of them, both of two),
## whatever the post would be otherwise (stepping back from enemies, waiting close by the
## altar in a war of more than two, the throne room's door with none of its own near).
const REAR_GAP := 5.0
## Besides its whole guild on the way, the leader keeps behind the middle of those within
## REAR_RADIUS m of it (its healers, bard and bodyguard among them).
const REAR_RADIUS := 45.0
## Its healers, bard and bodyguard stand a step ahead of its post: they count this much
## nearer the altar (more than REAR_GAP less that step), so its post never backs away
## from them for good, yet it waits for them when they lag behind it.
const TIED_SLACK := 4.0
## The leader goes onto the altar only with the barrier open (both switches held) and the
## way clear: at least the escort's worth of its guild within VANGUARD_RADIUS of the altar
## and at most ALTAR_CLEAR_FOES of the other guild there (or twice as many of ours), or one
## of its own up there with the altar empty. After LEADER_WAIT_MAX s with the barrier open
## it goes anyway inside its guard (two or more of its guild at the altar or round it), or
## alone once the altar is nearly clear, so a capture is never put off for good.
## While the members go in first they turn only on enemies within ASSAULT_HOLD.
const VANGUARD_RADIUS := 10.0
const ALTAR_CLEAR_FOES := 2
const LEADER_WAIT_MAX := 25.0
const ASSAULT_HOLD := 7.0
## A leader with enemies within LEADER_THREAT_RADIUS, as many as its guild round it (or
## any while it is hurt), steps back behind its own (LEADER_COVER m behind their middle).
const LEADER_THREAT_RADIUS := 7.0
const LEADER_COVER := 4.0
## Taking the altar, an AI leader under LEADER_REST of its HP with enemies on it steps off
## behind the altar (REST_BACK m, still in the throne room, so its count waits instead of
## starting over when it would fall) and its healers patch it up; it steps back on at
## LEADER_RESTED, or when the count is all but done (REST_FINISH s left) it holds on.
const LEADER_REST := 0.4
const LEADER_RESTED := 0.8
const REST_BACK := 7.0
const REST_FINISH := 6.0
## Holding the castle, the leader stands this far behind the altar (away from the door),
## its defenders in front.
const HOLD_BACK := 4.5
const SLOT_GAP := 1.7
const ROW_WIDTH := 6
const ROW_STEP := 1.2

const GATHER := "gather"
const PUSH := "push"
const ESCORT := "escort"
const GUARD := "guard"
const DEFEND := "defend"
const FALLBACK := "fallback"
const SECURE := "secure"
const TACTIC_NAMES := {
	"gather": "รวมพล", "push": "บุกพร้อมกัน", "escort": "คุ้มกันหัวหน้าไปยึดแท่น",
	"guard": "คุ้มกันหัวหน้า", "defend": "ตั้งรับ", "fallback": "ถอยรวมตัวใหม่",
	"secure": "ยึดสวิตช์ซ้าย-ขวาก่อนบุกแท่น",
}
## Securing the switches: after this long the leader goes up anyway (and waits on the altar).
const SECURE_MAX := 30.0
## Picking the moment (a war of more than two): two other guilds that traded at least
## CLASH_HEAT falls lately (each fading over HEAT_MEMORY s) are busy with each other; the
## leader waits for them at most TIMING_MAX s.
const CLASH_HEAT := 2.0
const TIMING_MAX := 6.0
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
## Switch squads: at most SQUAD_MAX per switch, one per SQUAD_SHARE of the guild standing.
const SQUAD_MAX := 3
const SQUAD_SHARE := 5
## With both switches held (or its leader on the altar) a guild of at least this many
## standing posts two on each switch (squad_sizes).
const COMMIT_MIN := 5

## Gathering ends when this share of the guild stands at the rally point (or after
## GATHER_MAX seconds, or when the other guild comes to the rally point: then it fights).
const GATHER_SHARE := 0.5
const GATHER_MAX := 10.0
const GATHER_RADIUS := 12.0
## Pushing: after PUSH_MIN seconds with less than TRICKLE_SHARE of the guild at the front
## (the rest dead or strung out on the way) it gathers again.
const PUSH_MIN := 30.0
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
## The switch squads, one list of fighters per switch (picked each think), and the post of
## each by instance id (apply).
var squads: Array = [[], []]
var _posts: Dictionary = {}
## Whether the squads contest the switches (holding the castle) rather than take them.
var contesting := false
## While securing: the switch the main body goes to clear (-1 none).
var secure_k := -1
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
## Another guild's leader on the altar: the switch the main body goes to (-1: the leader).
var deny_k := -1
## Holding the castle: the guild nearest to taking it (-1 none).
var counter_team := -1
## Other guilds' trading: "a|b" -> heat (falls between them, fading).
var clash := {}
## The leader waits for its moment (tests): since when, and why.
var waiting := false
var _wait_since := 0.0


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
	if prev == FALLBACK and held < FALLBACK_MAX and (held < FALLBACK_MIN or share < REENGAGE_SHARE):
		return FALLBACK
	if prev != FALLBACK and losing and share < RETREAT_SHARE and not bool(s.holding):
		return FALLBACK
	if bool(s.leader_alive) and float(s.leader_hp) < LEADER_LOW and int(s.leader_threat) > 0:
		return GUARD
	if plan in ["defend", "forward", "hold", "gates"]:
		return DEFEND
	if not bool(s.gates_up):
		if bool(s.leader_ai):
			if not bool(s.leader_alive):
				return GATHER
			if prev == ESCORT:
				return ESCORT
			# The switches first: the leader waits at the door until both are held.
			if int(s.get("switches", 2)) < 2 and not bool(s.get("leader_on_altar", false)) and not (prev == SECURE and held >= SECURE_MAX):
				return SECURE
			if prev == SECURE or int(s.escort) >= int(s.escort_need) or (prev == GATHER and held >= GATHER_MAX):
				return ESCORT
			return GATHER
		return ESCORT if bool(s.leader_alive) and bool(s.leader_in_castle) else PUSH
	if prev == PUSH:
		if held >= PUSH_MIN and float(s.at_front) < TRICKLE_SHARE and int(s.enemies_at_rally) == 0:
			return GATHER
		return PUSH
	if prev == GATHER:
		if float(s.gathered) >= GATHER_SHARE or held >= GATHER_MAX or int(s.enemies_at_rally) >= 2:
			return PUSH
		return GATHER
	return GATHER


## Whether the AI leader may go onto the altar in an assault for a reading `s` (see
## read()), `held` s into it: the barrier open (both switches held) and the way clear (its
## vanguard round the altar, few of the other guild left there), or, after LEADER_WAIT_MAX
## s with the barrier open, two of its guild there or round the leader. Already on the
## altar it stays while the barrier is open (with it back the leader steps off behind its
## guild and the count waits).
static func leader_may_go(s: Dictionary, held: float) -> bool:
	if int(s.get("switches", 0)) < 2:
		return false
	if bool(s.get("leader_on_altar", false)):
		return true
	# A war of more than two: the barrier is open only a few seconds at a time (three other
	# guilds fight over the switches), so the leader, waiting close, goes at once.
	if int(s.get("rivals", 1)) > 1 and int(s.get("escort", 0)) + int(s.get("vanguard", 0)) >= 1:
		return true
	var van := int(s.get("vanguard", 0))
	var foes := int(s.get("altar_foes", 0))
	if van >= maxi(1, int(s.escort_need)) and (foes <= ALTAR_CLEAR_FOES or van >= foes * 2):
		return true
	# Its first member up there and nobody (or only the other guild's leader) left round
	# the altar: the way is clear (a guild that holds the switches with two each has few
	# to send ahead).
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


## A switch changed hands: think again within a beat.
func on_switch_change() -> void:
	_think_left = minf(_think_left, 0.3)


## A stun of ours landed on `target` for `seconds`: the others hold theirs until it ends.
func note_cc(target: Node, seconds: float) -> void:
	if target != null:
		_cc[target.get_instance_id()] = clock + seconds


func cc_fresh(target: Node) -> bool:
	return target != null and float(_cc.get(target.get_instance_id(), -1.0)) > clock


## Whether the AI leader may go onto the altar now: inside its escort, guarded, or to
## contest the other guild's leader on it (taking over the moment it steps off).
func allows_capture() -> bool:
	if resting or evading:
		return false
	if tactic == ESCORT:
		return leader_go
	if tactic == GUARD:
		# Guarding the one taking the altar while the barrier is open (a hurt leader off
		# it, or one behind the barrier, steps back behind its guild instead).
		if team == GuildFighter.TEAM_ALLY and war.hero_leads():
			return true
		return not war.barrier_up(team) and (bool(last_read.get("we_capturing", false)) or bool(last_read.get("leader_on_altar", false)))
	return tactic == DEFEND and war.capture.has("team") and int(war.capture.team) != team


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
	_plan_switches(s)
	var before := focus
	focus = _pick_focus()
	dive = _pick_dive()
	if focus != null and focus != before:
		_call_focus(focus)


## The assault on the altar: the members go in first and the AI leader follows behind
## them; it goes up once the barrier is open and the way is clear (leader_may_go, then
## kept until the tactic changes), called out in the war chat.
func _leader_orders(s: Dictionary) -> void:
	if not bool(s.leader_ai) or not bool(s.leader_alive) or bool(s.gates_up):
		leader_go = false
		return
	if leader_go and int(s.get("switches", 0)) < 2 and (tactic == ESCORT or tactic == GUARD):
		# The barrier is back before the leader got the castle: it steps back behind its
		# guild (a count waits where it was) and the guild retakes the switch.
		leader_go = false
		callout("leader_back", "บาเรียกลับมา! หัวกิลถอยหลังแนว ไปยึดสวิตช์คืน")
		return
	if tactic == ESCORT:
		var timing := leader_timing(s)
		if not leader_go and timing != "" and int(s.get("switches", 0)) >= 2:
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
			if int(s.get("switches", 0)) < 2:
				callout("vanguard", "บุกก่อน! ยึดสวิตช์ให้ครบ หัวกิลตามหลัง")
			else:
				callout("vanguard", "บุกก่อน! เคลียร์แท่นให้หัวกิล หัวกิลตามหลัง")
	elif tactic != GUARD:
		leader_go = false


## The leader's moment in a war of more than two (its barrier open, not yet going up):
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
	if busy and not clear and (not waiting or clock - _wait_since < TIMING_MAX):
		return "wait"
	if waiting and (clear or not busy):
		return " หลังกิลด์อื่นซัดกันจนอ่อนแรง"
	return ""


## Another guild's leader taking the altar: the main body goes for whichever is quicker,
## the leader on it or a switch its guild holds with few in the circle (losing one brings
## the barrier back). Holding the castle or taking it ourselves: nothing to deny.
func _deny(s: Dictionary) -> void:
	var was := deny_k
	deny_k = -1
	if not bool(s.enemy_capturing):
		return
	var taker := war.capturer()
	var their := int(war.capture.get("team", -1))
	if taker == null or their < 0:
		return
	var body := _middle_of_side()
	if not body.is_finite():
		return
	var to_leader := _flat(body, taker.global_position)
	var best := to_leader
	for k in SiegeArena.SWITCHES.size():
		if war.switch_owner[k] != their:
			continue
		var holders: int = war.count_switch(k)[their]
		var d := _flat(body, SiegeArena.SWITCHES[k]) + 6.0 * float(holders)
		if d < best - 6.0:
			best = d
			deny_k = k
	if deny_k >= 0 and deny_k != was:
		trace_line("deny_sw%d" % deny_k, "หัวหน้ากิลด์ %s: ตัด%sของกิลด์ %s เร็วกว่า!" % [war.team_name(team), SiegeArena.SWITCH_NAMES[deny_k], war.team_name(their)])
	elif deny_k < 0 and (was >= 0 or tactic == DEFEND):
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


## Holding the castle: the guild nearest to taking it (its count, both switches, how many
## it has in the throne room) is the one to push back.
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
		var near := float(war.switches_held(t)) * 3.0 + float(inside[t]) * 0.5
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
				callout("push", "บุก! ตีประตูพร้อมกัน หัวกิลตามหลัง!" if bool(s.leader_ai) and bool(s.leader_alive) else "บุก! ตีประตูพร้อมกัน!")
			_buff_up(rally, 18.0)
		ESCORT:
			if not bool(s.leader_ai):
				callout("escort", "คุ้มกันหัวหน้าไปยึดแท่น! นำหน้าไปก่อน")
			elif was == SECURE and int(s.get("switches", 0)) >= 2:
				callout("escort", "ยึดสวิตช์ครบ! บุกก่อน เคลียร์แท่น หัวกิลตามหลัง")
			else:
				callout("escort", "บุกก่อน! หัวกิลตามหลัง")
			_buff_up(front(), 18.0)
		SECURE:
			callout("secure", "แบ่งทีมยึดสวิตช์ซ้ายและขวา! หัวกิลรอหลังแนว")
		GUARD:
			callout("guard", "คุ้มกันหัวหน้า!")
		DEFEND:
			if bool(s.enemy_capturing):
				callout("stop", "หยุดคนบนแท่น! สตันหัวกิล แย่งสวิตช์ให้บาเรียกลับมา!")
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
	secure_k = _pick_secure() if war.front_gate() == null else -1
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
			rally = Vector3(x + toward * 4.0, 0, SiegeArena.GATE_Z[k] + 12.0)
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


## The switch the guild lacks that most needs the main body: one being fought over, then
## one the other guild holds, then an empty one (-1 when it holds both).
func _pick_secure() -> int:
	var best := -1
	var best_score := -1
	for k in SiegeArena.SWITCHES.size():
		if war.switch_pin == team or (war.switch_pin < 0 and war.switch_owner[k] == team):
			continue
		var score := 3 if war.switch_contested[k] else (2 if war.switch_owner[k] >= 0 and war.switch_owner[k] != team else 1)
		if score > best_score:
			best_score = score
			best = k
	return best


func place_name() -> String:
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


## How many of the other guilds stand within 12 m of gate g's front.
func _defenders_at(g: CastleGate) -> int:
	var at := SiegeArena.gate_front(g.tier, g.lane)
	var n := 0
	for f in _foes():
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
		if deny_k >= 0:
			return SiegeArena.SWITCHES[deny_k]
		if who == null and war.castle_owner == team and war.front_gate() != null:
			return rally
		return who.global_position if who != null else SiegeArena.ALTAR
	if tactic == FALLBACK:
		return fallback_point
	if tactic == SECURE and secure_k >= 0:
		return SiegeArena.SWITCHES[secure_k]
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
	for f in _foes():
		if f.is_dead():
			continue
		if _flat(f.global_position, rally) < 16.0:
			enemies_at_rally += 1
		if lead != null and _flat(f.global_position, lead.global_position) < 10.0:
			threat += 1
		if _flat(f.global_position, SiegeArena.ALTAR) < VANGUARD_RADIUS + 2.0:
			altar_foes += 1
	if team != GuildFighter.TEAM_ALLY and lead != null and war.hero_alive() and _flat(war.hero.global_position, lead.global_position) < 10.0:
		threat += 1
	if team != GuildFighter.TEAM_ALLY and war.hero_alive() and _flat(war.hero.global_position, SiegeArena.ALTAR) < VANGUARD_RADIUS + 2.0:
		altar_foes += 1
	var foe_switches := 0
	var leaders_down := 0
	var rivals := 0
	for t in war.team_count():
		if t == team:
			continue
		rivals += 1
		foe_switches = maxi(foe_switches, war.switches_held(t))
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
		"switches": war.switches_held(team),
		"foe_switches": foe_switches,
		"rival_leaders_down": leaders_down,
		"rivals": rivals,
		"leader_on_altar": lead != null and SiegeArena.on_altar(lead.global_position),
		"vanguard": vanguard,
		"altar_foes": altar_foes,
	}


## The focus target: the best of the other guild (the hero too, for theirs) within
## FOCUS_RANGE of our front.
func _pick_focus() -> Node3D:
	var at := front()
	var taker := war.capturer()
	if taker != null and war.capture.has("team") and int(war.capture.team) != team:
		return taker
	var best: Node3D = null
	var best_score := -1.0e9
	for f in _foes():
		if f.is_dead():
			continue
		var d := _flat(f.global_position, at)
		if d > FOCUS_RANGE or _in_camp(f):
			continue
		var score := focus_score(d, f.hp_ratio(), _kind(f), _escorts(f), f.under_guard(), f.capturing)
		# Holding the castle: the guild nearest to taking it first.
		if counter_team >= 0 and f.team == counter_team:
			score += 6.0
		# Whoever holds a switch for the other guild (killing it brings the barrier back
		# for them, or opens it for us).
		if f.switch_post >= 0 and SiegeArena.on_switch(f.global_position, f.switch_post):
			score += 14.0
		if score > best_score:
			best_score = score
			best = f
	if team != GuildFighter.TEAM_ALLY and war.hero_alive():
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
	for f in _foes():
		if f.is_dead() or f.under_guard() or _in_camp(f):
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
	var hero_kind := _kind(war.hero) if war.hero_alive() else KIND_OTHER
	if team != GuildFighter.TEAM_ALLY and hero_kind != KIND_OTHER and (hero_kind != KIND_LEADER or _escorts(war.hero) <= 1):
		var d := _flat(war.hero.global_position, at)
		if d <= DIVE_RANGE and not _in_camp(war.hero) and focus_score(d, war.hero_hp_ratio(), hero_kind, _escorts(war.hero), false, false) > best_score:
			best = war.hero
	return best


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
		return _flat(who.global_position, SiegeArena.KEEP_CAMP) < SiegeArena.KEEP_SAFE
	return _flat(who.global_position, SiegeArena.camp(t)) < SiegeArena.CAMP_RADIUS


func _call_focus(target: Node3D) -> void:
	if war.capturer() == target:
		return
	var g := target as GuildFighter
	if g != null and g.switch_post >= 0 and SiegeArena.on_switch(g.global_position, g.switch_post):
		callout("focus", "รุมคนยืน%s!" % SiegeArena.SWITCH_NAMES[g.switch_post])
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
# The castle switches: who holds or contests them
# ---------------------------------------------------------------------------

## How many to post on each switch for a reading `s` (pure): none with the gates up or
## falling back; to take them (not holding the castle) one per SQUAD_SHARE standing, at
## least one, at most two, plus one on a switch we lack while our leader is on the altar
## or taking it (retake it now); to contest them while holding the castle one each, two
## while the other guild takes the altar. Never more than SQUAD_MAX.
static func squad_sizes(s: Dictionary, tactic_now: String, owned: Array, fought: Array = []) -> Array[int]:
	var out: Array[int] = [0, 0]
	if bool(s.gates_up) or tactic_now == FALLBACK or tactic_now == "":
		return out
	var standing := int(s.get("standing", 8))
	if standing <= 0:
		return out
	var base := 1
	var waiting := bool(s.we_capturing) or bool(s.get("leader_on_altar", false))
	# Committed to the altar (both switches held, or the leader on it): the guild holds
	# each switch with as many as the holder sends to contest it (two), so two of them
	# walking in never outnumber a lone holder and flick the barrier back on.
	var committed := not bool(s.holding) and (waiting or int(s.get("switches", 0)) >= 2)
	if bool(s.holding):
		base = 2 if bool(s.enemy_capturing) else 1
	else:
		base = clampi(standing / SQUAD_SHARE, 1, 2)
		if committed and standing >= COMMIT_MIN:
			base = 2
	var big := standing >= 10
	for k in out.size():
		var n := base
		if big and not bool(s.holding) and waiting and k < owned.size() and not bool(owned[k]):
			n += 1
		# The other guild in the circle: one more to kill its holders.
		if standing >= 6 and k < fought.size() and bool(fought[k]):
			n += 1
		out[k] = mini(n, SQUAD_MAX)
	# Never most of the guild on the switches: the main body wins a switch by numbers
	# (it rolls onto the one the guild lacks) and the leader needs its guard.
	# Committed, up to two in three hold them (the leader on the altar is guarded by the
	# switches: the barrier is what stops a count).
	var cap := maxi(2, standing * 2 / 3 if committed else standing / 2)
	while out[0] + out[1] > cap and (out[0] > 1 or out[1] > 1):
		if out[0] >= out[1]:
			out[0] -= 1
		else:
			out[1] -= 1
	return out


## How fit a fighter of role `r` is to go to a switch: to take it, the sturdy ones that
## hold out (tanks, then healers to keep them up, then fighters); to contest it, the
## damage dealers that kill its holders (assassins, fighters, tanks).
static func holder_fit(r: int, contest: bool) -> float:
	if contest:
		return [7.0, 8.0, 10.0, 5.0, 2.0, 1.0, -100.0][r]
	return [10.0, 6.0, 3.0, 4.0, 2.5, 8.0, -100.0][r]


## Picks the switch squads (the ones already posted stay while they stand) and tells the
## plan in the war chat.
func _plan_switches(s: Dictionary) -> void:
	var lead := _alive_leader()
	var ai_lead := lead as GuildFighter
	var side := _side()
	var standing := 0
	for f in side:
		standing += 0 if f.is_dead() or f == ai_lead else 1
	s["standing"] = standing
	var owned: Array = []
	var fought: Array = []
	for k in SiegeArena.SWITCHES.size():
		owned.append(war.switch_pin == team or (war.switch_pin < 0 and war.switch_owner[k] == team))
		fought.append(war.switch_pin < 0 and (war.switch_contested[k] or (war.switch_owner[k] >= 0 and war.switch_owner[k] != team)))
	var sizes := squad_sizes(s, tactic, owned, fought)
	contesting = bool(s.holding)
	var ordered := war.party_switch >= 0 and war.front_gate() == null
	var taken := {}
	var had_any := not (squads[0] as Array).is_empty() or not (squads[1] as Array).is_empty()
	for k in sizes.size():
		var keep: Array[GuildFighter] = []
		for f in squads[k]:
			if keep.size() < sizes[k] and _can_post(f, ai_lead, ordered):
				keep.append(f)
				taken[f.get_instance_id()] = true
		squads[k] = keep
	for k in sizes.size():
		var keep: Array[GuildFighter] = squads[k]
		var post: Vector3 = SiegeArena.SWITCHES[k]
		while keep.size() < sizes[k]:
			var best: GuildFighter = null
			var best_score := -1.0e9
			var has_healer := keep.any(func(g): return (g as GuildFighter).role == ROLE_HEALER)
			for f in side:
				if taken.has(f.get_instance_id()) or not _can_post(f, ai_lead, ordered):
					continue
				var r := _role(f, ai_lead)
				# The first to hold it is sturdy; the next on a fought switch kills.
				var fit := holder_fit(r, contesting or (bool(fought[k]) and not keep.is_empty()))
				if r == ROLE_HEALER and (has_healer or keep.is_empty()):
					fit -= 6.0
				var score := fit + 4.0 * f.hp_ratio() - 0.12 * _flat(f.global_position, post) - (6.0 if f.in_hero_party() else 0.0)
				if score > best_score:
					best_score = score
					best = f
			if best == null:
				break
			keep.append(best)
			taken[best.get_instance_id()] = true
		squads[k] = keep
	_posts.clear()
	for k in squads.size():
		for f in squads[k]:
			_posts[(f as GuildFighter).get_instance_id()] = k
	var any := not (squads[0] as Array).is_empty() or not (squads[1] as Array).is_empty()
	if any and not had_any:
		if contesting:
			callout("contest", "ส่งคนไปแย่งสวิตช์ซ้าย-ขวา! ฆ่าคนยืนสวิตช์ให้บาเรียกลับมา")
		else:
			callout("switches", "แท็งค์กับฮีลไปยืนยึดสวิตช์ซ้ายและขวา คนอื่นคุ้มกัน!")
	# A switch lost while the leader is on the altar: the barrier is back, retake it.
	if not contesting and (bool(s.we_capturing) or bool(s.get("leader_on_altar", false))):
		for k in owned.size():
			if not bool(owned[k]):
				callout("retake", "เสีย%s! ส่งคนไปยึดคืนด่วน หัวกิลรออยู่บนแท่น" % SiegeArena.SWITCH_NAMES[k])
				break
	elif bool(s.enemy_capturing) and int(s.get("foe_switches", 0)) >= 2:
		callout("break", "ศัตรูยึดสวิตช์ครบ! ไปแย่งสวิตช์ด่วน แค่คนเดียวในวงบาเรียก็กลับมา")


## Whether `f` may be posted to a switch: standing, not the leader nor the one on the
## altar, not one of the hero's party while the player has sent the party somewhere.
func _can_post(f: GuildFighter, ai_lead: GuildFighter, ordered: bool) -> bool:
	if f == null or not is_instance_valid(f) or f.is_dead() or f == ai_lead or f.capture_role or f.capturing:
		return false
	return not (ordered and f.in_hero_party())


## The switch `f` is posted to now (-1 none): its squad's, or the one the player sent the
## hero's party to.
func post_of(f: GuildFighter) -> int:
	if f.is_dead() or f.capture_role or f.capturing or war.front_gate() != null:
		return -1
	if war.party_switch >= 0 and f.in_hero_party():
		return war.party_switch
	return int(_posts.get(f.get_instance_id(), -1))


# ---------------------------------------------------------------------------
# Orders: who stands where (with GuildWarMatch._assign_objectives)
# ---------------------------------------------------------------------------

## Lays the guild out for the tactic on top of the plan's posts: rows by role facing the
## way forward, the AI leader behind its tanks, the focus and dive targets, tanks told
## whom to guard. Nothing changes before the first think (tactic "").
func apply() -> void:
	if tactic == "":
		return
	var side := _side()
	for f in side:
		f.switch_post = post_of(f)
	var lead := _alive_leader()
	var ai_lead := lead as GuildFighter
	_update_rest(ai_lead)
	var at := front()
	var fwd := forward
	# The assault on the altar with an AI leader that has not gone up yet: the members go
	# first, onto the altar to clear it; the leader follows behind them.
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
	elif tactic == SECURE and secure_k >= 0:
		# The front line through the switch, the healers and the leader behind it.
		var to: Vector3 = SiegeArena.SWITCHES[secure_k] - rally
		to.y = 0.0
		fwd = to.normalized()
	_counts.fill(0)
	_index.fill(0)
	for f in side:
		if not f.is_dead() and not f.capture_role and f.switch_post < 0:
			_counts[_role(f, ai_lead)] += 1
	# The leader at the altar: half the tanks and fighters screen the throne room's door.
	var screen := (tactic == ESCORT or tactic == GUARD) and lead != null and _flat(lead.global_position, SiegeArena.ALTAR) < 10.0
	var door := Vector3(0, 0, SiegeArena.GATE_Z[2] - 5.0)
	# The leader waits on the altar behind the barrier: two in three go with the main
	# body to clear the switch it lacks, the rest stay round the leader.
	var rolling := (screen or assault) and not contesting and secure_k >= 0 and war.switches_held(team) < 2
	var roll_at: Vector3 = SiegeArena.SWITCHES[secure_k] if rolling else Vector3.ZERO
	var roll_fwd := (roll_at - SiegeArena.ALTAR).normalized() if rolling else Vector3.FORWARD
	var capturing_foe := war.capturer() != null and int(war.capture.get("team", team)) != team
	leader_post = _leader_post(ai_lead, at, fwd, assault) if ai_lead != null else Vector3.INF
	# In the push, the switches and the assault the healers stand by the leader behind.
	var guarded_post := leader_post.is_finite() and tactic in [PUSH, SECURE, ESCORT, GUARD]
	var lead_dir := Vector3(at.x - leader_post.x, 0, at.z - leader_post.z) if guarded_post else Vector3.ZERO
	lead_dir = lead_dir.normalized() if lead_dir.length() > 0.5 else fwd
	var side_k := 0
	# The assault on the altar (the gates down): a Defender at the leader's side and a screen.
	var inside := guarded_post and war.front_gate() == null
	var bodyguard := _bodyguard(side, ai_lead) if inside else null
	var screen_dir := _screen_dir(leader_post) if inside else Vector3.ZERO
	_tied.clear()
	for f in side:
		var r := _role(f, ai_lead)
		f.focus = focus
		f.dive = dive if f.role == ROLE_ASSASSIN else null
		f.guard_node = lead if f.role == ROLE_TANK else null
		if f.is_dead() or f.capture_role:
			continue
		if f == ai_lead and leader_post.is_finite():
			# The leader at its post behind its guild: it fights only what comes to it (in
			# the assault on the altar giving ground backwards only).
			f.objective = null
			f.keep_back = true
			f.keep_front = SiegeArena.ALTAR if assault and not leader_covering else Vector3.INF
			f.hold_range = LEADER_REACH
			f.goal_point = leader_post
			continue
		if f.switch_post >= 0:
			# Posted to a switch: into its circle, spread a little, nothing else.
			f.objective = null
			f.hold_range = 0.0
			f.guard_node = null
			f.dive = null
			var spread := TAU * float(f.get_instance_id() % 7) / 7.0
			f.goal_point = SiegeArena.SWITCHES[f.switch_post] + Vector3(cos(spread), 0, sin(spread)) * SiegeArena.SWITCH_RADIUS * 0.35
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
			# The healers and the bard keep at the waiting leader's side, a step ahead of it
			# towards the fight (it is never left alone to be dived, they heal from behind).
			f.objective = null
			f.hold_range = 9.0
			f.goal_point = _in_bounds(leader_post + lead_dir * 2.0 + Vector3(-lead_dir.z, 0, lead_dir.x) * (float(side_k % 3) - 1.0) * 1.8)
			side_k += 1
			continue
		var i := _index[r]
		_index[r] += 1
		var depth := -1.0
		if f == ai_lead and f.hp_ratio() < 0.45:
			depth = LEADER_BACK
		match tactic:
			GATHER, FALLBACK, SECURE:
				f.objective = null
				f.hold_range = 8.0 if tactic == FALLBACK else 12.0
				f.goal_point = slot(at, fwd, r, i, _counts[r], depth)
			PUSH:
				if war.front_gate() != null:
					f.goal_point = slot(at, fwd, r, i, _counts[r], depth)
			ESCORT, GUARD:
				f.objective = null
				f.hold_range = ASSAULT_HOLD if assault else 11.0
				if rolling and f != ai_lead and i % 3 != 0:
					f.hold_range = 12.0
					f.goal_point = slot(roll_at, roll_fwd, r, i, _counts[r], depth)
				elif screen and f != ai_lead and (r == ROLE_TANK or r == ROLE_MELEE) and i % 2 == 1:
					f.hold_range = 10.0
					f.goal_point = slot(door, Vector3(0, 0, 1), r, i / 2, maxi(1, _counts[r] / 2))
				else:
					f.goal_point = slot(at, fwd, r, i, _counts[r], depth)
			DEFEND:
				if capturing_foe and deny_k >= 0 and (i % 4 != 3 if war.team_count() <= 2 else i % 3 == 0):
					# Quicker to cut a switch of theirs than to reach the leader.
					f.objective = null
					f.hold_range = 6.0
					f.goal_point = SiegeArena.SWITCHES[deny_k]
				elif capturing_foe and war.team_count() > 2 and war.castle_owner != team and i % 3 != 0:
					# A war of more than two: only the strike group (a third) goes for the leader
					# on the altar; the rest hold the throne room's door against the other guilds.
					f.objective = null
					f.hold_range = 9.0
					f.goal_point = slot(Vector3(0, 0, SiegeArena.GATE_Z[2] - 6.0), Vector3(0, 0, 1), r, i / 2, maxi(1, _counts[r] / 2))
				elif capturing_foe:
					f.objective = null
					f.hold_range = 0.0
					f.goal_point = war.capturer().global_position
				elif war.castle_owner == team and war.front_gate() != null and f != ai_lead:
					# Out in front of both gates of the front tier (more on the one pressed harder).
					var front := war.front_gates()
					var g := defend_gate_for(f, front)
					if g != null:
						f.objective = null
						f.hold_range = 12.0
						f.goal_point = SiegeArena.gate_front(g.tier, g.lane) + Vector3(float(i % 5 - 2) * 1.6, 0, 1.5 + float(i / 5 % 3) * 1.4)
		# The AI leader never charges in alone: it keeps to its place behind the tanks.
		if f == ai_lead and tactic != DEFEND:
			f.hold_range = 8.0 if depth < 0.0 else 5.0


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


## Where the AI leader stands now (Vector3.INF: where the formation puts it, going up to
## the altar or guarded on it): behind its own when enemies are on it (_cover_point);
## holding the castle, behind the altar; else LEADER_TRAIL behind its front line (the
## switch it clears, the gate, the rally point), and never nearer that front than
## LEADER_TRAIL behind the middle of its guild's body (on the way back to its camp), so it
## never walks ahead of the guild into the other one's line; in the assault on the altar,
## not yet sent up, behind the members round it whatever else it does (_rear_line,
## _rear_post: measured from the altar, not along the way home, which runs from a switch
## past the altar's side to the door).
func _leader_post(lead: GuildFighter, at: Vector3, fwd: Vector3, assault: bool) -> Vector3:
	# Holding the castle with the gates up: inside, behind the front tier (it walks through
	# its own gates), out of the attackers' reach.
	if war.castle_owner == team and war.front_gate() != null:
		leader_covering = false
		return Vector3(0, 0, SiegeArena.GATE_Z[war.front_tier()] - 9.0)
	if resting or evading:
		leader_covering = false
		return _in_bounds(SiegeArena.ALTAR + forward * REST_BACK)
	# The assault on the altar, not yet sent up: whatever else it does, behind its members
	# (taking the switches before it too, so it is not left ahead once the assault starts).
	var securing := tactic == SECURE and war.front_gate() == null and war.castle_owner != team and not leader_go
	var rear: Dictionary = _rear_line(lead) if assault or securing else {}
	var cover := _cover_point(lead, fwd)
	if cover.is_finite() and not rear.is_empty() and _flat(cover, SiegeArena.ALTAR) < float(rear.line) - REAR_GAP:
		# Stepping back from enemies would take it ahead of its members: its rear post
		# instead (its bodyguard and screen between it and them).
		cover = Vector3.INF
	leader_covering = cover.is_finite()
	if leader_covering:
		return _in_bounds(cover)
	# A war of more than two with the gates down: the leader waits close by the altar,
	# behind it and its guard (the barrier opens only for a few seconds at a time).
	if war.team_count() > 2 and war.front_gate() == null and war.castle_owner != team and tactic in [SECURE, ESCORT, GATHER, GUARD] and not leader_go:
		var near := SiegeArena.ALTAR + forward * (SiegeArena.ALTAR_RADIUS + 3.5)
		if _guard_near(near, lead) >= 2:
			return _in_bounds(near)
	match tactic:
		DEFEND:
			if war.castle_owner == team and war.front_gate() == null:
				return SiegeArena.ALTAR + forward * HOLD_BACK
			return Vector3.INF
		GUARD, ESCORT:
			if not assault:
				return Vector3.INF
			if not rear.is_empty():
				return _rear_post(lead, rear)
	var body := _body_anchor(lead, at)
	var p := at - fwd * LEADER_TRAIL
	if body.is_finite():
		if assault or _flat(p, at) < _flat(body, at) + LEADER_TRAIL:
			p = _back_along(body, at, LEADER_TRAIL)
	elif war.front_gate() == null:
		# Too few of its guild up there (the rest on the switches or on the way): it waits
		# behind the throne room's door.
		p = _back_along(rally, at, LEADER_TRAIL)
	if not rear.is_empty() and _flat(p, SiegeArena.ALTAR) < float(rear.line):
		return _rear_post(lead, rear)
	return _in_bounds(Vector3(p.x, 0.0, p.z))


## The members the AI leader keeps behind in the assault on the altar ({} with none):
## "line", the least distance from the altar its post may have: REAR_GAP past the upper
## median of the distances of its guild on its way there (behind at least half of them,
## both of two: those standing, not on a switch nor in their camp nor falling back to
## it), of the whole guild and of those within REAR_RADIUS of it (its healers, bard and
## bodyguard, a step ahead of its post, counted TIED_SLACK m nearer the altar, so that it
## waits for them when they lag but never backs away from them; not its screen);
## "anchor" (and "dist" from the altar), the member it trails LEADER_TRAIL behind: the
## middle of those that go on their own (not its healers, bard or bodyguard; the ones
## coming back from their camp too: it falls back to them, so it is not left ahead of
## them when they pass it), else of all of them.
func _rear_line(lead: GuildFighter) -> Dictionary:
	var going: Array = []
	var all: Array = []
	for f in _side():
		# Not those falling back to their camp to heal (it would follow them home).
		if f == lead or f.is_dead() or f.switch_post >= 0 or f.is_retreating() or _in_camp(f):
			continue
		var tie := int(_tied.get(f.get_instance_id(), -1))
		if tie == TIED_SCREEN:
			continue
		var r := _role(f, lead)
		var follows := tie == TIED_GUARD or r == ROLE_HEALER or r == ROLE_BARD
		var d := _flat(f.global_position, SiegeArena.ALTAR)
		var by := _flat(f.global_position, lead.global_position) < REAR_RADIUS
		if by:
			all.append([d - (TIED_SLACK if follows else 0.0), f.global_position])
		if not follows:
			going.append([d, f.global_position])
	var near := going
	# Only those who keep by it round it: it keeps just behind them (trailing them by
	# LEADER_TRAIL, their posts a step ahead of its own, it would back away for good).
	var trail := not near.is_empty()
	if not trail:
		near = all
	if near.is_empty():
		return {}
	var by_d := func(x, y): return float(x[0]) < float(y[0])
	near.sort_custom(by_d)
	var mid: Array = near[near.size() / 2]
	var line := float(mid[0]) + REAR_GAP
	if not all.is_empty():
		all.sort_custom(by_d)
		var round_it: Array = all[all.size() / 2]
		if float(round_it[0]) + REAR_GAP > line:
			line = float(round_it[0]) + REAR_GAP
			if not trail or line > float(mid[0]) + LEADER_TRAIL:
				# Those round it hold it back more than the middle it trails: it keeps
				# just behind them.
				return {"line": line, "anchor": round_it[1], "dist": float(round_it[0]), "trail": false}
	return {"line": line, "anchor": mid[1], "dist": float(mid[0]), "trail": trail}


## The leader's post in the assault on the altar (`rear` from _rear_line): LEADER_TRAIL m
## farther from the altar than its anchor (at least its line): in the throne room
## straight out from the altar past the anchor (the way home runs to the door, past the
## altar's side for a member by a switch), else back along the way home; of those past
## the line the one nearest the anchor, else the farthest. Kept back by those round it
## (no anchor to trail) it holds where it stands while that is past the line by at most
## LEADER_TRAIL.
func _rear_post(lead: GuildFighter, rear: Dictionary) -> Vector3:
	var a: Vector3 = rear.anchor
	a.y = 0.0
	var line := float(rear.line)
	var lead_d := _flat(lead.global_position, SiegeArena.ALTAR)
	if not bool(rear.trail) and lead_d >= line and lead_d <= line + LEADER_TRAIL:
		return Vector3(lead.global_position.x, 0.0, lead.global_position.z)
	var want := maxf(float(rear.dist) + LEADER_TRAIL, line) if bool(rear.trail) else line
	var cands: Array[Vector3] = []
	if SiegeArena.section(a) == 4:
		var out := a - SiegeArena.ALTAR
		out.y = 0.0
		var dir := out.normalized() if out.length() > 1.0 else Vector3(0, 0, 1)
		for k in [0, 1, -1, 2, -2, 3, -3, 4, -4]:
			var c := _in_bounds(SiegeArena.ALTAR + dir.rotated(Vector3.UP, 0.3 * float(k)) * want)
			if SiegeArena.section(c) == 4:
				cands.append(c)
	# Back along the way home a step at a time (the way may turn, so its length is not the
	# distance gained from the altar).
	var back := maxf(1.0, want - _flat(a, SiegeArena.ALTAR))
	for k in 6:
		cands.append(_in_bounds(_back_along(a, SiegeArena.ALTAR, back + 2.0 * float(k))))
	var best := Vector3.INF
	var far := cands[0]
	for c in cands:
		if _flat(c, SiegeArena.ALTAR) > _flat(far, SiegeArena.ALTAR):
			far = c
		if _flat(c, SiegeArena.ALTAR) >= line and (not best.is_finite() or _flat(c, a) < _flat(best, a)):
			best = c
	var p := best if best.is_finite() else far
	return Vector3(p.x, 0.0, p.z)


## The middle of the guild's body on its way to `at`: the member at the median distance
## from it, of those standing within 45 m of the front or of the leader (not the switch
## holders, nor the one sent to the altar, nor the healers and bards who keep by the
## leader); INF with fewer than two.
func _body_anchor(lead: GuildFighter, at: Vector3) -> Vector3:
	var near: Array = []
	for f in _side():
		if f == lead or f.is_dead() or f.capture_role or f.switch_post >= 0:
			continue
		var r := _role(f, lead)
		if r == ROLE_HEALER or r == ROLE_BARD:
			continue
		var d := _flat(f.global_position, at)
		if d > 45.0 and _flat(f.global_position, lead.global_position) > 45.0:
			continue
		near.append([d, f.global_position])
	if near.size() < 2:
		return Vector3.INF
	near.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	return near[near.size() / 2][1]


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
		if f == lead or f.is_dead() or f.switch_post >= 0:
			continue
		var d := _flat(f.global_position, lead.global_position)
		if d < 20.0:
			mates += 1
			mates_at += f.global_position
		if d < LEADER_THREAT_RADIUS:
			guards += 1
	if guards > foes and lead.hp_ratio() >= 0.6:
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
		if f == ai_lead or f.is_dead() or f.switch_post >= 0 or f.capture_role or _role(f, ai_lead) != ROLE_TANK:
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
