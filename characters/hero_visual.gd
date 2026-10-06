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


## p_model: wear another character's stock look (villagers); armed=false = no weapon.
func setup(p_class: StringName, p_model := "", armed := true, p_equip := {}, p_look := {}) -> void:
	class_id = p_class
	look = p_look
	for child in get_children():
		child.queue_free()
	var data := ClassData.get_class_data(class_id)
	model_name = p_model if p_model != "" else String(data.model)
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


## Rebuilds everything the hero wears from [member equip] (slot -> item).
func set_equipment(p_equip: Dictionary) -> void:
	equip = p_equip
	refresh()


func refresh() -> void:
	for n in _body_nodes:
		if is_instance_valid(n):
			n.free()
	_body_nodes.clear()
	for n in _hold_nodes:
		if is_instance_valid(n):
			n.free()
	_hold_nodes.clear()
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
	for piece in OUTFIT_PARTS:
		var piece_tint := outfit_tint
		if boots != null and piece.begins_with("Leg"):
			piece_tint *= ItemLook.boots_tint(boots)
		var part := _add_part(glb, "%s_%s" % [glb, piece], piece_tint)
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
	if cape != null and cape is Array:
		var cape_tint := Color(2.2, 2.2, 2.0) if (priest and armor == null) else outfit_tint
		_add_part(cape[0], cape[1], cape_tint)
	if helm != null:
		var hat := ItemLook.helm_look(helm)
		_wear_hat(hat)
	elif preset.has("hat") and look.is_empty():
		_add_part(preset.hat[0], preset.hat[1], PRIEST_GOLD if priest else Color.WHITE)
	_wear_trinkets()
	_hold_gear()
	_polish()


static var _outline_material: StandardMaterial3D


## One dark hull shared by every character: a thin cartoon outline.
static func outline_material() -> StandardMaterial3D:
	if _outline_material == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.09, 0.05, 0.13)
		m.cull_mode = BaseMaterial3D.CULL_FRONT
		m.grow = true
		m.grow_amount = 0.02
		_outline_material = m
	return _outline_material


## Premium finish: a cartoon outline and a soft rim light on everything the
## hero wears (glowing / transparent effect meshes are left alone).
func _polish() -> void:
	var meshes: Array[MeshInstance3D] = []
	for node in find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	# Thin held gear (bows, staffs) only gets the rim light: an outline would swallow it.
	var held: Array[Node] = []
	for hold in _hold_nodes:
		held.append(hold)
		held.append_array(hold.find_children("*", "MeshInstance3D", true, false))
	for mi in meshes:
		if mi.mesh == null or mi.has_meta("polished"):
			continue
		mi.set_meta("polished", true)
		var outlined := not (mi in held)
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
		var copy := std.duplicate() as StandardMaterial3D
		copy.rim_enabled = true
		copy.rim = 0.25
		copy.rim_tint = 0.6
		if outlined:
			copy.next_pass = outline_material()
		return copy
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
		elif slot == "weapon" and int(item.get("plus", 0)) >= 7 and color.a == 0.0:
			color = Color("ffd23c")
	var tier := _top_tier()
	if tier >= 6:
		color = GearKit.TIERS_METAL[tier]
		if tier >= 8:
			var halo := BoneAttachment3D.new()
			halo.name = "Halo"
			halo.bone_name = "head"
			_skeleton.add_child(halo)
			halo.add_child(GearKit.halo(tier))
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
	mat.albedo_color = color
	quad.material = mat
	p.mesh = quad
	var grand := maxi(tier - 5, 0)
	p.amount = 14 + grand * 10
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
	attach.add_child(FaceKit.build_head(look, with_hair))
	_body_nodes.append(attach)


func _wear_hat(hat: Dictionary) -> void:
	if hat.has("part"):
		var worn := _add_part(hat.part[0], hat.part[1], hat.tint)
		_lift_hat(worn)
		return
	var attach := BoneAttachment3D.new()
	attach.name = "Hat"
	attach.bone_name = "head"
	_skeleton.add_child(attach)
	var model_hat := GearKit.hat(hat.proc, hat.tint)
	attach.add_child(model_hat)
	_lift_hat(model_hat)
	_body_nodes.append(attach)


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
	_hold(weapon_look, "handslot.r")
	match class_id:
		&"warrior":
			_hold("shield_0", "handslot.l")
		&"priest":
			_hold("book", "handslot.l")


func _hold(look: String, bone: String) -> void:
	var item: Node3D
	if look.begins_with("shield"):
		item = WeaponKit.shield(look)
	elif look == "book":
		item = WeaponKit.book()
	else:
		item = WeaponKit.build(look)
	var attach := BoneAttachment3D.new()
	attach.name = "Held_" + look
	attach.bone_name = bone
	_skeleton.add_child(attach)
	var pivot := Node3D.new()
	pivot.rotation = Vector3(0, PI, 0) if bone == "handslot.r" else Vector3(0, PI, 0)
	attach.add_child(pivot)
	pivot.add_child(item)
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
	if _skeleton == null or _head_bone < 0:
		return
	var pose := _skeleton.get_bone_global_pose_no_override(_head_bone)
	pose.basis = pose.basis.scaled(Vector3.ONE * CHIBI_HEAD)
	_skeleton.set_bone_global_pose_override(_head_bone, pose, 1.0, true)


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
