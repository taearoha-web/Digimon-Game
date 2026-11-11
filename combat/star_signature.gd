class_name StarSignature
extends RefCounted
## Signature art of the star skills below the god tier (50 / 100 / 150 / 200 stars): one
## script per skill id, res://combat/star_art/<skill id>.gd, the same idea as the god skills'
## combat/god_art (GodSkillArt.signature). Cosmetic ONLY: StarSkillSequence owns every
## contact, target, buff and timing; a signature only dresses the beats it already plays.
##
## A signature script exposes static functions, each returning true when it drew its beat:
##   telegraph(art, caster, skill, point, time)       the wind-up (art: the caster's root)
##   launch(art, caster, skill, point, duration)      a carrier's flight (optional)
##   strike(art, parent, skill, point, index, source) any contact (index = hit number), or
##   wave(...) / finale(...) as the god art has them, the finale on the script's LAST index
##   drop(caster, parent, point, index, flight) / canopy(parent, point, radius, duration)
##                                                    Celestial Swordfall's falling swords
## When a skill has one, it owns the whole show (owns): the shared class systems
## (ClassFlourish, ClassSignature, CasterArt, MeleeArt, ShadowSkillArt, the SkillLayers
## stack and the generic star motifs) stay out, exactly as they do for a god skill.
## Every root it opens is tied to its cast (GodSkillArt.bind_roots): the hero dying or
## leaving mid-cast fades the set piece out at once.
const DIR := "res://combat/star_art/%s.gd"
static var _scripts := {}


## The signature script of [param id] (null when it has none). Looked up once.
static func script_for(id) -> GDScript:
	var key := String(id)
	if key == "" or key.begins_with("_"):
		return null
	if not _scripts.has(key):
		var path := DIR % key
		_scripts[key] = load(path) if ResourceLoader.exists(path) else null
	return _scripts[key]


## A real star skill (authored, with its own timing) below the god tier whose signature
## art draws every beat. Lookalikes that only borrow a star skill's id for its colours
## (a star monster's attack) carry no hit_delay and keep the shared art.
static func owns(skill: Dictionary) -> bool:
	if skill.is_empty() or not skill.has("star") or not skill.has("hit_delay") or StarSkillData.is_god(skill):
		return false
	return script_for(skill.get("id", "")) != null


## The running cast (StarSkillSequence) of [param id] by [param caster], if any.
static func _cast_of(caster: Node, id: String) -> Node:
	if not is_instance_valid(caster):
		return null
	var node := caster.get_node_or_null("StarCast_" + id)
	if node == null and caster.get("hero") is Node:
		node = (caster.get("hero") as Node).get_node_or_null("StarCast_" + id)
	return node


## Seconds the cast of [param id] still has to run (0: no cast is running).
static func _left(id: String) -> float:
	var ref: WeakRef = GodSkillArt._casts.get(id)
	var cast: Node = ref.get_ref() if ref else null
	if not is_instance_valid(cast) or cast.get("end") == null:
		return 0.0
	return maxf(0.0, float(cast.get("end")) - float(cast.get("clock")))


static func _bind(parent: Node, id: String) -> void:
	var left := _left(id) - GodSkillArt.CAST_MARGIN
	if left > 0.0:
		GodSkillArt.bind_roots(parent, id, left)


## The cast's flat forward (where the hero faced at the cast), or the root's own.
static func forward(art: Node3D, id: String) -> Vector3:
	var ref: WeakRef = GodSkillArt._casts.get(id)
	var cast: Node = ref.get_ref() if ref else null
	if is_instance_valid(cast) and cast.get("forward") is Vector3:
		return cast.get("forward")
	return art.global_basis.z if is_instance_valid(art) else Vector3.BACK


## A root sitting on its own source (a burst round the caster) turns to the cast's facing.
static func _aim(art: StarSkillArt, id: String, source: Vector3, point: Vector3) -> void:
	var flat := (point - source) * Vector3(1, 0, 1)
	if flat.length_squared() > 0.01:
		StarSkillArt._face(art, source, point)
		return
	var f := forward(art, id)
	if Vector2(f.x, f.z).length_squared() > 0.001:
		art.rotation.y = atan2(f.x, f.z)


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var id := String(skill.get("id", ""))
	var own := script_for(id)
	if art == null or own == null or not own.has_method("telegraph"):
		return false
	var cast := _cast_of(caster, id)
	GodSkillArt._casts[id] = weakref(cast) if cast else null
	_aim(art, id, art.global_position, point)
	if not own.telegraph(art, caster, skill, point, time):
		return false
	_bind(art.get_parent(), id)
	return true


static func launch(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, duration: float) -> bool:
	var id := String(skill.get("id", ""))
	var own := script_for(id)
	if art == null or own == null or not own.has_method("launch"):
		return false
	if not own.launch(art, caster, skill, point, duration):
		return false
	_bind(art.get_parent(), id)
	return true


## A contact: opens the contact root and lets the signature draw it. Returns the root.
static func strike(parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> StarSkillArt:
	var id := String(skill.get("id", ""))
	var own := script_for(id)
	if own == null or not is_instance_valid(parent):
		return null
	var art := StarSkillArt._root(parent, point, 1.0, "StarContact_%s_%d" % [id, index])
	if not art:
		return null
	_aim(art, id, source, point)
	var drawn := false
	if own.has_method("strike"):
		drawn = own.strike(art, parent, skill, point, index, source)
	else:
		var last := int(own.get_script_constant_map().get("LAST", 0))
		if index >= last and own.has_method("finale"):
			drawn = own.finale(art, parent, skill, point, source)
		elif own.has_method("wave"):
			drawn = own.wave(art, parent, skill, index, point, source)
	if drawn:
		_bind(parent, id)
	art._draw()
	return art


## Celestial Swordfall's falling swords and their sky (StarSkillArt.sword_drop / sword_canopy).
static func drop(id: String, caster: Node3D, parent: Node3D, point: Vector3, index: int, flight: float) -> StarSkillArt:
	var own := script_for(id)
	if own == null or not own.has_method("drop"):
		return null
	var art: StarSkillArt = own.drop(caster, parent, point, index, flight)
	if art:
		_bind(parent, id)
	return art


static func canopy(id: String, parent: Node3D, point: Vector3, radius: float, duration: float) -> StarSkillArt:
	var own := script_for(id)
	if own == null or not own.has_method("canopy"):
		return null
	var art: StarSkillArt = own.canopy(parent, point, radius, duration)
	if art:
		_bind(parent, id)
	return art
