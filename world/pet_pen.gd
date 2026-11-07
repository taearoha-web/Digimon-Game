class_name PetPen
extends Node3D
## The pet pen (คอกสัตว์เลี้ยง) in the village's training district: a low wooden rail
## fence round a patch of grass with a gate on the street side, a sign, a hay pile and a
## water trough, and PEN_PETS of the three pets (PetData) wandering inside. The pet
## keeper (ผู้ดูแลสัตว์เลี้ยง, role "pet", Zone._villagers) stands at the gate.
##
## The pen's pets are cheap on purpose: no AI, no physics, no health bar; one loop here
## walks each to a random spot inside the fence, idles, then picks another. They are
## smaller than the pets that fight, join the zone's animation LOD ("anim_lod": far from
## the camera their skeletons stop) and are not drawn past VIEW_RANGE.

## Middle of the pen and its half size (x, z) in village coordinates.
const CENTER := Vector3(-63.0, 0.0, 8.5)
const HALF := Vector2(5.5, 4.0)
## The gate: a gap in the east fence (toward the street and the keeper).
const GATE_HALF := 1.1
## Where the keeper stands (outside the gate) and the spot it faces.
const KEEPER := CENTER + Vector3(HALF.x + 2.0, 0.0, 0.0)
const KEEPER_FACE := CENTER + Vector3(HALF.x + 20.0, 0.0, 0.0)
## How many pets wander in the pen, in this order of kinds (4 fire, 3 water, 3 earth).
const KINDS: Array[String] = ["fire", "water", "earth", "fire", "water", "earth", "fire", "earth", "water", "fire"]
const PEN_PETS := 10
## The pen's pets stand at this share of a fighting pet's height.
const SIZE := 0.75
const WALK_SPEED := 1.1
const VIEW_RANGE := 46.0

var critters: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


## Builds the pen into [param zone] (the village) and returns it. [param clear] gets the
## circle random rocks and trees keep off.
static func build(zone: Node3D, rng: RandomNumberGenerator, clear: Array[Vector3] = []) -> PetPen:
	var pen := PetPen.new()
	pen.name = "PetPen"
	pen.position = CENTER
	pen._rng.seed = rng.randi()
	zone.add_child(pen)
	pen._build_fence()
	pen._spawn_pets()
	clear.append(Vector3(CENTER.x, CENTER.z, maxf(HALF.x, HALF.y) + 2.0))
	return pen


## The pen's footprint in village x / z, with [param margin] metres more on each side.
static func footprint(margin := 0.0) -> Rect2:
	return Rect2(CENTER.x - HALF.x - margin, CENTER.z - HALF.y - margin, (HALF.x + margin) * 2.0, (HALF.y + margin) * 2.0)


func _build_fence() -> void:
	var b := JapanKit.Batch.new()
	var wood := Color("8a6a40")
	var dark := Color("5e4528")
	# Grass inside the fence (a thin slab over the paving) and a ring of soil at its foot.
	b.box(Vector3(0, 0.03, 0), Vector3(HALF.x * 2.0 - 0.2, 0.06, HALF.y * 2.0 - 0.2), Color("7fb35a"))
	b.box(Vector3(0, 0.02, 0), Vector3(HALF.x * 2.0 + 0.6, 0.04, HALF.y * 2.0 + 0.6), Color("8a7458"))
	var corners := [Vector3(-HALF.x, 0, -HALF.y), Vector3(HALF.x, 0, -HALF.y), Vector3(HALF.x, 0, HALF.y), Vector3(-HALF.x, 0, HALF.y)]
	for i in 4:
		var from: Vector3 = corners[i]
		var to: Vector3 = corners[(i + 1) % 4]
		# The east side (from (x, -z) to (x, +z)) leaves the gate open in its middle.
		var runs: Array = [[from, to]]
		if i == 1:
			runs = [[from, Vector3(HALF.x, 0, -GATE_HALF)], [Vector3(HALF.x, 0, GATE_HALF), to]]
		for run in runs:
			_rail(b, run[0], run[1], wood, dark)
	# Gate posts with a little roof beam, the hay pile and the water trough.
	for s in [-1.0, 1.0]:
		b.box(Vector3(HALF.x, 0.85, s * GATE_HALF), Vector3(0.22, 1.7, 0.22), dark)
	b.box(Vector3(HALF.x, 1.75, 0), Vector3(0.18, 0.16, GATE_HALF * 2.0 + 0.6), wood)
	b.ball(Vector3(-HALF.x + 1.1, 0.35, -HALF.y + 1.0), Vector3(0.9, 0.55, 0.75), Color("e6c65a"))
	b.ball(Vector3(-HALF.x + 1.9, 0.25, -HALF.y + 0.9), Vector3(0.6, 0.4, 0.5), Color("d8b44a"))
	b.box(Vector3(-HALF.x + 1.0, 0.25, HALF.y - 0.9), Vector3(1.6, 0.5, 0.6), wood)
	b.box(Vector3(-HALF.x + 1.0, 0.47, HALF.y - 0.9), Vector3(1.4, 0.06, 0.4), Color("6ab8e0"))
	b.commit(self, "PenFence")
	# Colliders along the rails (the gate stays open), so heroes walk round or through it.
	for i in 4:
		var from: Vector3 = corners[i]
		var to: Vector3 = corners[(i + 1) % 4]
		if i == 1:
			_wall(from, Vector3(HALF.x, 0, -GATE_HALF))
			_wall(Vector3(HALF.x, 0, GATE_HALF), to)
		else:
			_wall(from, to)
	var sign := Label3D.new()
	sign.name = "PenSign"
	sign.text = "คอกสัตว์เลี้ยง"
	sign.font_size = 64
	sign.pixel_size = 0.006
	sign.outline_size = 10
	sign.modulate = Color("fff6e0")
	sign.outline_modulate = Color("3a2418")
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sign.position = Vector3(-HALF.x - 0.2, 2.1, 0)
	sign.visibility_range_end = 42.0
	add_child(sign)


func _rail(b: JapanKit.Batch, from: Vector3, to: Vector3, wood: Color, dark: Color) -> void:
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var dir := (to - from) / length
	var yaw := rad_to_deg(atan2(dir.x, dir.z))
	var posts := maxi(1, int(ceil(length / 1.5)))
	for k in posts + 1:
		var p := from + dir * length * float(k) / float(posts)
		b.box(p + Vector3(0, 0.5, 0), Vector3(0.16, 1.0, 0.16), dark)
	for h in [0.4, 0.8]:
		b.box((from + to) * 0.5 + Vector3(0, h, 0), Vector3(0.08, 0.1, length), wood, Vector3(0, yaw, 0))


func _wall(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var yaw := atan2(to.x - from.x, to.z - from.z)
	JapanKit.collider(self, (from + to) * 0.5 + Vector3(0, 0.6, 0), Vector3(0.3, 1.2, length), yaw)


func _spawn_pets() -> void:
	for i in PEN_PETS:
		var id: String = KINDS[i % KINDS.size()]
		var data := PetData.get_pet(id)
		var body := Node3D.new()
		body.name = "PenPet_%s_%d" % [id, i]
		add_child(body)
		body.position = _random_spot()
		body.rotation.y = _rng.randf() * TAU
		var visual := MonsterVisual.new()
		body.add_child(visual)
		var skin: Texture2D = load(String(data.skin)) as Texture2D if String(data.get("skin", "")) != "" else null
		visual.setup(String(data.model), float(data.height) * SIZE, 0.0, data.tint, skin)
		visual.add_to_group("anim_lod")
		for mi in visual.find_children("*", "MeshInstance3D", true, false):
			(mi as GeometryInstance3D).visibility_range_end = VIEW_RANGE
			(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var shadow := MeshKit.blob_shadow(body, 0.42)
		shadow.visibility_range_end = VIEW_RANGE
		critters.append({"id": id, "body": body, "visual": visual, "goal": body.position, "wait": _rng.randf_range(0.2, 3.0)})


## A spot inside the fence, clear of the posts.
func _random_spot() -> Vector3:
	return Vector3(_rng.randf_range(-HALF.x + 0.9, HALF.x - 0.9), 0.0, _rng.randf_range(-HALF.y + 0.9, HALF.y - 0.9))


func _process(delta: float) -> void:
	for c in critters:
		var body: Node3D = c.body
		var visual: MonsterVisual = c.visual
		if float(c.wait) > 0.0:
			c.wait = float(c.wait) - delta
			visual.play("idle")
			if float(c.wait) <= 0.0:
				c.goal = _random_spot()
			continue
		var to: Vector3 = c.goal - body.position
		to.y = 0.0
		if to.length() < 0.15:
			c.wait = _rng.randf_range(1.5, 5.0)
			continue
		body.position += to.normalized() * minf(to.length(), WALK_SPEED * delta)
		body.rotation.y = lerp_angle(body.rotation.y, atan2(to.x, to.z), 1.0 - exp(-8.0 * delta))
		visual.play("walk", 0.8)


## How many of the pen's pets are of kind [param id] (tests).
func count_of(id: String) -> int:
	return critters.filter(func(c): return String(c.id) == id).size()
