extends Node3D
var checks := 0
var failures := 0

class Victim:
	extends Node3D
	var hits := 0
	func is_dead() -> bool: return false
	func take_damage(_amount: float, _source: Node) -> void: hits += 1

class Actor:
	extends Mob
	func _ready() -> void:
		visual = MonsterVisual.new()
		add_child(visual)
		set_physics_process(false)

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL ", note)

func begin(actor: Actor, special := false) -> DivineAttack:
	DivineAttack.start(actor, special)
	var attack := actor.get_child(actor.get_child_count() - 1) as DivineAttack
	attack.set_process(false)
	return attack

func clear_effects() -> void:
	for child in get_children():
		if child is DivineImpact: child._process(1.0)
	await get_tree().process_frame

func _ready() -> void:
	Game.set_process(false)
	var target := Victim.new()
	add_child(target)
	var actor := Actor.new()
	actor.template = DivineRegionData.monster(&"lotus_seraph")
	actor.stats = {"atk":100}
	actor.hero = target
	actor._victim = target
	actor.is_boss = true
	add_child(actor)
	target.position = Vector3(3,0,0)
	var attack := begin(actor)
	var locked := attack.points.duplicate()
	target.position = Vector3(15,0,0)
	attack._process(attack.contact + 0.1)
	check(attack.points == locked, "warning never follows a dodging player")
	check(target.hits == 0, "leaving the warning avoids damage")
	attack.queue_free()
	await get_tree().process_frame
	await clear_effects()
	target.position = Vector3(3,0,0)
	attack = begin(actor)
	attack.points.append(target.position)
	attack._process(attack.contact + 0.1)
	attack._process(0.1)
	check(target.hits == 1, "overlapping warnings and extra frames still hit once")
	attack.queue_free()
	await get_tree().process_frame
	await clear_effects()
	attack = begin(actor)
	actor._stun = 1.0
	attack._process(2.0)
	await get_tree().process_frame
	check(target.hits == 1 and not actor._winding, "stun cancels pending hit and unlocks actor")
	actor._stun = 0.0
	attack = begin(actor, true)
	check(attack.points.size() == 6 and attack.contact >= 1.2, "six petals with a readable boss windup")
	target.position = Vector3.ZERO
	attack._process(attack.contact + 0.1)
	check(target.hits == 1, "boss ring leaves a real safe center")
	attack.queue_free()
	await get_tree().process_frame
	await clear_effects()
	attack = begin(actor)
	actor._dead = true
	attack._process(2.0)
	await get_tree().process_frame
	check(target.hits == 1 and not actor._winding, "death cancels pending damage")
	actor.free()
	await get_tree().process_frame
	check(find_children("DivineEnemyWarnings", "Node3D", true, false).is_empty(), "warning nodes released after cancellation")
	check(get_children().filter(func(n): return n is DivineImpact).is_empty(), "all impact effects expire")
	Game.has_profile = false
	print("DIVINE ATTACK: ", checks, " checks, ", failures, " failures")
	get_tree().quit(failures)
