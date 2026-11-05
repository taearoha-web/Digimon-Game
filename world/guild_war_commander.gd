class_name GuildWarCommander
extends RefCounted
## One guild's war chief in the castle siege (GuildWarMatch keeps one per side, and both
## sides run this same brain, so neither plays smarter by design). The guild's plan
## (GuildWarMatch.plan_for: rush, hold, regroup, storm, split, defend, forward) says where
## the war is fought; the commander says how, every THINK_EVERY seconds of war time:
##   gather   (รวมพล)  wait for the guild at a rally point before a gate or the throne room,
##             instead of trickling in one by one, then push together, buffed;
##   push     (บุก)    hit the gate together, tanks in front, ranged and healers behind;
##   escort   (คุ้มกัน) the leader goes for the altar inside its guard (an AI leader only
##             once enough of its guild stands round it; with the hero leading ours they
##             follow the hero, with a member picked to lead it they escort that member);
##   guard    (ป้องกันหัวหน้า) the leader is taking the altar or is hurt: tanks peel the
##             attackers off it, healers stay at its side;
##   defend   (ตั้งรับ) the other guild is taking the altar (everyone at the one on it) or
##             the plan is to hold a line;
##   fallback (ถอย)    a lost fight: pull back to the last rally point, wait for the fallen
##             to come back, then go again;
##   secure   (ยึดสวิตช์) the gates are down but the guild does not hold both castle
##             switches: its switch squads go for them while the rest wait with the leader
##             inside the throne room's door; with both held (or after SECURE_MAX s) the
##             leader is escorted onto the altar and waits there for the barrier to fall.
## The castle assault (SiegeArena.SWITCHES, GuildWarMatch.barrier_up) runs beside the
## tactic: with the gates down a guild posts switch squads (_plan_switches): to take them
## (sturdy ones: a tank and a healer each) while it goes for the altar, one more at once
## to retake a switch lost while its leader is on the altar, one more (a damage dealer)
## on a switch the other guild stands in; while securing, the main body rolls from one
## switch it lacks to the other (secure_k) to clear it; to contest them (damage
## dealers to kill the holders: one enemy inside and the switch is not held) while it
## holds the castle, two each while the other guild takes the altar. While the leader is
## on the altar half of the tanks and fighters screen the throne room's door.
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
## Switch squads: at most SQUAD_MAX per switch, one per SQUAD_SHARE of the guild standing.
const SQUAD_MAX := 3
const SQUAD_SHARE := 5

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


func _init(p_war: GuildWarMatch, p_team: int) -> void:
	war = p_war
	team = p_team
	# The two guilds think half a beat apart, never in the same frame.
	_think_left = 0.2 + THINK_EVERY * 0.5 * float(p_team)


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
	if plan in ["defend", "forward", "hold"]:
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
	if tactic == ESCORT or tactic == GUARD:
		return true
	return tactic == DEFEND and war.capture.has("team") and int(war.capture.team) != team


func think(dt: float) -> void:
	if war == null or not is_instance_valid(war):
		return
	var fade := exp(-dt / HEAT_MEMORY)
	loss_heat *= fade
	kill_heat *= fade
	if not _cc.is_empty():
		for id in _cc.keys():
			if float(_cc[id]) <= clock:
				_cc.erase(id)
	_place()
	var s := read()
	last_read = s
	var next := pick_tactic(tactic, since, s)
	if next != tactic:
		_switch(next, s)
	_plan_switches(s)
	var before := focus
	focus = _pick_focus()
	dive = _pick_dive()
	if focus != null and focus != before:
		_call_focus(focus)


func _switch(next: String, s: Dictionary) -> void:
	var was := tactic
	tactic = next
	since = 0.0
	match next:
		GATHER:
			callout("gather", "ทุกคนรวมพลที่%s!" % place_name())
		PUSH:
			if bool(s.gates_up):
				callout("push", "บุก! ตีประตูพร้อมกัน!")
			_buff_up(rally, 18.0)
		ESCORT:
			if was == SECURE and int(s.get("switches", 0)) >= 2:
				callout("escort", "ยึดสวิตช์ครบ! คุ้มกันหัวกิลเข้าห้องแท่น!")
			else:
				callout("escort", "คุ้มกันหัวหน้าไปยึดแท่น!")
			_buff_up(front(), 18.0)
		SECURE:
			callout("secure", "แบ่งทีมยึดสวิตช์ซ้ายและขวา! หัวกิลรอที่ประตูห้องบัลลังก์")
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
	var toward := -1.0 if team == GuildFighter.TEAM_ALLY else 1.0
	var gate := war.front_gate()
	secure_k = _pick_secure() if gate == null else -1
	if gate != null:
		var k := gate.gate_index
		forward = Vector3(0, 0, -1)
		if k == 0:
			rally = Vector3(toward * 8.0, 0, 0.0)
			fallback_point = SiegeArena.PLAZA + Vector3(toward * 16.0, 0, 6.0)
		else:
			rally = Vector3(toward * 5.0, 0, SiegeArena.GATE_Z[k] + 12.0)
			# Just inside the gate broken last, the far end of the same yard.
			fallback_point = Vector3(toward * 5.0, 0, SiegeArena.GATE_Z[k - 1] - 6.0)
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
		var score := 3 if war.switch_contested[k] else (2 if war.switch_owner[k] == 1 - team else 1)
		if score > best_score:
			best_score = score
			best = k
	return best


func place_name() -> String:
	var gate := war.front_gate()
	if gate == null:
		return "หน้าห้องบัลลังก์"
	return ["หัวสะพาน", "ประตูสอง", "ประตูสาม"][clampi(gate.gate_index, 0, 2)]


func leader() -> Node3D:
	return war.leader_of(team)


func _alive_leader() -> Node3D:
	var lead := leader()
	if lead == null or not is_instance_valid(lead) or bool(lead.call("is_dead")):
		return null
	return lead


func _side() -> Array[GuildFighter]:
	return war.allies if team == GuildFighter.TEAM_ALLY else war.enemies


func _foes() -> Array[GuildFighter]:
	return war.enemies if team == GuildFighter.TEAM_ALLY else war.allies


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Where the guild's front is: the gate front while pushing a gate, else the rally point.
func front() -> Vector3:
	var gate := war.front_gate()
	if tactic == PUSH and gate != null:
		return SiegeArena.gate_front(gate.gate_index)
	var lead := _alive_leader()
	if (tactic == ESCORT or tactic == GUARD) and lead != null:
		return lead.global_position
	if tactic == DEFEND:
		var who := war.capturer()
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
	var gate := war.front_gate()
	var front_at := SiegeArena.gate_front(gate.gate_index) if gate != null else rally
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
	var enemies_at_rally := 0
	for f in _foes():
		if f.is_dead():
			continue
		if _flat(f.global_position, rally) < 16.0:
			enemies_at_rally += 1
		if lead != null and _flat(f.global_position, lead.global_position) < 10.0:
			threat += 1
	if team == GuildFighter.TEAM_ENEMY and lead != null and war.hero_alive() and _flat(war.hero.global_position, lead.global_position) < 10.0:
		threat += 1
	var capture := war.capture
	var lead_hp := 1.0
	if lead is GuildFighter:
		lead_hp = (lead as GuildFighter).hp_ratio()
	elif lead == war.hero:
		lead_hp = war.hero_hp_ratio()
	return {
		"plan": war.plans[team] if war.plans[team] != "" else war.plan_for(team),
		"gates_up": gate != null,
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
		"foe_switches": war.switches_held(1 - team),
		"leader_on_altar": lead != null and SiegeArena.on_altar(lead.global_position),
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
		# Whoever holds a switch for the other guild (killing it brings the barrier back
		# for them, or opens it for us).
		if f.switch_post >= 0 and SiegeArena.on_switch(f.global_position, f.switch_post):
			score += 14.0
		if score > best_score:
			best_score = score
			best = f
	if team == GuildFighter.TEAM_ENEMY and war.hero_alive():
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
	if team == GuildFighter.TEAM_ENEMY and hero_kind != KIND_OTHER and (hero_kind != KIND_LEADER or _escorts(war.hero) <= 1):
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
	var side := war.enemies if team == GuildFighter.TEAM_ALLY else war.allies
	for f in side:
		if f != who and not f.is_dead() and _flat(f.global_position, who.global_position) < 8.0:
			n += 1
	return n


## Someone of the other guild standing in its own camp (nobody chases it there).
func _in_camp(who: Node3D) -> bool:
	var their_camp := Vector3(SiegeArena.BASE_X * (1.0 if team == GuildFighter.TEAM_ALLY else -1.0), 0, SiegeArena.BASE_Z)
	return _flat(who.global_position, their_camp) < SiegeArena.CAMP_RADIUS


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
	if bool(s.holding):
		base = 2 if bool(s.enemy_capturing) else 1
	else:
		base = clampi(standing / SQUAD_SHARE, 1, 2)
	var waiting := bool(s.we_capturing) or bool(s.get("leader_on_altar", false))
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
	while out[0] + out[1] > maxi(2, standing / 2) and (out[0] > 1 or out[1] > 1):
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
		fought.append(war.switch_pin < 0 and (war.switch_contested[k] or war.switch_owner[k] == 1 - team))
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
	var at := front()
	var fwd := forward
	if tactic == ESCORT and lead != null:
		var to := SiegeArena.ALTAR - lead.global_position
		to.y = 0.0
		fwd = to.normalized() if to.length() > 1.5 else Vector3(0, 0, 1)
		at = lead.global_position + fwd * 2.5
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
	var rolling := screen and not contesting and secure_k >= 0 and war.switches_held(team) < 2
	var roll_at: Vector3 = SiegeArena.SWITCHES[secure_k] if rolling else Vector3.ZERO
	var roll_fwd := (roll_at - SiegeArena.ALTAR).normalized() if rolling else Vector3.FORWARD
	var capturing_foe := war.capturer() != null and int(war.capture.get("team", team)) != team
	for f in side:
		var r := _role(f, ai_lead)
		f.focus = focus
		f.dive = dive if f.role == ROLE_ASSASSIN else null
		f.guard_node = lead if f.role == ROLE_TANK else null
		if f.is_dead() or f.capture_role:
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
				f.hold_range = 11.0
				if rolling and f != ai_lead and i % 3 != 0:
					f.hold_range = 12.0
					f.goal_point = slot(roll_at, roll_fwd, r, i, _counts[r], depth)
				elif screen and f != ai_lead and (r == ROLE_TANK or r == ROLE_MELEE) and i % 2 == 1:
					f.hold_range = 10.0
					f.goal_point = slot(door, Vector3(0, 0, 1), r, i / 2, maxi(1, _counts[r] / 2))
				else:
					f.goal_point = slot(at, fwd, r, i, _counts[r], depth)
			DEFEND:
				if capturing_foe:
					f.objective = null
					f.hold_range = 0.0
					f.goal_point = war.capturer().global_position
		# The AI leader never charges in alone: it keeps to its place behind the tanks.
		if f == ai_lead and tactic != DEFEND:
			f.hold_range = 8.0 if depth < 0.0 else 5.0


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
