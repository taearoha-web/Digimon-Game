class_name JudgmentRaySequence
extends Node3D
## Tracks one living target until release. Decorative rings never deal damage.
signal impact(victim: Node3D)
var elapsed := 0.0
var release := 1.05
var hit_done := false
var art: JudgmentRayArt
var _caster: WeakRef
var _target: WeakRef
var _field: WeakRef
var _visual: WeakRef
var _generation := 0
var _hit: Callable
var _visuals := true

static func launch(field: Node3D, caster: Node3D, victim: Node3D, delay: float, hit: Callable, visual: HeroVisual = null, visuals := true) -> JudgmentRaySequence:
	if not is_instance_valid(field) or not is_instance_valid(caster) or not is_instance_valid(victim) or not hit.is_valid():
		return null
	var node := JudgmentRaySequence.new()
	node._field=weakref(field)
	node._caster=weakref(caster)
	node._target=weakref(victim)
	node._hit=hit
	node.release=maxf(delay,0.001)
	node._visuals=visuals
	if is_instance_valid(visual):
		node._visual=weakref(visual)
		node._generation=visual.skill_generation
	field.add_child(node)
	return node

func _alive_in_field(node: Node) -> bool:
	var field := _field.get_ref() as Node
	if not is_instance_valid(field) or field.is_queued_for_deletion() or not is_instance_valid(node):
		return false
	if not node.is_inside_tree() or node.is_queued_for_deletion() or not field.is_ancestor_of(node):
		return false
	if node.has_method("is_dead") and node.is_dead():
		return false
	return not (node is Rival and node.duel_over)

func _ready() -> void:
	add_to_group("judgment_ray_sequences")
	if _visuals:
		art=JudgmentRayArt.new()
		add_child(art)
	_sync_target()

func _sync_target() -> void:
	var target := _target.get_ref() as Node3D
	if is_instance_valid(target):
		global_position=Vector3(target.global_position.x,0.0,target.global_position.z)

func _process(delta: float) -> void:
	if not _alive_in_field(_caster.get_ref() as Node) or not _hit.is_valid():
		queue_free()
		return
	if not hit_done:
		if not _alive_in_field(_target.get_ref() as Node):
			queue_free()
			return
		if _visual:
			var visual := _visual.get_ref() as HeroVisual
			if not is_instance_valid(visual) or visual.skill_generation!=_generation:
				queue_free()
				return
		_sync_target()
	elapsed+=maxf(delta,0.0)
	var landed := elapsed+0.00001>=release
	if art:
		art.draw_stage(clampf(elapsed/release,0.0,1.0),maxf(elapsed-release,0.0) if landed else -1.0)
	if landed and not hit_done:
		hit_done=true
		var target := _target.get_ref() as Node3D
		_hit.call(target)
		impact.emit(target)
	if elapsed>=release+JudgmentRayArt.TAIL:
		queue_free()
