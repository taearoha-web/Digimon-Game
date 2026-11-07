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
## A real online player's pet also shows its fights (act, from the owner's `pet_act`,
## PetSync): it runs to the monster, plays the attack or skill clip and a cheap flash of
## the skill, then walks back to its owner. It never deals damage: the owner's game did.

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

## A fight shown (act): it stays on it this long after the last act (seconds), never
## farther than FIGHT_LEASH from its owner, and plays a waiting act anyway after
## ACT_WAIT (it could not get there in time).
const FIGHT_HOLD := 2.6
const FIGHT_LEASH := 18.0
const ACT_WAIT := 0.8
const ACT_LOCK := 0.55
## Most act effects drawn per second by all followers together (cheap ones, VfxBudget).
const FX_PER_SEC := 6
static var _fx_sec := -1
static var _fx_count := 0

## Acts shown and effects drawn (tests).
var acts := 0
var fx_shown := 0
## The fight being shown: the target (WeakRef to a monster, or null), the point, until when.
var _fight: WeakRef
var _fight_at := Vector3.ZERO
var _fight_until := 0.0
var _lock_until := 0.0
## An act waiting to be played once it is in reach ({} none) and since when.
var _due: Dictionary = {}
var _due_since := 0.0


## The pet of [param id]'s model, built once (the crowd's spares keep theirs).
func build(id: String) -> void:
	pet_id = id
	name = "PetFollower_%s" % id
	add_to_group("pet_followers")
	var data := PetData.get_pet(id)
	visual = MonsterVisual.new()
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
	end_fight()
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
	if next == stage or visual == null:
		return
	stage = next
	visual.scale = Vector3.ONE * float(PetData.STAGE_SCALE[stage])
	PetForm.clear(form_root)
	form_root = PetForm.dress_lite(self, visual, pet_id, stage, float(PetData.get_pet(pet_id).get("height", 1.5)) * SIZE, PetCrowd.HIDE)
	if form_root:
		form_root.scale = visual.scale


## Back to the crowd's spares: hidden, not thinking, not animating.
func detach() -> void:
	owner_node = null
	end_fight()
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
	if _fight_until > 0.0 and _fight_tick(delta):
		return
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


# ---------------------------------------------------------------------------
# A real player's pet fighting (PetSync: pictures only, no damage here)
# ---------------------------------------------------------------------------

static func _now() -> float:
	return Time.get_ticks_msec() * 0.001


## Shows one act of its owner's pet ([param a] from PetSync.parse): off to the target,
## the clip and a cheap effect there. A second act while one waits plays the first now.
func act(a: Dictionary) -> void:
	if owner_node == null or not is_instance_valid(owner_node) or not visible:
		return
	var at: Vector3 = a.get("at", Vector3.ZERO)
	if Vector2(at.x - owner_node.global_position.x, at.z - owner_node.global_position.z).length() > PetSync.NEAR_OWNER:
		return
	if not _due.is_empty():
		_play(_due)
	var target: Variant = a.get("target")
	_fight = weakref(target) if target != null and is_instance_valid(target) else null
	_fight_at = Vector3(at.x, owner_node.global_position.y, at.z)
	_fight_until = _now() + FIGHT_HOLD
	_due = a
	_due_since = _now()
	_moving = false
	set_process(true)


## Back to plain following.
func end_fight() -> void:
	_fight = null
	_fight_until = 0.0
	_lock_until = 0.0
	_due = {}


## Whether it is showing a fight now.
func fighting() -> bool:
	return _fight_until > 0.0


func _fight_target() -> Node3D:
	if _fight == null:
		return null
	var t: Variant = _fight.get_ref()
	if t == null or not is_instance_valid(t) or not (t as Node).is_inside_tree() or (t as Node).is_queued_for_deletion():
		return null
	if (t as Object).has_method("is_dead") and bool(t.call("is_dead")):
		return null
	return t as Node3D


## How near the target it stands to show [param a] (metres): close for a bite, within
## the skill's range for a bolt or a breath, anywhere for a buff or a nova.
static func _reach_for(a: Dictionary, id: String) -> float:
	var skill: Dictionary = a.get("skill", {})
	match String(a.get("kind", "attack")):
		"bolt", "blast", "pull":
			return float(skill.get("range", 9.0)) * 0.7
		"cone", "line":
			return float(skill.get("range", 6.0)) * 0.6
		"nova", "self_buff", "owner_buff", "owner_heal", "owner_hot":
			return INF
	return float(PetData.get_pet(id).get("range", 1.6)) + 0.4


## One frame of the fight shown; false when it is over (it follows again).
func _fight_tick(delta: float) -> bool:
	var who := owner_node
	var now := _now()
	var t := _fight_target()
	if t == null and _due.is_empty() and now >= _lock_until:
		# The monster fell (or went) and nothing waits: back to the owner.
		end_fight()
		return false
	var from_owner := Vector2(who.global_position.x - global_position.x, who.global_position.z - global_position.z).length()
	if now > _fight_until or from_owner > FIGHT_LEASH:
		end_fight()
		return false
	var goal := t.global_position if t != null else _fight_at
	var to := goal - global_position
	to.y = 0.0
	var dist := to.length() - (float(t.call("body_radius")) if t != null and t.has_method("body_radius") else 0.5)
	var reach := _reach_for(_due, pet_id)
	if dist > reach and now >= _lock_until and to.length() > 0.05:
		var speed := float(PetData.get_pet(pet_id).get("speed", 5.5)) * 1.25
		global_position += to.normalized() * minf(dist - reach + 0.05, speed * delta)
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 1.0 - exp(-12.0 * delta))
		visual.play("run")
	else:
		if to.length() > 0.05:
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 1.0 - exp(-10.0 * delta))
		if now >= _lock_until:
			visual.play("idle")
	if not _due.is_empty() and (dist <= reach + 0.3 or now - _due_since >= ACT_WAIT):
		_play(_due)
	global_position.y = who.global_position.y
	return true


## Plays [param a]: the clip, then a cheap effect (only a picture, no damage).
func _play(a: Dictionary) -> void:
	_due = {}
	acts += 1
	_lock_until = _now() + ACT_LOCK
	visual.action(String(a.get("clip", "attack")), int(ACT_LOCK * 1000.0) + 150)
	_effect(a)


## Whether one more act effect may be drawn now: the shared per-second cap, the memory
## guard and the visual budget allow it.
static func _may_draw(cost := 1) -> bool:
	if MemoryGuard.pressure >= 2 or not VfxBudget.can_decorate(cost):
		return false
	var sec := int(Time.get_ticks_msec() / 1000.0)
	if sec != _fx_sec:
		_fx_sec = sec
		_fx_count = 0
	if _fx_count >= FX_PER_SEC:
		return false
	_fx_count += 1
	return true


func _effect(a: Dictionary) -> void:
	var field := get_parent() as Node3D
	if field == null or not is_inside_tree() or not _may_draw(2):
		return
	var data := PetData.get_pet(pet_id)
	var color: Color = data.get("color", Color.WHITE)
	var skill: Dictionary = a.get("skill", {})
	var t := _fight_target()
	var hit := _fight_at + Vector3(0, 0.8, 0)
	if t != null and t.has_method("hit_point"):
		hit = t.call("hit_point")
	var ground := Vector3(hit.x, global_position.y + 0.1, hit.z)
	fx_shown += 1
	match String(a.get("kind", "attack")):
		"bolt":
			_bolt(field, global_position + Vector3(0, 0.6, 0), hit, color)
		"blast", "pull":
			VfxKit.impact_ring(field, ground, color, float(skill.get("radius", 3.0)), 0.45)
		"nova", "self_buff":
			VfxKit.impact_ring(field, global_position + Vector3(0, 0.1, 0), color, float(skill.get("radius", 3.0)), 0.45)
		"cone", "line":
			VfxKit.impact_ring(field, global_position.lerp(ground, 0.6), color, 1.6, 0.35)
		"owner_buff", "owner_heal", "owner_hot":
			if owner_node != null and is_instance_valid(owner_node):
				VfxKit.impact_ring(field, owner_node.global_position + Vector3(0, 0.1, 0), data.get("glow", color), 1.4, 0.45)
		_:
			VfxKit.flash(field, hit, color, 0.9, 0.2)


## A small glowing ball from [param from] to [param to]: one mesh, no particles, no light.
static func _bolt(field: Node3D, from: Vector3, to: Vector3, color: Color) -> void:
	var ball := MeshInstance3D.new()
	ball.name = "PetBolt"
	ball.mesh = MeshKit.sphere_low()
	ball.material_override = MeshKit.toon(color.lightened(0.25), {"unshaded": true, "emission": 1.0})
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.scale = Vector3.ONE * 0.35
	field.add_child(ball)
	ball.global_position = from
	VfxBudget.track_decoration(ball)
	var tween := ball.create_tween()
	tween.tween_property(ball, "global_position", to, clampf(from.distance_to(to) / 20.0, 0.1, 0.45))
	tween.tween_callback(ball.queue_free)
