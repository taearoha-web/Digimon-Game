class_name InventoryPanel
extends HBoxContainer
## Inventory: category tabs, item list, details and "Use" with a party
## target picker. Item effects are resolved by ItemService; chips (Gear tab)
## are held by Digimon through EquipmentService.

const TABS := [
	["Items", ItemData.Category.CONSUMABLE],
	["Gear", ItemData.Category.EQUIPMENT],
	["Evo", ItemData.Category.EVOLUTION],
	["Quest", ItemData.Category.QUEST],
	["Key", ItemData.Category.KEY],
]

var _category: int = ItemData.Category.CONSUMABLE
var _list: VBoxContainer
var _detail: VBoxContainer
var _selected: StringName = &""
var _tab_buttons: Array[Button] = []


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := UIUtil.vbox(10)
	left.custom_minimum_size = Vector2(480, 0)
	add_child(left)
	var tabs := UIUtil.hbox(6)
	left.add_child(tabs)
	var group := ButtonGroup.new()
	for tab in TABS:
		var category: int = tab[1]
		var b := UIUtil.button(tab[0], &"TabButton", Vector2(0, 50))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = category == _category
		b.pressed.connect(func():
			_category = category
			_selected = &""
			refresh())
		tabs.add_child(b)
		_tab_buttons.append(b)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	_list = UIUtil.vbox(8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var detail_panel := UIUtil.panel(&"GlassPanel")
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(detail_panel)
	_detail = UIUtil.vbox(12)
	detail_panel.add_child(_detail)
	refresh()


func refresh() -> void:
	UIUtil.clear(_list)
	var entries := GameState.inventory.get_entries(_category)
	if entries.is_empty():
		var empty_text := "No chips in your bag. Chips held by Digimon show in their details." \
			if _category == ItemData.Category.EQUIPMENT else "No items in this category."
		var empty := UIUtil.label(empty_text, &"DimLabel")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(empty)
	for entry in entries:
		var item: ItemData = entry.item
		if _selected == &"":
			_selected = item.id
		var row := UIUtil.button("", &"ChoiceButton", Vector2(0, 64))
		row.toggle_mode = true
		row.button_pressed = item.id == _selected
		row.icon = item.get_icon()
		row.expand_icon = false
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = "%s   ×%d" % [item.display_name, int(entry.quantity)]
		row.add_theme_constant_override("icon_max_width", 44)
		row.pressed.connect(func():
			_selected = item.id
			refresh())
		_list.add_child(row)
	_show_detail()


func _show_detail() -> void:
	UIUtil.clear(_detail)
	var item := GameData.get_item(_selected)
	if item == null or not GameState.inventory.has_item(_selected):
		_detail.add_child(UIUtil.label("Select an item.", &"DimLabel"))
		return
	var head := UIUtil.hbox(14)
	_detail.add_child(head)
	head.add_child(UIUtil.texture_rect(item.get_icon(), Vector2(88, 88)))
	var titles := UIUtil.vbox(4)
	head.add_child(titles)
	titles.add_child(UIUtil.label(item.display_name, &"HeaderLabel"))
	titles.add_child(UIUtil.label("%s · Owned %d" % [item.get_category_name(), GameState.inventory.count(item.id)], &"DimLabel"))
	var desc := UIUtil.label(item.description, &"")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(desc)
	if item.usable_in_battle and not item.usable_in_field:
		_detail.add_child(UIUtil.label("Can only be used during battle.", &"SmallLabel"))
	if item.is_equipment():
		_show_equip_targets(item)
		return
	if not item.is_usable(false):
		return
	_detail.add_child(UIUtil.label("Use on:", &"SubHeaderLabel"))
	for inst in GameState.roster.get_party():
		var reason := ItemService.get_block_reason(item, inst, false)
		var b := UIUtil.button("%s  Lv %d  ·  HP %d/%d  SP %d/%d" % [inst.get_display_name(), inst.level, inst.current_hp,
			inst.get_max_hp(), inst.current_sp, inst.get_max_sp()], &"ChoiceButton", Vector2(0, 58))
		b.disabled = reason != ""
		b.tooltip_text = reason
		b.pressed.connect(func():
			var result := ItemService.use_item(item.id, inst, GameState.inventory, false)
			EventBus.toast(result.message, &"success" if result.ok else &"warning")
			if result.ok:
				AudioManager.play_sfx(&"heal")
				GameState.roster.notify_changed()
			if not GameState.inventory.has_item(item.id):
				_selected = &""
			refresh())
		_detail.add_child(b)


func _show_equip_targets(item: ItemData) -> void:
	_detail.add_child(UIUtil.label("Held bonus: " + item.describe_bonuses(), &"BoldLabel"))
	_detail.add_child(UIUtil.label("Give to (one chip per Digimon):", &"SubHeaderLabel"))
	for inst in GameState.roster.get_party():
		var held := GameData.get_item(inst.held_item_id)
		var text := "%s  Lv %d  ·  %s" % [inst.get_display_name(), inst.level, ("Holding " + held.display_name) if held else "No chip"]
		var b := UIUtil.button(text, &"ChoiceButton", Vector2(0, 58))
		b.disabled = inst.held_item_id == item.id
		b.pressed.connect(func():
			var result := EquipmentService.equip(inst, item.id, GameState.inventory)
			EventBus.toast(result.message, &"success" if result.ok else &"warning")
			if result.ok:
				AudioManager.play_ui(&"ui_confirm")
				GameState.roster.notify_changed()
			if not GameState.inventory.has_item(item.id):
				_selected = &""
			refresh())
		_detail.add_child(b)
