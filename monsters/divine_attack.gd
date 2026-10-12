class_name DivineAttack
extends Node
## Fixed telegraphs: the locked points never chase the player after warning.
## One hit per actor, including overlapping petals; stun/death cancels cleanly.
var mob: Mob
var special := false
var age := 0.0
var contact := 0.9
var radius := 2.0
var points: Array[Vector3] = []
var warned: Node3D
var impact_done := false
var charge := false

static func start(actor: Mob, boss_move := false) -> void:
	if not actor._alive(actor._victim): return
	var action := DivineAttack.new()
	action.mob = actor
	action.special = boss_move
	actor._winding = true
	actor._attack_timer = 2.6 if not actor.is_boss else 2.0
	if boss_move: actor._slam_timer = 8.0
	actor.add_child(action)

func _ready() -> void:
	var origin := mob.global_position * Vector3(1,0,1)
	var target := mob._victim.global_position * Vector3(1,0,1)
	var forward := (target - origin).normalized()
	charge = mob.template.get("behavior", "") == "jade_charge"
	if special:
		contact = 1.3
		radius = 2.1
		for i in 6:
			var a := TAU * float(i) / 6.0 + float(mob.phase) * PI / 6.0
			points.append(origin + Vector3(cos(a),0,sin(a)) * 6.0)
	elif charge:
		points.append(origin + forward * minf(5.0, origin.distance_to(target)))
	elif mob.template.attack == "ranged":
		contact = 1.05
		points.append(target)
	else:
		radius = 2.5
		points.append(origin + forward * 1.9)
	warned = Node3D.new()
	warned.name = "DivineEnemyWarnings"
	mob.get_parent().add_child(warned)
	for point in points: VfxKit.danger_circle(warned, point, radius, contact)
	mob.visual.action("attack", int((contact + 0.5) * 1000.0))
	mob._anim_lock = Time.get_ticks_msec() + int((contact + 0.5) * 1000.0)

func _process(delta: float) -> void:
	if not is_instance_valid(mob) or mob.is_dead() or mob._stun > 0.0 or mob._returning:
		queue_free()
		return
	age += delta
	if charge and age > contact - 0.25 and age <= contact:
		var movement := (points[0] - mob.global_position) * Vector3(1,0,1)
		mob.move_and_collide(movement.limit_length(delta * 16.0))
	if not impact_done and age >= contact:
		impact_done = true
		for point in points: DivineImpact.emit_at(mob.get_parent(), point, radius)
		for actor in mob._targets():
			for point in points:
				if ((actor.global_position - point) * Vector3(1,0,1)).length() <= radius:
					actor.take_damage(float(mob.stats.atk) * mob._atk_scale * (1.55 if special else 1.0), mob)
					break
	if age >= contact + 0.6: queue_free()

func _exit_tree() -> void:
	if is_instance_valid(warned): warned.queue_free()
	if is_instance_valid(mob): mob._winding = false
