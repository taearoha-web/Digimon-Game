class_name ShaderWarm
extends RefCounted
## Draws every effect shader once while a zone loads, so no cast, pet or aura compiles
## one in the middle of a fight. The browser (WebGL, the Compatibility renderer) compiles
## a material's shader the first time something draws it, and a second variant the first
## time a particle emitter or multimesh draws it (instanced): on a phone either is a
## 30-200 ms stall, felt on the first cast of each new effect (the skill layer cards,
## melee art, signature art, the Mage ultimates' pieces) or the first time another
## player's ★100 pet walks in (its rim light).
## A tiny, invisible sample of each (a quad, and a one-particle emitter for those effects
## that draw instanced) sits in front of the hero for a moment and is freed again. The
## compiled program is kept by the Shader resource, which the effects preload, so every
## later material of the same shader finds it ready.

## Effect shaders drawn on plain meshes.
const MESH_SHADERS: Array[String] = [
	"res://shaders/skill_layer_ring.gdshader",
	"res://shaders/skill_layer_haze.gdshader",
	"res://shaders/skill_layer_glow.gdshader",
	"res://shaders/skill_layer_smoke.gdshader",
	"res://shaders/melee_art.gdshader",
	"res://shaders/melee_glow.gdshader",
	"res://shaders/melee_chain.gdshader",
	"res://shaders/signature_glow.gdshader",
	"res://shaders/signature_ink.gdshader",
	"res://shaders/pet_form_rim.gdshader",
	"res://shaders/summon_aura.gdshader",
	"res://shaders/martial_art.gdshader",
	"res://shaders/star_skill.gdshader",
	"res://shaders/shadow_glow.gdshader",
	"res://shaders/shadow_ink.gdshader",
	"res://shaders/shadow_wing.gdshader",
	"res://shaders/shadow_wing_glow.gdshader",
	"res://shaders/elite_skill.gdshader",
	"res://shaders/vfx_spirit.gdshader",
]
## Effect shaders that particles or multimeshes draw (the instanced variant).
const INSTANCED_SHADERS: Array[String] = [
	"res://shaders/skill_layer_glow.gdshader",
	"res://shaders/skill_layer_smoke.gdshader",
	"res://shaders/melee_spark.gdshader",
	"res://shaders/melee_debris.gdshader",
	"res://shaders/summon_aura.gdshader",
]
## Seconds the samples stay drawn.
const HOLD := 0.4

## Off in tests that count a zone's nodes right after it loads.
static var enabled := true
## Samples drawn by the last warm (tests).
static var last_count := 0


## Draws the samples near [param at] (the hero, in view) under [param parent]; with a
## [param slicer] the mesh and instanced batches go on separate frames.
static func warm(parent: Node3D, at: Vector3, slicer: SceneTree = null) -> void:
	last_count = 0
	if not enabled or parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var holder := Node3D.new()
	holder.name = "ShaderWarm"
	parent.add_child(holder)
	holder.global_position = at + Vector3(0, 1.0, 0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.01, 0.01)
	for path in MESH_SHADERS:
		var mat := _material(path)
		if mat == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = mat
		holder.add_child(mi)
		last_count += 1
	await FrameSlicer.pace(slicer)
	if not is_instance_valid(holder):
		return
	for path in INSTANCED_SHADERS:
		var mat := _material(path)
		if mat == null:
			continue
		var p := CPUParticles3D.new()
		p.amount = 1
		p.lifetime = HOLD
		p.mesh = quad
		p.material_override = mat
		p.gravity = Vector3.ZERO
		p.initial_velocity_min = 0.0
		p.initial_velocity_max = 0.0
		p.emitting = true
		holder.add_child(p)
		last_count += 1
	holder.get_tree().create_timer(HOLD).timeout.connect(holder.queue_free)


static func _material(path: String) -> ShaderMaterial:
	var shader := load(path) as Shader
	if shader == null:
		return null
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat
