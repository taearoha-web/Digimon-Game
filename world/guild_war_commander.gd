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
##             to come back, then go again.
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
const TACTIC_NAMES := {
	"gather": "รวมพล", "push": "บุกพร้อมกัน", "escort": "คุ้มกันหัวหน้าไปยึดแท่น",
	"guard": "คุ้มกันหัวหน้า", "defend": "ตั้งรับ", "fallback": "ถอยรวมตัวใหม่",
}

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
			if int(s.escort) >= int(s.escort_need) or (prev == GATHER and held >= GATHER_MAX):
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
			callout("escort", "คุ้มกันหัวหน้าไปยึดแท่น!")
			_buff_up(front(), 18.0)
		GUARD:
			callout("guard", "คุ้มกันหัวหน้า!")
		DEFEND:
			if bool(s.enemy_capturing):
				callout("stop", "หยุดคนบนแท่น! ทุกคนเข้าแท่น!")
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
	if tactic == "":
		return
	var side := _side()
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
	_counts.fill(0)
	_index.fill(0)
	for f in side:
		if not f.is_dead() and not f.capture_role:
			_counts[_role(f, ai_lead)] += 1
	var capturing_foe := war.capturer() != null and int(war.capture.get("team", team)) != team
	for f in side:
		var r := _role(f, ai_lead)
		f.focus = focus
		f.dive = dive if f.role == ROLE_ASSASSIN else null
		f.guard_node = lead if f.role == ROLE_TANK else null
		if f.is_dead() or f.capture_role:
			continue
		var i := _index[r]
		_index[r] += 1
		var depth := -1.0
		if f == ai_lead and f.hp_ratio() < 0.45:
			depth = LEADER_BACK
		match tactic:
			GATHER, FALLBACK:
				f.objective = null
				f.hold_range = 12.0 if tactic == GATHER else 8.0
				f.goal_point = slot(at, fwd, r, i, _counts[r], depth)
			PUSH:
				if war.front_gate() != null:
					f.goal_point = slot(at, fwd, r, i, _counts[r], depth)
			ESCORT, GUARD:
				f.objective = null
				f.hold_range = 11.0
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
