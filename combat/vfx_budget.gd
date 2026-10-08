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


static func count(requested: int, minimum := 1) -> int:
	return maxi(minimum, int(ceil(float(requested) * [0.35, 0.65, 1.0][quality()])))


static func particle_limit() -> int:
	return [120, 240, 420][quality()]


static func decoration_limit() -> int:
	return [28, 54, 88][quality()]


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
	return quality() == 2 and _lights < 3


static func track_light(node: OmniLight3D) -> void:
	_lights += 1
	node.shadow_enabled = false
	node.tree_exited.connect(func(): _lights = maxi(0, _lights - 1), CONNECT_ONE_SHOT)


static func counters() -> Dictionary:
	return {"particles": _particles, "decorations": _decorations, "lights": _lights}
