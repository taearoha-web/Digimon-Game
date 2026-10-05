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

## Imported models name their clips freely; each contract clip maps to the
## first clip found in this list (Quaternius "Ultimate Monsters" names here).
const CLIP_ALIASES := {
	&"idle": [&"Idle", &"Flying_Idle"],
	&"walk": [&"Walk", &"Flying_Idle"],
	&"run": [&"Run", &"Fast_Flying", &"Walk"],
	&"attack": [&"Bite_Front", &"Punch", &"Headbutt"],
	&"skill": [&"Weapon", &"Headbutt", &"Jump", &"Punch"],
	&"hurt": [&"HitRecieve", &"HitReact"],
	&"defeat": [&"Death"],
	&"victory": [&"Dance", &"Yes", &"Wave"],
}
const LOOPING_CLIPS: Array[StringName] = [&"idle", &"walk", &"run", &"victory"]

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
			model = _wrap_imported(packed.instantiate() as Node3D)
	if model == null:
		model = PlaceholderDigimonFactory.build(species)
		_anim = ProceduralAnimator.build_creature(model, species.hovers)
		model_height = float(model.get_meta("height", 1.0))
	model.scale = Vector3.ONE * species.model_scale
	add_child(model)
	play_animation(&"idle", 0.0)


## Normalises an imported model: scales it to the species' target height,
## sits its feet on the ground (or hovering), adds a blob shadow and aliases
## its clips to the creature animation contract. Returns the wrapper root.
func _wrap_imported(imported: Node3D) -> Node3D:
	if imported == null:
		return null
	var root := Node3D.new()
	root.name = "ImportedModel"
	root.add_child(imported)
	var box := _mesh_bounds(imported)
	# Bounds are measured in the bind pose: T-posed arms/wings inflate the
	# width, and flyers fold their wings up when animated, so size by the
	# larger of height and depth.
	var height := maxf(maxf(box.size.y, box.size.z), 0.001)
	var fit := species.model_target_height / height if species.model_target_height > 0.0 else 1.0
	imported.scale = Vector3.ONE * fit
	var hover := 0.0
	if species.hovers:
		hover = 0.35 if species.model_target_height < 1.4 else 0.5
	imported.position.y = -box.position.y * fit + hover
	root.set_meta("hover", hover)
	model_height = (height * fit + hover) * species.model_scale
	MeshKit.blob_shadow(root, clampf(maxf(box.size.x, box.size.z) * fit * 0.3, 0.25, 1.3))
	_anim = _find_animation_player(imported)
	_alias_clips()
	return root


func _alias_clips() -> void:
	if _anim == null:
		return
	var aliases := AnimationLibrary.new()
	for contract in CLIP_ALIASES:
		if _anim.has_animation(contract):
			continue
		for clip in CLIP_ALIASES[contract]:
			if _anim.has_animation(clip):
				# Duplicate so loop changes never leak into the shared import.
				var a := _anim.get_animation(clip).duplicate() as Animation
				a.loop_mode = Animation.LOOP_LINEAR if contract in LOOPING_CLIPS else Animation.LOOP_NONE
				aliases.add_animation(contract, a)
				break
	if _anim.has_animation_library(&"contract"):
		_anim.remove_animation_library(&"contract")
	_anim.add_animation_library(&"contract", aliases)


static func _mesh_bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b := _relative_transform(m, node) * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


static func _relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != ancestor:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _resolve(anim_name: StringName) -> StringName:
	if _anim == null:
		return &""
	for candidate in [anim_name] + ANIMATION_FALLBACKS.get(anim_name, []):
		if _anim.has_animation(candidate):
			return candidate
		var aliased := StringName("contract/" + candidate)
		if _anim.has_animation(aliased):
			return aliased
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
