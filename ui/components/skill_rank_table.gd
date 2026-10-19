class_name SkillRankTable
## The Skill Master's per-star table: one row per value a skill has (damage,
## targets, area, heal, buff, control, cooldown, MP), one column per star. The
## current star is gold, the next one green, and a line under the table says
## what the next upgrade adds.


static func build(rows: Array, rank: int) -> VBoxContainer:
	var box := UIUtil.vbox(2)
	box.name = "RankTable"
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = SkillRank.MAX + 1
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 0)
	box.add_child(grid)
	grid.add_child(_cell("", UIPalette.TEXT_MUTED, true))
	for star in range(1, SkillRank.MAX + 1):
		grid.add_child(_cell("ดาว %d" % star, _tint(star, rank), false))
	for row in rows:
		grid.add_child(_cell(String(row[0]), UIPalette.TEXT_DIM, true))
		var values: Array = row[1]
		for star in range(1, SkillRank.MAX + 1):
			grid.add_child(_cell(String(values[star - 1]), _tint(star, rank), false))
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


static func _tint(star: int, rank: int) -> Color:
	if star == rank:
		return UIPalette.GOLD
	if star == rank + 1:
		return UIPalette.SUCCESS
	return UIPalette.TEXT_DIM if star < rank else UIPalette.TEXT_MUTED


static func _cell(text: String, color: Color, first: bool) -> Label:
	var cell := UIUtil.label(text, &"SmallLabel", HORIZONTAL_ALIGNMENT_LEFT if first else HORIZONTAL_ALIGNMENT_CENTER)
	cell.add_theme_color_override("font_color", color)
	if first:
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		cell.custom_minimum_size = Vector2(64, 0)
	return cell
