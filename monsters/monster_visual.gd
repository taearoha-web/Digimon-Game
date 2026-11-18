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
## Remastered models (built by tools/blender/remaster_monsters.py): a file at
## REMASTER_DIR + "<dir>/<Name>.glb" stands in for that model wherever it is used, with
## the same rig and clip names. Off only for before/after review shots.
const REMASTER_DIR := DIR + "remaster/"
static var use_remaster := true

var model: Node3D
var anim: AnimationPlayer
var height := 1.0
var current := ""
var busy_until := 0
## The ink outline (a second draw of every surface); everyone else's pets wear it at
## high quality only (set before setup).
var outline := true

var _clips: Dictionary = {}
var _clip_speed: Dictionary = {}
var _tween: Tween
var _flash_restore: Dictionary = {}
## The overlay of the hit flash on now (null when none).
var _flash_overlay: Material
var _rest_scale := Vector3.ONE
var _ground_offset := 0.0
var _hover := 0.0
var _idle_phase := 0.0
var _soft_body := false
var _motion_weight := 0.0


## [param model_path] is a monster under DIR without extension ("big/Dino"), or a full
## "res://" path (the pets, PetData). [param skin] replaces the model's albedo texture
## (a repainted palette: the earth pet's stone golem).
func setup(model_path: String, target_height: float, hover := 0.0, tint := Color.WHITE, skin: Texture2D = null) -> void:
	if is_instance_valid(model):
		model.free()
	_clips.clear()
	current = ""
	busy_until = 0
	_motion_weight = 0.0
	var path := DIR + model_path + ".gltf"
	if model_path.begins_with("res://"):
		path = model_path
	else:
		for ext in [".glb", ".fbx"]:
			if ResourceLoader.exists(DIR + model_path + ext):
				path = DIR + model_path + ext
		if use_remaster and ResourceLoader.exists(REMASTER_DIR + model_path + ".glb"):
			path = REMASTER_DIR + model_path + ".glb"
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("MonsterVisual: missing %s" % model_path)
		return
	model = packed.instantiate() as Node3D
	model.rotation.y += float(FACING_FIX.get(model_path, 0.0))
	add_child(model)
	_flash_meshes.clear()
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
	_apply_finish(tint, fit, skin)
	anim = _find_player(model)
	_clip_speed = CLIP_SPEED.get(model_path, {})
	if anim and EXTRA_CLIPS.has(model_path):
		_add_extra_clips(model_path)
	if anim:
		# Older FBX packs name clips "BatArmature|Bat_Flying": match them by the
		# part after the armature and the model's own name.
		var names := {}
		var base := model_path.get_file().get_basename() if model_path.begins_with("res://") else model_path.get_file()
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
func _apply_finish(tint: Color, fit: float, skin: Texture2D = null) -> void:
	var width := 0.009 / maxf(fit, 0.001) if GameSettings.quality > 0 and outline else 0.0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		if not GameSettings.world_shadows():
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The outline grows in the mesh's own space: the FBX rigs (dawn/Bat, dawn/Dragon,
		# dawn/Slime) carry a x100 node scale, which would blow it up into shards.
		var nested := 1.0
		var up: Node = mi
		while up != model and up is Node3D:
			nested *= absf((up as Node3D).scale.x)
			up = up.get_parent()
		var mesh_width := width / maxf(nested, 0.0001)
		for i in mi.mesh.get_surface_count():
			var source := mi.get_active_material(i) as StandardMaterial3D
			if source and skin:
				var painted := source.duplicate() as StandardMaterial3D
				painted.albedo_texture = skin
				painted.set_meta("storybook_key", "%s|%s" % [source.resource_path, skin.resource_path])
				source = painted
			if source:
				# Remastered parts on an "Ivory*" (bone, tusks, glowing eyes) or "Keep*" material
				# (eyes, teeth, glowing marks) keep their own painted colour under a tint.
				var mat_name := String(source.resource_name)
				var own_tint := Color.WHITE if mat_name.begins_with("Ivory") or mat_name.begins_with("Keep") else tint
				mi.set_surface_override_material(i, StorybookFinish.material(source, own_tint, mesh_width, _soft_body))


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


# ---------------------------------------------------------------------------
# Boss casts (BossCast): the rigs carry no cast clips, so a special move's wind-up is
# played procedurally. The move's clip (attack, or Poseidon's Skill1/2) creeps through
# its anticipation in slow motion and freezes there, while this node leans back / rises
# / crouches; the release fast-plays the rest of the clip with a strike lean and a
# squash. The body lives on this node's own transform (rest: origin, no tilt, unit
# scale), so Mob's yaw (rotation.y) and the model's breathing are left alone.
# ---------------------------------------------------------------------------

## How far into the clip the wind-up frame sits (the anticipation of the rigs' strikes).
const CAST_ANTICIPATION := 0.32
var _cast_tween: Tween
var _cast_mat: StandardMaterial3D
var _cast_clip := ""
var _cast_pose := ""
var _cast_serial := 0
var casting := false


## The body's wind-up for [param pose] ("rear", "crouch", "raise"):
## {lean (rad, minus = back), lift (m), sx, sy (scale)}. Hovering bodies rise higher.
func cast_body(pose: String) -> Dictionary:
	var air := _hover > 0.05
	match pose:
		"crouch":
			return {"lean": 0.08, "lift": 0.0, "sx": 1.12, "sy": 0.82}
		"raise":
			return {"lean": -0.16, "lift": height * (0.18 if air else 0.07), "sx": 1.05, "sy": 1.13}
	return {"lean": -0.3, "lift": height * (0.08 if air else 0.03), "sx": 1.03, "sy": 1.08}


## Starts the wind-up: [param secs] to draw into the pose, then [param hold] seconds
## held there (cast_release lets go). [param clip] is the move's clip.
func cast_windup(secs: float, hold: float, clip: String, pose: String) -> void:
	cast_cancel()
	casting = true
	_cast_pose = pose
	secs = maxf(secs, 0.1)
	_cast_clip_windup(secs, hold, clip)
	var p := cast_body(pose)
	_cast_tween = create_tween().set_parallel(true)
	_cast_tween.tween_property(self, "rotation:x", float(p.lean), secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cast_tween.tween_property(self, "position:y", float(p.lift), secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cast_tween.tween_property(self, "scale", Vector3(float(p.sx), float(p.sy), float(p.sx)), secs).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The clip's part of the wind-up: slow-motion into the anticipation frame, then frozen.
func _cast_clip_windup(secs: float, hold: float, clip: String) -> void:
	if anim == null:
		return
	if not _clips.has(clip):
		clip = "attack"
	if not _clips.has(clip):
		return
	var length := maxf(anim.get_animation(_clips[clip]).length, 0.05)
	_cast_clip = clip
	current = clip
	busy_until = Time.get_ticks_msec() + int((secs + hold + length + 0.5) * 1000.0)
	anim.play(_clips[clip], 0.12)
	anim.speed_scale = length * CAST_ANTICIPATION / secs
	_cast_serial += 1
	var serial := _cast_serial
	var t := create_tween()
	t.tween_interval(secs)
	t.tween_callback(func():
		if casting and serial == _cast_serial and anim != null and _cast_clip != "":
			anim.speed_scale = 0.0)


## The release: the strike plays out fast, the body snaps forward and squashes, then
## eases back to rest over about [param secs].
func cast_release(secs := 0.45) -> void:
	if not casting:
		return
	casting = false
	_cast_clip_release(secs)
	if _cast_tween:
		_cast_tween.kill()
	var p := cast_body(_cast_pose)
	var strike := 0.0 if is_zero_approx(float(p.lean)) else (0.2 if _cast_pose == "rear" else (0.1 if _cast_pose == "raise" else 0.04))
	_cast_tween = create_tween()
	if _cast_pose == "crouch":
		_cast_tween.tween_property(self, "scale", Vector3(0.94, 1.14, 0.94), 0.06)
	_cast_tween.tween_property(self, "rotation:x", strike, 0.08).set_ease(Tween.EASE_OUT)
	_cast_tween.parallel().tween_property(self, "scale", Vector3(1.14, 0.86, 1.14), 0.08)
	_cast_tween.parallel().tween_property(self, "position:y", float(p.lift) * 0.2, 0.08)
	_cast_tween.tween_property(self, "rotation:x", 0.0, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cast_tween.parallel().tween_property(self, "scale", Vector3.ONE, secs).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_cast_tween.parallel().tween_property(self, "position:y", 0.0, secs).set_trans(Tween.TRANS_SINE)
	cast_glow(Color.WHITE, 0.0)


func _cast_clip_release(secs: float) -> void:
	if anim == null or _cast_clip == "" or not _clips.has(_cast_clip):
		_cast_clip = ""
		return
	var length := maxf(anim.get_animation(_clips[_cast_clip]).length, 0.05)
	var left := maxf(length - anim.current_animation_position, 0.05)
	var speed := clampf(left / maxf(secs, 0.1), 1.2, 3.5)
	anim.speed_scale = speed
	busy_until = Time.get_ticks_msec() + int(left / speed * 1000.0) + 80
	_cast_clip = ""


## Stops a cast at once (stun, death, a leash reset): everything back at rest.
func cast_cancel() -> void:
	casting = false
	_cast_serial += 1
	if _cast_tween:
		_cast_tween.kill()
		_cast_tween = null
	rotation.x = 0.0
	position = Vector3.ZERO
	scale = Vector3.ONE
	if anim != null and _cast_clip != "":
		anim.speed_scale = 1.0
		busy_until = 0
	_cast_clip = ""
	cast_glow(Color.WHITE, 0.0)


## The charge glow on the body, [param amount] 0..1 (an additive overlay on the rigs).
## A hit flash covers it while it shows (and hands it back after).
func cast_glow(color: Color, amount: float) -> void:
	if model == null:
		return
	if amount <= 0.001:
		if _cast_mat == null:
			return
		for mi in _flash_targets():
			if is_instance_valid(mi) and (mi as MeshInstance3D).material_overlay == _cast_mat:
				(mi as MeshInstance3D).material_overlay = null
		for mesh in _flash_restore.keys():
			if _flash_restore[mesh] == _cast_mat:
				_flash_restore.erase(mesh)
		return
	if _cast_mat == null:
		_cast_mat = StandardMaterial3D.new()
		_cast_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_cast_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cast_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_cast_mat.albedo_color = Color(color.r, color.g, color.b, clampf(amount, 0.0, 1.0) * 0.5)
	for mi in _flash_targets():
		var mesh := mi as MeshInstance3D
		if is_instance_valid(mesh) and mesh.material_overlay == null:
			mesh.material_overlay = _cast_mat


## Where the cast gathers, in this node's space: "mouth" (the head, a little forward)
## or "chest".
func cast_point(part: String) -> Vector3:
	if part == "mouth":
		return Vector3(0, height * 0.82, height * 0.22)
	return Vector3(0, height * 0.55, height * 0.08)


## The hit flash's own overlay and the model's meshes, made once: a crowd hit by one
## blow used to search every model and make a new material per hit.
var _flash_mat: StandardMaterial3D
var _flash_meshes: Array = []


func _flash_targets() -> Array:
	if _flash_meshes.is_empty() and model != null:
		_flash_meshes = model.find_children("*", "MeshInstance3D", true, false)
	return _flash_meshes


func flash(color := Color(1, 1, 1), duration := 0.16) -> void:
	if model == null:
		return
	var meshes := _flash_targets()
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		MaterialKeeper.keep(_flash_mat)
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var overlay := _flash_mat
	overlay.albedo_color = Color(color.r, color.g, color.b, 0.8)
	# A new hit while the last flash is still fading takes that flash off first: kept as
	# if it were a lasting overlay, its half-faded tint stayed on for good (red heroes).
	if _tween:
		_tween.kill()
	_end_flash()
	for mi in meshes:
		var mesh := mi as MeshInstance3D
		if mesh.material_overlay != null and mesh.material_overlay != overlay:
			_flash_restore[mesh] = mesh.material_overlay
		mesh.material_overlay = overlay
	_flash_overlay = overlay
	_tween = create_tween()
	_tween.tween_property(overlay, "albedo_color:a", 0.0, duration)
	_tween.tween_callback(_end_flash)


## Takes the hit flash off every piece wearing it and hands back what it covered.
func _end_flash() -> void:
	if _flash_overlay != null and is_instance_valid(model):
		for mi in _flash_targets():
			if is_instance_valid(mi) and (mi as MeshInstance3D).material_overlay == _flash_overlay:
				(mi as MeshInstance3D).material_overlay = null
	_flash_overlay = null
	_restore_overlays()


## Overlays a flash covered (a summon's spirit glow) come back when it fades.
func _restore_overlays() -> void:
	for mesh in _flash_restore:
		if is_instance_valid(mesh) and is_instance_valid(_flash_restore[mesh]):
			(mesh as MeshInstance3D).material_overlay = _flash_restore[mesh]
	_flash_restore.clear()


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
