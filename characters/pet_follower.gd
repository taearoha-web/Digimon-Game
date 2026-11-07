class_name PetFollower
extends Node3D
## Another player's pet walking along with its owner where nobody fights (PetCrowd): a
## world player or a party member in the village, a real online player (RemotePlayer), a
## world player mirrored from another game (FieldPlayer puppet). Only a picture: the
## pet's model (MonsterVisual: the GLB's meshes and the finish materials are shared by
## every copy), a blob shadow, no health bar, no name, no light, no particles, no
## physics or collision (it never blocks a villager or a door) and no thinking beyond a
## follow-lerp: it stays put while its owner stands near, walks (or runs, far behind) to a
## spot behind its owner when the owner moves off, idles facing the owner, and hops to the
## owner from too far. It joins the zone's animation LOD ("anim_lod") and is not drawn past
## PetCrowd.HIDE. PetCrowd keeps a few spare ones per pet to hand out again (attach /
## detach) instead of building a new model each time a player comes into view.

## A walking pet stands at this share of the fighting pet's height (the pen's are 0.75).
const SIZE := 0.8
## It sets off once its owner is this far, and stops this close to its spot.
const START := 2.6
const STOP := 0.3
## Behind and beside its owner (metres).
const SIDE := 1.2
const BACK := 1.5
## Farther than this from its owner it hops back to it.
const TELEPORT := 18.0

var pet_id := ""
var owner_node: Node3D
var visual: MonsterVisual

## The form shown (PetData.stage_for of its owner's level and ★), -1 before attach,
## and its cheap form look (PetForm.dress_lite).
var stage := -1
var form_root: Node3D

var _moving := false
var _spot := Vector3.ZERO
var _shadow: MeshInstance3D
## Seconds to the next look at its owner's level and ★ (an AI player levels up).
var _rank_in := 0.0
## Seconds between two such looks.
const RANK_EVERY := 2.0
## Whether it was dressed with the rim light (PetForm.crowd_rim, looked at with the rank).
var _rim := false


## The pet of [param id]'s model, built once (the crowd's spares keep theirs).
func build(id: String) -> void:
	pet_id = id
	name = "PetFollower_%s" % id
	add_to_group("pet_followers")
	var data := PetData.get_pet(id)
	visual = MonsterVisual.new()
	# Below high quality the crowd's pets skip the ink outline (a second draw per mesh).
	visual.outline = GameSettings.quality >= 2
	add_child(visual)
	var skin: Texture2D = load(String(data.skin)) as Texture2D if String(data.get("skin", "")) != "" else null
	visual.setup(String(data.model), float(data.height) * SIZE, 0.0, data.tint, skin)
	for mi in visual.find_children("*", "MeshInstance3D", true, false):
		(mi as GeometryInstance3D).visibility_range_end = PetCrowd.HIDE
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow = MeshKit.blob_shadow(self, 0.45)
	_shadow.visibility_range_end = PetCrowd.HIDE


## Walks with [param who] from now on, starting right behind it.
func attach(who: Node3D) -> void:
	owner_node = who
	# Its form follows its owner's level and ★ (PetData.stage_for).
	stage = -1
	_update_form()
	_rank_in = RANK_EVERY
	_moving = false
	global_position = who.global_position + spot_behind(who, SIDE, BACK)
	rotation.y = _owner_yaw(who)
	visible = true
	set_process(true)
	if visual:
		visual.add_to_group("anim_lod")
		visual.set_process(true)
		if visual.anim:
			visual.anim.active = true
		visual.play("idle")


## Its owner's level and ★: an AI player's member sheet (a world player, a party member,
## a mirrored world player), a real online player's state (its look as a fallback).
static func owner_rank(who: Object) -> Vector2i:
	if who == null:
		return Vector2i(1, 0)
	if "member" in who and who.member is Dictionary:
		var m: Dictionary = who.member
		return Vector2i(int(m.get("level", 1)), Game.party_stars(m))
	var level := 1
	var stars := 0
	var found := false
	for key in ["player", "look"]:
		if key in who and who.get(key) is Dictionary and not found:
			var d: Dictionary = who.get(key)
			if d.has("level"):
				level = Online.num(d.get("level", 1), 1)
				stars = Online.num(d.get("stars", 0), 0)
				found = true
	if not found and "level" in who:
		level = int(who.level)
		stars = int(who.stars) if "stars" in who else 0
	return Vector2i(maxi(1, level), clampi(stars, 0, Game.PARAGON_MAX))


## Sizes and dresses it for its owner's form now (only when the form changes).
func _update_form() -> void:
	var rank := owner_rank(owner_node)
	var next := PetData.stage_for(rank.x, rank.y)
	var rim := PetForm.crowd_rim()
	if (next == stage and rim == _rim) or visual == null:
		return
	stage = next
	_rim = rim
	visual.scale = Vector3.ONE * float(PetData.STAGE_SCALE[stage])
	PetForm.clear(form_root)
	form_root = PetForm.dress_lite(self, visual, pet_id, stage, float(PetData.get_pet(pet_id).get("height", 1.5)) * SIZE, PetCrowd.HIDE)
	if form_root:
		form_root.scale = visual.scale


## Back to the crowd's spares: hidden, not thinking, not animating.
func detach() -> void:
	owner_node = null
	visible = false
	set_process(false)
	if visual:
		visual.remove_from_group("anim_lod")
		visual.set_process(false)
		if visual.anim:
			visual.anim.active = false


func _process(delta: float) -> void:
	var who := owner_node
	if who == null or not is_instance_valid(who) or not who.is_inside_tree():
		# The owner is gone: wait hidden for the crowd to take it back.
		visible = false
		set_process(false)
		return
	_rank_in -= delta
	if _rank_in <= 0.0:
		_rank_in = RANK_EVERY
		_update_form()
	var at := who.global_position
	var gap := Vector2(at.x - global_position.x, at.z - global_position.z).length()
	if gap > TELEPORT:
		global_position = at + spot_behind(who, SIDE, BACK)
		_moving = false
		gap = 0.0
	if not _moving and gap > START:
		_moving = true
		_spot = spot_behind(who, SIDE, BACK)
	var speed := float(PetData.get_pet(pet_id).get("speed", 5.5)) * 0.85
	if _moving:
		var to := at + _spot - global_position
		to.y = 0.0
		var dist := to.length()
		if dist <= STOP:
			_moving = false
		else:
			var hurry := clampf(dist / 4.0, 0.6, 1.8)
			global_position += to / dist * minf(dist, speed * hurry * delta)
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 1.0 - exp(-10.0 * delta))
			visual.play("run" if hurry > 1.3 else "walk")
	if not _moving:
		var look := at - global_position
		if look.length_squared() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(look.x, look.z), 1.0 - exp(-3.0 * delta))
		visual.play("idle")
	global_position.y = at.y


## Where a pet stands relative to its owner [param who]: [param back] metres behind and
## [param side] to its left, by the way the owner faces (a party member's or world
## player's _facing, a fighter's _yaw, else its turn).
static func spot_behind(who: Node3D, side: float, back: float) -> Vector3:
	return Vector3(side, 0.0, -back).rotated(Vector3.UP, _owner_yaw(who))


static func _owner_yaw(who: Node3D) -> float:
	if "_facing" in who:
		return float(who._facing)
	if "_yaw" in who:
		return float(who._yaw)
	return who.rotation.y
