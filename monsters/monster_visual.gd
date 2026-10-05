class_name MonsterVisual
extends Node3D
## A Quaternius monster model scaled to a target height, standing on the
## ground (or hovering), with its clip names mapped to idle / walk / run /
## attack / hurt / die.

const DIR := "res://assets/models/monsters/"
const CLIP_ALIASES := {
	"idle": ["Idle", "Flying_Idle"],
	"walk": ["Walk", "Flying_Idle"],
	"run": ["Run", "Fast_Flying", "Walk"],
	"attack": ["Bite_Front", "Punch", "Headbutt"],
	"hurt": ["HitRecieve", "HitReact"],
	"die": ["Death"],
}
const LOOPING: Array[String] = ["idle", "walk", "run"]

var model: Node3D
var anim: AnimationPlayer
var height := 1.0
var current := ""
var busy_until := 0

var _clips: Dictionary = {}
var _tween: Tween


func setup(model_path: String, target_height: float, hover := 0.0, tint := Color.WHITE) -> void:
	var packed := load(DIR + model_path + ".gltf") as PackedScene
	if packed == null:
		push_error("MonsterVisual: missing %s" % model_path)
		return
	model = packed.instantiate() as Node3D
	add_child(model)
	var box := _bounds(model)
	# Bind-pose bounds include T-posed arms and spread wings: size by height/depth.
	var measured := maxf(maxf(box.size.y, box.size.z), 0.001)
	var fit := target_height / measured
	model.scale = Vector3.ONE * fit
	model.position.y = -box.position.y * fit + hover
	height = target_height + hover
	if tint != Color.WHITE:
		_apply_tint(tint)
	anim = _find_player(model)
	if anim:
		for key in CLIP_ALIASES:
			for clip in CLIP_ALIASES[key]:
				if anim.has_animation(clip):
					_clips[key] = clip
					var a := anim.get_animation(clip)
					a.loop_mode = Animation.LOOP_LINEAR if key in LOOPING else Animation.LOOP_NONE
					break
	play("idle")


## Re-colours the model (variants of the same monster for later zones).
func _apply_tint(tint: Color) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var source := mi.get_active_material(i) as StandardMaterial3D
			if source:
				var copy := source.duplicate() as StandardMaterial3D
				copy.albedo_color = source.albedo_color * tint
				mi.set_surface_override_material(i, copy)


func play(key: String, speed := 1.0) -> void:
	if anim == null or not _clips.has(key) or Time.get_ticks_msec() < busy_until:
		return
	if current == key and anim.is_playing():
		return
	current = key
	anim.speed_scale = speed
	anim.play(_clips[key], 0.15)


func action(key: String, lock_ms := 450, speed := 1.0) -> void:
	if anim == null or not _clips.has(key):
		return
	busy_until = Time.get_ticks_msec() + lock_ms
	current = key
	anim.speed_scale = speed
	anim.play(_clips[key], 0.06)


func hold(key: String) -> void:
	if anim == null or not _clips.has(key):
		return
	busy_until = Time.get_ticks_msec() + 3_600_000
	current = key
	anim.play(_clips[key], 0.08)


func flash(color := Color(1, 1, 1), duration := 0.16) -> void:
	if model == null:
		return
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var overlay := StandardMaterial3D.new()
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	overlay.albedo_color = Color(color.r, color.g, color.b, 0.8)
	for mi in meshes:
		(mi as MeshInstance3D).material_overlay = overlay
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(overlay, "albedo_color:a", 0.0, duration)
	_tween.tween_callback(func():
		for mi in meshes:
			if is_instance_valid(mi):
				(mi as MeshInstance3D).material_overlay = null)


static func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var t := Transform3D.IDENTITY
		var n: Node = m
		while n != null and n != node:
			if n is Node3D:
				t = (n as Node3D).transform * t
			n = n.get_parent()
		var b := t * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


static func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found:
			return found
	return null
