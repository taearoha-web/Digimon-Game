class_name TrainingDummy
extends Mob
## The guild hall's training dummy (หุ่นฝึกซ้อม): a straw man on a post that the hero
## may hit like any monster (it is in the "mobs" group, so the attack and auto buttons
## find it) but that never fights back, never moves and never falls: every hit tops its
## health up again. It keeps the damage of the last WINDOW seconds and shows the damage a
## second (dps) and the best run (best_dps) on its plate, so a build can be measured.

const WINDOW := 5.0
## Far more health than one hit can take, so no blow ever "kills" it.
const DUMMY_HP := 2000000000
const NAME := "หุ่นฝึกซ้อม"

var dps := 0.0
var best_dps := 0.0
var total := 0
var _hits: Array = []
var _idle_since := 0.0


class DummyVisual:
	extends MonsterVisual
	## A straw dummy built from code: a post, a cross bar, a straw body and head, a target
	## on its chest. No clips: the Mob's play / action / hold calls do nothing to it.

	func build(target_height: float) -> void:
		if is_instance_valid(model):
			model.free()
		model = Node3D.new()
		add_child(model)
		var wood := MeshKit.toon(Color("5a3a26"))
		var straw := MeshKit.toon(Color("d2b265"))
		var rope := MeshKit.toon(Color("8a6a40"))
		MeshKit.part(model, MeshKit.cylinder(), MeshKit.toon(Color("7f7d76")), Vector3(0, 0.1, 0), Vector3(1.1, 0.2, 1.1))
		MeshKit.part(model, MeshKit.cylinder(), wood, Vector3(0, 1.0, 0), Vector3(0.22, 1.9, 0.22))
		MeshKit.part(model, MeshKit.box(), wood, Vector3(0, 1.45, 0), Vector3(1.5, 0.12, 0.12))
		MeshKit.part(model, MeshKit.capsule(), straw, Vector3(0, 1.25, 0), Vector3(0.62, 0.95, 0.5))
		MeshKit.part(model, MeshKit.box(), rope, Vector3(0, 1.1, 0), Vector3(0.66, 0.08, 0.54))
		MeshKit.part(model, MeshKit.box(), rope, Vector3(0, 1.45, 0), Vector3(0.66, 0.08, 0.54))
		MeshKit.part(model, MeshKit.sphere_low(), straw, Vector3(0, 1.95, 0), Vector3(0.44, 0.46, 0.44))
		MeshKit.part(model, MeshKit.box(), rope, Vector3(0, 1.82, 0), Vector3(0.46, 0.06, 0.46))
		MeshKit.part(model, MeshKit.cylinder(), MeshKit.toon(Color("f4f0e8")), Vector3(0, 1.3, 0.27), Vector3(0.42, 0.03, 0.42), Vector3(90, 0, 0))
		MeshKit.part(model, MeshKit.cylinder(), MeshKit.toon(Color("d8452e")), Vector3(0, 1.3, 0.29), Vector3(0.28, 0.03, 0.28), Vector3(90, 0, 0))
		MeshKit.part(model, MeshKit.cylinder(), MeshKit.toon(Color("f4f0e8")), Vector3(0, 1.3, 0.31), Vector3(0.14, 0.03, 0.14), Vector3(90, 0, 0))
		for mi in model.get_children():
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		height = target_height
		_rest_scale = Vector3.ONE
		_ground_offset = 0.0
		_flash_meshes.clear()
		set_process(true)


## Stands at `p_home` (no monster record: its own template).
func setup_dummy(p_home: Vector3, p_hero: Node3D) -> void:
	monster_id = &"training_dummy"
	level = Game.GUILD_LEVEL
	home = p_home
	hero = p_hero
	template = {"name": NAME, "model": "", "height": 2.2, "speed": 0.0, "boss": false, "atk": 0.0, "hp": DUMMY_HP, "exp": 0, "gold": 0}
	stats = {"hp": DUMMY_HP, "atk": 0.0, "def": 0.0, "speed": 0.0, "exp": 0, "gold": 0}
	hp = DUMMY_HP
	max_hp = hp
	is_boss = false
	_speed = 0.0


func _make_visual() -> MonsterVisual:
	var v := DummyVisual.new()
	add_child(v)
	v.build(float(template.height))
	return v


func _ready() -> void:
	super._ready()
	_label.text = _plate()
	_label.visibility_range_end = 22.0
	_label.modulate = Color("ffe9a0")


## Takes the blow (the number, the flash), stays whole and counts it for the DPS plate.
func take_hit(amount: int, crit: bool, color := Color.WHITE, attacker: Node = null) -> bool:
	if _dead or amount <= 0:
		return false
	var now := GameClock.msec() * 0.001
	_hits.append([now, amount])
	total += amount
	super.take_hit(amount, crit, color, attacker)
	hp = max_hp
	hostile = false
	_bar.set_ratio(1.0)
	_refresh(now)
	return false


func _refresh(now: float) -> void:
	while not _hits.is_empty() and float(_hits[0][0]) < now - WINDOW:
		_hits.pop_front()
	var sum := 0.0
	for h in _hits:
		sum += float(h[1])
	var span := WINDOW
	if not _hits.is_empty():
		span = clampf(now - float(_hits[0][0]), 1.0, WINDOW)
	dps = sum / span if not _hits.is_empty() else 0.0
	best_dps = maxf(best_dps, dps)
	_idle_since = now
	_label.text = _plate()
	_label.visible = true


func _plate() -> String:
	if best_dps <= 0.0:
		return "%s\nตีเพื่อวัดดาเมจต่อวินาที" % NAME
	return "%s\nDPS %s · สูงสุด %s" % [NAME, _num(dps), _num(best_dps)]


static func _num(v: float) -> String:
	if v >= 1000000.0:
		return "%.2fM" % (v / 1000000.0)
	if v >= 10000.0:
		return "%.1fK" % (v / 1000.0)
	return "%d" % int(round(v))


## It never moves, never strikes, never wakes up angry; only its burns and the plate tick.
func _physics_process(delta: float) -> void:
	if not global_position.is_finite():
		global_position = home
	velocity = Vector3.ZERO
	_tick_status(delta)
	hp = max_hp
	var now := GameClock.msec() * 0.001
	if dps > 0.0 and now - _idle_since > WINDOW:
		dps = 0.0
		_hits.clear()
		_label.text = _plate()


func set_dormant(_on: bool) -> void:
	pass


func provoke(_alert_pack := true) -> void:
	pass


func taunt(_by: Node3D, _seconds: float) -> void:
	pass


func knock_back(_from: Vector3, _strength := 2.5) -> void:
	pass


func shove_out(_center: Vector3, _radius: float) -> void:
	pass
