class_name SetGearArt
extends RefCounted
## The 250-star class sets (SetGearData). Each piece is the eclipse silhouette of
## StarGearArt re-cut in the class's set palette, crowned with what only the set
## has: an emissive rune halo with floating shards on the weapon, the class sigil
## (flames, gale leaves, thunder, a galaxy, dawn rays, a moon, ice, blood
## crescents, abyss horns or aurora ribbons) on the weapon, chest, helm, amulet
## and ring, glowing trims, and the class aura at the hero's feet (aura()).
## Built once into StarGearArt's two vertex-colour surfaces (solid + unshaded
## glow): no per-frame script, lights or extra materials. Weapons keep
## WeaponKit's grip origin and +Y axis; worn pieces are in ChibiGear bone frames.

## Where each weapon's rune halo sits (held units, before the kind's scale) and its radius.
const HEADS := {
	"sword": [Vector3(0, 1.18, 0.0), 0.44], "spear": [Vector3(0, 1.62, 0.0), 0.4], "bow": [Vector3(-0.4, 0, -0.06), 0.3],
	"staff": [Vector3(0, 2.05, 0.0), 0.74], "wand": [Vector3(0, 0.79, 0.0), 0.42], "lantern": [Vector3(-0.6, 0.85, 0.0), 0.34],
	"greatshield": [Vector3(0, 0.12, 0.4), 0.3], "shield": [Vector3(0, 0.12, 0.4), 0.3], "dagger": [Vector3(0, 0.66, 0.0), 0.3],
	"scepter": [Vector3(0, 0.86, 0.0), 0.42], "lute": [Vector3(0, -0.33, -0.05), 0.3], "book": [Vector3(0, 0.06, 0.0), 0.5],
	"tome": [Vector3(0, 0.06, 0.0), 0.5],
}
const HELD := ["sword", "spear", "bow", "staff", "wand", "lantern", "greatshield", "shield", "dagger", "scepter", "lute", "book", "tome"]


static func cloth(cls: String) -> Color:
	return SetGearData.palette(cls).cloth


static func _palette(cls: String) -> Dictionary:
	return SetGearData.palette(cls)


## "set_<kind>_<class>": a held weapon or off-hand (shield, book, tome, dagger).
static func build(look: String) -> Node3D:
	var bits := look.split("_")
	var kind := String(bits[1]) if bits.size() >= 3 else "sword"
	var cls := String(bits[2]) if bits.size() >= 3 else "warrior"
	var root := Node3D.new()
	root.name = look
	if not StarGearArt._cache.has(look):
		var b := StarGearArt._builder()
		var p := _palette(cls)
		match kind:
			"sword": StarGearArt._sword(b, p, 3)
			"spear": StarGearArt._spear(b, p, 3)
			"bow": StarGearArt._bow(b, p, 3)
			"staff": StarGearArt._staff(b, p, 3)
			"wand": StarGearArt._wand(b, p, 3)
			"lantern": StarGearArt._lantern(b, p, 3)
			"greatshield", "shield": StarGearArt._shield(b, p, 3)
			"dagger": StarGearArt._dagger(b, p, 3)
			"scepter": StarGearArt._scepter(b, p, 3)
			"lute": StarGearArt._lute(b, p, 3)
			"book", "tome": StarGearArt._book(b, p, 3)
		_weapon_extras(b, p, kind, cls)
		StarGearArt._store(look, b)
	StarGearArt._attach(root, look)
	# The same held sizes as the star pieces.
	if kind == "greatshield": root.scale = Vector3.ONE * 1.55
	if kind == "dagger": root.scale = Vector3.ONE * 0.62
	if kind == "lute": root.scale = Vector3.ONE * float(WeaponKit.MODELS.lute.scale) / 1.5
	root.set_meta("star_gear", true)
	root.set_meta("set_gear", true)
	root.set_meta("weapon_kind", kind)
	return root


## part: chest | pauldron | belt | helm | boots | ring | amulet (ChibiGear bone frames).
static func armor_piece(part: String, cls: String, side := 1.0) -> Node3D:
	var key := "setwear_%s_%s_%d" % [part, cls, int(side)]
	var root := Node3D.new()
	root.name = "Set_" + part
	if not StarGearArt._cache.has(key):
		var b := StarGearArt._builder()
		var p := _palette(cls)
		match part:
			"chest":
				StarGearArt._chest(b, p, 3, cls)
				_chest_extras(b, p, cls)
			"pauldron":
				StarGearArt._pauldron(b, p, 3, cls, side)
				_pauldron_extras(b, p, cls, side)
			"belt":
				StarGearArt._belt(b, p, 3, cls)
				_belt_extras(b, p, cls)
			"helm":
				StarGearArt._helm(b, p, 3, cls)
				_helm_extras(b, p, cls)
			"boots":
				StarGearArt._boots(b, p, 3, cls)
				_boots_extras(b, p, cls)
			"ring":
				_ring(b, p, cls)
			"amulet":
				StarGearArt._amulet(b, p, 3, cls)
				_amulet_extras(b, p, cls)
		StarGearArt._store(key, b)
	StarGearArt._attach(root, key)
	root.set_meta("set_gear", true)
	return root


## The inventory icon model of a set look (ItemLook.build_icon_node).
static func build_icon_node(look: String) -> Node3D:
	var bits := look.split("_")
	var kind := String(bits[1]) if bits.size() >= 3 else "sword"
	var cls := String(bits[2]) if bits.size() >= 3 else "warrior"
	var root := Node3D.new()
	if kind in HELD:
		root.add_child(build(look))
		root.rotation_degrees.z = -27.0 if kind not in ["bow", "shield", "greatshield"] else -12.0
		return root
	if kind == "armor":
		root.add_child(armor_piece("chest", cls))
		for side in [-1.0, 1.0]:
			var shoulder := armor_piece("pauldron", cls, side)
			shoulder.position = Vector3(side * 0.135, 0.07, 0)
			root.add_child(shoulder)
		var belt := armor_piece("belt", cls)
		belt.position.y = -0.13
		root.add_child(belt)
	elif kind == "boots":
		var boot_key := "seticon_boots_%s" % cls
		if not StarGearArt._cache.has(boot_key):
			var b := StarGearArt._builder()
			var p := _palette(cls)
			StarGearArt._boots(b, p, 3, cls)
			_boots_extras(b, p, cls)
			StarGearArt._part(b, MeshKit.box(), p.cloth, Vector3(0, -0.07, 0), Vector3(0.105, 0.16, 0.11))
			StarGearArt._part(b, MeshKit.box(), p.dark, Vector3(0, -0.159, 0.047), Vector3(0.112, 0.031, 0.21))
			StarGearArt._part(b, MeshKit.box(), p.metal, Vector3(0, -0.132, 0.078), Vector3(0.108, 0.038, 0.13))
			StarGearArt._line(b, [Vector3(-0.056, -0.142, 0.15), Vector3(0, -0.12, 0.158), Vector3(0.056, -0.142, 0.15)], 0.006, p.glow, true)
			StarGearArt._store(boot_key, b)
		StarGearArt._attach(root, boot_key)
		root.rotation_degrees = Vector3(-12, -32, 0)
	else:
		root.add_child(armor_piece(kind, cls))
	root.scale = Vector3.ONE * 5.0
	return root


# --- Shared ornaments ---------------------------------------------------------

## A four-pointed star of light in XY at [param at].
static func _spark(b: Dictionary, at: Vector3, s: float, color: Color) -> void:
	StarGearArt._shape(b, [Vector2(0, s), Vector2(s * 0.22, s * 0.22), Vector2(s, 0), Vector2(s * 0.22, -s * 0.22), Vector2(0, -s), Vector2(-s * 0.22, -s * 0.22), Vector2(-s, 0), Vector2(-s * 0.22, s * 0.22)], at, s * 0.12, color, true)


## A rune ring facing +Z: a glowing band, a metal inner ring and rune ticks.
static func _rune_halo(b: Dictionary, p: Dictionary, at: Vector3, r: float, ticks := 8) -> void:
	StarGearArt._ring_at(b, at, r, r * 0.07, p.glow, Vector3(90, 0, 0), true)
	StarGearArt._ring_at(b, at, r * 0.84, r * 0.05, p.metal, Vector3(90, 0, 0))
	for k in ticks:
		var a := TAU * k / float(ticks)
		var dir := Vector3(sin(a), cos(a), 0)
		StarGearArt._part(b, MeshKit.box(), p.glow, at + dir * r * 0.92, Vector3(r * 0.05, r * 0.14, r * 0.04), Vector3(0, 0, -rad_to_deg(a)), true)


## The class sigil in XY facing +Z, about [param s] across its half-width.
static func _sigil(b: Dictionary, p: Dictionary, cls: String, c: Vector3, s: float) -> void:
	match cls:
		"warrior":  # a crown of flames
			for k in 5:
				var a := (float(k) - 2.0) * 0.32
				var length := s * (2.3 - absf(float(k) - 2.0) * 0.45)
				StarGearArt._feather(b, c + Vector3(sin(a) * s * 0.55, cos(a) * s * 0.55 + length * 0.3, 0.0), length, s * 0.62, -a, p.glow, true)
				StarGearArt._feather(b, c + Vector3(sin(a) * s * 0.5, cos(a) * s * 0.5 + length * 0.18, s * 0.06), length * 0.55, s * 0.32, -a, p.edge, true)
		"archer":  # three gale leaves turning round a gem
			for k in 3:
				var a := TAU * k / 3.0
				StarGearArt._feather(b, c + Vector3(sin(a), cos(a), 0) * s * 0.75, s * 1.6, s * 0.55, -a - 0.9, p.glow, true)
			StarGearArt._ring_at(b, c, s * 0.42, s * 0.08, p.metal)
		"lancer":  # a thunderbolt between two dragon horns
			StarGearArt._line(b, [c + Vector3(-s * 0.2, s * 1.3, 0), c + Vector3(s * 0.32, s * 0.2, 0), c + Vector3(-s * 0.22, s * 0.05, 0), c + Vector3(s * 0.25, -s * 1.2, 0)], s * 0.13, p.glow, true)
			for side in [-1.0, 1.0]:
				StarGearArt._line(b, [c + Vector3(side * s * 0.5, -s * 0.2, -s * 0.05), c + Vector3(side * s * 0.95, s * 0.5, -s * 0.05), c + Vector3(side * s * 0.72, s * 1.2, -s * 0.05)], s * 0.12, p.metal)
		"mage":  # a galaxy: a glowing core, a tilted orbit and four stars
			StarGearArt._part(b, MeshKit.sphere_low(), p.gem, c, Vector3.ONE * s * 0.6, Vector3.ZERO, true)
			StarGearArt._ring_at(b, c, s * 0.95, s * 0.07, p.glow, Vector3(70, 0, 25), true)
			for k in 4:
				var a := TAU * k / 4.0 + 0.4
				_spark(b, c + Vector3(sin(a), cos(a), 0.0) * s * 1.25, s * 0.32, p.edge)
		"priest":  # dawn: a sun disc in twelve rays
			StarGearArt._part(b, MeshKit.sphere_low(), p.glow, c, Vector3(s * 0.75, s * 0.75, s * 0.2), Vector3.ZERO, true)
			for k in 12:
				var a := TAU * k / 12.0
				var length := s * (0.85 if k % 2 == 0 else 0.55)
				StarGearArt._part(b, MeshKit.box(), p.metal if k % 2 else p.glow, c + Vector3(sin(a), cos(a), 0) * (s * 0.5 + length * 0.5), Vector3(s * 0.09, length, s * 0.05), Vector3(0, 0, -rad_to_deg(a)), k % 2 == 0)
		"summoner":  # a crescent moon and two spirit wisps
			for k in 9:
				var a := PI * (0.15 + 1.25 * float(k) / 8.0)
				var thick := sin(PI * float(k) / 8.0)
				StarGearArt._feather(b, c + Vector3(-cos(a), sin(a), 0) * s, s * 0.55, s * (0.18 + 0.32 * thick), a, p.glow, true)
			for side in [-1.0, 1.0]:
				StarGearArt._part(b, MeshKit.sphere_low(), p.edge, c + Vector3(side * s * 0.35 + s * 0.3, side * s * 0.45, 0), Vector3.ONE * s * 0.26, Vector3.ZERO, true)
		"defender":  # glacier shards over a hexagonal ward
			var hexagon: Array[Vector2] = []
			for k in 6:
				var a := TAU * k / 6.0
				hexagon.append(Vector2(sin(a), cos(a)) * s * 0.7)
			StarGearArt._shape(b, hexagon, c, s * 0.12, p.metal)
			for k in 5:
				var a := (float(k) - 2.0) * 0.38
				StarGearArt._shape(b, [Vector2(-s * 0.16, 0), Vector2(0, s * (1.1 - absf(float(k) - 2.0) * 0.18)), Vector2(s * 0.16, 0), Vector2(0, -s * 0.2)], c + Vector3(sin(a) * s * 0.6, cos(a) * s * 0.6, s * 0.04), s * 0.08, p.glow, true, -a)
		"assassin":  # two blood crescents crossed over a drop
			for side in [-1.0, 1.0]:
				for k in 7:
					var a := PI * (0.2 + 0.6 * float(k) / 6.0)
					var at := c + Vector3(side * cos(a) * s * 0.9 - side * s * 0.25, sin(a) * s * 1.1 - s * 0.45, side * 0.01 * s)
					StarGearArt._feather(b, at, s * 0.48, s * (0.12 + 0.2 * sin(PI * float(k) / 6.0)), side * (a - PI * 0.5), p.glow, true)
			StarGearArt._shape(b, [Vector2(0, s * 0.45), Vector2(s * 0.24, -s * 0.08), Vector2(0, -s * 0.34), Vector2(-s * 0.24, -s * 0.08)], c + Vector3(0, -s * 0.1, s * 0.06), s * 0.1, p.gem, true)
		"darklord":  # abyss horns round a green hellfire eye
			for side in [-1.0, 1.0]:
				StarGearArt._line(b, [c + Vector3(side * s * 0.35, -s * 0.15, 0), c + Vector3(side * s * 0.95, s * 0.35, 0), c + Vector3(side * s * 0.88, s * 1.0, 0), c + Vector3(side * s * 0.55, s * 1.35, 0)], s * 0.13, p.dark.lightened(0.25))
				StarGearArt._feather(b, c + Vector3(side * s * 0.3, s * 0.6, s * 0.02), s * 1.1, s * 0.34, side * -0.35, p.glow, true)
			StarGearArt._shape(b, [Vector2(-s * 0.5, 0), Vector2(0, s * 0.26), Vector2(s * 0.5, 0), Vector2(0, -s * 0.26)], c + Vector3(0, 0, s * 0.05), s * 0.1, p.gem, true)
			StarGearArt._part(b, MeshKit.sphere_low(), p.dark, c + Vector3(0, 0, s * 0.1), Vector3(s * 0.16, s * 0.24, s * 0.08))
		"bard":  # aurora ribbons under a note
			var colors: Array[Color] = [p.glow, p.gem, p.edge]
			for k in 3:
				var arc: Array[Vector3] = []
				for j in 7:
					var a := PI * (0.12 + 0.76 * float(j) / 6.0)
					arc.append(c + Vector3(-cos(a) * s * (1.2 - k * 0.22), sin(a) * s * (0.9 - k * 0.18) - s * 0.35, -k * 0.01 * s))
				StarGearArt._line(b, arc, s * 0.08, colors[k], true)
			StarGearArt._part(b, MeshKit.sphere_low(), p.metal, c + Vector3(-s * 0.12, -s * 0.05, s * 0.05), Vector3(s * 0.34, s * 0.25, s * 0.14), Vector3(0, 0, -25))
			StarGearArt._line(b, [c + Vector3(s * 0.04, -s * 0.02, s * 0.05), c + Vector3(s * 0.04, s * 0.7, s * 0.05), c + Vector3(s * 0.3, s * 0.52, s * 0.05)], s * 0.06, p.metal)


# --- Weapons -------------------------------------------------------------------

static func _weapon_extras(b: Dictionary, p: Dictionary, kind: String, cls: String) -> void:
	var head: Vector3 = HEADS.get(kind, HEADS.sword)[0]
	var r: float = HEADS.get(kind, HEADS.sword)[1]
	var behind := head + Vector3(0, 0, -0.03 if kind not in ["greatshield", "shield"] else 0.03)
	_rune_halo(b, p, behind, r, 12 if r > 0.5 else 8)
	# Four shards float at the halo's diagonals.
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		StarGearArt._shape(b, [Vector2(-r * 0.08, 0), Vector2(0, r * 0.24), Vector2(r * 0.08, 0), Vector2(0, -r * 0.24)], behind + Vector3(sin(a), cos(a), 0) * r * 1.18, r * 0.05, p.gem, true, -a)
	# The class sigil: on a shield's face, on the lute's back, behind every other head.
	match kind:
		"greatshield", "shield":
			_sigil(b, p, cls, Vector3(0, 0.12, 0.47), 0.15)
		"book", "tome":
			_sigil(b, p, cls, Vector3(0, 0.08, 0.17), 0.12)
		"bow":
			_sigil(b, p, cls, head + Vector3(-0.02, 0, -0.08), r * 0.42)
		"lute":
			_sigil(b, p, cls, Vector3(0, 0.52, -0.1), 0.07)
		"sword":
			# A glowing edge down both sides of the blade and the sigil over the guard.
			for side in [-1.0, 1.0]:
				StarGearArt._line(b, [Vector3(side * 0.2, 0.45, 0.05), Vector3(side * 0.15, 1.6, 0.05), Vector3(0, 2.36, 0.03)], 0.012, p.glow, true)
			_sigil(b, p, cls, Vector3(0, 0.52, 0.12), 0.12)
		"dagger":
			_sigil(b, p, cls, Vector3(0, 0.36, 0.1), 0.1)
		_:
			_sigil(b, p, cls, head + Vector3(0, 0, 0.12), r * 0.42)


# --- Worn pieces (ChibiGear bone frames) -------------------------------------

static func _chest_extras(b: Dictionary, p: Dictionary, cls: String) -> void:
	# Glowing piping round the breastplate and a rune circle carrying the sigil.
	var rim: Array[Vector3] = [Vector3(-0.108, 0.084, 0.104), Vector3(-0.086, -0.065, 0.106), Vector3(0, -0.103, 0.104), Vector3(0.086, -0.065, 0.106), Vector3(0.108, 0.084, 0.104)]
	StarGearArt._line(b, rim, 0.0045, p.glow, true)
	StarGearArt._ring_at(b, Vector3(0, 0.0, 0.128), 0.045, 0.004, p.glow, Vector3(90, 0, 0), true)
	_sigil(b, p, cls, Vector3(0, 0.0, 0.134), 0.026)
	for side in [-1.0, 1.0]:
		StarGearArt._line(b, [Vector3(side * 0.09, 0.06, -0.118), Vector3(side * 0.1, -0.2, -0.118)], 0.004, p.glow, true)


static func _pauldron_extras(b: Dictionary, p: Dictionary, cls: String, side: float) -> void:
	for k in 3:
		StarGearArt._feather(b, Vector3(side * (0.06 + k * 0.014), 0.05 + k * 0.016, -0.02 - k * 0.01), 0.07 + k * 0.012, 0.022, side * -(0.55 + k * 0.2), p.glow, true)
	StarGearArt._ring_at(b, Vector3(side * 0.012, 0.012, 0.0), 0.06, 0.006, p.glow, Vector3(0, 0, side * -15), true)
	if cls in ["warrior", "defender", "darklord", "lancer"]:
		StarGearArt._part(b, MeshKit.cone(), p.metal, Vector3(side * 0.05, 0.065, 0.0), Vector3(0.03, 0.07, 0.03), Vector3(0, 0, side * -35))


static func _belt_extras(b: Dictionary, p: Dictionary, cls: String) -> void:
	StarGearArt._ring_at(b, Vector3(0, 0.07, -0.005), 0.148, 0.007, p.glow, Vector3.ZERO, true)
	for side in [-1.0, 1.0]:
		StarGearArt._gem(b, Vector3(side * 0.07, 0.085, 0.13), Vector3(0.02, 0.028, 0.008), p)
	if cls in ["mage", "priest", "summoner", "bard"]:
		StarGearArt._line(b, [Vector3(0, 0.06, 0.14), Vector3(0, -0.12, 0.13)], 0.004, p.glow, true)


static func _helm_extras(b: Dictionary, p: Dictionary, cls: String) -> void:
	# A floating crest of the sigil above the brow and a thin glowing circlet.
	StarGearArt._ring_at(b, Vector3(0, 0.2, 0.01), 0.205, 0.008, p.glow, Vector3(-8, 0, 0), true)
	var crest := Vector3(0, 0.37, 0.15) if cls != "mage" else Vector3(0, 0.3, 0.19)
	_sigil(b, p, cls, crest, 0.045)
	for side in [-1.0, 1.0]:
		StarGearArt._shape(b, [Vector2(-0.012, 0), Vector2(0, 0.05), Vector2(0.012, 0), Vector2(0, -0.012)], Vector3(side * 0.12, 0.27, 0.15), 0.006, p.glow, true, side * -0.5)


static func _boots_extras(b: Dictionary, p: Dictionary, cls: String) -> void:
	StarGearArt._ring_at(b, Vector3(0, -0.006, 0), 0.068, 0.006, p.glow, Vector3.ZERO, true)
	for side in [-1.0, 1.0]:
		StarGearArt._feather(b, Vector3(side * 0.065, -0.01, -0.03), 0.07, 0.022, side * -1.15, p.glow, true)
	if cls in ["warrior", "defender", "lancer", "darklord"]:
		StarGearArt._part(b, MeshKit.cone(), p.metal, Vector3(0, 0.03, 0.06), Vector3(0.022, 0.05, 0.022), Vector3(20, 0, 0))


## A signet: a broad band tipped towards the viewer, a glowing inlay, a gem in four
## prongs and the class sigil rising behind the gem like a crown.
static func _ring(b: Dictionary, p: Dictionary, cls: String) -> void:
	StarGearArt._ring_at(b, Vector3(0, -0.01, 0), 0.026, 0.013, p.metal, Vector3(62, 0, 0))
	StarGearArt._ring_at(b, Vector3(0, -0.01, 0.001), 0.0265, 0.004, p.glow, Vector3(62, 0, 0), true)
	_sigil(b, p, cls, Vector3(0, 0.028, -0.006), 0.012)
	var top := Vector3(0, 0.017, 0.012)
	StarGearArt._part(b, MeshKit.cylinder(), p.dark, top - Vector3(0, 0.004, 0), Vector3(0.022, 0.008, 0.022))
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		StarGearArt._part(b, MeshKit.box(), p.edge, top + Vector3(sin(a) * 0.011, 0.002, cos(a) * 0.011), Vector3(0.003, 0.012, 0.003))
	StarGearArt._gem(b, top + Vector3(0, 0.004, 0.004), Vector3(0.02, 0.024, 0.01), p)


static func _amulet_extras(b: Dictionary, p: Dictionary, cls: String) -> void:
	var center := Vector3(0, -0.018, 0.123)
	StarGearArt._ring_at(b, center, 0.036, 0.004, p.glow, Vector3(90, 0, 0), true)
	_sigil(b, p, cls, center + Vector3(0, 0, 0.012), 0.017)
	for side in [-1.0, 1.0]:
		StarGearArt._gem(b, Vector3(side * 0.045, 0.02, 0.112), Vector3(0.012, 0.018, 0.005), p)


# --- The class aura ------------------------------------------------------------

## The set's aura at the hero's feet (visual space): a rune circle in the class
## glow with the sigil on the ground, and rising motes unless [param light]
## (other players, the lowest quality). The caller frees it with the outfit.
static func aura(cls: String, light := false) -> Node3D:
	var root := Node3D.new()
	root.name = "SetAura"
	root.set_meta("set_aura", cls)
	var key := "setaura_" + cls
	if not StarGearArt._cache.has(key):
		var b := StarGearArt._builder()
		var p := _palette(cls)
		StarGearArt._ring_at(b, Vector3.ZERO, 0.86, 0.03, p.glow, Vector3.ZERO, true)
		StarGearArt._ring_at(b, Vector3.ZERO, 0.7, 0.018, p.glow.lerp(p.edge, 0.4), Vector3.ZERO, true)
		for k in 12:
			var a := TAU * k / 12.0
			StarGearArt._part(b, MeshKit.box(), p.glow, Vector3(sin(a) * 0.78, 0, cos(a) * 0.78), Vector3(0.035, 0.012, 0.12), Vector3(0, rad_to_deg(a), 0), true)
		for k in 6:
			var a := TAU * k / 6.0 + PI / 6.0
			StarGearArt._shape(b, [Vector2(-0.05, 0), Vector2(0, 0.14), Vector2(0.05, 0), Vector2(0, -0.04)], Vector3(sin(a) * 0.95, 0.07, cos(a) * 0.95), 0.02, p.gem, true, 0.0)
		StarGearArt._store(key, b)
	var ring := Node3D.new()
	ring.name = "Circle"
	ring.position.y = 0.03
	root.add_child(ring)
	StarGearArt._attach(ring, key)
	if not light and GameSettings.quality > 0:
		var p := _palette(cls)
		var motes := CPUParticles3D.new()
		motes.name = "SetMotes"
		var quad := QuadMesh.new()
		quad.size = Vector2(0.16, 0.16)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_texture = VfxKit.soft_dot()
		mat.albedo_color = Color(p.glow.r, p.glow.g, p.glow.b, 0.75)
		quad.material = mat
		motes.mesh = quad
		motes.amount = VfxBudget.count(18)
		motes.lifetime = 1.8
		motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		motes.emission_ring_axis = Vector3.UP
		motes.emission_ring_radius = 0.82
		motes.emission_ring_inner_radius = 0.6
		motes.emission_ring_height = 0.02
		motes.direction = Vector3.UP
		motes.spread = 8.0
		motes.initial_velocity_min = 0.4
		motes.initial_velocity_max = 0.9
		motes.gravity = Vector3.ZERO
		motes.local_coords = false
		motes.color_ramp = VfxKit._fade_ramp()
		motes.position.y = 0.05
		motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(motes)
	return root
