class_name MazeFighter
extends GuildFighter
## A world player fighting for real in เขาวงกตหนึ่งในใต้หล้า (MazeMatch): its own gear,
## level, stars and skills (WorldPlayers.fighter, like a guild war's fighter), in a
## free-for-all: every fighter is a team of its own (MazeMatch gives each its own team
## number past TEAM_ALLY), so the hero, every other fighter and every real player are its
## foes. How it plays (a person in a deathmatch, not a monster):
## - it hunts: it walks the maze (MazeLayout.route, cell to cell) towards a goal cell of
##   its own, picks a fight with whom it meets, the weak and the hurt first, and leaves a
##   much stronger one alone unless that one comes for it (avoid stronger players);
## - an ambusher (some players by name) waits at a corner by a plaza gate for whoever
##   walks past instead of roaming;
## - hurt (below its own flee line) it runs for the nearest shrine (ที่หลบภัย) by the
##   maze's ways, drinks on the run, heals there and goes out again before its shelter
##   runs out (MazeWar.SAFE_MAX);
## - in a shrine it is untouchable and strikes nobody; one leaving a shrine is guarded
##   for SAFE_LEAVE seconds and strikes nobody yet; one just come back from a fall is
##   guarded for SPAWN_GUARD seconds (GuildFighter's guard).

## Where a fighter waits out of the way once it fell (and spawn_point after a respawn:
## the guild war's camp heal never starts in the maze).
const FAR := Vector3(0, -500.0, 0)
## The share of players who wait in ambush rather than roam.
const AMBUSH_SHARE := 0.25
## A foe this many times stronger is left alone unless it comes for this fighter.
const AVOID_RATIO := 1.6
const SIGHT := 26.0

var maze: MazeMatch
## The roster index of the world player (WorldPlayers), -1 none.
var world_index := -1
## Its fight power (GuildWarData.power_of), for sizing up a foe.
var power := 1.0
var ambusher := false
## The HP share under which it runs for a shrine (its own nerve: 0.25-0.45).
var flee_below := 0.35
## The shrine it is in (-1 none), how long this visit has lasted, the shrines that will
## not take it again until a time (msec), and until when its leaving guard lasts (msec).
var shrine := -1
var shrine_time := 0.0
var _shrine_cool := {}
var _leave_until := 0
var _maze_goal := -1
var _maze_wait := 0.0
var _aim_shrine := -1


func setup_maze(info: Dictionary, p_team: int, p_hero: Node3D, at: Vector3, p_maze: MazeMatch) -> void:
	maze = p_maze
	world_index = int(info.get("world", -1))
	power = maxf(1.0, float(info.get("power", 1.0)))
	setup_fighter(info, p_team, p_hero, at, "")
	rival_name = String(info.member.name)
	template["name"] = rival_name
	var who := String(info.member.name)
	ambusher = float(hash("maze_ambush|%s" % who) % 1000) / 1000.0 < AMBUSH_SHARE
	flee_below = lerpf(0.25, 0.45, float(hash("maze_nerve|%s" % who) % 1000) / 999.0)
	spawn_point = FAR


func _ready() -> void:
	super._ready()
	_label.text = shown_name()
	_label.modulate = Color("ffd6a0")
	# The crown holder (MazeCrown.holder): its title in gold over its name.
	var crown := MazeCrown.holder(MazeWar.now())
	if not crown.is_empty() and not bool(crown.get("hero", false)) and String(crown.get("name", "")) == rival_name:
		_label.text = "%s\n%s" % [MazeCrown.TITLE_NAME, shown_name()]
		_label.modulate = MazeWar.COLOR
	_label.visibility_range_end = 40.0
	start_fight()


func shown_name() -> String:
	return String(member.name)


# --- Shrines and guards -------------------------------------------------------------

## Untouchable now: in a shrine whose blessing still holds for it, just out of one, or
## just back from a fall.
func protected() -> bool:
	return sheltered() or GameClock.msec() < _leave_until or under_guard()


## In a shrine's circle with its blessing on (MazeWar.SAFE_MAX a visit).
func sheltered() -> bool:
	return shrine >= 0 and shrine_time < MazeWar.SAFE_MAX


## May strike now (not sheltered, not in its leaving guard).
func can_strike() -> bool:
	return not sheltered() and GameClock.msec() >= _leave_until


func _update_shrine(delta: float) -> void:
	var now := GameClock.msec()
	var k := MazeLayout.safe_at(global_position)
	if k >= 0 and int(_shrine_cool.get(k, 0)) > now:
		# Its blessing for this player is spent: it stands there like anywhere else.
		k = -1
	if k != shrine:
		if shrine >= 0 and k < 0:
			_leave_until = now + int(MazeWar.SAFE_LEAVE * 1000.0)
			if shrine_time >= MazeWar.SAFE_MAX:
				_shrine_cool[shrine] = now + int(MazeWar.SAFE_COOLDOWN * 1000.0)
		shrine = k
		shrine_time = 0.0
	if shrine >= 0:
		shrine_time += delta
		if shrine_time >= MazeWar.SAFE_MAX:
			_shrine_cool[shrine] = now + int(MazeWar.SAFE_COOLDOWN * 1000.0)
			shrine = -1
			_leave_until = 0
		elif hp < max_hp:
			hp = mini(max_hp, hp + int(ceil(float(max_hp) * MazeWar.SAFE_REGEN * delta)))
			mp = minf(float(rstats.max_mp), mp + float(rstats.max_mp) * MazeWar.SAFE_REGEN * delta)
			_bar.set_ratio(float(hp) / float(max_hp))


func take_hit(amount: int, crit: bool, color := Color.WHITE, attacker: Node = null) -> bool:
	if protected():
		if visual.visible and not _dead:
			BattleVfx.floating_text(get_parent(), top_point(), "ป้องกัน", Color("9ff7ff"), 0.8)
		return false
	return super.take_hit(amount, crit, color, attacker)


func take_damage(raw: float, attacker: Node = null) -> void:
	if protected():
		return
	super.take_damage(raw, attacker)


## Strikes only out of the shrines (an area blow cast before stepping in lands nowhere).
func _hit(victim: Node3D, mult: float, color: Color, fx := {}) -> void:
	if not can_strike() or (maze != null and maze.shields(victim)):
		return
	super._hit(victim, mult, color, fx)


func _physics_process(delta: float) -> void:
	if not _dead:
		_update_shrine(delta)
	super._physics_process(delta)


func respawn() -> void:
	spawn_point = maze.spawn_for(self) if maze != null else global_position
	super.respawn()
	spawn_point = FAR
	shrine = -1
	shrine_time = 0.0
	_leave_until = 0
	_maze_goal = -1
	_aim_shrine = -1


func _start_guard() -> void:
	_guard_until = GameClock.msec() + int(MazeWar.SPAWN_GUARD * 1000.0)


func _in_own_camp(t: Node3D) -> bool:
	return maze != null and maze.shields(t)


# --- Picking a fight ----------------------------------------------------------------

## The foe to go for: one in sight (SIGHT, by the maze's ways not too far round), not in a
## shrine nor guarded; the hurt and the weak first, the one it already fights and the one
## that just hit it kept; a much stronger one left alone unless it is on this fighter.
func _nearest_victim() -> Node3D:
	if not can_strike() and sheltered():
		return null
	var best: Node3D = null
	var best_score := -1.0e9
	var ratio := hp_ratio()
	if ratio < flee_below:
		# Running for a shrine: only what blocks the way, right in front of it.
		return _victim if _up(_victim) and _flat_distance(_victim.global_position) < 3.0 else null
	var here := MazeLayout.cell_at(global_position)
	for seen in _foes():
		if not _up(seen):
			continue
		var t := seen as Node3D
		var d := _flat_distance(t.global_position)
		if d > SIGHT:
			continue
		if maze != null and maze.shields(t):
			continue
		# Walls between: only a foe a few cells round counts.
		var cells := MazeLayout.steps(here, MazeLayout.cell_at(t.global_position))
		if cells > 3:
			continue
		var on_me := t == _last_attacker and _grudge > 0.0
		var theirs := maze.power_of(t) if maze != null else power
		if theirs > power * AVOID_RATIO and not on_me and t != _victim:
			continue
		var score := -d - float(cells) * 4.0
		var their_ratio := 1.0
		if t is GuildFighter:
			their_ratio = (t as GuildFighter).hp_ratio()
		elif t == hero and "stats" in hero:
			their_ratio = float(Game.profile.hp) / maxf(float(hero.stats.max_hp), 1.0)
		score += (1.0 - their_ratio) * 10.0
		score += clampf((power / maxf(theirs, 1.0) - 1.0) * 4.0, -6.0, 6.0)
		if t == _victim:
			score += 5.0
		if on_me:
			score += 6.0
		if score > best_score:
			best_score = score
			best = t
	return best


# --- Moving ---------------------------------------------------------------------------

func _chase_on(target: Node3D, delta: float, speed_factor: float) -> Vector3:
	var dodge_step := _dodge_area(delta)
	if dodge_step != Vector3.ZERO:
		return dodge_step
	if hp_ratio() < flee_below and not sheltered():
		return _fall_back(delta)
	if not can_strike():
		return _wander_on(delta)
	if maze != null and maze.shields(target):
		return _wander_on(delta)
	if not MazeLayout.direct(global_position, target.global_position):
		return _run_to(MazeLayout.route(global_position, target.global_position), delta)
	return _fight(target, delta, speed_factor)


## The fight itself (Rival's way: potions and skills by its own clock, ranged ones keep
## their distance, melee ones circle a little between swings).
func _fight(target: Node3D, delta: float, _speed_factor: float) -> Vector3:
	var to := target.global_position - global_position
	to.y = 0.0
	var distance := to.length()
	var now := GameClock.msec()
	if to.length_squared() > 0.01:
		_yaw = lerp_angle(_yaw, atan2(to.x, to.z), 1.0 - exp(-12.0 * delta))
		visual.rotation.y = _yaw
	if _frozen or duel_over:
		return Vector3.ZERO
	_tick(delta)
	if now < _cast_until:
		return Vector3.ZERO
	var attack: Dictionary = class_data.attack
	var ranged := float(attack.range) > 5.0
	var reach := float(attack.range) * 0.85 + (float(target.call("body_radius")) if target.has_method("body_radius") else 0.0)
	var speed := float(rstats.speed) * lerpf(0.85, 1.05, difficulty) * (0.5 if _slow > 0.0 else 1.0)
	var dir := to.normalized() if distance > 0.01 else Vector3.ZERO
	_think -= delta
	if _think <= 0.0 and _may_think():
		_think = lerpf(0.55, 0.18, difficulty)
		if _try_potion():
			return Vector3.ZERO
		if _try_skill(target, distance):
			return Vector3.ZERO
	if ranged:
		var keep := lerpf(4.5, 7.5, difficulty)
		if distance < keep:
			# Back off along the corridor (sideways when a wall is behind).
			var away := -dir
			if not MazeLayout.direct(global_position, global_position + away * 3.0):
				away = Vector3(-dir.z, 0, dir.x) * _strafe
			return away * speed * 0.95
		if distance > reach:
			return dir * speed
	elif distance - 0.4 > reach:
		return dir * speed
	if _attack_timer <= 0.0:
		_basic_attack(target)
		return Vector3.ZERO
	if not ranged and difficulty > 0.35:
		_strafe_timer -= delta
		if _strafe_timer <= 0.0:
			_strafe_timer = randf_range(0.9, 2.2)
			_strafe = -_strafe
		return Vector3(-dir.z, 0, dir.x) * _strafe * speed * 0.5
	return Vector3.ZERO


## Hurt: to the nearest shrine whose blessing still takes it, by the maze's ways, drinking
## on the run.
func _fall_back(delta: float) -> Vector3:
	_tick(delta)
	if _aim_shrine < 0 or int(_shrine_cool.get(_aim_shrine, 0)) > GameClock.msec():
		_aim_shrine = _pick_shrine()
	_think -= delta
	if _think <= 0.0:
		_think = 0.3
		_try_potion()
	if _aim_shrine < 0:
		return _wander_on(delta)
	var goal := MazeLayout.safe_center(_aim_shrine)
	if _flat_distance(goal) < 1.5:
		return Vector3.ZERO
	return _step_to(MazeLayout.route(global_position, goal), delta, 1.05)


func _pick_shrine() -> int:
	var here := MazeLayout.cell_at(global_position)
	var best := -1
	var best_d := 1 << 30
	var now := GameClock.msec()
	for k in MazeLayout.safe_count():
		if int(_shrine_cool.get(k, 0)) > now:
			continue
		var sc: Vector2i = MazeLayout.SAFE_CELLS[k]
		var d := MazeLayout.steps(here, sc.y * MazeLayout.CELLS + sc.x)
		if d < best_d:
			best_d = d
			best = k
	return best


## Nobody to fight: out of a shrine once healed (or before its blessing runs out), else
## to its goal cell (a roamer picks cells far off, an ambusher a corner by a plaza gate
## and waits there).
func _wander_on(delta: float) -> Vector3:
	if _frozen:
		return Vector3.ZERO
	_tick(delta)
	if sheltered():
		var healed := hp_ratio() > 0.92 or shrine_time > MazeWar.SAFE_MAX - 5.0
		if not healed:
			return Vector3.ZERO
		if _maze_goal < 0 or MazeLayout.is_safe_cell(_maze_goal):
			_maze_goal = _new_goal()
	var here := MazeLayout.cell_at(global_position)
	if _maze_goal < 0 or (here == _maze_goal and _flat_distance(MazeLayout.center(_maze_goal)) < 2.0):
		if _maze_goal >= 0 and ambusher:
			_maze_wait -= delta
			if _maze_wait > 0.0:
				return Vector3.ZERO
		_maze_goal = _new_goal()
		_maze_wait = randf_range(8.0, 20.0)
	return _step_to(MazeLayout.route(global_position, MazeLayout.center(_maze_goal)), delta, 0.9)


func _new_goal() -> int:
	var here := MazeLayout.cell_at(global_position)
	for attempt in 12:
		var c := randi() % MazeLayout.cell_count()
		if MazeLayout.is_safe_cell(c):
			continue
		if ambusher:
			# A corner by a plaza: a cell next to a plaza's gate with a turn in it.
			if MazeLayout.exits(c).size() < 2 or MazeLayout.steps(here, c) > 12:
				continue
			var near_plaza := false
			for nb in MazeLayout.exits(c):
				if MazeLayout.plaza_of[nb] >= 0:
					near_plaza = true
			if not near_plaza and attempt < 10:
				continue
		elif MazeLayout.steps(here, c) < 4:
			continue
		return c
	return randi() % MazeLayout.cell_count()


func _step_to(point: Vector3, delta: float, pace: float) -> Vector3:
	var to := point - global_position
	to.y = 0.0
	if to.length_squared() > 0.01:
		_yaw = lerp_angle(_yaw, atan2(to.x, to.z), 1.0 - exp(-10.0 * delta))
		visual.rotation.y = _yaw
	if GameClock.msec() < _cast_until or to.length() < 0.3:
		return Vector3.ZERO
	return to.normalized() * float(rstats.speed) * pace


func _run_to(point: Vector3, delta: float) -> Vector3:
	_tick(delta)
	return _step_to(point, delta, 1.0)
