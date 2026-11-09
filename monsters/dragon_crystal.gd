class_name DragonCrystal
extends Mob
## A ศิลามังกร crystal of the Ancient Dragon King (DragonBoss): a code-built glowing
## prism that stands still and never attacks. While any of a phase's crystals lives the
## dragon is invulnerable, so the party switches to them (Companion targets them through
## DragonBoss.priority_target). Its stats come from DungeonData.monster_stats "crystal".

const ID: StringName = &"dragon_crystal"
const HEIGHT := 3.2


func setup_crystal(p_level: int, p_home: Vector3, p_hero: Node3D, scaled: Dictionary) -> void:
	monster_id = ID
	level = p_level
	home = p_home
	hero = p_hero
	template = {"name": DungeonData.CRYSTAL_NAME, "model": "", "height": HEIGHT, "speed": 0.0, "aggro": false, "attack": "melee",
		"boss": false, "color": DragonBoss.CRYSTAL_COLOR, "tint": Color.WHITE}
	stats = {"hp": int(scaled.get("hp", 100)), "atk": 1, "def": int(scaled.get("def", 0)), "exp": 0.0, "gold": 0.0}
	hp = int(stats.hp)
	max_hp = hp
	is_boss = false
	_speed = 0.0
	_base_speed = 0.0


## No model file: a crystal of prisms inside an empty MonsterVisual (its hit flash, die
## hold and scale tween are null-safe without a model).
func _make_visual() -> MonsterVisual:
	var v := MonsterVisual.new()
	add_child(v)
	v.height = HEIGHT
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(DragonBoss.CRYSTAL_COLOR.r, DragonBoss.CRYSTAL_COLOR.g, DragonBoss.CRYSTAL_COLOR.b, 0.85)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.emission_enabled = true
	glow.emission = DragonBoss.CRYSTAL_COLOR
	glow.emission_energy_multiplier = 1.6
	var core := MeshInstance3D.new()
	core.mesh = MeshKit.prism()
	core.material_override = glow
	core.position = Vector3(0, HEIGHT * 0.5, 0)
	core.scale = Vector3(1.4, HEIGHT, 1.4)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	v.add_child(core)
	for i in 3:
		var shard := MeshInstance3D.new()
		shard.mesh = MeshKit.prism()
		shard.material_override = glow
		var a := TAU * float(i) / 3.0
		shard.position = Vector3(cos(a) * 0.9, HEIGHT * 0.22, sin(a) * 0.9)
		shard.rotation = Vector3(0.35 * sin(a), a, 0.35 * cos(a))
		shard.scale = Vector3(0.6, HEIGHT * 0.45, 0.6)
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		v.add_child(shard)
	var base := MeshInstance3D.new()
	base.mesh = MeshKit.cylinder()
	base.material_override = MeshKit.toon(Color("3a4a40"))
	base.position = Vector3(0, 0.15, 0)
	base.scale = Vector3(1.8, 0.3, 1.8)
	v.add_child(base)
	return v


func _ready() -> void:
	super._ready()
	_label.visibility_range_end = 30.0
	_label.modulate = DragonBoss.CRYSTAL_COLOR
	# Always on its feet, never put to sleep.
	hostile = true


## It stands where it was raised: no chase, no wander, no attack.
func _physics_process(delta: float) -> void:
	if _dead:
		return
	_tick_status(delta)
	velocity = Vector3.ZERO
	var now := GameClock.msec() * 0.001
	if _bar_until > 0.0 and now > _bar_until and (_ring == null or not _ring.visible):
		_bar.visible = false
		_bar_until = 0.0


func _leash() -> float:
	return 999.0


func set_dormant(_on: bool) -> void:
	pass
