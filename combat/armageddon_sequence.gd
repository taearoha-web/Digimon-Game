class_name ArmageddonSequence
extends Node3D
## Gameplay clock for Armageddon. Cosmetic budgets never decide whether a hit
## happens. All eleven area hits use the caster's normal damage/status pipeline.

signal impact(index: int, center: Vector3, radius: float, multiplier: float)
signal completed()
signal cancelled()

const METEOR_ART := preload("res://combat/meteor_art.gd")
const DESCENT_SECONDS := 1.25
const FRAGMENT_COUNT := 10
const INTERVAL_SECONDS := 0.5
const FRAGMENT_MULTIPLIER := 0.12
const FRAGMENT_RADIUS_SCALE := 0.45
const VISUAL_TAIL_SECONDS := 1.5
const GOLDEN_ANGLE := 2.399963229728653

var elapsed := 0.0
var targets: Array[Vector3] = []
var _center := Vector3.ZERO
var _radius := 1.0
var _base_multiplier := 1.0
var _caster: WeakRef
var _field: WeakRef
var _damage_callback: Callable
var _visuals := true
var _next_impact := 0
var _stopped := false


## The callback takes (index, center, radius, multiplier), where index zero is
## the giant meteor. Rank scaling is supplied once in base_multiplier/radius.
static func launch(field: Node3D, caster: Node, center: Vector3, radius: float, base_multiplier: float, damage_callback: Callable, visuals := true) -> ArmageddonSequence:
	if not is_instance_valid(field) or not is_instance_valid(caster):
		return null
	if not field.is_inside_tree() or field.is_queued_for_deletion() or not damage_callback.is_valid():
		return null
	var sequence := ArmageddonSequence.new()
	sequence.name = "ArmageddonSequence"
	sequence._field = weakref(field)
	sequence._caster = weakref(caster)
	sequence._center = Vector3(center.x, 0.0, center.z)
	sequence._radius = maxf(radius, 0.1)
	sequence._base_multiplier = maxf(base_multiplier, 0.0)
	sequence._damage_callback = damage_callback
	sequence._visuals = visuals
	sequence.targets = fragment_targets(sequence._center, sequence._radius)
	field.add_child(sequence)
	return sequence


## A deterministic breakup pattern. Each fragment's area includes the locked
## impact center, so a stationary target can take every one of the eleven hits.
static func fragment_targets(center: Vector3, radius: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for i in FRAGMENT_COUNT:
		var angle := float(i) * GOLDEN_ANGLE
		var distance := radius * lerpf(0.2, 0.35, sqrt(float(i) / float(FRAGMENT_COUNT - 1)))
		points.append(center + Vector3(cos(angle), 0.0, sin(angle)) * distance)
	return points


static func hit_time(index: int) -> float:
	return DESCENT_SECONDS + float(index) * INTERVAL_SECONDS


func _ready() -> void:
	# Inherit pause from the field, including the game's pause menu. Engine
	# hitstop scales both this clock and the bound visual tweens together.
	process_mode = Node.PROCESS_MODE_INHERIT
	add_to_group("armageddon_sequences")
	if not _can_run():
		cancel()
		return
	if _visuals:
		METEOR_ART.descent(self, _center, _radius, DESCENT_SECONDS)


func _process(delta: float) -> void:
	if _stopped:
		return
	if not _can_run():
		cancel()
		return
	elapsed += maxf(delta, 0.0)
	while _next_impact <= FRAGMENT_COUNT and elapsed + 0.00001 >= hit_time(_next_impact):
		if not _can_run():
			cancel()
			return
		var index := _next_impact
		_next_impact += 1
		var center := _center if index == 0 else targets[index - 1]
		var radius := _radius if index == 0 else _radius * FRAGMENT_RADIUS_SCALE
		var multiplier := _base_multiplier * (1.0 if index == 0 else FRAGMENT_MULTIPLIER)
		if _visuals:
			if index == 0:
				# Reserve the ten readable fragment bodies before optional debris.
				METEOR_ART.fragments(self, _center, targets, INTERVAL_SECONDS)
			METEOR_ART.impact(self, center, radius, index == 0)
		_damage_callback.call(index, center, radius, multiplier)
		impact.emit(index, center, radius, multiplier)
		if index == FRAGMENT_COUNT:
			completed.emit()
	if elapsed >= hit_time(FRAGMENT_COUNT) + VISUAL_TAIL_SECONDS:
		_stopped = true
		_damage_callback = Callable()
		queue_free()


func _can_run() -> bool:
	if is_queued_for_deletion() or not is_inside_tree() or not _damage_callback.is_valid():
		return false
	var caster := _caster.get_ref() as Node if _caster != null else null
	var field := _field.get_ref() as Node if _field != null else null
	if not is_instance_valid(caster) or not is_instance_valid(field):
		return false
	if caster.is_queued_for_deletion() or field.is_queued_for_deletion() or not caster.is_inside_tree():
		return false
	# A surviving/reparented character must never damage enemies in its old zone.
	if caster != field and not field.is_ancestor_of(caster):
		return false
	return not (caster.has_method("is_dead") and bool(caster.call("is_dead")))


func cancel() -> void:
	if _stopped:
		return
	_stopped = true
	_damage_callback = Callable()
	set_process(false)
	cancelled.emit()
	queue_free()
