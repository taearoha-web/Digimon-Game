class_name CastleGate
extends Mob
## One of the castle's three gates in the guild-war siege (SiegeArena). Both guilds batter
## it: it takes hits like a monster from the hero, the fighters and their summons (the war's
## damage scale applies, like on a fighter), only the front-most gate standing can be hurt,
## and while it stands its door blocks the way. Broken, it stays broken for the rest of the
## war (and after a resume). It never fights back and gives no EXP or loot.

signal broken(gate: CastleGate)

const HEIGHT := SiegeArena.GATE_H

var gate_index := 0
## Only the first gate still standing can be hurt (set by GuildWarMatch).
var breakable := false
var _blocker: StaticBody3D
var _door: Node3D
var _hit_fx_at := 0


func setup_gate(index: int, at: Vector3, p_hp: int, p_hero: Node3D) -> void:
	gate_index = index
	monster_id = &"castle_gate"
	level = 100
	home = at
	hero = p_hero
	template = {"name": "ประตูปราสาท %d" % (index + 1), "model": "", "height": HEIGHT, "speed": 0.0, "aggro": false,
		"attack": "melee", "boss": true, "color": Color("8a5a32")}
	stats = {"hp": p_hp, "atk": 0.0, "def": 0.0, "exp": 0, "gold": 0}
	hp = maxi(1, p_hp)
	max_hp = hp
	is_boss = true
	hostile = false
	_speed = 0.0
	_base_speed = 0.0


func _ready() -> void:
	super._ready()
	add_to_group("castle_gates")
	_label.text = String(template.name)
	_label.visibility_range_end = 60.0
	_label.position = Vector3(0, HEIGHT + 1.6, 0)
	_bar.position = Vector3(0, HEIGHT + 1.2, 0)
	_bar.scale = Vector3.ONE * 2.6
	_bar.visible = true
	_bar.set_ratio(float(hp) / float(max_hp))
	# The door is a wall while it stands.
	_blocker = StaticBody3D.new()
	_blocker.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SiegeArena.GATE_HALF * 2.0 + 0.4, HEIGHT, 1.6)
	shape.shape = box
	shape.position = Vector3(0, HEIGHT * 0.5, 0)
	_blocker.add_child(shape)
	add_child(_blocker)


## The door: two heavy wooden leaves with iron bands and studs.
func _make_visual() -> MonsterVisual:
	var v := MonsterVisual.new()
	add_child(v)
	v.height = HEIGHT
	_door = Node3D.new()
	_door.name = "Door"
	v.add_child(_door)
	v.model = _door
	var wood := MeshKit.toon(Color("6b4126"))
	var iron := MeshKit.toon(Color("2f3035"))
	var stud := MeshKit.toon(Color("d8b050"), {"emission": 0.1})
	var half := SiegeArena.GATE_HALF
	for side in [-1.0, 1.0]:
		MeshKit.part(_door, MeshKit.box(), wood, Vector3(side * half * 0.5, HEIGHT * 0.5, 0), Vector3(half - 0.08, HEIGHT, 0.7))
		for band in 4:
			var y := HEIGHT * (0.14 + float(band) * 0.24)
			MeshKit.part(_door, MeshKit.box(), iron, Vector3(side * half * 0.5, y, 0.38), Vector3(half - 0.2, 0.32, 0.08))
			for k in 3:
				MeshKit.part(_door, MeshKit.sphere_low(), stud, Vector3(side * (0.7 + float(k) * (half - 1.2) * 0.5), y, 0.44), Vector3.ONE * 0.26)
		# The great iron ring on each leaf.
		MeshKit.part(_door, MeshKit.cylinder(), iron, Vector3(side * 0.9, HEIGHT * 0.45, 0.42), Vector3(0.7, 0.08, 0.7), Vector3(90, 0, 0))
	return v


func body_radius() -> float:
	return SiegeArena.GATE_HALF * 0.7


func hit_point() -> Vector3:
	return global_position + Vector3(0, 2.2, 1.0)


func top_point() -> Vector3:
	return global_position + Vector3(0, HEIGHT + 0.4, 0.8)


## Hits from the hero, the hero's summons and the hero's party (war scale like on a fighter).
func take_hit(amount: int, crit: bool, _color := Color.WHITE, _attacker: Node = null) -> bool:
	return _batter(int(ceil(float(amount) * GuildWarData.damage_scale)), crit)


## Hits from the fighters (already scaled by the war).
func take_damage(raw: float, _attacker: Node = null) -> void:
	_batter(int(round(raw)), false)


func _batter(amount: int, crit: bool) -> bool:
	if _dead or not breakable or amount <= 0:
		return false
	hp = maxi(0, hp - amount)
	_bar.set_ratio(float(hp) / float(max_hp))
	var now := Time.get_ticks_msec()
	# Sixteen fighters on one door: numbers and flashes a few times a second, not every hit.
	if now >= _hit_fx_at:
		_hit_fx_at = now + 120
		BattleVfx.damage_number(get_parent(), top_point(), str(amount) + ("!" if crit else ""), false, 1.2 if crit else 0.9)
		visual.flash(Color(1.0, 0.9, 0.7), 0.1)
	if hp <= 0:
		_break()
		return true
	return false


## Splinters and dust; the way is open for good.
func _break() -> void:
	if _dead:
		return
	_dead = true
	breakable = false
	remove_from_group("mobs")
	collision_layer = 0
	set_targeted(false)
	_bar.visible = false
	_label.visible = false
	if is_instance_valid(_blocker):
		_blocker.queue_free()
	var field := get_parent()
	VfxKit.shockwave(field, global_position + Vector3(0, 0.2, 1.0), Color("ffd27a"), 7.0)
	VfxKit.sparks(field, global_position + Vector3(0, 3.0, 0.8), Color("c08850"), 30, 8.0, 0.9)
	VfxKit.flash(field, global_position + Vector3(0, 3.0, 0.5), Color("fff0c0"), 3.0)
	AudioManager.play_sfx(&"shield_quake", -4.0)
	if _door != null:
		var tw := create_tween()
		tw.tween_property(_door, "rotation_degrees:x", -88.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(_door, "scale", Vector3(1.0, 1.0, 0.4), 0.2)
	broken.emit(self)


## Already broken when the war comes back from a checkpoint.
func set_broken_quietly() -> void:
	_dead = true
	breakable = false
	hp = 0
	remove_from_group("mobs")
	collision_layer = 0
	_bar.visible = false
	_label.visible = false
	if is_instance_valid(_blocker):
		_blocker.queue_free()
	if _door != null:
		_door.visible = false


# A door does not walk, chase, flinch, burn or call for help.
func _physics_process(_delta: float) -> void:
	pass


func _check_phase() -> void:
	pass


func provoke(_alert_pack := true) -> void:
	pass


func knock_back(_from: Vector3, _strength := 2.5) -> void:
	pass


func apply_stun(_seconds: float) -> void:
	pass


func apply_slow(_seconds: float) -> void:
	pass


func taunt(_by: Node3D, _seconds: float) -> void:
	pass


func apply_burn(_dps: float, _seconds: float) -> void:
	pass


func set_dormant(_on: bool) -> void:
	pass
