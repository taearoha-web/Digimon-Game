class_name Villager
extends Node3D
## A background villager walking a loop between the plaza, market and shrine,
## or an animal pottering about one spot. Visual only: no collider, not in
## Zone.npcs, so the Talk button and the role NPC count are unchanged. The
## model joins the "anim_lod" group like every other character.

## Never more than three walkers: each is a full chibi rig (the blob shadow
## grounds them; their meshes skip the shadow pass).
const MAX_WALKERS := 3

var waypoints: Array[Vector2] = []
var speed := 1.5
var visual: Node3D
var _index := 0
var _pause := 0.0
var _yaw := 0.0
var _animal := false
var _rng := RandomNumberGenerator.new()
var _home := Vector2.ZERO
var _roam := 0.0


func setup_person(look: Dictionary, outfit: Array, hat: Array, loop: Array, rng: RandomNumberGenerator) -> void:
	_rng.seed = rng.randi()
	var own := look.duplicate()
	own["npc_outfit"] = outfit
	own["npc_hat"] = hat
	var hero := HeroVisual.new()
	add_child(hero)
	hero.setup(&"warrior", String(outfit[0]), false, {}, own)
	hero.add_to_group("anim_lod")
	for mesh in hero.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual = hero
	waypoints.assign(loop)
	_index = _rng.randi() % waypoints.size()
	position = Vector3(waypoints[_index].x, 0, waypoints[_index].y)
	_pause = _rng.randf_range(0.5, 3.0)
	speed = _rng.randf_range(1.3, 1.7)
	MeshKit.blob_shadow(self, 0.8)
	_play(false)


## An animal (MonsterVisual model) wandering within `roam` metres of `home`.
func setup_animal(model: String, height: float, home: Vector2, roam: float, p_speed: float, rng: RandomNumberGenerator) -> void:
	_rng.seed = rng.randi()
	_animal = true
	var mob := MonsterVisual.new()
	add_child(mob)
	mob.setup(model, height)
	mob.add_to_group("anim_lod")
	visual = mob
	_home = home
	_roam = roam
	speed = p_speed
	position = Vector3(home.x, 0, home.y)
	waypoints = [_next_spot()]
	MeshKit.blob_shadow(self, 0.45)
	_play(false)


func _next_spot() -> Vector2:
	var a := _rng.randf() * TAU
	return _home + Vector2(cos(a), sin(a)) * sqrt(_rng.randf()) * _roam


func _play(walking: bool) -> void:
	if visual is MonsterVisual:
		(visual as MonsterVisual).play("walk" if walking else "idle")
	elif visual is HeroVisual:
		(visual as HeroVisual).play("Walking_A" if walking else "Idle")


func _process(delta: float) -> void:
	if waypoints.is_empty():
		return
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			_play(true)
		return
	var goal := waypoints[_index]
	var d := Vector3(goal.x - position.x, 0, goal.y - position.z)
	if d.length() < 0.2:
		if _animal:
			waypoints[0] = _next_spot()
		else:
			_index = (_index + 1) % waypoints.size()
		_pause = _rng.randf_range(1.5, 5.0) if not _animal else _rng.randf_range(1.0, 4.0)
		_play(false)
		return
	var step := d.normalized() * speed * delta
	position += step if step.length() < d.length() else d
	_yaw = lerp_angle(_yaw, atan2(d.x, d.z), 1.0 - exp(-8.0 * delta))
	visual.rotation.y = _yaw
