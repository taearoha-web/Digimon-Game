class_name InteractionDetector
extends Area3D
## Player-side sensor that tracks overlapping [Interactable]s and exposes the
## best one (highest priority, then nearest). Evaluated a few times per second
## instead of every frame.

signal current_changed(interactable: Interactable)

@export var radius := 0.6
@export var refresh_interval := 0.12

var _candidates: Array[Interactable] = []
var _current: Interactable
var _timer := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 3
	monitoring = true
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	add_child(shape)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func get_current() -> Interactable:
	return _current if is_instance_valid(_current) else null


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = refresh_interval
	var best: Interactable = null
	var best_score := -INF
	for candidate in _candidates:
		if not is_instance_valid(candidate) or not candidate.enabled or not candidate.is_inside_tree():
			continue
		var distance := global_position.distance_to(candidate.global_position)
		var score := candidate.interaction_priority * 100.0 - distance
		if score > best_score:
			best_score = score
			best = candidate
	if best != _current:
		_current = best
		current_changed.emit(_current)


func _on_area_entered(area: Area3D) -> void:
	if area is Interactable and not _candidates.has(area):
		_candidates.append(area)


func _on_area_exited(area: Area3D) -> void:
	if area is Interactable:
		_candidates.erase(area)
