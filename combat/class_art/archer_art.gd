class_name ArcherArt
extends RefCounted
## The Archer's signature (ClassSignature): the bow drawn to a glow with light
## gathering at the hand, a shock ring and a gust at the release, arrows with
## luminous fletching trails and wind wakes, rain of arrows falling in long
## perspective streaks and kicking up dust where they land, phoenix shots as
## flaming birds shedding feather embers, spirit glow for the hawk, wolf and
## nature summons, and every shot tinted by its element (wind, fire, thunder,
## nature, gold, moon).

const K = preload("res://combat/class_art/signature_kit.gd")
## [core-side primary, white-hot accent, dark rim]
const WIND := [Color("5fe6b0"), Color("efffea"), Color("0f4a40")]
const FIRE := [Color("ff7a2a"), Color("fff0c4"), Color("5a1206")]
const THUNDER := [Color("7ab8ff"), Color("f4f9ff"), Color("1a2a6a")]
const NATURE := [Color("9be05a"), Color("f6ffe0"), Color("1f4a1a")]
const GOLD := [Color("ffc94a"), Color("fff8de"), Color("6a3a0a")]
const MOON := [Color("9cc0ff"), Color("f4f6ff"), Color("26306e")]
const DUST := [Color("c9b896"), Color("efe4cc"), Color("6a5a44")]
const ELEMENTS := {
	"fire": ["elemental_shot", "bomb_shot", "phoenix_shot", "phoenix_rain", "dragon_shot", "meteor_arrow"],
	"thunder": ["arrow_of_thunder", "lightning_arrow"],
	"nature": ["arrow_of_rage", "ensnare", "force_of_nature", "recall_wolverine", "avalanche"],
	"gold": ["perfect_aim", "perforation", "lethal_sight", "dionic_sight", "golden_falcon", "scout_hawk", "hunters_verdict", "sunfall_volley"],
	"moon": ["moonpiercer", "celestial_hunt"],
}
const PHOENIX := ["phoenix_shot", "phoenix_rain", "dragon_shot", "sunfall_volley"]
const RAIN := ["avalanche", "ensnare", "tempest", "phoenix_rain", "celestial_hunt", "sunfall_volley"]


static func element(id: String) -> String:
	for e in ELEMENTS:
		if id in ELEMENTS[e]:
			return e
	return "wind"


static func palette(id: String) -> Array:
	match element(id):
		"fire": return FIRE
		"thunder": return THUNDER
		"nature": return NATURE
		"gold": return GOLD
		"moon": return MOON
	return WIND


## The bow drawn: light gathers at the bow hand and glows hotter as the string
## comes back; high levels draw a sigil at the feet; rain shots light the sky.
static func anticipate(kit: SignatureKit, ctx: Dictionary) -> void:
	var c := palette(ctx.id)
	var time := float(ctx.time)
	var hand := Vector3(0.18, 1.35, 0.5)
	kit.sheet(K.SOFT, c, hand, 0.0, time + 0.06, {"billboard": 1, "size": Vector2.ONE * 0.25, "grow": Vector2.ONE * 1.25, "ease": K.IN, "fade_in": 0.3, "decay": 0.9, "level": K.CORE, "opacity": 0.7})
	kit.sheet(K.STREAK, c, hand + Vector3(0, 0, -0.05), 0.0, time + 0.06, {"billboard": 2, "basis": ClassSignature.along(Vector3.UP), "size": Vector2(0.18, 1.6), "grow": Vector2(0.32, 1.9), "fade_in": 0.5, "decay": 0.9, "opacity": 0.5})
	kit.burst("gather", c, hand, 0.0, {"amount": 14, "radius": 1.3, "speed": 1.0 / maxf(time, 0.2) * 0.45})
	var e := element(ctx.id)
	if e == "fire":
		kit.burst("embers", FIRE, hand, time * 0.3, {"amount": 8, "radius": 0.2, "speed": 0.6, "spread": 40.0})
	elif e == "thunder":
		for i in 2:
			kit.bolt(THUNDER, hand, hand + Vector3(randf_range(-0.7, 0.7), randf_range(0.4, 0.9), randf_range(-0.3, 0.4)), time * (0.35 + 0.3 * i), 0.18, 0.6, K.MAIN)
	if int(ctx.level) >= 40 or int(ctx.star) > 0:
		kit.sheet(K.RUNES, c, Vector3(0, 0.05, 0), 0.0, time + 0.1, {"ground": true, "size": Vector2.ONE * 1.4, "grow": Vector2.ONE * 2.3, "spin": 1.4, "count": 14.0, "fade_in": 0.3, "decay": 0.85, "opacity": 0.65})
	if String(ctx.id) in RAIN or String((ctx.skill as Dictionary).get("special", "")) == "rain":
		var sky := kit.to_local(Vector3(ctx.center.x, kit.global_position.y, ctx.center.z)) + Vector3(0, 7.5, 0)
		kit.sheet(K.SOFT, c, sky, 0.0, time + 0.3, {"billboard": 1, "size": Vector2.ONE * 1.0, "grow": Vector2.ONE * 4.0, "fade_in": 0.4, "decay": 0.8, "opacity": 0.55})
		kit.sheet(K.RUNES, c, sky, 0.0, time + 0.3, {"ground": true, "size": Vector2.ONE * 1.5, "grow": Vector2.ONE * float(ctx.radius) * 1.4, "spin": -1.0, "count": 18.0, "fade_in": 0.4, "decay": 0.85, "opacity": 0.6})


static func play(kit: SignatureKit, ctx: Dictionary) -> void:
	var id := String(ctx.id)
	var c := palette(id)
	var shape := String(ctx.shape)
	var skill: Dictionary = ctx.skill
	if id in RAIN or String(skill.get("special", "")) == "rain":
		rain(kit, c, float(ctx.radius), float(ctx.delay), 6 + int(ctx.level) / 12, id in PHOENIX)
		return
	match shape:
		"single", "fan", "chain":
			_release(kit, c, id, shape == "fan")
		"burst":
			_gale(kit, c, float(ctx.radius))
		"blast":
			_release(kit, c, id, false)
			_detonation(kit, c, kit.to_local(Vector3(ctx.center.x, kit.global_position.y, ctx.center.z)), float(ctx.radius), float(ctx.delay))
		"summon":
			_spirit(kit, c, id, Vector3(0, 0, 1.6))
		"self":
			_aura(kit, c, id)


## The release: a shock ring off the bow, a flash, a gust of wind forward and
## dust kicked from the archer's feet.
static func _release(kit: SignatureKit, c: Array, id: String, fan: bool) -> void:
	var bow := Vector3(0.12, 1.35, 0.7)
	kit.sheet(K.RING, c, bow, 0.0, 0.34, {"size": Vector2.ONE * 0.35, "grow": Vector2.ONE * (3.0 if fan else 2.3), "level": K.CORE, "decay": 0.3, "opacity": 0.9})
	kit.sheet(K.RING, c, bow + Vector3(0, 0, 0.5), 0.05, 0.3, {"size": Vector2.ONE * 0.2, "grow": Vector2.ONE * 1.5, "decay": 0.3, "opacity": 0.7})
	kit.sheet(K.SOFT, c, bow, 0.0, 0.16, {"billboard": 1, "size": Vector2.ONE * 1.6, "grow": Vector2.ONE * 0.6, "level": K.CORE, "fade_in": 0.01, "decay": 0.2, "opacity": 0.75})
	kit.burst("motes", c, bow, 0.0, {"amount": 16, "dir": Vector3(0, 0.15, 1), "spread": 28.0 if not fan else 60.0, "speed": 3.2, "radius": 0.15})
	kit.burst("dust", DUST, Vector3(0, 0.05, -0.1), 0.0, {"amount": 6, "radius": 0.35, "speed": 0.8})
	if id in PHOENIX:
		kit.burst("fire_feathers", FIRE, bow, 0.0, {"amount": 8, "dir": Vector3(0, 0.6, 0.5), "spread": 70.0, "speed": 1.4, "scale": 0.8})


## Rain of arrows: long streaks falling from the sky at a slant, each landing
## with a ground ring and a puff of dust, the last ones on the damage beat.
static func rain(kit: SignatureKit, c: Array, radius: float, landing: float, count: int, fire: bool) -> void:
	var n: int = [4, 8, count][K.detail()]
	var slant := Vector3(-0.22, -1.0, -0.14).normalized()
	for i in n:
		var a := randf() * TAU
		var r := sqrt(randf()) * radius * 0.9
		var ground := Vector3(cos(a) * r, 0.1, sin(a) * r)
		var fall := randf_range(0.32, 0.46)
		# The volley: the first arrows strike just before the damage beat, the rest stream in after.
		var land := maxf(0.06, landing - 0.12 + float(i) / float(n) * 0.42 + randf_range(-0.05, 0.05))
		var top := ground - slant * 7.5
		var length := randf_range(2.6, 3.8)
		kit.sheet(K.STREAK, c, top, land - fall, fall + 0.03, {"to": ground - slant * length * 0.45, "ease": K.LINEAR, "billboard": 2, "basis": ClassSignature.along(slant),
			"size": Vector2(0.42, length * 0.7), "grow": Vector2(0.3, length), "fade_in": 0.08, "decay": 0.95, "level": K.CORE if i < 4 else K.MAIN, "opacity": 0.95})
		kit.sheet(K.SOFT, c, ground + Vector3(0, 0.15, 0), land, 0.18, {"billboard": 1, "size": Vector2.ONE * 0.9, "grow": Vector2.ONE * 0.4, "fade_in": 0.01, "decay": 0.2, "level": K.DEBRIS, "opacity": 0.6})
		kit.sheet(K.RING, c, ground, land, 0.34, {"ground": true, "size": Vector2.ONE * 0.2, "grow": Vector2.ONE * 1.4, "decay": 0.3, "level": K.MAIN, "opacity": 0.75})
		if i % 2 == 0:
			kit.burst("dust", DUST, ground, land, {"amount": 5, "radius": 0.25, "speed": 0.7, "scale": 0.7})
		if fire and i % 3 == 0:
			kit.burst("embers", FIRE, ground, land, {"amount": 6, "radius": 0.2, "speed": 0.8})
	kit.sheet(K.RING, c, Vector3(0, 0.08, 0), landing, 0.45, {"ground": true, "size": Vector2.ONE * radius * 0.6, "grow": Vector2.ONE * radius * 2.2, "decay": 0.35, "level": K.CORE, "opacity": 0.8})
	kit.burst("dust", DUST, Vector3(0, 0.05, 0), landing, {"amount": 14, "radius": radius * 0.7, "speed": 1.4})
	if fire:
		kit.burst("fire_feathers", FIRE, Vector3(0, 0.6, 0), landing, {"amount": 10, "radius": radius * 0.5, "speed": 1.5, "spread": 70.0})


## Hurricane: rings of wind spiral up and out, leaves and dust whirl round.
static func _gale(kit: SignatureKit, c: Array, radius: float) -> void:
	for i in 3:
		kit.sheet(K.RING, c, Vector3(0, 0.15 + i * 0.7, 0), i * 0.08, 0.55, {"ground": true, "to": Vector3(0, 0.6 + i * 0.9, 0), "size": Vector2.ONE * 1.0, "grow": Vector2.ONE * radius * (1.2 + i * 0.35), "spin": 5.0, "level": K.CORE if i == 0 else K.MAIN, "decay": 0.4, "opacity": 0.55})
	kit.burst("motes", c, Vector3(0, 0.8, 0), 0.0, {"amount": 26, "radius": radius * 0.5, "speed": 1.6, "swirl": 9.0, "spread": 90.0})
	kit.burst("dust", DUST, Vector3(0, 0.05, 0), 0.0, {"amount": 12, "radius": radius * 0.45, "speed": 1.6})
	kit.burst("feathers", NATURE, Vector3(0, 1.0, 0), 0.05, {"amount": 10, "radius": radius * 0.4, "speed": 1.2, "swirl": 7.0, "scale": 0.7})


## A blast landing (Bomb Shot): fire ring, smoke and embers.
static func _detonation(kit: SignatureKit, c: Array, at: Vector3, radius: float, delay: float) -> void:
	kit.sheet(K.SOFT, c, at + Vector3(0, 0.8, 0), delay, 0.25, {"billboard": 1, "size": Vector2.ONE * radius * 0.8, "grow": Vector2.ONE * radius * 1.4, "level": K.CORE, "fade_in": 0.02, "decay": 0.25, "opacity": 0.55})
	kit.sheet(K.RING, c, at + Vector3(0, 0.08, 0), delay, 0.45, {"ground": true, "size": Vector2.ONE * 0.6, "grow": Vector2.ONE * radius * 2.1, "decay": 0.3, "level": K.CORE})
	kit.burst("embers", FIRE, at + Vector3(0, 0.4, 0), delay, {"amount": 16, "radius": radius * 0.35, "speed": 1.6, "swirl": 2.0, "spread": 80.0})
	kit.burst("smoke", [Color("5a4a44"), Color("8a7a70"), Color("1a1412")], at + Vector3(0, 0.5, 0), delay + 0.05, {"amount": 8, "radius": radius * 0.3, "speed": 0.9, "scale": 1.2})
	kit.burst("sparks", FIRE, at + Vector3(0, 0.4, 0), delay, {"amount": 12, "radius": 0.3, "spread": 75.0})
	kit.lamp(c[0], at + Vector3(0, 1.0, 0), 1.6, radius * 1.6)


## Summons: a spirit gate of light where the beast steps through.
static func _spirit(kit: SignatureKit, c: Array, id: String, at: Vector3) -> void:
	kit.sheet(K.RUNES, c, at + Vector3(0, 0.06, 0), 0.0, 1.2, {"ground": true, "size": Vector2.ONE * 0.6, "grow": Vector2.ONE * 2.6, "ease": K.BACK, "spin": 1.2, "count": 16.0, "level": K.CORE, "decay": 0.7, "opacity": 0.75})
	kit.sheet(K.STREAK, c, at + Vector3(0, 1.6, 0), 0.0, 0.9, {"billboard": 2, "basis": ClassSignature.along(Vector3.UP), "size": Vector2(1.6, 3.4), "grow": Vector2(0.6, 4.2), "decay": 0.5, "opacity": 0.55})
	kit.burst("motes", c, at + Vector3(0, 0.3, 0), 0.0, {"amount": 20, "radius": 0.8, "speed": 1.4, "dir": Vector3.UP, "spread": 25.0, "swirl": 3.0})
	if id == "golden_falcon":
		kit.burst("feathers", GOLD, at + Vector3(0, 1.4, 0), 0.1, {"amount": 10, "radius": 0.5, "speed": 1.6, "spread": 90.0})
	else:
		kit.burst("dust", DUST, at + Vector3(0, 0.05, 0), 0.05, {"amount": 10, "radius": 0.5, "speed": 1.4})
	kit.lamp(c[0], at + Vector3(0, 1.0, 0), 1.2, 4.0)


## Self buffs: a spirit wind spirals up round the archer; sight buffs open a
## halo of runes behind the head.
static func _aura(kit: SignatureKit, c: Array, id: String) -> void:
	for i in 3:
		kit.sheet(K.RING, c, Vector3(0, 0.1, 0), i * 0.12, 0.7, {"ground": true, "to": Vector3(0, 2.3, 0), "ease": K.OUT, "size": Vector2.ONE * 1.6, "grow": Vector2.ONE * 0.6, "spin": 6.0, "level": K.CORE if i == 0 else K.MAIN, "decay": 0.6, "opacity": 0.7})
	kit.burst("motes", c, Vector3(0, 0.4, 0), 0.0, {"amount": 22, "radius": 0.8, "speed": 1.2, "dir": Vector3.UP, "spread": 20.0, "swirl": 8.0})
	if id in ["dionic_sight", "scout_hawk", "sylph_step"]:
		kit.sheet(K.RUNES, c, Vector3(0, 1.9, -0.35), 0.0, 1.0, {"billboard": 1, "size": Vector2.ONE * 0.4, "grow": Vector2.ONE * 1.6, "ease": K.BACK, "roll_speed": 1.5, "count": 10.0, "decay": 0.7, "opacity": 0.65})
	kit.burst("feathers", c, Vector3(0, 1.4, 0), 0.1, {"amount": 8, "radius": 0.6, "speed": 1.2, "swirl": 5.0, "scale": 0.7})


## Riding the arrow: a luminous fletching trail behind it, two vanes of light
## at its tail, wind wakes left in the air and motes streaming off; fire
## arrows burn, thunder arrows crackle and phoenix shots become flaming birds.
static func flight(kit: SignatureKit, ctx: Dictionary) -> void:
	var id := String(ctx.id)
	var c := palette(id)
	var seconds := float(ctx.seconds)
	var size := float(ctx.size)
	var life := seconds + 0.1
	var trail := clampf(float(ctx.length) * 0.4, 1.2, 3.2) * size
	var back := ClassSignature.along(Vector3.BACK)
	kit.sheet(K.STREAK, c, Vector3(0, 0, -trail * 0.5), 0.0, life, {"billboard": 2, "basis": back, "size": Vector2(0.8 * size, trail * 0.6), "grow": Vector2(0.6 * size, trail),
		"ease": K.OUT, "fade_in": 0.05, "decay": 0.85, "level": K.CORE, "opacity": 0.9})
	for k in 2:
		kit.sheet(K.FEATHER, c, Vector3(0, 0, -0.75 * size), 0.0, life, {"basis": Basis(Vector3.BACK, k * PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5), "size": Vector2(0.5, 0.7) * size, "fade_in": 0.05, "decay": 0.85, "opacity": 0.8})
	var speed := float(ctx.length) / seconds
	var t := 0.04
	var wakes := 0
	while t < seconds - 0.04 and wakes < 3:
		var ring_life := minf(0.3, seconds - t + 0.08)
		kit.sheet(K.RING, c, Vector3(0, 0, -0.6), t, ring_life, {"to": Vector3(0, 0, -0.6 - speed * ring_life), "ease": K.LINEAR, "billboard": 1, "size": Vector2(0.15, 0.3) * size, "grow": Vector2(0.45, 0.9) * size, "decay": 0.25, "opacity": 0.55, "level": K.DEBRIS})
		t += maxf(0.09, seconds / 3.0)
		wakes += 1
	kit.burst("wake", c, Vector3(0, 0, -0.4), 0.0, {"amount": 14, "stream": seconds, "radius": 0.08, "speed": 0.4, "spread": 180.0})
	match element(id):
		"fire":
			kit.burst("embers", FIRE, Vector3(0, 0, -0.5), 0.0, {"amount": 12, "stream": seconds, "radius": 0.1, "speed": 0.5, "spread": 180.0})
			kit.sheet(K.FLAME, FIRE, Vector3(0, 0, -0.8 * size), 0.0, life, {"billboard": 2, "basis": back, "size": Vector2(0.6, 1.4) * size, "decay": 0.8, "opacity": 0.85, "glow": true})
		"thunder":
			kit.bolt(THUNDER, Vector3(0.1, 0, 0), Vector3(-0.15, 0.1, -trail), 0.0, life, 0.5, K.MAIN, true)
		"moon":
			kit.sheet(K.SOFT, MOON, Vector3.ZERO, 0.0, life, {"billboard": 1, "size": Vector2.ONE * 1.1 * size, "decay": 0.8, "opacity": 0.5})
	if id in PHOENIX:
		_phoenix(kit, size, life, seconds)


## The phoenix: two wings of fire beating at the arrow, a flame tail and
## feathers of fire drifting down behind it.
static func _phoenix(kit: SignatureKit, size: float, life: float, seconds: float) -> void:
	var plumes: int = [1, 2, 3][K.detail()]
	for side in [-1.0, 1.0]:
		for k in plumes:
			var sweep := 0.35 + 0.32 * float(k)
			var out := Vector3(side * sin(PI * 0.5 - sweep), 0.0, -cos(PI * 0.5 - sweep))
			kit.sheet(K.FEATHER, FIRE, (out * 0.8 + Vector3(0, 0.05 * k, -0.15)) * size, 0.0, life,
				{"basis": Basis(Vector3.UP, -side * (PI * 0.5 - sweep)) * Basis(Vector3.RIGHT, -PI * 0.5), "size": Vector2(0.55, 1.6 - 0.25 * k) * size,
				"flap": side * 0.5, "flap_speed": 15.0, "phase": -0.25 * k, "level": K.CORE if k == 0 else K.MAIN, "decay": 0.85, "opacity": 0.85})
	kit.sheet(K.SOFT, FIRE, Vector3.ZERO, 0.0, life, {"billboard": 1, "size": Vector2.ONE * 1.3 * size, "decay": 0.85, "opacity": 0.6, "level": K.CORE})
	kit.burst("fire_feathers", FIRE, Vector3(0, 0, -0.6), 0.0, {"amount": 10, "stream": seconds, "radius": 0.3, "speed": 0.5, "spread": 180.0, "scale": 0.7})


## Every hit: a ring of light, a puff of torn fletching and sparks; fire hits
## burn, thunder hits branch down from the sky, wind hits gust.
static func contact(kit: SignatureKit, ctx: Dictionary) -> void:
	var id := String(ctx.id)
	var c := palette(id)
	var crit := bool(ctx.crit)
	kit.sheet(K.RING, c, Vector3.ZERO, 0.0, 0.3, {"billboard": 1, "size": Vector2.ONE * 0.3, "grow": Vector2.ONE * (2.2 if crit else 1.5), "level": K.CORE, "decay": 0.3, "opacity": 0.85})
	kit.burst("feathers", c, Vector3.ZERO, 0.0, {"amount": 4, "radius": 0.15, "speed": 1.0, "spread": 120.0, "scale": 0.5})
	kit.burst("sparks", c, Vector3.ZERO, 0.0, {"amount": 8, "radius": 0.1, "spread": 90.0, "speed": 0.8})
	match element(id):
		"fire":
			kit.burst("embers", FIRE, Vector3.ZERO, 0.0, {"amount": 8, "radius": 0.3, "speed": 1.0, "swirl": 2.0})
		"thunder":
			var top := Vector3(randf_range(-1.0, 1.0), 7.0, randf_range(-1.0, 1.0))
			kit.bolt(THUNDER, top, Vector3.ZERO, 0.0, 0.3, 0.8, K.CORE)
			if ctx.previous != null:
				kit.bolt(THUNDER, kit.to_local(ctx.previous), Vector3.ZERO, 0.0, 0.28, 0.5, K.MAIN)
			kit.sheet(K.SOFT, THUNDER, Vector3.ZERO, 0.0, 0.22, {"billboard": 1, "size": Vector2.ONE * 1.6, "level": K.MAIN, "decay": 0.2, "opacity": 0.6})
		"nature":
			kit.burst("motes", NATURE, Vector3.ZERO, 0.0, {"amount": 8, "radius": 0.3, "speed": 1.2})
	if id in PHOENIX:
		kit.burst("fire_feathers", FIRE, Vector3.ZERO, 0.0, {"amount": 8, "radius": 0.3, "speed": 1.6, "spread": 100.0})


## Star beats: Moonpiercer's silver lance, Hunter's Verdict's three marks,
## Sylph Step's gale, Celestial Hunt's and Sunfall Volley's rain of light.
static func star_beat(kit: SignatureKit, ctx: Dictionary) -> void:
	var id := String(ctx.id)
	var c := palette(id)
	var index := int(ctx.index)
	var radius := float(ctx.radius)
	match id:
		"celestial_hunt", "sunfall_volley":
			rain(kit, c, radius, 0.0 if index > 0 else 0.15, 8 + index * 2, id == "sunfall_volley")
			if id == "sunfall_volley" and index == 0:
				kit.sheet(K.RUNES, GOLD, Vector3(0, 7.5, 0), 0.0, 1.6, {"ground": true, "size": Vector2.ONE * radius, "grow": Vector2.ONE * radius * 1.8, "spin": 0.8, "count": 24.0, "level": K.CORE, "decay": 0.75, "opacity": 0.5})
		"sylph_step":
			_gale(kit, WIND, radius * 0.7)
		"moonpiercer":
			var src := kit.to_local(ctx.origin)
			src.y = 1.2
			var lane := Vector3(0, 1.2, 0) - src
			kit.sheet(K.STREAK, MOON, src + lane * 0.5, 0.0, 0.4, {"billboard": 2, "basis": ClassSignature.along(lane), "size": Vector2(0.5, lane.length()), "grow": Vector2(0.15, lane.length() * 1.2), "level": K.CORE, "decay": 0.3})
			kit.sheet(K.RING, MOON, Vector3(0, 1.2, 0), 0.0, 0.45, {"billboard": 1, "size": Vector2.ONE * 0.5, "grow": Vector2.ONE * 3.0, "level": K.CORE, "decay": 0.3})
			kit.burst("motes", MOON, Vector3(0, 1.2, 0), 0.0, {"amount": 14, "radius": 0.4, "speed": 2.0, "spread": 90.0})
		_:
			kit.sheet(K.RUNES, c, Vector3(0, 1.3, 0), 0.0, 0.6, {"billboard": 1, "size": Vector2.ONE * 2.2, "grow": Vector2.ONE * 0.9, "ease": K.OUT, "roll_speed": -3.0, "count": 8.0, "level": K.CORE, "decay": 0.5})
			kit.sheet(K.RING, c, Vector3(0, 1.2, 0), 0.05, 0.35, {"billboard": 1, "size": Vector2.ONE * 0.4, "grow": Vector2.ONE * 2.4, "level": K.MAIN, "decay": 0.3})
			kit.burst("feathers", c, Vector3(0, 1.2, 0), 0.0, {"amount": 6, "radius": 0.2, "speed": 1.2, "spread": 120.0, "scale": 0.6})
			kit.burst("sparks", c, Vector3(0, 1.2, 0), 0.0, {"amount": 10, "radius": 0.2, "spread": 90.0})
