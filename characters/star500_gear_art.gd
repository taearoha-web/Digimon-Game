class_name Star500GearArt
extends RefCounted
## The 500-star class sets of ดินแดนเทวาลัย (Star500Gear). Every piece is the eclipse
## silhouette of StarGearArt re-cut in celestial gold, pearl and jade, crowned with
## the 250★ set's rune halo and class sigil (SetGearArt, now in the class's accent),
## and then what only heaven gives: a sunburst of gold rays and a tilted jade orbit
## behind every weapon head, a pair of pearl angel wings at the guard, a floating
## jade tear above the tip; on the body pearl feather mantles at the shoulders and
## the back, a floating gold halo over the helm with wings at the temples, winged
## ankles, a lotus at the breast; and a celestial lotus circle at the hero's feet
## from AURA_PIECES worn pieces (aura()). The wings are Star500WingArt.
##
## Built once into StarGearArt's two vertex-colour surfaces (solid + unshaded glow):
## no per-frame script, lights or extra materials (the aura adds one particle mote
## system, never in a crowd's light dress). Weapons keep WeaponKit's grip origin and
## +Y axis; worn pieces are in ChibiGear bone frames.

## Where the guard wings sit (held units, before the kind's scale) and their size.
const GUARD := {
	"sword": [Vector3(0, 0.34, -0.02), 0.62], "spear": [Vector3(0, 1.2, -0.02), 0.5], "bow": [Vector3(-0.1, 0, -0.04), 0.46],
	"staff": [Vector3(0, 1.62, -0.02), 0.55], "wand": [Vector3(0, 0.6, -0.02), 0.36], "lantern": [Vector3(0, 0.6, -0.02), 0.4],
	"greatshield": [Vector3(0, 0.3, 0.3), 0.55], "shield": [Vector3(0, 0.3, 0.3), 0.55], "dagger": [Vector3(0, 0.26, -0.02), 0.34],
	"scepter": [Vector3(0, 0.66, -0.02), 0.42], "lute": [Vector3(0, -0.12, -0.08), 0.3], "book": [Vector3(0, 0.06, -0.02), 0.42],
	"tome": [Vector3(0, 0.06, -0.02), 0.42],
}


static func palette(cls: String) -> Dictionary:
	var own := SetGearData.palette(cls)
	return {
		"metal": Star500Gear.GOLD, "edge": Star500Gear.PEARL, "cloth": cloth(cls), "gem": own.gem,
		"dark": Star500Gear.JADE_DEEP.lerp(own.dark, 0.3), "glow": (own.glow as Color).lerp(Star500Gear.GOLD_LIGHT, 0.25),
		"jade": Star500Gear.JADE, "gold": Star500Gear.GOLD_LIGHT,
	}


## The cloth of the set: pearl white with a breath of the class's own colour.
static func cloth(cls: String) -> Color:
	return Color("fff1cf").lerp(SetGearData.palette(cls).cloth, 0.22)


## "heaven_<kind>_<class>": a held weapon or off-hand (shield, book, tome, dagger).
static func build(look: String) -> Node3D:
	# The Muay Thai fighter's knuckle dusters are drawn by HandWraps for every look kind.
	if HandWraps.is_look(look):
		return HandWraps.build(look)
	var bits := look.split("_")
	var kind := String(bits[1]) if bits.size() >= 3 else "sword"
	var cls := String(bits[2]) if bits.size() >= 3 else "warrior"
	var root := Node3D.new()
	root.name = look
	if not StarGearArt._cache.has(look):
		var b := StarGearArt._builder()
		var p := palette(cls)
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
		SetGearArt._weapon_extras(b, p, kind, cls)
		_heaven_extras(b, p, kind)
		StarGearArt._store(look, b)
	StarGearArt._attach(root, look)
	if kind == "greatshield": root.scale = Vector3.ONE * 1.55
	if kind == "dagger": root.scale = Vector3.ONE * 0.62
	if kind == "lute": root.scale = Vector3.ONE * float(WeaponKit.MODELS.lute.scale) / 1.5
	root.set_meta("star_gear", true)
	root.set_meta("set_gear", true)
	root.set_meta("star500", true)
	root.set_meta("weapon_kind", kind)
	return root


## part: chest | pauldron | belt | helm | boots | ring | amulet (ChibiGear bone frames).
static func armor_piece(part: String, cls: String, side := 1.0) -> Node3D:
	var key := "heavenwear_%s_%s_%d" % [part, cls, int(side)]
	var root := Node3D.new()
	root.name = "Heaven_" + part
	if not StarGearArt._cache.has(key):
		var b := StarGearArt._builder()
		var p := palette(cls)
		match part:
			"chest":
				StarGearArt._chest(b, p, 3, cls)
				SetGearArt._chest_extras(b, p, cls)
				_chest_heaven(b, p)
			"pauldron":
				StarGearArt._pauldron(b, p, 3, cls, side)
				SetGearArt._pauldron_extras(b, p, cls, side)
				_pauldron_heaven(b, p, side)
			"belt":
				StarGearArt._belt(b, p, 3, cls)
				SetGearArt._belt_extras(b, p, cls)
				_belt_heaven(b, p)
			"helm":
				StarGearArt._helm(b, p, 3, cls)
				SetGearArt._helm_extras(b, p, cls)
				_helm_heaven(b, p, cls)
			"boots":
				StarGearArt._boots(b, p, 3, cls)
				SetGearArt._boots_extras(b, p, cls)
				_boots_heaven(b, p)
			"ring":
				SetGearArt._ring(b, p, cls)
				StarGearArt._ring_at(b, Vector3(0, 0.05, -0.004), 0.016, 0.0025, p.gold, Vector3(10, 0, 0), true)
			"amulet":
				StarGearArt._amulet(b, p, 3, cls)
				SetGearArt._amulet_extras(b, p, cls)
				_amulet_heaven(b, p)
		StarGearArt._store(key, b)
	StarGearArt._attach(root, key)
	root.set_meta("set_gear", true)
	root.set_meta("star500", true)
	return root


## The inventory icon model of a ★500 look (ItemLook.build_icon_node).
static func build_icon_node(look: String) -> Node3D:
	var bits := look.split("_")
	var kind := String(bits[1]) if bits.size() >= 3 else "sword"
	var cls := String(bits[2]) if bits.size() >= 3 else "warrior"
	if kind == "wings":
		return Star500WingArt.build_icon_node(cls)
	var root := Node3D.new()
	if kind in SetGearArt.HELD:
		root.add_child(build(look))
		root.rotation_degrees.z = -27.0 if kind not in ["bow", "shield", "greatshield", "book", "tome"] else -12.0
		if kind == HandWraps.KIND:
			root.rotation_degrees = HandWraps.ICON_ROTATION
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
		var boot_key := "heavenicon_boots_%s" % cls
		if not StarGearArt._cache.has(boot_key):
			var b := StarGearArt._builder()
			var p := palette(cls)
			StarGearArt._boots(b, p, 3, cls)
			SetGearArt._boots_extras(b, p, cls)
			_boots_heaven(b, p)
			StarGearArt._part(b, MeshKit.box(), p.cloth, Vector3(0, -0.07, 0), Vector3(0.105, 0.16, 0.11))
			StarGearArt._part(b, MeshKit.box(), p.dark, Vector3(0, -0.159, 0.047), Vector3(0.112, 0.031, 0.21))
			StarGearArt._part(b, MeshKit.box(), p.metal, Vector3(0, -0.132, 0.078), Vector3(0.108, 0.038, 0.13))
			StarGearArt._line(b, [Vector3(-0.056, -0.142, 0.15), Vector3(0, -0.12, 0.158), Vector3(0.056, -0.142, 0.15)], 0.006, p.gold, true)
			StarGearArt._store(boot_key, b)
		StarGearArt._attach(root, boot_key)
		root.rotation_degrees = Vector3(-12, -32, 0)
	else:
		root.add_child(armor_piece(kind, cls))
	root.scale = Vector3.ONE * 5.0
	return root


# --- Shared ornaments ---------------------------------------------------------

## A wing of [param n] pearl feathers fanning from [param at] out to [param side]
## (XY plane, facing +Z): long flight feathers with gold shafts of light over a row
## of short gold coverts. [param s] is the longest feather.
static func _wing(b: Dictionary, p: Dictionary, at: Vector3, side: float, s: float, n := 5, z := 0.0) -> void:
	for k in n:
		var f := float(k) / float(maxi(1, n - 1))
		# From the leading feather (up and out) to the trailing one (out and down).
		var a := lerpf(0.55, 1.75, f)
		var length := s * lerpf(1.0, 0.62, f)
		var dir := Vector3(side * sin(a), cos(a), 0.0)
		var centre := at + dir * length * 0.5 + Vector3(0, 0, z - 0.004 * k)
		StarGearArt._feather(b, centre, length, s * 0.26, -side * a, p.edge)
		StarGearArt._line(b, [at + dir * length * 0.12 + Vector3(0, 0, z + 0.006), at + dir * length * 0.86 + Vector3(0, 0, z + 0.006)], s * 0.012, p.gold, true)
	for k in maxi(2, n - 2):
		var f := float(k) / float(maxi(1, n - 3))
		var a := lerpf(0.75, 1.5, f)
		var length := s * 0.42
		var dir := Vector3(side * sin(a), cos(a), 0.0)
		StarGearArt._feather(b, at + dir * length * 0.45 + Vector3(0, 0, z + 0.012), length, s * 0.2, -side * a, p.metal)


## A sunburst of [param n] rays round [param at] facing +Z, from [param r0] out.
static func _rays(b: Dictionary, p: Dictionary, at: Vector3, r0: float, length: float, n := 16, thick := 0.0) -> void:
	var w := thick if thick > 0.0 else length * 0.09
	for k in n:
		var a := TAU * k / float(n)
		var long := k % 2 == 0
		var l := length * (1.0 if long else 0.6)
		var dir := Vector3(sin(a), cos(a), 0)
		StarGearArt._shape(b, [Vector2(-w, 0), Vector2(0, l), Vector2(w, 0), Vector2(0, -w * 0.6)], at + dir * r0, w * 0.4, p.gold if long else p.edge, long, -a)


# --- Weapons -------------------------------------------------------------------

static func _heaven_extras(b: Dictionary, p: Dictionary, kind: String) -> void:
	var head: Vector3 = SetGearArt.HEADS.get(kind, SetGearArt.HEADS.sword)[0]
	var r: float = SetGearArt.HEADS.get(kind, SetGearArt.HEADS.sword)[1]
	var shield := kind in ["greatshield", "shield"]
	var behind := head + Vector3(0, 0, 0.03 if shield else -0.06)
	# The sunburst behind the rune halo, and a tilted jade orbit round the head.
	if kind not in ["book", "tome", "lute"]:
		_rays(b, p, behind, r * 1.22, r * 0.5, 16)
		StarGearArt._ring_at(b, head, r * 1.08, r * 0.035, p.jade, Vector3(72, 0, 24), true)
	else:
		_rays(b, p, behind + Vector3(0, 0, -0.04), r * 0.9, r * 0.35, 12)
	# A jade tear floating above the tip.
	if kind not in ["bow", "lute", "book", "tome"] and not shield:
		StarGearArt._shape(b, [Vector2(0, r * 0.22), Vector2(r * 0.09, 0), Vector2(0, -r * 0.12), Vector2(-r * 0.09, 0)], head + Vector3(0, r * 1.62, 0), r * 0.05, p.jade, true)
		StarGearArt._ring_at(b, head + Vector3(0, r * 1.62, 0), r * 0.16, r * 0.025, p.gold, Vector3(90, 0, 0), true)
	# The pearl wings at the guard.
	var at: Vector3 = GUARD.get(kind, GUARD.sword)[0]
	var s: float = GUARD.get(kind, GUARD.sword)[1]
	match kind:
		"bow":
			# Wings sweeping back from the grip, both limbs.
			for up in [-1.0, 1.0]:
				_wing(b, p, at + Vector3(0, up * 0.12, 0), -1.0, s, 4)
		"greatshield", "shield":
			for side in [-1.0, 1.0]:
				_wing(b, p, at + Vector3(side * 0.3, 0.05, -0.02), side, s, 5)
		_:
			for side in [-1.0, 1.0]:
				_wing(b, p, at + Vector3(side * 0.04, 0, 0), side, s, 5 if s > 0.4 else 4)
	if kind == "sword":
		# A second, pearl-gold edge of light down the blade.
		StarGearArt._line(b, [Vector3(0, 0.46, 0.09), Vector3(0, 1.8, 0.06), Vector3(0, 2.2, 0.03)], 0.01, p.gold, true)


# --- Worn pieces (ChibiGear bone frames) -------------------------------------

static func _chest_heaven(b: Dictionary, p: Dictionary) -> void:
	# A gold collar, a jade lotus round the sigil and small pearl wings on the back.
	StarGearArt._line(b, [Vector3(-0.085, 0.096, 0.07), Vector3(-0.04, 0.078, 0.108), Vector3(0, 0.072, 0.114), Vector3(0.04, 0.078, 0.108), Vector3(0.085, 0.096, 0.07)], 0.006, p.metal)
	for k in 8:
		var a := TAU * k / 8.0
		StarGearArt._feather(b, Vector3(sin(a) * 0.058, cos(a) * 0.058, 0.13), 0.03, 0.016, -a, p.jade if k % 2 == 0 else p.gold, true)
	for side in [-1.0, 1.0]:
		_wing(b, p, Vector3(side * 0.03, 0.06, -0.13), side, 0.13, 4, 0.0)


static func _pauldron_heaven(b: Dictionary, p: Dictionary, side: float) -> void:
	# A pearl feather mantle standing up off the shoulder, gold-shafted.
	for k in 4:
		var a := 0.15 + k * 0.32
		var length := 0.11 - k * 0.012
		var dir := Vector3(side * sin(a), cos(a), 0)
		StarGearArt._feather(b, Vector3(side * 0.03, 0.05, -0.03 - k * 0.006) + dir * length * 0.5, length, 0.032, -side * a, p.edge)
		StarGearArt._line(b, [Vector3(side * 0.03, 0.05, -0.022 - k * 0.006) + dir * length * 0.1, Vector3(side * 0.03, 0.05, -0.022 - k * 0.006) + dir * length * 0.85], 0.0025, p.gold, true)
	StarGearArt._gem(b, Vector3(side * 0.02, 0.03, 0.068), Vector3(0.02, 0.03, 0.008), {"gem": p.jade})


static func _belt_heaven(b: Dictionary, p: Dictionary) -> void:
	for side in [-1.0, 1.0]:
		StarGearArt._feather(b, Vector3(side * 0.04, -0.02, 0.128), 0.11, 0.035, side * -0.08, p.edge)
	StarGearArt._gem(b, Vector3(0, 0.087, 0.145), Vector3(0.026, 0.03, 0.008), {"gem": p.jade})


static func _helm_heaven(b: Dictionary, p: Dictionary, cls: String) -> void:
	# A floating gold halo over the head, rayed, and pearl wings at the temples.
	var top := Vector3(0, 0.54 + (0.08 if cls == "mage" else 0.0), -0.03)
	StarGearArt._ring_at(b, top, 0.15, 0.012, p.gold, Vector3(-12, 0, 0), true)
	StarGearArt._ring_at(b, top, 0.12, 0.006, p.jade, Vector3(-12, 0, 0), true)
	for k in 12:
		var a := TAU * k / 12.0
		var dir := Vector3(sin(a), 0, cos(a))
		StarGearArt._part(b, MeshKit.box(), p.gold if k % 2 == 0 else p.edge, top + dir * 0.17 + Vector3(0, -dir.z * 0.035, 0), Vector3(0.008, 0.008, 0.035 if k % 2 == 0 else 0.022), Vector3(-12, rad_to_deg(a), 0), k % 2 == 0)
	if cls in ["bard", "archer"]:
		return
	for side in [-1.0, 1.0]:
		for k in 3:
			var a := 0.5 + k * 0.38
			var length := 0.13 - k * 0.022
			var dir := Vector3(side * sin(a), cos(a), -0.35).normalized()
			StarGearArt._feather(b, Vector3(side * 0.19, 0.24, -0.04 - k * 0.01) + dir * length * 0.5, length, 0.034, -side * a, p.edge)


static func _boots_heaven(b: Dictionary, p: Dictionary) -> void:
	for side in [-1.0, 1.0]:
		for k in 3:
			var a := 0.65 + k * 0.33
			var length := 0.075 - k * 0.012
			var dir := Vector3(side * sin(a), cos(a), 0)
			StarGearArt._feather(b, Vector3(side * 0.066, 0.0, -0.02 - k * 0.005) + dir * length * 0.5, length, 0.022, -side * a, p.edge)
	StarGearArt._ring_at(b, Vector3(0, 0.012, 0), 0.071, 0.005, p.gold, Vector3.ZERO, true)


static func _amulet_heaven(b: Dictionary, p: Dictionary) -> void:
	var center := Vector3(0, -0.018, 0.12)
	_rays(b, p, center, 0.04, 0.02, 12, 0.004)


# --- The celestial aura ----------------------------------------------------------

## The ★500 set's aura at the hero's feet (visual space): a lotus of pearl petals in
## a gold sunburst round two rune rings (gold and the class's accent), and rising gold
## motes unless [param light] (other players, the lowest quality). The caller frees it.
static func aura(cls: String, light := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Star500Aura"
	root.set_meta("set_aura", cls)
	var key := "heavenaura_" + cls
	if not StarGearArt._cache.has(key):
		var b := StarGearArt._builder()
		var p := palette(cls)
		StarGearArt._ring_at(b, Vector3.ZERO, 0.95, 0.03, p.gold, Vector3.ZERO, true)
		StarGearArt._ring_at(b, Vector3.ZERO, 0.78, 0.018, p.glow, Vector3.ZERO, true)
		StarGearArt._ring_at(b, Vector3.ZERO, 0.55, 0.012, p.jade, Vector3.ZERO, true)
		for k in 8:
			var a := TAU * k / 8.0
			StarGearArt._part(b, MeshKit.sphere_low(), p.edge, Vector3(sin(a) * 0.66, 0.0, cos(a) * 0.66), Vector3(0.11, 0.014, 0.26), Vector3(0, rad_to_deg(a), 0), true)
			StarGearArt._part(b, MeshKit.sphere_low(), p.gold, Vector3(sin(a + PI / 8.0) * 0.62, 0.0, cos(a + PI / 8.0) * 0.62), Vector3(0.07, 0.012, 0.17), Vector3(0, rad_to_deg(a + PI / 8.0), 0), true)
		for k in 24:
			var a := TAU * k / 24.0
			var long := k % 2 == 0
			StarGearArt._part(b, MeshKit.box(), p.gold if long else p.glow, Vector3(sin(a), 0, cos(a)) * (1.08 if long else 1.03), Vector3(0.028, 0.01, 0.2 if long else 0.1), Vector3(0, rad_to_deg(a), 0), true)
		StarGearArt._store(key, b)
	var ring := Node3D.new()
	ring.name = "Circle"
	ring.position.y = 0.035
	root.add_child(ring)
	StarGearArt._attach(ring, key)
	if not light and GameSettings.quality > 0:
		var motes := CPUParticles3D.new()
		motes.name = "Star500Motes"
		var quad := QuadMesh.new()
		quad.size = Vector2(0.14, 0.14)
		quad.material = LegendWingArt.mote_material()
		motes.mesh = quad
		motes.amount = VfxBudget.count(16)
		motes.lifetime = 2.2
		motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		motes.emission_ring_axis = Vector3.UP
		motes.emission_ring_radius = 0.9
		motes.emission_ring_inner_radius = 0.55
		motes.emission_ring_height = 0.02
		motes.direction = Vector3.UP
		motes.spread = 6.0
		motes.initial_velocity_min = 0.35
		motes.initial_velocity_max = 0.8
		motes.gravity = Vector3.ZERO
		motes.local_coords = false
		motes.color_ramp = VfxKit._fade_ramp()
		motes.position.y = 0.05
		motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(motes)
	return root
