class_name VfxBudget
extends RefCounted
## A shared visual budget. Decorative effects may be omitted; gameplay callbacks,
## projectiles and enemy warning circles are never gated by this class.
##
## The player's own hero has a room of its own beside the shared budget. While the hero
## casts (hero_begin / hero_end round its cast, its landing and its hits; carry for a
## piece of it that waits), effects may draw from the hero's room as well as from the
## shared one. Nothing else (AI world players, party members, pets, auras) ever spends
## the hero's room, so a crowded field on a phone under memory pressure, whose casts keep
## the shared budget full, can no longer leave the player's own skills with nothing to
## show (an iPhone report: "when I use a skill I don't see its effect at all"). The room
## shrinks with the quality and the memory pressure like the shared budget, down to a
## floor that still fits a class signature, whose layers ask for up to
## ClassFlourish.RESERVE decorations of headroom.

static var _particles := 0
static var _decorations := 0
static var _lights := 0
## What the hero's own effects hold of the hero's room.
static var _hero_particles := 0
static var _hero_decorations := 0
## Inside a hero cast (nesting depth), only within the frame it was opened in: a scope
## an aborted call left open closes itself by the next frame.
static var _hero_depth := 0
static var _hero_frame := -1
## Which room the last reserve_particles / reserve_decoration charged (pools keep it
## and pass it back on release).
static var last_from_hero := false

## The hero's room: this share of the shared limits, never below the floors.
const HERO_SHARE := 0.5
const HERO_DECORATION_FLOOR := 28
const HERO_PARTICLE_FLOOR := 72


static func quality() -> int:
	GameSettings.load_settings()
	return clampi(GameSettings.quality, 0, 2)


## Decorative counts shrink with the quality setting and, while memory is
## tight (MemoryGuard.pressure), with the pressure level too.
static func count(requested: int, minimum := 1) -> int:
	return maxi(minimum, int(ceil(float(requested) * [0.35, 0.65, 1.0][quality()] * MemoryGuard.effect_scale())))


static func particle_limit() -> int:
	return int([120, 240, 420][quality()] * MemoryGuard.effect_scale())


static func decoration_limit() -> int:
	return int([28, 54, 88][quality()] * MemoryGuard.effect_scale())


static func hero_decoration_room() -> int:
	return maxi(HERO_DECORATION_FLOOR, int(decoration_limit() * HERO_SHARE))


static func hero_particle_room() -> int:
	return maxi(HERO_PARTICLE_FLOOR, int(particle_limit() * HERO_SHARE))


## The hero's own cast, landing or hit begins / ends: effects built in between may use
## the hero's room. Calls nest; always pair them.
static func hero_begin() -> void:
	var frame := Engine.get_process_frames()
	if _hero_frame != frame:
		_hero_frame = frame
		_hero_depth = 0
	_hero_depth += 1


static func hero_end() -> void:
	_hero_depth = maxi(0, _hero_depth - 1)


## Whether the effect being built now belongs to the hero's own cast.
static func for_hero() -> bool:
	return _hero_depth > 0 and _hero_frame == Engine.get_process_frames()


## A piece of the hero's cast that waits (a tween or timer callback without arguments)
## keeps the hero's room when it runs. Outside a hero cast it comes back unchanged.
static func carry(fn: Callable) -> Callable:
	if not for_hero():
		return fn
	return func():
		hero_begin()
		fn.call()
		hero_end()


## Particles free for the effect being built now (the hero's room counts in a hero cast).
static func particle_room() -> int:
	var shared := maxi(0, particle_limit() - _particles)
	if for_hero():
		return maxi(shared, hero_particle_room() - _hero_particles)
	return shared


## Charges [param amount] particles (no more than particle_room): the hero's room first
## in a hero cast. Returns whether the hero's room paid.
static func _charge_particles(amount: int) -> bool:
	if for_hero() and hero_particle_room() - _hero_particles >= amount:
		_hero_particles += amount
		return true
	_particles += amount
	return false


static func _charge_decoration() -> bool:
	if for_hero() and _hero_decorations < hero_decoration_room():
		_hero_decorations += 1
		return true
	_decorations += 1
	return false


## Emitters release their reservation even when a zone is removed mid-effect.
static func track_particles(emitter: CPUParticles3D, requested: int) -> bool:
	var amount := mini(count(requested), particle_room())
	if amount == 0:
		# A carrier can still complete its flight / damage callback. Only this
		# cosmetic child is disabled, including persistent buff emitters.
		emitter.amount = 1
		emitter.emitting = false
		emitter.visible = false
		emitter.process_mode = Node.PROCESS_MODE_DISABLED
		return false
	emitter.amount = amount
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hero := _charge_particles(amount)
	emitter.tree_exited.connect(func(): release_particles(amount, hero), CONNECT_ONE_SHOT)
	return true


## Room for [param cost] more decorations (callers add the headroom they leave for
## later layers and hits). Inside a hero cast the hero's room counts too.
static func can_decorate(cost := 1) -> bool:
	if _decorations + cost <= decoration_limit():
		return true
	return for_hero() and _hero_decorations + cost <= hero_decoration_room()


static func track_decoration(node: Node) -> void:
	var hero := _charge_decoration()
	node.tree_exited.connect(func(): release_decoration(hero), CONNECT_ONE_SHOT)


static func can_light() -> bool:
	return quality() == 2 and MemoryGuard.pressure == 0 and _lights < 3


static func track_light(node: OmniLight3D) -> void:
	_lights += 1
	node.shadow_enabled = false
	node.tree_exited.connect(func(): _lights = maxi(0, _lights - 1), CONNECT_ONE_SHOT)


## Pooled effects (SkillLayerPool, MeleeArt) keep their nodes and borrow budget while
## they play: [param amount] is already scaled; returns what fits (0: show nothing).
## last_from_hero tells which room paid: hand it back to release_particles.
static func reserve_particles(amount: int) -> int:
	var granted := maxi(0, mini(amount, particle_room()))
	last_from_hero = false
	if granted > 0:
		last_from_hero = _charge_particles(granted)
	return granted


static func release_particles(amount: int, hero := false) -> void:
	if hero:
		_hero_particles = maxi(0, _hero_particles - amount)
	else:
		_particles = maxi(0, _particles - amount)


## Takes one decoration (after can_decorate); returns whether the hero's room paid,
## to hand back to release_decoration.
static func reserve_decoration() -> bool:
	last_from_hero = _charge_decoration()
	return last_from_hero


static func release_decoration(hero := false) -> void:
	if hero:
		_hero_decorations = maxi(0, _hero_decorations - 1)
	else:
		_decorations = maxi(0, _decorations - 1)


## A pooled light takes one of the scene's few effect lights while it shines.
static func claim_light() -> bool:
	if not can_light():
		return false
	_lights += 1
	return true


static func free_light() -> void:
	_lights = maxi(0, _lights - 1)


## Everything held: the shared budget and the hero's room together.
static func counters() -> Dictionary:
	return {"particles": _particles + _hero_particles, "decorations": _decorations + _hero_decorations, "lights": _lights}


## What the hero's own effects hold of the hero's room.
static func hero_counters() -> Dictionary:
	return {"particles": _hero_particles, "decorations": _hero_decorations}


## The counters plus the memory pressure level (for the web session samples).
static func report() -> Dictionary:
	var out := counters()
	out["hero"] = _hero_decorations
	out["pressure"] = MemoryGuard.pressure
	return out

