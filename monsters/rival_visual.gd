class_name RivalVisual
extends MonsterVisual
## A hero model (class, gear, face) standing in for a monster model, so the
## ranked-duel rival can use the same Mob plumbing. The generic clip keys
## (idle / walk / run / hurt / die) map to the hero animation names.

var hero_visual: HeroVisual


func setup_rival(class_id: StringName, equip: Dictionary, look: Dictionary) -> void:
	hero_visual = HeroVisual.new()
	add_child(hero_visual)
	hero_visual.setup(class_id, "", true, equip, look)
	height = 2.0


func setup(_model_path: String, _target_height: float, _hover := 0.0, _tint := Color.WHITE) -> void:
	pass


func _clip(key: String) -> String:
	match key:
		"idle":
			return "Idle"
		"walk":
			return "Walking_A" if hero_visual.has_clip("Walking_A") else "Running_A"
		"run":
			return "Running_A"
		"hurt":
			return "Hit_A"
		"die":
			return "Death_A"
	return key


func play(key: String, speed := 1.0) -> void:
	if hero_visual:
		hero_visual.play(_clip(key), 0.15, speed)


func action(key: String, _lock_ms := 450, speed := 1.0) -> void:
	if hero_visual:
		hero_visual.action(_clip(key), speed if key != "hurt" else 1.2)


func hold(key: String) -> void:
	if hero_visual:
		hero_visual.hold_last_frame(_clip(key))


func flash(color := Color(1, 1, 1), duration := 0.16) -> void:
	if hero_visual:
		hero_visual.flash(color, duration)
