class_name GuildWarDoctrine
extends RefCounted
## One guild's war doctrine (หลักการรบของหัวหน้ากิลด์): the leader's plan over its commander
## (GuildWarCommander, which still lays out the formation, the escort
## and the focus). GuildWarMatch keeps one per guild that plays it (every guild in the
## game's own wars; GuildWarMatch.smart false: the old commander alone, for the
## old-vs-new measurement in tests/tools/guild_war_sim). Only the game running the war
## thinks (a league mirror online runs no fighters and no doctrine: it is shown the
## host's plan and phase, GuildWarMatch.mirror_phase).
##
## Every THINK_EVERY s (staggered between guilds) it reads the field as a leader standing
## at the front would (read_field): who of each guild stands within FRONT_RADIUS of its
## front, their health and strength, how many are down or still walking back from camp
## (the enemy's respawn window), the gates, the altar, the points and the
## clock, and decides:
##   the PHASE (ขั้นของแผน: PHASES, phase_for): what the guild does now, attack
##     (form, breach, exploit, wait, muster, assault, capture, besiege), defence
##     (hold, guard, stop, counter, recover) or a war of four (vulture: let two others
##     trade first). A phase changes only after it is seen on two thinks running (or
##     PHASE_MIN s held), but at once for the urgent ones (settle_phase);
##   the WINDOW (respawn timing, pick_window), read at its objective (the gate it
##     batters, else the altar): `engage` while the guild it fights has
##     lost most of its front (EXPLOIT_SPENT down or walking back) and ours outweighs what
##     is left (it pushes at once instead of waiting at the rally point, and its leader
##     may go up to the altar sooner); `wait` (a war of two) while ours is outweighed there
##     (WAIT_BALANCE) with its own fallen on the way back: it pulls back to the rally point
##     (with the gates down a staging point in the last yard) and goes again as one wave
##     once WAVE_READY of it stands there (or WAIT_MAX s). Both with hysteresis;
##   the RACE (nobody holds the castle): the whole guild musters at the last gate as it is
##     about to fall (pick_muster) and surges into the throne room the moment it does;
##   the SIEGE (a war of two): waves that keep losing the trades to a holder stop
##     feeding it and besiege from the last yard (pick_besiege) until its front is spent;
##   the LAST MINUTES (LAST_CALL s before the bell): the holder keeps everyone round the
##     altar, every other guild goes all in (no falling back);
##   the TARGETS (focus_extra): the guild leading on points or holding the castle, a
##     fighter busy with a third guild (third-party), the killable;
##   the SQUADS (assign_squads): every member in one squad by its class and the moment:
##     vanguard (tanks), breakers (melee), support (priest, bard), ranged (archer, mage,
##     summoner), hunters (assassins) and the leader's
##     guard (its bodyguard), each with a squad leader (its strongest standing) and an
##     objective; the members follow their squad: the hurt fall back to the support squad
##     at the front (not the far camp) and come back, squishy ones a little earlier; a tank
##     peels for a healer under attack; area skills go where foes stand thick; everyone
##     leans harder on the called target.
## The SECOND BRAIN (smart2, every guild in the game's own wars; `base` keeps the doctrine
## as it stood before it, the measurement's baseline), from traced sim wars:
##   the DEADLINE (last_call_at): a guild not holding the castle goes all in once the bell
##     is nearer than its capture can still be won (the walk, the fight, CAPTURE_TIME), not
##     at a fixed two minutes (it was still staging a wave with its count out of reach);
##   the INTERCEPT (focus_extra, dive_override): the holder marks the enemy leader near the
##     altar above all (the only one who can take it) and its assassins dive it; whoever
##     strikes our leader on the altar is peeled off;
##   the leader falls back to its healers at the front, and a little sooner;
##   (trials, off in the game, see `trial`: WAVES, the fallen coming back meeting at a join
##     point to go in four at a time - a third of all falls were of one walking in alone;
##     WALKERS, those walking up from far behind turning only on what is on them; the hurt
##     falling back to the guild's own body when no healer is at the front);
##   the fighters' own (GuildFighter.smart2): focus fire without overkill,
##     potions before a fall, the leader drinking and fighting back on the altar, idle
##     heals, stuns kept for a priority foe, area skills not spent on one foe, no skills on a
##     gate with foes near.
## It tells its orders in the war feed in a commander's voice (orders: ⚑ แผน ...), only
## when the phase or the war really changes, at most one every ORDER_GAP s and the same
## order not again within ORDER_REPEAT s; members acknowledge some of them. With the hero
## leading ours its words are a ที่ปรึกษา's advice and the player's own orders
## (GuildWarCommander.set_order) come first; the AI fills in the rest.
## Deterministic: its decisions read only the war (the wall clock only times its own cost
## for the measurement), its own dice seeded from the war's seed and the team.
## Cheap: one pass over the fighters a think (a few hundred distance checks for 80), and
## a pass over its own guild with the formation (every 0.5 s).

## Tools (the measurement's ablations, tests/tools/guild_war_sim SIM_OFF): rules switched
## off by name ("muster", "besiege", "wait", "exploit", "squads"; the second brain's
## "altar", "deadline", "intercept"); empty in the game.
## Trials: second-brain rules built, measured and kept OFF in the game (switched on by
## name, tests/tools/guild_war_sim SIM_TRIAL, tests): "waves" (_waves), "walkers"
## (_walkers), "bodyrear" (the hurt to the guild's body, back sooner). They cut the lone
## falls (one walking in alone: 67 a guild a war against 73) but kept members out of the
## fight; with them on the second brain won 50-56% of its wars against the first (28),
## without them 83% (12).
static var trial: Dictionary = {}
## (A leash, nobody chased farther than 20 m from its post, was measured and dropped: the
## guild playing it lost the trades, K/D 0.86 against 1.11, tests/tools/guild_war_sim.)
static var off: Dictionary = {}

## The doctrine as it stood before its second brain (the measurement's baseline,
## GuildWarMatch.next_base / tests/tools/guild_war_sim SIM_BASE): none of the rules marked
## "v2" below (smart2) run for it. False in the game.
var base := false


## Whether the second brain's rules run (every guild in the game's own wars).
func smart2() -> bool:
	return not base

const THINK_EVERY := 2.0
## What a leader at the front sees: fighters within this many metres of it.
const FRONT_RADIUS := 24.0
## The window: the guild it fights has at least this share of its fighters down or far
## from the front, and ours outweighs what stands there EXPLOIT_BALANCE times.
const EXPLOIT_SPENT := 0.45
const EXPLOIT_END := 0.3
const EXPLOIT_BALANCE := 1.3
const EXPLOIT_MAX := 25.0
## Outweighed at the front (ours / theirs under WAIT_BALANCE) with at least WAIT_COMING of
## ours down or on the way: pull back to the rally point until WAIT_RESUME, at most
## WAIT_MAX s, not again within WAIT_REST s.
const WAIT_BALANCE := 0.55
const WAIT_COMING := 0.3
const WAIT_MIN_FOES := 4
const WAIT_MAX := 25.0
const WAIT_REST := 15.0
## The wave goes with this share of the guild standing at the rally point.
const WAVE_READY := 0.7
const GATHER_RADIUS := 12.0
## With the gates down the wave stages in the last yard this far inside the second tier.
const STAGE_DEPTH := 10.0
## Whether to muster at the last gate for a reading `r` with that gate at `share` of its
## health (-1: it is not the front): nobody holds the castle, the guild is not taking or
## stopping a capture.
static func pick_muster(r: Dictionary, share: float) -> bool:
	if share < 0.0 or share > MUSTER_HP or int(r.get("owner", -1)) >= 0:
		return false
	return not bool(r.get("enemy_capturing", false))


## Whether to besiege (was `was`, `held` s) for a reading `r`, the commander's fading
## trade counts `trades` {loss, kill} and the window (`engage`): only against a holder
## with every gate down, never in the last minutes or the window.
static func pick_besiege(was: bool, held: float, r: Dictionary, trades: Dictionary, engage: bool) -> bool:
	var owner := int(r.get("owner", -1))
	if owner < 0 or bool(r.get("holding", false)) or bool(r.get("gates_up", true)) or engage or int(r.get("teams", 2)) > 2:
		return false
	if float(r.get("time_left", 9999.0)) <= float(r.get("last_at", LAST_CALL)) or bool(r.get("we_capturing", false)) or bool(r.get("enemy_capturing", false)):
		return false
	if was:
		return held < BESIEGE_MAX
	var loss := float(trades.get("loss", 0.0))
	return loss >= BESIEGE_LOSSES and float(trades.get("kill", 0.0)) < loss * BESIEGE_TRADE


## The last tier's gate's health share while it is the front (-1 otherwise).
func _last_gate_share() -> float:
	var g := war.front_gate()
	if g == null or g.tier < SiegeArena.GATE_Z.size() - 1:
		return -1.0
	return float(g.hp) / float(maxi(1, g.max_hp))


## Phase hysteresis: a calm phase is changed after two thinks or this long.
const PHASE_MIN := 6.0
## The race: muster at the last gate under MUSTER_HP of its health (nobody holds the
## castle), surge into the throne room for SURGE_TIME s once it falls.
const MUSTER_HP := 0.35
## Besieging: the waves lose the trades (falls taken at least BESIEGE_LOSSES, under
## BESIEGE_TRADE of them dealt back); it stays up to BESIEGE_MAX s (less in a window).
const BESIEGE_LOSSES := 6.0
const BESIEGE_TRADE := 0.5
const BESIEGE_MAX := 90.0
const SURGE_TIME := 20.0
## The last minutes of the war.
const LAST_CALL := 120.0
## Second brain: a guild not holding the castle goes all in once the bell is nearer than
## its capture can still be won: CAPTURE_TIME on the altar, the walk there (its leader's
## way to the altar at DEADLINE_PACE m/s) and DEADLINE_FIGHT s to clear it (last_call_at).
const DEADLINE_PACE := 6.0
const DEADLINE_FIGHT := 75.0
## Second brain's focus: the enemy leader in the throne room (the only one who can take the
## altar) for the castle's holder, and for anyone when it is this near the altar; whoever
## strikes our own leader on the altar (peel).
const INTERCEPT_BONUS := 40.0
const INTERCEPT_RADIUS := 34.0
const LEADER_IN_BONUS := 12.0
const PEEL_BONUS := 20.0
## Orders: at most one every ORDER_GAP s, the same key not within ORDER_REPEAT s (urgent
## ones every URGENT_REPEAT s); a member answers ACK_CHANCE of them.
const ORDER_GAP := 7.0
const ORDER_REPEAT := 30.0
const URGENT_REPEAT := 12.0
const ACK_CHANCE := 0.4
## Retreat thresholds by role (the old brain: GuildFighter.RETREAT_BELOW for all).
const RETREAT_SQUISHY := 0.33
const RETREAT_STURDY := 0.25
## Second brain: the leader's own (GuildWarCommander.LEADER_RETREAT for the old rules).
const LEADER_RETREAT2 := 0.42
## The called target: everyone's lean on it, on top of GuildFighter's own.
const FOCUS_BONUS := 6.0
## A support member under attack: foes within this many metres of it.
const PEEL_RADIUS := 6.0
## The support squad is the fall-back point only when within this far of the front.
const SUPPORT_REACH := 30.0

const PHASES := {
	"form": "จัดทัพ", "breach": "ทลายประตู", "exploit": "ฉวยจังหวะบุก", "wait": "ถอยรอกำลังเสริม",
	"assault": "บุกแท่น", "capture": "คุ้มกันการยึดแท่น",
	"hold": "ตั้งรับจุดคอขวด", "guard": "เฝ้าปราสาท", "stop": "สกัดการยึด", "counter": "สวนกลับ",
	"recover": "ถอยฟื้นพล", "vulture": "รอซ้ำเติม", "muster": "รวมพลหน้าประตูสุดท้าย", "besiege": "ล้อมรอจังหวะ",
}
## Phases that change at once (no hysteresis).
const URGENT: Array[String] = ["stop", "capture", "recover"]

const SQUAD_VANGUARD := "vanguard"
const SQUAD_BREAKERS := "breakers"
const SQUAD_SUPPORT := "support"
const SQUAD_RANGED := "ranged"
const SQUAD_HUNTERS := "hunters"
const SQUAD_GUARD := "guard"
const SQUAD_LEADER := "leader"
const SQUAD_NAMES := {
	"vanguard": "หน่วยแนวหน้า", "breakers": "หน่วยทำลาย", "support": "หน่วยสนับสนุน",
	"ranged": "หน่วยระยะไกล", "hunters": "หน่วยนักฆ่า",
	"guard": "หน่วยคุ้มกันหัวกิล", "leader": "หัวหน้ากิลด์",
}
const ACKS: Array[String] = ["รับทราบ!", "รับทราบ หัวหน้า", "ได้เลย ลุย!", "ตามแผนเลย", "จัดไป!", "โอเค ไปพร้อมกัน", "ไปกัน!"]

var team := 0
var war: GuildWarMatch
var commander: GuildWarCommander
var phase := ""
var phase_since := 0.0
var _candidate := ""
var clock := 0.0
var _think_left := 0.0
## The window (see the header) and since when; the end of the last wait.
var engage := false
var wait := false
var _window_since := 0.0
var _wait_ended := -1.0e9
var last_call := false
## When the last call comes (time left, s): LAST_CALL, or the second brain's deadline.
var last_at := LAST_CALL
## The race for the castle: mustering at the last gate, surging through it (until when).
var muster := false
## Besieging a holder that keeps beating the waves (see think), and since when.
var besiege := false
var _besiege_since := 0.0
var surge_until := -1.0e9
var _last_gate_seen := true
## The last reading (tests, the HUD): see read_field.
var field: Dictionary = {}
## Squads: instance id -> squad key; squad key -> its leader; squad key -> count.
var squad_of: Dictionary = {}
var squad_leads: Dictionary = {}
var squad_counts: Dictionary = {}
## Where the support squad stands at the front (INF: none near it).
var support_at := Vector3.INF
## The guild leading the war for us (points or the castle; -1 none), and the one we fight.
var leading_team := -1
var main_foe := -1
## Orders told (after the rate limit), the last few (tests), acknowledgements.
var orders_said := 0
var orders: Array[String] = []
var acks := 0
var _last_order := -1.0e9
var _order_at: Dictionary = {}
var _rng := RandomNumberGenerator.new()
## The measurement: thinks, and the slowest think in microseconds.
var thinks := 0
var peak_us := 0
var total_us := 0
## The squads' layout (apply, every 0.5 s): its total and count (the measurement).
var apply_us := 0
var applies := 0
## Events seen since the last think: tiers broken, our leader's falls, the castle.
var _tiers_seen := 0
var _leader_was_up := true
var _owner_seen := -1
var _peeled: Dictionary = {}
var _last_acker: GuildFighter


func _init(p_war: GuildWarMatch, p_team: int) -> void:
	war = p_war
	team = p_team
	_rng.seed = hash("gw_doctrine|%d|%d" % [p_war.roll_seed if p_war != null else 0, p_team])
	spread(2)


## The guilds think a share of a beat apart, and never in the same frame as their
## commanders (0.2 s + THINK_EVERY spread): `n` guilds.
func spread(n: int) -> void:
	_think_left = 0.95 + THINK_EVERY * float(team) / float(maxi(1, n))


func tick(delta: float) -> void:
	clock += delta
	_think_left -= delta
	if _think_left <= 0.0:
		_think_left = THINK_EVERY
		var t0 := Time.get_ticks_usec()
		think()
		var spent := int(Time.get_ticks_usec() - t0)
		peak_us = maxi(peak_us, spent)
		total_us += spent
		thinks += 1


## Think again within a beat (a gate fell, the castle changed hands, a capture began).
func nudge() -> void:
	_think_left = minf(_think_left, 0.25)


func _cmd() -> GuildWarCommander:
	if commander == null and war != null and team < war.commanders.size():
		commander = war.commanders[team]
	return commander


# ---------------------------------------------------------------------------
# Reading the field
# ---------------------------------------------------------------------------

## What a leader at the front of guild `team` knows now: per guild its standing, its
## strength at our front (power x health share of those within FRONT_RADIUS) and how
## many of it are down or far from the front; the balance (ours / the strongest other
## guild's at the front), the guild we fight (most strength at our front; the holder under
## the siege's focus) and how spent it is; the points and the clock.
func read_field() -> Dictionary:
	var c := _cmd()
	var at := objective_point()
	var n := war.team_count()
	var near_power: Array[float] = []
	var near_count: Array[int] = []
	var away: Array[int] = []
	var total: Array[int] = []
	near_power.resize(n)
	near_count.resize(n)
	away.resize(n)
	total.resize(n)
	near_power.fill(0.0)
	near_count.fill(0)
	away.fill(0)
	total.fill(0)
	var r2 := FRONT_RADIUS * FRONT_RADIUS
	var rally: Vector3 = c.rally if c != null else at
	var at_rally := 0
	var standing := 0
	for t in n:
		for f in war.side(t):
			total[t] += 1
			if f.is_dead():
				away[t] += 1
				continue
			var p := f.global_position
			var dx := p.x - at.x
			var dz := p.z - at.z
			var d2 := dx * dx + dz * dz
			if d2 <= r2:
				near_count[t] += 1
				near_power[t] += f.hp_ratio() * f.power
			elif d2 > 4.0 * r2:
				away[t] += 1
			if t == team:
				standing += 1
				if Vector2(p.x - rally.x, p.z - rally.z).length_squared() < GATHER_RADIUS * GATHER_RADIUS:
					at_rally += 1
	# The hero fights for ours (it counts where it stands).
	if not war.spectating() and war.hero_alive():
		var hp := war.hero.global_position
		if Vector2(hp.x - at.x, hp.z - at.z).length_squared() <= r2:
			near_count[0] += 1
			near_power[0] += war.hero_hp_ratio() * _hero_weight()
	var focus_on := war.castle_owner if war.castle_owner >= 0 and war.castle_owner != team else -1
	var foe := focus_on
	if foe < 0:
		var best := 0.0
		for t in n:
			if t != team and near_power[t] > best:
				best = near_power[t]
				foe = t
	var theirs := 0.0
	for t in n:
		if t != team and (focus_on < 0 or t == focus_on):
			theirs = maxf(theirs, near_power[t])
	var spent := 0.0
	if foe >= 0 and total[foe] > 0:
		spent = float(away[foe]) / float(total[foe])
	main_foe = foe
	leading_team = _leader_of_war()
	var mine := war._strength(team)
	return {
		"front": at,
		"near": near_count[team],
		"near_power": near_power[team],
		"foe": foe,
		"foe_near": near_count[foe] if foe >= 0 else 0,
		"foe_power": theirs,
		"balance": near_power[team] / maxf(theirs, 0.001) if theirs > 0.0 else 9.0,
		"foe_spent": spent,
		"coming": float(away[team]) / float(maxi(1, total[team])),
		"gathered": float(at_rally) / float(maxi(1, standing)),
		"alive_share": float(mine.x) / float(mine.y),
		"time_left": war.time_left,
		"holding": war.castle_owner == team,
		"owner": war.castle_owner,
		"gates_up": war.front_gate() != null,
		"enemy_capturing": not war.capture.is_empty() and int(war.capture.team) != team,
		"we_capturing": not war.capture.is_empty() and int(war.capture.team) == team,
		"tactic": c.tactic if c != null else "",
		"plan": String(war.plans[team]) if team < war.plans.size() else "",
		"waiting": c != null and c.waiting,
		"leading": leading_team,
		"teams": n,
		"last_at": last_at,
	}


## Where the guild's fight is: the gate it batters (its front), else the altar.
func objective_point() -> Vector3:
	var c := _cmd()
	var g: CastleGate = c.target_gate() if c != null else null
	if war.castle_owner == team:
		var front := war.front_gates()
		if not front.is_empty():
			return SiegeArena.gate_front(front[0].tier, front[0].lane)
		return SiegeArena.ALTAR
	if g != null:
		return SiegeArena.gate_front(g.tier, g.lane)
	return SiegeArena.ALTAR


## Where the guild stages a wave while waiting (with the gates down: the last yard, out of
## the throne room's reach; INF: the commander's own rally point).
func stage_point() -> Vector3:
	if war.front_gate() != null or war.castle_owner == team:
		return Vector3.INF
	var side: float = [-1.0, 1.0, -0.4, 0.4][team % 4] * 8.0
	return Vector3(side, 0.0, SiegeArena.GATE_Z[1] - STAGE_DEPTH)


## The hero's weight at the front: its guild's average fighter (its own strength is
## rated on another scale).
func _hero_weight() -> float:
	var sum := 0.0
	var n := 0
	for f in war.side(team):
		sum += f.power
		n += 1
	return sum / float(n) if n > 0 else 1.0


## Who leads the war now: the castle's holder, else the guild with the most war points
## (-1 when none is ahead of the rest).
func _leader_of_war() -> int:
	if war.castle_owner >= 0:
		return war.castle_owner
	var best := -1
	var pts := -1
	var tied := false
	for t in war.team_count():
		var p := war.war_points(t)
		if p > pts:
			pts = p
			best = t
			tied = false
		elif p == pts:
			tied = true
	return -1 if tied else best


# ---------------------------------------------------------------------------
# The decision (pure: the same reading always gives the same answer)
# ---------------------------------------------------------------------------

## The window after (`engage`, `wait`) held `held` s (`rested`: s since the last wait
## ended) for a reading `r`: [engage, wait].
static func pick_window(was_engage: bool, was_wait: bool, held: float, rested: float, r: Dictionary) -> Array:
	var bal := float(r.get("balance", 1.0))
	var spent := float(r.get("foe_spent", 0.0))
	var attacking := not bool(r.get("holding", false)) and not bool(r.get("enemy_capturing", false))
	var last := float(r.get("time_left", 9999.0)) <= float(r.get("last_at", LAST_CALL))
	# Exploit: their front is spent and ours outweighs what is left.
	var engage := false
	if attacking and float(r.get("alive_share", 1.0)) >= 0.55:
		if was_engage:
			engage = held < EXPLOIT_MAX and spent >= EXPLOIT_END and bal >= 1.0
		else:
			engage = spent >= EXPLOIT_SPENT and bal >= EXPLOIT_BALANCE
	# Wait: outweighed at the front with our own on the way (never in the last minutes,
	# never while taking the altar or stopping a capture).
	var wait := false
	# (Only in a war of two: with three others on the field every falls dealt is a point
	# and whoever stands back leaves the kills and the altar to the rest.)
	if attacking and not engage and not last and not bool(r.get("we_capturing", false)) and int(r.get("teams", 2)) <= 2:
		if was_wait:
			# The wave goes when most of the guild stands at the rally point (or after WAIT_MAX).
			wait = held < WAIT_MAX and not (float(r.get("gathered", 0.0)) >= WAVE_READY and float(r.get("alive_share", 0.0)) >= 0.6)
		else:
			wait = rested >= WAIT_REST and bal < WAIT_BALANCE and int(r.get("foe_near", 0)) >= WAIT_MIN_FOES and float(r.get("coming", 0.0)) >= WAIT_COMING
	return [engage, wait]


## The phase for a reading `r` with the window decided (r.engage / r.wait), from the
## commander's tactic and the guild's plan.
static func phase_for(r: Dictionary) -> String:
	var tactic := String(r.get("tactic", ""))
	var plan := String(r.get("plan", ""))
	if bool(r.get("enemy_capturing", false)):
		return "stop"
	if bool(r.get("we_capturing", false)):
		return "capture"
	if plan == "regroup" or tactic == GuildWarCommander.FALLBACK:
		return "recover"
	if bool(r.get("holding", false)):
		if bool(r.get("counter", false)):
			return "counter"
		return "hold" if bool(r.get("gates_up", false)) else "guard"
	if plan == "hold":
		return "hold"
	if bool(r.get("besiege", false)):
		return "besiege"
	if bool(r.get("wait", false)):
		return "wait"
	if bool(r.get("muster", false)) and bool(r.get("gates_up", true)):
		return "muster"
	if bool(r.get("engage", false)):
		return "exploit"
	if bool(r.get("gates_up", true)):
		return "form" if tactic == GuildWarCommander.GATHER or tactic == "" else "breach"
	if bool(r.get("waiting", false)):
		return "vulture"
	match tactic:
		GuildWarCommander.ESCORT, GuildWarCommander.GUARD:
			return "assault"
		GuildWarCommander.DEFEND:
			return "hold"
		GuildWarCommander.GATHER:
			return "form"
	return "assault"


## Phase hysteresis: `next` replaces `prev` (held `held` s) at once when urgent or when
## leaving an urgent one, else only when it was also the candidate of the think before or
## `prev` has stood PHASE_MIN s.
static func settle_phase(prev: String, held: float, candidate: String, next: String) -> String:
	if next == prev or prev == "":
		return next
	if next in URGENT or prev in URGENT:
		return next
	if candidate == next or held >= PHASE_MIN:
		return next
	return prev


## The plan the doctrine fights instead of `plan` (GuildWarMatch.plan_for's) for a reading:
## in the last minutes the holder stays round the altar (defend, or its gates), the others
## never pull back to regroup.
static func adjust_plan(plan: String, time_left: float, holding: bool, gates_up: bool, last := LAST_CALL) -> String:
	if time_left > last:
		return plan
	if holding:
		return "gates" if gates_up else "defend"
	if plan == "regroup" or plan == "hold":
		return "rush" if gates_up else "storm"
	return plan


## The squad for a fighter of commander role `role` (GuildWarCommander.ROLE_*), the
## leader's bodyguard or the leader itself.
static func squad_for(role: int, bodyguard: bool, is_lead: bool) -> String:
	if is_lead:
		return SQUAD_LEADER
	if bodyguard:
		return SQUAD_GUARD
	match role:
		GuildWarCommander.ROLE_TANK:
			return SQUAD_VANGUARD
		GuildWarCommander.ROLE_MELEE:
			return SQUAD_BREAKERS
		GuildWarCommander.ROLE_ASSASSIN:
			return SQUAD_HUNTERS
		GuildWarCommander.ROLE_RANGED:
			return SQUAD_RANGED
		GuildWarCommander.ROLE_HEALER, GuildWarCommander.ROLE_BARD:
			return SQUAD_SUPPORT
	return SQUAD_BREAKERS


## Retreat threshold for a fighter of `role`: the squishy back line falls back earlier.
static func retreat_for(role: int) -> float:
	if role in [GuildWarCommander.ROLE_RANGED, GuildWarCommander.ROLE_HEALER, GuildWarCommander.ROLE_BARD]:
		return RETREAT_SQUISHY
	return RETREAT_STURDY


# ---------------------------------------------------------------------------
# Thinking
# ---------------------------------------------------------------------------

func think() -> void:
	if war == null or not is_instance_valid(war) or _cmd() == null:
		return
	var r := read_field()
	var held := clock - _window_since
	var win := pick_window(engage, wait, held, clock - _wait_ended, r)
	if bool(win[0]) != engage or bool(win[1]) != wait:
		if wait and not bool(win[1]):
			_wait_ended = clock
		_window_since = clock
	engage = bool(win[0]) and not off.has("exploit")
	wait = bool(win[1]) and not off.has("wait")
	last_at = last_call_at() if smart2() and not off.has("deadline") else LAST_CALL
	r["last_at"] = last_at
	last_call = war.time_left <= last_at
	# The race for the castle (nobody holds it): the whole guild musters at the last gate
	# as it is about to fall, and surges through to the throne room the moment it does.
	muster = pick_muster(r, _last_gate_share()) and not off.has("muster")
	if muster:
		wait = false
	if war.front_gate() == null and _last_gate_seen and war.castle_owner < 0:
		surge_until = clock + SURGE_TIME if not off.has("muster") else surge_until
	_last_gate_seen = war.front_gate() != null
	var surging := clock < surge_until and war.castle_owner < 0 and not bool(r.holding)
	if surging:
		wait = false
	r["muster"] = muster
	# Besieging a holder: its waves keep failing (it loses the trades badly), so it stops
	# feeding the holder falls: it stays massed in the last yard (catching the holder's
	# fighters as they come out of the keep) until the holder's front is spent (the
	# window), the last minutes, or BESIEGE_MAX s, then tries a wave again.
	var trades := {"loss": commander.loss_heat, "kill": commander.kill_heat}
	var next_besiege := pick_besiege(besiege, clock - _besiege_since, r, trades, engage) and not off.has("besiege")
	if next_besiege != besiege:
		besiege = next_besiege
		_besiege_since = clock
	if besiege:
		wait = true
	r["besiege"] = besiege
	r["engage"] = engage
	r["wait"] = wait
	r["counter"] = bool(r.holding) and commander.counter_team >= 0 and float(r.foe_spent) >= EXPLOIT_SPENT
	field = r
	commander.hints = {"engage_now": engage or muster or surging, "hold_back": wait, "all_in": last_call and not bool(r.holding), "stage": stage_point() if wait else Vector3.INF}
	var next := phase_for(r)
	var settled := settle_phase(phase, clock - phase_since, _candidate, next)
	_candidate = next
	if settled != phase:
		var was := phase
		phase = settled
		phase_since = clock
		_announce_phase(was, r)
	assign_squads()
	_events(r)


## Second brain: when the last call comes (s left on the clock). Holding the castle
## LAST_CALL; else the time its capture still needs: CAPTURE_TIME, its leader's way to the
## altar (from its camp while it is down) and DEADLINE_FIGHT s to clear the altar, at
## least LAST_CALL.
func last_call_at() -> float:
	if war.castle_owner == team:
		return LAST_CALL
	var lead := war.ai_leader(team)
	var from: Vector3 = SiegeArena.camp(team)
	if lead != null and not lead.is_dead():
		from = lead.global_position
	elif team == GuildFighter.TEAM_ALLY and war.hero_leads() and war.hero_alive():
		from = war.hero.global_position
	var way := GuildWarCommander._flat(from, SiegeArena.ALTAR)
	if SiegeArena.section(from) < 2:
		way = GuildWarCommander._flat(from, SiegeArena.APPROACH) + GuildWarCommander._flat(SiegeArena.APPROACH, SiegeArena.ALTAR)
	return maxf(LAST_CALL, GuildWarMatch.CAPTURE_TIME + way / DEADLINE_PACE + DEADLINE_FIGHT)


## Every member's squad, each squad's leader (its strongest standing) and count.
func assign_squads() -> void:
	var c := _cmd()
	var lead := war.ai_leader(team)
	var guard: GuildFighter = c._bodyguard(war.side(team), lead) if lead != null and not lead.is_dead() else null
	squad_of.clear()
	squad_leads.clear()
	squad_counts.clear()
	var best: Dictionary = {}
	for f in war.side(team):
		var key := squad_for(c._role(f, lead), f == guard, f == lead)
		squad_of[f.get_instance_id()] = key
		squad_counts[key] = int(squad_counts.get(key, 0)) + 1
		if f.is_dead() or key == SQUAD_LEADER:
			continue
		var score := f.power * (0.5 + f.hp_ratio())
		if score > float(best.get(key, -1.0)):
			best[key] = score
			squad_leads[key] = f


func squad_name_of(f: GuildFighter) -> String:
	return String(SQUAD_NAMES.get(String(squad_of.get(f.get_instance_id(), "")), ""))


## How much more the guild wants `f` as its called target (GuildWarCommander._pick_focus):
## the guild leading the war (points or the castle), one busy with a third guild (it fights
## someone not ours: hit it from behind), one of the guild we fight.
func focus_extra(f: GuildFighter) -> float:
	var extra := 0.0
	if war.team_count() > 2:
		if leading_team >= 0 and leading_team != team and f.team == leading_team:
			extra += 6.0
		var v: Variant = f._victim
		if v is GuildFighter and is_instance_valid(v) and (v as GuildFighter).team != team:
			extra += 5.0
	if main_foe >= 0 and f.team == main_foe:
		extra += 2.0
	if smart2() and not off.has("intercept"):
		extra += _intercept_extra(f)
	return extra


## Second brain: the enemy leader near the altar with every gate down is the one to stop
## (INTERCEPT_BONUS for the castle's holder within INTERCEPT_RADIUS of the altar,
## LEADER_IN_BONUS for anyone in the throne room); whoever strikes our leader taking the
## altar is peeled off it (PEEL_BONUS).
func _intercept_extra(f: GuildFighter) -> float:
	var extra := 0.0
	if f.is_leader and war.front_gate() == null:
		var d := GuildWarCommander._flat(f.global_position, SiegeArena.ALTAR)
		if war.castle_owner == team and d < INTERCEPT_RADIUS:
			extra += INTERCEPT_BONUS
		elif SiegeArena.section(f.global_position) == 4:
			extra += LEADER_IN_BONUS
	var lead := war.ai_leader(team)
	if lead != null and not lead.is_dead() and (lead.capturing or lead.capture_role) and f._victim == lead:
		extra += PEEL_BONUS
	return extra


## Second brain: the assassins' mark when holding the castle: the enemy leader near the
## altar (null: the commander's own pick).
func dive_override() -> GuildFighter:
	if not smart2() or off.has("intercept") or war.castle_owner != team or war.front_gate() != null:
		return null
	var best: GuildFighter = null
	var best_d := INTERCEPT_RADIUS
	for t in war.team_count():
		if t == team:
			continue
		var lead := war.ai_leader(t)
		if lead == null or lead.is_dead() or lead.under_guard():
			continue
		var d := GuildWarCommander._flat(lead.global_position, SiegeArena.ALTAR)
		if d < best_d:
			best_d = d
			best = lead
	return best


## After the commander's layout (GuildWarCommander.apply, before the player's orders):
## the squads' own rules on every member: retreat thresholds by role and the fall-back
## point at the support squad, the called target's extra lean, the tanks peeling for a
## healer under attack.
func apply() -> void:
	if off.has("squads"):
		return
	var t0 := Time.get_ticks_usec()
	_apply()
	apply_us += int(Time.get_ticks_usec() - t0)
	applies += 1


func _apply() -> void:
	var c := _cmd()
	var side := war.side(team)
	var lead := war.ai_leader(team)
	# The support squad's middle at the front: where the hurt fall back to.
	var sum := Vector3.ZERO
	var n := 0
	var front: Vector3 = field.get("front", c.front())
	var supports: Array[GuildFighter] = []
	for f in side:
		if f.is_dead() or f.is_retreating() or f == lead:
			continue
		var r := c._role(f, lead)
		if r == GuildWarCommander.ROLE_HEALER or r == GuildWarCommander.ROLE_BARD:
			supports.append(f)
			if Vector2(f.global_position.x - front.x, f.global_position.z - front.z).length() < SUPPORT_REACH:
				sum += f.global_position
				n += 1
	support_at = Vector3(sum.x / float(n), 0.0, sum.z / float(n)) if n > 0 else Vector3.INF
	# Second brain: with no healer at the front the hurt fall back to the guild's own body
	# (a step behind its middle), not alone across the field to the far camp.
	var body_rear := _body_rear(side, lead, c) if smart2() and not support_at.is_finite() and trial.has("bodyrear") else Vector3.INF
	# Supports with a foe on them: the nearest standing tank (not the leader's bodyguard on
	# the altar run) goes to them.
	var threatened: Array[GuildFighter] = []
	if not supports.is_empty():
		var foes := war.foes_of(team)
		for s in supports:
			for e in foes:
				if not e.is_dead() and e._victim == s and Vector2(e.global_position.x - s.global_position.x, e.global_position.z - s.global_position.z).length() < PEEL_RADIUS:
					threatened.append(s)
					break
	_peeled.clear()
	for s in threatened:
		var tank: GuildFighter = null
		var best := 1.0e9
		for f in side:
			if f.is_dead() or f.capture_role or f == lead or _peeled.has(f.get_instance_id()) or c._role(f, lead) != GuildWarCommander.ROLE_TANK:
				continue
			var d := Vector2(f.global_position.x - s.global_position.x, f.global_position.z - s.global_position.z).length()
			if d < best and d < 16.0:
				best = d
				tank = f
		if tank != null:
			_peeled[tank.get_instance_id()] = true
			tank.guard_node = s
	for f in side:
		var r := c._role(f, lead)
		f.retreat_below = retreat_for(r) if f != lead else GuildWarCommander.LEADER_RETREAT
		if f == lead and smart2() and not f.capture_role:
			# Second brain: the leader (the only one who can take the castle) falls back a
			# little sooner, to its healers at the front rather than the far camp.
			f.retreat_below = LEADER_RETREAT2
			if support_at.is_finite() and not f.rear_point.is_finite():
				f.rear_point = support_at
		f.focus_bonus = FOCUS_BONUS
		f.clump_aware = true
		# The hurt fall back to the support squad at the front, not the far camp (the
		# support squad itself, and the leader, as before).
		if f != lead and support_at.is_finite() and r != GuildWarCommander.ROLE_HEALER and r != GuildWarCommander.ROLE_BARD and not f.rear_point.is_finite():
			f.rear_point = support_at
		if body_rear.is_finite() and not f.rear_point.is_finite() and GuildWarCommander._flat(f.global_position, body_rear) < GuildWarCommander._flat(f.global_position, war.home_of(team)):
			f.rear_point = body_rear
	if smart2() and trial.has("walkers"):
		_walkers(side, front)
	if smart2() and trial.has("waves"):
		_waves(side, lead, front)


## Second brain: the members walking back from far behind (farther than WALKER_FAR m from the
## guild's objective, out of the camp, not falling back) fight only what is on them
## (WALK_HOLD m) and keep walking: the old rule had them turn on anyone of the other guild
## they met on the plaza (with no hold range, anyone within 48 m), and they fell there one
## by one (traced: a holder's members dying on the plaza while its altar was being taken).
const WALKER_FAR := 55.0
const WALK_HOLD := 6.0


func _walkers(side: Array[GuildFighter], front: Vector3) -> void:
	var c := _cmd()
	for f in side:
		if f.is_dead() or f.capture_role or f.is_retreating() or f.keep_back:
			continue
		if GuildWarCommander._flat(f.global_position, front) < WALKER_FAR or c._in_camp(f):
			continue
		if f.hold_range <= 0.0 or f.hold_range > WALK_HOLD:
			f.hold_range = WALK_HOLD


## Second brain: waves, not a trickle. The members coming back from a fall (standing, out
## of the fight: farther than STRAGGLE m from the guild's objective) meet at a join point
## out of the fight (join_point) and go in together once WAVE_N of them are there, after
## JOIN_MAX s, or at once while the guild holds the field there (WAVE_MAIN of its own at the
## objective, at least as many as the foes; fewer than WAVE_FOES foes there) or while it
## cannot wait (another guild's capture running, the last call). Only in a fight (the tactics push, escort, guard, defend): gathering and
## falling back have their own rally point.
const STRAGGLE := 42.0
const MAIN_RADIUS := 24.0
const WAVE_N := 4
const WAVE_MAIN := 6
## Fewer foes than this at the objective: no fight there to be fed, everyone goes on.
const WAVE_FOES := 3
const JOIN_RADIUS := 9.0
const JOIN_MAX := 12.0
const JOIN_BACK := 34.0
const JOIN_CONTESTED := 2
## The wave held at the join point (ids -> true), since when it waits, and the join point;
## the members sent in with a wave (ids -> until when they are left to go on).
var _joining: Dictionary = {}
var _released: Dictionary = {}
const RELEASE_TIME := 30.0
var _join_since := -1.0
var join_at := Vector3.INF
## Waves sent in (the measurement, tests).
var waves_sent := 0


func _waves(side: Array[GuildFighter], lead: GuildFighter, front: Vector3) -> void:
	var c := _cmd()
	join_at = Vector3.INF
	# (The holder behind its standing gates comes back from its keep right behind them.)
	if not (c.tactic in [GuildWarCommander.PUSH, GuildWarCommander.ESCORT, GuildWarCommander.GUARD, GuildWarCommander.DEFEND]) or (war.castle_owner == team and war.front_gate() != null):
		_joining.clear()
		return
	# The last call and another guild's capture running cannot wait (measured: waves of
	# four held back while the count ran fed the capturer's whole guard all the same and
	# lost the castle); ours running, the guild holds the field round its leader.
	var urgent := last_call or (not war.capture.is_empty() and int(war.capture.get("team", -1)) != team)
	var join_max := JOIN_MAX
	var main := 0
	var stragglers: Array[GuildFighter] = []
	for f in side:
		var id := f.get_instance_id()
		if f.is_dead() or f.capture_role:
			_released.erase(id)
			continue
		var d := GuildWarCommander._flat(f.global_position, front)
		if _released.has(id) and (d < MAIN_RADIUS or clock > float(_released[id])):
			_released.erase(id)
		if d < MAIN_RADIUS:
			main += 1
		elif _released.has(id):
			continue
		elif d > STRAGGLE and not f.is_retreating() and not c._in_camp(f) or d > STRAGGLE and c._in_camp(f) and f.hp_ratio() > 0.95:
			stragglers.append(f)
	var foes := 0
	for e in war.foes_of(team):
		if not e.is_dead() and GuildWarCommander._flat(e.global_position, front) < MAIN_RADIUS:
			foes += 1
	if urgent or stragglers.is_empty() or foes < WAVE_FOES or (main >= WAVE_MAIN and main >= foes):
		for f in stragglers:
			_released[f.get_instance_id()] = clock + RELEASE_TIME
		_joining.clear()
		_join_since = -1.0
		return
	var at := join_point(front)
	var contested := 0
	for e in war.foes_of(team):
		if not e.is_dead() and GuildWarCommander._flat(e.global_position, at) < JOIN_RADIUS + 5.0:
			contested += 1
	if contested >= JOIN_CONTESTED:
		for f in stragglers:
			_released[f.get_instance_id()] = clock + RELEASE_TIME
		_joining.clear()
		_join_since = -1.0
		return
	join_at = at
	var there := 0
	for f in stragglers:
		if GuildWarCommander._flat(f.global_position, at) < JOIN_RADIUS:
			there += 1
	if there > 0 and _join_since < 0.0:
		_join_since = clock
	var go := there >= WAVE_N or (_join_since >= 0.0 and clock - _join_since >= join_max)
	if go:
		waves_sent += 1
		for f in stragglers:
			if GuildWarCommander._flat(f.global_position, at) < JOIN_RADIUS:
				_released[f.get_instance_id()] = clock + RELEASE_TIME
		_joining.clear()
		_join_since = -1.0
		order("wave", "ครบแล้ว! %d คนบุกพร้อมกัน ตามไปที่แนวหน้า" % there)
		return
	var k := 0
	for f in stragglers:
		_joining[f.get_instance_id()] = true
		f.objective = null
		f.keep_front = Vector3.INF
		f.hold_range = JOIN_RADIUS
		f.goal_point = GuildWarMatch._spot(at, k, 2.5)
		k += 1


## A step (BODY_BACK m) behind the middle of the guild's standing members out of the camp
## (not falling back), INF with fewer than BODY_MIN of them.
const BODY_MIN := 3
const BODY_BACK := 6.0


func _body_rear(side: Array[GuildFighter], lead: GuildFighter, c: GuildWarCommander) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for f in side:
		if f.is_dead() or f.is_retreating() or f.capture_role or c._in_camp(f):
			continue
		sum += f.global_position
		n += 1
	if n < BODY_MIN:
		return Vector3.INF
	var mid := Vector3(sum.x / float(n), 0.0, sum.z / float(n))
	var front: Vector3 = field.get("front", mid)
	return GuildWarCommander._in_bounds(c._back_along(mid, front, BODY_BACK))


## Where a wave meets: outside the throne room's door for the altar, else JOIN_BACK m
## back from the guild's objective along its way home.
func join_point(front: Vector3) -> Vector3:
	var c := _cmd()
	var side_x: float = [-1.0, 1.0, -0.4, 0.4][team % 4] * 6.0
	if GuildWarCommander._flat(front, SiegeArena.ALTAR) < 20.0:
		return Vector3(side_x, 0.0, SiegeArena.GATE_Z[2] + 12.0)
	return GuildWarCommander._in_bounds(c._back_along(front, front, JOIN_BACK))


# ---------------------------------------------------------------------------
# Orders
# ---------------------------------------------------------------------------

func _advisor() -> bool:
	return team == GuildFighter.TEAM_ALLY and not war.spectating() and war.hero_leads()


## Tells the guild its order (the war feed, over the leader's head): `urgent` ones may come
## sooner than ORDER_GAP. The commander's own callouts wait CALL_GAP after it. True when said.
func order(key: String, text: String, urgent := false) -> bool:
	var repeat := URGENT_REPEAT if urgent else ORDER_REPEAT
	if _order_at.has(key) and clock - float(_order_at[key]) < repeat:
		return false
	if not urgent and clock - _last_order < ORDER_GAP:
		return false
	if war.state != "fight":
		return false
	_last_order = clock
	_order_at[key] = clock
	var line := ("⚑ แนะนำ: " if _advisor() else "⚑ ") + text
	orders_said += 1
	orders.append(line)
	if orders.size() > 16:
		orders.remove_at(0)
	war.tactical_call(team, line)
	var c := _cmd()
	if c != null:
		# One voice for the guild: the commander's own callouts wait, and the order is
		# among what the guild said (GuildWarCommander.said).
		c._last_call = c.clock
		c.calls += 1
		c.said.append(line)
		if c.said.size() > 12:
			c.said.remove_at(0)
	_ack()
	return true


## Now and then a member answers the order in the feed (one, by the doctrine's own dice).
func _ack() -> void:
	if _rng.randf() >= ACK_CHANCE:
		return
	var lead := war.ai_leader(team)
	var up: Array[GuildFighter] = []
	for f in war.side(team):
		if not f.is_dead() and f != lead:
			up.append(f)
	if up.is_empty():
		return
	var who := up[_rng.randi() % up.size()]
	if who == _last_acker and up.size() > 1:
		who = up[(up.find(who) + 1) % up.size()]
	_last_acker = who
	acks += 1
	war.feed.emit("%s: %s" % [who.shown_name(), ACKS[_rng.randi() % ACKS.size()]], team)


func _place() -> String:
	return commander.place_name() if commander != null else ""


func _gate_text() -> String:
	var g := commander.target_gate() if commander != null else null
	if g == null:
		return "ประตู"
	return CastleGate.gate_label(g.tier, g.lane)


## The order for a new phase, with what each squad does.
func _announce_phase(_was: String, r: Dictionary) -> void:
	var foe := int(r.get("foe", -1))
	var foe_name := war.team_name(foe) if foe >= 0 else "ศัตรู"
	match phase:
		"form":
			order("form", "แผน: จัดทัพที่%s แทงค์หน้า ฮีลหลัง ครบแล้วบุก" % _place())
		"breach":
			if commander.split:
				order("breach", "แผน: แบ่งตีประตูซ้าย-ขวาพร้อมกัน ฮีลตามหลัง")
			else:
				order("breach", "แผน: ทลาย%s แทงค์นำ หน่วยทำลายตาม ฮีลอยู่หลัง" % _gate_text())
		"exploit":
			order("exploit", "เปลี่ยนแผน! %s ล้มไป %d%% บุกเดี๋ยวนี้!" % [foe_name, int(float(r.get("foe_spent", 0.0)) * 100.0)])
		"wait":
			order("wait", "ถอยรอพล! หน้าแนว %d:%d รวมที่%s อย่าบุกทีละคน" % [int(r.get("near", 0)), int(r.get("foe_near", 0)), _place()])
		"assault":
			order("assault", "แผน: บุกแท่น สายดาเมจนำ หัวกิลตามติด ฮีลประกบหัวกิล")
		"capture":
			order("capture", "หัวกิลยึดแท่น! ล้อมแท่น ขวางประตูห้องบัลลังก์", true)
		"stop":
			var who := int(war.capture.get("team", -1))
			order("stop", "ด่วน! %s ยึดแท่น สตันหัวกิลมัน ล้มให้ได้" % (war.team_name(who) if who >= 0 else "ศัตรู"), true)
		"hold":
			order("hold", "แผน: ตั้งรับที่%s แทงค์ขวางคอขวด คนเจ็บถอยหาฮีล" % _place())
		"guard":
			order("guard", "แผน: เฝ้าปราสาท ล้อมแท่น ขวางประตูห้องบัลลังก์ ผลัดคนเจ็บ")
		"counter":
			order("counter", "สวนกลับ! %s หมดแรงแล้ว ไล่ตีแล้วกลับมา" % war.team_name(commander.counter_team if commander.counter_team >= 0 else foe))
		"recover":
			order("recover", "ถอย! รวมพลที่%s รอเพื่อนเกิดก่อน" % _place(), true)
		"besiege":
			order("besiege", "ล้อมรอจังหวะ! อย่าบุกทีละคน รวมที่ลานชั้นใน ดักคนของ %s ที่ออกมา" % foe_name)
		"muster":
			order("muster", "ประตูสุดท้ายใกล้พัง! รวมที่%s พังแล้วบุกแท่นพร้อมกัน" % _gate_text())
		"vulture":
			var pair := commander.busy_pair()
			if pair.size() == 2:
				order("vulture", "รอจังหวะ! ให้ %s กับ %s ซัดกันก่อน" % [war.team_name(pair[0]), war.team_name(pair[1])])


## The war's turns: a tier broken, our leader down or back, the castle changing hands, the
## last minutes.
func _events(r: Dictionary) -> void:
	var open := 0
	for k in SiegeArena.GATE_Z.size():
		if war.tier_open(k):
			open += 1
	if open > _tiers_seen:
		_tiers_seen = open
		if not bool(r.holding):
			if open >= SiegeArena.GATE_Z.size():
				order("tier", "ประตูสุดท้ายพัง! บุกห้องบัลลังก์ สายดาเมจนำ หัวกิลตามติดขึ้นแท่น", true)
			else:
				order("tier", "ประตูชั้น %d พัง! เดินหน้ารวมที่%s" % [open, _place()], true)
		else:
			order("tier", "ประตูชั้น %d ของเราพัง! ถอยตั้งรับชั้นถัดไป" % open, true)
	var lead := war.ai_leader(team)
	var up := lead != null and not lead.is_dead()
	if lead != null and _leader_was_up and not up and war.front_gate() == null and not bool(r.holding):
		order("lead_down", "หัวกิลล้ม! รวมพลรอหัวกิล อย่าบุกทีละคน", true)
	_leader_was_up = up
	if war.castle_owner != _owner_seen:
		_owner_seen = war.castle_owner
		if war.castle_owner == team:
			order("owner", "ยึดปราสาทได้! ล้อมแท่นไว้ แทงค์คุมประตูห้องบัลลังก์", true)
		elif war.castle_owner >= 0:
			order("owner", "%s ยึดปราสาทไป! รวมพลแล้วชิงคืน" % war.team_name(war.castle_owner), true)
	if last_call and not _order_at.has("last"):
		if bool(r.holding):
			order("last", "เหลือ 2 นาที! เฝ้าแท่นจนหมดเวลา", true)
		elif war.castle_owner >= 0:
			order("last", "เหลือ 2 นาที! ห้ามถอย บุกชิงปราสาท", true)
		else:
			order("last", "เหลือ 2 นาที! ห้ามถอย บุกยึดแท่น", true)


## Ours on the HUD: the phase's name ("" before the first think).
func phase_name() -> String:
	return String(PHASES.get(phase, ""))
