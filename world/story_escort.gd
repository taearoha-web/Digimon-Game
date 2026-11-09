class_name StoryEscort
extends CharacterBody3D
## นาวิน reading the shadow conduit (StoryChapter2 "ch2_escort"): a real body the monsters
## attack. It joins the "companions" group so every monster targets it like a party member
## (Mob._targets) and party heals and buffs reach it; it never moves or fights. Its health
## is a share of the hero's (HP_OF_HERO), mitigated by DEF_OF_HERO of the hero's defence.
## StoryChapter runs the clock and the waves; `fell` ends the attempt.

signal fell()

const HP_OF_HERO := 1.6
const DEF_OF_HERO := 0.8

var hp := 1
var max_hp := 1
var stats: Dictionary = {"def": 0.0}
var visual: HeroVisual
var _bar: FieldHpBar
var _dead := false


func setup(hero_stats: Dictionary, look: Dictionary) -> void:
	max_hp = maxi(1, int(round(float(hero_stats.get("max_hp", 1000)) * HP_OF_HERO)))
	hp = max_hp
	stats = {"def": float(hero_stats.get("def", 0.0)) * DEF_OF_HERO}
	visual = HeroVisual.new()
	add_child(visual)
	var own := look.duplicate()
	visual.setup(&"archer", String(own.get("npc_outfit", ["Rogue"])[0]), false, {}, own)
	visual.add_to_group("anim_lod")


func _ready() -> void:
	name = "StoryEscort"
	add_to_group("companions")
	collision_layer = 0
	collision_mask = 1 << 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.7
	shape.shape = capsule
	shape.position = Vector3(0, 0.85, 0)
	add_child(shape)
	var label := Label3D.new()
	label.text = "%s\nกำลังอ่านจารึก..." % StoryChapter2.role_name("abyss_exile")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.0048
	label.font_size = 40
	label.outline_size = 12
	label.modulate = Color("c9f0ff")
	label.position = Vector3(0, 2.75, 0)
	add_child(label)
	_bar = FieldHpBar.new()
	_bar.position = Vector3(0, 3.05, 0)
	_bar.scale = Vector3.ONE * 1.3
	add_child(_bar)
	_bar.set_ratio(1.0)
	MeshKit.blob_shadow(self, 0.8)
	if visual:
		visual.play("Idle")


func is_dead() -> bool:
	return _dead


## A monster's blow (Mob.strike), mitigated like a companion's.
func take_damage(raw: float, _attacker: Node = null) -> void:
	if _dead:
		return
	var amount := maxi(1, int(round(HeroStats.mitigate(raw, float(stats.def)))))
	hp = maxi(0, hp - amount)
	_bar.set_ratio(float(hp) / float(max_hp))
	BattleVfx.other_number(get_parent(), global_position + Vector3(0, 2.4, 0), str(amount), Color("ff7a8a"), 1.0)
	if visual:
		visual.flash()
	if hp <= 0:
		_die()


## A story boss's telegraph landing on it: a fraction of its health.
func boss_hit(fraction: float) -> void:
	take_damage(float(max_hp) * fraction * (100.0 + float(stats.def)) / 100.0)


func heal_fraction(fraction: float) -> void:
	if _dead:
		return
	hp = mini(max_hp, hp + int(round(float(max_hp) * fraction)))
	_bar.set_ratio(float(hp) / float(max_hp))


func receive_party_buff(_buff: Dictionary, _color: Color, _label := "", _skill_id := "") -> void:
	pass


func _die() -> void:
	if _dead:
		return
	_dead = true
	remove_from_group("companions")
	collision_layer = 0
	if visual:
		visual.play("Death_A")
	fell.emit()
