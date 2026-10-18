class_name FairyVisual
extends MonsterVisual
## The Fairy Spirit's body: the chibi girl hero model, unarmed, in a small size,
## wearing the summoner's spirit-butterfly wings in their flying pose. The generic
## clip keys (idle / walk / run / attack / hurt / die) map to the hero clips; while
## the wings fly, Idle and Running become the hovering body clips (FlyClips).

const SCALE := 0.62

var hero_visual: HeroVisual


func setup_fairy() -> void:
	hero_visual = HeroVisual.new()
	add_child(hero_visual)
	var look := FaceKit.default_look()
	look["gender"] = 1
	look["hair_color"] = 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	hero_visual.setup(&"summoner", "", false, {"wings": ItemData.wings(rng, "summoner", 0)}, look)
	hero_visual.scale = Vector3.ONE * SCALE
	hero_visual.set_wing_mode(HeroVisual.WING_FLY, true)
	hero_visual.set_wing_moving(false)
	height = HeroVisual.CHIBI_HEIGHT * SCALE
	set_process(false)


func setup(_model_path: String, _target_height: float, _hover := 0.0, _tint := Color.WHITE) -> void:
	pass


func _clip(key: String) -> String:
	match key:
		"idle":
			return "Idle"
		"walk", "run":
			return "Running_A"
		"attack":
			return "Spellcast_Raise" if hero_visual.has_clip("Spellcast_Raise") else "Idle"
		"hurt":
			return "Hit_A"
		"die":
			return "Death_A"
	return key


func play(key: String, speed := 1.0) -> void:
	if hero_visual:
		hero_visual.set_wing_moving(key != "idle")
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
