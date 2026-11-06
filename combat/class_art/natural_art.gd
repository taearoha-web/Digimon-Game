class_name NaturalArt
extends SculptureArt
## SculptureArt with natural motion and a layer hierarchy, for the caster classes'
## signature art (CasterArt: the Mage, Priest and Summoner; BardSkillArt).
##
## Extra style keys, all evaluated on the layer's own clock without allocating:
##   toss (Vector3, m/s) + gravity (m/s²): a ballistic arc (debris, feathers, sparks);
##   drag: how fast toss bleeds off (air resistance, 0 = none);
##   sway (m) + sway_rate (Hz-ish): a lazy side-to-side drift (feathers, leaves, notes);
##   bob (m): a soft vertical bob (notes riding the melody);
##   flutter (rad): a rocking tilt about Z (feathers, leaves);
##   overshoot: the grow-in overshoots its size and settles (eased "back" curve);
##   pulse: a breathing scale (rad/s of the breath);
##   tier: 0 core (always drawn), 1 secondary, 2 debris / embellishment.
## Low quality and memory pressure 2 keep the core only; medium quality and pressure 1
## drop the debris and halve the counts (count()).

const TIER_CORE := 0
const TIER_MID := 1
const TIER_DEBRIS := 2


## The deepest tier drawn now: high quality 2, medium or memory pressure 1 → 1,
## low quality or pressure 2 → 0 (core only).
static func depth() -> int:
	var q := VfxBudget.quality()
	var p := MemoryGuard.pressure
	if q == 0 or p >= 2:
		return TIER_CORE
	if q == 1 or p == 1:
		return TIER_MID
	return TIER_DEBRIS


## A count of repeated pieces (flames, feathers, leaves ...) for the current budget:
## the full count at high quality, half under pressure 1 or medium quality, one at low.
static func count(full: int) -> int:
	match depth():
		TIER_CORE: return mini(full, 1)
		TIER_MID: return maxi(1, full / 2)
	return full


func layer(kind: String, glow: bool, c: Array, at: Vector3, size: Vector3, angles := Vector3.ZERO, start := 0.0, seconds := 1.0, style := {}) -> void:
	if int(style.get("tier", TIER_CORE)) > depth():
		return
	super.layer(kind, glow, c, at, size, angles, start, seconds, style)


func _draw() -> void:
	super._draw()
	for data in layers:
		var node: MeshInstance3D = data.node
		if not node.visible:
			continue
		var style: Dictionary = data.style
		var local := age - float(data.start)
		if style.has("toss") or style.has("gravity"):
			var v: Vector3 = style.get("toss", Vector3.ZERO)
			var drag := float(style.get("drag", 0.0))
			# Distance under linear drag: v (1 - e^-kt) / k; plain v t without drag.
			var reach := local if drag <= 0.0 else (1.0 - exp(-drag * local)) / drag
			var fall := 0.5 * float(style.get("gravity", 0.0)) * local * local
			node.position += v * reach - Vector3(0, fall, 0)
			var floor_y := float(style.get("floor", -INF))
			if node.position.y < floor_y:
				node.position.y = floor_y
		if style.has("sway"):
			var rate := float(style.get("sway_rate", 1.6))
			var phase := float(style.get("phase", 0.0))
			var amp := float(style.sway)
			node.position.x += sin(local * rate * TAU + phase) * amp
			node.position.z += sin(local * rate * TAU * 0.71 + phase * 1.3) * amp * 0.6
		if style.has("bob"):
			node.position.y += sin(local * 5.2 + float(style.get("phase", 0.0))) * float(style.bob)
		if style.has("flutter"):
			node.rotation.z += sin(local * 6.3 + float(style.get("phase", 0.0))) * float(style.flutter)
		if bool(style.get("overshoot", false)):
			var t := clampf(local / float(data.seconds), 0.0, 1.0)
			var k := minf(t * float(style.get("grow", 4.0)), 1.0)
			# Back-out ease: past 1 by ~10% and settling, applied over the cubic grow-in.
			var back := 1.0 + 2.70158 * pow(k - 1.0, 3.0) + 1.70158 * pow(k - 1.0, 2.0)
			node.scale = (data.size as Vector3) * maxf(0.004, lerpf(float(style.get("initial", 0.55)), 1.0, back))
		if style.has("pulse"):
			node.scale *= 1.0 + 0.06 * sin(local * float(style.pulse))
		node.scale = node.scale.max(Vector3.ONE * 0.002)
