class_name GemPicker
extends OverlaySheet
## ใส่อัญมณี: the forge's gem sheet for one piece of gear (opened from the game menu's
## bag in forge mode). At the top the piece's sockets (the gem in each, or ว่าง; tap a
## gem to take it out, Game.unsocket_gem), resonance and the quick fill; below one row
## per gem type in ItemData.GEM_ORDER (its colour, name and stat, "ใส่ให้เต็ม") with the
## sizes left to right, small to legendary, as tiles: icon, size, ×count and the bonus.
## A tap puts that gem into the next free socket (Game.socket_gem: every rule there).
##   GemPicker.open_for(parent, item)

## A gem went in or came out (the menu refreshes behind the sheet when it closes).
signal gems_changed()

const TILE_SIZE := Vector2(150, 70)
const HEAD_WIDTH := 240.0

var item: Dictionary = {}
var _body: VBoxContainer
var _scroll: TouchScroll


static func open_for(parent: Node, piece: Dictionary) -> GemPicker:
	var sheet := GemPicker.new()
	sheet.name = "GemPicker"
	sheet.item = piece
	parent.add_child(sheet)
	var view := parent.get_viewport().get_visible_rect().size if parent.is_inside_tree() else Vector2(1280, 720)
	var body := UIUtil.vbox(10)
	sheet._body = body
	sheet._build("ใส่อัญมณี · %s" % ItemData.name_of(piece), body,
		Vector2(minf(1240.0, maxf(860.0, view.x - 40.0)), minf(680.0, maxf(380.0, view.y - 30.0))))
	sheet._title.add_theme_color_override("font_color", ItemData.color_of(piece))
	sheet._title.clip_text = true
	sheet._title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sheet.refresh()
	return sheet


# ---------------------------------------------------------------------------
# The rules (static: the tests use them on a bare profile)
# ---------------------------------------------------------------------------

## The bag's gems grouped by type in GEM_ORDER, sizes small to large: one entry per type
## the bag holds, {type, name, stat, color, special, total, sizes: [5 x {id, size, count,
## index (first bag index of that gem, -1 when none), value}]}.
static func rows(inv: Array) -> Array:
	var have := {}
	for i in inv.size():
		var it: Dictionary = inv[i]
		# A locked stack (ItemData.is_locked) is never set into a socket.
		if it.get("kind", "") != "gem" or not ItemData.GEMS.has(String(it.id).split("_")[0]) or ItemData.is_locked(it):
			continue
		var id := String(it.id)
		if not have.has(id):
			have[id] = {"count": 0, "index": i}
		have[id]["count"] += int(it.get("count", 1))
	var out := []
	for gem_type in ItemData.GEM_ORDER:
		var base: Dictionary = ItemData.GEMS[gem_type]
		var row := {"type": gem_type, "name": base.name, "stat": base.stat, "color": base.color, "special": bool(base.special), "total": 0, "sizes": []}
		for size in ItemData.GEM_SIZES.size():
			var id := "%s_%d" % [gem_type, size]
			var got: Dictionary = have.get(id, {"count": 0, "index": -1})
			row.sizes.append({"id": id, "size": size, "count": int(got.count), "index": int(got.index), "value": float(base.values[size])})
			row["total"] += int(got.count)
		if int(row.total) > 0:
			out.append(row)
	return out


static func free_sockets(piece: Dictionary) -> int:
	return maxi(0, int(piece.get("sockets", 0)) - (piece.get("gems", []) as Array).size())


## The gem type a class wants most: sapphire for a caster (its magic attack is its
## attack, HeroStats: plus MP), ruby for everyone else.
static func main_type(profile: Dictionary) -> String:
	var data := JobData.resolve(StringName(profile.get("class", "warrior")), int(profile.get("adv", 0)))
	return "sapphire" if String(data.get("main", "")) == "int" else "ruby"


## What "ใส่ดีที่สุดอัตโนมัติ" puts in the free sockets (gem ids, in order): the class's
## main gem (main_type), largest first; when those run out the largest of any other gem
## (GEM_ORDER breaks a tie). Gems already in the piece are never touched.
static func best_plan(piece: Dictionary, inv: Array, profile: Dictionary) -> Array[String]:
	var main := main_type(profile)
	var pool: Array = []
	for row in rows(inv):
		for s in row.sizes:
			for k in int(s.count):
				pool.append(s)
	pool.sort_custom(func(a, b):
		var am := String(a.id).begins_with(main + "_")
		var bm := String(b.id).begins_with(main + "_")
		if am != bm:
			return am
		if int(a.size) != int(b.size):
			return int(a.size) > int(b.size)
		return ItemData.gem_sort_key(a.id) < ItemData.gem_sort_key(b.id))
	var out: Array[String] = []
	for k in mini(free_sockets(piece), pool.size()):
		out.append(String(pool[k].id))
	return out


## What "ใส่ให้เต็ม" on a type's row puts in the free sockets: that type, largest first.
static func fill_plan(piece: Dictionary, inv: Array, type: String) -> Array[String]:
	var out: Array[String] = []
	for row in rows(inv):
		if row.type != type:
			continue
		for size in range(ItemData.GEM_MAX_SIZE, -1, -1):
			for k in int(row.sizes[size].count):
				if out.size() < free_sockets(piece):
					out.append(String(row.sizes[size].id))
	return out


## Puts one gem of [param gem_id] from the bag into the piece's next free socket.
static func put(piece: Dictionary, gem_id: String) -> bool:
	for i in Game.profile.inv.size():
		var it: Dictionary = Game.profile.inv[i]
		if it.get("kind", "") == "gem" and String(it.id) == gem_id and not ItemData.is_locked(it):
			return Game.socket_gem(piece, i)
	return false


## Every gem of a plan in turn; how many went in.
static func apply(piece: Dictionary, plan: Array) -> int:
	var done := 0
	for gem_id in plan:
		if put(piece, String(gem_id)):
			done += 1
	return done


## "ทับทิมตำนาน ×2, ทับทิมใหญ่ ×1" for a plan.
static func plan_text(plan: Array) -> String:
	var counts := {}
	var order: Array[String] = []
	for gem_id in plan:
		if not counts.has(gem_id):
			counts[gem_id] = 0
			order.append(String(gem_id))
		counts[gem_id] += 1
	var parts := PackedStringArray()
	for gem_id in order:
		parts.append("%s ×%d" % [ItemData.gem_info({"id": gem_id}).name, int(counts[gem_id])])
	return ", ".join(parts)


# ---------------------------------------------------------------------------
# The sheet
# ---------------------------------------------------------------------------

func refresh() -> void:
	var keep := _scroll.scroll_vertical if _scroll != null and is_instance_valid(_scroll) else 0
	UIUtil.clear(_body)
	_body.add_child(_sockets_bar())
	var hint := UIUtil.label("แตะอัญมณีเพื่อใส่ลงช่องว่าง · เรียงตามชนิด ขนาด เล็ก → ตำนาน" if free_sockets(item) > 0
		else ("ช่องเต็มแล้ว · แตะอัญมณีในช่องด้านบนเพื่อถอดออก (เก็บเข้ากระเป๋า)" if int(item.get("sockets", 0)) > 0
		else "ชิ้นนี้ยังไม่มีช่องอัญมณี · เจาะช่องด้วยสว่านเจาะที่หน้าช่างตีเหล็ก"), &"SmallLabel")
	hint.name = "GemHint"
	hint.add_theme_color_override("font_color", UIPalette.TEXT_DIM if free_sockets(item) > 0 else UIPalette.WARNING)
	_body.add_child(hint)
	_scroll = TouchScroll.new()
	_scroll.name = "GemRows"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(_scroll)
	var list := UIUtil.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(list)
	var all := rows(Game.profile.inv)
	if all.is_empty():
		var none := UIUtil.label("ไม่มีอัญมณีในกระเป๋า · อัญมณีดรอปจากมอนสเตอร์ทุกพื้นที่", &"DimLabel", HORIZONTAL_ALIGNMENT_CENTER)
		none.name = "GemNone"
		none.custom_minimum_size = Vector2(0, 120)
		list.add_child(none)
	for row in all:
		list.add_child(_type_row(row))
	if keep > 0:
		_scroll.set_deferred("scroll_vertical", keep)


func _sockets_bar() -> Control:
	var bar := UIUtil.hbox(8)
	bar.name = "GemSockets"
	var sockets := int(item.get("sockets", 0))
	var gems: Array = item.get("gems", [])
	var ring := 1.0 + ItemData.GEM_RESONANCE if ItemData.resonates(item) else 1.0
	var head := UIUtil.vbox(0)
	head.custom_minimum_size = Vector2(118, 0)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(UIUtil.label("ช่องอัญมณี", &"BoldLabel"))
	var count := UIUtil.label("%d/%d ช่อง" % [gems.size(), sockets], &"SmallLabel")
	count.add_theme_color_override("font_color", UIPalette.GOLD if gems.size() >= sockets and sockets > 0 else UIPalette.TEXT_DIM)
	head.add_child(count)
	bar.add_child(head)
	for k in sockets:
		var tile := Button.new()
		tile.focus_mode = Control.FOCUS_NONE
		tile.custom_minimum_size = Vector2(236 if sockets <= 3 else 196, 66)
		tile.clip_text = true
		tile.expand_icon = true
		tile.add_theme_constant_override("icon_max_width", 42)
		tile.add_theme_font_size_override("font_size", 16)
		tile.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if k < gems.size():
			var info := ItemData.gem_info({"id": gems[k]})
			tile.name = "GemSocket%d" % k
			tile.icon = ItemLook.icon(ItemData.gem(info.type, info.size))
			tile.text = "%s\n%s · ถอด" % [info.name, ItemData.gem_effect_text(info, ring)]
			tile.add_theme_color_override("font_color", Color(info.color).lightened(0.25))
			_style_tile(tile, info.color, 0.22, 2)
			var socket_index := k
			tile.pressed.connect(func(): _take_out(socket_index))
		else:
			tile.name = "GemSocket%d" % k
			tile.text = "ว่าง\nแตะอัญมณีด้านล่าง"
			tile.alignment = HORIZONTAL_ALIGNMENT_CENTER
			tile.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
			tile.add_theme_color_override("font_disabled_color", UIPalette.TEXT_MUTED)
			_style_tile(tile, UIPalette.TEXT_MUTED, 0.0, 2)
			tile.disabled = true
		bar.add_child(tile)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	var side := UIUtil.vbox(4)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(side)
	var ring_line := UIUtil.label("สะท้อนพลัง! อัญมณี +%d%%" % int(ItemData.GEM_RESONANCE * 100.0) if ItemData.resonates(item)
		else "ชนิดเดียวกันครบทุกช่อง (3 ช่องขึ้นไป): +%d%%" % int(ItemData.GEM_RESONANCE * 100.0), &"SmallLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	ring_line.name = "GemResonance"
	ring_line.add_theme_color_override("font_color", UIPalette.GOLD if ItemData.resonates(item) else UIPalette.TEXT_MUTED)
	side.add_child(ring_line)
	var auto := UIUtil.button("ใส่ดีที่สุดอัตโนมัติ", &"PrimaryButton", Vector2(236, 52))
	auto.name = "GemAutoBest"
	auto.add_theme_font_size_override("font_size", 18)
	auto.disabled = best_plan(item, Game.profile.inv, Game.profile).is_empty()
	auto.pressed.connect(_auto_best)
	side.add_child(auto)
	return bar


func _type_row(row: Dictionary) -> Control:
	var line := UIUtil.hbox(8)
	line.name = "GemRow_%s" % row.type
	var color: Color = row.color
	var head := PanelContainer.new()
	head.custom_minimum_size = Vector2(HEAD_WIDTH, TILE_SIZE.y)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIPalette.CARD.lerp(color, 0.16)
	sb.border_color = Color(color, 0.85)
	sb.border_width_left = 6
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 12
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	head.add_theme_stylebox_override("panel", sb)
	line.add_child(head)
	var inner := UIUtil.hbox(6)
	head.add_child(inner)
	var words := UIUtil.vbox(0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(words)
	var title := UIUtil.label(String(row.name), &"BoldLabel")
	title.add_theme_color_override("font_color", color.lightened(0.3))
	title.add_theme_font_size_override("font_size", 18)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(title)
	var stat := UIUtil.label(String(ItemData.STAT_LABELS.get(row.stat, row.stat)), &"SmallLabel")
	stat.add_theme_font_size_override("font_size", 15)
	stat.clip_text = true
	stat.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(stat)
	var fill := UIUtil.button("ใส่\nให้เต็ม", &"", Vector2(64, 60))
	fill.name = "GemFill_%s" % row.type
	fill.add_theme_font_size_override("font_size", 14)
	fill.tooltip_text = "ใส่%sขนาดใหญ่สุดลงทุกช่องที่ว่าง" % row.name
	fill.disabled = fill_plan(item, Game.profile.inv, String(row.type)).is_empty()
	var type := String(row.type)
	fill.pressed.connect(func(): _fill_type(type))
	inner.add_child(fill)
	var free := free_sockets(item) > 0
	for s in row.sizes:
		var tile := Button.new()
		tile.name = "GemTile_%s" % s.id
		tile.focus_mode = Control.FOCUS_NONE
		tile.custom_minimum_size = TILE_SIZE
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.clip_text = true
		tile.expand_icon = true
		tile.add_theme_constant_override("icon_max_width", 40)
		tile.add_theme_font_size_override("font_size", 16)
		tile.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var info := ItemData.gem_info({"id": s.id})
		var have := int(s.count) > 0
		tile.icon = ItemLook.icon(ItemData.gem(String(row.type), int(s.size)))
		tile.text = "%s ×%d\n%s" % [ItemData.GEM_SIZES[s.size], int(s.count), ItemData.gem_value_text(info)] if have else "%s\n—" % ItemData.GEM_SIZES[s.size]
		tile.tooltip_text = "%s: %s" % [info.name, ItemData.gem_effect_text(info)]
		tile.add_theme_color_override("font_color", UIPalette.TEXT)
		tile.add_theme_color_override("font_disabled_color", UIPalette.TEXT_DIM if have else UIPalette.TEXT_MUTED)
		_style_tile(tile, color, 0.14 if have else 0.0, 2 if have else 1)
		if not have:
			tile.modulate = Color(1, 1, 1, 0.38)
		tile.disabled = not have or not free
		var gem_id := String(s.id)
		tile.pressed.connect(func(): _put_one(gem_id))
		line.add_child(tile)
	return line


func _style_tile(tile: Button, color: Color, tint: float, border: int) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		var t := tint + (0.12 if state in ["hover", "pressed", "hover_pressed"] else 0.0)
		style.bg_color = UIPalette.CARD.lerp(color, t) if state != "disabled" else Color(UIPalette.CARD.lerp(color, tint * 0.6), 0.85)
		style.border_color = Color(color, 0.8 if border > 1 else 0.45)
		style.set_border_width_all(border)
		style.set_corner_radius_all(12)
		style.content_margin_left = 8
		style.content_margin_right = 6
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		tile.add_theme_stylebox_override(state, style)


func _changed() -> void:
	gems_changed.emit()
	refresh()


func _put_one(gem_id: String) -> void:
	if free_sockets(item) <= 0:
		Game.say("ช่องอัญมณีเต็มแล้ว ถอดอันเดิมออกก่อน", &"warning")
		return
	if put(item, gem_id):
		Game.say("ใส่%sแล้ว" % ItemData.gem_info({"id": gem_id}).name, &"success")
		AudioManager.play_sfx(&"pickup")
		if ItemData.resonates(item):
			Game.say("อัญมณีชนิดเดียวกันครบทุกช่อง: สะท้อนพลัง +%d%%!" % int(ItemData.GEM_RESONANCE * 100.0), &"success")
	_changed()


func _take_out(socket_index: int) -> void:
	var gems: Array = item.get("gems", [])
	if socket_index >= gems.size():
		return
	var worn := ItemData.gem_info({"id": gems[socket_index]})
	var result := Game.unsocket_gem(item, socket_index)
	if result == "ok":
		Game.say("ถอด%sแล้ว (เก็บเข้ากระเป๋า)" % worn.name, &"success")
		AudioManager.play_sfx(&"pickup")
	else:
		Game.say(result, &"warning")
	_changed()


func _fill_type(type: String) -> void:
	var plan := fill_plan(item, Game.profile.inv, type)
	if plan.is_empty():
		return
	var done := apply(item, plan)
	if done > 0:
		Game.say("ใส่ %s แล้ว" % plan_text(plan.slice(0, done)), &"success")
		AudioManager.play_sfx(&"pickup")
		if ItemData.resonates(item):
			Game.say("อัญมณีชนิดเดียวกันครบทุกช่อง: สะท้อนพลัง +%d%%!" % int(ItemData.GEM_RESONANCE * 100.0), &"success")
	_changed()


func _auto_best() -> void:
	var plan := best_plan(item, Game.profile.inv, Game.profile)
	if plan.is_empty():
		return
	var main := main_type(Game.profile)
	var cls := String(ClassData.get_class_data(StringName(Game.profile.get("class", "warrior"))).get("name", ""))
	var lines := PackedStringArray()
	lines.append("ใส่ %s ลงช่องว่าง %d ช่อง" % [plan_text(plan), plan.size()])
	lines.append("เลือกตามค่าหลักของ%s: %s (%s) ขนาดใหญ่สุดก่อน" % [cls if cls != "" else "อาชีพ", ItemData.GEMS[main].name, ItemData.STAT_LABELS[ItemData.GEMS[main].stat]])
	lines.append("ถ้าไม่พอ ใช้อัญมณีขนาดใหญ่สุดที่เหลือ")
	var after := item.duplicate()
	after["gems"] = (item.get("gems", []) as Array) + plan
	if ItemData.resonates(after):
		lines.append("ทุกช่องเป็นชนิดเดียวกัน: สะท้อนพลัง +%d%%" % int(ItemData.GEM_RESONANCE * 100.0))
	lines.append("อัญมณีที่ใส่อยู่แล้ว ไม่ถูกเปลี่ยน")
	var ok: bool = await ModalDialog.confirm(self, "ใส่ดีที่สุดอัตโนมัติ", "\n".join(lines), "ใส่เลย", "ยกเลิก")
	if not ok or not is_instance_valid(self):
		return
	var done := apply(item, plan)
	if done > 0:
		Game.say("ใส่ %s แล้ว" % plan_text(plan.slice(0, done)), &"success")
		AudioManager.play_sfx(&"level_up")
	_changed()
