class_name PauseMenu
extends CanvasLayer
## Pause menu with tabs: Digimon (collection), Party, Inventory, Quests,
## Settings, Save, Title, Return to Game. Pauses the world while open.

signal closed()

const TABS := [
	[&"digimon", "Digimon"],
	[&"party", "Party"],
	[&"inventory", "Inventory"],
	[&"quests", "Quests"],
	[&"settings", "Settings"],
	[&"save", "Save"],
]

var is_open := false
var current_tab: StringName = &"party"

var _root: Control
var _content: PanelContainer
var _tab_buttons: Dictionary = {}
var _header_info: Label
var _was_paused := false


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.12, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var safe := SafeAreaContainer.new()
	_root.add_child(safe)
	var main := UIUtil.hbox(16)
	safe.add_child(main)

	var side := UIUtil.vbox(8)
	side.custom_minimum_size = Vector2(210, 0)
	main.add_child(side)
	side.add_child(UIUtil.label("Menu", &"HeaderLabel"))
	var group := ButtonGroup.new()
	for tab in TABS:
		var b := UIUtil.button(tab[1], &"TabButton", Vector2(0, 58))
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(_show_tab.bind(tab[0]))
		side.add_child(b)
		_tab_buttons[tab[0]] = b
	side.add_child(UIUtil.spacer(false))
	var title_button := UIUtil.button("Title Screen", &"GhostButton", Vector2(0, 56))
	title_button.pressed.connect(_on_title)
	side.add_child(title_button)
	var resume := UIUtil.button("Return to Game", &"PrimaryButton", Vector2(0, 66))
	resume.pressed.connect(close)
	side.add_child(resume)

	var right := UIUtil.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(right)
	var header := UIUtil.hbox(12)
	right.add_child(header)
	_header_info = UIUtil.label("", &"DimLabel")
	_header_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_header_info)
	var close_button := UIUtil.icon_button("res://assets/icons/ui/close.svg", Vector2(60, 60))
	close_button.pressed.connect(close)
	header.add_child(close_button)
	_content = UIUtil.panel()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_content)


func open(tab: StringName = &"") -> void:
	if is_open:
		if tab != &"":
			_show_tab(tab)
		return
	is_open = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_root.visible = true
	AudioManager.play_ui(&"ui_open")
	_update_header()
	_show_tab(tab if tab != &"" else current_tab)
	UIUtil.pop_in(_content, 0.18)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	UIUtil.clear(_content)
	get_tree().paused = _was_paused
	AudioManager.play_ui(&"ui_cancel")
	closed.emit()


func _show_tab(tab: StringName) -> void:
	current_tab = tab
	if _tab_buttons.has(tab):
		(_tab_buttons[tab] as Button).button_pressed = true
	UIUtil.clear(_content)
	var panel: Control
	match tab:
		&"digimon":
			panel = CollectionPanel.new()
		&"party":
			panel = PartyPanel.new()
		&"inventory":
			panel = InventoryPanel.new()
		&"quests":
			panel = QuestPanel.new()
		&"settings":
			panel = SettingsPanel.new()
		&"save":
			var save_panel := SaveLoadPanel.create(&"save")
			save_panel.saved.connect(func(_s): _update_header())
			panel = save_panel
		_:
			panel = PartyPanel.new()
	_content.add_child(panel)
	_update_header()


func _update_header() -> void:
	var p := GameState.profile
	_header_info.text = "Tamer %s  ·  Play time %s  ·  %d Data Coins  ·  %d Digimon" % [p.player_name,
		UIUtil.format_play_time(p.play_time_seconds), p.currency, GameState.roster.size()]


func _on_title() -> void:
	var ok := await ModalDialog.confirm(_root, "Return to Title?", "Unsaved progress since your last save will be lost. (Autosave keeps key moments.)", "Leave", "Stay", true)
	if not ok:
		return
	is_open = false
	get_tree().paused = false
	GameState.is_game_active = false
	SceneManager.goto_scene(&"main_menu")


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("pause_menu") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

