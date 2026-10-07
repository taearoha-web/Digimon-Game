class_name TimerChip
extends Control
## A small round buff / summon indicator: a dark disc with a glyph, the seconds
## left, and a ring that unwinds around the disc as the time runs out. The ring
## turns red and the chip pulses when only a little time is left.

const SIZE := 66.0
const WARN_RATIO := 0.2

var accent := Color.WHITE
var glyph := "power"
var title := ""
var time_text := ""
var ratio := 1.0
var ally := false
var count := 1
var summon := false
var _pulse := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(SIZE + 14.0, SIZE + 34.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_values(entry: Dictionary, delta: float) -> void:
	accent = entry.color
	glyph = String(entry.get("glyph", "power"))
	title = String(entry.name)
	var left := maxf(float(entry.left), 0.0)
	ratio = clampf(left / maxf(float(entry.total), 0.001), 0.0, 1.0)
	time_text = _format(left)
	ally = bool(entry.ally)
	summon = String(entry.kind) == "summon"
	count = int(entry.count)
	_pulse = fmod(_pulse + delta * 7.0, TAU)
	queue_redraw()


func _draw() -> void:
	var c := Vector2(size.x * 0.5, SIZE * 0.5 + 2.0)
	var warn := ratio < WARN_RATIO
	var throb := 1.0 + (0.05 * sin(_pulse) if warn else 0.0)
	var r := SIZE * 0.5 * throb
	var ring_color := accent
	if warn:
		ring_color = accent.lerp(Color("ff3a2a"), 0.6 + 0.4 * (0.5 + 0.5 * sin(_pulse)))
	draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.3))
	draw_circle(c, r, Color(0.03, 0.06, 0.17, 0.88))
	draw_arc(c, r - 3.0, 0.0, TAU, 48, Color(1, 1, 1, 0.14), 5.0, true)
	# The remaining time: starts full at 12 o'clock and unwinds clockwise.
	if ratio > 0.002:
		draw_arc(c, r - 3.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 64, ring_color, 5.0, true)
	draw_circle(c, r - 8.0, Color(accent.r, accent.g, accent.b, 0.16))
	_draw_glyph(c + Vector2(0, -8), 10.0, accent.lerp(Color.WHITE, 0.35))
	_text(time_text, c + Vector2(0, 14), 15, Color(1, 1, 1, 0.96))
	if ally:
		draw_circle(c + Vector2(r * 0.72, -r * 0.72), 8.0, Color("5aff9a"))
		_text("+", c + Vector2(r * 0.72, -r * 0.72 + 5), 13, Color(0.02, 0.1, 0.05))
	if summon and count > 1:
		draw_circle(c + Vector2(r * 0.72, r * 0.72), 9.0, Color(0.05, 0.1, 0.3))
		_text("×%d" % count, c + Vector2(r * 0.72, r * 0.72 + 5), 12, Color.WHITE)
	_text(title, Vector2(size.x * 0.5, SIZE + 22.0), 13, Color(1, 1, 1, 0.9))


func _text(text: String, at: Vector2, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var clipped := text
	while width > size.x + 6.0 and clipped.length() > 3:
		clipped = clipped.substr(0, clipped.length() - 2)
		width = font.get_string_size(clipped + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if clipped != text:
		clipped += "…"
		width = font.get_string_size(clipped, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string_outline(font, at + Vector2(-width * 0.5, 0), clipped, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.7))
	draw_string(font, at + Vector2(-width * 0.5, 0), clipped, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_glyph(c: Vector2, r: float, color: Color) -> void:
	match glyph:
		"shield":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.8), c + Vector2(r * 0.8, -r * 0.8), c + Vector2(r * 0.8, r * 0.1), c + Vector2(0, r), c + Vector2(-r * 0.8, r * 0.1)]), color)
		"power":
			for i in 2:
				var y := r * (0.45 - i * 0.7)
				draw_polyline(PackedVector2Array([c + Vector2(-r * 0.8, y + r * 0.45), c + Vector2(0, y - r * 0.25), c + Vector2(r * 0.8, y + r * 0.45)]), color, 3.5, true)
		"wind":
			for i in 3:
				var y := r * (-0.6 + i * 0.6)
				draw_line(c + Vector2(-r * 0.9, y), c + Vector2(r * (0.5 - i * 0.2), y), color, 3.0, true)
				draw_circle(c + Vector2(r * (0.65 - i * 0.2), y), 2.2, color)
		"spark":
			var pts := PackedVector2Array()
			for i in 8:
				var rad := r if i % 2 == 0 else r * 0.38
				pts.append(c + Vector2.from_angle(-PI * 0.5 + TAU * float(i) / 8.0) * rad)
			draw_colored_polygon(pts, color)
		"summon":
			draw_circle(c + Vector2(0, r * 0.35), r * 0.55, color)
			for p in [Vector2(-0.75, -0.2), Vector2(-0.25, -0.75), Vector2(0.25, -0.75), Vector2(0.75, -0.2)]:
				draw_circle(c + p * r * 0.9, r * 0.25, color)
		_:
			draw_circle(c, r * 0.6, color)


## 2:41 for long timers, 18s for short ones.
static func _format(seconds: float) -> String:
	var s := int(ceil(seconds))
	if s >= 60:
		return "%d:%02d" % [s / 60, s % 60]
	return "%ds" % s
