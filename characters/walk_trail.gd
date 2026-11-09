class_name WalkTrail
extends Node3D
## A walk trail (เอฟเฟกต์ท่าเดิน, RewardShop.TRAILS): particles left behind a character's
## steps while it moves. Decorative only: it takes its particles from VfxBudget
## (track_particles) and is not built at all at the low quality setting or while memory
## is tight (MemoryGuard.pressure), so a crowded field on a phone never pays for it.
## `attach` puts one on a character body (Hero, FieldPlayer, RemotePlayer); `detach`
## removes whatever trail the body has.

const NODE_NAME := "WalkTrail"
const PARTICLES := 24
const MOVE_SPEED := 0.6
## The lowest quality that shows a trail.
const MIN_QUALITY := 1

var trail_id := ""
var _emitter: CPUParticles3D
var _last := Vector3.INF


## Whether a trail may be built now (the quality setting and the memory pressure).
static func allowed() -> bool:
	return VfxBudget.quality() >= MIN_QUALITY and MemoryGuard.pressure == 0


## Puts trail `id` on `body` (replacing the one it has). Null when `id` is "", unknown,
## or trails are off right now.
static func attach(body: Node3D, id: String) -> WalkTrail:
	detach(body)
	if id == "" or not RewardShop.TRAILS.has(id) or not allowed():
		return null
	var t := WalkTrail.new()
	t.name = NODE_NAME
	t.trail_id = id
	body.add_child(t)
	return t if t._emitter != null else null


static func detach(body: Node3D) -> void:
	var old := body.get_node_or_null(NODE_NAME)
	if old != null:
		old.free()


## The trail body `body` wears ("" for none).
static func worn(body: Node3D) -> String:
	var t := body.get_node_or_null(NODE_NAME) as WalkTrail
	return t.trail_id if t != null else ""


func _ready() -> void:
	var spec: Dictionary = RewardShop.TRAILS.get(trail_id, {})
	var color: Color = spec.get("color", Color.WHITE)
	var p := CPUParticles3D.new()
	p.name = "Emitter"
	var quad := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = VfxKit.soft_dot()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.85)
	quad.material = mat
	p.mesh = quad
	p.lifetime = 0.9
	p.local_coords = false
	p.emitting = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.gravity = Vector3.ZERO
	p.color_ramp = VfxKit._fade_ramp()
	p.position = Vector3(0, 0.15, 0)
	match trail_id:
		"sparkle":
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			quad.size = Vector2(0.14, 0.14)
			p.direction = Vector3.UP
			p.spread = 40.0
			p.initial_velocity_min = 0.4
			p.initial_velocity_max = 0.9
		"petal":
			quad.size = Vector2(0.16, 0.1)
			p.direction = Vector3.UP
			p.spread = 70.0
			p.initial_velocity_min = 0.3
			p.initial_velocity_max = 0.7
			p.gravity = Vector3(0, -0.6, 0)
			p.angular_velocity_min = -180.0
			p.angular_velocity_max = 180.0
			p.lifetime = 1.3
		"flame":
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			quad.size = Vector2(0.22, 0.3)
			p.direction = Vector3.UP
			p.spread = 15.0
			p.initial_velocity_min = 0.8
			p.initial_velocity_max = 1.4
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.0
			p.lifetime = 0.6
		"star":
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			quad.size = Vector2(0.2, 0.2)
			p.direction = Vector3.UP
			p.spread = 80.0
			p.initial_velocity_min = 0.2
			p.initial_velocity_max = 0.5
			p.angular_velocity_min = 90.0
			p.angular_velocity_max = 240.0
			p.lifetime = 1.1
		_:
			quad.size = Vector2(0.12, 0.12)
			p.direction = Vector3.UP
			p.spread = 60.0
			p.initial_velocity_min = 0.2
			p.initial_velocity_max = 0.5
			p.gravity = Vector3(0, -0.3, 0)
			p.lifetime = 1.2
	if not VfxBudget.track_particles(p, PARTICLES):
		p.free()
		queue_free()
		return
	_emitter = p
	add_child(p)
	set_process(true)


## Emits only while the body moves (its position changed since the last frame).
func _process(delta: float) -> void:
	if _emitter == null:
		return
	var at := get_parent_node_3d().global_position if get_parent_node_3d() != null else global_position
	var moving := false
	if _last != Vector3.INF and delta > 0.0:
		moving = Vector2(at.x - _last.x, at.z - _last.z).length() / delta > MOVE_SPEED
	_last = at
	if _emitter.emitting != moving:
		_emitter.emitting = moving
