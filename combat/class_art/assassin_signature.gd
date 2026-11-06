class_name AssassinSignature
extends RefCounted
## The Assassin's signature (ClassSignature): shadows and blood. Afterimage
## clones linger where the assassin dashed and stepped, crescent cuts tear open
## like cloth and fray away, smoke bombs billow into real smoke that thins and
## dissolves, poison drips and steams in green-violet vapour, a critical is
## marked by a red X, and eclipse skills darken the ground under a red rim of
## light.

const K = preload("res://combat/class_art/signature_kit.gd")
const NIGHT := [Color("9a6bff"), Color("f1e6ff"), Color("140a26")]
const BLOOD := [Color("ff3a5e"), Color("ffe2ea"), Color("26050f")]
const CRIT := [Color("ff2438"), Color("ffe8e8"), Color("3a0008")]
const VENOM := [Color("86e05a"), Color("f2ffd8"), Color("4a1660")]
const SMOKE := [Color("4a405e"), Color("9a8ab6"), Color("120e1c")]
const ECLIPSE := [Color("ff2a4a"), Color("ffd6dc"), Color("08030c")]
const DASHES := ["shadow_step", "backstab", "throat_slit", "midnight_execution", "shadow_execution", "night_raid", "shadow_dance"]
const SLASHES := ["twin_fang", "venom_edge", "backstab", "crimson_cut", "throat_slit", "eclipse_fang", "shadow_step", "umbral_lacerate", "shadow_execution"]
const SPINS := ["blade_flurry", "thousand_cuts", "oblivion_requiem", "abyss_vortex"]
const SMOKES := ["smoke_bomb", "shadow_veil", "veil_of_night", "midnight_execution"]
const POISON := ["venom_edge", "deadly_venom"]
const BLEEDS := ["crimson_cut", "throat_slit", "backstab", "eclipse_fang", "umbral_lacerate", "shadow_execution", "death_gods_eclipse"]
const ECLIPSES := ["eclipse_fang", "abyss_vortex", "midnight_execution", "oblivion_requiem", "shadow_sovereign", "night_lord", "eclipse_requiem", "death_gods_eclipse"]


static func palette(id: String) -> Array:
	if id in POISON:
		return VENOM
	if id in BLEEDS:
		return BLOOD
	return NIGHT


## Shadows gather: smoke curls up round the feet, a pool of dark spreads, and
## glints of the coming cut flicker at the hands.
static func anticipate(kit: SignatureKit, ctx: Dictionary) -> void:
	var id := String(ctx.id)
	var c := palette(id)
	var time := float(ctx.time)
	kit.sheet(K.DARK, SMOKE, Vector3(0, 0.04, 0), 0.0, time + 0.15, {"ground": true, "size": Vector2.ONE * 0.6, "grow": Vector2.ONE * 2.6, "level": K.CORE, "fade_in": 0.4, "decay": 0.8, "opacity": 0.55})
	kit.burst("smoke", SMOKE, Vector3(0, 0.2, 0), 0.0, {"amount": 7, "radius": 0.45, "speed": 0.4, "scale": 0.7, "stream": time * 0.7})
	kit.burst("gather", c, Vector3(0, 1.1, 0.4), 0.0, {"amount": 10, "radius": 1.0, "speed": 0.5 / maxf(time, 0.2)})
	for side in [-1.0, 1.0]:
		kit.sheet(K.TEAR, c, Vector3(side * 0.3, 1.1, 0.45), time * 0.5, time * 0.5 + 0.05, {"billboard": 1, "roll": side * 0.9, "size": Vector2.ONE * 0.3, "grow": Vector2.ONE * 0.8, "fade_in": 0.3, "decay": 0.8, "opacity": 0.75})
	if id in POISON:
		kit.burst("vapour", VENOM, Vector3(0.3, 1.0, 0.4), 0.0, {"amount": 6, "radius": 0.2, "speed": 0.4, "scale": 0.5})
	if id in ECLIPSES:
		kit.sheet(K.RING, ECLIPSE, Vector3(0, 0.06, 0), 0.0, time + 0.15, {"ground": true, "size": Vector2.ONE * 2.6, "grow": Vector2.ONE * 1.6, "level": K.MAIN, "fade_in": 0.4, "decay": 0.8, "opacity": 0.7})


static func play(kit: SignatureKit, ctx: Dictionary) -> void:
	var id := String(ctx.id)
	var c := palette(id)
	var radius := float(ctx.radius)
	var target := kit.to_local(Vector3(ctx.center.x, kit.global_position.y, ctx.center.z))
	var delay := float(ctx.delay)
	var parent := kit.get_parent() as Node3D
	if id in DASHES and String(ctx.shape) == "single":
		ClassSignature.afterimages(parent, ctx.origin, Vector3(ctx.center.x, ctx.origin.y, ctx.center.z), NIGHT, 3)
	if id in ECLIPSES:
		eclipse(kit, Vector3(target.x, 0.0, target.z) if String(ctx.shape) == "single" else Vector3.ZERO, radius if String(ctx.shape) != "single" else 3.2, delay, 1.6)
	if id in SMOKES:
		smoke(kit, Vector3.ZERO if String(ctx.shape) != "blast" else target, radius, delay)
	match String(ctx.shape):
		"single":
			if id in SLASHES or not bool((ctx.skill as Dictionary).get("projectile", false)):
				tear_cross(kit, c, target + Vector3(0, 1.0, 0), 2.4 if int(ctx.level) < 60 else 3.0, delay)
			if id in BLEEDS:
				kit.burst("blood", BLOOD, target + Vector3(0, 1.0, 0), delay + 0.05, {"amount": 12, "radius": 0.2, "spread": 70.0, "dir": Vector3(0, 0.6, 1)})
			if id in POISON:
				poison(kit, target, 1.2, delay)
		"burst":
			if id in SPINS:
				_spin(kit, c, radius, delay)
			elif not id in SMOKES:
				kit.sheet(K.RING, c, Vector3(0, 0.08, 0), delay, 0.45, {"ground": true, "size": Vector2.ONE * 0.6, "grow": Vector2.ONE * radius * 2.0, "level": K.CORE, "decay": 0.35})
		"blast":
			if id in POISON:
				poison(kit, target, radius, delay)
			if id == "death_mark":
				_death_mark(kit, target, radius, delay)
		"fan":
			for side in [-1.0, 1.0]:
				kit.sheet(K.TEAR, c, Vector3(side * 0.25, 1.15, 0.6), 0.0, 0.3, {"billboard": 1, "roll": side * 1.2, "size": Vector2.ONE * 0.7, "grow": Vector2.ONE * 1.5, "level": K.CORE, "decay": 0.3})
			kit.burst("smoke", SMOKE, Vector3(0, 1.0, 0.4), 0.0, {"amount": 5, "radius": 0.3, "speed": 0.6, "scale": 0.6})
		"chain":
			kit.burst("smoke", SMOKE, Vector3(0, 0.4, 0), 0.0, {"amount": 8, "radius": 0.4, "speed": 0.8, "scale": 0.8})
		"self":
			_buff(kit, id, c)


## Two crescents crossing: the cut opens hot, then tears and frays like cloth.
static func tear_cross(kit: SignatureKit, c: Array, at: Vector3, size: float, start := 0.0, life := 0.42) -> void:
	for side in [-1.0, 1.0]:
		kit.sheet(K.TEAR, c, at, start + (0.0 if side < 0.0 else 0.05), life, {"billboard": 1, "roll": side * 0.85 + randf_range(-0.15, 0.15), "roll_speed": -side * 0.6,
			"size": Vector2.ONE * size * 0.7, "grow": Vector2.ONE * size, "ease": K.OUT, "fade_in": 0.02, "decay": 0.3, "level": K.CORE, "opacity": 0.92})
	kit.sheet(K.SOFT, c, at, start, 0.18, {"billboard": 1, "size": Vector2.ONE * size * 0.6, "grow": Vector2.ONE * size * 0.3, "fade_in": 0.01, "decay": 0.2, "opacity": 0.5})


## Smoke bomb: a pop of light, a shock of dark and real smoke billowing out,
## rolling up, thinning and dissolving.
static func smoke(kit: SignatureKit, at: Vector3, radius: float, start := 0.0) -> void:
	kit.sheet(K.SOFT, NIGHT, at + Vector3(0, 0.6, 0), start, 0.18, {"billboard": 1, "size": Vector2.ONE * 1.2, "grow": Vector2.ONE * 2.6, "fade_in": 0.01, "decay": 0.2, "level": K.CORE, "opacity": 0.6})
	kit.sheet(K.DARK, SMOKE, at + Vector3(0, 0.05, 0), start, 1.6, {"ground": true, "size": Vector2.ONE * 1.0, "grow": Vector2.ONE * radius * 2.2, "ease": K.OUT, "level": K.CORE, "decay": 0.55, "opacity": 0.6})
	kit.sheet(K.RING, NIGHT, at + Vector3(0, 0.08, 0), start, 0.4, {"ground": true, "size": Vector2.ONE * 0.6, "grow": Vector2.ONE * radius * 2.4, "decay": 0.3, "opacity": 0.6})
	kit.burst("smoke", SMOKE, at + Vector3(0, 0.5, 0), start, {"amount": 28, "radius": maxf(0.6, radius * 0.35), "speed": 1.8 + radius * 0.25, "spread": 85.0, "scale": 1.5, "level": K.CORE})
	kit.burst("smoke", SMOKE, at + Vector3(0, 0.3, 0), start + 0.35, {"amount": 10, "radius": radius * 0.5, "speed": 0.6, "spread": 60.0, "scale": 1.8, "life": 1.2})


## Poison: a green-violet stain, vapour steaming off it and drops falling.
static func poison(kit: SignatureKit, at: Vector3, radius: float, start := 0.0) -> void:
	kit.sheet(K.DARK, VENOM, at + Vector3(0, 0.04, 0), start, 1.5, {"ground": true, "size": Vector2.ONE * radius * 0.6, "grow": Vector2.ONE * radius * 1.8, "level": K.CORE, "decay": 0.6, "opacity": 0.5})
	kit.sheet(K.RING, VENOM, at + Vector3(0, 0.07, 0), start, 0.5, {"ground": true, "size": Vector2.ONE * 0.5, "grow": Vector2.ONE * radius * 2.0, "level": K.MAIN, "decay": 0.35, "opacity": 0.7})
	kit.burst("vapour", VENOM, at + Vector3(0, 0.3, 0), start, {"amount": 24 if radius > 2.0 else 10, "radius": radius * 0.55, "speed": 0.5, "spread": 30.0, "scale": 1.2})
	kit.burst("drips", VENOM, at + Vector3(0, 1.4, 0), start + 0.05, {"amount": 10, "radius": radius * 0.4, "speed": 0.5, "spread": 40.0})


## Eclipse: the ground darkens round the strike under a rim of red light, a
## black sun swells and fades.
static func eclipse(kit: SignatureKit, at: Vector3, radius: float, start := 0.0, seconds := 1.4) -> void:
	kit.sheet(K.DARK, ECLIPSE, at + Vector3(0, 0.03, 0), start, seconds, {"ground": true, "size": Vector2.ONE * radius * 1.2, "grow": Vector2.ONE * radius * 2.4, "ease": K.OUT, "level": K.CORE, "fade_in": 0.15, "decay": 0.6, "opacity": 0.6})
	kit.sheet(K.RING, ECLIPSE, at + Vector3(0, 0.06, 0), start, seconds, {"ground": true, "size": Vector2.ONE * radius * 1.4, "grow": Vector2.ONE * radius * 2.3, "ease": K.OUT, "level": K.CORE, "fade_in": 0.15, "decay": 0.6, "opacity": 0.85})
	kit.sheet(K.SOFT, ECLIPSE, at + Vector3(0, 2.6, 0), start, seconds * 0.8, {"billboard": 1, "size": Vector2.ONE * 1.0, "grow": Vector2.ONE * 2.4, "level": K.MAIN, "fade_in": 0.2, "decay": 0.6, "opacity": 0.5})
	kit.sheet(K.DARK, ECLIPSE, at + Vector3(0, 2.6, 0.05), start, seconds * 0.8, {"billboard": 1, "size": Vector2.ONE * 0.7, "grow": Vector2.ONE * 1.7, "level": K.MAIN, "fade_in": 0.2, "decay": 0.6, "opacity": 0.95})
	kit.burst("smoke", SMOKE, at + Vector3(0, 0.2, 0), start, {"amount": 10, "radius": radius * 0.7, "speed": 0.4, "spread": 30.0, "scale": 1.2})
	kit.lamp(ECLIPSE[0], at + Vector3(0, 1.2, 0), 1.4, radius * 2.2)


## Spinning skills: crescents tear round the assassin in a turning ring.
static func _spin(kit: SignatureKit, c: Array, radius: float, start: float) -> void:
	var n: int = [2, 4, 6][K.detail()]
	for i in n:
		var a := TAU * float(i) / float(n)
		var at := Vector3(sin(a), 0, cos(a)) * radius * 0.45 + Vector3(0, 0.9 + 0.25 * float(i % 2), 0)
		kit.sheet(K.TEAR, c, at, start + i * 0.04, 0.4, {"basis": Basis(Vector3.UP, a) * Basis(Vector3.BACK, 0.4 * (1.0 if i % 2 == 0 else -1.0)), "size": Vector2.ONE * radius * 0.5, "grow": Vector2.ONE * radius * 0.75, "level": K.CORE if i < 2 else K.MAIN, "decay": 0.3, "opacity": 0.9})
	kit.sheet(K.RING, c, Vector3(0, 0.08, 0), start, 0.45, {"ground": true, "size": Vector2.ONE * 0.8, "grow": Vector2.ONE * radius * 2.0, "spin": -6.0, "level": K.MAIN, "decay": 0.35})
	kit.burst("smoke", SMOKE, Vector3(0, 0.3, 0), start, {"amount": 10, "radius": radius * 0.4, "speed": 1.4, "swirl": 6.0, "spread": 85.0})
	kit.burst("blood", BLOOD, Vector3(0, 1.0, 0), start + 0.1, {"amount": 10, "radius": radius * 0.4, "spread": 90.0})


## Death Mark: a red rune circle stamped into the ground with a great X.
static func _death_mark(kit: SignatureKit, at: Vector3, radius: float, start: float) -> void:
	kit.sheet(K.RUNES, CRIT, at + Vector3(0, 0.06, 0), start, 1.4, {"ground": true, "size": Vector2.ONE * radius * 2.6, "grow": Vector2.ONE * radius * 2.0, "ease": K.BACK, "spin": 0.5, "count": 18.0, "level": K.CORE, "decay": 0.7, "opacity": 0.8})
	kit.sheet(K.CROSS, CRIT, at + Vector3(0, 0.07, 0), start + 0.08, 1.2, {"ground": true, "size": Vector2.ONE * radius * 2.4, "grow": Vector2.ONE * radius * 1.6, "ease": K.BACK, "level": K.CORE, "decay": 0.65, "opacity": 0.75})
	kit.sheet(K.DARK, ECLIPSE, at + Vector3(0, 0.03, 0), start, 1.4, {"ground": true, "size": Vector2.ONE * radius * 2.2, "level": K.MAIN, "decay": 0.6, "opacity": 0.45})


## Buffs: Shadow Clone casts clones round the assassin; the others wrap the
## body in smoke with a red or violet rim (Night Lord and Shadow Sovereign
## bring their eclipse).
static func _buff(kit: SignatureKit, id: String, c: Array) -> void:
	var parent := kit.get_parent() as Node3D
	if id == "shadow_clone":
		for i in 3:
			var a := TAU * float(i) / 3.0 + 0.5
			var spot := kit.global_position + Vector3(sin(a), 0, cos(a)) * 1.3
			ClassSignature.afterimages(parent, kit.global_position, spot, NIGHT, 1, float(i) * 0.08, 0.9)
	kit.sheet(K.RING, CRIT if id in ["killing_focus", "night_lord", "shadow_sovereign"] else c, Vector3(0, 0.06, 0), 0.0, 0.8, {"ground": true, "size": Vector2.ONE * 2.6, "grow": Vector2.ONE * 1.2, "level": K.CORE, "decay": 0.5})
	kit.burst("smoke", SMOKE, Vector3(0, 0.3, 0), 0.0, {"amount": 12, "radius": 0.6, "speed": 0.8, "swirl": 5.0, "spread": 40.0})
	kit.burst("motes", c, Vector3(0, 1.0, 0), 0.05, {"amount": 12, "radius": 0.6, "speed": 0.8, "swirl": 6.0})
	if id == "killing_focus":
		for side in [-1.0, 1.0]:
			kit.sheet(K.SOFT, CRIT, Vector3(side * 0.08, 1.62, 0.22), 0.1, 0.6, {"billboard": 1, "size": Vector2.ONE * 0.18, "grow": Vector2.ONE * 0.36, "level": K.MAIN, "decay": 0.5, "opacity": 0.95})


## Thrown knives: a thin violet streak and shadow shed behind each blade.
static func flight(kit: SignatureKit, ctx: Dictionary) -> void:
	var c := palette(String(ctx.id))
	var seconds := float(ctx.seconds)
	var trail := clampf(float(ctx.length) * 0.35, 1.0, 2.6)
	kit.sheet(K.STREAK, c, Vector3(0, 0, -trail * 0.5), 0.0, seconds + 0.08, {"billboard": 2, "basis": ClassSignature.along(Vector3.BACK), "size": Vector2(0.22, trail), "level": K.CORE, "decay": 0.85, "opacity": 0.85})
	kit.burst("smoke", SMOKE, Vector3(0, 0, -0.3), 0.0, {"amount": 6, "stream": seconds, "radius": 0.05, "speed": 0.2, "scale": 0.35, "life": 0.5})


## Every hit: the critical's red X; bleeding and poisoned hits spill; chain
## dashes leave an afterimage by their victim.
static func contact(kit: SignatureKit, ctx: Dictionary) -> void:
	var id := String(ctx.id)
	var c := palette(id)
	if bool(ctx.crit):
		crit_x(kit, Vector3.ZERO)
	if id in BLEEDS or bool(ctx.crit):
		kit.burst("blood", BLOOD, Vector3.ZERO, 0.0, {"amount": 8, "radius": 0.15, "spread": 80.0})
	if id in POISON:
		kit.burst("vapour", VENOM, Vector3(0, -0.3, 0), 0.0, {"amount": 4, "radius": 0.2, "speed": 0.4, "scale": 0.5})
		kit.burst("drips", VENOM, Vector3(0, 0.2, 0), 0.0, {"amount": 5, "radius": 0.2})
	if String(ctx.shape) == "chain" and ctx.previous != null:
		var parent := kit.get_parent() as Node3D
		var prev: Vector3 = ctx.previous
		var here := kit.global_position
		ClassSignature.afterimages(parent, Vector3(prev.x, here.y - 0.9, prev.z), Vector3(here.x, here.y - 0.9, here.z), NIGHT, 2, 0.0, 0.4)
		tear_cross(kit, c, Vector3.ZERO, 1.6)
	elif not bool(ctx.crit):
		kit.sheet(K.TEAR, c, Vector3.ZERO, 0.0, 0.3, {"billboard": 1, "roll": randf_range(-1.2, 1.2), "size": Vector2.ONE * 0.8, "grow": Vector2.ONE * 1.4, "level": K.MAIN, "decay": 0.3})


## The red X of a critical hit: it snaps open with an overshoot, flares and frays.
static func crit_x(kit: SignatureKit, at: Vector3, size := 1.0) -> void:
	kit.sheet(K.CROSS, CRIT, at, 0.0, 0.42, {"billboard": 1, "size": Vector2.ONE * 0.5 * size, "grow": Vector2.ONE * 1.9 * size, "ease": K.BACK, "fade_in": 0.02, "decay": 0.45, "level": K.CORE, "opacity": 0.95})
	kit.sheet(K.SOFT, CRIT, at, 0.0, 0.2, {"billboard": 1, "size": Vector2.ONE * 1.5 * size, "grow": Vector2.ONE * 0.8 * size, "fade_in": 0.01, "decay": 0.2, "level": K.MAIN, "opacity": 0.55})


## Star beats: Umbral Lacerate's crossed tears, Shadow Execution's dash and
## mark, Veil of Night's smoke, the eclipses of Eclipse Requiem and of the
## Death God's Eclipse.
static func star_beat(kit: SignatureKit, ctx: Dictionary) -> void:
	var id := String(ctx.id)
	var c := palette(id)
	var index := int(ctx.index)
	var radius := float(ctx.radius)
	var high := Vector3(0, 1.0, 0)
	match id:
		"umbral_lacerate":
			_spin(kit, NIGHT if index == 0 else BLOOD, radius * 0.8, 0.0)
		"shadow_execution":
			if index == 0:
				ClassSignature.afterimages(kit.get_parent() as Node3D, ctx.origin, kit.global_position, NIGHT, 4)
			tear_cross(kit, BLOOD, high, 3.2)
			crit_x(kit, high, 1.4)
			kit.burst("blood", BLOOD, high, 0.03, {"amount": 14, "radius": 0.2, "spread": 80.0})
		"veil_of_night":
			if index == 0:
				smoke(kit, Vector3.ZERO, radius * 0.7)
		"eclipse_requiem", "death_gods_eclipse":
			if index == 0:
				eclipse(kit, Vector3.ZERO, radius, 0.0, 2.4 if id == "death_gods_eclipse" else 1.8)
			else:
				tear_cross(kit, BLOOD if index % 2 == 0 else NIGHT, high + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), 2.8)
			if index >= 3 or (id == "eclipse_requiem" and index == 2):
				crit_x(kit, high, 1.6)
				kit.burst("blood", BLOOD, high, 0.0, {"amount": 14, "radius": radius * 0.3, "spread": 90.0})
		_:
			tear_cross(kit, c, high, 2.6)
