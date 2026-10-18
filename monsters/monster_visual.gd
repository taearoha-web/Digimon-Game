class_name MonsterVisual
extends Node3D
## A Quaternius monster model scaled to a target height, standing on the
## ground (or hovering), with its clip names mapped to idle / walk / run /
## attack / hurt / die.

const DIR := "res://assets/models/monsters/"
const CLIP_ALIASES := {
	"idle": ["Idle", "Flying_Idle", "Flying"],
	"walk": ["Walk", "Flying_Idle", "Flying"],
	"run": ["Run", "Fast_Flying", "Walk", "Flying"],
	"attack": ["Bite_Front", "Punch", "Headbutt", "Attack"],
	"hurt": ["HitRecieve", "HitReact", "Hit"],
	"die": ["Death"],
	"skill1": ["Skill1"],
	"skill2": ["Skill2"],
}
const LOOPING: Array[String] = ["idle", "walk", "run"]
## Models whose front is not +Z, turned at load so they face where they walk.
const FACING_FIX := {"dawn/Slime": -PI * 0.5}
## Models whose file carries one clip only: extra clip names, either the file's own clip ("")
## or a saved Animation resource, plus how fast a clip plays (the demon's punch is 1.1 s long).
const EXTRA_CLIPS := {
	"summon/ChibiDemon": {"Idle": "", "Walk": "", "Run": "", "Attack": "res://assets/models/monsters/summon/ChibiDemon_punch.res"},
}
const CLIP_SPEED := {"summon/ChibiDemon": {"attack": 2.4}}

var model: Node3D
var anim: AnimationPlayer
var height := 1.0
var current := ""
var busy_until := 0

var _clips: Dictionary = {}
var _clip_speed: Dictionary = {}
var _tween: Tween
var _rest_scale := Vector3.ONE
var _ground_offset := 0.0
var _hover := 0.0
var _idle_phase := 0.0
var _soft_body := false
var _motion_weight := 0.0


func setup(model_path: String, target_height: float, hover := 0.0, tint := Color.WHITE) -> void:
	if is_instance_valid(model):
		model.free()
	_clips.clear()
	current = ""
	busy_until = 0
	_motion_weight = 0.0
	var path := DIR + model_path + ".gltf"
	for ext in [".glb", ".fbx"]:
		if ResourceLoader.exists(DIR + model_path + ext):
			path = DIR + model_path + ext
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("MonsterVisual: missing %s" % model_path)
		return
	model = packed.instantiate() as Node3D
	model.rotation.y += float(FACING_FIX.get(model_path, 0.0))
	add_child(model)
	var box := _bounds(model)
	if maxf(box.size.y, box.size.z) < 0.05:
		box = _bone_bounds(model, box)
	# Bind-pose bounds include T-posed arms and spread wings: size by height/depth.
	var measured := maxf(maxf(box.size.y, box.size.z), 0.001)
	var fit := target_height / measured
	model.scale = Vector3.ONE * fit
	model.position.y = -box.position.y * fit + hover
	_rest_scale = model.scale
	_ground_offset = -box.position.y * fit
	_hover = hover
	_idle_phase = float(absi(model_path.hash()) % 100) * 0.063
	_soft_body = model_path.contains("Blob") or model_path.contains("Glub") or model_path.contains("Ghost")
	height = target_height + hover
	_apply_finish(tint, fit)
	anim = _find_player(model)
	_clip_speed = CLIP_SPEED.get(model_path, {})
	if anim and EXTRA_CLIPS.has(model_path):
		_add_extra_clips(model_path)
	if anim:
		# Older FBX packs name clips "BatArmature|Bat_Flying": match them by the
		# part after the armature and the model's own name.
		var names := {}
		var base := model_path.get_file()
		for clip in anim.get_animation_list():
			var short := String(clip).get_slice("|", String(clip).get_slice_count("|") - 1)
			if short.begins_with(base + "_"):
				short = short.substr(base.length() + 1)
			if not names.has(short):
				names[short] = clip
			names[String(clip)] = clip
		for key in CLIP_ALIASES:
			for alias in CLIP_ALIASES[key]:
				if names.has(alias):
					var clip: StringName = names[alias]
					_clips[key] = clip
					var a := anim.get_animation(clip)
					a.loop_mode = Animation.LOOP_LINEAR if key in LOOPING else Animation.LOOP_NONE
					break
	play("idle")
	set_process(true)


func _add_extra_clips(model_path: String) -> void:
	var own := anim.get_animation_list()
	if own.is_empty():
		return
	var lib := anim.get_animation_library("")
	for clip in EXTRA_CLIPS[model_path]:
		var path: String = EXTRA_CLIPS[model_path][clip]
		var res: Animation = anim.get_animation(own[0]) if path == "" else load(path) as Animation
		if res != null and not lib.has_animation(clip):
			lib.add_animation(clip, res)


## The same soft illustrated finish as the heroes, with a satin gloss reserved
## for jelly creatures. Outline width is measured in world space after fitting.
func _apply_finish(tint: Color, fit: float) -> void:
	var width := 0.009 / maxf(fit, 0.001) if GameSettings.quality > 0 else 0.0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		if not GameSettings.world_shadows():
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in mi.mesh.get_surface_count():
			var source := mi.get_active_material(i) as StandardMaterial3D
			if source:
				mi.set_surface_override_material(i, StorybookFinish.material(source, tint, width, _soft_body))


func _process(delta: float) -> void:
	if model == null or has_meta("freeze_expression"):
		return
	# Small idle-only breathing complements authored clips. Attack, hit and death
	# silhouettes stay precise, and low quality skips this extra presentation work.
	var target := 1.0 if current == "idle" and GameSettings.quality > 0 else 0.0
	_motion_weight = move_toward(_motion_weight, target, delta * 5.0)
	_idle_phase += delta * (2.8 if _soft_body else 1.9)
	var wave := sin(_idle_phase) * _motion_weight
	var stretch := 1.0 + wave * (0.024 if _soft_body else 0.008)
	model.scale = _rest_scale * Vector3(1.0 / sqrt(stretch), stretch, 1.0 / sqrt(stretch))
	var bob := wave * minf(height * 0.022, 0.06) if _hover > 0.0 else 0.0
	model.position.y = _ground_offset * stretch + _hover + bob


func play(key: String, speed := 1.0) -> void:
	if anim == null or not _clips.has(key) or Time.get_ticks_msec() < busy_until:
		return
	if current == key and anim.is_playing():
		return
	current = key
	anim.speed_scale = speed * float(_clip_speed.get(key, 1.0))
	anim.play(_clips[key], 0.15)


func action(key: String, lock_ms := 450, speed := 1.0) -> void:
	if anim == null or not _clips.has(key):
		return
	busy_until = Time.get_ticks_msec() + lock_ms
	current = key
	anim.speed_scale = speed * float(_clip_speed.get(key, 1.0))
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
	MaterialKeeper.keep(overlay)
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


## Rigs exported in centimetres (Mixamo) keep their mesh bounds in a different unit
## from the skeleton: measure the bones instead, with room for horns and soles.
static func _bone_bounds(node: Node3D, fallback: AABB) -> AABB:
	var skeletons := node.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return fallback
	var sk := skeletons[0] as Skeleton3D
	var t := Transform3D.IDENTITY
	var n: Node = sk
	while n != null and n != node:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	var box := AABB()
	for i in sk.get_bone_count():
		var p := t * sk.get_bone_global_rest(i).origin
		box = AABB(p, Vector3.ZERO) if i == 0 else box.expand(p)
	box.position += Vector3(-0.05, -0.04, -0.05)
	box.size += Vector3(0.1, 0.16, 0.1)
	return box


static func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found:
			return found
	return null
