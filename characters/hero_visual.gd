class_name HeroVisual
extends Node3D
## The hero's 3D body: a KayKit character model with its class weapon in the
## hand, and a small animation API (idle / run / one-shot actions).

const CHARACTER_DIR := "res://assets/models/characters/"
const LOOPING: Array[String] = ["Idle", "Running_A", "Running_B", "Walking_A", "Walking_B", "2H_Melee_Idle", "Unarmed_Idle", "Cheer", "Spellcasting", "Blocking", "Sit_Floor_Idle"]
const HEIGHT := 2.0
const PROPS := {
	&"warrior": ["1H_Sword", "Badge_Shield", "Knight_Helmet", "Knight_Cape"],
	&"archer": ["2H_Crossbow", "Rogue_Cape"],
	&"mage": ["2H_Staff", "Mage_Hat", "Mage_Cape"],
	&"priest": ["1H_Wand", "Spellbook", "Mage_Hat", "Mage_Cape"],
}

var class_id: StringName = &"warrior"
var model: Node3D
var anim: AnimationPlayer
var current: String = ""
var busy_until := 0

var _tween: Tween


func setup(p_class: StringName) -> void:
	class_id = p_class
	for child in get_children():
		child.queue_free()
	var data := ClassData.get_class_data(class_id)
	var packed := load(CHARACTER_DIR + String(data.model) + ".glb") as PackedScene
	if packed == null:
		push_error("HeroVisual: missing model %s" % data.model)
		return
	model = packed.instantiate() as Node3D
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		for clip in anim.get_animation_list():
			var a := anim.get_animation(clip)
			a.loop_mode = Animation.LOOP_LINEAR if clip in LOOPING else Animation.LOOP_NONE
	_fit_height()
	_show_props(PROPS[class_id])
	if class_id == &"priest":
		_tint_priest()
	play("Idle")


func _fit_height() -> void:
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var skel := m.get_parent()
		var b := m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	# KayKit rigs report a tall bind-pose box; the standing body is ~2.2 units.
	model.scale = Vector3.ONE * (HEIGHT / 2.2)


## The models carry all their props as bone attachments: show only the class kit.
func _show_props(wanted: Array) -> void:
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	for child in skeleton.get_children():
		if child is BoneAttachment3D:
			child.visible = child.name in wanted


func _tint_priest() -> void:
	var tints := {"Mage_Hat": Color(1.9, 1.6, 0.35), "Mage_Cape": Color(2.2, 2.2, 2.0), "Mage_Body": Color(1.8, 1.8, 1.5),
			"Mage_ArmLeft": Color(1.8, 1.8, 1.5), "Mage_ArmRight": Color(1.8, 1.8, 1.5), "Mage_LegLeft": Color(1.6, 1.6, 1.4), "Mage_LegRight": Color(1.6, 1.6, 1.4)}
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not tints.has(String(m.name)):
			continue
		var source := m.mesh.surface_get_material(0) as StandardMaterial3D
		if source:
			var copy := source.duplicate() as StandardMaterial3D
			copy.albedo_color = tints[String(m.name)]
			m.set_surface_override_material(0, copy)


func has_clip(clip: String) -> bool:
	return anim != null and anim.has_animation(clip)


## Loops a locomotion clip (ignored while a one-shot action is still playing).
func play(clip: String, blend := 0.15, speed := 1.0) -> void:
	if anim == null or not anim.has_animation(clip):
		return
	if Time.get_ticks_msec() < busy_until:
		return
	if current == clip and anim.is_playing():
		return
	current = clip
	anim.speed_scale = speed
	anim.play(clip, blend)


## Plays an action once; locomotion resumes afterwards.
func action(clip: String, speed := 1.0, blend := 0.08) -> float:
	if anim == null or not anim.has_animation(clip):
		return 0.0
	var length := anim.get_animation(clip).length / maxf(speed, 0.1)
	busy_until = Time.get_ticks_msec() + int(length * 1000.0 * 0.92)
	current = clip
	anim.speed_scale = speed
	anim.play(clip, blend)
	return length


func hold_last_frame(clip: String) -> void:
	if anim and anim.has_animation(clip):
		busy_until = Time.get_ticks_msec() + 3_600_000
		current = clip
		anim.speed_scale = 1.0
		anim.play(clip, 0.1)


func release() -> void:
	busy_until = 0
	current = ""


func flash(color := Color(1, 0.35, 0.35), duration := 0.18) -> void:
	if model == null:
		return
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var overlay := StandardMaterial3D.new()
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	overlay.albedo_color = Color(color.r, color.g, color.b, 0.7)
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
