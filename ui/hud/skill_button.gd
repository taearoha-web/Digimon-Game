class_name SkillButton
extends TouchButton
## One slot of the right-side skill bar: element-coloured round button with a
## glyph for how the skill is aimed, a cooldown sweep, an SP cost badge and the
## skill name drawn to its left (the bar hugs the right screen edge).

const ELEMENT_COLORS := {
	&"fire": Color("ff7a3d"), &"ice": Color("7fdcff"), &"wind": Color("6ff0b4"), &"thunder": Color("ffe14d"),
	&"plant": Color("6fe36b"), &"earth": Color("c79a62"), &"light": Color("fff2a0"), &"dark": Color("b084ff"),
	&"neutral": Color("c9d3ff"),
}

var skill: SkillData
var cooldown_ratio := 0.0
var affordable := true
var queued := false
var cost_text := ""
var key_hint := ""


func _init() -> void:
	radius = 38.0
	toggle_mode = false


## Returns true when something changed (so the bar only redraws when needed).
func apply_state(p_skill: SkillData, p_cooldown: float, p_affordable: bool, p_queued: bool) -> bool:
	var changed := p_skill != skill or not is_equal_approx(p_cooldown, cooldown_ratio) \
			or p_affordable != affordable or p_queued != queued
	if p_skill != skill:
		skill = p_skill
		accent = ELEMENT_COLORS.get(skill.element, ELEMENT_COLORS[&"neutral"]) if skill else UIPalette.CYAN
		cost_text = str(skill.sp_cost) if skill and skill.sp_cost > 0 else ""
		text = ""
	cooldown_ratio = p_cooldown
	affordable = p_affordable
	queued = p_queued
	visible = skill != null
	if changed:
		queue_redraw()
	return changed


func _draw() -> void:
	if skill == null:
		return
	var center := size * 0.5
	var ready := cooldown_ratio <= 0.0 and affordable
	var alpha := 1.0 if ready else 0.62
	var fill := Color(accent.r * 0.32, accent.g * 0.32, accent.b * 0.42, 0.82 * alpha)
	if _held or queued:
		fill = Color(accent.r * 0.8, accent.g * 0.8, accent.b * 0.8, 0.92)
	draw_circle(center + Vector2(0, 4), radius, Color(0, 0, 0, 0.28 * alpha))
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0, TAU, 48, Color(1, 1, 1, 0.85 * alpha), 3.0, true)
	draw_arc(center, radius - 6.0, 0, TAU, 48, Color(accent.r, accent.g, accent.b, 0.9 * alpha), 3.0, true)
	_draw_glyph(center, Color(1, 1, 1, alpha))
	if cooldown_ratio > 0.0:
		_draw_cooldown(center)
	if not affordable:
		draw_circle(center, radius - 2.0, Color(0.1, 0.05, 0.3, 0.35))
	if cost_text != "":
		var badge := center + Vector2(radius * 0.72, radius * 0.72)
		draw_circle(badge, 14.0, Color(0.07, 0.08, 0.3, 0.95))
		draw_arc(badge, 14.0, 0, TAU, 20, UIPalette.SP if affordable else UIPalette.DANGER, 2.0, true)
		_draw_centered(cost_text, badge + Vector2(0, 1), 17, UIPalette.SP if affordable else UIPalette.DANGER)
	if key_hint != "":
		_draw_centered(key_hint, center + Vector2(-radius * 0.72, -radius * 0.72), 14, Color(1, 1, 1, 0.6))
	if _font:
		var name_text := skill.display_name
		var font_size := 21
		var width := _font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var pos := Vector2(center.x - radius - 10.0 - width, center.y + font_size * 0.35)
		draw_string_outline(_font, pos, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0.02, 0.04, 0.12, 0.95))
		draw_string(_font, pos, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 1.0 if ready else 0.7))
		if skill.is_area():
			var tag := L10n.t("Area")
			var tag_width := _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			var tag_pos := Vector2(center.x - radius - 10.0 - tag_width, center.y + 24.0)
			draw_string_outline(_font, tag_pos, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0.02, 0.04, 0.12, 0.95))
			draw_string(_font, tag_pos, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIPalette.GOLD)


## Glyph by aiming: dot-in-ring = single, spreading rings = burst around me,
## ring with rays = blast on the target, plus / arrow = self skill.
func _draw_glyph(center: Vector2, color: Color) -> void:
	var r := radius * 0.42
	match skill.shape if skill.target == SkillData.Target.ENEMY else -1:
		SkillData.Shape.SINGLE:
			draw_arc(center, r, 0, TAU, 28, color, 3.0, true)
			draw_circle(center, r * 0.32, color)
			for a in 4:
				var dir := Vector2.from_angle(a * PI * 0.5)
				draw_line(center + dir * r * 1.05, center + dir * r * 1.45, color, 3.0, true)
		SkillData.Shape.BURST:
			draw_circle(center, r * 0.25, color)
			draw_arc(center, r * 0.7, 0, TAU, 28, color, 3.0, true)
			draw_arc(center, r * 1.25, 0, TAU, 28, Color(color.r, color.g, color.b, color.a * 0.7), 3.0, true)
		SkillData.Shape.BLAST:
			draw_circle(center, r * 0.5, color)
			for a in 8:
				var dir := Vector2.from_angle(a * PI * 0.25 + 0.2)
				draw_line(center + dir * r * 0.8, center + dir * r * 1.45, color, 3.0, true)
		_:
			if _has_heal():
				draw_rect(Rect2(center - Vector2(r * 0.25, r * 0.9), Vector2(r * 0.5, r * 1.8)), color)
				draw_rect(Rect2(center - Vector2(r * 0.9, r * 0.25), Vector2(r * 1.8, r * 0.5)), color)
			else:
				var pts := PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, r * 0.2),
						center + Vector2(r * 0.4, r * 0.2), center + Vector2(r * 0.4, r),
						center + Vector2(-r * 0.4, r), center + Vector2(-r * 0.4, r * 0.2), center + Vector2(-r, r * 0.2)])
				draw_colored_polygon(pts, color)


func _has_heal() -> bool:
	for effect in skill.effects:
		if effect and effect.type == SkillEffect.Type.HEAL:
			return true
	return false


func _draw_cooldown(center: Vector2) -> void:
	var points := PackedVector2Array([center])
	var steps := 36
	var sweep := TAU * cooldown_ratio
	for i in steps + 1:
		points.append(center + Vector2.from_angle(-PI * 0.5 + sweep * float(i) / steps) * (radius - 2.0))
	draw_colored_polygon(points, Color(0.02, 0.03, 0.1, 0.62))
	if _font:
		var seconds := ceilf(cooldown_ratio * skill.cooldown)
		_draw_centered("%d" % seconds, center + Vector2(0, 1), 26, Color(1, 1, 1, 0.95))


func _draw_centered(value: String, at: Vector2, font_size: int, color: Color) -> void:
	if _font == null:
		return
	var width := _font.get_string_size(value, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	var pos := Vector2(at.x - width * 0.5, at.y + font_size * 0.35)
	draw_string_outline(_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0.02, 0.04, 0.12, 0.95))
	draw_string(_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
