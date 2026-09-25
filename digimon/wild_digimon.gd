class_name WildDigimon
extends CharacterBody3D
## A wild Digimon roaming its spawn region. Touching the player starts a
## battle ("symbol encounter"). AI is intentionally light: decisions a few
## times per second, and fully asleep when the player is far away.

signal encountered(wild: WildDigimon)
signal despawned(wild: WildDigimon)

const NOTICE_RADIUS := 7.0
const SLEEP_DISTANCE := 55.0

var species_id: StringName
var level := 3
var spawn_key := ""
var region_center := Vector3.ZERO
var region_extents := Vector3(10, 0, 10)
var player: Node3D
var encounters_enabled := true

var visual: DigimonVisual
var _label: Label3D
var _alert: Label3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)
var _goal := Vector3.ZERO
var _think_timer := 0.0
var _pause_timer := 0.0
var _speed := 2.0
var _aggressive := false
var _noticed := false
var _yaw := 0.0
var _triggered := false


func setup(p_species_id: StringName, p_level: int, center: Vector3, extents: Vector3, p_player: Node3D) -> void:
	species_id = p_species_id
	level = p_level
	region_center = center
	region_extents = extents
	player = p_player


func _ready() -> void:
	collision_layer = 1 << 2
	collision_mask = 1 << 0
	floor_snap_length = 0.5
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.0
	shape.shape = capsule
	shape.position = Vector3(0, 0.5, 0)
	add_child(shape)

	visual = DigimonVisual.new()
	add_child(visual)
	visual.set_species(species_id)
	var species := visual.species
	_speed = (species.move_speed if species else 3.0) * 0.55
	_aggressive = species != null and species.attribute == DigimonSpecies.Attribute.VIRUS

	var trigger := Area3D.new()
	trigger.name = "EncounterTrigger"
	trigger.collision_layer = 0
	trigger.collision_mask = 1 << 1
	var trigger_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.25
	trigger_shape.shape = sphere
	trigger_shape.position = Vector3(0, 0.6, 0)
	trigger.add_child(trigger_shape)
	add_child(trigger)
	trigger.body_entered.connect(_on_body_entered)

	_label = Label3D.new()
	_label.text = "Lv %d %s" % [level, species.display_name if species else String(species_id)]
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.004
	_label.font_size = 44
	_label.outline_size = 12
	_label.modulate = Color(1, 0.92, 0.8)
	_label.no_depth_test = false
	_label.visibility_range_end = 16.0
	_label.position = Vector3(0, visual.model_height + 0.45, 0)
	add_child(_label)
	_alert = Label3D.new()
	_alert.text = "!"
	_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert.pixel_size = 0.01
	_alert.font_size = 64
	_alert.outline_size = 16
	_alert.modulate = Color(1.0, 0.35, 0.3)
	_alert.position = Vector3(0, visual.model_height + 0.95, 0)
	_alert.visible = false
	add_child(_alert)
	_pick_goal()
	# Pop-in spawn animation.
	visual.scale = Vector3.ONE * 0.01
	create_tween().tween_property(visual, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	if player and global_position.distance_squared_to(player.global_position) > SLEEP_DISTANCE * SLEEP_DISTANCE:
		return # Asleep: far from the player.
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = 0.3
		_think()
	var desired := Vector3.ZERO
	if _pause_timer > 0.0:
		_pause_timer -= delta
	else:
		var to_goal := _goal - global_position
		to_goal.y = 0.0
		if to_goal.length() < 0.6:
			_pause_timer = randf_range(1.5, 4.0)
			_pick_goal()
		else:
			var speed := _speed * (1.9 if (_noticed and _aggressive) else 1.0)
			desired = to_goal.normalized() * speed
	var horizontal := Vector3(velocity.x, 0, velocity.z).move_toward(desired, 10.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = -0.5 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	if horizontal.length() > 0.2:
		_yaw = lerp_angle(_yaw, atan2(horizontal.x, horizontal.z), 1.0 - exp(-6.0 * delta))
		visual.rotation.y = _yaw
		visual.play_animation(&"run" if horizontal.length() > _speed * 1.4 else &"walk")
	elif _noticed and player:
		var to_player := player.global_position - global_position
		_yaw = lerp_angle(_yaw, atan2(to_player.x, to_player.z), 1.0 - exp(-6.0 * delta))
		visual.rotation.y = _yaw
		visual.play_animation(&"idle")
	else:
		visual.play_animation(&"idle")


func _think() -> void:
	if player == null:
		return
	var distance := global_position.distance_to(player.global_position)
	var was_noticed := _noticed
	_noticed = distance < NOTICE_RADIUS and encounters_enabled
	if _noticed and not was_noticed:
		_show_alert()
	if _noticed and _aggressive and _is_inside_region(player.global_position, 1.3):
		_goal = player.global_position
		_pause_timer = 0.0


func _show_alert() -> void:
	_alert.visible = true
	_alert.scale = Vector3.ONE * 0.2
	var tween := create_tween()
	tween.tween_property(_alert, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.2)
	tween.tween_callback(func(): _alert.visible = false)


func _pick_goal() -> void:
	_goal = region_center + Vector3(randf_range(-region_extents.x, region_extents.x), 0, randf_range(-region_extents.z, region_extents.z))


func _is_inside_region(point: Vector3, margin := 1.0) -> bool:
	var local := point - region_center
	return absf(local.x) <= region_extents.x * margin and absf(local.z) <= region_extents.z * margin


func _on_body_entered(body: Node3D) -> void:
	if _triggered or not encounters_enabled:
		return
	if body is PlayerController:
		_triggered = true
		encountered.emit(self)


## Removes the Digimon with a small shrink animation.
func despawn() -> void:
	encounters_enabled = false
	set_physics_process(false)
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE * 0.01, 0.3)
	tween.tween_callback(func():
		despawned.emit(self)
		queue_free())
