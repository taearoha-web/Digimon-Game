class_name UltCutIn
extends CanvasLayer
## The ultimate cut-in: when the player's own hero casts a 200-star skill or its god
## skill (300 stars), a diagonal band in the class colour sweeps across the screen
## with the hero's portrait and the skill's Thai name, and time slows to SLOW_SCALE
## for a moment (about 0.3 s of real time), then eases back.
##
## Cheap on phones: one layer kept for the whole session (built once, hidden between
## uses), a handful of polygons and labels, the portrait the HUD already captured
## (no new 3D capture), animated by hand in real time.
##
## The clock: slow motion multiplies whatever Engine.time_scale was (a test's fast
## clock stays fast relative to itself), every gameplay timer and sequence slows with
## it so damage stays in step with its art, and it lets go at once without touching the
## clock again when anyone else changes Engine.time_scale meanwhile. HitFeel's hit-stop
## waits while it runs. Never in a duel or a guild war (the banner shows, shorter, and
## time runs on), never for AI casters (only Hero calls it), off with the "ฉากท่าไม้ตาย"
## setting.

const LENGTH := 0.74
const PVP_LENGTH := 0.45
const SLOW_SCALE := 0.35
## Real-time slow motion profile: ramp in, hold, ease back.
const SLOW_IN := 0.05
const SLOW_HOLD := 0.22
const SLOW_OUT := 0.40
## Game time the slow motion takes out of a cast (ms of the real clock the hero's
## cast lock must add so a new cast never starts under the sequence's tail).
const SLOW_DEBT_MS := 190

static var _layer_ref: WeakRef
static var _slowing := false
static var _applied := 1.0
static var _base := 1.0
static var shown_count := 0
static var last_name := ""

var _root: Node2D
## The band's tilt (radians): the sweep runs on a diagonal across the screen.
const TILT := -0.16
var _pivot: Node2D
var _shade: Polygon2D
var _band: Polygon2D
var _edge_a: Polygon2D
var _edge_b: Polygon2D
var _streaks: Array[Polygon2D] = []
var _portrait: TextureRect
var _emblem: Polygon2D
var _title: Label
var _sub: Label
var _flash: ColorRect
var _started := false
var _adding := false
## Seconds the cut-in has run: real time, but a hitch frame (the cast building its
## art) adds at most MAX_STEP, so a slow frame never eats the moment.
var _t := 0.0
const MAX_STEP := 0.05
var _length := LENGTH
var _slow := false
var _size := Vector2(1280, 720)
var _portrait_x := 0.0


## Shows the cut-in for [param skill] cast by [param hero]. Returns true when shown.
static func play(hero: Node, skill: Dictionary) -> bool:
	if hero == null or not hero.is_inside_tree() or not SkillWeight.is_ultimate(skill):
		return false
	GameSettings.load_settings()
	if not GameSettings.ult_cutin:
		return false
	var layer := _layer(hero.get_tree())
	var pvp := pvp_now()
	var view := hero.get_viewport()
	layer._begin(skill, pvp, view.get_visible_rect().size if view else Vector2(1280, 720))
	shown_count += 1
	last_name = layer._title.text
	return true


## A duel or a guild war: everyone's clock must run alike.
static func pvp_now() -> bool:
	return Game.in_duel() or GuildWarMatch.in_war()


static func slowing() -> bool:
	return _slowing


## Game time the slow motion of the cut-in now running takes out of a cast.
static func slow_debt_ms() -> int:
	return SLOW_DEBT_MS if _slowing else 0


static func active() -> UltCutIn:
	var layer: UltCutIn = _layer_ref.get_ref() if _layer_ref != null else null
	return layer if is_instance_valid(layer) else null


## Stops the banner and gives the clock back (zone change, tests).
static func stop_now() -> void:
	var layer := active()
	if layer:
		layer._finish()


static func _layer(tree: SceneTree) -> UltCutIn:
	var layer := active()
	if layer == null:
		layer = UltCutIn.new()
		layer.name = "UltCutIn"
		_layer_ref = weakref(layer)
	if not layer.is_inside_tree() and not layer._adding:
		# Deferred: a cast can come while the root is still setting up its children.
		layer._adding = true
		tree.root.add_child.call_deferred(layer)
	return layer


func _enter_tree() -> void:
	_adding = false


func _init() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _build() -> void:
	_flash = ColorRect.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	add_child(_flash)
	# Pivot at the screen centre, tilted; the band is drawn in screen coordinates under it.
	_pivot = Node2D.new()
	_pivot.rotation = TILT
	add_child(_pivot)
	_root = Node2D.new()
	_pivot.add_child(_root)
	_shade = Polygon2D.new()
	_shade.color = Color(0.02, 0.02, 0.08, 0.55)
	_root.add_child(_shade)
	_band = Polygon2D.new()
	_root.add_child(_band)
	for i in 6:
		var streak := Polygon2D.new()
		streak.color = Color(1, 1, 1, 0.55)
		_streaks.append(streak)
		_band.add_child(streak)
	_edge_a = Polygon2D.new()
	_edge_b = Polygon2D.new()
	_root.add_child(_edge_a)
	_root.add_child(_edge_b)
	_emblem = Polygon2D.new()
	_band.add_child(_emblem)
	_portrait = TextureRect.new()
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_band.add_child(_portrait)
	var font: Font = load("res://ui/theme/fonts/heading_font.tres")
	_title = Label.new()
	_title.add_theme_font_override("font", font)
	_title.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1))
	_title.add_theme_constant_override("outline_size", 14)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.add_child(_title)
	_sub = Label.new()
	_sub.add_theme_font_override("font", font)
	_sub.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1))
	_sub.add_theme_constant_override("outline_size", 8)
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.add_child(_sub)


func _begin(skill: Dictionary, pvp: bool, view_size: Vector2) -> void:
	# A new cut-in replaces one still running; its slow motion hands over cleanly.
	_release_clock(true)
	_size = view_size
	_pivot.position = _size * 0.5
	_root.position = -_size * 0.5
	var w := _size.x
	var h := _size.y
	var color: Color = skill.get("color", Color("ffd36b"))
	var job: Dictionary = Game.class_data() if Game.profile.size() > 0 else {}
	var class_color: Color = job.get("color", color)
	var base := class_color.lerp(color, 0.5)
	base = Color.from_hsv(base.h, clampf(base.s * 1.3, 0.45, 0.92), clampf(base.v * 0.85, 0.55, 0.88))
	var top := h * 0.30
	var bottom := h * 0.64
	var skew := (bottom - top) * 0.45
	_band.polygon = PackedVector2Array([Vector2(-w * 0.5 + skew, top), Vector2(w * 1.5 + skew, top), Vector2(w * 1.5, bottom), Vector2(-w * 0.5, bottom)])
	_band.color = Color(base, 0.92)
	_shade.polygon = PackedVector2Array([Vector2(-w * 0.55 + skew, top - h * 0.04), Vector2(w * 1.55 + skew, top - h * 0.04), Vector2(w * 1.55, bottom + h * 0.04), Vector2(-w * 0.55, bottom + h * 0.04)])
	var thin := h * 0.012
	_edge_a.polygon = PackedVector2Array([Vector2(-w * 0.5 + skew, top - thin), Vector2(w * 1.5 + skew, top - thin), Vector2(w * 1.5 + skew, top), Vector2(-w * 0.5 + skew, top)])
	_edge_b.polygon = PackedVector2Array([Vector2(-w * 0.5, bottom), Vector2(w * 1.5, bottom), Vector2(w * 1.5, bottom + thin), Vector2(-w * 0.5, bottom + thin)])
	var light := base.lightened(0.55)
	_edge_a.color = light
	_edge_b.color = light
	for i in _streaks.size():
		var y := lerpf(top, bottom, (float(i) + 0.5) / float(_streaks.size()))
		var length := w * (0.18 + 0.05 * float(i % 3))
		var x := w * (0.1 + 0.15 * float(i))
		var lean := (bottom - y) / (bottom - top) * skew
		_streaks[i].polygon = PackedVector2Array([Vector2(x + lean, y), Vector2(x + lean + length, y), Vector2(x + lean + length, y + 2.5), Vector2(x + lean, y + 2.5)])
		_streaks[i].color = Color(1, 1, 1, 0.22 + 0.08 * float(i % 2))
	# The hero: the portrait the HUD captured, the bare head, or the class emblem.
	var portrait_size := (bottom - top) * 1.18
	var tex := _portrait_texture()
	_portrait.texture = tex
	_portrait.visible = tex != null
	_portrait.size = Vector2(portrait_size, portrait_size)
	_portrait_x = w * 0.06 + skew * 0.3
	_portrait.position = Vector2(_portrait_x, bottom - portrait_size)
	_emblem.visible = tex == null
	if tex == null:
		_emblem.polygon = _star_points(Vector2(w * 0.06 + skew * 0.3 + portrait_size * 0.5, (top + bottom) * 0.5), (bottom - top) * 0.42)
		_emblem.color = light
	var text_x := w * 0.06 + skew * 0.3 + portrait_size * 1.02
	_title.text = SkillWeight.thai_name(skill)
	_title.add_theme_font_size_override("font_size", int(clampf(h * 0.085, 30.0, 84.0)))
	_title.add_theme_color_override("font_color", Color(1, 0.98, 0.9))
	_title.position = Vector2(text_x, top + (bottom - top) * 0.12)
	var god := StarSkillData.is_god(skill)
	_sub.text = ("สกิลเทพ ★%d" if god else "ท่าไม้ตาย ★%d") % int(skill.get("star", 200))
	if job.has("name"):
		_sub.text += "  •  " + String(job.name)
	_sub.add_theme_font_size_override("font_size", int(clampf(h * 0.04, 18.0, 40.0)))
	_sub.add_theme_color_override("font_color", Color("ffe28a") if god else light.lightened(0.3))
	_sub.position = Vector2(text_x + skew * 0.25, top + (bottom - top) * 0.62)
	_flash.size = _size
	_flash.color = Color(light, 0.0)
	_length = PVP_LENGTH if pvp else LENGTH
	_started = false
	_t = 0.0
	visible = true
	set_process(true)
	_layout(0.0)
	_slow = not pvp and not HitFeel._stopped and Engine.time_scale > 0.05
	if _slow:
		_base = Engine.time_scale
		_slowing = true
		_set_clock(1.0)


func _portrait_texture() -> Texture2D:
	if Game.profile.is_empty():
		return null
	var key := HeroPortrait.appearance_key(Game.profile)
	var pair: Variant = HeroPortrait._textures.get(key)
	if pair is Array and not pair.is_empty() and pair[0] is Texture2D:
		return pair[0]
	var look: Dictionary = Game.profile.get("look", {})
	var gender := clampi(int(look.get("gender", 0)), 0, HeroPortrait.BARE_HEADS.size() - 1)
	return HeroPortrait.BARE_HEADS[gender]


static func _star_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var angle := -PI * 0.5 + TAU * float(i) / 10.0
		points.append(center + Vector2(cos(angle), sin(angle)) * (radius if i % 2 == 0 else radius * 0.45))
	return points


func _process(delta: float) -> void:
	# Unscaled frame time (its own slow motion and a fast test clock divided out),
	# a hitch frame capped.
	if _started:
		_t += minf(delta / maxf(Engine.time_scale, 0.01), MAX_STEP)
	_started = true
	var t := _t
	if _slow:
		_step_clock(t)
	_layout(t)
	if t >= _length and not _slow:
		_finish()


## Sweep in (0.14 s), hold with the streaks running, sweep out over the last 0.13 s.
func _layout(t: float) -> void:
	var w := _size.x
	var into := clampf(t / 0.14, 0.0, 1.0)
	var out := clampf((t - (_length - 0.13)) / 0.13, 0.0, 1.0)
	var x := -w * 1.9 * pow(1.0 - into, 3.0) + w * 1.9 * out * out
	_band.position.x = x
	_shade.position.x = x * 0.92
	_edge_a.position.x = x * 1.06
	_edge_b.position.x = x * 0.94
	_shade.color.a = 0.55 * (1.0 - out)
	# The portrait drifts a little slower than the band (parallax), the name a little faster.
	_portrait.position.x = _portrait_x - t * 30.0
	_title.modulate.a = clampf((t - 0.08) / 0.1, 0.0, 1.0)
	_sub.modulate.a = clampf((t - 0.14) / 0.1, 0.0, 1.0)
	for i in _streaks.size():
		_streaks[i].position.x = fposmod(t * (900.0 + 160.0 * float(i)), w * 1.2) - w * 0.3
	_flash.color.a = 0.28 * (1.0 - clampf(t / 0.12, 0.0, 1.0))


func _step_clock(t: float) -> void:
	# Someone else took the clock (a test's speed-up, a pause screen): let go untouched.
	if not is_equal_approx(Engine.time_scale, _applied):
		_slow = false
		_slowing = false
		return
	var factor := 1.0
	if t < SLOW_IN:
		factor = lerpf(1.0, SLOW_SCALE, t / SLOW_IN)
	elif t < SLOW_HOLD:
		factor = SLOW_SCALE
	elif t < SLOW_OUT:
		factor = lerpf(SLOW_SCALE, 1.0, smoothstep(SLOW_HOLD, SLOW_OUT, t))
	else:
		_release_clock(false)
		return
	_set_clock(factor)


func _set_clock(factor: float) -> void:
	_applied = _base * factor
	Engine.time_scale = _applied


## Gives the clock back: to the speed it had before, unless someone else changed it.
func _release_clock(_replacing: bool) -> void:
	if _slow and _slowing and is_equal_approx(Engine.time_scale, _applied):
		Engine.time_scale = _base
	_slow = false
	_slowing = false


func _finish() -> void:
	_release_clock(false)
	visible = false
	set_process(false)
	# The portrait belongs to the HUD's cache: never keep it alive from here.
	_portrait.texture = null


func _exit_tree() -> void:
	_release_clock(false)
