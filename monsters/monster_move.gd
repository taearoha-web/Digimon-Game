class_name MonsterMove
extends Node
## Runs one StarMoves plan for an ordinary or elite monster of the star regions or
## the lotus sanctum (StarAttack / DivineAttack hand their non-boss attacks here).
## Same contract as the other enemy attacks: every warning is drawn and locked when
## the move starts, an actor takes one hit per wave and at most StarMoves.MAX_HITS
## a move, and stun, death or a leash reset before the last blow cancels what has
## not landed. The online cast (EntitySync) carries circles that cover each shape.

const RECOVER := 0.3

var mob: Mob
var move := ""
var elite := false
var style := "dawn"
var plan: Dictionary
var parts: Array = []
var landed: Array[bool] = []
var age := 0.0
var first_impact := 99.0
var last_impact := 0.0
var released := false
var warned: Node3D
var warns: Array = []
var hit_counts := {}
var hit_waves := {}
var hazards: Array[Dictionary] = []
var flights: Array[Dictionary] = []
## The circles this move sent (or would send) to the online party.
var sync_circles: Array = []
var _base_y := 0.0
var _lifted := false


## Starts the move of [param actor]'s template; false when it has none (bosses
## keep their own attacks). [param cooldown]: the monster's next attack timer.
static func start(actor: Mob, cooldown := 2.4) -> bool:
	if actor.is_boss or not StarMoves.knows(actor.template):
		return false
	if not actor._alive(actor._victim):
		return true
	var m := MonsterMove.new()
	m.name = "MonsterMove"
	m.mob = actor
	m.move = String(actor.template.behavior)
	actor._winding = true
	actor._attack_timer = cooldown
	actor.add_child(m)
	return true


func _ready() -> void:
	var template: Dictionary = mob.template
	elite = bool(template.get("elite", false))
	style = StarMoves.style_of(template)
	var origin := mob.global_position * Vector3(1, 0, 1)
	var hero_pos := (mob._victim as Node3D).global_position * Vector3(1, 0, 1)
	var forward := hero_pos - origin
	forward = forward.normalized() if forward.length_squared() > 0.01 else Vector3(sin(mob._yaw), 0, cos(mob._yaw))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	plan = StarMoves.plan(move, elite, origin, forward, hero_pos, mob.body_radius(), rng)
	parts = plan.parts
	landed.resize(parts.size())
	landed.fill(false)
	for part in parts:
		first_impact = minf(first_impact, float(part.at))
		last_impact = maxf(last_impact, float(part.at))
	warned = Node3D.new()
	warned.name = "StarMoveWarnings"
	mob.get_parent().add_child(warned)
	for part in parts:
		warns.append(MoveFx.telegraph(warned, part))
	for shot in plan.get("shots", []):
		flights.append({"shot": shot, "node": null, "from": Vector3.ZERO})
	sync_circles = StarMoves.sync_circles(parts)
	var title := StarMoves.title(template) if elite else ""
	if EntitySync.hosting():
		EntitySync.cast(mob, sync_circles, "attack", title)
	if title != "":
		BattleVfx.floating_text(mob.get_parent(), mob.top_point() + Vector3(0, 0.9, 0), title, StarMoves.palette(style)[0], 1.0)
	mob.visual.flash(Color(1.0, 0.3, 0.2), first_impact)
	mob.visual.action("attack", int((last_impact + 0.4) * 1000.0))
	mob._anim_lock = GameClock.msec() + int((last_impact + 0.4) * 1000.0)
	_base_y = mob.visual.position.y


func _process(delta: float) -> void:
	if not is_instance_valid(mob) or mob.is_dead() or mob._returning:
		queue_free()
		return
	if age < last_impact and mob._stun > 0.0:
		queue_free()
		return
	age += delta
	_motion(delta)
	for i in warns.size():
		if not landed[i] and is_instance_valid(warns[i]):
			(warns[i] as MoveFx.Warn).show_progress(age / maxf(float(parts[i].at), 0.05))
	_fly()
	for i in parts.size():
		if not landed[i] and age >= float(parts[i].at):
			landed[i] = true
			if is_instance_valid(warns[i]):
				(warns[i] as Node).queue_free()
			_land(parts[i])
	if not released and age >= last_impact + RECOVER:
		_release()
	_tick_hazards()
	if released and hazards.is_empty():
		queue_free()


func _exit_tree() -> void:
	if is_instance_valid(warned):
		warned.queue_free()
	if is_instance_valid(mob):
		if _lifted:
			mob.visual.position.y = _base_y
		if not released:
			mob._winding = false


func _release() -> void:
	released = true
	mob._winding = false
	if _lifted:
		mob.visual.position.y = _base_y
		_lifted = false


## Dashes along the lane and leaps in an arc onto the locked spot.
func _motion(delta: float) -> void:
	var dash: Dictionary = plan.get("dash", {})
	if not dash.is_empty() and age > float(dash.t0) and age <= float(dash.t1) + delta:
		_slide_to(dash.to, float(dash.t1), delta)
	var leap: Dictionary = plan.get("leap", {})
	if leap.is_empty():
		return
	var hop := -1.0
	if age > float(leap.t0) and age <= float(leap.t1) + delta:
		_slide_to(leap.to, float(leap.t1), delta)
		hop = clampf((age - float(leap.t0)) / (float(leap.t1) - float(leap.t0)), 0.0, 1.0)
	elif leap.has("to2") and age > float(leap.t2) and age <= float(leap.t3) + delta:
		_slide_to(leap.to2, float(leap.t3), delta)
		hop = clampf((age - float(leap.t2)) / (float(leap.t3) - float(leap.t2)), 0.0, 1.0)
	if hop >= 0.0:
		_lifted = true
		mob.visual.position.y = _base_y + sin(hop * PI) * float(leap.height)
	elif _lifted:
		mob.visual.position.y = _base_y
		_lifted = false


func _slide_to(to: Vector3, until: float, delta: float) -> void:
	var gap := (to - mob.global_position) * Vector3(1, 0, 1)
	var left := maxf(until - age, delta)
	mob.move_and_collide((gap / left * delta).limit_length(26.0 * delta))


## Projectiles leave the monster when their flight starts and land with their part.
func _fly() -> void:
	for f in flights:
		var shot: Dictionary = f.shot
		if age < float(shot.t0):
			continue
		if f.node == null:
			f.node = MoveFx.shot_body(warned, String(shot.kind), style)
			f.from = mob.hit_point()
		var node := f.node as Node3D
		if not is_instance_valid(node):
			continue
		var t := clampf((age - float(shot.t0)) / maxf(float(shot.t1) - float(shot.t0), 0.05), 0.0, 1.0)
		var to: Vector3 = (shot.to as Vector3) + Vector3(0, 0.3, 0)
		var from: Vector3 = f.from
		var p := from.lerp(to, t) + Vector3(0, sin(t * PI) * float(shot.arc), 0)
		if p.distance_squared_to(node.global_position) > 0.0001:
			var ahead := from.lerp(to, minf(t + 0.05, 1.0)) + Vector3(0, sin(minf(t + 0.05, 1.0) * PI) * float(shot.arc), 0)
			node.global_position = p
			if ahead.distance_squared_to(p) > 0.0001:
				node.look_at(ahead, Vector3.UP if absf((ahead - p).normalized().y) < 0.98 else Vector3.RIGHT)
		else:
			node.global_position = p
		if t >= 1.0:
			node.queue_free()


func _land(part: Dictionary) -> void:
	MoveFx.impact(mob.get_parent(), part, style, mob.template.get("color", Color.WHITE))
	for actor in mob._targets():
		if not StarMoves.inside(part, actor.global_position):
			continue
		var key := actor.get_instance_id()
		var waves: Array = hit_waves.get(key, [])
		if int(part.wave) in waves or int(hit_counts.get(key, 0)) >= StarMoves.MAX_HITS:
			continue
		waves.append(int(part.wave))
		hit_waves[key] = waves
		hit_counts[key] = int(hit_counts.get(key, 0)) + 1
		_damage(actor, float(part.dmg))
		if float(part.get("slow", 0.0)) > 0.0 and actor.has_method("apply_slow"):
			actor.apply_slow(float(part.slow))
		if float(part.get("knock", 0.0)) > 0.0:
			_knock(actor, part)
	var linger := float(part.get("linger", 0.0))
	if linger > 0.0:
		MoveFx.hazard(mob.get_parent(), part, style, linger)
		hazards.append({"part": part, "until": age + linger, "tick": age + StarMoves.HAZARD_TICK})


func _tick_hazards() -> void:
	for i in range(hazards.size() - 1, -1, -1):
		var hz := hazards[i]
		if age >= float(hz.until):
			hazards.remove_at(i)
			continue
		if age < float(hz.tick):
			continue
		hz.tick = float(hz.tick) + StarMoves.HAZARD_TICK
		var part: Dictionary = hz.part
		for actor in mob._targets():
			if StarMoves.inside(part, actor.global_position):
				_damage(actor, float(part.get("tick", 0.0)))
				if float(part.get("slow", 0.0)) > 0.0 and actor.has_method("apply_slow"):
					actor.apply_slow(1.0)


func _damage(actor: Node3D, mult: float) -> void:
	if mult <= 0.0:
		return
	Mob.strike(actor, float(mob.stats.atk) * mob._atk_scale * mult, mob)


## Throws a hero / companion clear of the blow (a real remote player moves itself;
## monsters on our side and bosses hold their ground).
func _knock(actor: Node3D, part: Dictionary) -> void:
	if actor.is_in_group("remote_players") or not (actor is CharacterBody3D):
		return
	if actor is Mob and (actor as Mob).is_boss:
		return
	var away := (actor.global_position - (part.pos as Vector3)) * Vector3(1, 0, 1)
	if String(part.shape) == "line":
		var dir: Vector3 = part.dir
		var lateral := away - dir * away.dot(dir)
		away = dir * 0.6 + lateral.normalized() * 0.8 if lateral.length_squared() > 0.01 else dir
	if away.length_squared() < 0.01:
		away = part.dir
	var shove := Shove.new()
	shove.body = actor as CharacterBody3D
	shove.velocity = away.normalized() * float(part.knock) / Shove.TIME
	actor.add_child(shove)


## A short slide of a body thrown by a blow (walls still stop it).
class Shove:
	extends Node
	const TIME := 0.22
	var body: CharacterBody3D
	var velocity := Vector3.ZERO
	var left := TIME

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(body) or left <= 0.0:
			queue_free()
			return
		body.move_and_collide(velocity * minf(delta, left))
		left -= delta
