class_name VfxBudget
extends RefCounted
## A shared visual budget. Decorative effects may be omitted; gameplay callbacks,
## projectiles and enemy warning circles are never gated by this class.

static var _particles := 0
static var _decorations := 0
static var _lights := 0


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


## Emitters release their reservation even when a zone is removed mid-effect.
static func track_particles(emitter: CPUParticles3D, requested: int) -> bool:
	var amount := mini(count(requested), maxi(0, particle_limit() - _particles))
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
	_particles += amount
	emitter.tree_exited.connect(func(): _particles = maxi(0, _particles - amount), CONNECT_ONE_SHOT)
	return true


static func can_decorate(cost := 1) -> bool:
	return _decorations + cost <= decoration_limit()


static func track_decoration(node: Node) -> void:
	_decorations += 1
	node.tree_exited.connect(func(): _decorations = maxi(0, _decorations - 1), CONNECT_ONE_SHOT)


static func can_light() -> bool:
	return quality() == 2 and MemoryGuard.pressure == 0 and _lights < 3


static func track_light(node: OmniLight3D) -> void:
	_lights += 1
	node.shadow_enabled = false
	node.tree_exited.connect(func(): _lights = maxi(0, _lights - 1), CONNECT_ONE_SHOT)


## Pooled effects (SkillLayerPool) keep their nodes and borrow budget while they
## play: [param amount] is already scaled; returns what fits (0: show nothing).
static func reserve_particles(amount: int) -> int:
	var granted := mini(amount, maxi(0, particle_limit() - _particles))
	_particles += maxi(0, granted)
	return maxi(0, granted)


static func release_particles(amount: int) -> void:
	_particles = maxi(0, _particles - amount)


static func reserve_decoration() -> void:
	_decorations += 1


static func release_decoration() -> void:
	_decorations = maxi(0, _decorations - 1)


## A pooled light takes one of the scene's few effect lights while it shines.
static func claim_light() -> bool:
	if not can_light():
		return false
	_lights += 1
	return true


static func free_light() -> void:
	_lights = maxi(0, _lights - 1)


static func counters() -> Dictionary:
	return {"particles": _particles, "decorations": _decorations, "lights": _lights}


## The counters plus the memory pressure level (for the web session samples).
static func report() -> Dictionary:
	var out := counters()
	out["pressure"] = MemoryGuard.pressure
	return out
