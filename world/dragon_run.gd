class_name DragonRun
extends Node
## One entry of the mechanics dungeon (DungeonData): two packs of tomb guardians, then the
## Ancient Dragon King (DragonBoss) in the bone arena. Each stage's monsters come in one
## per frame and are published together (as RaidRun), the next stage follows a short rest
## that heals the party. The party is the hero and the zone's companions (world players in
## the party; real online party members fight through EntitySync).
##
## Deaths: a fallen member (the hero too) stands again at the next phase change (a pack
## cleared, a crystal phase beginning or ending); when nobody stands the run is lost (the
## entry is spent, no reward). A clear pays once (DungeonData.claim), records the clear
## time for the weekly ranking (DungeonRanking.record_clear) and the party's classes. The
## clock (`elapsed`) runs from the first pack's spawn to the kill.

signal finished(result: Dictionary)
signal stage_started(stage: int)
signal stage_cleared(stage: int)

const INTRO := 3.5
const REST := 5.0
const END_DELAY := 3.0
const CENTER := Vector3(0, 0, -10)
const STAGE_HEAL := 0.5
const REVIVE_HP := 0.5

var zone: Node3D
var hero: Hero
## 1 and 2 are the packs, PACKS + 1 the boss.
var stage := 1
var state := "intro"
var power: Dictionary = {}
var boss: DragonBoss
var mobs: Array[Mob] = []
var result: Dictionary = {}
## Seconds of the run so far (from the first pack's spawn; game time).
var elapsed := 0.0
## Times the fallen were raised (tests).
var revives := 0
## Whether the clear time was handed to the ranking (once).
var ranked := false
var rng := RandomNumberGenerator.new()
var _timer := INTRO
var _pending: Array[Dictionary] = []
var _end_timer := 0.0
var _hud: CanvasLayer
var _line: Label
var _hud_timer := 0.0
var _started := false


func setup(p_zone: Node3D, p_hero: Hero, seed_value := 0) -> void:
	zone = p_zone
	hero = p_hero
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()


func _ready() -> void:
	name = "DragonRun"
	power = party_power()
	_banner("%s · เลเวลศัตรู %d" % [DungeonData.TITLE, RaidData.shown_level(power)])
	Game.say("สุสานมังกรโบราณ: ล้างผู้พิทักษ์สุสาน %d ฝูง แล้วปราบ%s — กระจายตัวเมื่อถูกมาร์ค ให้ผู้พิทักษ์ล่อบอสรับกรงเล็บ สลับไปทุบศิลาเมื่อบอสไร้เทียมทาน (คลั่งเมื่อครบ %d:%02d นาที)" % [DungeonData.PACKS, DungeonData.BOSS_NAME, int(DragonBoss.ENRAGE_TIME) / 60, int(DragonBoss.ENRAGE_TIME) % 60], &"quest")
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


## The party's classes (the hero first): the ranking shows them.
func party_classes() -> Array:
	var out: Array = [String(Game.class_id())] if Game.has_profile else []
	for c in party_members():
		out.append(String(c.member.get("class", "")))
	return out


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
	if _started and state not in ["ending", "done"]:
		elapsed += delta
	_tick_hud(delta)
	if state in ["spawning", "fight", "rest"] and standing() == 0:
		_wipe()
		return
	match state:
		"intro", "rest":
			_timer -= delta
			if _timer <= 0.0:
				start_stage()
		"spawning":
			_spawn_one()
		"fight":
			mobs = mobs.filter(func(m): return is_instance_valid(m) and not m.is_dead())
			var done := mobs.is_empty()
			if stage > DungeonData.PACKS:
				done = boss == null or not is_instance_valid(boss) or boss.is_dead()
			if done:
				clear_stage()
		"ending":
			_end_timer -= delta
			if _end_timer <= 0.0:
				state = "done"
				finished.emit(result)


func start_stage() -> void:
	if state == "spawning":
		return
	state = "spawning"
	_started = true
	mobs.clear()
	_pending.clear()
	power = party_power()
	var title := ""
	if stage > DungeonData.PACKS:
		_pending.append({"id": DungeonData.BOSS_MODEL, "spot": CENTER + Vector3(0, 0, -6), "stats": DungeonData.monster_stats(power, "boss"), "role": "boss"})
		title = "%s ตื่นแล้ว!" % DungeonData.BOSS_NAME
	else:
		var ids := DungeonData.pack_plan(stage, rng)
		var trash := DungeonData.monster_stats(power, "trash")
		for i in ids.size():
			var angle := TAU * float(i) / float(maxi(1, ids.size())) + rng.randf() * 0.4
			var spot := CENTER + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(5.0, 9.0)
			_pending.append({"id": ids[i], "spot": spot, "stats": trash, "role": "trash"})
		title = "ฝูงผู้พิทักษ์สุสาน %d/%d" % [stage, DungeonData.PACKS]
	_banner(title)
	stage_started.emit(stage)


## Builds at most ONE model per frame; the stage becomes targetable all at once.
func _spawn_one() -> void:
	if _pending.is_empty():
		_publish()
		return
	var entry: Dictionary = _pending.pop_front()
	var mob: Mob
	if entry.role == "boss":
		var b := DragonBoss.new()
		b.setup_dungeon(zone, entry.stats, entry.spot, hero, DungeonData.monster_stats(power, "crystal"), rng.randi())
		b.phase_changed.connect(_on_boss_phase)
		boss = b
		mob = b
	else:
		mob = Mob.new()
		mob.setup(entry.id, int(entry.stats.level), entry.spot, hero)
		RaidRun.apply_stats(mob, entry.stats)
		mob.template = mob.template.duplicate(true)
		mob.template["name"] = "ผู้พิทักษ์สุสาน · " + String(mob.template.name)
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
		VfxKit.shockwave(zone, boss.global_position + Vector3(0, 0.1, 0), DragonBoss.COLOR, 10.0)
		Game.screen_flash.emit(Color(0.4, 1.0, 0.6), 0.3)
	state = "fight"


func clear_stage() -> void:
	stage_cleared.emit(stage)
	if stage > DungeonData.PACKS:
		_victory()
		return
	_banner("ฝูง %d ล้มแล้ว! พักฟื้นก่อน%s" % [stage, "เผชิญหน้าบอส" if stage == DungeonData.PACKS else "ฝูงต่อไป"])
	AudioManager.play_sfx(&"quest_complete", -2.0)
	revive_fallen()
	_heal_party(STAGE_HEAL)
	stage += 1
	state = "rest"
	_timer = REST


## A phase change of the boss (a crystal phase begins or ends): the fallen stand again.
func _on_boss_phase(_mob: Mob, _phase: int) -> void:
	if state != "fight":
		return
	revive_fallen()


## Every fallen member stands again at REVIVE_HP (the hero too).
func revive_fallen() -> void:
	var raised := 0
	if is_instance_valid(hero) and hero.is_dead():
		var s := Game.stats_now()
		Game.profile["hp"] = int(float(s.max_hp) * REVIVE_HP)
		Game.profile["mp"] = s.max_mp
		hero.revive()
		hero.global_position = Vector3(0, 0.3, 4)
		VfxKit.heal(zone, hero.global_position)
		raised += 1
	for c in party_members():
		if c.is_dead():
			c._revive()
			raised += 1
	if raised > 0:
		revives += raised
		Game.say("เปลี่ยนช่วง! ผู้ที่ล้มลุกขึ้นมาแล้ว %d คน" % raised, &"success")


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
		if m is Mob and m.has_meta("tomb_crystal") and not (m as Mob).is_dead():
			(m as Mob).queue_free()
	var seconds := int(round(elapsed))
	var paid := DungeonData.claim(rng, seconds)
	var classes := party_classes()
	result = {"cleared": true, "stage": stage, "paid": paid, "seconds": seconds, "classes": classes, "revives": revives,
		"fast": seconds <= DungeonData.FAST_SECONDS, "ranked": false}
	if not ranked and not paid.is_empty():
		ranked = true
		result["ranked"] = DungeonRanking.record_clear(seconds, classes)
	_banner("พิชิตสุสานมังกรโบราณ! %s ล้มแล้ว · %s" % [DungeonData.BOSS_NAME, DungeonData.time_text(seconds)])
	Game.screen_flash.emit(Color(1.0, 0.85, 0.4), 0.4)
	if is_instance_valid(hero):
		VfxKit.level_up(zone, hero.global_position)
	AudioManager.play_sfx(&"quest_complete")
	if not paid.is_empty():
		Game.say(("เคลียร์แรกของสัปดาห์! เกล็ดมังกร x%d · " % int(paid.scales) if bool(paid.first_week) else "รางวัลสุสาน: ") + " · ".join(DungeonData.reward_lines(paid)), &"success")
		if bool(result.fast):
			Game.say("เคลียร์ใน %s! ได้ตำแหน่ง \"ผู้พิชิตสุสานมังกร\"" % DungeonData.time_text(seconds), &"success")
	_restore_hero()


func _wipe() -> void:
	state = "ending"
	_end_timer = END_DELAY
	result = {"cleared": false, "stage": stage, "paid": {}, "seconds": int(round(elapsed)), "classes": party_classes(), "revives": revives, "fast": false, "ranked": false}
	_banner("ปาร์ตี้ล้มทั้งสี่ · ไปถึง%s" % ("บอส" if stage > DungeonData.PACKS else "ฝูงที่ %d" % stage))
	Game.say("ดันเจี้ยนล้มเหลว รอบนี้ถูกใช้ไปแล้ว — กระจายตัวเมื่อถูกมาร์ค ให้ผู้พิทักษ์รับกรงเล็บ และทุบศิลาให้ทัน", &"warning")
	_restore_hero()


func _restore_hero() -> void:
	var s := Game.stats_now()
	Game.profile["hp"] = s.max_hp
	Game.profile["mp"] = s.max_mp
	if is_instance_valid(hero) and hero.is_dead():
		hero.revive()
	Game.save()


## The hero fell: it waits for the next phase change (or the wipe).
func _on_hero_died() -> void:
	if state not in ["spawning", "fight", "rest"]:
		return
	if standing() > 0:
		Game.say("คุณล้มลง! จะลุกขึ้นเมื่อเปลี่ยนช่วง (ฝูงล้ม / ศิลาขึ้นหรือแตก) ถ้าเพื่อนยังยืนอยู่", &"warning")


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
	_line.add_theme_color_override("font_color", Color("d0ffd8"))
	_line.add_theme_color_override("font_outline_color", Color(0.0, 0.12, 0.06))
	_line.add_theme_constant_override("outline_size", 8)
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_line)


func status_text() -> String:
	var text := "%s · %s" % [DungeonData.SHORT, DungeonData.time_text(int(elapsed))]
	match state:
		"intro", "rest":
			text += " · เริ่มใน %d" % int(ceil(maxf(_timer, 0.0)))
		"fight":
			if boss != null and is_instance_valid(boss) and not boss.is_dead():
				text += " · คลั่งสุดขีด!" if boss.enraged else " · คลั่งใน %d:%02d" % [int(boss.enrage_left()) / 60, int(boss.enrage_left()) % 60]
				if boss.shielded():
					text += " · ทุบศิลามังกร %d วิ" % int(ceil(boss.crystal_left))
			else:
				text += " · ฝูง %d/%d · ศัตรูเหลือ %d" % [stage, DungeonData.PACKS, mobs.size()]
		"ending", "done":
			text += " · สำเร็จ!" if bool(result.get("cleared", false)) else " · ล้มเหลว"
	if is_instance_valid(hero) and hero.is_dead() and state == "fight":
		text += " · รอเปลี่ยนช่วงเพื่อฟื้น"
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
