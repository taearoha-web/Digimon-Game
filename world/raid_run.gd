class_name RaidRun
extends Node
## One entry of the party raid (RaidData): three floors in the crimson arena. Each floor's
## monsters come in one per frame and are published together (as TowerRun), the next floor
## follows a short rest that heals the party, and the last floor is the raid boss
## (RaidBoss). The party is the hero and the zone's companions (world players in the party).
## The hero who falls gets back up after REVIVE_DELAY while a mate still stands (at most
## HERO_LIVES times); when nobody stands the run is lost (the entry is spent, no reward).
## A clear pays once (RaidData.claim). A small banner line on screen (floor, monsters
## left, the enrage clock) is the only UI of its own; the boss bar is the HUD's.

signal finished(result: Dictionary)
signal floor_started(floor_no: int)
signal floor_cleared(floor_no: int)

const INTRO := 3.5
const REST := 6.0
const REVIVE_DELAY := 8.0
const HERO_LIVES := 3
const END_DELAY := 3.0
const CENTER := Vector3(0, 0, -10)
const FLOOR_HEAL := 0.4

var zone: Node3D
var hero: Hero
var floor_no := 1
var state := "intro"
var power: Dictionary = {}
var boss: RaidBoss
var mid_boss: Mob
var mobs: Array[Mob] = []
var hero_falls := 0
var result: Dictionary = {}
## Seconds the run has been going (game time).
var elapsed := 0.0
var rng := RandomNumberGenerator.new()
var _timer := INTRO
var _revive_timer := -1.0
var _pending: Array[Dictionary] = []
var _end_timer := 0.0
var _hud: CanvasLayer
var _line: Label
var _hud_timer := 0.0


func setup(p_zone: Node3D, p_hero: Hero, seed_value := 0) -> void:
	zone = p_zone
	hero = p_hero
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()


func _ready() -> void:
	name = "RaidRun"
	power = party_power()
	_banner("%s · %s" % [RaidData.TITLE, "เลเวลศัตรู %d" % RaidData.shown_level(power)])
	Game.say("ดันเจี้ยนปาร์ตี้ %d ชั้น: ล้างมอนสเตอร์ชั้น 1-2 แล้วปราบ%sที่ชั้น 3 (บอสจะคลั่งเมื่อครบ %d:%02d นาที)" % [RaidData.FLOORS, RaidData.BOSS_NAME, int(RaidBoss.ENRAGE_TIME) / 60, int(RaidBoss.ENRAGE_TIME) % 60], &"quest")
	if is_instance_valid(hero) and not hero.died.is_connected(_on_hero_died):
		hero.died.connect(_on_hero_died)
	_make_hud()


## The party as RaidData.party_power numbers: the hero and the companions here.
func party_power() -> Dictionary:
	var members: Array = []
	if Game.has_profile:
		var s := Game.stats_now()
		members.append({"level": int(Game.profile.level), "stars": int(Game.paragon().level), "atk": float(s.atk), "max_hp": float(s.max_hp), "def": float(s.def)})
	for c in party_members():
		members.append({"level": int(c.member.get("level", 1)), "stars": Game.party_stars(c.member), "atk": float(c.stats.get("atk", 10)), "max_hp": float(c.max_hp), "def": float(c.stats.get("def", 0))})
	return RaidData.party_power(members)


func party_members() -> Array[Companion]:
	var out: Array[Companion] = []
	if zone != null and "companions" in zone:
		for c in zone.companions:
			if is_instance_valid(c):
				out.append(c)
	return out


func standing() -> int:
	var n := 0 if hero == null or hero.is_dead() else 1
	for c in party_members():
		if not c.is_dead():
			n += 1
	return n


func _process(delta: float) -> void:
	if not is_instance_valid(hero) or not is_instance_valid(zone):
		queue_free()
		return
	step(delta)


## One step of the run (tests call it with big deltas).
func step(delta: float) -> void:
	if state not in ["ending", "done"]:
		elapsed += delta
	_tick_hud(delta)
	if state in ["intro", "spawning", "fight", "rest"]:
		_tick_revive(delta)
		if state != "intro" and standing() == 0:
			_wipe()
			return
	match state:
		"intro", "rest":
			_timer -= delta
			if _timer <= 0.0:
				start_floor()
		"spawning":
			_spawn_one()
		"fight":
			mobs = mobs.filter(func(m): return is_instance_valid(m) and not m.is_dead())
			var done := mobs.is_empty()
			if floor_no >= RaidData.FLOORS:
				done = boss == null or not is_instance_valid(boss) or boss.is_dead()
			if done:
				clear_floor()
		"ending":
			_end_timer -= delta
			if _end_timer <= 0.0:
				state = "done"
				finished.emit(result)


func start_floor() -> void:
	if state == "spawning":
		return
	state = "spawning"
	mobs.clear()
	_pending.clear()
	power = party_power()
	var plan := RaidData.floor_plan(floor_no, power, rng)
	var trash := RaidData.monster_stats(power, "trash")
	var ids: Array = plan.ids
	for i in ids.size():
		var angle := TAU * float(i) / float(maxi(1, ids.size())) + rng.randf() * 0.4
		var spot := CENTER + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(5.0, 10.0)
		_pending.append({"id": ids[i], "spot": spot, "stats": trash, "role": "trash"})
	if StringName(plan.mid) != &"":
		_pending.append({"id": plan.mid, "spot": CENTER + Vector3(0, 0, -4), "stats": RaidData.monster_stats(power, "mid"), "role": "mid"})
	if bool(plan.boss):
		_pending.append({"id": RaidData.BOSS_MODEL, "spot": CENTER + Vector3(0, 0, -6), "stats": RaidData.monster_stats(power, "boss"), "role": "boss"})
	var title := "ชั้น %d/%d" % [floor_no, RaidData.FLOORS]
	if bool(plan.boss):
		title += " · %s!" % RaidData.BOSS_NAME
	elif StringName(plan.mid) != &"":
		title += " · ผู้คุมชั้นปรากฏ!"
	_banner(title)
	floor_started.emit(floor_no)


## Builds at most ONE model per frame; the floor becomes targetable all at once.
func _spawn_one() -> void:
	if _pending.is_empty():
		_publish()
		return
	var entry: Dictionary = _pending.pop_front()
	var mob: Mob
	if entry.role == "boss":
		var b := RaidBoss.new()
		var add := RaidData.monster_stats(power, "trash")
		b.setup_raid(zone, entry.stats, entry.spot, hero, RaidData.trash_pool(int(power.level)), add, rng.randi())
		boss = b
		mob = b
	else:
		mob = Mob.new()
		mob.setup(entry.id, int(entry.stats.level), entry.spot, hero)
		apply_stats(mob, entry.stats)
		if entry.role == "mid":
			mob.template = mob.template.duplicate(true)
			mob.template["name"] = RaidData.MID_NAME_PREFIX + String(mob.template.name)
			mob.is_boss = true
			mid_boss = mob
	mob.position = Vector3(entry.spot.x, 0.3, entry.spot.z)
	zone.add_child(mob)
	mob.visible = false
	mob.process_mode = Node.PROCESS_MODE_DISABLED
	mob.remove_from_group("mobs")
	mob.visual.remove_from_group("anim_lod")
	mobs.append(mob)
	if _pending.is_empty():
		_publish()


func _publish() -> void:
	for m in mobs:
		if not is_instance_valid(m):
			continue
		m.add_to_group("mobs")
		m.visual.add_to_group("anim_lod")
		m.visible = true
		m.process_mode = Node.PROCESS_MODE_INHERIT
		m.provoke(false)
	if boss != null and is_instance_valid(boss):
		VfxKit.shockwave(zone, boss.global_position + Vector3(0, 0.1, 0), RaidBoss.COLOR, 10.0)
		Game.screen_flash.emit(Color(1.0, 0.15, 0.2), 0.3)
	state = "fight"


## Raid numbers on a monster ({hp, atk, def}).
static func apply_stats(mob: Mob, s: Dictionary) -> void:
	mob.stats["hp"] = int(s.get("hp", mob.stats.hp))
	mob.stats["atk"] = int(s.get("atk", mob.stats.atk))
	mob.stats["def"] = int(s.get("def", mob.stats.def))
	mob.hp = int(mob.stats.hp)
	mob.max_hp = mob.hp


func clear_floor() -> void:
	floor_cleared.emit(floor_no)
	if floor_no >= RaidData.FLOORS:
		_victory()
		return
	_banner("ชั้น %d สำเร็จ! พักฟื้นก่อนลงชั้นต่อไป" % floor_no)
	AudioManager.play_sfx(&"quest_complete", -2.0)
	_heal_party(FLOOR_HEAL)
	floor_no += 1
	state = "rest"
	_timer = REST


func _heal_party(fraction: float) -> void:
	if is_instance_valid(hero) and not hero.is_dead():
		hero.receive_heal(fraction)
	for c in party_members():
		if not c.is_dead():
			c.heal_fraction(fraction)


func _victory() -> void:
	state = "ending"
	_end_timer = END_DELAY
	for m in get_tree().get_nodes_in_group("mobs"):
		if m is Mob and m.has_meta("raid_add") and not (m as Mob).is_dead():
			(m as Mob).queue_free()
	var paid := RaidData.claim(rng)
	result = {"cleared": true, "floor": floor_no, "paid": paid, "seconds": int(elapsed), "falls": hero_falls}
	_banner("พิชิตดันเจี้ยนปาร์ตี้! %s ล้มแล้ว" % RaidData.BOSS_NAME)
	Game.screen_flash.emit(Color(1.0, 0.85, 0.4), 0.4)
	if is_instance_valid(hero):
		VfxKit.level_up(zone, hero.global_position)
	AudioManager.play_sfx(&"quest_complete")
	if not paid.is_empty():
		Game.say(("หีบรางวัลเคลียร์แรกของวัน! " if bool(paid.first) else "รางวัลดันเจี้ยน: ") + " · ".join(RaidData.reward_lines(paid)), &"success")
	_restore_hero()


func _wipe() -> void:
	state = "ending"
	_end_timer = END_DELAY
	result = {"cleared": false, "floor": floor_no, "paid": {}, "seconds": int(elapsed), "falls": hero_falls}
	_banner("ปาร์ตี้ล้มทั้งทีม · ไปถึงชั้น %d" % floor_no)
	Game.say("ดันเจี้ยนล้มเหลว รอบนี้ถูกใช้ไปแล้ว ลองจัดทีมใหม่ ให้ผู้พิทักษ์รับทุบทำลาย และหลบวงสีแดง", &"warning")
	_restore_hero()


func _restore_hero() -> void:
	var s := Game.stats_now()
	Game.profile["hp"] = s.max_hp
	Game.profile["mp"] = s.max_mp
	if is_instance_valid(hero) and hero.is_dead():
		hero.revive()
	Game.save()


# --- The fallen hero ----------------------------------------------------------------

func _on_hero_died() -> void:
	if state not in ["intro", "spawning", "fight", "rest"]:
		return
	hero_falls += 1
	if hero_falls > HERO_LIVES:
		return
	_revive_timer = REVIVE_DELAY
	Game.say("คุณล้มลง! จะฟื้นใน %d วินาทีถ้าเพื่อนยังยืนอยู่ (ฟื้นได้อีก %d ครั้ง)" % [int(REVIVE_DELAY), HERO_LIVES - hero_falls], &"warning")


func _tick_revive(delta: float) -> void:
	if _revive_timer < 0.0 or hero == null or not hero.is_dead():
		_revive_timer = -1.0
		return
	_revive_timer -= delta
	if _revive_timer > 0.0:
		return
	_revive_timer = -1.0
	if standing() == 0:
		return
	var s := Game.stats_now()
	Game.profile["hp"] = int(float(s.max_hp) * 0.5)
	Game.profile["mp"] = s.max_mp
	hero.revive()
	hero.global_position = Vector3(0, 0.3, 4)
	VfxKit.heal(zone, hero.global_position)
	Game.say("ฟื้นแล้ว! กลับไปช่วยปาร์ตี้", &"success")


# --- The line on screen -------------------------------------------------------------

func _make_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 5
	add_child(_hud)
	_line = Label.new()
	_line.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_line.offset_top = 150
	_line.offset_left = -360
	_line.offset_right = 360
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.add_theme_font_size_override("font_size", 24)
	_line.add_theme_color_override("font_color", Color("ffd0d4"))
	_line.add_theme_color_override("font_outline_color", Color(0.2, 0.0, 0.05))
	_line.add_theme_constant_override("outline_size", 8)
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_line)


func status_text() -> String:
	var text := "%s · ชั้น %d/%d" % [RaidData.SHORT, mini(floor_no, RaidData.FLOORS), RaidData.FLOORS]
	match state:
		"intro", "rest":
			text += " · เริ่มใน %d" % int(ceil(maxf(_timer, 0.0)))
		"fight":
			if boss != null and is_instance_valid(boss) and not boss.is_dead():
				text += " · คลั่งสุดขีด!" if boss.enraged else " · คลั่งใน %d:%02d" % [int(boss.enrage_left()) / 60, int(boss.enrage_left()) % 60]
				if boss.shielded():
					text += " · ฆ่าสมุนเพื่อทำลายโล่"
			else:
				text += " · ศัตรูเหลือ %d" % mobs.size()
		"ending", "done":
			text += " · สำเร็จ!" if bool(result.get("cleared", false)) else " · ล้มเหลว"
	if _revive_timer >= 0.0:
		text += " · ฟื้นใน %d" % int(ceil(_revive_timer))
	return text


func _tick_hud(delta: float) -> void:
	_hud_timer -= delta
	if _hud_timer > 0.0 or _line == null:
		return
	_hud_timer = 0.25
	_line.text = status_text()


func _banner(text: String) -> void:
	if zone != null and zone.has_signal("banner_requested"):
		zone.banner_requested.emit(text)


func _exit_tree() -> void:
	_pending.clear()
	if state == "spawning":
		for m in mobs:
			if is_instance_valid(m):
				m.queue_free()
		mobs.clear()
