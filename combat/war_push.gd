class_name WarPush
extends RefCounted
## Skills that move their targets (a knock-back away from the caster or the blast, a pull
## that gathers them in) also move enemy PLAYERS in the player-versus-player wars: in a
## guild war (GuildWarMatch) and in the maze war (MazeMatch). Elsewhere players hold their
## ground as before (rivals and guild fighters are flagged is_boss so the monsters' knocks
## leave them be; the duel arena keeps its rules).
##
## What moves a player (the same distances as on a monster):
##   repel  fx "repel": thrown out until its edge stands Mob.REPEL_DISTANCE from the caster
##          (Mob.shove_out);
##   pull   fx "pull" (the Dark Lord's Imperial Judgment): drawn in until its edge stands
##          Mob.PULL_DISTANCE from the caster (Mob.pull_in);
##   kick   fx "kick" (the Muay Thai fighter's kicks and throws, MuayThai.kick): thrown that
##          many metres; a body on the guild war altar always lands clear of the yellow
##          circle (its capture count pauses, banked: GuildWarMatch._tick_capture).
## The limits:
##   - allies are never moved by their own side (team_of), nor one under its spawn guard or
##     in a maze shrine's shelter;
##   - diminishing returns: a player moved is not moved again for IMMUNE_MS (no chain-push);
##   - the slide is cut short where it would leave the field (its round edge), go into the
##     moat, through a castle wall or a gate still standing (SiegeArena's sections: a join is
##     crossed only through the bridge or an open gate), past the throne room's walls, out
##     of the maze or into a maze shrine; the walls' colliders stop it besides;
##   - nobody ends below the floor: the slide runs on the bodies' own collision (up and down
##     the grand staircase's ramps), the hero's is set on SiegeArena.floor_y if it sank
##     (SiegeLift does the same for every body in the zone);
##   - a short stagger: a fighter is held (Mob._stun) for the slide and STAGGER more, the hero
##     cannot move or cast for as long (Hero._cast_until).
## Fighters slide on their own velocity (Mob._physics_process slows it by DECAY m/s each
## second), the hero on a Slide node. Nothing here is random: a seeded war plays the same.

const NONE := 0
const SIEGE := 1
const MAZE := 2
## After a push the player cannot be pushed again for this long (game ms).
const IMMUNE_MS := 2000
## Held this long after the slide (s).
const STAGGER := 0.3
## The slide slows by this much each second (Mob._physics_process's 12 m/s per second).
const DECAY := 12.0
## The way is checked in steps this long.
const STEP := 0.25
## Kept this far inside the field's round edge.
const EDGE := 1.5
## Kept this far from a castle wall's line (its inner face is 1.7 m off it: SiegeArena's
## walls are 3.4 m thick) and from a gate opening's jambs (GATE_HALF off its middle).
const WALL_GAP := 2.2
const JAMB_GAP := 0.5
const META := &"war_push_until"

## Counters (tests, the sim): pushes made, pushes refused by the immunity.
static var pushes := 0
static var refused := 0


## Which war the push happens in (NONE: elsewhere, nothing moves a player).
static func context(attacker: Variant, victim: Variant) -> int:
	if GuildWarMatch.in_war():
		return SIEGE
	if victim is MazeFighter or attacker is MazeFighter:
		return MAZE
	return NONE


## A body this module moves: a war fighter run here (not another game's mirror) or the hero.
static func movable(victim: Variant) -> bool:
	if victim == null or not is_instance_valid(victim):
		return false
	return (victim is GuildFighter and not (victim is MirrorFighter)) or victim is Hero


## Whether a push of [param victim] by [param attacker] is this module's to make.
static func handles(attacker: Variant, victim: Variant) -> bool:
	return movable(victim) and context(attacker, victim) != NONE


## The side a unit fights for (-1 unknown: then it is nobody's ally).
static func team_of(unit: Variant) -> int:
	if unit == null or not is_instance_valid(unit):
		return -1
	if unit is GuildFighter:
		return (unit as GuildFighter).team
	if unit is Hero or unit is Companion:
		return GuildFighter.TEAM_ALLY
	if unit is Summon:
		return team_of((unit as Summon).summoner)
	if unit is SummonMob:
		return team_of((unit as SummonMob).caster)
	return -1


static func _radius_of(victim: Node3D) -> float:
	return (victim as Mob).body_radius() if victim is Mob else 0.4


## Whether the victim may not be moved now (dead, its own side, guarded, sheltered, immune).
static func _held(attacker: Variant, victim: Node3D) -> bool:
	if victim is Mob and (victim as Mob).is_dead():
		return true
	if victim is Hero and (victim as Hero).is_dead():
		return true
	var side := team_of(attacker)
	if side >= 0 and side == team_of(victim):
		return true
	if victim is GuildFighter and (victim as GuildFighter).under_guard():
		return true
	if victim is MazeFighter and (victim as MazeFighter).protected():
		return true
	if victim is Hero and attacker is MazeFighter:
		var maze: MazeMatch = (attacker as MazeFighter).maze
		if maze != null and is_instance_valid(maze) and maze.shields(victim):
			return true
	return false


## Whether [param victim] was pushed less than IMMUNE_MS ago.
static func immune(victim: Object) -> bool:
	return victim != null and GameClock.msec() < int(victim.get_meta(META, -1))


## Moves [param victim] [param metres] along [param dir] (flat), cut short by the arena's
## limits. Returns the distance it will slide (0 when it does not move).
static func push(attacker: Variant, victim: Node3D, dir: Vector3, metres: float) -> float:
	var ctx := context(attacker, victim)
	if ctx == NONE or not movable(victim) or metres <= 0.0 or _held(attacker, victim):
		return 0.0
	if immune(victim):
		refused += 1
		return 0.0
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = Vector3(0, 0, 1)
	dir = dir.normalized()
	var dist := safe_distance(ctx, victim.global_position, dir, metres)
	victim.set_meta(META, GameClock.msec() + IMMUNE_MS)
	pushes += 1
	var speed := sqrt(2.0 * DECAY * dist)
	var slide_s := speed / DECAY
	if victim is GuildFighter:
		var fighter := victim as GuildFighter
		fighter.velocity.x = dir.x * speed
		fighter.velocity.z = dir.z * speed
		fighter._stun = maxf(fighter._stun, slide_s + STAGGER)
	elif victim is Hero:
		var hero := victim as Hero
		for old in hero.get_children():
			if old is Slide:
				old.queue_free()
		hero._cast_until = maxi(hero._cast_until, Time.get_ticks_msec() + int((slide_s + STAGGER) * 1000.0))
		if dist > 0.0:
			var slide := Slide.new()
			slide.name = "WarPushSlide"
			slide.body = hero
			slide.dir = dir
			slide.speed = speed
			slide.left = dist
			slide.siege = ctx == SIEGE
			hero.add_child(slide)
	return dist


## Thrown out until its edge stands [param radius] from [param center] (Mob.shove_out).
static func repel(attacker: Variant, victim: Node3D, center: Vector3, radius: float) -> float:
	var dir := victim.global_position - center
	dir.y = 0.0
	var gap := radius + _radius_of(victim) - dir.length()
	if gap <= 0.0:
		return 0.0
	return push(attacker, victim, dir, gap)


## Drawn in until its edge stands [param radius] from [param center] (Mob.pull_in).
static func pull(attacker: Variant, victim: Node3D, center: Vector3, radius: float) -> float:
	var dir := center - victim.global_position
	dir.y = 0.0
	var gap := dir.length() - radius - _radius_of(victim)
	if gap <= 0.0:
		return 0.0
	return push(attacker, victim, dir, gap)


## Thrown [param metres] away from [param from] (MuayThai.kick): one on the guild war altar
## goes clear of the yellow circle the shortest way, however it was struck.
static func kick(attacker: Variant, victim: Node3D, from: Vector3, metres: float) -> float:
	var dir := victim.global_position - from
	dir.y = 0.0
	var dist := metres
	if context(attacker, victim) == SIEGE and SiegeArena.on_altar(victim.global_position):
		var off := victim.global_position - SiegeArena.ALTAR
		off.y = 0.0
		if off.length() > 0.25:
			dir = off
		dist = maxf(dist, SiegeArena.ALTAR_RADIUS - off.length() + MuayThai.ALTAR_CLEAR)
	return push(attacker, victim, dir, dist)


## A skill's displacement on a player struck by [param attacker] (Rival._hit): its pull or
## its repel, from where the attacker stands. The kick goes through MuayThai.skill_fx.
static func skill_fx(attacker: Node3D, victim: Variant, fx: Dictionary) -> void:
	if not handles(attacker, victim):
		return
	if fx.has("pull"):
		pull(attacker, victim as Node3D, attacker.global_position, Mob.PULL_DISTANCE)
	elif fx.has("repel"):
		repel(attacker, victim as Node3D, attacker.global_position, Mob.REPEL_DISTANCE)


## How far of [param metres] a body at [param start] may slide along [param dir] (flat,
## unit) and stay where a player can stand.
static func safe_distance(ctx: int, start: Vector3, dir: Vector3, metres: float) -> float:
	var q := Vector3(start.x, 0.0, start.z)
	var q_ok := _inside(ctx, q)
	var went := 0.0
	while went < metres - 0.0001:
		var step := minf(STEP, metres - went)
		var p := q + dir * step
		if not _step_ok(ctx, q, p, q_ok):
			break
		went += step
		q = p
	return went


## Whether a point lies inside its part of the arena (the castle's walls, the maze's edge).
static func _inside(ctx: int, p: Vector3) -> bool:
	if ctx == MAZE:
		return absf(p.x) <= MazeLayout.HALF - EDGE and absf(p.z) <= MazeLayout.HALF - EDGE
	match SiegeArena.section(p):
		0:
			return true
		1:
			return p.z > SiegeArena.MOAT_NORTH or absf(p.x) <= SiegeArena.HALL_HALF - WALL_GAP
		2, 3:
			return absf(p.x) <= SiegeArena.HALL_HALF - WALL_GAP
		_:
			return absf(p.x) <= SiegeArena.THRONE_HALF - WALL_GAP and p.z >= SiegeArena.BACK_Z + WALL_GAP


## One step of the slide from `q` to `p`: never off the field, into the moat or a shrine,
## through a wall or a standing gate (the castle's rules hold only for a body that stood
## where they apply: `q_ok`).
static func _step_ok(ctx: int, q: Vector3, p: Vector3, q_ok: bool) -> bool:
	if ctx == MAZE:
		if absf(p.x) > MazeLayout.HALF - EDGE or absf(p.z) > MazeLayout.HALF - EDGE:
			return false
		return MazeLayout.safe_at(p) < 0 or MazeLayout.safe_at(q) >= 0
	if Vector2(p.x, p.z).length() > SiegeArena.RADIUS - EDGE and not SiegeArena.hall_rect().has_point(Vector2(p.x, p.z)):
		return false
	if SiegeArena.in_moat(p):
		return false
	if not q_ok:
		return true
	if not _inside(ctx, p):
		return false
	var a := SiegeArena.section(q)
	var b := SiegeArena.section(p)
	if a == b:
		return true
	if absi(a - b) > 1:
		return false
	# Through the join between the two sections: the bridge, or a gate already broken.
	var j := mini(a, b)
	if j == 0:
		return absf(p.x) <= SiegeArena.BRIDGE_HALF - JAMB_GAP
	var tier := j - 1
	for lane in SiegeArena.TIER_LANES[tier]:
		if absf(p.x - SiegeArena.gate_x(tier, lane)) <= SiegeArena.GATE_HALF - JAMB_GAP and SiegeArena.is_open(j, lane):
			return true
	return false


## The hero's slide: `left` metres along `dir`, slowing by DECAY m/s each second, on the
## hero's own collision (walls stop it, the ramps carry it up and down), never below the
## floor or in the moat.
class Slide:
	extends Node
	var body: CharacterBody3D
	var dir := Vector3.ZERO
	var speed := 0.0
	var left := 0.0
	var siege := false

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(body) or left <= 0.0 or (body is Hero and (body as Hero).is_dead()):
			queue_free()
			return
		var step := minf(maxf(speed, 1.0) * delta, left)
		left -= step
		speed = maxf(0.0, speed - DECAY * delta)
		var hit := body.move_and_collide(dir * step)
		if hit != null:
			var rest := hit.get_remainder().slide(hit.get_normal())
			if rest.length_squared() > 0.000001:
				body.move_and_collide(rest)
			# Against a wall (not a ramp): the slide ends there.
			if hit.get_normal().y < 0.3:
				left = 0.0
		if siege:
			var p := body.global_position
			if SiegeArena.in_moat(p):
				body.global_position = SiegeArena.out_of_moat(p)
				left = 0.0
			elif p.y < SiegeArena.floor_y(p) - 0.25:
				body.global_position.y = SiegeArena.floor_y(p)
		if left <= 0.0:
			queue_free()
