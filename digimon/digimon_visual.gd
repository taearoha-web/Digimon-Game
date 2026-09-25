class_name DigimonVisual
extends Node3D
## Visual representation of a Digimon species, used in the world, battles and
## menu previews.
##
## * If the species has a [member DigimonSpecies.model_path], that scene is
##   instanced and its AnimationPlayer is expected to follow the creature
##   animation contract: idle, walk, run, attack, skill, hurt, defeat, victory.
## * Otherwise an ORIGINAL placeholder is built by PlaceholderDigimonFactory.

signal species_changed()

const ANIMATION_FALLBACKS := {
	&"run": [&"walk", &"idle"],
	&"walk": [&"run", &"idle"],
	&"skill": [&"attack", &"idle"],
	&"attack": [&"skill", &"idle"],
	&"hurt": [&"idle"],
	&"defeat": [&"hurt", &"idle"],
	&"victory": [&"idle"],
}

var species: DigimonSpecies
var model: Node3D
var model_height: float = 1.0
var current_animation: StringName = &""

var _anim: AnimationPlayer
var _flash_material: StandardMaterial3D
var _flash_tween: Tween


func set_species(value: Variant) -> void:
	var new_species: DigimonSpecies = null
	if value is DigimonSpecies:
		new_species = value
	elif value is StringName or value is String:
		new_species = _registry().get_species(StringName(value)) if _registry() else null
	if new_species == species and model != null:
		return
	species = new_species
	_rebuild()
	species_changed.emit()


func play_animation(anim_name: StringName, blend := 0.18) -> void:
	var resolved := _resolve(anim_name)
	if resolved == &"" or _anim == null:
		return
	if current_animation == resolved and _anim.is_playing():
		return
	current_animation = resolved
	_anim.play(resolved, blend)


## Plays a one-shot animation and waits for it; then plays [param then_anim]
## (pass &"" to hold the last frame, e.g. for "defeat").
func play_once(anim_name: StringName, then_anim: StringName = &"idle") -> void:
	var resolved := _resolve(anim_name)
	if resolved == &"" or _anim == null:
		return
	current_animation = resolved
	_anim.play(resolved, 0.08)
	var anim_res := _anim.get_animation(resolved)
	if anim_res.loop_mode != Animation.LOOP_NONE:
		# Looping clips never emit animation_finished: play one cycle.
		await get_tree().create_timer(anim_res.length).timeout
	else:
		await _anim.animation_finished
	if not is_inside_tree():
		return
	if then_anim != &"" and current_animation == resolved:
		play_animation(then_anim)


## Brief colour flash (hit feedback) using a material overlay.
func flash(color := Color(1, 1, 1), duration := 0.18) -> void:
	if model == null:
		return
	if _flash_material == null:
		_flash_material = StandardMaterial3D.new()
		_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_material.albedo_color = Color(color.r, color.g, color.b, 0.85)
	var meshes := MeshKit.collect_meshes(model)
	for mi in meshes:
		mi.material_overlay = _flash_material
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_material, "albedo_color:a", 0.0, duration)
	_flash_tween.tween_callback(func():
		for mi in meshes:
			if is_instance_valid(mi):
				mi.material_overlay = null)


func get_hover_offset() -> float:
	return float(model.get_meta("hover", 0.0)) if model else 0.0


func get_animation_player() -> AnimationPlayer:
	return _anim


func _rebuild() -> void:
	if model:
		remove_child(model)
		model.queue_free()
	model = null
	_anim = null
	current_animation = &""
	if species == null:
		return
	if species.model_path != "" and ResourceLoader.exists(species.model_path):
		var packed := load(species.model_path) as PackedScene
		if packed:
			model = packed.instantiate() as Node3D
			_anim = _find_animation_player(model)
			model_height = 1.2
	if model == null:
		model = PlaceholderDigimonFactory.build(species)
		_anim = ProceduralAnimator.build_creature(model, species.hovers)
		model_height = float(model.get_meta("height", 1.0))
	model.scale = Vector3.ONE * species.model_scale
	add_child(model)
	play_animation(&"idle", 0.0)


func _resolve(anim_name: StringName) -> StringName:
	if _anim == null:
		return &""
	if _anim.has_animation(anim_name):
		return anim_name
	for fallback in ANIMATION_FALLBACKS.get(anim_name, []):
		if _anim.has_animation(fallback):
			return fallback
	return &""


static func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _registry() -> Node:
	var loop := Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("GameData") if loop is SceneTree else null
