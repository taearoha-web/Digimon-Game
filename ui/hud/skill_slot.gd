class_name SkillSlot
extends TouchButton
## One skill on the arc: coloured round button with a glyph for how the skill
## is aimed, cooldown sweep, MP cost, a lock for skills not unlocked yet and
## the skill name underneath.

var skill: Dictionary = {}
var cooldown_ratio := 0.0
var cooldown_left := 0.0
var enough_mp := true
var unlocked := true
var rank := 1
var queued := false
var show_name := true
var cost := 0


func _init() -> void:
	radius = 34.0
	toggle_mode = false


func apply(p_skill: Dictionary, p_ratio: float, p_left: float, p_mp_ok: bool, p_unlocked: bool, p_rank: int, p_queued: bool) -> void:
	var changed := p_skill != skill or not is_equal_approx(p_ratio, cooldown_ratio) or p_mp_ok != enough_mp \
			or p_unlocked != unlocked or p_rank != rank or p_queued != queued
	skill = p_skill
	cooldown_ratio = p_ratio
	cooldown_left = p_left
	enough_mp = p_mp_ok
	unlocked = p_unlocked
	rank = p_rank
	queued = p_queued
	accent = skill.get("color", UIPalette.CYAN)
	text = ""
	if changed:
		queue_redraw()


func _draw() -> void:
	if skill.is_empty():
		return
	var c := size * 0.5
	var ready := cooldown_ratio <= 0.0 and enough_mp and unlocked
	var alpha := 1.0 if ready else 0.6
	var fill := Color(accent.r * 0.3, accent.g * 0.3, accent.b * 0.4, 0.88 * alpha)
	if _held or queued:
		fill = Color(accent.r * 0.85, accent.g * 0.85, accent.b * 0.85, 0.95)
	draw_circle(c + Vector2(0, 4), radius, Color(0, 0, 0, 0.3 * alpha))
	draw_circle(c, radius, fill)
	draw_arc(c, radius, 0, TAU, 48, Color(1, 1, 1, 0.9 * alpha), 3.0, true)
	draw_arc(c, radius - 5.0, 0, TAU, 48, Color(accent.r, accent.g, accent.b, 0.95 * alpha), 3.0, true)
	if unlocked:
		_glyph(c, Color(1, 1, 1, alpha))
	else:
		_lock(c)
	if cooldown_ratio > 0.0 and unlocked:
		var pts := PackedVector2Array([c])
		var sweep := TAU * cooldown_ratio
		for i in 33:
			pts.append(c + Vector2.from_angle(-PI * 0.5 + sweep * float(i) / 32.0) * (radius - 2.0))
		draw_colored_polygon(pts, Color(0.02, 0.03, 0.1, 0.65))
		_text(str(ceili(cooldown_left)), c + Vector2(0, 0), 24, Color(1, 1, 1, 0.95))
	if unlocked:
		var badge := c + Vector2(radius * 0.74, radius * 0.74)
		var cost_color := UIPalette.SP if enough_mp else UIPalette.DANGER
		draw_circle(badge, 12.0, Color(0.06, 0.07, 0.28, 0.95))
		draw_arc(badge, 12.0, 0, TAU, 16, cost_color, 2.0, true)
		_text(str(cost), badge, 14, cost_color)
		if rank > 1:
			_text("★%d" % rank, c + Vector2(-radius * 0.7, -radius * 0.7), 14, UIPalette.GOLD)
	else:
		_text("Lv.%d" % int(skill.level), c + Vector2(0, radius * 0.52), 15, Color(1, 0.85, 0.5))
	if show_name and _font:
		_text(String(skill.name), c + Vector2(0, radius + 15.0), 15, Color(1, 1, 1, 0.95 if ready else 0.65))


func _glyph(c: Vector2, color: Color) -> void:
	var r := radius * 0.42
	match String(skill.shape):
		"single":
			draw_arc(c, r, 0, TAU, 28, color, 3.0, true)
			draw_circle(c, r * 0.3, color)
			for a in 4:
				var d := Vector2.from_angle(a * PI * 0.5)
				draw_line(c + d * r * 1.05, c + d * r * 1.5, color, 3.0, true)
		"burst":
			draw_circle(c, r * 0.25, color)
			draw_arc(c, r * 0.7, 0, TAU, 28, color, 3.0, true)
			draw_arc(c, r * 1.25, 0, TAU, 28, Color(color.r, color.g, color.b, color.a * 0.7), 3.0, true)
		"blast":
			draw_circle(c, r * 0.5, color)
			for a in 8:
				var d := Vector2.from_angle(a * PI * 0.25 + 0.2)
				draw_line(c + d * r * 0.8, c + d * r * 1.5, color, 3.0, true)
		"fan":
			for a in [-0.5, 0.0, 0.5]:
				var d := Vector2.from_angle(-PI * 0.5 + a)
				draw_line(c + Vector2(0, r * 1.0), c + d * r * 1.55, color, 3.0, true)
				draw_circle(c + d * r * 1.55, 3.0, color)
		"chain":
			var pts := PackedVector2Array([c + Vector2(-r * 0.2, -r * 1.2), c + Vector2(r * 0.5, -r * 0.1), c + Vector2(-r * 0.4, r * 0.1), c + Vector2(r * 0.3, r * 1.2)])
			draw_polyline(pts, color, 4.0, true)
		_:
			if _is_heal():
				draw_rect(Rect2(c - Vector2(r * 0.25, r * 0.9), Vector2(r * 0.5, r * 1.8)), color)
				draw_rect(Rect2(c - Vector2(r * 0.9, r * 0.25), Vector2(r * 1.8, r * 0.5)), color)
			else:
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, r * 0.2), c + Vector2(r * 0.4, r * 0.2),
						c + Vector2(r * 0.4, r), c + Vector2(-r * 0.4, r), c + Vector2(-r * 0.4, r * 0.2), c + Vector2(-r, r * 0.2)]), color)


func _is_heal() -> bool:
	return skill.get("fx", {}).has("heal") and not skill.get("fx", {}).has("buff")


func _lock(c: Vector2) -> void:
	var col := Color(1, 1, 1, 0.7)
	draw_rect(Rect2(c + Vector2(-9, -2), Vector2(18, 14)), col)
	draw_arc(c + Vector2(0, -3), 7.0, PI, TAU, 12, col, 3.0, true)


func _text(value: String, at: Vector2, font_size: int, color: Color) -> void:
	if _font == null:
		return
	var w := _font.get_string_size(value, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	var pos := Vector2(at.x - w * 0.5, at.y + font_size * 0.35)
	draw_string_outline(_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0.02, 0.04, 0.12, 0.95))
	draw_string(_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
