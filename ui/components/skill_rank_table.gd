class_name SkillRankTable
## The Skill Master's per-star table: one row per value a skill has (damage,
## targets, area, heal, buff, control, cooldown, MP), one column per star. The
## current star is gold, the next one green, and a line under the table says
## what the next upgrade adds.


static func build(rows: Array, rank: int) -> VBoxContainer:
	var box := UIUtil.vbox(2)
	box.name = "RankTable"
	# One drawn control instead of a grid of ~36 labels per skill: the Skill Master lists
	# every skill, and its 1,000+ labels were the biggest burst of memory in town.
	var grid := RankGrid.new()
	grid.name = "Grid"
	grid.rows = rows
	grid.rank = rank
	box.add_child(grid)
	var changes := SkillRank.next_changes(rows, rank)
	var next := UIUtil.label("", &"SmallLabel")
	next.name = "NextStar"
	next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if rank >= SkillRank.MAX:
		next.text = "ดาวเต็ม 5 ดาวแล้ว: ค่าทุกอย่างสูงสุด"
		next.add_theme_color_override("font_color", UIPalette.GOLD)
	elif rank <= 0:
		next.text = "ปลดล็อกแล้วเริ่มที่ดาว 1"
		next.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
	else:
		next.text = "อัปเป็นดาว %d: %s" % [rank + 1, ",  ".join(changes)]
		next.add_theme_color_override("font_color", UIPalette.SUCCESS)
	box.add_child(next)
	return box


## The table drawn in place of a GridContainer of SmallLabels, laid out the same way: a
## first column that takes the free width (left-aligned names), then one centred column per
## star at least 64 px wide, 14 px apart, rows one line high.
class RankGrid:
	extends Control
	const COLUMN_MIN := 64.0
	const SEPARATION := 14.0
	var rows: Array = []
	var rank := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

	func _notification(what: int) -> void:
		if what == NOTIFICATION_THEME_CHANGED:
			update_minimum_size()
			queue_redraw()
		elif what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _font() -> Font:
		return get_theme_font(&"font", &"SmallLabel")

	func _font_size() -> int:
		return get_theme_font_size(&"font_size", &"SmallLabel")

	func _text_width(text: String) -> float:
		return _font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size()).x

	func _star_column() -> float:
		var width := COLUMN_MIN
		for star in range(1, SkillRank.MAX + 1):
			width = maxf(width, _text_width("ดาว %d" % star))
		for row in rows:
			for value in row[1]:
				width = maxf(width, _text_width(String(value)))
		return width

	func _first_column() -> float:
		var width := 0.0
		for row in rows:
			width = maxf(width, _text_width(String(row[0])))
		return width

	func _get_minimum_size() -> Vector2:
		var line := _font().get_height(_font_size())
		return Vector2(_first_column() + SkillRank.MAX * (_star_column() + SEPARATION), line * (rows.size() + 1))

	func _draw() -> void:
		var font := _font()
		var font_size := _font_size()
		var line := font.get_height(font_size)
		var ascent := font.get_ascent(font_size)
		var star_w := _star_column()
		var first_w := maxf(_first_column(), size.x - SkillRank.MAX * (star_w + SEPARATION))
		for r in rows.size() + 1:
			var y := r * line + ascent
			if r > 0:
				draw_string(font, Vector2(0, y), String(rows[r - 1][0]), HORIZONTAL_ALIGNMENT_LEFT, first_w, font_size, UIPalette.TEXT_DIM)
			for star in range(1, SkillRank.MAX + 1):
				var x := first_w + SEPARATION + (star - 1) * (star_w + SEPARATION)
				var text := "ดาว %d" % star if r == 0 else String(rows[r - 1][1][star - 1])
				draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_CENTER, star_w, font_size, SkillRankTable._tint(star, rank))


static func _tint(star: int, rank: int) -> Color:
	if star == rank:
		return UIPalette.GOLD
	if star == rank + 1:
		return UIPalette.SUCCESS
	return UIPalette.TEXT_DIM if star < rank else UIPalette.TEXT_MUTED
