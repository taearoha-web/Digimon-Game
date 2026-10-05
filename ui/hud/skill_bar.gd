class_name SkillBar
extends Control
## The partner's skills on the right edge of the screen, plus small buttons to
## switch the locked-on monster and to swap the partner. Reads [FieldCombat]
## every frame (cheap: buttons only redraw when their state changes).

const SLOT_COUNT := 4
const BUTTON_RADIUS := 38.0
const TOP := 104.0
const SPACING := 90.0

var combat: FieldCombat
var _buttons: Array[SkillButton] = []
var _target_button: TouchButton
var _swap_button: TouchButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -100.0
	offset_right = -14.0
	for i in SLOT_COUNT:
		var button := SkillButton.new()
		button.position = Vector2(8, TOP + i * SPACING)
		button.size = Vector2(BUTTON_RADIUS * 2.0, BUTTON_RADIUS * 2.0)
		button.key_hint = str(i + 1)
		button.visible = false
		button.pressed.connect(_on_skill_pressed.bind(i))
		add_child(button)
		_buttons.append(button)
	var y := TOP + SLOT_COUNT * SPACING + 2.0
	_target_button = _small_button("res://assets/icons/ui/target.svg", Vector2(46, y), UIPalette.DANGER)
	_target_button.pressed.connect(func(): if combat: combat.cycle_target())
	_swap_button = _small_button("res://assets/icons/ui/swap.svg", Vector2(-8, y), UIPalette.CYAN)
	_swap_button.pressed.connect(_on_swap_pressed)


func bind(p_combat: FieldCombat) -> void:
	combat = p_combat


func get_button(index: int) -> SkillButton:
	return _buttons[index]


func _process(_delta: float) -> void:
	if combat == null:
		return
	var skills := combat.get_skills()
	for i in SLOT_COUNT:
		var button := _buttons[i]
		if i >= skills.size():
			button.skill = null
			button.visible = false
			continue
		var skill := skills[i]
		button.apply_state(skill, combat.cooldown_ratio(skill), combat.combatant != null and combat.combatant.can_afford(skill),
				combat.is_pending(skill))
	var party_size := GameState.roster.get_party().size()
	_swap_button.visible = party_size > 1
	_target_button.visible = not skills.is_empty()


func _on_skill_pressed(index: int) -> void:
	if combat == null:
		return
	var skills := combat.get_skills()
	if index < skills.size():
		combat.use_skill(skills[index])


## Brings the next healthy party member to the front as the active partner.
func _on_swap_pressed() -> void:
	var party := GameState.roster.get_party()
	for step in range(1, party.size()):
		var candidate := party[step]
		if not candidate.is_fainted():
			GameState.roster.set_lead(candidate.uid)
			EventBus.toast(L10n.t("%s steps in!") % candidate.get_display_name(), &"info")
			return
	EventBus.toast("No other Digimon can fight right now.", &"warning")


func _small_button(icon_path: String, pos: Vector2, accent: Color) -> TouchButton:
	var button := TouchButton.new()
	button.radius = 27.0
	button.icon = load(icon_path)
	button.accent = accent
	button.position = pos
	button.size = Vector2(54, 54)
	add_child(button)
	return button
