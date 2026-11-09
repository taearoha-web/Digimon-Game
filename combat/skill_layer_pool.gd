class_name SkillLayerPool
extends Node3D
## The fixed pools behind the skill layer stack (SkillLayers): particle emitters,
## shockwave rings, flash lights and one heat-haze card. Every cast borrows from
## them, so 200 casts create no new nodes: a busy pool takes back its oldest
## slot. One pool per game under the Game autoload (never under a field, whose
## temporary children the leak tests count), created on first use.
##
## A slot remembers the field that borrowed it: once that field is gone (a zone
## change) the slot goes back at the next frame, so nothing lingers into the
## next zone. Particle, decoration and light reservations go through VfxBudget
## while a slot plays and are returned when it ends. The pool processes only
## while something plays and allocates nothing per frame.

const NODE_NAME := "SkillLayerPool"
const EMITTERS := 24
const RINGS := 6
const LIGHTS := 2
const HAZES := 1
const RING_SHADER := preload("res://shaders/skill_layer_ring.gdshader")
const HAZE_SHADER := preload("res://shaders/skill_layer_haze.gdshader")

var _clock := 0.0
## Emitters: when they start, stop streaming and end; who borrowed them.
var _emitters: Array[CPUParticles3D] = []
var _e_start := PackedFloat32Array()
var _e_stop := PackedFloat32Array()
var _e_end := PackedFloat32Array()
var _e_owner := PackedInt64Array()
var _e_reserved := PackedInt32Array()
## 1 where the hero's own room (VfxBudget) paid the reservation, handed back on release.
var _e_hero := PackedByteArray()
var _e_live := PackedByteArray()
## Rings: start, length, owner; each has its own material (parameters per use).
var _rings: Array[MeshInstance3D] = []
var _r_mats: Array[ShaderMaterial] = []
var _r_start := PackedFloat32Array()
var _r_len := PackedFloat32Array()
var _r_owner := PackedInt64Array()
var _r_live := PackedByteArray()
var _r_hero := PackedByteArray()
## Lights: start, length, peak energy, mode (0 flash: fast rise, eased decay;
## 1 charge: rises over its length then cuts), owner.
var _lights: Array[OmniLight3D] = []
var _l_start := PackedFloat32Array()
var _l_len := PackedFloat32Array()
var _l_peak := PackedFloat32Array()
var _l_mode := PackedByteArray()
var _l_owner := PackedInt64Array()
var _l_live := PackedByteArray()
var _haze: MeshInstance3D
var _haze_mat: ShaderMaterial
var _h_start := 0.0
var _h_len := 0.0
var _h_owner := 0
var _h_live := false
var _h_hero := false
var _active := 0
var _watched: Dictionary = {}
## Test / probe counters.
var borrowed := 0
var stolen := 0


static func of(parent: Node) -> SkillLayerPool:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var tree := parent.get_tree()
	var holder: Node = tree.root.get_node_or_null("Game")
	if holder == null:
		holder = tree.root
	var pool := holder.get_node_or_null(NODE_NAME) as SkillLayerPool
	if pool == null:
		pool = SkillLayerPool.new()
		pool.name = NODE_NAME
		holder.add_child(pool)
	pool._watch(parent)
	return pool


## The pool of this game, if one was made (tests, probes).
static func existing(tree: SceneTree) -> SkillLayerPool:
	if tree == null:
		return null
	var holder: Node = tree.root.get_node_or_null("Game")
	if holder == null:
		holder = tree.root
	return holder.get_node_or_null(NODE_NAME) as SkillLayerPool


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	top_level = true
	set_process(false)


## The field a cast borrows for: once it leaves the tree (a zone change, a test
## scene freed) its slots go back at once, with their budget.
func _watch(owner: Node) -> void:
	var id := owner.get_instance_id()
	if _watched.has(id):
		return
	_watched[id] = true
	owner.tree_exited.connect(_owner_gone.bind(id), CONNECT_ONE_SHOT)


func _owner_gone(id: int) -> void:
	_watched.erase(id)
	for i in _emitters.size():
		if _e_owner[i] == id:
			_retire_emitter(i)
	for i in _rings.size():
		if _r_owner[i] == id:
			_retire_ring(i)
	for i in _lights.size():
		if _l_owner[i] == id:
			_retire_light(i)
	if _h_owner == id:
		_retire_haze()


func node_count() -> int:
	return _emitters.size() + _rings.size() + _lights.size() + (1 if _haze else 0)


func active_count() -> int:
	return _active


# ---------------------------------------------------------------------------
# Emitters
# ---------------------------------------------------------------------------

## A configured, idle emitter for [param owner_id], playing from [param delay]
## for [param stream] seconds (0: one burst). Returns null when the particle
## budget is spent. The caller sets its look and motion, then the pool starts it.
func emitter(owner_id: int, amount: int, life: float, delay := 0.0, stream := 0.0) -> CPUParticles3D:
	var slot := _free_emitter()
	var reserved := VfxBudget.reserve_particles(amount)
	if reserved <= 0:
		return null
	var p := _emitters[slot]
	if p.amount != reserved:
		p.amount = reserved
	p.lifetime = maxf(0.05, life)
	p.one_shot = stream <= 0.0
	p.emitting = false
	p.visible = false
	_e_start[slot] = _clock + maxf(0.0, delay)
	_e_stop[slot] = _e_start[slot] + maxf(0.0, stream)
	_e_end[slot] = _e_stop[slot] + life * 1.35 + 0.1
	_e_owner[slot] = owner_id
	_e_reserved[slot] = reserved
	_e_hero[slot] = 1 if VfxBudget.last_from_hero else 0
	_e_live[slot] = 2 # armed: starts at _e_start
	_active += 1
	_wake()
	borrowed += 1
	return p


func _free_emitter() -> int:
	if _emitters.size() < EMITTERS:
		var p := CPUParticles3D.new()
		p.local_coords = false
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.visible = false
		p.emitting = false
		p.fixed_fps = 0
		add_child(p)
		_emitters.append(p)
		_e_start.append(0.0)
		_e_stop.append(0.0)
		_e_end.append(0.0)
		_e_owner.append(0)
		_e_reserved.append(0)
		_e_hero.append(0)
		_e_live.append(0)
		return _emitters.size() - 1
	var oldest := 0
	for i in _emitters.size():
		if _e_live[i] == 0:
			return i
		if _e_end[i] < _e_end[oldest]:
			oldest = i
	stolen += 1
	_retire_emitter(oldest)
	return oldest


func _retire_emitter(i: int) -> void:
	if _e_live[i] == 0:
		return
	_e_live[i] = 0
	_active -= 1
	var p := _emitters[i]
	p.emitting = false
	p.visible = false
	VfxBudget.release_particles(_e_reserved[i], _e_hero[i] == 1)
	_e_reserved[i] = 0


# ---------------------------------------------------------------------------
# Rings, lights, haze
# ---------------------------------------------------------------------------

func ring(owner_id: int, at: Vector3, radius: float, length: float, mid: Color, hot: Color, delay := 0.0,
		width := 0.16, intensity := 0.85, ripples := 0.0, gather := false) -> bool:
	if not VfxBudget.can_decorate():
		return false
	var slot := -1
	for i in _rings.size():
		if _r_live[i] == 0:
			slot = i
			break
	if slot < 0 and _rings.size() < RINGS:
		var node := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(2, 2)
		node.mesh = plane
		var mat := ShaderMaterial.new()
		mat.shader = RING_SHADER
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visible = false
		add_child(node)
		_rings.append(node)
		_r_mats.append(mat)
		_r_start.append(0.0)
		_r_len.append(0.0)
		_r_owner.append(0)
		_r_live.append(0)
		_r_hero.append(0)
		slot = _rings.size() - 1
	if slot < 0:
		slot = 0
		for i in _rings.size():
			if _r_start[i] + _r_len[i] < _r_start[slot] + _r_len[slot]:
				slot = i
		stolen += 1
		_retire_ring(slot)
	var node := _rings[slot]
	node.global_position = at + Vector3(0, 0.14, 0)
	node.scale = Vector3(radius, 1.0, radius)
	node.rotation = Vector3(0, randf() * TAU, 0)
	var mat := _r_mats[slot]
	mat.set_shader_parameter("color", mid)
	mat.set_shader_parameter("core", hot)
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("width", width)
	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("ripples", ripples)
	mat.set_shader_parameter("gather", 1.0 if gather else 0.0)
	mat.set_shader_parameter("seed", randf())
	_r_start[slot] = _clock + maxf(0.0, delay)
	_r_len[slot] = maxf(0.08, length)
	_r_owner[slot] = owner_id
	_r_live[slot] = 2
	_r_hero[slot] = 1 if VfxBudget.reserve_decoration() else 0
	_active += 1
	borrowed += 1
	_wake()
	return true


func _retire_ring(i: int) -> void:
	if _r_live[i] == 0:
		return
	_r_live[i] = 0
	_active -= 1
	_rings[i].visible = false
	VfxBudget.release_decoration(_r_hero[i] == 1)


## A flash (mode 0) or a rising charge (mode 1). Lights are the scarcest
## resource: high quality and no memory pressure only (VfxBudget.claim_light).
func light(owner_id: int, at: Vector3, color: Color, energy: float, reach: float, length: float, delay := 0.0, charge := false) -> bool:
	var slot := -1
	for i in _lights.size():
		if _l_live[i] == 0:
			slot = i
			break
	if slot < 0 and _lights.size() < LIGHTS:
		var node := OmniLight3D.new()
		node.shadow_enabled = false
		node.light_energy = 0.0
		node.visible = false
		node.omni_attenuation = 0.9
		add_child(node)
		_lights.append(node)
		_l_start.append(0.0)
		_l_len.append(0.0)
		_l_peak.append(0.0)
		_l_mode.append(0)
		_l_owner.append(0)
		_l_live.append(0)
		slot = _lights.size() - 1
	if slot < 0 or not VfxBudget.claim_light():
		return false
	var node := _lights[slot]
	node.global_position = at
	node.light_color = color
	node.omni_range = reach
	node.light_energy = 0.0
	_l_start[slot] = _clock + maxf(0.0, delay)
	_l_len[slot] = maxf(0.08, length)
	_l_peak[slot] = energy
	_l_mode[slot] = 1 if charge else 0
	_l_owner[slot] = owner_id
	_l_live[slot] = 2
	_active += 1
	borrowed += 1
	_wake()
	return true


func _retire_light(i: int) -> void:
	if _l_live[i] == 0:
		return
	_l_live[i] = 0
	_active -= 1
	_lights[i].visible = false
	_lights[i].light_energy = 0.0
	VfxBudget.free_light()


func haze(owner_id: int, at: Vector3, size: float, length: float, tint: Color, delay := 0.0) -> bool:
	if _h_live or not VfxBudget.can_decorate():
		return false
	if _haze == null:
		_haze = MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		_haze.mesh = quad
		_haze_mat = ShaderMaterial.new()
		_haze_mat.shader = HAZE_SHADER
		_haze.material_override = _haze_mat
		_haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_haze.visible = false
		add_child(_haze)
	_haze.global_position = at
	_haze.scale = Vector3(size, size * 1.25, size)
	_haze_mat.set_shader_parameter("fade", 0.0)
	_haze_mat.set_shader_parameter("tint", tint)
	_h_start = _clock + maxf(0.0, delay)
	_h_len = maxf(0.1, length)
	_h_owner = owner_id
	_h_live = true
	_h_hero = VfxBudget.reserve_decoration()
	_active += 1
	borrowed += 1
	_wake()
	return true


func _retire_haze() -> void:
	if not _h_live:
		return
	_h_live = false
	_active -= 1
	_haze.visible = false
	VfxBudget.release_decoration(_h_hero)


# ---------------------------------------------------------------------------
# Clock
# ---------------------------------------------------------------------------

func _wake() -> void:
	if not is_processing():
		set_process(true)


func _process(delta: float) -> void:
	_clock += delta
	for i in _emitters.size():
		var live := _e_live[i]
		if live == 0:
			continue
		if not is_instance_id_valid(_e_owner[i]) or _clock >= _e_end[i]:
			_retire_emitter(i)
			continue
		var p := _emitters[i]
		if live == 2 and _clock >= _e_start[i]:
			_e_live[i] = 1
			p.visible = true
			p.restart()
			p.emitting = true
		elif live == 1 and not p.one_shot and p.emitting and _clock >= _e_stop[i]:
			p.emitting = false
	for i in _rings.size():
		if _r_live[i] == 0:
			continue
		var t := (_clock - _r_start[i]) / _r_len[i]
		if not is_instance_id_valid(_r_owner[i]) or t >= 1.0:
			_retire_ring(i)
			continue
		if t >= 0.0:
			if _r_live[i] == 2:
				_r_live[i] = 1
				_rings[i].visible = true
			_r_mats[i].set_shader_parameter("progress", t)
	for i in _lights.size():
		if _l_live[i] == 0:
			continue
		var t := (_clock - _l_start[i]) / _l_len[i]
		if not is_instance_id_valid(_l_owner[i]) or t >= 1.0:
			_retire_light(i)
			continue
		if t >= 0.0:
			if _l_live[i] == 2:
				_l_live[i] = 1
				_lights[i].visible = true
			var k := 0.0
			if _l_mode[i] == 1:
				k = t * t * (3.0 - 2.0 * t)
			else:
				# A sharp 8% rise, then an eased, slightly lingering fall.
				k = t / 0.08 if t < 0.08 else pow(1.0 - (t - 0.08) / 0.92, 2.2)
			_lights[i].light_energy = _l_peak[i] * k
	if _h_live:
		var t := (_clock - _h_start) / _h_len
		if not is_instance_id_valid(_h_owner) or t >= 1.0:
			_retire_haze()
		elif t >= 0.0:
			_haze.visible = true
			_haze_mat.set_shader_parameter("fade", smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.55, 1.0, t)))
	if _active <= 0:
		_active = 0
		set_process(false)


## Ends everything at once (a zone change, tests). Reservations are returned.
func stop_all() -> void:
	for i in _emitters.size():
		_retire_emitter(i)
	for i in _rings.size():
		_retire_ring(i)
	for i in _lights.size():
		_retire_light(i)
	_retire_haze()
	_active = 0
	set_process(false)


func _exit_tree() -> void:
	stop_all()
	# The shared cards belong to SkillLayers' static cache, which a quitting game
	# may free first: let go of them here.
	for p in _emitters:
		p.mesh = null
	for node in _rings:
		node.mesh = null
	if _haze:
		_haze.mesh = null
