class_name BardSkillArt
extends SculptureArt
## The Bard's art: every skill of the line (25) and its four star skills get their
## own layered composition of music made visible. A rosette (the lute's sound hole)
## turns under the Bard, notes and beamed pairs fly, rain and circle, staff lines
## ring the caster and crack under the foe, sound rings quaver out, a spectral lute
## and a lyre of light rise in the sky, and the great songs raise a concert stage
## with curtains, spotlights and a choir of light spirits. Status marks share one
## language: a gold fermata over the stunned, a cracked staff for armour broken,
## blue tear-notes for strength sapped. Built on SculptureArt (shadow_ink for velvet
## curtains, drum heads and cracked staves; shadow_glow for the light); a few pieces
## are borrowed (LordSkillArt bolt/pillar/shock/banner, ShadowSkillArt vortex/moon).
## Backdrops (the lute, the lyre, the clef, the choir, banners, curtains) stand on
## the side of the caster away from the camera, so the face stays clear.
## Cosmetic only: it never selects victims, deals damage or changes timing.

const KINDS := "note notes treble tear_note heart fermata spirit lyre lute_ghost rosette rosette_ink soundwave soundwave_ink stave score drum_ring cracked_stave curtain spotlight stage pips2 pips3 pips4 pips5"
const LORD_KINDS := ["bolt", "pillar", "shock", "banner"]
const SHADOW_KINDS := ["vortex", "moon"]
## [primary, accent, shade] palettes.
## (The primaries run a shade deeper than the icon and recipe palettes: additive light on a
## sunny field washes a pastel to white.)
const MELODY := [Color("ff6ab8"), Color("fff0f8"), Color("2a0a20")]
const GILT := [Color("ffbf3a"), Color("fff6d6"), Color("2a1606")]
const DISCORD := [Color("9a5cff"), Color("efe2ff"), Color("1a0830")]
const LAMENT := [Color("5f94ff"), Color("eaf2ff"), Color("0a1430")]
const SERENE := [Color("4fd2f2"), Color("eefdff"), Color("06222e")]
const TEMPEST := [Color("a57bff"), Color("fff6ff"), Color("140a36")]
const DREAM := [Color("7c9cff"), Color("f4f2ff"), Color("121636")]
const STARLIGHT := [Color("ffc24a"), Color("fff4d8"), Color("2a1430")]
const COSMOS := [Color("a678ff"), Color("fff0ff"), Color("1a0a3a")]
## By id, not by colour (robust to retuned skill colours).
const PALETTE_OF := {
	"staccato_shot": "melody", "valor_march": "melody", "resonance": "melody", "sorrow_note": "lament",
	"discord": "discord", "iron_ballad": "gilt", "triad_chord": "melody", "echo_chain": "serene",
	"war_drum": "gilt", "heartstring": "melody", "virtuoso": "melody", "heroic_anthem": "melody",
	"slumber_lullaby": "dream", "lament": "lament", "cascade": "melody", "sanctuary_serenade": "serene",
	"fortissimo": "melody", "shattering_rhapsody": "tempest", "maestro_fervor": "gilt",
	"grand_dissonance": "discord", "aria_of_ruin": "melody", "eternal_echo": "serene",
	"thunder_crescendo": "tempest", "hymn_of_legends": "gilt", "grand_finale": "melody"}
const STAR_PALETTES := {"starlight_overture": "starlight", "heartbreak_sonata": "melody", "celestial_stage": "gilt", "cosmic_encore": "cosmos"}
const CONTACT_GAP_MS := 90
## The rosette in the caster's facing frame (hero-local): where notes leave the lute.
const LUTE := Vector3(-0.22, 0.95, 0.38)
## Body height of a struck monster.
const HIT := Vector3(0, 1.0, 0)
## How hot each glowing sculpture burns (a scale on COLOR.r, the white core): the
## bodies keep their palette colour and only small highlights reach the accent, so a
## field of rings over a sunny meadow reads rose, gold or violet instead of white.
const TONE := {"note": 0.45, "notes": 0.45, "treble": 0.6, "tear_note": 0.5, "heart": 0.65, "fermata": 0.75,
	"spirit": 0.6, "lyre": 0.36, "lute_ghost": 0.62, "rosette": 0.42, "soundwave": 0.45, "stave": 0.55,
	"score": 0.55, "spotlight": 0.45, "stage": 0.5, "pips": 0.85}
## Notes, beamed pairs and tears are drawn this much larger than their authored size.
const NOTE_SCALE := 1.4
static var _meshes: Dictionary = {}
static var _last_contact: Dictionary = {}
## Away from the camera in the root's frame (backdrops go there), its yaw, and the side axis.
var _away := Vector3(0, 0, -1)
var _away_yaw := PI
var _side := Vector3(1, 0, 0)


static func handles(skill: Dictionary) -> bool:
	return not skill.is_empty() and SkillShow.family_of(skill) == "bard"


static func palette(skill: Dictionary) -> Array:
	var id := String(skill.get("id", ""))
	return _named(String(STAR_PALETTES.get(id, PALETTE_OF.get(id, "melody"))))


static func _named(name: String) -> Array:
	match name:
		"gilt": return GILT
		"discord": return DISCORD
		"lament": return LAMENT
		"serene": return SERENE
		"tempest": return TEMPEST
		"dream": return DREAM
		"starlight": return STARLIGHT
		"cosmos": return COSMOS
	return MELODY


static func layer_cap() -> int:
	return int([6, 11, 18][VfxBudget.quality()] * MemoryGuard.effect_scale())


func _sculpture(kind: String) -> ArrayMesh:
	return mesh(kind)


## Every note-shaped sculpture is drawn at [constant NOTE_SCALE] so it reads from the
## gameplay camera. Lace lying on the ground (the rosette, sound rings) is drawn in ink
## in the palette's saturated hue, so it keeps its colour on a sunny field; in the air it
## stays light.
func layer(kind: String, glow: bool, c: Array, at: Vector3, size: Vector3, angles := Vector3.ZERO, start := 0.0, seconds := 1.0, style := {}) -> void:
	if glow and kind in ["rosette", "soundwave"] and absf(angles.x) < 0.3 and absf(angles.z) < 0.3:
		super.layer(kind + "_ink", false, _lace(c), at, size, angles, start, seconds, style)
		return
	if kind == "shock":
		# The borrowed shockwave's bright front is wide at a big radius: a softer, smaller veil.
		size = Vector3(minf(size.x, 6.0), size.y, minf(size.z, 6.0))
		if not style.has("opacity"):
			style = style.merged({"opacity": 0.42})
	if kind == "lyre" and not style.has("opacity"):
		style = style.merged({"opacity": 0.72})
	super.layer(kind, glow, c, at, size * (NOTE_SCALE if kind in ["note", "notes", "tear_note"] else 1.0), angles, start, seconds, style)


## Velvet for curtains and banners: a deep body of the palette's own hue, a light inlay.
static func _velvet(c: Array) -> Array:
	return [c[0], (c[0] as Color).lerp(Color.WHITE, 0.5), (c[0] as Color).darkened(0.62)]


## The lace version of a palette: the inlay is the primary at full saturation.
static func _lace(c: Array) -> Array:
	var p: Color = c[0]
	return [p, Color.from_hsv(p.h, clampf(p.s * 1.3 + 0.2, 0.0, 1.0), p.v), c[2]]


static func warm_geometry() -> void:
	for kind in Array(KINDS.split(" ")) + LORD_KINDS + SHADOW_KINDS:
		mesh(String(kind))


## Draws both materials once, invisibly, so the first cast does not stall on a phone.
static func warm_up(parent: Node3D, at: Vector3) -> void:
	warm_geometry()
	var art := _root(parent, at, "BardArt_Warm")
	art.cap = 2
	art.layer("note", true, MELODY, Vector3.UP, Vector3.ONE * 0.01, Vector3.ZERO, 0.0, 0.3, {"opacity": 0.001})
	art.layer("curtain", false, MELODY, Vector3.UP, Vector3.ONE * 0.01, Vector3.ZERO, 0.0, 0.3, {"opacity": 0.001})


static func _root(parent: Node3D, at: Vector3, label: String, yaw := 0.0) -> BardSkillArt:
	var art := BardSkillArt.new()
	art.name = label
	art.cap = layer_cap()
	parent.add_child(art)
	art.global_position = at
	art.rotation.y = yaw
	art._face_away()
	return art


## Away from the gameplay camera, in this root's frame (the camera is player-steered,
## so "behind the hero" is found at cast time). Without a camera it stays at local -Z.
func _face_away() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera:
		var to_camera := camera.global_position - global_position
		to_camera.y = 0.0
		if to_camera.length_squared() > 0.01:
			_away = global_basis.inverse() * -to_camera.normalized()
			_away.y = 0.0
			_away = _away.normalized() if _away.length_squared() > 0.0001 else Vector3(0, 0, -1)
	_away_yaw = atan2(_away.x, _away.z)
	_side = Vector3(_away.z, 0, -_away.x)


## Bound to the caster's skill generation: a cancelled cast drops the art.
func _bind(visual: HeroVisual) -> void:
	if visual:
		owner_ref = weakref(visual)
		generation = visual.skill_generation


## The skill's star rank (1-5). The hero's ranked skill carries it when SkillRank
## records it; otherwise it is recovered from a ranked field (area, control time,
## buff strength, heal, a fan or chain's extra targets). AI casts are unranked (1).
static func _rank_of(skill: Dictionary) -> int:
	if skill.has("rank"):
		return clampi(int(skill.rank), 1, 5)
	var base := ClassData.find_skill(&"bard", String(skill.get("id", "")))
	if base.is_empty():
		return 1
	if base.has("radius") and float(base.radius) > 0.0:
		return _steps(float(skill.get("radius", base.radius)), float(base.radius), SkillRank.RADIUS_PER_STAR)
	var fx: Dictionary = skill.get("fx", {})
	var was: Dictionary = base.get("fx", {})
	for key in ["stun", "slow"]:
		if was.has(key) and fx.has(key) and float(was[key]) > 0.0:
			return _steps(float(fx[key]), float(was[key]), SkillRank.CONTROL_PER_STAR)
	if was.get("buff") is Dictionary and fx.get("buff") is Dictionary:
		for key in ["atk", "def"]:
			if (was.buff as Dictionary).has(key) and float(was.buff[key]) > 0.0:
				return _steps(float(fx.buff.get(key, was.buff[key])), float(was.buff[key]), SkillRank.BUFF_PER_STAR)
	if String(base.get("shape", "")) in ["chain", "fan"]:
		var extra := int(skill.get("hits", base.get("hits", 1))) - int(base.get("hits", 1))
		return 1 if extra <= 0 else (3 if extra == 1 else 5)
	return 1


static func _steps(now: float, was: float, per: float) -> int:
	return clampi(1 + int(round((now / maxf(was, 0.0001) - 1.0) / per)), 1, 5)


# ---------------------------------------------------------------------------
# Entry points
# ---------------------------------------------------------------------------

## Wind-up: the lute is tuned. The rosette turns at the Bard's feet and a note rises
## off the strings; from Lv.20 a staff ring rides the hips, each ★ above the first
## adds a gold star at the feet, from Lv.40 a clef rises behind and from Lv.80 (and
## every star skill) the spectral lute stands behind under a spotlight. The aria
## hangs its note over the target, the finale raises its stage round the pack and the
## encore turns a cosmic staff over the field. Bound to the caster's skill generation.
static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, aim: Vector3, duration: float, visual: HeroVisual = null) -> void:
	if not handles(skill) or not _alive(parent) or duration < 0.12 or not VfxBudget.can_decorate(4 + RESERVE):
		return
	var id := String(skill.get("id", ""))
	var c := palette(skill)
	var level := int(skill.get("level", 1))
	var is_star := skill.has("star")
	var rank := _rank_of(skill)
	var time := maxf(duration, 0.15)
	var art := _root(parent, origin, "BardArt_Windup_" + id, _yaw(origin, aim))
	art._bind(visual)
	art.layer("rosette", true, c, Vector3(0, 0.04, 0), Vector3.ONE * (1.15 + 0.1 * float(mini(level / 20, 5))), Vector3.ZERO, 0.0, time + 0.08, {"initial": 0.2, "grow": 1.3, "spin": 1.4, "decay": 0.85, "fade_in": 0.3})
	art.layer("note", true, c, LUTE, Vector3.ONE * 0.3, Vector3.ZERO, 0.0, time + 0.05, {"initial": 0.2, "grow": 2.0, "travel": Vector3(0, 0.3, 0.1), "face_camera": true, "roll": 1.5, "fade_in": 0.25, "decay": 0.85})
	if level >= 20 or is_star:
		art.layer("stave", true, c, Vector3(0, 0.55, 0), Vector3(1.05, 0.9, 1.05), Vector3.ZERO, 0.0, time + 0.08, {"initial": 0.4, "grow": 1.5, "spin": 1.2, "fade_in": 0.3, "decay": 0.85, "opacity": 0.7})
	if rank >= 2:
		art.layer("pips%d" % rank, true, GILT, Vector3(0, 0.06, 0), Vector3.ONE, Vector3.ZERO, 0.0, time + 0.1, {"initial": 0.3, "grow": 2.0, "spin": -2.4, "fade_in": 0.2})
	if level >= 40 or is_star:
		art.layer("treble", true, c, art._away * 0.55 + Vector3.UP * 0.8, Vector3.ONE * 0.75, Vector3.ZERO, 0.0, time + 0.1, {"initial": 0.3, "grow": 1.4, "travel": Vector3(0, 0.35, 0), "face_camera": true, "fade_in": 0.3, "decay": 0.85, "opacity": 0.8})
	if level >= 80 or is_star:
		art.layer("lute_ghost", true, c, art._away * 0.85 + Vector3.UP * 0.6, Vector3.ONE * 1.35, Vector3.ZERO, 0.0, time + 0.12, {"initial": 0.3, "grow": 1.2, "travel": Vector3(0, 0.45, 0), "face_camera": true, "fade_in": 0.35, "decay": 0.85, "opacity": 0.55})
		art.layer("spotlight", true, GILT, Vector3.ZERO, Vector3(1.1, 4.4, 1.1), Vector3.ZERO, 0.0, time + 0.1, {"initial": 0.5, "grow": 2.0, "fade_in": 0.4, "decay": 0.8, "opacity": 0.32})
	var spot := Vector3(aim.x, origin.y, aim.z)
	match id:
		"aria_of_ruin":
			# A great note hangs high over the foe in a falling spotlight, then drops on the release.
			var sky := _root(parent, spot, "BardArt_Sky_" + id, _yaw(origin, aim))
			sky._bind(visual)
			sky.layer("spotlight", true, GILT, Vector3.ZERO, Vector3(1.5, 7.5, 1.5), Vector3.ZERO, 0.0, time + 0.3, {"initial": 0.2, "grow": 1.0, "fade_in": 0.5, "opacity": 0.4})
			sky.layer("note", true, c, Vector3(0, 7.0, 0), Vector3.ONE * 2.4, Vector3.ZERO, 0.0, maxf(time - 0.15, 0.1), {"initial": 0.1, "grow": 1.2, "face_camera": true, "fade_in": 0.3, "decay": 0.95})
			sky.layer("note", true, c, Vector3(0, 0.6, 0), Vector3.ONE * 2.4, Vector3.ZERO, maxf(time - 0.18, 0.0), 0.5, {"initial": 1.0, "drop": 6.4, "land": 0.18, "face_camera": true, "decay": 0.6})
		"grand_finale":
			# The concert stage rises round the pack: a disc of light, curtains, spotlights, a clef and a turning staff.
			var r := minf(float(skill.get("radius", 9.5)), 12.5)
			var stage := _root(parent, spot, "BardArt_Stage_" + id, _yaw(origin, aim))
			stage._bind(visual)
			stage._stage(c, Vector3.ZERO, r, 0.0, time + (0.35 if VfxBudget.quality() > 0 else 0.05))
			stage.layer("treble", true, c, stage._away * r * 0.42 + Vector3.UP * 0.3, Vector3.ONE * 2.6, Vector3.ZERO, 0.1, time + 0.3, {"initial": 0.2, "grow": 1.2, "face_camera": true, "fade_in": 0.3, "opacity": 0.8})
			stage.layer("stave", true, GILT, Vector3(0, 5.0, 0), Vector3(r * 0.45, 1.4, r * 0.45), Vector3.ZERO, 0.0, time + 0.35, {"initial": 0.3, "grow": 1.3, "spin": 1.6, "fade_in": 0.3})
		"cosmic_encore":
			var r := clampf(float(skill.get("radius", 7.5)), 3.0, 10.0)
			var sky := _root(parent, spot, "BardArt_Sky_" + id, _yaw(origin, aim))
			sky._bind(visual)
			sky.layer("stave", true, c, Vector3(0, 6.0, 0), Vector3(r * 0.55, 1.4, r * 0.55), Vector3.ZERO, 0.0, time + 0.4, {"initial": 0.3, "grow": 1.5, "spin": 0.8, "fade_in": 0.3})


## Release: the skill's own composition, at the same beat as its damage.
static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, delay := 0.0) -> void:
	if not handles(skill) or not _alive(parent) or skill.has("star") or not VfxBudget.can_decorate(3 + RESERVE):
		return
	var id := String(skill.get("id", ""))
	var shape := String(skill.get("shape", "single"))
	var at := center if shape == "blast" else origin
	var art := _root(parent, Vector3(at.x, origin.y, at.z), "BardArt_" + id, _yaw(origin, center))
	# A crowd of casters (a guild war) keeps each composition to its first six layers.
	var now := Time.get_ticks_msec()
	if SkillShow._recent_shows.filter(func(t: int): return now - t < 1000).size() >= 3:
		art.cap = mini(art.cap, 6)
	var reach := Vector2(center.x - origin.x, center.z - origin.z).length()
	art._compose(id, skill, palette(skill), reach, minf(float(skill.get("radius", 3.0)), 9.5), maxf(delay, 0.0), _rank_of(skill))


## Every hit: a note thrown off the struck foe and a sound ring under it, with the
## status mark the skill brings (cracked staff, tear-note, fermata) or a gold echo.
static func contact(parent: Node3D, skill: Dictionary, at: Vector3) -> void:
	if not handles(skill) or skill.has("star") or not _alive(parent) or not VfxBudget.can_decorate(2 + RESERVE):
		return
	var id := String(skill.get("id", ""))
	var q := VfxBudget.quality()
	var now := Time.get_ticks_msec()
	if now - int(_last_contact.get(id, -100000)) < int(CONTACT_GAP_MS * [2.2, 1.5, 1.0][q]):
		return
	_last_contact[id] = now
	var c := palette(skill)
	var fx: Dictionary = skill.get("fx", {})
	var art := _root(parent, at, "BardArt_Hit_" + id)
	art.cap = mini(art.cap, [2, 3, 3][q])
	var tilt := randf_range(-0.5, 0.5)
	art.layer("note", true, c, Vector3(0, 0.2, 0), Vector3.ONE * 0.42, Vector3.ZERO, 0.0, 0.5, {"initial": 0.5, "travel": Vector3(tilt, 0.75, 0), "roll": tilt * 8.0, "face_camera": true, "decay": 0.6})
	art.layer("soundwave", true, c, Vector3(0, -0.92, 0), Vector3.ONE * 0.75, Vector3.ZERO, 0.0, 0.4, {"initial": 0.2, "grow": 5.0})
	if fx.get("shred") is Array:
		art.layer("cracked_stave", false, DISCORD, Vector3(0, -0.93, 0), Vector3.ONE * 0.6, Vector3(0, randf() * TAU, 0), 0.0, 0.6, {"initial": 0.5, "grow": 6.0})
	elif fx.get("weaken") is Array:
		art.layer("tear_note", true, LAMENT, Vector3(0, 0.9, 0), Vector3.ONE * 0.35, Vector3.ZERO, 0.0, 0.6, {"initial": 0.8, "travel": Vector3(0, -0.9, 0), "face_camera": true})
	elif float(fx.get("stun", 0.0)) >= 1.0:
		art.layer("fermata", true, GILT, Vector3(0, 1.2, 0), Vector3.ONE * 0.45, Vector3.ZERO, 0.0, 0.7, {"initial": 0.3, "grow": 5.0, "face_camera": true})
	elif int(skill.get("level", 1)) >= 60:
		art.layer("note", true, GILT, Vector3(0, 0.3, 0), Vector3.ONE * 0.34, Vector3.ZERO, 0.03, 0.5, {"initial": 0.5, "travel": Vector3(-tilt, 0.7, 0), "roll": -tilt * 8.0, "face_camera": true, "decay": 0.6})


## Star skills: one composition per contact beat of StarSkillSequence. A self star
## skill is rooted at the Bard ([param source]), never at the aimed foe.
static func star(parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> void:
	if not handles(skill) or not _alive(parent) or not VfxBudget.can_decorate(3 + RESERVE):
		return
	var id := String(skill.get("id", ""))
	var at := source if String(skill.get("shape", "")) == "self" else Vector3(point.x, source.y, point.z)
	var art := _root(parent, at, "BardArt_Star_%s_%d" % [id, index], _yaw(source, point))
	var radius := clampf(float(skill.get("radius", 6.0)), 3.0, 10.0)
	art._star(id, skill, palette(skill), index, radius, art.to_local(source))


# ---------------------------------------------------------------------------
# Shared pieces of the compositions
# ---------------------------------------------------------------------------

## A carrier from the lute to [param to] (landing after [param flight]), always facing the camera.
func _carrier(kind: String, c: Array, to: Vector3, start: float, flight: float, size := 0.42, from := LUTE) -> void:
	layer(kind, true, c, from, Vector3.ONE * size, Vector3.ZERO, start, flight + 0.05, {"initial": 0.9, "travel": to - from, "accelerate": true, "face_camera": true, "roll": 2.5, "decay": 0.9})


## The sound hole flares as the strings are struck.
func _flash(c: Array, start: float, size := 0.34) -> void:
	layer("rosette", true, c, LUTE, Vector3.ONE * size, Vector3(PI * 0.5, 0, 0), start, 0.3, {"initial": 0.3, "grow": 6.0, "roll": 6.0})


## [param count] sound rings rolling out from [param at], biggest first; vertical rings
## face the Bard; [param wobble] tilts each ring off-axis (out of tune).
func _rings(c: Array, at: Vector3, radius: float, count: int, start: float, gap := 0.1, seconds := 0.6, vertical := false, wobble := 0.0) -> void:
	for i in count:
		var tilt := Vector3(PI * 0.5, 0, 0) if vertical else Vector3(wobble * float(i + 1), 0, -wobble * 0.8 * float(i + 1))
		var lift := Vector3.ZERO if vertical else Vector3.UP * (0.04 + 0.01 * float(i))
		layer("soundwave", true, c, at + lift, Vector3.ONE * radius * (1.0 - 0.27 * float(i)), tilt, start + gap * float(i), seconds, {"initial": 0.15, "grow": 4.0, "opacity": 0.8})


## Notes circling the caster at [param y] (keep y <= 1.3 or >= 2.3: the face rule) and rising by [param rise].
func _orbit_notes(c: Array, count: int, radius: float, y: float, speed: float, start: float, seconds: float, size := 0.38, rise := 0.5, kind := "note") -> void:
	for i in count:
		layer(kind, true, c, Vector3(0, y, 0), Vector3.ONE * size, Vector3.ZERO, start + 0.04 * float(i), seconds, {"initial": 0.3, "orbit": radius, "orbit_speed": speed, "phase": TAU * float(i) / float(count), "travel": Vector3(0, rise, 0), "face_camera": true, "fade_in": 0.15, "decay": 0.75})


## Notes falling softly onto an area (golden-angle spots).
func _note_rain(c: Array, at: Vector3, radius: float, count: int, start: float, height := 3.4, kind := "note", size := 0.42) -> void:
	for k in count:
		var a := float(k) * 2.39996 + 0.6
		var spot := at + Vector3(sin(a), 0, cos(a)) * radius * sqrt(float(k + 1) / float(count))
		layer(kind, true, c, spot + Vector3.UP * 0.4, Vector3.ONE * size, Vector3.ZERO, start + 0.07 * float(k), 0.75, {"initial": 1.0, "drop": height, "land": 0.5, "flap": 0.12, "face_camera": true, "decay": 0.7})


## Notes thrown up and out from [param at].
func _note_burst(c: Array, at: Vector3, count: int, spread: float, start: float, size := 0.32, kind := "note", up := 0.7) -> void:
	for k in count:
		var a := float(k) * TAU / float(count) + randf() * 0.4
		layer(kind, true, c, at, Vector3.ONE * size, Vector3.ZERO, start + 0.02 * float(k), 0.6, {"initial": 0.6, "travel": Vector3(sin(a) * spread, up + 0.3 * float(k % 2), cos(a) * spread), "roll": 6.0 if k % 2 == 0 else -6.0, "face_camera": true, "decay": 0.6})


## The shared status language over [param at]: a gold fermata over each stunned foe (held
## for the stun), a cracked staff for armour broken (sized by the fraction), blue tears
## for strength sapped.
func _marks(fx: Dictionary, at: Vector3, r: float, start: float, spots := 2) -> void:
	if fx.has("stun"):
		for k in spots:
			var a := float(k) * 2.39996 + 0.3
			layer("fermata", true, GILT, at + Vector3(sin(a), 0, cos(a)) * r * 0.45 + Vector3.UP * 2.2, Vector3.ONE * 0.85, Vector3.ZERO, start + 0.05 * float(k), clampf(float(fx.stun), 0.5, 2.2), {"initial": 0.3, "grow": 5.0, "face_camera": true, "travel": Vector3(0, 0.15, 0), "decay": 0.8})
	if fx.get("shred") is Array:
		layer("cracked_stave", false, DISCORD, at + Vector3.UP * 0.05, Vector3.ONE * r * (0.45 + 1.2 * float(fx.shred[0])), Vector3(0, randf() * TAU, 0), start, 1.4, {"initial": 0.5, "grow": 6.0, "decay": 0.7})
	if fx.get("weaken") is Array:
		var f := float(fx.weaken[0])
		for k in 2 + int(f >= 0.2) + int(f >= 0.25):
			layer("tear_note", true, LAMENT, at + Vector3((float(k) - 1.0) * r * 0.3, 2.6, 0.3), Vector3.ONE * 0.45, Vector3.ZERO, start + 0.1 * float(k), 0.9, {"initial": 0.8, "travel": Vector3(0, -1.8, 0), "accelerate": true, "face_camera": true, "decay": 0.7})


## Two theatre drapes either side of [param at], facing the audience (the camera) a
## little behind the performer, parting as the song begins. Velvet in the palette's deep tone.
func _curtains(c: Array, at: Vector3, radius: float, height: float, start: float, seconds: float) -> void:
	var velvet := _velvet(c)
	var width := radius * 0.8
	for s: float in [-1.0, 1.0]:
		layer("curtain", false, velvet, at + _side * s * radius * 0.3 + _away * radius * 0.2, Vector3(-s * width, height, width * 0.6), Vector3(0, _away_yaw + PI, 0), start, seconds, {"initial": 0.7, "grow": 2.5, "travel": _side * s * radius * 0.45, "fade_in": 0.1, "decay": 0.8, "opacity": 0.95})


## The concert stage at [param at]: a disc of light, curtains parting, two spotlights.
func _stage(c: Array, at: Vector3, r: float, start: float, seconds: float) -> void:
	layer("stage", true, c, at + Vector3.UP * 0.02, Vector3(r * 0.62, 1.0, r * 0.62), Vector3.ZERO, start, seconds, {"initial": 0.25, "grow": 1.6, "spin": 0.15, "fade_in": 0.15, "decay": 0.85, "opacity": 0.75})
	_curtains(MELODY, at, r * 0.6, 3.4, start, seconds)
	for s: float in [-1.0, 1.0]:
		layer("spotlight", true, GILT, at + _side * s * r * 0.32 + _away * r * 0.1, Vector3(1.4, 7.0, 1.4), Vector3.ZERO, start + 0.05, seconds, {"initial": 0.4, "grow": 1.5, "fade_in": 0.3, "decay": 0.85, "opacity": 0.38})


## ★ growth: an outer gold ring from ★3, a crown of five gold stars at ★5 (always last: first to drop).
func _encore(rank: int, at: Vector3, r: float, start: float) -> void:
	if rank >= 3:
		layer("soundwave", true, GILT, at + Vector3.UP * 0.07, Vector3.ONE * r * 1.15, Vector3.ZERO, start + 0.12, 0.6, {"initial": 0.2, "grow": 3.5, "opacity": 0.55})
	if rank >= 5:
		layer("pips5", true, GILT, at + Vector3.UP * 2.6, Vector3.ONE * 0.9, Vector3.ZERO, start, 1.2, {"initial": 0.3, "spin": 2.0, "decay": 0.8})


static func _frac(fx: Dictionary, key: String) -> float:
	return float(fx[key][0]) if fx.get(key) is Array else 0.2


# ---------------------------------------------------------------------------
# Compositions. Every arm lists its layers most important first: the cap
# ([6, 11, 18] by quality) keeps the first ones, so a phone still sees the song.
# ---------------------------------------------------------------------------

func _compose(id: String, skill: Dictionary, c: Array, reach: float, r: float, d: float, rank: int) -> void:
	var target := Vector3(0, 0, reach)
	var th := target + HIT
	var fly := clampf(reach / 20.0, 0.12, 0.6)
	var fx: Dictionary = skill.get("fx", {})
	var hits := int(skill.get("hits", 1))
	match id:
		"staccato_shot":
			# A bright note flicked off the strings runs down a fleeting staff and pops on the foe.
			_flash(c, d)
			_carrier("notes" if rank >= 3 else "note", c, th, d, fly, 0.42 + 0.03 * float(rank))
			layer("score", true, c, LUTE + Vector3(0, -0.1, 0.1), Vector3(0.42, 0.42, maxf(reach - 0.6, 1.0)), Vector3.ZERO, d, fly + 0.3, {"initial": 0.05, "grow": 2.5, "decay": 0.55, "opacity": 0.6})
			_rings(c, th, 0.9, 1, d + fly, 0.0, 0.4, true)
			_note_burst(c, th, 2, 0.6, d + fly, 0.3)
			layer("rosette", true, c, target + Vector3.UP * 0.05, Vector3.ONE * 1.1, Vector3.ZERO, d + fly, 0.6, {"initial": 0.3, "grow": 5.0, "spin": 3.0})
			_encore(rank, target, 1.2, d + fly)
		"valor_march":
			# The march strikes up: a rosette and a ripple to the party, a staff ring rising, notes and banners.
			layer("rosette", true, c, Vector3(0, 0.04, 0), Vector3.ONE * 1.8, Vector3.ZERO, d, 1.6, {"initial": 0.3, "grow": 2.5, "spin": 1.0, "decay": 0.8})
			_rings(c, Vector3.ZERO, 2.8, 1, d, 0.0, 0.7)
			layer("stave", true, c, Vector3(0, 0.15, 0), Vector3(1.25, 1.0, 1.25), Vector3.ZERO, d, 1.3, {"initial": 0.5, "grow": 2.0, "travel": Vector3(0, 0.6, 0), "spin": 1.6, "decay": 0.7})
			_orbit_notes(c, 3 + (rank - 1) / 2, 1.15, 0.7, 3.5, d + 0.05, 1.4, 0.36, 0.5)
			for s: float in [-1.0, 1.0]:
				layer("banner", false, _velvet(c), _away * 0.7 + _side * s * 0.75 + Vector3(0, -0.6, 0), Vector3.ONE * 0.75, Vector3(0, _away_yaw + PI + s * 0.35, 0), d + 0.05, 1.6, {"initial": 1.0, "travel": Vector3(0, 0.6, 0), "flap": 0.05, "fade_in": 0.1, "decay": 0.75})
			_encore(rank, Vector3.ZERO, 2.0, d)
		"resonance":
			# A chord rings out over the target: three rings round a rosette, notes, a lingering staff.
			_rings(c, Vector3.ZERO, r, 3, d, 0.1, 0.6)
			layer("rosette", true, c, Vector3(0, 0.05, 0), Vector3.ONE * r * 0.55, Vector3.ZERO, d, 0.9, {"initial": 0.3, "spin": 2.0})
			layer("notes", true, c, Vector3(0, 0.5, 0), Vector3.ONE * 0.6, Vector3.ZERO, d, 0.8, {"initial": 0.3, "grow": 5.0, "travel": Vector3(0, 1.2, 0), "face_camera": true, "decay": 0.6})
			layer("stave", true, c, Vector3(0, 0.12, 0), Vector3(r * 0.5, 0.7, r * 0.5), Vector3.ZERO, d + 0.1, clampf(float(fx.get("slow", 2.0)), 1.0, 3.0), {"initial": 0.6, "spin": 0.8, "opacity": 0.45, "decay": 0.8})
			_note_burst(c, Vector3(0, 0.6, 0), 3, r * 0.5, d + 0.05, 0.3)
			_encore(rank, Vector3.ZERO, r, d)
		"sorrow_note":
			# A blue tear of a note droops to the foe; tears fall on it under a dark-blue sorrow seal.
			_flash(LAMENT, d)
			_carrier("tear_note", LAMENT, th, d, fly, 0.45)
			layer("score", true, LAMENT, LUTE + Vector3(0, -0.1, 0.1), Vector3(0.2, 0.2, maxf(reach - 0.6, 1.0)), Vector3(0.05, 0, 0), d, fly + 0.22, {"initial": 0.05, "grow": 2.0, "decay": 0.55, "opacity": 0.45})
			layer("rosette", false, LAMENT, target + Vector3.UP * 0.05, Vector3.ONE * 1.2, Vector3.ZERO, d + fly, 1.0, {"initial": 0.4, "spin": -1.5, "opacity": 0.7})
			_rings(LAMENT, target, 1.4, 1, d + fly, 0.0, 0.6)
			_marks(fx, target, 1.6, d + fly)
			_encore(rank, target, 1.4, d + fly)
		"discord":
			# A jarring chord: the staff under the pack cracks, rings roll out askew, notes shake loose.
			layer("cracked_stave", false, c, Vector3(0, 0.05, 0), Vector3.ONE * r * (0.45 + 1.2 * _frac(fx, "shred")), Vector3(0, randf() * TAU, 0), d, 1.3, {"initial": 0.4, "grow": 6.0, "decay": 0.7})
			_rings(c, Vector3.ZERO, r, 2, d, 0.06, 0.55, false, 0.12)
			layer("vortex", true, c, Vector3(0, 0.08, 0), Vector3.ONE * r * 0.6, Vector3.ZERO, d, 0.8, {"initial": 0.3, "spin": 4.0, "opacity": 0.5})
			for k in 3:
				var a := float(k) * TAU / 3.0 + 0.4
				layer("note", true, c, Vector3(0, 1.0, 0), Vector3.ONE * 0.45, Vector3.ZERO, d + 0.03 * float(k), 0.75, {"initial": 0.6, "travel": Vector3(sin(a), 0.6, cos(a)) * r * 0.45, "flap": 0.35, "roll": 8.0 if k % 2 == 0 else -8.0, "face_camera": true, "decay": 0.6})
			layer("shock", true, c, Vector3(0, 0.04, 0), Vector3.ONE * r * 0.9, Vector3.ZERO, d, 0.45, {"initial": 0.2, "grow": 5.0})
			_encore(rank, Vector3.ZERO, r, d)
		"iron_ballad":
			# A ballad of iron: a gold rosette, a soft pillar, a staff wall, the lyre behind, shield-notes.
			layer("rosette", true, c, Vector3(0, 0.04, 0), Vector3.ONE * 2.0, Vector3.ZERO, d, 1.7, {"initial": 0.3, "grow": 2.5, "spin": 0.8, "decay": 0.8})
			layer("pillar", true, c, Vector3.ZERO, Vector3(1.4, 3.0, 1.4), Vector3.ZERO, d, 1.2, {"initial": 0.4, "grow": 3.0, "opacity": 0.35})
			_rings(c, Vector3.ZERO, 2.6, 1, d, 0.0, 0.7)
			layer("stave", true, c, Vector3(0, 0.1, 0), Vector3(1.3, 1.6, 1.3), Vector3.ZERO, d, 1.4, {"initial": 0.5, "grow": 2.0, "travel": Vector3(0, 0.3, 0), "spin": -1.2, "decay": 0.75})
			layer("lyre", true, c, _away * 0.9 + Vector3.UP * 0.9, Vector3.ONE * 0.75, Vector3.ZERO, d + 0.05, 1.5, {"initial": 0.3, "grow": 2.0, "travel": Vector3(0, 0.3, 0), "face_camera": true, "fade_in": 0.15, "decay": 0.75})
			_orbit_notes(c, 4 + (rank - 1) / 2, 1.2, 0.8, 2.2, d + 0.05, 1.5, 0.4, 0.3)
			_encore(rank, Vector3.ZERO, 2.0, d)
		"triad_chord":
			# A chord of three to five notes fans out in rose, gold and aqua under a sweeping staff.
			_flash(c, d)
			var tones := [c, GILT, SERENE]
			for i in hits:
				var a := (float(i) / maxf(1.0, float(hits - 1)) - 0.5) * (0.5 + 0.1 * float(hits))
				_carrier("note", tones[i % 3], Vector3(sin(a), 0, cos(a)) * reach * 0.95 + HIT, d + 0.02 * float(i), 0.38, 0.4)
			layer("score", true, c, Vector3(-0.8, 1.0, 0.6), Vector3(0.35, 0.35, 1.6), Vector3(0, PI * 0.5, 0), d, 0.45, {"initial": 0.3, "travel": Vector3(0, 0, 2.6), "decay": 0.6, "opacity": 0.55})
			_rings(c, Vector3(0, 1.0, 0.8), 0.8, 1, d, 0.0, 0.35, true)
			_encore(rank, Vector3(0, 0, reach * 0.9), 1.2, d + 0.38)
		"echo_chain":
			# A note leaps to the first foe and its echo rings out twice; every hop adds its own (contact).
			_flash(c, d)
			_carrier("note", c, th, d, 0.2, 0.4)
			_rings(c, th, 0.9, 2, d + 0.2, 0.08, 0.32, true)
			layer("notes", true, c, Vector3(0, 2.4, 0), Vector3.ONE * 0.45, Vector3.ZERO, d, 0.8, {"initial": 0.3, "grow": 4.0, "travel": Vector3(0, 0.5, 0), "face_camera": true, "decay": 0.6})
			_encore(rank, target, 1.2, d + 0.2)
		"war_drum":
			# The drum of war: a drum head stamps down, two booming rings (the flam), a shock, fermatas.
			layer("drum_ring", false, c, Vector3(0, 0.05, 0), Vector3.ONE * 1.6, Vector3.ZERO, d, 0.9, {"initial": 0.9, "drop": 0.4, "land": 0.08, "decay": 0.7})
			_rings(c, Vector3.ZERO, r, 2, d, 0.14, 0.55)
			layer("shock", true, c, Vector3(0, 0.04, 0), Vector3.ONE * r * 0.9, Vector3.ZERO, d, 0.45, {"initial": 0.2, "grow": 5.0})
			_marks(fx, Vector3.ZERO, r, d + 0.05, 2)
			for s: float in [-1.0, 1.0]:
				layer("note", true, c, Vector3(s * 0.8, 0.3, 0.5), Vector3.ONE * 0.4, Vector3.ZERO, d + 0.05, 0.7, {"initial": 0.5, "travel": Vector3(s * 0.4, 0.9, 0), "roll": s * 5.0, "face_camera": true, "decay": 0.6})
			_encore(rank, Vector3.ZERO, r, d)
		"heartstring":
			# A heart flares on the strings, a heavy note runs down one string of light, a heart blooms on the foe.
			layer("heart", true, c, LUTE + Vector3(0, 0.1, 0.1), Vector3.ONE * 0.4, Vector3.ZERO, d, 0.32, {"initial": 0.2, "grow": 6.0, "face_camera": true})
			_carrier("note", c, th, d, fly, 0.55)
			layer("score", true, c, LUTE + Vector3(0, -0.05, 0.1), Vector3(0.06, 0.06, maxf(reach - 0.6, 1.0)), Vector3.ZERO, d, fly + 0.25, {"initial": 0.05, "grow": 2.5, "decay": 0.6, "opacity": 0.6})
			layer("heart", true, c, th + Vector3.UP * 0.2, Vector3.ONE * 0.9, Vector3.ZERO, d + fly, 0.6, {"initial": 0.3, "grow": 5.0, "face_camera": true, "decay": 0.6})
			_rings(c, target, 1.6, 1, d + fly, 0.0, 0.5)
			layer("stave", true, c, target + Vector3.UP * 0.4, Vector3(0.85, 0.8, 0.85), Vector3.ZERO, d + fly, clampf(float(fx.get("slow", 3.0)), 1.0, 4.0), {"initial": 0.4, "spin": 1.0, "opacity": 0.5, "decay": 0.85})
			_encore(rank, target, 1.6, d + fly)
		"virtuoso":
			# A dazzling solo: the spectral lute behind, notes spiralling fast up round the Bard, a gold clef above.
			layer("lute_ghost", true, c, _away * 0.7 + Vector3.UP * 0.5, Vector3.ONE * 0.85, Vector3.ZERO, d, 1.4, {"initial": 0.3, "grow": 2.0, "travel": Vector3(0, 0.55, 0), "face_camera": true, "fade_in": 0.15, "decay": 0.75, "opacity": 0.6})
			layer("rosette", true, c, Vector3(0, 0.04, 0), Vector3.ONE * 1.5, Vector3.ZERO, d, 1.2, {"initial": 0.3, "spin": 3.0})
			_orbit_notes(c, 4 + (rank - 1) / 2, 1.0, 0.5, 5.0, d, 1.2, 0.28, 1.9)
			layer("treble", true, GILT, _away * 0.35 + Vector3.UP * 2.35, Vector3.ONE * 0.5, Vector3.ZERO, d + 0.1, 1.2, {"initial": 0.3, "grow": 3.0, "travel": Vector3(0, 0.35, 0), "face_camera": true, "decay": 0.7})
			_rings(c, Vector3.ZERO, 1.8, 1, d, 0.0, 0.5)
			_encore(rank, Vector3.ZERO, 1.8, d)
		"heroic_anthem":
			# The anthem: a gold rosette and a ripple to the party, a spotlight, notes, a staff crown, banners.
			layer("rosette", true, GILT, Vector3(0, 0.04, 0), Vector3.ONE * 2.4, Vector3.ZERO, d, 1.8, {"initial": 0.3, "grow": 2.5, "spin": 0.9, "decay": 0.8})
			_rings(c, Vector3.ZERO, 3.2, 1, d, 0.0, 0.75)
			layer("spotlight", true, GILT, Vector3.ZERO, Vector3(1.3, 5.0, 1.3), Vector3.ZERO, d, 1.4, {"initial": 0.5, "grow": 3.0, "opacity": 0.35, "decay": 0.75})
			_orbit_notes(c, 5 + (rank - 1) / 2, 1.25, 0.75, 3.0, d + 0.05, 1.6, 0.4, 0.5)
			layer("stave", true, GILT, Vector3(0, 2.35, 0), Vector3(0.7, 0.7, 0.7), Vector3.ZERO, d + 0.08, 1.6, {"initial": 0.3, "grow": 3.0, "spin": 1.4, "decay": 0.8})
			for k in 3:
				var off := float(k) - 1.0
				layer("banner", false, _velvet(c), _away * 1.3 + _side * off * 0.95 + Vector3(0, -0.6, 0), Vector3.ONE * 0.8, Vector3(0, _away_yaw + PI + off * 0.4, 0), d + 0.05 * float(k), 1.7, {"initial": 1.0, "travel": Vector3(0, 0.6, 0), "flap": 0.05, "fade_in": 0.1, "decay": 0.75})
			_encore(rank, Vector3.ZERO, 2.4, d)
		"slumber_lullaby":
			# A lullaby: a crescent moon rocks over the pack, notes drift down like snow, fermatas over the sleepers.
			layer("moon", true, c, Vector3(0, 4.0, 0) + _away * 0.6, Vector3.ONE * 1.4, Vector3.ZERO, d, 2.0, {"initial": 0.3, "grow": 2.0, "face_camera": true, "flap": 0.05, "fade_in": 0.12, "decay": 0.8, "opacity": 0.75})
			_note_rain(c, Vector3.ZERO, r * 0.6, 4, d, 3.2)
			layer("rosette", true, c, Vector3(0, 0.05, 0), Vector3.ONE * r * 0.8, Vector3.ZERO, d, 2.0, {"initial": 0.3, "spin": 0.5, "opacity": 0.6})
			_rings(c, Vector3.ZERO, r, 1, d, 0.0, 1.2)
			_marks(fx, Vector3.ZERO, r, d + 0.1, 3)
			layer("stave", true, c, Vector3(0, 0.2, 0), Vector3(r * 0.6, 0.8, r * 0.6), Vector3.ZERO, d, 1.8, {"initial": 0.5, "spin": 0.3, "opacity": 0.45})
			_encore(rank, Vector3.ZERO, r, d)
		"lament":
			# A lament: blue tear-notes rain on the pack, a heavy ring, a dark sorrow seal and a grieving swirl.
			_note_rain(LAMENT, Vector3.ZERO, r * 0.6, 5, d, 3.4, "tear_note", 0.42)
			_rings(LAMENT, Vector3.ZERO, r, 1, d, 0.0, 0.9)
			layer("rosette", false, LAMENT, Vector3(0, 0.05, 0), Vector3.ONE * r * 0.7, Vector3.ZERO, d, 1.6, {"initial": 0.4, "spin": -0.6, "opacity": 0.75})
			layer("vortex", true, LAMENT, Vector3(0, 0.08, 0), Vector3.ONE * r * 0.55, Vector3.ZERO, d + 0.1, 1.2, {"initial": 0.3, "spin": 1.2, "opacity": 0.4})
			_marks(fx, Vector3.ZERO, r, d + 0.2)
			_encore(rank, Vector3.ZERO, r, d)
		"cascade":
			# A cascade: a staff of light pours forward like water and the notes tumble down it in a fan.
			_flash(c, d)
			layer("score", true, c, LUTE + Vector3(0.0, 0.3, 0.1), Vector3(0.6, 0.45, maxf(reach * 0.9, 2.0)), Vector3(0.12, 0, 0), d, 0.6, {"initial": 0.08, "grow": 2.0, "decay": 0.6, "opacity": 0.55})
			for i in hits:
				var a := (float(i) / maxf(1.0, float(hits - 1)) - 0.5) * 1.1
				_carrier("note", c if i % 2 == 0 else SERENE, Vector3(sin(a), 0, cos(a)) * reach * 0.95 + HIT, d + 0.03 * float(i), 0.32, 0.36, LUTE + Vector3(0, 0.3, 0))
			_encore(rank, Vector3(0, 0, reach * 0.9), 1.6, d + 0.32)
		"sanctuary_serenade":
			# A serenade of the sanctuary: an aqua rosette and ripple, a great lyre, a pillar, notes, curtains, a crown.
			layer("rosette", true, c, Vector3(0, 0.04, 0), Vector3.ONE * 2.6, Vector3.ZERO, d, 2.0, {"initial": 0.3, "grow": 2.5, "spin": 0.6, "decay": 0.8})
			_rings(c, Vector3.ZERO, 3.4, 1, d, 0.0, 0.8)
			layer("lyre", true, c, _away * 1.0 + Vector3.UP * 0.8, Vector3.ONE * 1.1, Vector3.ZERO, d, 1.8, {"initial": 0.3, "grow": 2.0, "travel": Vector3(0, 0.4, 0), "face_camera": true, "fade_in": 0.15, "decay": 0.8})
			layer("pillar", true, c, Vector3.ZERO, Vector3(1.6, 4.0, 1.6), Vector3.ZERO, d, 1.4, {"initial": 0.4, "grow": 3.0, "opacity": 0.35})
			_orbit_notes(c, 6 + (rank - 1) / 2, 1.3, 0.7, -1.8, d + 0.05, 1.7, 0.4, 0.4)
			_curtains(c, Vector3.ZERO, 1.7, 2.6, d, 1.8)
			layer("stave", true, c, Vector3(0, 2.4, 0), Vector3(0.75, 0.7, 0.75), Vector3.ZERO, d + 0.1, 1.6, {"initial": 0.3, "grow": 3.0, "spin": -1.2})
			_encore(rank, Vector3.ZERO, 2.6, d)
		"fortissimo":
			# Fortissimo: two sonic rings slam into the foe, a great beamed pair bursts on it, a fermata holds it.
			for i in 2:
				layer("soundwave", true, c, LUTE + Vector3(0, 0, 0.2), Vector3.ONE * (0.8 + 0.5 * float(i)), Vector3(PI * 0.5, 0, 0), d + 0.04 * float(i), 0.2, {"initial": 0.4, "travel": th - LUTE, "accelerate": true, "decay": 0.8})
			layer("notes", true, c, th + Vector3.UP * 0.2, Vector3.ONE * 1.2, Vector3.ZERO, d + 0.15, 0.45, {"initial": 0.2, "grow": 8.0, "face_camera": true, "decay": 0.55})
			layer("shock", true, c, target + Vector3.UP * 0.04, Vector3.ONE * 2.4, Vector3.ZERO, d + 0.15, 0.5, {"initial": 0.2, "grow": 5.0})
			_marks(fx, target, 0.1, d + 0.18, 1)
			_rings(c, target, 2.0, 1, d + 0.2, 0.0, 0.5)
			_encore(rank, target, 2.0, d + 0.18)
		"shattering_rhapsody":
			# A rhapsody of thunder: the staff shatters, a storm staff turns overhead and drops three bolts on the beats.
			layer("cracked_stave", false, c, Vector3(0, 0.05, 0), Vector3.ONE * r * (0.45 + 1.2 * _frac(fx, "shred")), Vector3(0, randf() * TAU, 0), d, 1.4, {"initial": 0.4, "grow": 6.0, "decay": 0.7})
			for k in 3:
				var a := float(k) * 2.39996 + 0.4
				layer("bolt", true, c, Vector3(sin(a), 0, cos(a)) * r * 0.5 * sqrt(float(k + 1) / 3.0), Vector3(0.9, 4.5, 0.9), Vector3(0, 0, randf_range(-0.12, 0.12)), d + 0.12 * float(k), 0.28, {"initial": 1.0, "face_camera": true})
			_rings(c, Vector3.ZERO, r, 2, d, 0.24, 0.55)
			layer("stave", true, c, Vector3(0, 3.2, 0), Vector3(r * 0.45, 1.0, r * 0.45), Vector3.ZERO, d, 1.0, {"initial": 0.4, "grow": 3.0, "spin": 2.0, "opacity": 0.7})
			_note_burst(c, Vector3(0, 0.8, 0), 3, r * 0.5, d + 0.05, 0.36)
			_encore(rank, Vector3.ZERO, r, d)
		"maestro_fervor":
			# The conductor's fire: a gold spotlight, the lute behind, two note spirals turning opposite ways, a clef.
			layer("spotlight", true, c, Vector3.ZERO, Vector3(1.2, 4.6, 1.2), Vector3.ZERO, d, 1.3, {"initial": 0.5, "grow": 3.0, "opacity": 0.4, "decay": 0.75})
			layer("lute_ghost", true, c, _away * 0.8 + Vector3.UP * 0.6, Vector3.ONE * 1.0, Vector3.ZERO, d, 1.5, {"initial": 0.3, "grow": 2.0, "travel": Vector3(0, 0.6, 0), "face_camera": true, "fade_in": 0.15, "decay": 0.75, "opacity": 0.6})
			_orbit_notes(c, 3 + (rank - 1) / 2, 1.0, 0.5, 5.0, d, 1.3, 0.28, 1.9)
			_orbit_notes(MELODY, 3, 1.3, 0.5, -5.0, d + 0.06, 1.3, 0.28, 1.9)
			layer("treble", true, MELODY, _away * 0.35 + Vector3.UP * 2.4, Vector3.ONE * 0.55, Vector3.ZERO, d + 0.1, 1.2, {"initial": 0.3, "grow": 3.0, "travel": Vector3(0, 0.3, 0), "face_camera": true, "decay": 0.7})
			layer("rosette", true, c, Vector3(0, 0.04, 0), Vector3.ONE * 1.7, Vector3.ZERO, d, 1.2, {"initial": 0.3, "spin": 3.5})
			_rings(c, Vector3.ZERO, 2.0, 1, d, 0.0, 0.5)
			_encore(rank, Vector3.ZERO, 2.0, d)
		"grand_dissonance":
			# Grand dissonance: a colossal dark lute tilts off-key in the sky, the field's staff cracks, crooked rings.
			layer("lute_ghost", true, c, _away * r * 0.3 + Vector3.UP * 3.0, Vector3.ONE * 2.1, Vector3.ZERO, d, 1.6, {"initial": 0.4, "grow": 2.0, "face_camera": true, "flap": 0.06, "turn": Vector3(0, 0, 0.25), "fade_in": 0.12, "decay": 0.8, "opacity": 0.75})
			layer("cracked_stave", false, c, Vector3(0, 0.05, 0), Vector3.ONE * r * (0.45 + 1.2 * _frac(fx, "shred")), Vector3(0, randf() * TAU, 0), d, 1.5, {"initial": 0.4, "grow": 6.0, "decay": 0.7})
			for i in 3:
				layer("soundwave", true, c if i % 2 == 0 else LAMENT, Vector3(0, 0.05 + 0.01 * float(i), 0), Vector3.ONE * r * (1.0 - 0.25 * float(i)), Vector3(0.1 * float(i + 1), 0, -0.08 * float(i + 1)), d + 0.1 * float(i), 0.6, {"initial": 0.15, "grow": 4.0})
			layer("vortex", true, c, Vector3(0, 0.08, 0), Vector3.ONE * r * 0.7, Vector3.ZERO, d, 1.3, {"initial": 0.3, "spin": 4.0, "opacity": 0.55})
			for k in 4:
				var a := float(k) * TAU / 4.0 + 0.3
				layer("note", true, c, Vector3(0, 1.2, 0), Vector3.ONE * 0.5, Vector3.ZERO, d + 0.03 * float(k), 0.8, {"initial": 0.6, "travel": Vector3(sin(a), 0.7, cos(a)) * r * 0.5, "flap": 0.35, "roll": 8.0 if k % 2 == 0 else -8.0, "face_camera": true, "decay": 0.6})
			_marks({"weaken": fx.get("weaken")}, Vector3.ZERO, r, d + 0.15)
			layer("shock", true, c, Vector3(0, 0.04, 0), Vector3.ONE * r, Vector3.ZERO, d, 0.5, {"initial": 0.2, "grow": 4.0})
			_encore(rank, Vector3.ZERO, r, d)
		"aria_of_ruin":
			# The aria: the sky note lands as a gold spotlight slams on the foe; a giant clef rises behind it.
			layer("spotlight", true, GILT, target, Vector3(1.6, 7.0, 1.6), Vector3.ZERO, d, 1.0, {"initial": 0.6, "grow": 5.0, "opacity": 0.5, "decay": 0.7})
			layer("treble", true, c, target + _away * 0.8, Vector3.ONE * 2.0, Vector3.ZERO, d + 0.04, 1.2, {"initial": 0.3, "grow": 3.0, "travel": Vector3(0, 0.4, 0), "face_camera": true, "decay": 0.75})
			_rings(c, target, 3.4, 2, d + 0.02, 0.08, 0.6)
			layer("shock", true, c, target + Vector3.UP * 0.04, Vector3.ONE * 3.0, Vector3.ZERO, d, 0.5, {"initial": 0.2, "grow": 5.0})
			layer("rosette", true, c, target + Vector3.UP * 0.05, Vector3.ONE * 2.2, Vector3.ZERO, d, 1.2, {"initial": 0.3, "spin": 2.0})
			_note_burst(c, th, 3, 1.2, d + 0.05, 0.4)
			_encore(rank, target, 3.0, d)
		"eternal_echo":
			# Eternal echo: the spectral lute rings behind, three echo rings chase a beamed pair to the first foe.
			layer("lute_ghost", true, c, _away * 0.85 + Vector3.UP * 0.6, Vector3.ONE * 1.1, Vector3.ZERO, d, 1.3, {"initial": 0.3, "grow": 2.0, "face_camera": true, "opacity": 0.55, "decay": 0.75})
			_carrier("notes", c, th, d, 0.22, 0.5)
			for i in 3:
				layer("soundwave", true, c, LUTE + Vector3(0, 0, 0.2), Vector3.ONE * (0.8 + 0.3 * float(i)), Vector3(PI * 0.5, 0, 0), d + 0.05 * float(i), 0.3, {"initial": 0.5, "travel": th - LUTE, "accelerate": true, "decay": 0.8})
			layer("rosette", true, c, Vector3(0, 0.04, 0), Vector3.ONE * 1.8, Vector3.ZERO, d, 1.0, {"initial": 0.3, "spin": 2.0})
			_orbit_notes(c, 3, 1.0, 2.3, 2.5, d, 1.0, 0.3, 0.3)
			_encore(rank, target, 1.6, d + 0.22)
		"thunder_crescendo":
			# Thunder crescendo: two drum heads stamp in a flam, four bolts strike round the Bard, rings roll out.
			layer("drum_ring", false, c, Vector3(0, 0.05, 0), Vector3.ONE * 2.0, Vector3.ZERO, d, 0.9, {"initial": 0.9, "drop": 0.5, "land": 0.08, "decay": 0.7})
			layer("drum_ring", false, c, Vector3(0, 0.06, 0), Vector3.ONE * r * 0.5, Vector3(0, 0.4, 0), d + 0.16, 0.9, {"initial": 0.9, "drop": 0.4, "land": 0.08, "decay": 0.7})
			for k in 4:
				var a := float(k) * TAU / 4.0 + 0.4
				layer("bolt", true, c, Vector3(sin(a), 0, cos(a)) * r * 0.6, Vector3(1.1, 5.5, 1.1), Vector3(0, 0, randf_range(-0.1, 0.1)), d + 0.06 * float(k), 0.3, {"initial": 1.0, "face_camera": true})
			_rings(c, Vector3.ZERO, r, 3, d, 0.15, 0.6)
			_marks(fx, Vector3.ZERO, r, d + 0.1, 3)
			layer("shock", true, c, Vector3(0, 0.04, 0), Vector3.ONE * r, Vector3.ZERO, d, 0.5, {"initial": 0.2, "grow": 4.0})
			_encore(rank, Vector3.ZERO, r, d)
		"hymn_of_legends":
			# The great song: a vast rosette, a giant lyre of light in the sky, a choir of light spirits behind.
			layer("rosette", true, c, Vector3(0, 0.04, 0), Vector3.ONE * 3.2, Vector3.ZERO, d, 2.2, {"initial": 0.3, "grow": 2.0, "spin": 0.7, "decay": 0.8})
			_rings(c, Vector3.ZERO, 4.0, 1, d, 0.0, 0.9)
			layer("lyre", true, c, _away * 2.2 + Vector3.UP * 2.0, Vector3.ONE * 2.0, Vector3.ZERO, d, 2.2, {"initial": 0.2, "grow": 1.5, "travel": Vector3(0, 0.5, 0), "face_camera": true, "fade_in": 0.2, "decay": 0.8})
			for k in 4:
				var a := _away_yaw + (float(k) - 1.5) * 0.75
				layer("spirit", true, GILT, Vector3(sin(a), 0, cos(a)) * 2.0 + Vector3.UP * 0.8, Vector3.ONE * 1.4, Vector3.ZERO, d + 0.08 * float(k), 2.0, {"initial": 0.3, "grow": 2.0, "travel": Vector3(0, 1.4, 0), "face_camera": true, "fade_in": 0.15, "decay": 0.8})
			_curtains(MELODY, Vector3.ZERO, 2.4, 3.0, d, 2.0)
			for s: float in [-1.0, 1.0]:
				layer("spotlight", true, GILT, _side * s * 1.2 + _away * 0.4, Vector3(1.2, 6.0, 1.2), Vector3.ZERO, d + 0.05, 1.8, {"initial": 0.5, "grow": 2.0, "opacity": 0.35, "decay": 0.8})
			_orbit_notes(c, 6 + (rank - 1) / 2, 1.5, 0.8, 2.5, d + 0.05, 1.8, 0.38, 0.4)
			layer("stave", true, c, Vector3(0, 2.5, 0), Vector3(0.85, 0.7, 0.85), Vector3.ZERO, d + 0.1, 2.0, {"initial": 0.3, "grow": 3.0, "spin": 1.4})
			_encore(rank, Vector3.ZERO, 3.2, d)
		"grand_finale":
			# The finale: three rings land (rose, gold, violet), five pillars of light, a colossal lute strums in
			# the sky, notes go up like fireworks and the marks follow.
			for i in 3:
				layer("soundwave", true, [c, GILT, DISCORD][i], Vector3(0, 0.05 + 0.01 * float(i), 0), Vector3.ONE * r * (1.0 - 0.28 * float(i)), Vector3.ZERO, d + 0.08 * float(i), 0.7, {"initial": 0.15, "grow": 4.0})
			for k in 5:
				var a := float(k) * TAU / 5.0 + 0.3
				layer("pillar", true, GILT, Vector3(sin(a), 0, cos(a)) * r * 0.55, Vector3(0.75, 6.0, 0.75), Vector3.ZERO, d + 0.03 * float(k), 0.9, {"initial": 0.3, "grow": 6.0, "opacity": 0.38})
			layer("lute_ghost", true, c, _away * r * 0.45 + Vector3.UP * 3.6, Vector3.ONE * 2.8, Vector3.ZERO, d, 1.8, {"initial": 0.6, "grow": 2.0, "face_camera": true, "turn": Vector3(0, 0, -0.15), "fade_in": 0.1, "decay": 0.8, "opacity": 0.7})
			_note_burst(c, Vector3.UP * 1.2, 6, r * 0.55, d + 0.05, 0.6, "note", 4.0)
			layer("shock", true, c, Vector3(0, 0.04, 0), Vector3.ONE * r, Vector3.ZERO, d, 0.5, {"initial": 0.2, "grow": 4.0})
			_marks(fx, Vector3.ZERO, r, d + 0.2, 3)
			_encore(rank, Vector3.ZERO, r, d)
		_:
			_rings(c, target, 1.6, 1, d, 0.0, 0.5)
			_note_burst(c, target + HIT, 3, 0.8, d, 0.34)


## Star beats. [param source_local] is the caster in this root's frame.
func _star(id: String, skill: Dictionary, c: Array, index: int, radius: float, source_local: Vector3) -> void:
	var fx: Dictionary = skill.get("fx", {})
	match id:
		"starlight_overture":
			# Every beat a star-note falls on the target and a ring rolls out; the last drops a great beamed pair.
			var a := float(index) * 2.39996
			var spot := Vector3(sin(a), 0, cos(a)) * radius * 0.22 * float(index)
			layer("note", true, c, spot + Vector3.UP * 0.6, Vector3.ONE * 1.2, Vector3.ZERO, 0.0, 0.7, {"initial": 1.0, "drop": 4.0, "land": 0.12, "face_camera": true, "decay": 0.6})
			_rings(c, spot, radius * (0.55 + 0.15 * float(index)), 1, 0.08, 0.0, 0.6)
			_note_burst(STARLIGHT, spot + Vector3.UP * 0.5, 3, radius * 0.3, 0.1, 0.3)
			if index == 0:
				layer("rosette", true, c, Vector3.UP * 0.05, Vector3.ONE * radius * 0.6, Vector3.ZERO, 0.0, 1.6, {"initial": 0.3, "spin": 1.5})
			if index >= 2:
				layer("notes", true, c, Vector3.UP * 0.6, Vector3.ONE * 1.8, Vector3.ZERO, 0.0, 0.8, {"initial": 1.0, "drop": 5.0, "land": 0.14, "face_camera": true, "decay": 0.6})
				layer("stave", true, GILT, Vector3(0, 3.2, 0), Vector3(radius * 0.4, 1.0, radius * 0.4), Vector3.ZERO, 0.0, 1.2, {"initial": 0.3, "spin": 1.2})
				_marks({"weaken": fx.get("weaken")}, Vector3.ZERO, radius, 0.15)
		"heartbreak_sonata":
			var side := 1.0 if index % 2 == 0 else -1.0
			if index < 5:
				# Five quick notes from alternating sides; the dark heart over the foe swells each beat.
				layer("note", true, c, Vector3(side * 0.45, 1.2, 0), Vector3.ONE * 0.6, Vector3.ZERO, 0.0, 0.35, {"initial": 0.6, "roll": side * 6.0, "face_camera": true, "decay": 0.5})
				layer("soundwave", true, c, Vector3(0, 1.2, -0.3), Vector3.ONE * (0.8 + 0.1 * float(index)), Vector3(PI * 0.5, 0, 0), 0.0, 0.3, {"initial": 0.3, "grow": 5.0})
				layer("heart", false, c, Vector3(0, 1.35, 0), Vector3.ONE * (0.5 + 0.1 * float(index)), Vector3.ZERO, 0.0, 0.42, {"initial": 0.8, "face_camera": true, "decay": 0.6})
			else:
				# The heartbreak: a great heart cracks across under a spotlight; rings and notes burst.
				layer("heart", true, c, Vector3(0, 1.4, 0), Vector3.ONE * 2.2, Vector3.ZERO, 0.0, 0.9, {"initial": 0.4, "grow": 4.0, "face_camera": true, "decay": 0.6})
				layer("cracked_stave", false, DISCORD, Vector3(0, 1.4, 0.05), Vector3.ONE * 1.3, Vector3(PI * 0.5, 0, 0.6), 0.08, 0.9, {"initial": 0.6, "grow": 6.0, "face_camera": true})
				layer("spotlight", true, c, Vector3.ZERO, Vector3(1.4, 6.0, 1.4), Vector3.ZERO, 0.0, 0.9, {"initial": 0.6, "grow": 5.0, "opacity": 0.45})
				_rings(c, Vector3.ZERO, 3.0, 2, 0.05, 0.1, 0.6)
				_note_burst(c, Vector3.UP * 1.2, 4, 1.4, 0.08, 0.4)
				_marks({"shred": fx.get("shred")}, Vector3.ZERO, 2.4, 0.1)
		"celestial_stage":
			# A stage of light rises under the party, a colossal lyre in the sky, a choir of five spirits,
			# curtains, three spotlights and seven notes turning overhead.
			layer("stage", true, c, Vector3.UP * 0.02, Vector3(radius * 0.5, 1.0, radius * 0.5), Vector3.ZERO, 0.0, 2.4, {"initial": 0.2, "grow": 2.5, "spin": 0.2, "decay": 0.85, "opacity": 0.6})
			layer("lyre", true, c, _away * 2.8 + Vector3.UP * 2.2, Vector3.ONE * 2.2, Vector3.ZERO, 0.0, 2.4, {"initial": 0.2, "grow": 1.5, "travel": Vector3(0, 0.4, 0), "face_camera": true, "fade_in": 0.15, "decay": 0.85})
			_rings(c, Vector3.ZERO, radius, 1, 0.0, 0.0, 0.9)
			for k in 5:
				var a := _away_yaw + (float(k) - 2.0) * 0.45
				layer("spirit", true, GILT, Vector3(sin(a), 0, cos(a)) * 2.5 + Vector3.UP * 1.0, Vector3.ONE * 1.5, Vector3.ZERO, 0.06 * float(k), 2.2, {"initial": 0.3, "grow": 2.0, "travel": Vector3(0, 0.6, 0), "face_camera": true, "fade_in": 0.15, "decay": 0.85})
			_curtains(MELODY, Vector3.ZERO, radius * 0.4, 3.6, 0.0, 2.4)
			for k in 3:
				var a := _away_yaw + (float(k) - 1.0) * 1.1
				layer("spotlight", true, GILT, Vector3(sin(a), 0, cos(a)) * radius * 0.25, Vector3(1.3, 7.0, 1.3), Vector3.ZERO, 0.05, 2.2, {"initial": 0.4, "grow": 1.5, "opacity": 0.35, "decay": 0.85})
			_orbit_notes(c, 7, 2.4, 2.3, 1.5, 0.05, 2.2, 0.42, 0.2)
		"cosmic_encore":
			if index == 0:
				# The encore begins in the sky: the Bard plays a colossal lute above the field and a
				# cosmic staff ring turns high over the target.
				layer("lute_ghost", true, c, source_local + Vector3(0, 3.4, 0) + _away * 1.8, Vector3.ONE * 2.0, Vector3.ZERO, 0.0, 2.2, {"initial": 0.3, "grow": 1.5, "face_camera": true, "fade_in": 0.1, "decay": 0.85, "opacity": 0.6})
				layer("stave", true, c, Vector3(0, 6.0, 0), Vector3(radius * 0.55, 1.4, radius * 0.55), Vector3.ZERO, 0.0, 2.2, {"initial": 0.3, "grow": 1.5, "spin": 0.8})
			# Each wave: star-notes fall from the score onto the field and a ring rolls out.
			_note_rain(c, Vector3.ZERO, radius * 0.7, 3, 0.0, 5.6, "note", 0.8)
			_rings(c, Vector3.ZERO, radius * (0.5 + 0.12 * float(index)), 1, 0.1, 0.0, 0.6)
			if index >= 4:
				_rings(GILT, Vector3.ZERO, radius, 2, 0.12, 0.1, 0.7)
				layer("rosette", true, c, Vector3.UP * 0.05, Vector3.ONE * radius, Vector3.ZERO, 0.1, 1.4, {"initial": 0.3, "spin": 1.0})
				_note_burst(c, Vector3.UP * 1.0, 6, radius * 0.6, 0.1, 0.6, "note", 3.0)
				_marks(fx, Vector3.ZERO, radius, 0.2, 3)


# ---------------------------------------------------------------------------
# Geometry (built once per kind, shared). COLOR.r = core / inlay, COLOR.g =
# opacity mask. Flat pieces in XY facing +Z, ground pieces in XZ, upright
# pieces stand on y = 0.
# ---------------------------------------------------------------------------

static func mesh(kind: String) -> ArrayMesh:
	if kind in LORD_KINDS:
		return LordSkillArt.mesh(kind)
	if kind in SHADOW_KINDS:
		return ShadowSkillArt.mesh(kind)
	if _meshes.has(kind):
		return _meshes[kind]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"note": _note(st)
		"notes": _notes(st)
		"treble": _treble(st)
		"tear_note": _tear_note(st)
		"heart": _heart(st)
		"fermata": _fermata(st)
		"spirit": _spirit(st)
		"lyre": _lyre(st)
		"lute_ghost": _lute_ghost(st)
		"rosette", "rosette_ink": _rosette(st)
		"soundwave": _soundwave(st)
		"soundwave_ink": _soundwave(st, false)
		"stave": _stave(st)
		"score": _score(st)
		"drum_ring": _drum_ring(st)
		"cracked_stave": _cracked_stave(st)
		"curtain": _curtain(st)
		"spotlight": _spotlight(st)
		"stage": _stage_mesh(st)
		"pips2", "pips3", "pips4", "pips5": _pips(st, int(kind.substr(4)))
		_: _rosette(st)
	# Tone the heat down once: additive light near 1.0 turns white on a bright field.
	var arrays := st.commit_to_arrays()
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var tone := float(TONE.get(kind.substr(0, 4) if kind.begins_with("pips") else kind, 1.0))
	for i in colors.size():
		colors[i].r *= tone
	arrays[Mesh.ARRAY_COLOR] = colors
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[kind] = result
	return result


static func _p(v: Vector2, z := 0.0) -> Vector3:
	return Vector3(v.x, v.y, z)


## A filled tilted oval in the XY plane with a soft halo round it.
static func _oval(st: SurfaceTool, centre: Vector2, radii: Vector2, tilt: float, core: Color, rim: Color, halo := 1.25, z := 0.0, seg := 16) -> void:
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var p0 := centre + Vector2(cos(a0) * radii.x, sin(a0) * radii.y).rotated(tilt)
		var p1 := centre + Vector2(cos(a1) * radii.x, sin(a1) * radii.y).rotated(tilt)
		_tri(st, _p(centre, z), _p(p0, z), _p(p1, z), core, rim, rim)
		if halo > 1.0:
			var h0 := centre + (p0 - centre) * halo
			var h1 := centre + (p1 - centre) * halo
			_quad(st, _p(p0, z - 0.004), _p(p1, z - 0.004), _p(h1, z - 0.004), _p(h0, z - 0.004), Color(rim.r * 0.6, 0.35, 0), Color(rim.r * 0.6, 0.35, 0), Color(0.2, 0, 0), Color(0.2, 0, 0))


## A polyline of flat strips in the XY plane, tapering from [param w0] to [param w1].
static func _polyline(st: SurfaceTool, points: Array, w0: float, w1: float, c0: Color, c1: Color, z := 0.0) -> void:
	var n := points.size() - 1
	for i in n:
		var t0 := float(i) / float(n)
		var t1 := float(i + 1) / float(n)
		_strip(st, _p(points[i], z), _p(points[i + 1], z), lerpf(w0, w1, t0), Vector3.BACK, c0.lerp(c1, t0), c0.lerp(c1, t1), lerpf(w0, w1, t1))


## A flat ring on the ground (XZ) from [param inner] to [param outer] at height [param y].
static func _ground_ring(st: SurfaceTool, inner: float, outer: float, y: float, c_in: Color, c_out: Color, seg := 48, from := 0.0, to := TAU) -> void:
	for i in seg:
		var a0 := lerpf(from, to, float(i) / float(seg))
		var a1 := lerpf(from, to, float(i + 1) / float(seg))
		var d0 := Vector3(sin(a0), 0, cos(a0))
		var d1 := Vector3(sin(a1), 0, cos(a1))
		_quad(st, d0 * inner + Vector3.UP * y, d1 * inner + Vector3.UP * y, d1 * outer + Vector3.UP * y, d0 * outer + Vector3.UP * y, c_in, c_in, c_out, c_out)


## An upright band (a slice of a cylinder) of radius [param r] from [param y0] to [param y1].
static func _band(st: SurfaceTool, r: float, y0: float, y1: float, c0: Color, c1: Color, seg := 40, from := 0.0, to := TAU) -> void:
	for i in seg:
		var a0 := lerpf(from, to, float(i) / float(seg))
		var a1 := lerpf(from, to, float(i + 1) / float(seg))
		var d0 := Vector3(sin(a0), 0, cos(a0)) * r
		var d1 := Vector3(sin(a1), 0, cos(a1)) * r
		_quad(st, d0 + Vector3.UP * y0, d1 + Vector3.UP * y0, d1 + Vector3.UP * y1, d0 + Vector3.UP * y1, c0, c0, c1, c1)


## A five-point (or [param points]-point) star fan lying on the ground at [param at].
static func _ground_star(st: SurfaceTool, at: Vector3, outer: float, inner: float, color: Color, points := 5, turn := 0.0) -> void:
	for i in points * 2:
		var a0 := turn + PI * float(i) / float(points)
		var a1 := turn + PI * float(i + 1) / float(points)
		var r0 := outer if i % 2 == 0 else inner
		var r1 := outer if i % 2 == 1 else inner
		_tri(st, at, at + Vector3(sin(a0), 0, cos(a0)) * r0, at + Vector3(sin(a1), 0, cos(a1)) * r1, color, color, color)


## An eighth note on the XY plane (y 0-1): a tilted head low left, a stem and a flag.
static func _note(st: SurfaceTool) -> void:
	_oval(st, Vector2(-0.12, 0.13), Vector2(0.17, 0.12), 0.38, Color(1, 1, 0), Color(0.85, 1, 0))
	_strip(st, Vector3(0.05, 0.14, 0), Vector3(0.05, 0.96, 0), 0.05, Vector3.BACK, Color(0.75, 1, 0), Color(0.75, 1, 0))
	_polyline(st, [Vector2(0.05, 0.96), Vector2(0.2, 0.86), Vector2(0.3, 0.72), Vector2(0.27, 0.56)], 0.07, 0.025, Color(0.8, 1, 0), Color(0.6, 0.85, 0))
	# A soft glow along the stem so the note reads at a distance.
	_strip(st, Vector3(0.05, 0.14, -0.004), Vector3(0.05, 0.96, -0.004), 0.16, Vector3.BACK, Color(0.4, 0.25, 0), Color(0.3, 0.12, 0))


## A beamed pair of eighth notes (x ±0.45, y 0-1).
static func _notes(st: SurfaceTool) -> void:
	for head in [[Vector2(-0.30, 0.10), 0.86], [Vector2(0.24, 0.0), 0.78]]:
		var h: Vector2 = head[0]
		var x := h.x + 0.15
		_oval(st, h, Vector2(0.17, 0.12), 0.38, Color(1, 1, 0), Color(0.85, 1, 0))
		_strip(st, Vector3(x, h.y + 0.04, 0), Vector3(x, float(head[1]), 0), 0.05, Vector3.BACK, Color(0.75, 1, 0), Color(0.8, 1, 0))
		_strip(st, Vector3(x, h.y + 0.04, -0.004), Vector3(x, float(head[1]), -0.004), 0.15, Vector3.BACK, Color(0.35, 0.22, 0), Color(0.3, 0.12, 0))
	_strip(st, Vector3(-0.15, 0.86, 0), Vector3(0.39, 0.78, 0), 0.09, Vector3.BACK, Color(0.9, 1, 0), Color(0.9, 1, 0))
	_strip(st, Vector3(-0.15, 0.74, 0), Vector3(0.39, 0.66, 0), 0.05, Vector3.BACK, Color(0.75, 0.9, 0), Color(0.75, 0.9, 0))


## A treble clef (y -0.25 to 1.35): one tube round the spine, the top loop and the
## big spiral round the G line, a ball at the tail.
static func _treble(st: SurfaceTool) -> void:
	var pts: Array = [Vector2(-0.12, -0.12), Vector2(-0.04, -0.22), Vector2(0.06, -0.2), Vector2(0.1, -0.08), Vector2(0.08, 0.1),
		Vector2(0.04, 0.4), Vector2(0.0, 0.7), Vector2(-0.02, 0.95), Vector2(0.0, 1.15), Vector2(0.08, 1.3), Vector2(0.15, 1.33),
		Vector2(0.17, 1.22), Vector2(0.08, 1.05), Vector2(-0.06, 0.88), Vector2(-0.2, 0.7), Vector2(-0.28, 0.5), Vector2(-0.26, 0.3),
		Vector2(-0.16, 0.14), Vector2(0.0, 0.08), Vector2(0.18, 0.12), Vector2(0.28, 0.26), Vector2(0.26, 0.42), Vector2(0.14, 0.52),
		Vector2(0.0, 0.52), Vector2(-0.1, 0.44), Vector2(-0.12, 0.32), Vector2(-0.04, 0.24), Vector2(0.06, 0.28)]
	var points: Array = []
	var radii: Array = []
	var colors: Array = []
	for i in pts.size():
		var belly := 1.0 if i >= 14 and i <= 22 else 0.0
		points.append(_p(pts[i]))
		radii.append(0.035 + 0.015 * belly)
		colors.append(Color(0.8 + 0.2 * belly, 1, 0))
	_tube(st, points, radii, colors, 5)
	_sphere(st, Vector3(-0.15, -0.1, 0), Vector3.ONE * 0.07, Color(1, 1, 0), 3, 6)
	# A soft halo behind the clef's belly.
	_oval(st, Vector2(0.0, 0.32), Vector2(0.36, 0.3), 0.0, Color(0.35, 0.2, 0), Color(0.2, 0, 0), 1.0, -0.04, 20)


## A tear-note: a teardrop head (point up) and a stem drooping to the left like a wilted flag.
static func _tear_note(st: SurfaceTool) -> void:
	var c := Vector2(-0.05, 0.12)
	var seg := 18
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var d0 := 0.13 * (1.0 + 1.1 * pow(maxf(cos(a0), 0.0), 6.0))
		var d1 := 0.13 * (1.0 + 1.1 * pow(maxf(cos(a1), 0.0), 6.0))
		_tri(st, _p(c), _p(c + Vector2(sin(a0), cos(a0)) * d0), _p(c + Vector2(sin(a1), cos(a1)) * d1), Color(0.9, 1, 0), Color(0.75, 1, 0), Color(0.75, 1, 0))
		_quad(st, _p(c + Vector2(sin(a0), cos(a0)) * d0, -0.004), _p(c + Vector2(sin(a1), cos(a1)) * d1, -0.004), _p(c + Vector2(sin(a1), cos(a1)) * d1 * 1.3, -0.004), _p(c + Vector2(sin(a0), cos(a0)) * d0 * 1.3, -0.004), Color(0.45, 0.35, 0), Color(0.45, 0.35, 0), Color(0.2, 0, 0), Color(0.2, 0, 0))
	_polyline(st, [Vector2(0.07, 0.14), Vector2(0.07, 0.62), Vector2(-0.03, 0.7), Vector2(-0.12, 0.6)], 0.045, 0.02, Color(0.6, 1, 0), Color(0.55, 0.8, 0))


## A heart: a bright rim and a softer fill (about 1.0 x 0.95, centred).
static func _heart(st: SurfaceTool) -> void:
	var outline: Array = []
	for i in 40:
		var t := TAU * float(i) / 40.0
		outline.append(Vector2(16.0 * pow(sin(t), 3.0), 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)) / 32.0 + Vector2(0, 0.08))
	var centre := Vector2(0, 0.02)
	for i in 40:
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % 40]
		var ai := centre + (a - centre) * 0.88
		var bi := centre + (b - centre) * 0.88
		_tri(st, _p(centre), _p(ai), _p(bi), Color(0.55, 0.6, 0), Color(0.4, 0.6, 0), Color(0.4, 0.6, 0))
		_quad(st, _p(ai), _p(bi), _p(b), _p(a), Color(0.9, 1, 0), Color(0.9, 1, 0), Color(1, 1, 0), Color(1, 1, 0))
		_quad(st, _p(a, -0.004), _p(b, -0.004), _p(centre + (b - centre) * 1.18, -0.004), _p(centre + (a - centre) * 1.18, -0.004), Color(0.5, 0.35, 0), Color(0.5, 0.35, 0), Color(0.2, 0, 0), Color(0.2, 0, 0))


## A fermata (the musical hold): a semicircle arc over a dot, with a soft halo.
static func _fermata(st: SurfaceTool) -> void:
	var centre := Vector2(0, 0.1)
	for i in 24:
		var a0 := PI * float(i) / 24.0
		var a1 := PI * float(i + 1) / 24.0
		var w0 := 0.035 + 0.02 * sin(a0)
		var w1 := 0.035 + 0.02 * sin(a1)
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		_quad(st, _p(centre + d0 * (0.5 - w0)), _p(centre + d1 * (0.5 - w1)), _p(centre + d1 * (0.5 + w1)), _p(centre + d0 * (0.5 + w0)), Color(0.9, 1, 0), Color(0.9, 1, 0), Color(0.9, 1, 0), Color(0.9, 1, 0))
		_quad(st, _p(centre + d0 * (0.5 + w0), -0.004), _p(centre + d1 * (0.5 + w1), -0.004), _p(centre + d1 * 0.68, -0.004), _p(centre + d0 * 0.68, -0.004), Color(0.5, 0.35, 0), Color(0.5, 0.35, 0), Color(0.2, 0, 0), Color(0.2, 0, 0))
	_sphere(st, _p(centre), Vector3.ONE * 0.08, Color(1, 1, 0), 3, 8)
	_oval(st, centre, Vector2(0.1, 0.1), 0.0, Color(0.6, 0.45, 0), Color(0.5, 0.4, 0), 2.2, -0.01, 16)


## A choir spirit (y 0-1): a robe of light, a round head singing an "o", two small wings, a note.
static func _spirit(st: SurfaceTool) -> void:
	var robe: Array = [Vector2(0, 0.66), Vector2(-0.09, 0.6), Vector2(-0.12, 0.45), Vector2(-0.15, 0.25), Vector2(-0.18, 0.05), Vector2(-0.1, -0.02),
		Vector2(0, 0.02), Vector2(0.1, -0.02), Vector2(0.18, 0.05), Vector2(0.15, 0.25), Vector2(0.12, 0.45), Vector2(0.09, 0.6)]
	var centre := Vector2(0, 0.32)
	for i in robe.size():
		var a: Vector2 = robe[i]
		var b: Vector2 = robe[(i + 1) % robe.size()]
		_tri(st, _p(centre), _p(a), _p(b), Color(0.45, 0.9, 0), Color(0.5, 0.25 + 0.6 * a.y, 0), Color(0.5, 0.25 + 0.6 * b.y, 0))
	_oval(st, Vector2(0, 0.77), Vector2(0.13, 0.13), 0.0, Color(0.55, 1, 0), Color(0.75, 1, 0), 1.45, 0.0, 18)
	# The singing mouth: a bright "o".
	for i in 12:
		var a0 := TAU * float(i) / 12.0
		var a1 := TAU * float(i + 1) / 12.0
		var o := Vector2(0, 0.73)
		_quad(st, _p(o + Vector2(cos(a0), sin(a0)) * 0.02, 0.006), _p(o + Vector2(cos(a1), sin(a1)) * 0.02, 0.006), _p(o + Vector2(cos(a1), sin(a1)) * 0.035, 0.006), _p(o + Vector2(cos(a0), sin(a0)) * 0.035, 0.006), Color(1, 1, 0), Color(1, 1, 0), Color(1, 1, 0), Color(1, 1, 0))
	for s: float in [-1.0, 1.0]:
		for tip: Vector2 in [Vector2(0.34, 0.84), Vector2(0.37, 0.68), Vector2(0.31, 0.52)]:
			_polyline(st, [Vector2(s * 0.08, 0.58), Vector2(s * tip.x, tip.y)], 0.06, 0.012, Color(0.7, 0.9, 0), Color(0.45, 0.45, 0))
	# A tiny note above the singer.
	_oval(st, Vector2(0.17, 0.92), Vector2(0.045, 0.032), 0.38, Color(1, 1, 0), Color(0.9, 1, 0), 1.0)
	_strip(st, Vector3(0.21, 0.93, 0), Vector3(0.21, 1.07, 0), 0.016, Vector3.BACK, Color(1, 1, 0), Color(1, 1, 0))
	_strip(st, Vector3(0.21, 1.07, 0), Vector3(0.27, 1.02, 0), 0.018, Vector3.BACK, Color(1, 1, 0), Color(0.8, 1, 0))


## A great lyre (y 0-1.6): two curling horns, a crossbar with a gem, a sound box and seven strings.
static func _lyre(st: SurfaceTool) -> void:
	for s: float in [-1.0, 1.0]:
		var horn: Array = []
		for p: Vector2 in [Vector2(0.18, 0.12), Vector2(0.42, 0.45), Vector2(0.46, 0.85), Vector2(0.33, 1.2), Vector2(0.40, 1.45), Vector2(0.52, 1.52)]:
			horn.append(Vector3(s * p.x, p.y, 0))
		_tube(st, horn, [0.05, 0.048, 0.044, 0.038, 0.03, 0.025], [Color(0.85, 1, 0), Color(0.85, 1, 0), Color(0.9, 1, 0), Color(0.85, 1, 0), Color(0.9, 1, 0), Color(1, 1, 0)], 6)
		_sphere(st, Vector3(s * 0.54, 1.53, 0), Vector3.ONE * 0.04, Color(1, 1, 0), 2, 6)
	_tube(st, [Vector3(-0.37, 1.30, 0), Vector3(0.37, 1.30, 0)], [0.032, 0.032], [Color(0.9, 1, 0), Color(0.9, 1, 0)], 6)
	_sphere(st, Vector3(0, 0.12, 0), Vector3(0.3, 0.1, 0.08), Color(0.8, 1, 0), 4, 10)
	for k in 7:
		var x := -0.21 + 0.07 * float(k)
		_strip(st, Vector3(x, 0.18, 0.01), Vector3(x, 1.30, 0.01), 0.014, Vector3.BACK, Color(1, 0.95, 0), Color(1, 0.9, 0))
	_sphere(st, Vector3(0, 1.30, 0.03), Vector3.ONE * 0.065, Color(1, 1, 0), 3, 8)
	# The light the strings throw: a soft halo inside the frame.
	_oval(st, Vector2(0, 0.75), Vector2(0.36, 0.62), 0.0, Color(0.4, 0.3, 0), Color(0.2, 0, 0), 1.0, -0.03, 24)


static func _pear(i: int, count: int) -> Vector2:
	var a := TAU * float(i) / float(count)
	var p := Vector2(sin(a) * 0.42, 0.40 - cos(a) * 0.40)
	if p.y > 0.40:
		var u := smoothstep(0.40, 0.80, p.y)
		p = Vector2(p.x * lerpf(1.0, 0.13, u), 0.40 + (p.y - 0.40) * 1.375)
	return p


## A spectral lute (y 0-2.0): a pear bowl with a bright rim and rosette, a fretted
## neck, the pegbox bent back with its pegs and six strings of light.
static func _lute_ghost(st: SurfaceTool) -> void:
	var centre := Vector2(0, 0.45)
	for i in 20:
		var a := _pear(i, 20)
		var b := _pear(i + 1, 20)
		_tri(st, _p(centre), _p(a), _p(b), Color(0.2, 0.22, 0), Color(0.35, 0.45, 0), Color(0.35, 0.45, 0))
		_quad(st, _p(centre + (a - centre) * 0.94, 0.004), _p(centre + (b - centre) * 0.94, 0.004), _p(b, 0.004), _p(a, 0.004), Color(0.9, 1, 0), Color(0.9, 1, 0), Color(0.9, 1, 0), Color(0.9, 1, 0))
		_quad(st, _p(a, -0.006), _p(b, -0.006), _p(centre + (b - centre) * 1.16, -0.006), _p(centre + (a - centre) * 1.16, -0.006), Color(0.45, 0.4, 0), Color(0.45, 0.4, 0), Color(0.2, 0, 0), Color(0.2, 0, 0))
	# The rosette: a ring and a little ten-point star.
	for i in 20:
		var a0 := TAU * float(i) / 20.0
		var a1 := TAU * float(i + 1) / 20.0
		var o := Vector2(0, 0.5)
		_quad(st, _p(o + Vector2(cos(a0), sin(a0)) * 0.09, 0.01), _p(o + Vector2(cos(a1), sin(a1)) * 0.09, 0.01), _p(o + Vector2(cos(a1), sin(a1)) * 0.12, 0.01), _p(o + Vector2(cos(a0), sin(a0)) * 0.12, 0.01), Color(1, 1, 0), Color(1, 1, 0), Color(1, 1, 0), Color(1, 1, 0))
	for i in 20:
		var a0 := PI * float(i) / 10.0
		var a1 := PI * float(i + 1) / 10.0
		var r0 := 0.075 if i % 2 == 0 else 0.03
		var r1 := 0.075 if i % 2 == 1 else 0.03
		_tri(st, Vector3(0, 0.5, 0.012), Vector3(sin(a0) * r0, 0.5 + cos(a0) * r0, 0.012), Vector3(sin(a1) * r1, 0.5 + cos(a1) * r1, 0.012), Color(1, 0.85, 0), Color(1, 0.85, 0), Color(1, 0.85, 0))
	# Neck, frets, pegbox and pegs.
	_strip(st, Vector3(0, 0.9, 0.006), Vector3(0, 1.62, 0.006), 0.1, Vector3.BACK, Color(0.45, 0.95, 0), Color(0.5, 0.95, 0), 0.085)
	for k in 7:
		var y := 0.98 + 0.09 * float(k)
		_strip(st, Vector3(-0.052, y, 0.01), Vector3(0.052, y, 0.01), 0.014, Vector3.BACK, Color(0.9, 1, 0), Color(0.9, 1, 0))
	_polyline(st, [Vector2(0, 1.6), Vector2(-0.08, 1.78), Vector2(-0.2, 1.9)], 0.09, 0.065, Color(0.5, 0.95, 0), Color(0.6, 1, 0), 0.006)
	for k in 6:
		var t := 0.2 + 0.13 * float(k)
		var at := Vector2(0, 1.6).lerp(Vector2(-0.2, 1.9), t)
		var side := 1.0 if k % 2 == 0 else -1.0
		_sphere(st, Vector3(at.x + side * 0.06, at.y + side * 0.03, 0.01), Vector3.ONE * 0.026, Color(1, 1, 0), 2, 6)
	_strip(st, Vector3(-0.13, 0.22, 0.01), Vector3(0.13, 0.22, 0.01), 0.03, Vector3.BACK, Color(0.9, 1, 0), Color(0.9, 1, 0))
	for k in 6:
		var x := -0.1 + 0.04 * float(k)
		_strip(st, Vector3(x, 0.22, 0.014), Vector3(x * 0.5, 1.62, 0.014), 0.009, Vector3.BACK, Color(1, 0.9, 0), Color(1, 0.85, 0))


## The lute's sound hole as a ground rosette (r 1): four rings, ten lace petals,
## a ten-point star at the heart and a band of ticks.
static func _rosette(st: SurfaceTool) -> void:
	for ring in [[1.0, 0.03, 0.85], [0.85, 0.02, 0.75], [0.62, 0.02, 0.75], [0.26, 0.022, 0.9]]:
		var r := float(ring[0])
		var w := float(ring[1])
		_ground_ring(st, r - w * 0.5, r + w * 0.5, 0.0, Color(float(ring[2]), 0.95, 0), Color(float(ring[2]), 0.95, 0), 56)
	_ground_ring(st, 0.9, 0.985, -0.002, Color(0.25, 0.0, 0), Color(0.4, 0.35, 0), 56)
	for k in 10:
		var a := TAU * float(k) / 10.0
		for side: float in [-1.0, 1.0]:
			var prev := Vector3.ZERO
			for j in 9:
				var t := float(j) / 8.0
				var rr := lerpf(0.30, 0.95, t)
				var ang := a + side * 0.18 * sin(PI * t)
				var p := Vector3(sin(ang), 0.001, cos(ang)) * rr
				if j > 0:
					_strip(st, prev, p, 0.02, Vector3.UP, Color(0.6, 0.8, 0), Color(0.6, 0.8, 0))
				prev = p
		_ground_star(st, Vector3(sin(a), 0.001, cos(a)) * 0.74, 0.04, 0.016, Color(1, 1, 0), 4, a)
	_ground_star(st, Vector3.UP * 0.002, 0.22, 0.09, Color(1, 1, 0), 10)
	for k in 40:
		var a := TAU * float(k) / 40.0
		var dir := Vector3(sin(a), 0, cos(a))
		_strip(st, dir * 0.88, dir * 0.96, 0.012, Vector3.UP, Color(0.75, 0.85, 0), Color(0.75, 0.85, 0))


## Three quavering sound rings on the ground (a bright front and two fading echoes),
## each edge rippling like a plucked string.
static func _soundwave(st: SurfaceTool, wash := true) -> void:
	# Thin bands: the ring is scaled by the skill's whole radius, so a wide band would
	# become a white road on a big area. The edge quavers in 24 small waves.
	for ring in [[1.0, 0.016, 1.0], [0.84, 0.011, 0.7], [0.68, 0.008, 0.45]]:
		var r := float(ring[0])
		# The ink version (on the ground) is drawn solid, so its bands run thinner.
		var w := float(ring[1]) * (1.0 if wash else 0.7)
		var tone := float(ring[2])
		for i in 96:
			var a0 := TAU * float(i) / 96.0
			var a1 := TAU * float(i + 1) / 96.0
			var r0 := r + 0.012 * sin(24.0 * a0 + r * 7.0)
			var r1 := r + 0.012 * sin(24.0 * a1 + r * 7.0)
			var d0 := Vector3(sin(a0), 0, cos(a0))
			var d1 := Vector3(sin(a1), 0, cos(a1))
			_quad(st, d0 * (r0 - w), d1 * (r1 - w), d1 * (r1 + w), d0 * (r0 + w), Color(tone, tone, 0), Color(tone, tone, 0), Color(tone, tone, 0), Color(tone, tone, 0))
			if wash and tone >= 1.0:
				# The bright front trails a soft wash inwards.
				_quad(st, d0 * (r0 - w - 0.07), d1 * (r1 - w - 0.07), d1 * (r1 - w), d0 * (r0 - w), Color(0.2, 0, 0), Color(0.2, 0, 0), Color(0.5, 0.35, 0), Color(0.5, 0.35, 0))


## Five staff lines round a ring (r 1, open at -Z) with seven notes riding them.
static func _stave(st: SurfaceTool) -> void:
	var from := deg_to_rad(-165.0)
	var to := deg_to_rad(165.0)
	for j in 5:
		var y := 0.08 * float(j)
		_band(st, 1.0, y - 0.012, y + 0.012, Color(0.65, 0.9, 0), Color(0.65, 0.9, 0), 44, from, to)
	# A faint glow band behind the staff.
	_band(st, 1.0, -0.04, 0.36, Color(0.3, 0.12, 0), Color(0.3, 0.12, 0), 44, from, to)
	var heights := [0.0, 0.12, 0.24, 0.08, 0.20, 0.04, 0.16]
	var angles := [0.0, 40.0, 85.0, 130.0, 205.0, 250.0, 300.0]
	for k in 7:
		var a := deg_to_rad(float(angles[k]))
		var dir := Vector3(sin(a), 0, cos(a))
		var tangent := Vector3(cos(a), 0, -sin(a))
		var head := dir * 1.01 + Vector3.UP * float(heights[k])
		_sphere(st, head, Vector3(0.06, 0.042, 0.06), Color(1, 1, 0), 3, 6)
		_tube(st, [head + tangent * 0.05, head + tangent * 0.05 + Vector3.UP * 0.18], [0.01, 0.008], [Color(0.9, 1, 0), Color(0.9, 1, 0)], 4)


## A straight staff along +Z (z 0-1) swaying gently, four notes on its lines.
static func _score(st: SurfaceTool) -> void:
	for j in 5:
		var y := 0.08 * float(j)
		for i in 20:
			var z0 := float(i) / 20.0
			var z1 := float(i + 1) / 20.0
			var x0 := 0.05 * sin(z0 * TAU * 1.5)
			var x1 := 0.05 * sin(z1 * TAU * 1.5)
			var fade0 := Color(0.6, 0.85 * smoothstep(0.0, 0.15, z0) * (1.0 - smoothstep(0.85, 1.0, z0)), 0)
			var fade1 := Color(0.6, 0.85 * smoothstep(0.0, 0.15, z1) * (1.0 - smoothstep(0.85, 1.0, z1)), 0)
			_quad(st, Vector3(x0, y - 0.014, z0), Vector3(x1, y - 0.014, z1), Vector3(x1, y + 0.014, z1), Vector3(x0, y + 0.014, z0), fade0, fade1, fade1, fade0)
			_quad(st, Vector3(x0 - 0.014, y, z0), Vector3(x1 - 0.014, y, z1), Vector3(x1 + 0.014, y, z1), Vector3(x0 + 0.014, y, z0), fade0, fade1, fade1, fade0)
	var heights := [0.04, 0.16, 0.08, 0.24]
	for k in 4:
		var z: float = [0.2, 0.42, 0.64, 0.86][k]
		var x := 0.05 * sin(z * TAU * 1.5)
		var head := Vector3(x, float(heights[k]), z)
		_sphere(st, head, Vector3(0.07, 0.05, 0.02), Color(1, 1, 0), 3, 6)
		_strip(st, head + Vector3(0.06, 0, 0), head + Vector3(0.06, 0.2, 0), 0.016, Vector3.BACK, Color(0.9, 1, 0), Color(0.9, 1, 0))


## A drum head on the ground (r 1): the skin, a shell, the rim, a beat ring,
## zig-zag rope lacing and eight tension pegs.
static func _drum_ring(st: SurfaceTool) -> void:
	for i in 40:
		var a0 := TAU * float(i) / 40.0
		var a1 := TAU * float(i + 1) / 40.0
		_tri(st, Vector3.UP * 0.12, Vector3(sin(a0), 0.12, cos(a0)) * Vector3(0.94, 1, 0.94), Vector3(sin(a1), 0.12, cos(a1)) * Vector3(0.94, 1, 0.94), Color(0.25, 0.55, 0), Color(0.2, 0.6, 0), Color(0.2, 0.6, 0))
	_band(st, 1.0, 0.0, 0.12, Color(0.35, 0.9, 0), Color(0.6, 1, 0), 40)
	_ground_ring(st, 0.94, 1.0, 0.125, Color(1, 1, 0), Color(1, 1, 0), 40)
	_ground_ring(st, 0.33, 0.36, 0.125, Color(0.8, 0.9, 0), Color(0.8, 0.9, 0), 40)
	for k in 24:
		var a0 := TAU * float(k) / 24.0
		var a1 := TAU * (float(k) + 0.5) / 24.0
		var p0 := Vector3(sin(a0), 0.0, cos(a0)) * 1.005 + Vector3.UP * 0.115
		var p1 := Vector3(sin(a1), 0.0, cos(a1)) * 1.005 + Vector3.UP * 0.01
		var p2 := Vector3(sin(TAU * float(k + 1) / 24.0), 0.0, cos(TAU * float(k + 1) / 24.0)) * 1.005 + Vector3.UP * 0.115
		_strip(st, p0, p1, 0.018, Vector3(sin(a0), 0, cos(a0)), Color(0.7, 0.9, 0), Color(0.7, 0.9, 0))
		_strip(st, p1, p2, 0.018, Vector3(sin(a1), 0, cos(a1)), Color(0.7, 0.9, 0), Color(0.7, 0.9, 0))
	for k in 8:
		var a := TAU * float(k) / 8.0
		_sphere(st, Vector3(sin(a), 0, cos(a)) * 0.97 + Vector3.UP * 0.13, Vector3.ONE * 0.035, Color(1, 1, 0), 2, 6)


## Five concentric staff rings broken by four jagged gaps, shards lifted off the breaks.
static func _cracked_stave(st: SurfaceTool) -> void:
	var gaps := [20.0, 110.0, 200.0, 290.0]
	for j in 5:
		var r := 0.60 + 0.09 * float(j)
		for g in 4:
			var jitter := 4.0 * sin(float(j * 3 + g) * 1.7)
			var start := deg_to_rad(float(gaps[g]) + 7.0 + jitter)
			var end := deg_to_rad(float(gaps[(g + 1) % 4]) + (360.0 if g == 3 else 0.0) - 7.0 + 4.0 * sin(float(j * 5 + g) * 2.3))
			_ground_ring(st, r - 0.008, r + 0.008, 0.0, Color(0.7, 0.95, 0), Color(0.7, 0.95, 0), 14, start, end)
	for k in 10:
		var g := deg_to_rad(float(gaps[k % 4]) + 6.0 * sin(float(k) * 2.1))
		var r := 0.62 + 0.035 * float(k)
		var at := Vector3(sin(g), 0.02 + 0.008 * float(k), cos(g)) * Vector3(r, 1, r)
		var s := 0.05 + 0.005 * float(k)
		var tilt := Vector3(cos(g + float(k)), 0.4, sin(g - float(k))).normalized() * s
		_tri(st, at, at + tilt + Vector3.UP * s * 0.6, at + Vector3(sin(g + 0.4), 0.03, cos(g + 0.4)) * s * 1.4, Color(1, 1, 0), Color(1, 1, 0), Color(0.85, 1, 0))


## A theatre drape (XY plane facing +Z; x 0-1 from the opening to the outer edge, y 0-1):
## velvet folds gathered by a gold tie-back at the inner edge, a scalloped gold valance
## along the top and a hem. Mirrored (negative x scale) for the other side of the stage.
static func _drape(u: float, y: float) -> Vector3:
	var tie := exp(-pow((y - 0.42) / 0.18, 2.0))
	var inner := 0.34 * tie + 0.1 * (1.0 - y) * (1.0 - tie)
	var fold := sin(u * TAU * 3.5)
	return Vector3(lerpf(inner, 1.0, u), y, 0.07 * fold * (1.0 - 0.6 * tie))


static func _curtain(st: SurfaceTool) -> void:
	var cols := 18
	var rows := 10
	for i in cols:
		for j in rows:
			var u0 := float(i) / float(cols)
			var u1 := float(i + 1) / float(cols)
			var y0 := float(j) / float(rows) * 0.88
			var y1 := float(j + 1) / float(rows) * 0.88
			var corners := [[u0, y0], [u1, y0], [u1, y1], [u0, y1]]
			var pts: Array = []
			var tones: Array = []
			for uv in corners:
				pts.append(_drape(float(uv[0]), float(uv[1])))
				tones.append(Color(0.12 + 0.32 * maxf(sin(float(uv[0]) * TAU * 3.5), 0.0), 1, 0))
			_quad(st, pts[0], pts[1], pts[2], pts[3], tones[0], tones[1], tones[2], tones[3])
	# The hem, a gold line along the bottom.
	var hem: Array = []
	for i in cols + 1:
		hem.append(_drape(float(i) / float(cols), 0.0) + Vector3(0, 0.02, 0.012))
	_tube(st, hem, hem.map(func(_v): return 0.014), hem.map(func(_v): return Color(0.8, 1, 0)), 4)
	# The valance: six gold scallops along the top.
	for i in 36:
		var u0 := float(i) / 36.0
		var u1 := float(i + 1) / 36.0
		var b0 := 0.86 - 0.07 * absf(sin(u0 * PI * 6.0))
		var b1 := 0.86 - 0.07 * absf(sin(u1 * PI * 6.0))
		var x0 := lerpf(-0.04, 1.04, u0)
		var x1 := lerpf(-0.04, 1.04, u1)
		_quad(st, Vector3(x0, b0, 0.09), Vector3(x1, b1, 0.09), Vector3(x1, 1.0, 0.09), Vector3(x0, 1.0, 0.09), Color(0.55, 1, 0), Color(0.55, 1, 0), Color(0.75, 1, 0), Color(0.75, 1, 0))
		_quad(st, Vector3(x0, 1.0, 0.09), Vector3(x1, 1.0, 0.09), Vector3(x1, 1.03, 0.09), Vector3(x0, 1.03, 0.09), Color(0.95, 1, 0), Color(0.95, 1, 0), Color(0.95, 1, 0), Color(0.95, 1, 0))
	# The tie-back cord round the gathered drape, with a tassel.
	var cord: Array = []
	for k in 7:
		var t := float(k) / 6.0
		var at := _drape(lerpf(0.0, 0.55, t), 0.42)
		cord.append(Vector3(at.x, at.y - 0.02 * sin(PI * t), 0.11))
	_tube(st, cord, cord.map(func(_v): return 0.02), cord.map(func(_v): return Color(0.95, 1, 0)), 5)
	_sphere(st, cord[0] + Vector3(0, -0.06, 0), Vector3(0.03, 0.06, 0.03), Color(1, 1, 0), 3, 6)


## An open cone of light from a bright source at apex y 1 down to a pool on the ground
## at y 0. The cone thins out towards the foot so whoever stands in it stays readable;
## the pool's rim is bright.
static func _spotlight(st: SurfaceTool) -> void:
	for i in 24:
		var a0 := TAU * float(i) / 24.0
		var a1 := TAU * float(i + 1) / 24.0
		var d0 := Vector3(sin(a0), 0, cos(a0))
		var d1 := Vector3(sin(a1), 0, cos(a1))
		var foot := Color(0.25, 0.06, 0)
		var mid := Color(0.4, 0.2, 0)
		var top := Color(0.8, 0.5, 0)
		_quad(st, d0, d1, d1 * 0.53 + Vector3.UP * 0.5, d0 * 0.53 + Vector3.UP * 0.5, foot, foot, mid, mid)
		_quad(st, d0 * 0.53 + Vector3.UP * 0.5, d1 * 0.53 + Vector3.UP * 0.5, d1 * 0.06 + Vector3.UP, d0 * 0.06 + Vector3.UP, mid, mid, top, top)
	_sphere(st, Vector3.UP, Vector3(0.1, 0.02, 0.1), Color(1, 1, 0), 3, 8)
	_ground_ring(st, 0.9, 1.0, 0.01, Color(0.9, 0.85, 0), Color(0.9, 0.85, 0), 40)
	_ground_ring(st, 0.0, 0.9, 0.005, Color(0.3, 0.12, 0), Color(0.45, 0.3, 0), 40)


## A concert stage (r 1): a lit rim, a translucent floor with a star inlay, two
## steps, a skirt and sixteen footlights.
static func _stage_mesh(st: SurfaceTool) -> void:
	_ground_ring(st, 0.0, 0.96, 0.10, Color(0.25, 0.1, 0), Color(0.2, 0.16, 0), 48)
	_ground_ring(st, 0.96, 1.0, 0.10, Color(1, 1, 0), Color(1, 1, 0), 48)
	_band(st, 1.0, 0.0, 0.10, Color(0.45, 0.7, 0), Color(0.6, 0.8, 0), 48)
	_ground_ring(st, 1.0, 1.06, 0.05, Color(0.7, 0.8, 0), Color(0.6, 0.7, 0), 48)
	_ground_ring(st, 1.06, 1.12, 0.0, Color(0.6, 0.7, 0), Color(0.4, 0.5, 0), 48)
	_ground_star(st, Vector3.UP * 0.104, 0.55, 0.22, Color(0.6, 0.6, 0), 8)
	_ground_ring(st, 0.58, 0.61, 0.104, Color(0.8, 0.8, 0), Color(0.8, 0.8, 0), 48)
	for k in 16:
		var a := TAU * float(k) / 16.0
		_sphere(st, Vector3(sin(a), 0, cos(a)) * 0.98 + Vector3.UP * 0.13, Vector3.ONE * 0.03, Color(1, 1, 0), 2, 6)


## [param n] gold rank stars round a ring at the feet (r 0.42), on a thin ring.
static func _pips(st: SurfaceTool, n: int) -> void:
	for k in n:
		var a := TAU * float(k) / float(n)
		_ground_star(st, Vector3(sin(a), 0.002, cos(a)) * 0.42, 0.08, 0.034, Color(1, 1, 0), 5, a)
	_ground_ring(st, 0.415, 0.425, 0.0, Color(0.5, 0.5, 0), Color(0.5, 0.5, 0), 40)
