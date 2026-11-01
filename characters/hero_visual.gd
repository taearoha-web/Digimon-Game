class_name HeroVisual
extends Node3D
## The hero's 3D body: a KayKit character model with its class weapon in the
## hand, and a small animation API (idle / run / one-shot actions).

const CHARACTER_DIR := "res://assets/models/characters/"
const LOOPING: Array[String] = ["Idle", "Running_A", "Running_B", "Walking_A", "Walking_B", "2H_Melee_Idle", "Unarmed_Idle", "Cheer", "Spellcasting", "Blocking", "Sit_Floor_Idle"]
const HEIGHT := 2.0
## Ready-made looks per character model: head, outfit (body+arms+legs),
## hat and cape pieces as [glb, node].
const PRESETS := {
	"Knight": {"head": ["Knight", "Knight_Head"], "outfit": "Knight", "hat": ["Knight", "Knight_Helmet"], "cape": ["Knight", "Knight_Cape"]},
	"Mage": {"head": ["Mage", "Mage_Head"], "outfit": "Mage", "hat": ["Mage", "Mage_Hat"], "cape": ["Mage", "Mage_Cape"]},
	"Rogue_Hooded": {"head": ["Rogue_Hooded", "Rogue_Head_Hooded"], "outfit": "Rogue", "cape": ["Rogue_Hooded", "Rogue_Cape"]},
	"Rogue": {"head": ["Rogue", "Rogue_Head"], "outfit": "Rogue", "cape": ["Rogue", "Rogue_Cape"]},
	"Barbarian": {"head": ["Barbarian", "Barbarian_Head"], "outfit": "Barbarian", "hat": ["Barbarian", "Barbarian_BearHat"]},
	"Ranger": {"head": ["Ranger", "Ranger_Head"], "outfit": "Ranger", "cape": ["Ranger", "Ranger_Cape"], "extra": ["Ranger", "Ranger_Quiver"]},
}
const OUTFIT_PARTS: Array[String] = ["Body", "ArmLeft", "ArmRight", "LegLeft", "LegRight"]
const OUTFIT_GLB := {"knight": "Knight", "mage": "Mage", "rogue": "Rogue", "barbarian": "Barbarian", "ranger": "Ranger", "Knight": "Knight", "Mage": "Mage", "Rogue": "Rogue", "Barbarian": "Barbarian", "Ranger": "Ranger"}
const CHIBI_HEAD := 1.28
const BASE_MODEL := "Ranger"
const PRIEST_GOLD := Color(1.9, 1.6, 0.35)
const PRIEST_WHITE := Color(1.8, 1.8, 1.5)

## The player's own hero (and rivals / companions with a look) wear these
## fully rigged chibi models: boy or girl, fixed face and hair. Every KayKit clip
## was retargeted onto their rig (tools/retarget_chibi.py), weapon slots included.
const CHIBI_MODELS := ["res://assets/models/heroes/chibi_boy.glb", "res://assets/models/heroes/chibi_girl.glb"]
const CHIBI_HEIGHT := 2.45
## Where the enhancement glow of wings sits, and the class wing models on a KayKit
## body (chest-bone space; the models are sized for the chibi).
const WING_GLOW := Vector3(0, 1.6, -0.5)
const KAYKIT_WINGS := Transform3D(Vector3(2.2, 0, 0), Vector3(0, 2.2, 0), Vector3(0, 0, 2.2), Vector3(0, -1.0, -0.1))
## KayKit bone names used for gear -> the chibi rig's names.
const CHIBI_BONES := {"chest": "Chest", "head": "Head", "wrist.l": "LeftHand", "wrist.r": "RightHand",
	"lowerleg.l": "LeftLowerLeg", "lowerleg.r": "RightLowerLeg"}

## Wing poses: open and idling, flying (flap in place, glide when moving), folded.
const WING_STAND := 0
const WING_FLY := 1
const WING_FOLD := 2
static var _shared_library: AnimationLibrary

var class_id: StringName = &"warrior"
var model_name := ""
var equip: Dictionary = {}
## Counts re-dresses (refresh), so followers such as the DarkRaven see a gear change.
var dressed := 0
## Custom face/hair (FaceKit); empty = the stock KayKit head of the class model.
var look: Dictionary = {}
var model: Node3D
var anim: AnimationPlayer
var current: String = ""
var busy_until := 0

var _head_bone := -1
var _skeleton: Skeleton3D
var _body_nodes: Array[Node] = []
var _hold_nodes: Array[Node] = []
var _tween: Tween
var _flash_restore: Dictionary = {}
## The overlay of the hit flash on now (null when none).
var _flash_overlay: Material
var _face: FaceExpression
## True for the rigged chibi models; gear built for KayKit units is scaled by _gear_scale.
var chibi := false
## The cheap dressing of the other players seen around (set before setup): their
## enhancement glow keeps the overlays, rings and halos but at most one particle
## emitter, no flames, beams or lights, and no aura motes. A village of 28 players
## carried over 200 CPU particle emitters before.
var decor_light := false
## The particle emitters and meshes of the current outfit (distance LOD: set_far).
var _emitters: Array[CPUParticles3D] = []
var _lod_meshes: Array[MeshInstance3D] = []
var _far := false
## The enhancement overlays taken off a far player's meshes on a phone (mesh -> overlay),
## put back when it comes near again.
var _far_overlays: Dictionary = {}
## Wing pose picked on the HUD (see WING_*); kept across gear changes.
var wing_mode := WING_STAND
var _wing_moving := false
var _gear_scale := 1.0
var skill_generation := 0
var _emission_grip: Node3D
var _emission_point := Vector3.ZERO
var _emission_bone := -1
var _skill_pose: Dictionary = {}
var _skill_chest := -1
var _skill_clock := 0.0
var _skill_release := 0.0
var _skill_rest := Transform3D.IDENTITY
var _skill_start: Array[Transform3D] = []
var _skill_base: Array[Transform3D] = []
var _locomotion := "Idle"
var _locomotion_speed := 1.0


## p_model: wear another character's stock look (villagers); armed=false = no weapon.
func setup(p_class: StringName, p_model := "", armed := true, p_equip := {}, p_look := {}) -> void:
	_cancel_skill_motion()
	busy_until = 0
	current = ""
	_locomotion = "Idle"
	_locomotion_speed = 1.0
	class_id = p_class
	look = p_look
	for child in get_children():
		child.queue_free()
	var data := ClassData.get_class_data(class_id)
	model_name = p_model if p_model != "" else String(data.model)
	chibi = p_model == "" and look.has("gender")
	if chibi:
		_setup_chibi(armed, p_equip)
		return
	var packed := load(CHARACTER_DIR + BASE_MODEL + ".glb") as PackedScene
	model = packed.instantiate() as Node3D
	add_child(model)
	_skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	for child in _skeleton.get_children():
		child.free()
	anim = _borrow_animations()
	MartialClips.prepare(anim)
	for clip in anim.get_animation_list():
		var a := anim.get_animation(clip)
		a.loop_mode = Animation.LOOP_LINEAR if clip in LOOPING else Animation.LOOP_NONE
	# KayKit rigs report a tall bind-pose box; the standing body is ~2.2 units.
	model.scale = Vector3.ONE * (HEIGHT / 2.2)
	_gear_scale = 1.0
	if armed:
		WeaponPoses.install(anim, _skeleton, class_id, BASE_MODEL, {}, _gear_scale)
	_head_bone = _skeleton.find_bone("head")
	set_process(_head_bone >= 0)
	equip = p_equip
	_armed = armed
	refresh()
	play("Idle")


var _armed := true
## Held weapon and offhand hidden (while riding a mount, so they do not poke through it).
var held_stowed := false
var _pumpkin: Node3D
## Head widths in metres (the chibi bodies, the KayKit ones).
const PUMPKIN_HEAD_WIDTH := 0.85
const PUMPKIN_HEAD_WIDTH_KAYKIT := 1.0


## The Halloween potion's floating pumpkin over the head (PumpkinHead); safe to call
## every tick: a rebuilt body gets a new one.
func set_pumpkin(on: bool) -> void:
	var have := _pumpkin != null and is_instance_valid(_pumpkin) and _pumpkin.is_inside_tree()
	if on == have:
		return
	if not on:
		_pumpkin.queue_free()
		_pumpkin = null
		return
	if _skeleton == null or not is_instance_valid(_skeleton):
		return
	var mount := BoneAttachment3D.new()
	mount.name = "PumpkinMount"
	mount.bone_name = _bone("head")
	_skeleton.add_child(mount)
	# Metres: the skeleton's scale, the head bone's height and the top of the body.
	var unit := maxf(_skeleton.global_basis.get_scale().y / maxf(global_basis.get_scale().y, 0.001), 0.001)
	var bone := _skeleton.find_bone(_bone("head"))
	var bone_y := (_skeleton.get_bone_global_rest(bone).origin.y if bone >= 0 else 0.0) * unit
	var top := CHIBI_HEIGHT if chibi else HEIGHT
	mount.add_child(PumpkinHead.make(maxf(top - bone_y, 0.2), PUMPKIN_HEAD_WIDTH if chibi else PUMPKIN_HEAD_WIDTH_KAYKIT, unit))
	_pumpkin = mount


func has_pumpkin() -> bool:
	return _pumpkin != null and is_instance_valid(_pumpkin) and _pumpkin.is_inside_tree()


func _setup_chibi(armed: bool, p_equip: Dictionary) -> void:
	var gender := clampi(int(look.get("gender", 0)), 0, 1)
	model = (load(CHIBI_MODELS[gender]) as PackedScene).instantiate() as Node3D
	add_child(model)
	_skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	MartialClips.prepare(anim)
	for clip in anim.get_animation_list():
		var a := anim.get_animation(clip)
		a.loop_mode = Animation.LOOP_LINEAR if (clip in LOOPING or clip.begins_with("Chibi_") or clip.begins_with("Fly_")) else Animation.LOOP_NONE
	FlyClips.add_to(anim, _skeleton)
	var height := 0.0
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		height = maxf(height, (mi as MeshInstance3D).get_aabb().size.y)
	model.scale = Vector3.ONE * (CHIBI_HEIGHT / maxf(height, 0.1))
	_gear_scale = (HEIGHT / 2.2) / model.scale.x
	if armed:
		WeaponPoses.install(anim, _skeleton, class_id, CHIBI_MODELS[gender], {"r": _slot_fix("handslot.r"), "l": _slot_fix("handslot.l")}, _gear_scale)
	_head_bone = -1
	set_process(false)
	equip = p_equip
	_armed = armed
	refresh()
	play("Idle")


static var _slot_fixes: Dictionary = {}


## The chibi's weapon slot is a new bone whose axes differ from KayKit's: compare
## both rigs in the T-pose clip and return the turn that lines them up.
func _slot_fix(bone: String) -> Basis:
	var key := "%s|%s" % [CHIBI_MODELS[clampi(int(look.get("gender", 0)), 0, 1)], bone]
	if _slot_fixes.has(key):
		return _slot_fixes[key]
	var mine := _posed_slot(CHIBI_MODELS[clampi(int(look.get("gender", 0)), 0, 1)], bone)
	var kaykit := _posed_slot(CHARACTER_DIR + "Knight.glb", bone)
	var fix := mine.inverse() * kaykit
	_slot_fixes[key] = fix
	return fix


static func _posed_slot(path: String, bone: String) -> Basis:
	var scene := (load(path) as PackedScene).instantiate() as Node3D
	var skeleton := scene.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var out := Basis.IDENTITY
	if skeleton and player and player.has_animation("T-Pose"):
		var anim_res := player.get_animation("T-Pose")
		# Pose the bones straight from the clip's first keys (no scene tree needed).
		for i in anim_res.get_track_count():
			if anim_res.track_get_type(i) != Animation.TYPE_ROTATION_3D:
				continue
			var idx := skeleton.find_bone(String(anim_res.track_get_path(i).get_concatenated_subnames()))
			if idx >= 0:
				skeleton.set_bone_pose_rotation(idx, anim_res.rotation_track_interpolate(i, 0.0))
		var b := skeleton.find_bone(bone)
		if b >= 0:
			out = skeleton.get_bone_global_pose(b).basis.orthonormalized()
	scene.free()
	return out


## Bone of this rig for a KayKit bone name.
func _bone(kaykit_name: String) -> String:
	return String(CHIBI_BONES.get(kaykit_name, kaykit_name)) if chibi else kaykit_name


const CHIBI_OUTFIT := preload("res://shaders/chibi_outfit.gdshader")


## The chibi keeps its face and hair. Armour recolours its outfit and adds
## pieces (pauldrons, emblem, belt, cape), helms become headbands / circlets /
## crowns over the hair, boots get cuffs, an amulet a pendant.
func _refresh_chibi() -> void:
	var armor: Variant = equip.get("armor")
	var helm: Variant = equip.get("helm")
	var boots: Variant = equip.get("boots")
	_dress_chibi(armor)
	var armor_nodes: Array = []
	if armor != null:
		armor_nodes = _divine_slot(armor) if DivineGearData.is_item(armor) else (_star_armor(armor) if StarGearData.is_star(armor) else _chibi_armor(ItemLook.tier_of(armor)))
	if DivineGearData.is_item(helm):
		var crown_nodes := _divine_slot(helm)
		_glow_piece(crown_nodes, int(helm.get("plus", 0)), Vector3(0,2.2,0), 0.25)
	elif helm != null:
		var crown := _chibi_attach("Head", "ChibiHelm")
		if StarGearData.is_star(helm): crown.add_child(StarGearArt.armor_piece("helm",StarGearData.item_class(helm),int(helm.star_tier)))
		else: ChibiGear.headpiece(crown, ItemLook.tier_of(helm))
		_glow_piece([crown.get_parent()], int(helm.get("plus", 0)), Vector3(0, 2.2, 0), 0.25)
	var acc := int(look.get("acc", 0))
	if acc > 0:
		ChibiLook.build_accessory(_chibi_attach("Head", "ChibiLook"), acc, int(look.get("gender", 0)))
		_body_nodes[_body_nodes.size() - 1].set_meta("far_decor", true)
	var boot_nodes: Array = []
	if DivineGearData.is_item(boots):
		boot_nodes = _divine_slot(boots)
	elif boots != null:
		for side in ["Left", "Right"]:
			var cuff := _chibi_attach(side + "LowerLeg", "ChibiBoots")
			if StarGearData.is_star(boots): cuff.add_child(StarGearArt.armor_piece("boots",StarGearData.item_class(boots),int(boots.star_tier)))
			else: ChibiGear.boot_cuff(cuff, ItemLook.tier_of(boots))
			boot_nodes.append(cuff.get_parent())
	if equip.get("amulet") != null:
		if StarGearData.is_star(equip.amulet): _star_piece("amulet","Chest",equip.amulet)
		else: ChibiGear.pendant(_chibi_attach("Chest", "ChibiAmulet"), ItemLook.tier_of(equip.amulet))
	if StarGearData.is_star(equip.get("ring")): _star_piece("ring","LeftHand",equip.ring)
	_glow_piece(armor_nodes, int(equip.get("armor", {}).get("plus", 0)), Vector3(0, 1.1, 0), 0.4)
	_glow_piece(boot_nodes, int(equip.get("boots", {}).get("plus", 0)), Vector3(0, 0.3, 0), 0.4)
	var wings: Variant = equip.get("wings")
	if wings is Dictionary:
		# The wing models share the chibi's model space: undo the chest's rest pose.
		var back := _chibi_attach("Chest", "Wings")
		var chest := _skeleton.find_bone("Chest")
		if chest >= 0:
			back.transform = _skeleton.get_bone_global_rest(chest).affine_inverse()
		back.add_child(StarWingData.build(_wing_kind(wings)) if StarGearData.is_star(wings) else GearKit.wings(_wing_kind(wings)))
		_glow_piece([back.get_parent()], int(wings.get("plus", 0)), WING_GLOW, 0.5)
		_wing_flair(back.get_parent(), int(wings.get("plus", 0)))
		_pose_wings.call_deferred(wing_mode, true)
	# Fold only static accessories on each bone, keeping the skeleton and wing animation intact.
	for node in _body_nodes:
		if is_instance_valid(node) and String(node.name).begins_with("Chibi") and node.get_child_count() > 0:
			MeshMerge.merge(node.get_child(0) as Node3D, "auto")
	_make_aura()
	_hold_gear()
	_gem_glows()
	_polish()


## A node on a chibi bone whose axes are the model's (x side, y up, z front) and
## whose units are the chibi skeleton's.
## While flying, standing and running become the flying body clips (FlyClips).
const FLY_CLIPS := {"Idle": "Fly_Hover", "Running_A": "Fly_Forward"}


func flying() -> bool:
	return wing_mode == WING_FLY and has_wings()


## Where the Dark Lord's raven grips: on top of the raised left forearm, a little above
## the wrist (model's own bones, so it follows every pose and the flying lift).
func perch_point() -> Vector3:
	if _skeleton != null and is_instance_valid(_skeleton):
		for pair in [["LeftLowerArm", "LeftHand"], ["lowerarm.l", "wrist.l"]]:
			var arm := _skeleton.find_bone(pair[0])
			var hand := _skeleton.find_bone(pair[1])
			if arm >= 0 and hand >= 0:
				var from := _skeleton.global_transform * _skeleton.get_bone_global_pose(arm).origin
				var to := _skeleton.global_transform * _skeleton.get_bone_global_pose(hand).origin
				return from.lerp(to, 0.7) + Vector3.UP * 0.05
	return global_position + Vector3(-0.35, 1.25, 0.25)


## True while a pair of wings is worn.
func has_wings() -> bool:
	return equip.get("wings") is Dictionary


## Switches the wing pose: folding plays the fold once and holds it; opening
## from folded plays the unfold first.
func set_wing_mode(mode: int, instant := false) -> void:
	var was := wing_mode
	wing_mode = clampi(mode, WING_STAND, WING_FOLD)
	_pose_wings(was, instant)
	# Swap between the ground and flying body clips right away.
	var ground := current
	for key in FLY_CLIPS:
		if FLY_CLIPS[key] == current:
			ground = key
	if ground != current or (FLY_CLIPS.has(current) and flying()):
		current = ""
		play(ground)


## Flying wings glide while the hero moves and flap while hovering in place.
func set_wing_moving(moving: bool) -> void:
	if moving == _wing_moving:
		return
	_wing_moving = moving
	if wing_mode == WING_FLY:
		_pose_wings(WING_FLY, false)


func _wing_player() -> AnimationPlayer:
	var wings := find_child("Wings_*", true, false)
	return wings.find_child("AnimationPlayer", true, false) as AnimationPlayer if wings != null else null


func _pose_wings(was: int, instant: bool) -> void:
	var player := _wing_player()
	if player == null:
		return
	if wing_mode == WING_FOLD:
		if player.has_animation("Fold"):
			player.play("Fold", 0.0 if instant else 0.2)
			if instant:
				player.seek(player.get_animation("Fold").length, true)
		return
	var clip := "Idle" if wing_mode == WING_STAND else ("Glide" if _wing_moving else "Flap")
	if not player.has_animation(clip):
		return
	if was == WING_FOLD and not instant and player.has_animation("Unfold"):
		player.play("Unfold", 0.1)
		player.queue(clip)
	elif player.current_animation != clip:
		player.play(clip, 0.0 if instant else 0.3)


## Which class model a pair of wings shows (old items fall back to this hero's class).
func _wing_kind(item: Dictionary) -> String:
	var kind := String(item.get("wing", ""))
	return kind if ItemData.WING_INFO.has(kind) else String(class_id)


func _chibi_attach(bone: String, node_name: String) -> Node3D:
	var attach := BoneAttachment3D.new()
	attach.name = node_name
	attach.bone_name = bone
	_skeleton.add_child(attach)
	_body_nodes.append(attach)
	var frame := Node3D.new()
	var idx := _skeleton.find_bone(bone)
	if idx >= 0:
		frame.basis = _skeleton.get_bone_global_rest(idx).basis.orthonormalized().inverse()
	attach.add_child(frame)
	return frame


func _star_piece(part: String, bone: String, item: Dictionary, side := 1.0) -> Node3D:
	var aliases := {"Chest":"chest","Head":"head","Hips":"hips","LeftHand":"wrist.l","LeftUpperArm":"upperarm.l","RightUpperArm":"upperarm.r","LeftLowerLeg":"lowerleg.l","RightLowerLeg":"lowerleg.r"}
	var frame := _chibi_attach(bone if chibi else String(aliases.get(bone,bone)), "ChibiStar_" + part)
	var piece := StarGearArt.armor_piece(part,StarGearData.item_class(item),int(item.star_tier),side)
	if not chibi: piece.scale = Vector3.ONE * 2.2
	frame.add_child(piece)
	return frame.get_parent() as Node3D

func _star_armor(item: Dictionary) -> Array:
	return [_star_piece("chest","Chest",item),_star_piece("belt","Hips",item),
		_star_piece("pauldron","LeftUpperArm",item,1.0),_star_piece("pauldron","RightUpperArm",item,-1.0)]


func _divine_slot(item: Dictionary) -> Array:
	# Match the original level 1–100 silhouette: dye the existing body and use
	# small bone-mounted trims. Uploaded held weapons keep their real models.
	match String(item.slot):
		"armor":
			return [_divine_dye_piece("chest", "Chest", item), _divine_dye_piece("belt", "Hips", item),
				_divine_dye_piece("pauldron", "LeftUpperArm", item, 1.0), _divine_dye_piece("pauldron", "RightUpperArm", item, -1.0)]
		"helm": return [_divine_dye_piece("helm", "Head", item)]
		"boots": return [_divine_dye_piece("boots", "LeftLowerLeg", item), _divine_dye_piece("boots", "RightLowerLeg", item)]
	return []


func _divine_dye_piece(part: String, bone: String, item: Dictionary, side := 1.0) -> Node3D:
	var aliases := {"Chest":"chest", "Head":"head", "Hips":"hips", "LeftUpperArm":"upperarm.l", "RightUpperArm":"upperarm.r", "LeftLowerLeg":"lowerleg.l", "RightLowerLeg":"lowerleg.r"}
	var frame := _chibi_attach(bone if chibi else String(aliases.get(bone, bone)), "ChibiDivineDye_" + part)
	var piece := Node3D.new()
	frame.add_child(piece)
	DivineOutfitArt.decorate(piece, part, StarGearData.item_class(item), side)
	if not chibi: piece.scale = Vector3.ONE * 2.2
	return frame.get_parent() as Node3D


func _chibi_armor(tier: int) -> Array:
	var nodes: Array = []
	for side in [1.0, -1.0]:
		var shoulder := _chibi_attach(("Left" if side > 0.0 else "Right") + "UpperArm", "ChibiPauldron")
		ChibiGear.pauldron(shoulder, tier, side)
		nodes.append(shoulder.get_parent())
	var chest := _chibi_attach("Chest", "ChibiChest")
	ChibiGear.chest(chest, tier)
	nodes.append(chest.get_parent())
	if tier >= 4:
		var waist := _chibi_attach("Hips", "ChibiBelt")
		ChibiGear.belt(waist, tier)
		nodes.append(waist.get_parent())
	return nodes


## Recolours the outfit for the armour tier (no armour: the model's own colours).
func _dress_chibi(armor: Variant) -> void:
	var boots: Variant = equip.get("boots")
	var divine_armor := DivineGearData.is_item(armor)
	var divine_boots := DivineGearData.is_item(boots)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.skin == null or mi.mesh == null:
			continue
		# Always start from the imported body, even after repeated equipment swaps.
		var source_mesh: Mesh = mi.get_meta("outfit_source_mesh", mi.mesh)
		mi.set_meta("outfit_source_mesh", source_mesh)
		mi.mesh = OutfitDye.masked_mesh(source_mesh, mi.skin, _skeleton) if divine_armor or divine_boots else source_mesh
		var source := source_mesh.surface_get_material(0) as StandardMaterial3D
		if source == null:
			continue
		var mat := ShaderMaterial.new()
		mat.shader = CHIBI_OUTFIT
		mat.set_shader_parameter("albedo_tex", source.albedo_texture)
		ChibiLook.set_material(mat, look, int(look.get("gender", 0)))
		if armor != null:
			var tier := ItemLook.tier_of(armor)
			var cloth: Color = DivineOutfitArt.palette(StarGearData.item_class(armor)).body if divine_armor else (StarGearArt.cloth(StarGearData.item_class(armor),int(armor.star_tier)) if StarGearData.is_star(armor) else ChibiGear.cloth(tier))
			mat.set_shader_parameter("outfit_color", cloth)
			mat.set_shader_parameter("outfit_amount", 0.96 if divine_armor else 0.5 + 0.04 * float(tier))
			mat.set_shader_parameter("sheen", 0.22 if divine_armor else (0.0 if tier < 2 else 0.2 + 0.08 * float(tier)))
			if tier >= 7 and not divine_armor:
				mat.set_shader_parameter("glow_color", ChibiGear.cloth(tier) * 0.35)
		if divine_armor or divine_boots:
			mat.set_shader_parameter("part_masks_enabled", true)
		if divine_armor:
			var palette := DivineOutfitArt.palette(StarGearData.item_class(armor))
			for part in ["pants", "gloves"]:
				mat.set_shader_parameter(part + "_color", palette[part])
				mat.set_shader_parameter(part + "_amount", 0.96)
		if divine_boots:
			mat.set_shader_parameter("boots_color", DivineOutfitArt.palette(StarGearData.item_class(boots)).boots)
			mat.set_shader_parameter("boots_amount", 0.96)
		if GameSettings.quality > 0:
			mat.next_pass = StorybookFinish.outline(0.012 * _gear_scale)
		mi.material_override = mat
		mi.set_meta("polished", true)


## Rebuilds everything the hero wears from [member equip] (slot -> item).
func set_equipment(p_equip: Dictionary) -> void:
	equip = p_equip
	refresh()


## Enhancement glow of one worn piece, kept with the outfit so a re-dress frees it.
func _glow_piece(nodes: Array, plus: int, spot: Vector3, spread := 0.3) -> void:
	var made := EnhanceFx.glow_piece(self, nodes, plus, spot, spread, decor_light)
	if made != null:
		_body_nodes.append(made)


## Wings at +10 and up: a glow behind them and drifting light feathers (EnhanceFx.wing_flair).
func _wing_flair(back: Node3D, plus: int) -> void:
	var made := EnhanceFx.wing_flair(back, plus, Vector3.ZERO, decor_light)
	if made != null:
		_body_nodes.append(made)


## Where (visual space) a worn piece's legendary-gem sparkle shines; the weapon's
## shines at its tip on the held grip instead.
const GEM_SPOTS := {"armor": Vector3(0, 1.05, 0.12), "helm": Vector3(0, 1.9, 0), "boots": Vector3(0, 0.3, 0.08),
	"amulet": Vector3(0, 1.35, 0.2), "ring": Vector3(0.38, 0.9, 0.05), "wings": Vector3(0, 1.45, -0.45)}


## Every worn piece with a ตำนาน (size 4) gem socketed sparkles softly in that gem's
## colour (EnhanceFx.gem_sparkle). Kept in _body_nodes so a re-dress frees it;
## nothing for the other players around (decor_light) or at the lowest quality.
func _gem_glows() -> void:
	if decor_light or GameSettings.quality == 0:
		return
	for slot in equip:
		var color := EnhanceFx.legend_gem_color(equip[slot])
		if color.a <= 0.0:
			continue
		var parent: Node3D = self
		var spot: Vector3 = GEM_SPOTS.get(slot, Vector3(0, 1.0, 0))
		if slot == "weapon":
			if not is_instance_valid(_emission_grip):
				continue
			parent = _emission_grip
			spot = _emission_point
		elif slot == "helm" and chibi:
			spot = Vector3(0, 2.2, 0)
		var made := EnhanceFx.gem_sparkle(parent, spot, color, decor_light)
		if made != null:
			made.set_meta("gem_glow", String(slot))
			_body_nodes.append(made)


func refresh() -> void:
	dressed += 1
	_face = null
	for n in _body_nodes:
		if is_instance_valid(n):
			n.free()
	_body_nodes.clear()
	for n in _hold_nodes:
		if is_instance_valid(n):
			n.free()
	_hold_nodes.clear()
	if chibi:
		_refresh_chibi()
		return
	var preset: Dictionary = PRESETS.get(model_name, PRESETS["Ranger"])
	var priest := class_id == &"priest" and model_name == "Mage"
	var armor: Variant = equip.get("armor")
	var helm: Variant = equip.get("helm")
	# Outfit
	var outfit_style: String = preset.outfit
	var outfit_tint := PRIEST_WHITE if (priest and armor == null) else Color.WHITE
	var cape: Variant = preset.get("cape")
	if armor != null:
		var look := ItemLook.armor_look(armor)
		outfit_style = look.style
		outfit_tint = look.tint
		cape = look.cape
	if armor == null and class_id == ClassData.START and not look.is_empty() and int(look.get("outfit", 0)) > 0:
		var starter: Array = FaceKit.OUTFITS[clampi(int(look.outfit), 0, FaceKit.OUTFITS.size() - 1)]
		outfit_style = String(starter[1])
		outfit_tint = starter[2]
		cape = [outfit_style, String(starter[3])] if String(starter[3]) != "" else null
	# Villagers pick their own outfit: [model, tint, cape part or ""].
	if look.has("npc_outfit"):
		var own: Array = look.npc_outfit
		outfit_style = String(own[0])
		outfit_tint = own[1]
		cape = [String(own[0]), String(own[2])] if String(own[2]) != "" else null
	var glb: String = OUTFIT_GLB[outfit_style]
	var boots: Variant = equip.get("boots")
	var armor_nodes: Array = []
	var boot_nodes: Array = []
	for piece in OUTFIT_PARTS:
		var piece_tint := outfit_tint
		if DivineGearData.is_item(armor) and piece.begins_with("Leg"):
			piece_tint = DivineOutfitArt.palette(StarGearData.item_class(armor)).pants
		if boots != null and piece.begins_with("Leg"):
			if DivineGearData.is_item(boots): piece_tint = DivineOutfitArt.palette(StarGearData.item_class(boots)).boots
			else: piece_tint *= ItemLook.boots_tint(boots)
		var part := _add_part(glb, "%s_%s" % [glb, piece], piece_tint)
		if part != null:
			(boot_nodes if piece.begins_with("Leg") else armor_nodes).append(part)
		if not look.is_empty() and part is MeshInstance3D:
			_reskin(part as MeshInstance3D, piece_tint)
	# Head, hat, cape
	if look.is_empty():
		_add_part(preset.head[0], preset.head[1])
	else:
		_add_custom_head(helm == null)
		if look.has("npc_hat") and helm == null:
			var hat_spec: Array = look.npc_hat
			_body_nodes[_body_nodes.size() - 1].add_child(JapanKit.hat(String(hat_spec[0]), hat_spec[1]))
	if preset.has("extra") and armor == null:
		_add_part(preset.extra[0], preset.extra[1])
	if DivineGearData.is_item(armor):
		armor_nodes.append_array(_divine_slot(armor))
	elif StarGearData.is_star(armor):
		armor_nodes.append_array(_star_armor(armor))
	elif armor != null:
		_wear_flourish(ItemLook.tier_of(armor))
		var flourish := _body_nodes[_body_nodes.size() - 1] if not _body_nodes.is_empty() and ItemLook.tier_of(armor) >= 2 else null
		if flourish != null:
			armor_nodes.append(flourish)
	var wings: Variant = equip.get("wings")
	if wings is Dictionary:
		var back := BoneAttachment3D.new()
		back.name = "Wings"
		back.bone_name = "chest"
		_skeleton.add_child(back)
		var w := StarWingData.build(_wing_kind(wings)) if StarGearData.is_star(wings) else GearKit.wings(_wing_kind(wings))
		w.transform = KAYKIT_WINGS
		back.add_child(w)
		_body_nodes.append(back)
		_glow_piece([back], int(wings.get("plus", 0)), WING_GLOW, 0.5)
		_wing_flair(back, int(wings.get("plus", 0)))
		_pose_wings.call_deferred(wing_mode, true)
	if cape != null and cape is Array:
		var cape_tint := Color(2.2, 2.2, 2.0) if (priest and armor == null) else outfit_tint
		_add_part(cape[0], cape[1], cape_tint)
	if DivineGearData.is_item(helm):
		var crown_nodes := _divine_slot(helm)
		_glow_piece(crown_nodes, int(helm.get("plus", 0)), Vector3(0,1.85,0), 0.25)
	elif StarGearData.is_star(helm):
		_star_piece("helm","Head",helm)
	elif helm != null:
		var hat := ItemLook.helm_look(helm)
		var before_count := _body_nodes.size()
		var worn_part: Node = _wear_hat(hat)
		var hat_nodes: Array = []
		if worn_part != null:
			hat_nodes.append(worn_part)
		elif _body_nodes.size() > before_count:
			hat_nodes.append(_body_nodes[_body_nodes.size() - 1])
		_glow_piece(hat_nodes, int(helm.get("plus", 0)), Vector3(0, 1.85, 0), 0.25)
	elif preset.has("hat") and look.is_empty():
		_add_part(preset.hat[0], preset.hat[1], PRIEST_GOLD if priest else Color.WHITE)
	var cuff_start := _body_nodes.size()
	_wear_trinkets()
	if boots != null:
		for n in _body_nodes.slice(cuff_start):
			if n is BoneAttachment3D and (n as BoneAttachment3D).name == "Boots":
				boot_nodes.append(n)
	_glow_piece(armor_nodes, int(equip.get("armor", {}).get("plus", 0)), Vector3(0, 1.0, 0), 0.4)
	_glow_piece(boot_nodes, int(equip.get("boots", {}).get("plus", 0)), Vector3(0, 0.25, 0), 0.4)
	_hold_gear()
	_gem_glows()
	_polish()


static var _outline_material: StandardMaterial3D


## One dark hull shared by every character: a thin cartoon outline.
static func outline_material() -> StandardMaterial3D:
	if _outline_material == null:
		_outline_material = StorybookFinish.outline(0.012)
	return _outline_material


## Premium finish: a cartoon outline and a soft rim light on everything the
## hero wears (glowing / transparent effect meshes are left alone).
func _polish() -> void:
	var meshes: Array[MeshInstance3D] = []
	for node in find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	_lod_meshes = meshes
	_emitters.clear()
	for node in find_children("*", "CPUParticles3D", true, false):
		_emitters.append(node as CPUParticles3D)
	if _far:
		_far = false
		set_far(true)
	# Thin held gear (bows, staffs) and wings only get the rim light: an outline would swallow it.
	var held: Array[Node] = []
	for hold in _hold_nodes:
		held.append(hold)
		held.append_array(hold.find_children("*", "MeshInstance3D", true, false))
	for mi in meshes:
		if mi.mesh == null or mi.has_meta("polished"):
			continue
		mi.set_meta("polished", true)
		var outlined := not (mi in held) and not bool(mi.get_meta("face_detail", false)) and not bool(mi.get_meta("no_outline", false)) and GameSettings.quality > 0
		if mi.material_override != null:
			var done := _polish_material(mi.material_override, outlined)
			if done != null:
				mi.material_override = done
			continue
		for i in mi.mesh.get_surface_count():
			var done := _polish_material(mi.get_active_material(i), outlined)
			if done != null:
				mi.set_surface_override_material(i, done)


func _polish_material(source: Material, outlined: bool) -> Material:
	if source is StandardMaterial3D:
		var std := source as StandardMaterial3D
		if std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or std.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			return null
		return StorybookFinish.material(std, Color.WHITE, 0.012 * _gear_scale if outlined else 0.0)
	if outlined and source is ShaderMaterial and FaceKit._skin_shader != null and (source as ShaderMaterial).shader == FaceKit._skin_shader:
		(source as ShaderMaterial).next_pass = outline_material()
		return source
	return null


## Boots show as cuffs on both lower legs, an amulet as a necklace.
func _wear_trinkets() -> void:
	var boots: Variant = equip.get("boots")
	if DivineGearData.is_item(boots):
		var boot_nodes := _divine_slot(boots)
		_glow_piece(boot_nodes, int(boots.get("plus", 0)), Vector3(0,0.25,0), 0.4)
	elif StarGearData.is_star(boots):
		_star_piece("boots","LeftLowerLeg",boots)
		_star_piece("boots","RightLowerLeg",boots)
	elif boots != null:
		var tier := ItemLook.tier_of(boots)
		for side in [1.0, -1.0]:
			var attach := BoneAttachment3D.new()
			attach.name = "Boots"
			attach.bone_name = "lowerleg.l" if side > 0.0 else "lowerleg.r"
			_skeleton.add_child(attach)
			attach.add_child(GearKit.boot_cuff(tier, side))
			_body_nodes.append(attach)
	var ring: Variant = equip.get("ring")
	if StarGearData.is_star(ring):
		_star_piece("ring","LeftHand",ring)
	elif ring != null:
		var ring_attach := BoneAttachment3D.new()
		ring_attach.name = "RingBand"
		ring_attach.bone_name = "wrist.l"
		_skeleton.add_child(ring_attach)
		ring_attach.add_child(GearKit.ring_band(ItemLook.tier_of(ring)))
		_body_nodes.append(ring_attach)
	_make_aura()
	var amulet: Variant = equip.get("amulet")
	if StarGearData.is_star(amulet):
		_star_piece("amulet","Chest",amulet)
	elif amulet != null:
		var attach := BoneAttachment3D.new()
		attach.name = "Amulet"
		attach.bone_name = "chest"
		_skeleton.add_child(attach)
		attach.add_child(GearKit.necklace(ItemLook.tier_of(amulet)))
		_body_nodes.append(attach)


## Decoration on the armour that gets more lavish with the gear tier (Lv.10 per tier).
func _wear_flourish(tier: int) -> void:
	if tier < 2:
		return
	var attach := BoneAttachment3D.new()
	attach.name = "ArmorFlourish"
	attach.bone_name = "chest"
	_skeleton.add_child(attach)
	attach.add_child(GearKit.armor_flourish(tier))
	_body_nodes.append(attach)


## The best gear tier worn (0-9).
func _top_tier() -> int:
	var top := 0
	for slot in ["weapon", "armor", "helm", "boots"]:
		if equip.has(slot):
			top = maxi(top, ItemLook.tier_of(equip[slot]))
	return top


## Sparkles around the hero for legendary gear (violet), a weapon at +7 or more (gold)
## and, from gear tier 6 up (Lv.61+), a bigger and bigger aura plus a halo.
func _make_aura() -> void:
	if GameSettings.quality == 0:
		return
	var color := Color(0, 0, 0, 0)
	for slot in equip:
		var item: Dictionary = equip[slot]
		if int(item.get("rarity", 0)) >= 3:
			color = Color("c46bff")
	# The body aura is the whole set's: the lowest + of weapon, armour, helm, boots and
	# wings (each piece still glows by its own +).
	var whole := EnhanceFx.set_plus(equip)
	if whole >= EnhanceFx.AURA_STEPS[0]:
		color = EnhanceFx.color_of(whole)
		for made in EnhanceFx.on_body(self, whole, decor_light):
			made.set_meta("far_decor", true)
			_body_nodes.append(made)
	var tier := _top_tier()
	if tier >= 6:
		color = GearKit.TIERS_METAL[tier].lerp(Color("ffd870"), 0.35)
		if tier >= 8 and not StarGearData.is_star(equip.get("helm")):
			var halo := BoneAttachment3D.new()
			halo.name = "Halo"
			halo.bone_name = _bone("head")
			_skeleton.add_child(halo)
			var ring := GearKit.halo(tier)
			if chibi:
				ring.scale *= _gear_scale
			halo.add_child(ring)
			halo.set_meta("far_decor", true)
			_body_nodes.append(halo)
	if color.a == 0.0 or decor_light:
		return
	var p := CPUParticles3D.new()
	p.name = "Aura"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = VfxKit.soft_dot()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.5)
	quad.material = mat
	p.mesh = quad
	var grand := maxi(tier - 5, 0)
	p.amount = VfxBudget.count(14 + grand * 10 + EnhanceFx.aura_step(whole) * 2)
	p.lifetime = 1.5 + 0.1 * float(grand)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.55 + 0.08 * float(grand)
	p.direction = Vector3.UP
	p.spread = 20.0
	p.initial_velocity_min = 0.3 + 0.08 * float(grand)
	p.initial_velocity_max = 0.7 + 0.15 * float(grand)
	p.gravity = Vector3.ZERO
	p.local_coords = false
	p.color_ramp = VfxKit._fade_ramp()
	p.position = Vector3(0, 0.9, 0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	_body_nodes.append(p)


func _add_part(glb: String, node_name: String, tint := Color.WHITE) -> Node3D:
	var node := HeroParts.attach(_skeleton, glb, node_name, tint)
	if node:
		_body_nodes.append(node)
	return node


## Skin colour of the chosen look on a body part.
func _reskin(mi: MeshInstance3D, tint: Color) -> void:
	for i in mi.mesh.get_surface_count():
		var source := mi.mesh.surface_get_material(i) as StandardMaterial3D
		mi.set_surface_override_material(i, FaceKit.skin_material(source, tint, look))


func _add_custom_head(with_hair: bool) -> void:
	var attach := BoneAttachment3D.new()
	attach.name = "CustomHeadAttach"
	attach.bone_name = "head"
	_skeleton.add_child(attach)
	_face = FaceKit.build_head(look, with_hair) as FaceExpression
	attach.add_child(_face)
	_body_nodes.append(attach)


func _wear_hat(hat: Dictionary) -> Node:
	if hat.has("part"):
		var worn := _add_part(hat.part[0], hat.part[1], hat.tint)
		_lift_hat(worn)
		return worn
	var attach := BoneAttachment3D.new()
	attach.name = "Hat"
	attach.bone_name = "head"
	_skeleton.add_child(attach)
	var model_hat := GearKit.hat(hat.proc, hat.tint)
	attach.add_child(model_hat)
	_lift_hat(model_hat)
	_body_nodes.append(attach)
	return null


## The custom head is a little taller than the stock KayKit head: lift hats so
## they sit on the hair instead of covering the eyes.
func _lift_hat(node: Node) -> void:
	if look.is_empty() or node == null:
		return
	var holder: Node3D = node
	if node is BoneAttachment3D and node.get_child_count() > 0:
		holder = node.get_child(0) as Node3D
	if holder:
		holder.position += Vector3(0, 0.05, 0)


func _hold_gear() -> void:
	if not _armed:
		return
	var data := ClassData.get_class_data(class_id)
	var weapon_look := ItemLook.weapon_look(equip.get("weapon"), StringName(data.weapon_kind))
	_hold(weapon_look, WeaponGrip.hand_for(String(data.weapon_kind)), int(equip.get("weapon", {}).get("plus", 0)))
	var plus := int(equip.get("weapon", {}).get("plus", 0))
	if DivineGearData.is_item(equip.get("weapon")):
		var offhand: String = {&"warrior":"shield",&"priest":"book",&"summoner":"tome",&"assassin":"dagger"}.get(class_id, "")
		if offhand != "": _hold("divine_%s_%s_200" % [offhand, class_id], "handslot.l", plus if offhand == "dagger" else 0, true)
		return
	var star := StarGearData.is_star(equip.get("weapon"))
	var tier := int(equip.weapon.star_tier) if star else (ItemLook.tier_of(equip.weapon) if equip.get("weapon") is Dictionary else 0)
	if star:
		var offhand: String = {&"warrior":"shield",&"priest":"book",&"summoner":"tome",&"assassin":"dagger"}.get(class_id, "")
		if offhand != "": _hold("star_%s_%d" % [offhand,tier],"handslot.l", plus if offhand == "dagger" else 0, true)
		return
	match class_id:
		&"warrior":
			_hold("shield_%d" % (ItemLook.tier_of(equip.weapon) if equip.get("weapon") is Dictionary else 0), "handslot.l")
		&"priest":
			_hold("book_%d" % (ItemLook.tier_of(equip.weapon) if equip.get("weapon") is Dictionary else 0), "handslot.l")
		&"summoner":
			_hold("tome_%d" % (ItemLook.tier_of(equip.weapon) if equip.get("weapon") is Dictionary else 0), "handslot.l")
		&"assassin":
			# The twin of the main dagger, in the left hand.
			_hold(weapon_look, "handslot.l", plus, true)


## Hides (or shows again) every held piece: weapon, shield, book, tome, twin dagger.
func stow_held(on: bool) -> void:
	held_stowed = on
	if _skeleton == null:
		return
	for n in _skeleton.get_children():
		if n.has_meta(&"held"):
			(n as Node3D).visible = not on


## [param offhand]: a second held piece; the skill emission point stays on the main weapon.
func _hold(look: String, bone: String, plus := 0, offhand := false) -> void:
	var item: Node3D
	var kind := StarGearData.kind_from_look(look)
	if look.begins_with("divine_"):
		item = DivineGearArt.build(look)
	elif look.begins_with("star_"):
		item = StarGearArt.build(look)
	elif look.begins_with("shield"):
		item = WeaponKit.shield(look)
	elif look.begins_with("book_"):
		item = WeaponKit.book(int(look.trim_prefix("book_")))
	else:
		item = WeaponKit.build(look)
	var attach := BoneAttachment3D.new()
	attach.name = "Held_" + look
	attach.bone_name = bone
	attach.set_meta(&"held", true)
	attach.visible = not held_stowed
	_skeleton.add_child(attach)
	var pivot := Node3D.new()
	pivot.name = "Grip"
	pivot.basis = WeaponGrip.mount(kind)
	if chibi:
		pivot.basis = _slot_fix(bone) * pivot.basis
	pivot.scale = Vector3.ONE * _gear_scale
	attach.add_child(pivot)
	pivot.add_child(item)
	if kind not in ["shield","book","tome"] and not offhand:
		_emission_grip = pivot
		_emission_bone = _skeleton.find_bone(bone)
		var bounds := AABB()
		var first := true
		for mesh_node in item.find_children("*", "MeshInstance3D", true, false):
			var mesh := mesh_node as MeshInstance3D
			var relative := pivot.global_transform.affine_inverse() * mesh.global_transform
			var box := relative * mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		# Arrows leave the bow's grip, songs and notes the lute's rosette (the sound hole of
		# every lute look: tier models, star and divine), spells the weapon's head.
		_emission_point = Vector3.ZERO if kind == "bow" else (WeaponKit.LUTE_ROSETTE if kind == "lute" else Vector3(bounds.get_center().x, bounds.end.y * 0.94, bounds.get_center().z))
	if plus > 0:
		EnhanceFx.on_item(item, plus, decor_light)
	_hold_nodes.append(attach)


## Sample the current skeleton directly: BoneAttachment updates can otherwise
## lag a manually sampled animation by one frame. Equipment rebuilds this socket.
func skill_emission_position() -> Vector3:
	if is_instance_valid(_emission_grip) and is_instance_valid(_skeleton) and _emission_bone >= 0:
		return _skeleton.global_transform * _skeleton.get_bone_global_pose(_emission_bone) * _emission_grip.transform * _emission_point
	return global_position + Vector3(0, 1.3, 0)


## Stock Adventurers share the Knight animation library.
func _borrow_animations() -> AnimationPlayer:
	var rig := model.get_node_or_null("Rig_Medium")
	rig.name = "Rig"
	if _shared_library == null:
		var donor := (load(CHARACTER_DIR + "Knight.glb") as PackedScene).instantiate()
		var donor_player := donor.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_shared_library = donor_player.get_animation_library("")
		donor_player.remove_animation_library("")
		donor.free()
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	model.add_child(player)
	player.add_animation_library("", _shared_library)
	return player


## Animation level of detail: 1 poses every frame; N > 1 poses every Nth frame with the
## time gathered since (crowds far from the camera, a stall keeper standing still).
var anim_lod := 1
var _lod_frame := 0
var _lod_time := 0.0


func set_anim_lod(step: int) -> void:
	step = maxi(1, step)
	if step == anim_lod or anim == null:
		return
	anim_lod = step
	_lod_time = 0.0
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE if step == 1 else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# The manual steps are taken in _process, which a chibi switches off at rest.
	if step > 1:
		set_process(true)
	elif chibi and _skill_pose.is_empty():
		set_process(false)


## Far from the camera (FieldPlayer LOD): the outfit's particle emitters stop and its
## meshes cast no shadow; nobody sees either at that distance, and both cost every frame.
## On a phone the small decoration goes too (hair accessory, rune rings, disc and halo:
## "far_decor") and the enhancement glow overlays come off the meshes (one draw of every
## piece instead of two). The hero never gets here, and a party member is never far.
func set_far(far: bool) -> void:
	if far == _far:
		return
	_far = far
	for p in _emitters:
		if is_instance_valid(p):
			p.emitting = not far
			p.visible = not far
	for mi in _lod_meshes:
		if is_instance_valid(mi) and not bool(mi.get_meta("no_shadow_lod", false)):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if far else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if far and MemoryGuard.phone():
		_strip_far_decor()
	elif not far:
		_restore_far_decor()


## True while the phone's cheap far state is on (decoration hidden, overlays off).
var far_light := false


func _strip_far_decor() -> void:
	far_light = true
	_far_overlays.clear()
	for n in _body_nodes:
		if is_instance_valid(n) and n is Node3D and bool(n.get_meta("far_decor", false)):
			(n as Node3D).visible = false
	for mi in _lod_meshes:
		if not is_instance_valid(mi):
			continue
		# A hit flash in flight keeps its own overlay; the glow it covered is ours to hold.
		if _flash_restore.has(mi):
			_far_overlays[mi] = _flash_restore[mi]
			_flash_restore.erase(mi)
		elif mi.material_overlay != null and mi.material_overlay != _flash_overlay:
			_far_overlays[mi] = mi.material_overlay
			mi.material_overlay = null


func _restore_far_decor() -> void:
	far_light = false
	for n in _body_nodes:
		if is_instance_valid(n) and n is Node3D and bool(n.get_meta("far_decor", false)):
			(n as Node3D).visible = true
	for mi in _far_overlays:
		if is_instance_valid(mi) and is_instance_valid(_far_overlays[mi]):
			if (mi as MeshInstance3D).material_overlay == _flash_overlay and _flash_overlay != null:
				_flash_restore[mi] = _far_overlays[mi]
			else:
				(mi as MeshInstance3D).material_overlay = _far_overlays[mi]
	_far_overlays.clear()


## Big head = cuter. Scales the head bone after the animation has posed it.
func _process(delta: float) -> void:
	_advance_skill_motion(delta)
	if is_instance_valid(_face):
		_face.asleep = current.begins_with("Death") or current.begins_with("Lie")
	if anim_lod > 1 and anim != null:
		_lod_time += delta
		_lod_frame = (_lod_frame + 1) % anim_lod
		if _lod_frame != 0:
			return
		anim.advance(_lod_time)
		_lod_time = 0.0
	if _skeleton == null or _head_bone < 0:
		return
	var pose := _skeleton.get_bone_global_pose_no_override(_head_bone)
	pose.basis = pose.basis.scaled(Vector3.ONE * CHIBI_HEAD)
	_skeleton.set_bone_global_pose_override(_head_bone, pose, 1.0, true)


func has_clip(clip: String) -> bool:
	return anim != null and anim.has_animation(clip)


## Loops a locomotion clip (ignored while a one-shot action is still playing).
func play(clip: String, blend := 0.15, speed := 1.0) -> void:
	# Movement keeps arriving during a cast. Resume the latest request rather
	# than inserting an idle frame between the recovery and a running pose.
	_locomotion = clip
	_locomotion_speed = speed
	if not _skill_pose.is_empty():
		return
	if flying() and FLY_CLIPS.has(clip) and anim != null and anim.has_animation(FLY_CLIPS[clip]):
		clip = FLY_CLIPS[clip]
		speed = 1.0
		blend = maxf(blend, 0.3)
	if clip == "Idle" and class_id == &"lancer":
		clip = "2H_Melee_Idle"

	if anim == null or not anim.has_animation(clip):
		return
	if Time.get_ticks_msec() < busy_until:
		return
	anim.speed_scale = speed
	if current == clip and anim.is_playing():
		return
	current = clip
	anim.play(clip, blend)


## Plays an action once; locomotion resumes afterwards.
func action(clip: String, speed := 1.0, blend := 0.08) -> float:
	_cancel_skill_motion()
	if anim == null or not anim.has_animation(clip):
		return 0.0
	var length := anim.get_animation(clip).length / maxf(speed, 0.1)
	busy_until = Time.get_ticks_msec() + int(length * 1000.0 * 0.92)
	current = clip
	anim.speed_scale = speed
	anim.play(clip, blend)
	return length


func hold_last_frame(clip: String) -> void:
	_cancel_skill_motion()
	if anim and anim.has_animation(clip):
		busy_until = Time.get_ticks_msec() + 3_600_000
		current = clip
		anim.speed_scale = 1.0
		anim.play(clip, 0.1)


func release() -> void:
	_cancel_skill_motion()
	busy_until = 0
	current = ""


## Both rigs use the same source clips. Seek a paused clip so its authored
## contact frame coincides with the actual release, even with DEX haste.
## Only the visual model moves: no collision, targeting or gameplay root motion.
func skill_action(skill: Dictionary, release_time: float) -> void:
	_cancel_skill_motion()
	var cue := SkillChoreography.cue_for(skill)
	var clip := String(cue.clip)
	if not has_clip(clip):
		action(String(skill.get("anim", "Spellcast_Shoot")))
		return
	_skill_pose = cue
	_skill_chest = _skeleton.find_bone("Chest" if chibi else "chest") if cue.has("upper_pitch") else -1
	set_process(true)
	_skill_clock = 0.0
	_skill_release = maxf(release_time, 0.01)
	_skill_rest = model.transform
	_skill_start.clear()
	for bone in _skeleton.get_bone_count():
		_skill_start.append(_skeleton.get_bone_pose(bone))
	current = clip
	busy_until = Time.get_ticks_msec() + int((_skill_release + float(cue.recovery)) * 1000.0)
	anim.speed_scale = 1.0
	# A paused player cannot advance a cross-fade: leaving a blend here would
	# freeze its old idle pose while the seek clock appears to move correctly.
	# Imported clips omit constant rest tracks. Reset them before capturing the
	# cast's base, otherwise a raised running knee survives into a standing cast.
	_skeleton.reset_bone_poses()
	anim.play(clip, 0.0)
	anim.seek(0.0, true)
	anim.pause()
	_skill_base.clear()
	for bone in _skeleton.get_bone_count():
		_skill_base.append(_skeleton.get_bone_pose(bone))
	_blend_skill_start(0.0)


func _advance_skill_motion(delta: float) -> void:
	if _skill_pose.is_empty() or not is_instance_valid(model) or anim == null:
		return
	_skill_clock += delta
	var recovery := float(_skill_pose.recovery)
	var length := anim.get_animation(current).length
	# Restore constant tracks while blending. Animated tracks are then sampled
	# by AnimationPlayer; once the short blend ends this loop is empty.
	for bone in _skill_base.size():
		_skeleton.set_bone_pose(bone, _skill_base[bone])
	anim.seek(SkillChoreography.source_time(_skill_pose, _skill_clock, _skill_release, length), true)
	_blend_skill_start(smoothstep(0.0, minf(0.10, _skill_release * 0.4), _skill_clock))
	var windup := clampf(_skill_clock / _skill_release, 0.0, 1.0)
	var follow := clampf((_skill_clock - _skill_release) / recovery, 0.0, 1.0)
	var pulse := sin(windup * PI * 0.5) * (1.0 - smoothstep(0.0, 1.0, follow))
	var recoil := sin(follow * PI) * 0.045
	var pose := _skill_rest
	pose.basis = Basis(Vector3.RIGHT, float(_skill_pose.lean) * pulse) * pose.basis
	pose.origin += Vector3(0, float(_skill_pose.lift) * pulse, float(_skill_pose.step) * pulse - recoil)
	if bool(_skill_pose.get("elite", false)):
		var gather := sin(windup * PI) * (1.0 - follow)
		var strike := smoothstep(0.64, 1.0, windup) * (1.0 - smoothstep(0.0, 1.0, follow))
		var twist := float(_skill_pose.get("twist", 0.0))
		pose.basis = Basis(Vector3.UP, twist * (gather - strike * 0.55)) * pose.basis
		pose.origin.y -= float(_skill_pose.get("crouch", 0.0)) * gather
	model.transform = pose
	if _skill_chest >= 0:
		# Elevate the entire bow/arm chain together; keep feet and grip alignment.
		var chest_rotation := _skeleton.get_bone_pose_rotation(_skill_chest)
		_skeleton.set_bone_pose_rotation(_skill_chest,chest_rotation * Quaternion(Vector3.RIGHT,float(_skill_pose.upper_pitch)*pulse))
	if bool(_skill_pose.get("sky_sword",false)):
		_point_sword_sky()
	if _skill_clock >= _skill_release + recovery:
		_cancel_skill_motion()
		busy_until = 0
		current = ""
		play(_locomotion, 0.14, _locomotion_speed)


func _blend_skill_start(weight: float) -> void:
	if weight >= 1.0:
		_skill_start.clear()
		_skill_base.clear()
		return
	for bone in _skill_start.size():
		_skeleton.set_bone_pose(bone, _skill_start[bone].interpolate_with(_skeleton.get_bone_pose(bone), weight))


## Turn the complete sword arm at its shoulder, preserving the hand/socket.
## The raised pose remains steady through the tenth falling sword, then lowers.
func _point_sword_sky() -> void:
	var arm := _skeleton.find_bone("RightUpperArm" if chibi else "upperarm.r")
	if arm<0 or _emission_bone<0 or not is_instance_valid(_emission_grip): return
	var weight := smoothstep(_skill_release*0.45,_skill_release*0.90,_skill_clock)*(1.0-smoothstep(_skill_release+2.62,_skill_release+3.4,_skill_clock))
	var hand := _skeleton.get_bone_global_pose(_emission_bone)
	var axis := (hand.basis*_emission_grip.basis.y).normalized()
	var up := (_skeleton.global_basis.inverse()*Vector3.UP).normalized()
	var turn := Quaternion.IDENTITY.slerp(Quaternion(axis,up),weight)
	var posed := _skeleton.get_bone_global_pose(arm)
	posed.basis=Basis(turn)*posed.basis
	var parent := _skeleton.get_bone_parent(arm)
	var parent_pose := _skeleton.get_bone_global_pose(parent) if parent>=0 else Transform3D.IDENTITY
	# Godot bone poses are parent-relative transforms including the rest pose,
	# not a delta from rest. Subtracting rest twists the original KayKit rig.
	_skeleton.set_bone_pose(arm,parent_pose.affine_inverse()*posed)


func _cancel_skill_motion() -> void:
	skill_generation += 1
	if not _skill_pose.is_empty() and is_instance_valid(model):
		model.transform = _skill_rest
	_skill_pose.clear()
	_skill_start.clear()
	_skill_base.clear()
	_skill_clock = 0.0
	if chibi and anim_lod <= 1:
		set_process(false)


## The hit flash's own overlay, made once; the meshes are the outfit's (_lod_meshes).
var _flash_mat: StandardMaterial3D


func _flash_targets() -> Array:
	if not _lod_meshes.is_empty():
		# Gear changed since the list was made: its old pieces are gone.
		if _lod_meshes.any(func(mi): return not is_instance_valid(mi)):
			_lod_meshes.assign(_lod_meshes.filter(func(mi): return is_instance_valid(mi)))
		if not _lod_meshes.is_empty():
			return _lod_meshes
	return model.find_children("*", "MeshInstance3D", true, false) if model != null else []


func flash(color := Color(1, 0.35, 0.35), duration := 0.18) -> void:
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
	overlay.albedo_color = Color(color.r, color.g, color.b, 0.7)
	# A hit flash sits on top of whatever overlay a piece already wears (enhancement
	# glow, a summon's spirit light) and hands it back afterwards.
	# A new hit while the last flash is still fading takes that flash off first: kept as
	# if it were a lasting overlay, its half-faded tint stayed on for good (red heroes).
	if _tween:
		_tween.kill()
	_end_flash()
	for mi in meshes:
		if not is_instance_valid(mi):
			continue
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


func _restore_overlays() -> void:
	for mesh in _flash_restore:
		if is_instance_valid(mesh) and is_instance_valid(_flash_restore[mesh]):
			(mesh as MeshInstance3D).material_overlay = _flash_restore[mesh]
	_flash_restore.clear()
