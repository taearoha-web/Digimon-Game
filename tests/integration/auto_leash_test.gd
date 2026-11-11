extends Node
## Auto hunting's leash (Hero.AUTO_LEASH): the hero hunts inside a circle round the spot
## auto was switched on. A target that runs out of it is dropped for the nearest monster
## inside, with none the hero walks back to the spot, it never walks out after a target,
## walking by hand and teleports move the circle, a faint ring shows it, and following a
## party member (Hero.follow) keeps its own moving circle with no leash.
##   godot --headless --path . res://tests/integration/auto_leash_test.tscn

var checks := 0
var failures := 0
var field: Node3D
var hero: Hero


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	Game.set_process(false)
	Online.set_process(false)
	GameSettings.load_settings()
	Game.new_profile(&"warrior", "วงออโต้", FaceKit.default_look())
	Game.profile.level = 30
	field = Node3D.new()
	add_child(field)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(240, 1, 240)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(shape)
	field.add_child(floor_body)
	hero = Hero.new()
	hero.field = field
	hero.field_radius = 110.0
	field.add_child(hero)
	hero.global_position = Vector3(0, 0.2, 0)
	await _frames(10)
	hero._invulnerable_until = 0
	hero.stats.dodge = 0.0
	await _leash()
	await _manual_move()
	await _teleport()
	await _following()
	field.queue_free()
	await get_tree().process_frame
	print("AUTO LEASH: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _keep_alive() -> void:
	Game.profile.hp = int(hero.stats.max_hp)
	Game.profile.mp = int(hero.stats.max_mp)


## A still monster (no AI) that can't die, standing at [param at].
func _mob(at: Vector3) -> Mob:
	var m := Mob.new()
	m.setup(&"pink_slime", 1, at, hero)
	field.add_child(m)
	m.set_physics_process(false)
	m.global_position = at
	m.max_hp = 1000000000
	m.hp = m.max_hp
	return m


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Waits up to [param seconds] while tracking how far the hero gets from the anchor.
func _run(seconds: float, until := Callable()) -> float:
	var farthest := 0.0
	var t := 0.0
	while t < seconds:
		_keep_alive()
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		farthest = maxf(farthest, _flat_dist(hero.global_position, hero._auto_center))
		if until.is_valid() and bool(until.call()):
			break
	return farthest


func _leash() -> void:
	print("== Leash")
	var near := _mob(Vector3(5, 0, 0))
	var other := _mob(Vector3(-8, 0, 4))
	var outside := _mob(Vector3(Hero.AUTO_LEASH + 10.0, 0, 0))
	hero.set_auto(true)
	check(hero.auto, "auto turns on in a field")
	check(_flat_dist(hero._auto_center, Vector3.ZERO) < 0.5 and is_equal_approx(hero._auto_radius, Hero.AUTO_LEASH), "the circle is centred where auto was switched on (r %.0f m)" % hero._auto_radius)
	check(is_instance_valid(hero._auto_ring) and hero._auto_ring.visible and _flat_dist(hero._auto_ring.global_position, Vector3.ZERO) < 0.5, "a ring on the ground shows the circle")
	await _run(2.0, func(): return hero.target == near)
	check(hero.target == near, "auto picks the nearest monster inside the circle")
	check(not hero._auto_leash_ok(outside.global_position, outside.body_radius()) and hero._auto_leash_pick() != outside, "a monster outside the circle is never picked")
	# The target runs away, out of the circle.
	near.global_position = Vector3(Hero.AUTO_LEASH + 6.0, 0, 0)
	var farthest := await _run(1.5, func(): return hero.target == other)
	check(hero.target == other, "the fleeing target is dropped for the nearest monster still inside (target %s)" % [hero.target.name if hero.target else "none"])
	farthest = maxf(farthest, await _run(2.0))
	check(hero.target != near, "the fled monster is not chased")
	# A target standing just inside the edge: the hero closes in but stays in the circle.
	other.global_position = Vector3(-Hero.AUTO_LEASH + 0.5, 0, 0)
	farthest = maxf(farthest, await _run(3.0))
	check(farthest <= Hero.AUTO_LEASH + 0.6, "the hero never walked out of the circle (max %.1f m)" % farthest)
	# Everything leaves: back to the spot to wait.
	other.global_position = Vector3(-Hero.AUTO_LEASH - 8.0, 0, 0)
	await _run(8.0, func(): return hero.target == null and _flat_dist(hero.global_position, hero._auto_center) <= Hero.AUTO_HOME + 0.5 and hero.velocity.length() < 0.3)
	await _run(0.5)
	check(hero.auto and hero.target == null, "with nobody inside the circle auto waits without a target")
	check(_flat_dist(hero.global_position, Vector3.ZERO) <= Hero.AUTO_HOME + 0.8, "and the hero walked back to the spot (%.1f m)" % _flat_dist(hero.global_position, Vector3.ZERO))
	# Carried out of the circle (a dash, a knock-back): it walks back in.
	hero.global_position = Vector3(Hero.AUTO_LEASH + 3.0, hero.global_position.y, 0)
	hero._auto_last_pos = hero.global_position
	await _run(6.0, func(): return _flat_dist(hero.global_position, Vector3.ZERO) <= Hero.AUTO_HOME + 0.5)
	check(_flat_dist(hero._auto_center, Vector3.ZERO) < 0.5 and _flat_dist(hero.global_position, Vector3.ZERO) <= Hero.AUTO_HOME + 0.8, "pushed a little out, the hero walks back into the circle")
	for m in [near, other, outside]:
		m.queue_free()
	await _frames(2)


func _manual_move() -> void:
	print("== Walking by hand moves the circle")
	var before := hero._auto_center
	hero.move_input = Vector2(1, 0)
	await _run(1.2)
	hero.move_input = Vector2.ZERO
	await _frames(2)
	check(hero.auto, "walking by hand keeps auto on")
	check(_flat_dist(hero._auto_center, before) > 3.0 and _flat_dist(hero._auto_center, hero.global_position) < 1.0, "the circle moved with the hero (%.1f m)" % _flat_dist(hero._auto_center, before))
	check(_flat_dist(hero._auto_ring.global_position, hero._auto_center) < 0.1, "the ring moved too")
	# A monster inside the new circle but outside the old one is now fair game.
	var mob := _mob(hero._auto_center + Vector3(Hero.AUTO_LEASH - 3.0, 0, 0))
	await _run(2.0, func(): return hero.target == mob)
	check(hero.target == mob, "auto hunts in the new circle")
	mob.queue_free()
	await _frames(2)


func _teleport() -> void:
	print("== A teleport re-centres the circle")
	hero.global_position = Vector3(-40, 0.2, 40)
	await _frames(3)
	check(hero.auto and _flat_dist(hero._auto_center, Vector3(-40, 0, 40)) < 1.0, "after a teleport the circle is where the hero is")
	await _run(1.0)
	check(_flat_dist(hero.global_position, Vector3(-40, 0, 40)) < 2.0, "and the hero doesn't walk back to the old spot")
	hero.set_auto(false)
	check(not hero.auto and not hero._auto_ring.visible, "auto off hides the ring")
	hero.set_auto(true)
	check(hero.auto and _flat_dist(hero._auto_center, hero.global_position) < 0.5 and hero._auto_ring.visible, "auto on again re-centres the circle where the hero stands")
	hero.set_auto(false)


func _following() -> void:
	print("== Following a party member has no leash")
	var start := hero.global_position
	var lead := Node3D.new()
	field.add_child(lead)
	lead.global_position = start + Vector3(Hero.AUTO_LEASH + 16.0, 0, 0)
	var mob := _mob(lead.global_position + Vector3(3, 0, 2))
	hero.follow = lead
	check(hero._auto_leash_ok(mob.global_position), "the leash is off while following")
	await _run(10.0, func(): return hero.target == mob)
	check(hero.target == mob, "following, the hero fights next to the member (target %s)" % [hero.target.name if hero.target else "none"])
	check(_flat_dist(hero.global_position, start) > Hero.AUTO_LEASH + 4.0, "following took the hero well past an auto circle (%.1f m)" % _flat_dist(hero.global_position, start))
	check(not hero.auto, "following doesn't switch auto on")
	hero.follow = null
	mob.queue_free()
	lead.queue_free()
	await _frames(2)
