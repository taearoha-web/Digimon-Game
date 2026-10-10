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

## A spear is carried slanted forward, point up (pitch, yaw, roll in degrees).
static var spear_tilt := Vector3(-48.0, 22.0, 0.0)
## A lantern staff is held upright so the lantern hangs from its crook.
static var lantern_tilt := Vector3(0.0, 0.0, -75.0)
static var _shared_library: AnimationLibrary

var class_id: StringName = &"warrior"
var model_name := ""
var equip: Dictionary = {}
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
var _face: FaceExpression
## True for the rigged chibi models; gear built for KayKit units is scaled by _gear_scale.
var chibi := false
var _gear_scale := 1.0


## p_model: wear another character's stock look (villagers); armed=false = no weapon.
func setup(p_class: StringName, p_model := "", armed := true, p_equip := {}, p_look := {}) -> void:
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
	for clip in anim.get_animation_list():
		var a := anim.get_animation(clip)
		a.loop_mode = Animation.LOOP_LINEAR if clip in LOOPING else Animation.LOOP_NONE
	# KayKit rigs report a tall bind-pose box; the standing body is ~2.2 units.
	model.scale = Vector3.ONE * (HEIGHT / 2.2)
	_head_bone = _skeleton.find_bone("head")
	set_process(_head_bone >= 0)
	equip = p_equip
	_armed = armed
	refresh()
	play("Idle")


var _armed := true


func _setup_chibi(armed: bool, p_equip: Dictionary) -> void:
	var gender := clampi(int(look.get("gender", 0)), 0, 1)
	model = (load(CHIBI_MODELS[gender]) as PackedScene).instantiate() as Node3D
	add_child(model)
	_skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip in anim.get_animation_list():
		var a := anim.get_animation(clip)
		a.loop_mode = Animation.LOOP_LINEAR if (clip in LOOPING or clip.begins_with("Chibi_")) else Animation.LOOP_NONE
	var height := 0.0
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		height = maxf(height, (mi as MeshInstance3D).get_aabb().size.y)
	model.scale = Vector3.ONE * (CHIBI_HEIGHT / maxf(height, 0.1))
	_gear_scale = (HEIGHT / 2.2) / model.scale.x
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
		armor_nodes = _chibi_armor(ItemLook.tier_of(armor))
	if helm != null:
		var crown := _chibi_attach("Head", "ChibiHelm")
		ChibiGear.headpiece(crown, ItemLook.tier_of(helm))
		EnhanceFx.glow_piece(self, [crown.get_parent()], int(helm.get("plus", 0)), Vector3(0, 2.2, 0), 0.25)
	var boot_nodes: Array = []
	if boots != null:
		for side in ["Left", "Right"]:
			var cuff := _chibi_attach(side + "LowerLeg", "ChibiBoots")
			ChibiGear.boot_cuff(cuff, ItemLook.tier_of(boots))
			boot_nodes.append(cuff.get_parent())
	if equip.get("amulet") != null:
		ChibiGear.pendant(_chibi_attach("Chest", "ChibiAmulet"), ItemLook.tier_of(equip.amulet))
	EnhanceFx.glow_piece(self, armor_nodes, int(equip.get("armor", {}).get("plus", 0)), Vector3(0, 1.1, 0), 0.4)
	EnhanceFx.glow_piece(self, boot_nodes, int(equip.get("boots", {}).get("plus", 0)), Vector3(0, 0.3, 0), 0.4)
	var wings: Variant = equip.get("wings")
	if wings is Dictionary:
		# The wing models share the chibi's model space: undo the chest's rest pose.
		var back := _chibi_attach("Chest", "Wings")
		var chest := _skeleton.find_bone("Chest")
		if chest >= 0:
			back.transform = _skeleton.get_bone_global_rest(chest).affine_inverse()
		back.add_child(GearKit.wings(_wing_kind(wings)))
		EnhanceFx.glow_piece(self, [back.get_parent()], int(wings.get("plus", 0)), WING_GLOW, 0.5)
	_make_aura()
	_hold_gear()
	_polish()


## A node on a chibi bone whose axes are the model's (x side, y up, z front) and
## whose units are the chibi skeleton's.
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
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.skin == null or mi.mesh == null:
			continue
		var source := mi.mesh.surface_get_material(0) as StandardMaterial3D
		if source == null:
			continue
		var mat := ShaderMaterial.new()
		mat.shader = CHIBI_OUTFIT
		mat.set_shader_parameter("albedo_tex", source.albedo_texture)
		if armor != null:
			var tier := ItemLook.tier_of(armor)
			mat.set_shader_parameter("outfit_color", ChibiGear.cloth(tier))
			mat.set_shader_parameter("outfit_amount", 0.5 + 0.04 * float(tier))
			mat.set_shader_parameter("sheen", 0.0 if tier < 2 else 0.2 + 0.08 * float(tier))
			if tier >= 7:
				mat.set_shader_parameter("glow_color", ChibiGear.cloth(tier) * 0.35)
		if GameSettings.quality > 0:
			mat.next_pass = StorybookFinish.outline(0.012 * _gear_scale)
		mi.material_override = mat
		mi.set_meta("polished", true)


## Rebuilds everything the hero wears from [member equip] (slot -> item).
func set_equipment(p_equip: Dictionary) -> void:
	equip = p_equip
	refresh()


func refresh() -> void:
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
	var glb: String = OUTFIT_GLB[outfit_style]
	var boots: Variant = equip.get("boots")
	var armor_nodes: Array = []
	var boot_nodes: Array = []
	for piece in OUTFIT_PARTS:
		var piece_tint := outfit_tint
		if boots != null and piece.begins_with("Leg"):
			piece_tint *= ItemLook.boots_tint(boots)
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
	if preset.has("extra") and armor == null:
		_add_part(preset.extra[0], preset.extra[1])
	if armor != null:
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
		var w := GearKit.wings(_wing_kind(wings))
		w.transform = KAYKIT_WINGS
		back.add_child(w)
		_body_nodes.append(back)
		EnhanceFx.glow_piece(self, [back], int(wings.get("plus", 0)), WING_GLOW, 0.5)
	if cape != null and cape is Array:
		var cape_tint := Color(2.2, 2.2, 2.0) if (priest and armor == null) else outfit_tint
		_add_part(cape[0], cape[1], cape_tint)
	if helm != null:
		var hat := ItemLook.helm_look(helm)
		var before_count := _body_nodes.size()
		var worn_part: Node = _wear_hat(hat)
		var hat_nodes: Array = []
		if worn_part != null:
			hat_nodes.append(worn_part)
		elif _body_nodes.size() > before_count:
			hat_nodes.append(_body_nodes[_body_nodes.size() - 1])
		EnhanceFx.glow_piece(self, hat_nodes, int(helm.get("plus", 0)), Vector3(0, 1.85, 0), 0.25)
	elif preset.has("hat") and look.is_empty():
		_add_part(preset.hat[0], preset.hat[1], PRIEST_GOLD if priest else Color.WHITE)
	var cuff_start := _body_nodes.size()
	_wear_trinkets()
	if boots != null:
		for n in _body_nodes.slice(cuff_start):
			if n is BoneAttachment3D and (n as BoneAttachment3D).name == "Boots":
				boot_nodes.append(n)
	EnhanceFx.glow_piece(self, armor_nodes, int(equip.get("armor", {}).get("plus", 0)), Vector3(0, 1.0, 0), 0.4)
	EnhanceFx.glow_piece(self, boot_nodes, int(equip.get("boots", {}).get("plus", 0)), Vector3(0, 0.25, 0), 0.4)
	_hold_gear()
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
	if boots != null:
		var tier := ItemLook.tier_of(boots)
		for side in [1.0, -1.0]:
			var attach := BoneAttachment3D.new()
			attach.name = "Boots"
			attach.bone_name = "lowerleg.l" if side > 0.0 else "lowerleg.r"
			_skeleton.add_child(attach)
			attach.add_child(GearKit.boot_cuff(tier, side))
			_body_nodes.append(attach)
	var ring: Variant = equip.get("ring")
	if ring != null:
		var ring_attach := BoneAttachment3D.new()
		ring_attach.name = "RingBand"
		ring_attach.bone_name = "wrist.l"
		_skeleton.add_child(ring_attach)
		ring_attach.add_child(GearKit.ring_band(ItemLook.tier_of(ring)))
		_body_nodes.append(ring_attach)
	_make_aura()
	var amulet: Variant = equip.get("amulet")
	if amulet != null:
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
	var best := EnhanceFx.best_plus(equip)
	if best >= 4:
		color = EnhanceFx.color_of(best)
		_body_nodes.append_array(EnhanceFx.on_body(self, best))
	var tier := _top_tier()
	if tier >= 6:
		color = GearKit.TIERS_METAL[tier].lerp(Color("ffd870"), 0.35)
		if tier >= 8:
			var halo := BoneAttachment3D.new()
			halo.name = "Halo"
			halo.bone_name = _bone("head")
			_skeleton.add_child(halo)
			var ring := GearKit.halo(tier)
			if chibi:
				ring.scale *= _gear_scale
			halo.add_child(ring)
			_body_nodes.append(halo)
	if color.a == 0.0:
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
	p.amount = 14 + grand * 10 + (best * 3 if best >= 4 else 0)
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
	_hold(weapon_look, "handslot.r", int(equip.get("weapon", {}).get("plus", 0)))
	match class_id:
		&"warrior":
			_hold("shield_%d" % (ItemLook.tier_of(equip.weapon) if equip.get("weapon") is Dictionary else 0), "handslot.l")
		&"priest":
			_hold("book_%d" % (ItemLook.tier_of(equip.weapon) if equip.get("weapon") is Dictionary else 0), "handslot.l")
		&"summoner":
			_hold("tome_%d" % (ItemLook.tier_of(equip.weapon) if equip.get("weapon") is Dictionary else 0), "handslot.l")


func _hold(look: String, bone: String, plus := 0) -> void:
	var item: Node3D
	if look.begins_with("shield"):
		item = WeaponKit.shield(look)
	elif look.begins_with("book_"):
		item = WeaponKit.book(int(look.trim_prefix("book_")))
	else:
		item = WeaponKit.build(look)
	var attach := BoneAttachment3D.new()
	attach.name = "Held_" + look
	attach.bone_name = bone
	_skeleton.add_child(attach)
	var pivot := Node3D.new()
	pivot.rotation = Vector3(0, PI, 0)
	if look.begins_with("spear"):
		pivot.rotation_degrees = Vector3(0, 180.0, 0) + spear_tilt
	elif look.begins_with("lantern"):
		pivot.rotation_degrees = Vector3(0, 180.0, 0) + lantern_tilt
	if chibi:
		pivot.basis = _slot_fix(bone) * pivot.basis
	pivot.scale = Vector3.ONE * _gear_scale
	attach.add_child(pivot)
	pivot.add_child(item)
	if plus > 0:
		EnhanceFx.on_item(item, plus)
	_hold_nodes.append(attach)


## The free Adventurers 2.0 characters ship without animations; they share the
## Knight's rig, so give them the Knight's clips.
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


## Big head = cuter. Scales the head bone after the animation has posed it.
func _process(_delta: float) -> void:
	if is_instance_valid(_face):
		_face.asleep = current.begins_with("Death") or current.begins_with("Lie")
	if _skeleton == null or _head_bone < 0:
		return
	var pose := _skeleton.get_bone_global_pose_no_override(_head_bone)
	pose.basis = pose.basis.scaled(Vector3.ONE * CHIBI_HEAD)
	_skeleton.set_bone_global_pose_override(_head_bone, pose, 1.0, true)


func has_clip(clip: String) -> bool:
	return anim != null and anim.has_animation(clip)


## Loops a locomotion clip (ignored while a one-shot action is still playing).
func play(clip: String, blend := 0.15, speed := 1.0) -> void:
	if clip == "Idle" and class_id == &"lancer":
		clip = "2H_Melee_Idle"

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
