class_name SiegeLift
extends Node
## The guild war's raised throne court (SiegeArena.COURT_H up its grand staircase) in a
## game whose effects were all drawn for flat ground: a skill's ring, a danger circle, a
## pillar of light are put at y = 0 (or a little over it), which on the court is under the
## floor. This node, one per siege zone, puts them on the floor that is really there:
##   - effects: every plain 3D node added to the zone (and the shared skill layer pool's
##     slots) is looked at just before each frame is drawn. One that stands over the
##     stairs or the court and was put where flat ground would be (below the real floor,
##     or far over it: something falling from the sky) is "ground space": the floor's
##     height is added to wherever its maker puts it, every time it is moved. One put at a
##     real body's height (from the floor to REAL_BAND over it) is left alone.
##   - bodies: a fighter, the hero, a party member, a summon or a pet put below the floor
##     (a skill that moves it to a spot at the field's height) is set on the floor before
##     its next step, so nobody is ever left inside the court's block.
## Nothing here changes the war's rules: SiegeArena's map points stay flat.

## A node this far over the floor at most (and no lower than SUNK under it) was put at a
## real body's height.
const REAL_BAND := 3.0
const SUNK := 0.25
## A node that moved this far in a frame was put somewhere new (a pool's slot borrowed
## again): it is judged afresh.
const JUMP := 2.5
## The hero's camera reaches FAR_FIGHT in the fighting view and FAR_UP once tilted above TILT_UP.
const FAR_FIGHT := 150.0
const FAR_UP := 520.0
const TILT_UP := -30.0

var zone: Node3D
## Untyped: a freed node stays in the list until the next sweep takes it out.
var _nodes: Array = []
## 0 not judged yet, 1 real height, 2 ground space.
var _mode := PackedByteArray()
var _last := PackedVector3Array()
var _bodies: Array[CharacterBody3D] = []
var _pool_tick := 0.0
var _pool_seen := false
## Probe counters (tests).
var lifted := 0
var rescued := 0


static func attach(to: Node3D) -> SiegeLift:
	var old := to.get_node_or_null("SiegeLift")
	if old != null:
		return old as SiegeLift
	var lift := SiegeLift.new()
	lift.name = "SiegeLift"
	lift.zone = to
	to.add_child(lift)
	return lift


func _ready() -> void:
	# Before the bodies' own steps.
	process_physics_priority = -100
	if zone == null:
		zone = get_parent() as Node3D
	zone.child_entered_tree.connect(_entered)
	for child in zone.get_children():
		_entered(child)
	RenderingServer.frame_pre_draw.connect(_pre_draw)


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_pre_draw):
		RenderingServer.frame_pre_draw.disconnect(_pre_draw)


func _entered(node: Node) -> void:
	if node is CharacterBody3D:
		if not _bodies.has(node):
			_bodies.append(node as CharacterBody3D)
		return
	if not (node is Node3D) or node is CollisionObject3D or node is Light3D or node is Camera3D or node is ThirdPersonCamera:
		return
	# A summon or a pet keeps its own height by its summoner's (Summon._level_y).
	if node.name == &"Siege" or node == self or node is Summon:
		return
	_track(node as Node3D)


func _track(node: Node3D) -> void:
	_nodes.append(node)
	_mode.append(0)
	_last.append(Vector3.INF)


func _physics_process(delta: float) -> void:
	var i := _bodies.size() - 1
	while i >= 0:
		var body := _bodies[i]
		if not is_instance_valid(body) or body.get_parent() != zone:
			_bodies.remove_at(i)
		else:
			var p := body.global_position
			if p.z < SiegeArena.STAIR_Z0 + SiegeArena.STAIR_LEAD:
				var floor_at := SiegeArena.floor_y(p)
				if p.y < floor_at - 0.2:
					body.global_position = Vector3(p.x, floor_at + 0.05, p.z)
					if body.velocity.y < 0.0:
						body.velocity.y = 0.0
					rescued += 1
		i -= 1
	# The far kingdom is drawn only when the view is tilted up at it: tilted down at the
	# fight nothing past the field shows, and the camera's reach stays the fighting view's.
	var rig: Variant = zone.get("camera_rig")
	if rig is ThirdPersonCamera and (rig as ThirdPersonCamera).camera != null:
		var reach := FAR_UP if (rig as ThirdPersonCamera).pitch_degrees > TILT_UP else FAR_FIGHT
		if not is_equal_approx((rig as ThirdPersonCamera).camera.far, reach):
			(rig as ThirdPersonCamera).camera.far = reach
	_pool_tick -= delta
	if _pool_tick <= 0.0 and not _pool_seen:
		_pool_tick = 1.0
		var pool := Game.get_node_or_null(SkillLayerPool.NODE_NAME)
		if pool != null:
			_pool_seen = true
			for child in pool.get_children():
				if child is Node3D and not (child is Light3D):
					_track(child as Node3D)


func _pre_draw() -> void:
	settle()


## Puts every tracked effect on its floor (called before each drawn frame; tests call it).
func settle() -> void:
	var edge := SiegeArena.STAIR_Z0 + SiegeArena.STAIR_LEAD
	var i := _nodes.size() - 1
	while i >= 0:
		var item: Variant = _nodes[i]
		var node := item as Node3D if is_instance_valid(item) else null
		if node == null or not node.is_inside_tree():
			var end := _nodes.size() - 1
			_nodes[i] = _nodes[end]
			_mode[i] = _mode[end]
			_last[i] = _last[end]
			_nodes.remove_at(end)
			_mode.remove_at(end)
			_last.remove_at(end)
			i -= 1
			continue
		if not node.visible:
			_mode[i] = 0
			i -= 1
			continue
		var p := node.global_position
		if p.z >= edge:
			_mode[i] = 0
			i -= 1
			continue
		var was := _last[i]
		if p == was:
			i -= 1
			continue
		var floor_at := SiegeArena.floor_y(p)
		if floor_at < 0.3:
			_mode[i] = 0
			_last[i] = p
			i -= 1
			continue
		var mode := _mode[i]
		if mode != 0 and was.is_finite():
			# Put somewhere new (far across the floor, or a jump in height that no flight
			# makes in one frame: a ring that now follows its caster): judged afresh.
			var raw_before := was.y - (floor_at if mode == 2 else 0.0)
			if Vector2(p.x - was.x, p.z - was.z).length() > JUMP or absf(p.y - raw_before) > 2.0:
				mode = 0
		if mode == 0:
			mode = 1 if (p.y >= floor_at - SUNK and p.y <= floor_at + REAL_BAND) else 2
			_mode[i] = mode
		if mode == 2:
			p.y += floor_at
			node.global_position = p
			node.force_update_transform()
			lifted += 1
		_last[i] = p
		i -= 1
