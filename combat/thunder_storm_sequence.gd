class_name ThunderStormSequence
extends Node3D
## Three independently sampled waves. The fixed storm zone is resampled at each
## strike, so entering, leaving and dying enemies are handled on the actual beat.
signal wave_fired(index: int, victims: Array)
const WAVE_COUNT := 3
const TARGETS_PER_WAVE := 5
const FORM_SECONDS := 0.55
const INTERVAL_SECONDS := 0.75
const TAIL_SECONDS := 0.55
var elapsed := 0.0
var center := Vector3.ZERO
var radius := 9.0
var _caster: WeakRef
var _field: WeakRef
var _candidates: Callable
var _hit: Callable
var _wave := 0
var _visuals := true
var _art: ThunderStormArt
var _rng := RandomNumberGenerator.new()

static func launch(field: Node3D, caster: Node, at: Vector3, area: float, candidates: Callable, hit: Callable, visuals := true) -> ThunderStormSequence:
	if not is_instance_valid(field) or not is_instance_valid(caster) or not field.is_inside_tree() or field.is_queued_for_deletion():
		return null
	var sequence := ThunderStormSequence.new()
	sequence.center = Vector3(at.x, 0, at.z)
	sequence.radius = area
	sequence._caster = weakref(caster)
	sequence._field = weakref(field)
	sequence._candidates = candidates
	sequence._hit = hit
	sequence._visuals = visuals
	sequence._rng.randomize()
	field.add_child(sequence)
	return sequence

func _ready() -> void:
	add_to_group("thunder_storm_sequences")
	if _visuals:
		_art = ThunderStormArt.new()
		_art.radius = radius
		_art.position = center
		add_child(_art)

func _can_run() -> bool:
	var caster := _caster.get_ref() as Node
	var field := _field.get_ref() as Node
	if not is_instance_valid(caster) or not is_instance_valid(field) or caster.is_queued_for_deletion() or field.is_queued_for_deletion():
		return false
	if not caster.is_inside_tree() or not field.is_ancestor_of(caster) or not _candidates.is_valid() or not _hit.is_valid():
		return false
	if caster.has_method("is_dead") and caster.is_dead():
		return false
	if caster is Rival and caster.duel_over:
		return false
	return true

static func eligible(node: Node3D, field: Node, at: Vector3, area: float) -> bool:
	if not is_instance_valid(node) or not node.is_inside_tree() or node.is_queued_for_deletion() or not field.is_ancestor_of(node):
		return false
	if node.has_method("is_dead") and node.is_dead():
		return false
	# Matches Ice Storm's area overlap against monster bodies.
	var body := float(node.body_radius()) if node.has_method("body_radius") else 0.4
	return Vector2(node.global_position.x - at.x, node.global_position.z - at.z).length() <= area + body

func _process(delta: float) -> void:
	if not _can_run():
		queue_free()
		return
	elapsed += maxf(delta, 0.0)
	while _wave < WAVE_COUNT and elapsed + 0.00001 >= FORM_SECONDS + _wave * INTERVAL_SECONDS:
		if not _can_run():
			queue_free()
			return
		var pool: Array[Node3D] = []
		var field := _field.get_ref() as Node
		for node in _candidates.call():
			if node is Node3D and eligible(node, field, center, radius) and not pool.has(node):
				pool.append(node)
		# Fisher-Yates: sampling without replacement, independently every wave.
		for i in range(pool.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var swap := pool[i]
			pool[i] = pool[j]
			pool[j] = swap
		var selected: Array[Node3D] = []
		for i in mini(TARGETS_PER_WAVE, pool.size()):
			var victim := pool[i]
			if not _can_run():
				queue_free()
				return
			if not eligible(victim, field, center, radius):
				continue
			selected.append(victim)
			var point: Vector3 = victim.hit_point() if victim.has_method("hit_point") else victim.global_position + Vector3.UP
			if _visuals:
				_art.strike(point - center, _wave * 5 + i)
			_hit.call(victim)
		if _visuals and not selected.is_empty():
			_art.flash()
		wave_fired.emit(_wave, selected)
		_wave += 1
	if elapsed >= FORM_SECONDS + (WAVE_COUNT - 1) * INTERVAL_SECONDS + TAIL_SECONDS:
		queue_free()
