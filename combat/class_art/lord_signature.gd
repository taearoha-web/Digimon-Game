class_name LordSignature
extends RefCounted
## The Dark Lord's signature (ClassSignature): royal dark power. A sigil of
## runes turns at the scepter, purple-black flame licks up with gold edges,
## lightning forks down jagged and flickering and leaves an afterglow, raven
## feathers swirl, commands raise a crown of light over every ally, and Summon
## opens a dark portal ringed with gold runes.

const K = preload("res://combat/class_art/signature_kit.gd")
const ROYAL := [Color("ffcf5a"), Color("fff3d0"), Color("3a2008")]
## Purple-black flame with gold edges (signature_ink FLAME: body shade->primary, rim accent).
const DARKFIRE := [Color("5a1a9a"), Color("ffc24a"), Color("12061e")]
const FORCE := [Color("8a4dff"), Color("f0e2ff"), Color("140828")]
const STORM := [Color("7ab8ff"), Color("f4fbff"), Color("101a48")]
const RAVEN := [Color("6a3aa0"), Color("d8c4ff"), Color("0b0614")]
const PORTAL := [Color("3a1260"), Color("b08aff"), Color("06020c")]
const DUST := [Color("8a7a6a"), Color("c8b8a0"), Color("2a221a")]
const FIRE_SKILLS := ["fire_burst", "fire_scream", "fire_blast", "infernal_scream", "chaos_inferno", "dark_comet", "imperial_judgment", "abyssal_throne"]
const STORM_SKILLS := ["electric_spike", "thunder_lord", "plasma_storm", "imperial_cataclysm", "imperial_judgment", "abyssal_throne"]
const RAVEN_SKILLS := ["birds", "raven_storm", "raven_sovereign"]
const COMMANDS := ["critical_damage", "iron_defense", "commanders_aura", "lord_of_command", "emperors_command", "lords_dominion"]
const QUAKES := ["earthshake", "earth_dominion", "royal_crush", "imperial_judgment"]


static func palette(id: String) -> Array:
	if id in COMMANDS or id == "summon":
		return ROYAL
	if id in STORM_SKILLS and not id in FIRE_SKILLS:
		return STORM
	if id in RAVEN_SKILLS:
		return RAVEN
	if id in FIRE_SKILLS:
		return DARKFIRE
	return FORCE


## The scepter raised: a sigil of gold runes turns at its head and a wider one
## under the Lord's feet; fire skills lick dark flame round him, storm skills
## crackle at the scepter.
static func anticipate(kit: SignatureKit, ctx: Dictionary) -> void:
	var id := String(ctx.id)
	var time := float(ctx.time)
	var tip := Vector3(0.3, 1.75, 0.45)
	kit.sheet(K.RUNES, ROYAL, tip, 0.0, time + 0.08, {"billboard": 1, "size": Vector2.ONE * 0.25, "grow": Vector2.ONE * 1.0, "ease": K.BACK, "roll_speed": 2.5, "count": 8.0, "level": K.CORE, "fade_in": 0.25, "decay": 0.88, "opacity": 0.8})
	kit.sheet(K.SOFT, FORCE, tip, 0.0, time + 0.08, {"billboard": 1, "size": Vector2.ONE * 0.2, "grow": Vector2.ONE * 0.8, "ease": K.IN, "fade_in": 0.3, "decay": 0.9, "opacity": 0.6})
	kit.sheet(K.RUNES, ROYAL, Vector3(0, 0.05, 0), 0.0, time + 0.12, {"ground": true, "size": Vector2.ONE * 1.2, "grow": Vector2.ONE * 2.6, "spin": -1.0, "count": 16.0, "fade_in": 0.3, "decay": 0.85, "opacity": 0.7})
	if id == "summon":
		# The portal opens under the Lord as he raises the scepter, before the light of the warp.
		portal(kit, Vector3.ZERO, 2.0, 0.0, true)
		for spot in ClassSignature.allies(kit.get_parent() as Node3D, kit.global_position, 60.0, 4):
			if (spot as Vector3).distance_to(kit.global_position) > 1.5:
				portal(kit, kit.to_local(spot), 0.9, 0.0, false)
	if id in FIRE_SKILLS:
		_flame_ring(kit, 0.9, 5, 0.0, time + 0.1, 0.7, K.MAIN)
	if id in STORM_SKILLS:
		for i in 2:
			kit.bolt(STORM, tip, tip + Vector3(randf_range(-0.9, 0.9), randf_range(0.5, 1.2), randf_range(-0.5, 0.5)), time * (0.3 + 0.35 * i), 0.2, 0.6, K.MAIN)
	if id in RAVEN_SKILLS:
		kit.burst("feathers", RAVEN, Vector3(0, 1.8, 0), 0.0, {"amount": 8, "radius": 0.8, "speed": 0.6, "swirl": 6.0, "spread": 60.0})
	kit.burst("gather", FORCE if not id in COMMANDS else ROYAL, tip, 0.0, {"amount": 10, "radius": 1.0, "speed": 0.5 / maxf(time, 0.2)})


static func play(kit: SignatureKit, ctx: Dictionary) -> void:
	var id := String(ctx.id)
	var c := palette(id)
	var radius := float(ctx.radius)
	var delay := float(ctx.delay)
	var target := kit.to_local(Vector3(ctx.center.x, kit.global_position.y, ctx.center.z))
	var shape := String(ctx.shape)
	if id == "summon":
		# The release: a gold shock off the portal's rim and a wide ring of violet runes.
		kit.sheet(K.RING, ROYAL, Vector3(0, 0.1, 0), 0.0, 0.6, {"ground": true, "size": Vector2.ONE * 2.0, "grow": Vector2.ONE * 9.0, "level": K.CORE, "decay": 0.3, "opacity": 0.75})
		kit.sheet(K.RUNES, PORTAL, Vector3(0, 0.05, 0), 0.0, 2.0, {"ground": true, "size": Vector2.ONE * 5.0, "grow": Vector2.ONE * 5.6, "spin": -0.8, "count": 22.0, "level": K.CORE, "decay": 0.6, "opacity": 0.85})
		kit.burst("motes", [Color("9a6aff"), Color("ffe6a8"), Color("1a0a30")], Vector3(0, 0.2, 0), 0.0, {"amount": 20, "radius": 2.0, "speed": 1.4, "dir": Vector3.UP, "spread": 20.0, "swirl": 4.0})
		return
	if id in COMMANDS:
		command(kit, id)
		return
	var at := target if shape in ["blast", "single"] else Vector3.ZERO
	if shape == "single" and not bool((ctx.skill as Dictionary).get("projectile", false)):
		_force_hit(kit, c, at + Vector3(0, 1.0, 0), delay, id in FIRE_SKILLS)
	if id in FIRE_SKILLS and shape in ["blast", "burst"]:
		_flame_ring(kit, radius * 0.85, [3, 7, 11][K.detail()], delay + 0.08, 1.7, 2.3, K.CORE, at)
		_flame_ring(kit, radius * 0.4, [0, 2, 4][K.detail()], delay + 0.2, 1.4, 1.6, K.MAIN, at)
		kit.burst("embers", DARKFIRE, at + Vector3(0, 0.4, 0), delay, {"amount": 22, "radius": radius * 0.6, "speed": 1.4, "swirl": 3.0, "spread": 45.0})
		kit.sheet(K.RING, ROYAL, at + Vector3(0, 0.08, 0), delay, 0.5, {"ground": true, "size": Vector2.ONE * 0.6, "grow": Vector2.ONE * radius * 2.1, "level": K.CORE, "decay": 0.35, "opacity": 0.8})
		kit.lamp(Color("9a5aff"), at + Vector3(0, 1.0, 0), 1.6, radius * 1.8)
	if id in STORM_SKILLS and shape in ["blast", "burst"]:
		storm(kit, at, radius, delay, [2, 4, 7][K.detail()])
	if id in QUAKES:
		_quake(kit, at if shape == "single" else Vector3.ZERO, radius if shape != "single" else 2.0, delay)
	if id in RAVEN_SKILLS:
		kit.burst("feathers", RAVEN, Vector3(0, 1.6, 0.4), 0.0, {"amount": 16, "radius": 0.5, "speed": 1.8, "dir": Vector3(0, 0.3, 1), "spread": 70.0, "swirl": 4.0})
	if id == "force_wave" or id == "chaotic_diseier":
		kit.sheet(K.RING, FORCE, Vector3(0, 1.3, 0.8), 0.0, 0.35, {"size": Vector2.ONE * 0.4, "grow": Vector2.ONE * 2.6, "level": K.CORE, "decay": 0.3})


## Dark flame tongues, purple-black bodies with gold edges, in a ring.
static func _flame_ring(kit: SignatureKit, radius: float, count: int, start: float, seconds: float, height: float, level: int, at := Vector3.ZERO) -> void:
	for i in count:
		var a := TAU * float(i) / float(count) + randf_range(-0.2, 0.2)
		var spot := at + Vector3(sin(a), 0, cos(a)) * radius * randf_range(0.75, 1.05)
		var tall := height * randf_range(0.8, 1.25)
		kit.sheet(K.FLAME, DARKFIRE, spot + Vector3(0, tall * 0.5, 0), start + randf_range(0.0, 0.12), seconds * randf_range(0.8, 1.1),
			{"billboard": 2, "basis": ClassSignature.along(Vector3.UP), "size": Vector2(tall * 0.55, tall * 0.5), "grow": Vector2(tall * 0.6, tall), "ease": K.BACK,
			"glow": false, "fade_in": 0.12, "decay": 0.6, "level": level if i < 3 else maxi(level, K.MAIN), "opacity": 1.0})


## A force strike: dark flame bursting off the blow, a gold ring and runes.
static func _force_hit(kit: SignatureKit, c: Array, at: Vector3, start: float, fire: bool) -> void:
	kit.sheet(K.RUNES, ROYAL, at, start, 0.5, {"billboard": 1, "size": Vector2.ONE * 2.0, "grow": Vector2.ONE * 1.1, "roll_speed": -3.0, "count": 8.0, "level": K.MAIN, "decay": 0.45, "opacity": 0.75})
	kit.sheet(K.RING, ROYAL, at, start, 0.32, {"billboard": 1, "size": Vector2.ONE * 0.4, "grow": Vector2.ONE * 2.4, "level": K.CORE, "decay": 0.3})
	_flame_ring(kit, 0.5, 3, start, 0.6, 1.2, K.CORE, at - Vector3(0, 1.0, 0))
	kit.burst("embers", DARKFIRE if fire else FORCE, at, start, {"amount": 10, "radius": 0.3, "speed": 1.4, "swirl": 2.0, "spread": 70.0})


## Lightning: bolts fork down from the sky, flicker and leave an afterglow
## and a scorch ring where they strike.
static func storm(kit: SignatureKit, at: Vector3, radius: float, start: float, count: int) -> void:
	for i in count:
		var a := randf() * TAU
		var spot := at + Vector3(cos(a), 0, sin(a)) * sqrt(randf()) * radius * 0.8
		var t := start + float(i) * 0.09 + randf_range(0.0, 0.05)
		strike(kit, spot, t, K.CORE if i < 2 else K.MAIN)


static func strike(kit: SignatureKit, spot: Vector3, t: float, level := K.CORE) -> void:
	kit.bolt(STORM, spot + Vector3(randf_range(-1.2, 1.2), 8.0, randf_range(-1.2, 1.2)), spot, t, 0.34, 1.0, level)
	kit.sheet(K.SOFT, STORM, spot + Vector3(0, 0.3, 0), t, 0.4, {"billboard": 1, "size": Vector2.ONE * 1.8, "grow": Vector2.ONE * 1.2, "fade_in": 0.01, "decay": 0.25, "level": level, "opacity": 0.55})
	kit.sheet(K.RING, STORM, spot + Vector3(0, 0.06, 0), t, 0.4, {"ground": true, "size": Vector2.ONE * 0.3, "grow": Vector2.ONE * 1.8, "level": K.MAIN, "decay": 0.3})
	kit.burst("sparks", STORM, spot + Vector3(0, 0.2, 0), t, {"amount": 8, "radius": 0.15, "spread": 70.0})


## The earth answers: a shock ring of gold, dust thrown out and stones falling.
static func _quake(kit: SignatureKit, at: Vector3, radius: float, start: float) -> void:
	kit.sheet(K.RING, ROYAL, at + Vector3(0, 0.08, 0), start, 0.5, {"ground": true, "size": Vector2.ONE * 0.6, "grow": Vector2.ONE * radius * 2.2, "level": K.CORE, "decay": 0.3})
	kit.sheet(K.RUNES, ROYAL, at + Vector3(0, 0.05, 0), start, 0.9, {"ground": true, "size": Vector2.ONE * radius * 1.8, "grow": Vector2.ONE * radius * 1.4, "spin": 0.6, "count": 18.0, "level": K.MAIN, "decay": 0.6, "opacity": 0.6})
	kit.burst("dust", DUST, at + Vector3(0, 0.05, 0), start, {"amount": 18, "radius": radius * 0.5, "speed": 2.0, "scale": 1.2})
	kit.burst("sparks", DUST, at + Vector3(0, 0.3, 0), start, {"amount": 12, "radius": radius * 0.4, "spread": 40.0, "speed": 0.8, "scale": 1.6})


## Commands: a crown of light over the Lord and every ally in reach, gold
## motes rising off them, and a pillar banner of light behind the Lord.
static func command(kit: SignatureKit, id: String) -> void:
	var grand := id in ["lord_of_command", "emperors_command", "lords_dominion"]
	var parent := kit.get_parent() as Node3D
	var spots := ClassSignature.allies(parent, kit.global_position, 14.0, 4 if K.detail() == 2 else 2)
	if spots.is_empty():
		spots.append(kit.global_position)
	var first := true
	for spot in spots:
		crown(kit, kit.to_local(spot) + Vector3(0, 2.35, 0), 1.0 if first else 0.75, 0.0 if first else 0.12)
		first = false
	kit.sheet(K.STREAK, ROYAL, Vector3(0, 2.2, -0.5), 0.0, 1.2, {"billboard": 2, "basis": ClassSignature.along(Vector3.UP), "size": Vector2(0.7, 2.0), "grow": Vector2(1.2 if grand else 0.9, 5.0), "level": K.MAIN, "decay": 0.6, "opacity": 0.55})
	kit.sheet(K.RUNES, ROYAL, Vector3(0, 0.05, 0), 0.0, 1.2, {"ground": true, "size": Vector2.ONE * 1.0, "grow": Vector2.ONE * (4.2 if grand else 3.0), "ease": K.BACK, "spin": 0.8, "count": 20.0, "level": K.CORE, "decay": 0.6, "opacity": 0.75})


## A crown of light: a ring of runes with five points of light rising from it.
static func crown(kit: SignatureKit, at: Vector3, size: float, start: float) -> void:
	kit.sheet(K.RUNES, ROYAL, at, start, 1.3, {"ground": true, "size": Vector2.ONE * 0.3 * size, "grow": Vector2.ONE * 1.0 * size, "ease": K.BACK, "spin": 1.2, "count": 10.0, "level": K.CORE, "decay": 0.7, "opacity": 0.9})
	kit.sheet(K.SOFT, ROYAL, at + Vector3(0, 0.15, 0), start, 1.3, {"billboard": 1, "size": Vector2.ONE * 0.6 * size, "grow": Vector2.ONE * 1.1 * size, "level": K.MAIN, "decay": 0.6, "opacity": 0.45})
	for i in 5:
		var a := TAU * float(i) / 5.0
		kit.sheet(K.STREAK, ROYAL, at + Vector3(sin(a), 0, cos(a)) * 0.42 * size + Vector3(0, 0.2 * size, 0), start + 0.05 + i * 0.03, 1.2,
			{"billboard": 2, "basis": ClassSignature.along(Vector3.UP), "size": Vector2(0.14, 0.1) * size, "grow": Vector2(0.18, 0.5) * size, "ease": K.BACK, "level": K.DEBRIS, "decay": 0.65})
	kit.burst("motes", ROYAL, at - Vector3(0, 0.8, 0), start, {"amount": 10, "radius": 0.4 * size, "speed": 0.6, "dir": Vector3.UP, "spread": 25.0, "swirl": 2.0})


## Summon: a dark portal opens, ringed with gold runes, with a violet column
## and motes rising; the allies' own small portals open where they stood.
static func portal(kit: SignatureKit, at: Vector3, size: float, start: float, main: bool) -> void:
	kit.sheet(K.DARK, PORTAL, at + Vector3(0, 0.03, 0), start, 2.4, {"ground": true, "size": Vector2.ONE * 0.4 * size, "grow": Vector2.ONE * 2.4 * size, "ease": K.BACK, "level": K.CORE if main else K.MAIN, "decay": 0.7, "opacity": 0.95})
	kit.sheet(K.RUNES, ROYAL, at + Vector3(0, 0.06, 0), start, 2.4, {"ground": true, "size": Vector2.ONE * 0.6 * size, "grow": Vector2.ONE * 2.6 * size, "ease": K.BACK, "spin": 1.1, "count": 16.0, "level": K.CORE if main else K.MAIN, "decay": 0.7, "opacity": 0.9})
	kit.sheet(K.RUNES, PORTAL, at + Vector3(0, 0.07, 0), start + 0.1, 2.2, {"ground": true, "size": Vector2.ONE * 0.4 * size, "grow": Vector2.ONE * 1.6 * size, "ease": K.OUT, "spin": -2.2, "count": 10.0, "level": K.MAIN, "decay": 0.6, "opacity": 0.8})
	if main:
		kit.sheet(K.RING, ROYAL, at + Vector3(0, 0.1, 0), start + 0.05, 0.6, {"ground": true, "size": Vector2.ONE * 1.0, "grow": Vector2.ONE * 4.4 * size, "level": K.MAIN, "decay": 0.3, "opacity": 0.45})
		kit.sheet(K.STREAK, PORTAL, at + Vector3(0, 1.8, 0), start, 1.1, {"billboard": 2, "basis": ClassSignature.along(Vector3.UP), "size": Vector2(1.4, 2.0), "grow": Vector2(0.8 * size * 1.4, 4.0), "level": K.MAIN, "decay": 0.5, "opacity": 0.6})
		kit.lamp(Color("8a4dff"), at + Vector3(0, 1.2, 0), 1.5, 5.0)
	kit.burst("motes", [Color("9a6aff"), Color("ffe6a8"), Color("1a0a30")], at + Vector3(0, 0.2, 0), start + 0.05, {"amount": 18 if main else 8, "radius": 0.9 * size, "speed": 1.0, "dir": Vector3.UP, "spread": 20.0, "swirl": 4.0})


## Force and fire projectiles: a dark flame trail with gold edges, embers and,
## for the ravens, feathers shed in flight.
static func flight(kit: SignatureKit, ctx: Dictionary) -> void:
	var id := String(ctx.id)
	var seconds := float(ctx.seconds)
	var trail := clampf(float(ctx.length) * 0.35, 1.0, 2.6)
	var back := ClassSignature.along(Vector3.BACK)
	if id in RAVEN_SKILLS:
		kit.sheet(K.STREAK, FORCE, Vector3(0, 0, -trail * 0.5), 0.0, seconds + 0.08, {"billboard": 2, "basis": back, "size": Vector2(0.4, trail), "level": K.CORE, "decay": 0.8, "opacity": 0.6})
		kit.burst("feathers", RAVEN, Vector3(0, 0, -0.3), 0.0, {"amount": 6, "stream": seconds, "radius": 0.15, "speed": 0.4, "spread": 180.0, "scale": 0.6})
		return
	kit.sheet(K.FLAME, DARKFIRE, Vector3(0, 0, -trail * 0.45), 0.0, seconds + 0.1, {"billboard": 2, "basis": back, "size": Vector2(0.8, trail), "glow": false, "level": K.CORE, "decay": 0.8, "opacity": 0.9})
	kit.sheet(K.SOFT, FORCE if not id in FIRE_SKILLS else DARKFIRE, Vector3.ZERO, 0.0, seconds + 0.06, {"billboard": 1, "size": Vector2.ONE * 0.9, "level": K.MAIN, "decay": 0.8, "opacity": 0.55})
	kit.burst("embers", DARKFIRE, Vector3(0, 0, -0.3), 0.0, {"amount": 10, "stream": seconds, "radius": 0.12, "speed": 0.5, "spread": 180.0})


## Every hit: storm hits fork down from the sky and arc from the last victim;
## force and fire hits burst in dark flame with a ring of gold.
static func contact(kit: SignatureKit, ctx: Dictionary) -> void:
	var id := String(ctx.id)
	if id in STORM_SKILLS and not id in FIRE_SKILLS:
		kit.bolt(STORM, Vector3(randf_range(-1, 1), 7.5, randf_range(-1, 1)), Vector3.ZERO, 0.0, 0.32, 0.9, K.CORE)
		if ctx.previous != null:
			kit.bolt(STORM, kit.to_local(ctx.previous), Vector3.ZERO, 0.0, 0.3, 0.6, K.CORE)
		kit.sheet(K.SOFT, STORM, Vector3.ZERO, 0.0, 0.3, {"billboard": 1, "size": Vector2.ONE * 1.6, "grow": Vector2.ONE * 1.0, "level": K.MAIN, "fade_in": 0.01, "decay": 0.25, "opacity": 0.55})
		kit.burst("sparks", STORM, Vector3.ZERO, 0.0, {"amount": 8, "radius": 0.1, "spread": 90.0})
		return
	if id in RAVEN_SKILLS:
		kit.burst("feathers", RAVEN, Vector3.ZERO, 0.0, {"amount": 7, "radius": 0.2, "speed": 1.2, "swirl": 4.0, "spread": 100.0})
	kit.sheet(K.RING, ROYAL, Vector3.ZERO, 0.0, 0.3, {"billboard": 1, "size": Vector2.ONE * 0.3, "grow": Vector2.ONE * (2.0 if bool(ctx.crit) else 1.4), "level": K.CORE, "decay": 0.3, "opacity": 0.75})
	_flame_ring(kit, 0.35, 2, 0.0, 0.45, 0.9, K.MAIN, Vector3(0, -0.8, 0))
	kit.burst("embers", DARKFIRE, Vector3.ZERO, 0.0, {"amount": 6, "radius": 0.2, "speed": 1.0, "swirl": 2.0})


## Star beats: Chaos Inferno's ring of dark fire, Raven Sovereign's storm of
## feathers, Lord's Dominion's crowns, Imperial Cataclysm's lightning and the
## Abyssal Throne's portal, fire and storm.
static func star_beat(kit: SignatureKit, ctx: Dictionary) -> void:
	var id := String(ctx.id)
	var index := int(ctx.index)
	var radius := float(ctx.radius)
	match id:
		"chaos_inferno":
			_flame_ring(kit, radius * (0.55 + 0.25 * index), [3, 6, 10][K.detail()], 0.0, 1.0, 1.5, K.CORE)
			kit.burst("embers", DARKFIRE, Vector3(0, 0.4, 0), 0.0, {"amount": 22, "radius": radius * 0.6, "speed": 1.5, "swirl": 4.0, "spread": 45.0})
			kit.sheet(K.RING, ROYAL, Vector3(0, 0.08, 0), 0.0, 0.5, {"ground": true, "size": Vector2.ONE, "grow": Vector2.ONE * radius * 2.0, "level": K.CORE, "decay": 0.35})
		"raven_sovereign":
			kit.burst("feathers", RAVEN, Vector3(0, 1.2, 0), 0.0, {"amount": 18, "radius": radius * 0.4, "speed": 1.6, "swirl": 7.0, "spread": 90.0})
			kit.sheet(K.RING, FORCE, Vector3(0, 0.08, 0), 0.0, 0.45, {"ground": true, "size": Vector2.ONE, "grow": Vector2.ONE * radius * 1.8, "level": K.CORE, "decay": 0.35})
		"lords_dominion":
			if index == 0:
				var back := kit.to_local(ctx.origin)
				command_at(kit, back)
		"imperial_cataclysm":
			storm(kit, Vector3.ZERO, radius, 0.0, [2, 4, 6][K.detail()])
			if index == 0:
				crown(kit, Vector3(0, 7.0, 0), 3.0, 0.0)
		"abyssal_throne":
			if index == 0:
				portal(kit, Vector3.ZERO, radius * 0.6, 0.0, true)
			else:
				_flame_ring(kit, radius * 0.7, [3, 5, 8][K.detail()], 0.0, 0.9, 1.4, K.CORE)
				storm(kit, Vector3.ZERO, radius, 0.05, [1, 2, 4][K.detail()])
		_:
			kit.sheet(K.RING, ROYAL, Vector3(0, 0.08, 0), 0.0, 0.45, {"ground": true, "size": Vector2.ONE, "grow": Vector2.ONE * radius * 1.6, "level": K.CORE, "decay": 0.35})


## Lord's Dominion: the command crowns raised round the Lord (local [param at]).
static func command_at(kit: SignatureKit, at: Vector3) -> void:
	var parent := kit.get_parent() as Node3D
	var world := kit.to_global(at)
	var spots := ClassSignature.allies(parent, world, 14.0, 4 if K.detail() == 2 else 2)
	if spots.is_empty():
		spots.append(world)
	for spot in spots:
		crown(kit, kit.to_local(spot) + Vector3(0, 2.35, 0), 1.0, 0.0)
	kit.sheet(K.RUNES, ROYAL, at + Vector3(0, 0.05, 0), 0.0, 1.3, {"ground": true, "size": Vector2.ONE, "grow": Vector2.ONE * 4.4, "ease": K.BACK, "spin": 0.8, "count": 20.0, "level": K.CORE, "decay": 0.6})
