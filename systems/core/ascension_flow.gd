class_name AscensionFlow
extends Node
## The celestial sage's talk (AscensionData.ROLE) for บททดสอบเทวาลัย, on Main beside
## StoryChapter: offers the trial to a God at ★500, tells each step's progress, sends the
## hero into the trial stage (Main.go(AscensionData.STAGE_ID)) and greets the Ascended.
## Also tells the hero when ★500 opens the trial.

var main: Node


func _ready() -> void:
	name = "AscensionFlow"
	Game.paragon_leveled.connect(_on_star)


func _on_star(level: int) -> void:
	if level >= JobData.ASCEND_STARS and Game.adv() == JobData.GOD_ADV and AscensionData.step() == 0 and main != null:
		if main.get("hud") != null:
			main.hud.show_banner("ถึงดาว %d! %s เปิดแล้ว" % [JobData.ASCEND_STARS, AscensionData.TITLE])
		Game.say("ไปหา%s ข้างปรมาจารย์ผู้เปลี่ยนชะตา เพื่อรับ%s (เปลี่ยนอาชีพขั้นที่ 6)" % [AscensionData.SAGE, AscensionData.TITLE], &"quest")


func _say(text: String, choices: Array = []) -> void:
	if main != null and main.get("dialog") != null:
		main.dialog.say(AscensionData.SAGE, text, choices)


## What the sage says now (also used by tests).
func talk() -> void:
	var asc := JobData.ascend_step(Game.class_id())
	match AscensionData.step():
		AscensionData.DONE:
			_say("ข้าน้อยคารวะ \"%s\" — %s ประตูเทวาลัยเปิดรับท่านแล้ว จงใช้พลังนี้ปกป้องสามภพ" % [Game.class_data().name, Game.class_data().title])
		0:
			var problem := AscensionData.start_problem()
			if problem != "":
				_say("เหนือเทพเจ้ายังมีอีกขั้น... \"%s\" — %s\nแต่%s\nเมื่อพร้อม จงกลับมาหาข้าเพื่อรับ%s" % [asc.get("name", ""), asc.get("title", ""), problem, AscensionData.TITLE])
				return
			var lines: PackedStringArray = ["ดาว %d... เจ้ามาถึงประตูเทวาลัยแล้ว" % JobData.ASCEND_STARS,
				"%s มี 3 ขั้น:" % AscensionData.TITLE,
				"1) " + String(AscensionData.STEPS[0].desc) % [AscensionData.HUNT_COUNT, AscensionData.BOSS_WORTH],
				"2) " + String(AscensionData.STEPS[1].desc) % AscensionData.TOKEN_COUNT,
				"3) " + String(AscensionData.STEPS[2].desc) % int(AscensionData.ENRAGE_SECONDS),
				"ผ่านแล้วจะเป็น \"%s\" — %s พร้อมสกิลเทวาลัย 2 สกิล: %s" % [asc.get("name", ""), asc.get("title", ""), " และ ".join(AscendSkillData.pool(Game.class_id()).map(func(s): return String(s.name)))],
				"โบนัส: %s  %s" % [JobData.attr_text(asc.get("attrs", {})), JobData.bonus_text(asc.get("bonus", {}))]]
			_say("\n".join(lines), [{"label": "รับบททดสอบ", "action": func(): AscensionData.start()}, {"label": "ไว้ก่อน"}])
		AscensionData.TRIAL:
			_say("เจ้าพร้อมแล้ว ตราเทวาลัยครบ %d ชิ้น ลานบททดสอบจะเปิดให้เจ้าเพียงลำพัง ปราบ%s ภายใน %d วินาที ก่อนมันคลั่ง (พยายามมาแล้ว %d ครั้ง)" % [AscensionData.TOKEN_COUNT, AscensionData.BOSS_NAME, int(AscensionData.ENRAGE_SECONDS), AscensionData.tries()],
				[{"label": "เข้าลานบททดสอบ", "action": func(): enter()}, {"label": "ไว้ก่อน"}])
		_:
			_say("%s ขั้นที่ %d/3: %s" % [AscensionData.TITLE, AscensionData.step(), AscensionData.objective_text()])


## Into the trial stage (solo: the party waits in the village).
func enter() -> bool:
	if AscensionData.trial_problem() != "":
		Game.say(AscensionData.trial_problem(), &"warning")
		return false
	if main != null and main.has_method("go"):
		main.go(AscensionData.STAGE_ID)
	return true
