class_name StoryChapter
extends Node
## The runtime of บทที่ 2: เงาเหนือดวงดาว (StoryChapter2): a node on Main like Tutorial. It
## talks for the three chapter NPCs (talk), pays the quests, runs the investigation markers,
## the escort and the mid-boss in the fields, keeps the stage portal up while the finale is
## active, and plays the ending when the throne stage is won. Every TICK seconds `tick`
## reads the game state (tests drive it with big deltas). A hero of ★200 who has not
## started the chapter is told once a session (a toast) that the scholar is looking for them.

const TICK := 0.5
const MARK_REACH := 3.5
const ESCORT_SPOT := Vector3(-6, 0, -14)
const ESCORT_WAVE_EVERY := 9.0
const ESCORT_WAVE_SIZE := 3
const ESCORT_RADIUS := 9.0
const MIDBOSS_SPOT := Vector3(0, 0, -8)
const MIDBOSS_LEVEL := EndgameFields.BOSS_LEVEL

var main: Node
## Escort attempt: {escort, elapsed, wave_timer, mobs, npc} while one runs.
var escort: Dictionary = {}
## The mid-boss spawned by the guardian's rite (while it stands).
var mid_boss: Mob
## Every toast and banner shown by the chapter (tests).
var shown: Array[String] = []
var _tick := 0.0
var _told := {}
var _marks: Array[Node3D] = []
var _marks_zone: Node3D
var _collect_told := {}
var _ending: Node


func _ready() -> void:
	name = "StoryChapter"
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	tick(TICK)


## One look at the game: the offer toast, the investigation, the collect quests, the escort
## clock and the stage portal. `delta` is the game time since the last look.
func tick(delta: float) -> void:
	if not _in_play():
		if not escort.is_empty():
			_end_escort(false, true)
		return
	var zone: Zone = main.zone
	if zone == null or not is_instance_valid(zone) or not zone.is_built:
		return
	_offer_toast()
	_tick_marks(zone)
	_tick_collect()
	_tick_escort(zone, delta)
	if zone.zone_id == DrownedAbyssData.ID and StoryChapter2.portal_open():
		zone.add_story_portal()


func _in_play() -> bool:
	return main != null and Game.playing and Game.has_profile and main.title_screen == null


func _say(text: String, kind: StringName = &"quest") -> void:
	shown.append(text)
	Game.say(text, kind)


## A ★200 hero who has not begun: told once a session where the chapter starts.
func _offer_toast() -> void:
	if not StoryChapter2.offer_open():
		return
	var who := "%d|%s" % [Game.slot, String(Game.profile.get("name", ""))]
	if _told.has(who):
		return
	_told[who] = true
	_say("เควสต์เนื้อเรื่องใหม่: %s — %sรอเจ้าอยู่ที่หมู่บ้าน (ข้างเจดีย์)" % [StoryChapter2.TITLE, StoryChapter2.role_name("scholar")])


# --- Dialog -----------------------------------------------------------------------------

## The hero talks to a chapter NPC (Main._on_npc).
func talk(role: String) -> void:
	var dialog: DialogBox = main.dialog
	var speaker := StoryChapter2.role_name(role)
	var id := StoryChapter2.current()
	# 1. A talk quest sends the hero here: it is finished, and paid when this NPC pays it.
	if id != "":
		var quest := StoryChapter2.get_quest(id)
		var st := StoryChapter2.status(id)
		if st == "active" and String(quest.type) == "talk" and String(quest.npc) == role:
			Game.set_quest(id, "ready", 1)
			if StoryChapter2.turn_in_role(id) == role:
				dialog.say(speaker, _talk_text(id), [{"label": "รับรางวัล", "action": func(): _reward(id)}])
				return
			dialog.say(speaker, _talk_text(id))
			return
		# 2. A finished quest this NPC pays.
		if st == "ready" and StoryChapter2.turn_in_role(id) == role:
			dialog.say(speaker, _done_text(id), [{"label": "รับรางวัล", "action": func(): _reward(id)}])
			return
		# 3. The quest this NPC offers, or is helping with.
		if String(quest.giver) == role:
			if st == "new":
				var problem := StoryChapter2.unlock_problem(quest)
				if problem != "":
					dialog.say(speaker, _locked_text(role, problem))
					return
				dialog.say(speaker, _offer_text(id), [
					{"label": "รับเควสต์", "action": func():
						Game.set_quest(id, "active", 0)
						if String(quest.type) == "investigate":
							Game.profile["flags"][StoryChapter2.MARKS_FLAG] = 0
						_say("รับเควสต์: %s" % quest.name)
						Game.save()},
					{"label": "ไว้ก่อน"}])
				return
			if st == "active":
				_active_dialog(role, id, quest)
				return
	# 4. Nothing in hand for this NPC: its line for where the story stands.
	dialog.say(speaker, _idle_text(role))


## The giver of an active quest: progress, or the start of the escort / the rite.
func _active_dialog(role: String, id: String, quest: Dictionary) -> void:
	var dialog: DialogBox = main.dialog
	var speaker := StoryChapter2.role_name(role)
	var zone: Zone = main.zone
	match String(quest.type):
		"escort":
			if not escort.is_empty():
				dialog.say(speaker, "ข้ากำลังอ่านอยู่! กันพวกมันไว้อีก %d วินาที!" % int(ceil(StoryChapter2.ESCORT_SECONDS - float(escort.elapsed))))
			elif zone.zone_id != DrownedAbyssData.ID:
				dialog.say(speaker, "สายโยงเงาอยู่กลางเมืองจมน้ำ ไปพบข้าที่ห้วงสมุทรอสูรแล้วเริ่มกัน")
			else:
				dialog.say(speaker, "ข้าจะวิ่งไปที่สายโยงเงาแล้วอ่านจารึก ใช้เวลา %d วินาที ฝูงอสูรจะกรูเข้ามาแน่ เจ้าต้องกันพวกมันไว้ให้ได้ พร้อมไหม?" % int(quest.seconds), [
					{"label": "เริ่มพิธี", "action": func(): start_escort()}, {"label": "ยังก่อน"}])
		"boss":
			if mid_boss != null and is_instance_valid(mid_boss) and not mid_boss.is_dead():
				dialog.say(speaker, "ซาเลียออกมาแล้ว! หลบคลื่นเงาและหอกเงาบนพื้น แล้วฟันมันให้ร่วง!")
			elif zone.zone_id != DivineRegionData.ID:
				dialog.say(speaker, "พิธีเรียกเงาสะท้อนต้องทำที่หน้าวิหารบัวดารา กลับไปพบข้าที่นั่น")
			else:
				dialog.say(speaker, "ข้าจะเปิดปากสายโยงด้วยแสงดาวที่เหลือ เงาสะท้อนของออเรเลียจะพุ่งออกมา มันมีท่าคลื่นเงารอบตัวและหอกเงาพุ่งตรง มองพื้นแล้วหลบให้ดี พร้อมแล้วใช่ไหม?", [
					{"label": "เริ่มพิธี", "action": func(): start_mid_boss()}, {"label": "ยังก่อน"}])
		"collect":
			dialog.say(speaker, "%s ตอนนี้มี %d/%d แล้ว ไปล่าต่อเถอะ" % [StoryChapter2.objective_text(id), mini(StoryChapter2.collected(id), int(quest.count)), int(quest.count)])
		"finale":
			dialog.say(speaker, "ประตูบัลลังก์เงาเปิดอยู่ในห้วงสมุทรอสูร ใกล้ลานบัลลังก์ราชันสมุทร (ต้องดาว 300) นิรามีสามช่วง ทุกครั้งที่นางเปลี่ยนช่วงจะพูดและเรียกเงาเพิ่ม อย่าลืมหลบรูปร่างสีม่วงบนพื้น ขอให้ดาวคุ้มครองเจ้า")
		_:
			dialog.say(speaker, "ยังไม่เสร็จนะ... %s" % StoryChapter2.objective_text(id))


func _offer_text(id: String) -> String:
	var quest := StoryChapter2.get_quest(id)
	var head := ""
	match id:
		"ch2_omen":
			head = "เจ้าคือผู้ปราบราชันสุริยคราสใช่ไหม! ข้าดูดาวทุกคืน และดาวเหนือวิหารบัวดาราหรี่ลงทีละดวง... ไม่ใช่เมฆ ไม่ใช่ฤดู มีอะไรกำลังดูดแสงดาวอยู่ ข้าขอฝากเจ้าไปถามเทพพิทักษ์หยกวารีที่หน้าวิหารที\n\n"
		"ch2_sprites":
			head = "ภูตบัวประกายดาวตาดำวาวและแสงในตัวพวกมันหายไป เหมือนถูกเงาครอบงำ ไปสงบพวกมันในสวนบัวเรืองแสง แล้วข้าจะดูว่าเงานั่นทิ้งร่องรอยอะไรไว้\n\n"
		"ch2_scales":
			head = "ดูเกล็ดบัวดารานี่สิ... เกล็ดที่เคยสว่างกลับขุ่นมัว ข้าต้องการเกล็ด 5 เกล็ดจากมอนสเตอร์แถวนี้หรือในห้วงสมุทรอสูร เพื่อตามว่าแสงถูกดูดไปทางไหน\n\n"
		"ch2_landmarks":
			head = "เกล็ดบอกว่าแสงไหลลงสู่เบื้องล่าง ทางเหนือมีศาลาดาวร้าว ทางตะวันออกสระบัวดับแสง และทางตะวันตกเฉียงใต้เสาจารึกเงา ไปยืนดูให้ครบทั้งสามแห่ง แล้วกลับมาเล่าให้ข้าฟัง\n\n"
		"ch2_exile":
			head = "รอยเงาทุกแห่งชี้ลงไปที่เมืองจมน้ำใต้วิหาร... ห้วงสมุทรอสูร! ข้าได้ยินว่ามีผู้ลี้ภัยคนหนึ่งหนีขึ้นมาจากที่นั่น ชื่อนาวิน ไปหาเขาที่ทางเข้าห้วงสมุทรอสูรที\n\n"
		"ch2_mermen":
			head = "เจ้ามาจากหยกวารีงั้นหรือ... ฟังนะ นักรบเงือกทมิฬพวกนั้นเคยเป็นพี่น้องของข้า ก่อนราชินีเงาจะกลืนใจพวกเขา ถ้าเจ้าล้มพวกเขา 15 คน เงาในตัวจะหลุดออก ขอร้อง ช่วยปลดปล่อยพวกเขาที\n\n"
		"ch2_escort":
			head = "กลางเมืองมีสายโยงเงาเส้นใหญ่ โยงจากสระบัวในวิหารลงมาถึงบัลลังก์ของนาง ข้าอ่านจารึกบนสายนั่นได้ แต่ต้องใช้เวลา 60 วินาที และฝูงอสูรจะไม่ปล่อยข้าแน่ เจ้าช่วยกันพวกมันให้ข้าได้ไหม\n\n"
		"ch2_midboss":
			head = "จารึกที่นาวินอ่านมาบอกว่า นิรา ราชินีเงาแห่งห้วงลึก เคยเป็นนักบวชแห่งดวงดาวของวิหารนี้เอง... นางสร้างเงาสะท้อนของออเรเลียไว้เฝ้าปากสายโยงในวิหาร ข้าจะทำพิธีเรียกมันออกมา เจ้าต้องปราบมัน\n\n"
		"ch2_chaos":
			head = "ปากสายโยงเปิดแล้ว ทีนี้ต้องผนึกไม่ให้แสงดาวไหลลงไปอีก เพชรชาออสผนึกเงาได้ดีที่สุด เอามาให้ข้า 8 เม็ด มอนสเตอร์แถวนี้ดรอปบ่อยกว่าที่อื่น\n\n"
		"ch2_elites":
			head = "ร่องลึกเลวีอาธานคือทางลงสู่บัลลังก์ อสูรหนวดและลูกเลวีอาธานคุมอยู่ ล้มพวกมัน 10 ตัวให้ทางโล่ง\n\n"
		"ch2_tyrant":
			head = "โพไซดอน ราชันสมุทรอสูร... นางครอบงำท่านไว้เฝ้าประตู ปราบท่านที่ลานบัลลังก์ราชันสมุทร เงาจะหลุดจากท่าน และประตูบัลลังก์เงาจะเผยตัว\n\n"
		"ch2_throne":
			head = "ข้าเรียบเรียงทุกอย่างแล้ว: นิราดูดแสงดาวจากเกล็ดบัวผ่านสายโยงลงไปสร้างบัลลังก์เงาเหนือดวงดาว ถ้าเจ้ารับงานนี้ ประตูบัลลังก์จะปรากฏในห้วงสมุทรอสูร แต่ต้องมีดาว 300 ถึงเข้าได้ นี่คือบทสุดท้าย... ไปดับเงาเหนือดวงดาวให้สิ้นเถอะ\n\n"
	return "%sเควสต์: %s\n%s" % [head, quest.name, quest.desc]


func _talk_text(id: String) -> String:
	match id:
		"ch2_omen":
			return "ปิ่นดาราส่งเจ้ามางั้นหรือ... ใช่ ดาวเหนือวิหารกำลังดับ และภูตบัวของข้าเริ่มคลั่ง ข้าคือหยกวารี ผู้พิทักษ์วิหารนี้ ข้าต้องการความช่วยเหลือจากวีรบุรุษอย่างเจ้า นี่คือของขวัญต้อนรับ"
		"ch2_exile":
			return "...เจ้ามาจากวิหารข้างบนงั้นหรือ ข้าคือนาวิน เคยเป็นนักรบเงือกของเมืองนี้ก่อนที่นางจะมา ราชินีเงาแห่งห้วงลึก... นางเคยเป็นนักบวชแห่งดวงดาวของวิหารนั่นแหละ รับนี่ไว้ แล้วฟังข้าให้จบ"
	return "ขอบคุณที่มา รับรางวัลไปก่อน"


func _done_text(id: String) -> String:
	match id:
		"ch2_sprites":
			return "แสงในตัวภูตกลับมาแล้ว และดูนี่... เงาดำทิ้งเกล็ดบัวที่ไร้แสงไว้ เบาะแสแรกของเรา"
		"ch2_scales":
			return "เกล็ดทั้งห้า... แสงไหลลงสู่เบื้องล่างทั้งหมด ไม่ใช่ขึ้นฟ้า มีอะไรใต้วิหารนี้ดูดมันไป"
		"ch2_landmarks":
			return "ศาลาร้าว สระดับ เสาจารึก... ทั้งสามแห่งเรียงเป็นเส้นตรงลงสู่ทะเล นี่คือเงาของสายโยง เจ้าทำได้ดีมาก"
		"ch2_mermen":
			return "...เงาหลุดจากพี่น้องข้าแล้ว ขอบคุณ ขอบคุณจริง ๆ ทีนี้ข้าพร้อมจะอ่านจารึกบนสายโยงให้เจ้า"
		"ch2_escort":
			return "อ่านจบแล้ว! สายโยงนี้ดูดแสงจากเกล็ดบัวดาราลงสู่บัลลังก์ของนาง และนางสร้างเงาสะท้อนของผู้พิทักษ์ไว้ที่ปากสายข้างบน... บอกหยกวารีด้วย"
		"ch2_midboss":
			return "เงาสะท้อนของออเรเลียสลายแล้ว ปากสายโยงเปิดอยู่ตรงหน้า ขอบคุณที่สู้แทนวิหารนี้ นี่คือแก่นเทพที่เงาทิ้งไว้"
		"ch2_chaos":
			return "ผนึกแล้ว! แสงดาวหยุดไหลลงไปแล้ว นางจะอ่อนแรงลง ทีนี้ก็เหลือแค่ทางลงสู่บัลลังก์"
		"ch2_elites":
			return "ร่องลึกโล่งแล้ว เหลือแค่... ท่านโพไซดอน นางครอบงำท่านไว้เฝ้าประตู"
		"ch2_tyrant":
			return "เงาหลุดจากราชันสมุทรแล้ว และข้าเห็นประตูมืดเผยตัวข้างลานบัลลังก์... ไปบอกปิ่นดาราว่าทุกอย่างพร้อมแล้ว"
	return "เยี่ยมมาก! นี่คือรางวัลของเจ้า"


func _locked_text(role: String, problem: String) -> String:
	match role:
		"scholar":
			return "ข้าเห็นเจ้าในดวงดาว แต่ยังไม่ถึงเวลา... %s" % problem
		"sanctum_guardian":
			return "แสงของเจ้ายังไม่พอรับงานนี้ %s" % problem
	return "ยังไม่ถึงเวลา %s" % problem


## What an NPC says with nothing to give or take: by where the story stands (each has
## at least three such states besides its quests).
func _idle_text(role: String) -> String:
	var id := StoryChapter2.current()
	var done := StoryChapter2.finished()
	var started := StoryChapter2.started()
	match role:
		"scholar":
			if done:
				return "ตำนานบทที่ 2 จบลงที่เจ้า ผู้ดับเงาเหนือดวงดาว ข้าจดทุกบรรทัดไว้แล้ว ดาวเหนือวิหารสว่างกว่าที่เคย... แต่ห้วงลึกยังมีเรื่องเล่าอีกมาก ไว้พบกันใหม่นะ"
			if not started:
				if not Game.has_profile or int(Game.profile.get("level", 1)) < Game.MAX_LEVEL or int(Game.paragon().level) < 200:
					return "ข้าคือปิ่นดารา นักปราชญ์ผู้ดูดาว ดาวเหนือวิหารบัวดาราหรี่ลงทุกคืน... แต่คนที่จะช่วยได้ต้องเป็นผู้ที่มีดาวถึง 200 กลับมาเมื่อเจ้าแข็งแกร่งพอนะ"
				return "ข้าคือปิ่นดารา ดาวบอกข้าว่าเจ้าคือคนที่ข้ารอ"
			if id in ["ch2_omen", "ch2_sprites", "ch2_scales", "ch2_landmarks"]:
				return "หยกวารีเป็นผู้พิทักษ์ที่น่าเชื่อถือ ทำตามที่นางบอกเถอะ ข้าจะดูดาวต่อจากที่นี่"
			if id in ["ch2_exile", "ch2_mermen", "ch2_escort"]:
				return "ผู้ลี้ภัยจากห้วงลึก... ถ้าเขารู้เรื่องสายโยงเงาจริง ทุกอย่างจะกระจ่าง ระวังตัวในเมืองจมน้ำนะ"
			return "ชื่อ \"นิรา\" อยู่ในบันทึกเก่าของวิหาร: นักบวชแห่งดวงดาวที่หายไปในทะเล... นางคือราชินีเงาจริง ๆ สินะ ทำงานของนาวินกับหยกวารีให้เสร็จ แล้วกลับมาหาข้าสำหรับบทสุดท้าย"
		"sanctum_guardian":
			if done:
				return "ดาวกลับมาส่องเหนือวิหารแล้ว ผู้ดับเงาเหนือดวงดาว วิหารบัวดาราเป็นหนี้เจ้าตลอดไป"
			if not started or id == "ch2_omen":
				return "ยินดีต้อนรับสู่วิหารบัวดารา ข้าคือหยกวารี ผู้พิทักษ์ที่นี่ ...ดาวข้างบนหรี่ลงทุกคืน ถ้าเจ้ามาจากหมู่บ้าน ช่วยบอกปิ่นดาราด้วยว่าข้ากังวล"
			if id in ["ch2_exile", "ch2_mermen", "ch2_escort"]:
				return "นาวินอยู่ที่ทางเข้าห้วงสมุทรอสูร เขารู้เรื่องเบื้องล่างดีกว่าข้า ไปเถอะ"
			if id in ["ch2_chaos", "ch2_elites", "ch2_tyrant", "ch2_throne"]:
				return "ปากสายโยงเปิดอยู่ตรงนี้ ข้าจะเฝ้าไม่ให้เงาใดขึ้นมาอีก ส่วนเบื้องล่าง... ฝากเจ้าแล้วนะ"
			return "ดาวยังหรี่อยู่ รีบหน่อยนะวีรบุรุษ"
		"abyss_exile":
			if done:
				return "พี่น้องของข้าว่ายน้ำได้อย่างอิสระอีกครั้ง... ขอบคุณ ผู้ดับเงาเหนือดวงดาว เมืองนี้จะกลับมาร้องเพลงอีกครั้ง"
			if not started or id in ["ch2_omen", "ch2_sprites", "ch2_scales", "ch2_landmarks"]:
				return "...อย่าลงไปลึกกว่านี้ถ้าไม่จำเป็น นางเฝ้าดูอยู่เสมอ (ชายผู้นี้ดูเหมือนไม่อยากพูดอะไรมากกว่านี้)"
			if id == "ch2_exile":
				return "เจ้ามาจากวิหารข้างบนงั้นหรือ... เข้ามาใกล้อีกหน่อยสิ"
			if id == "ch2_midboss":
				return "เงาสะท้อนอยู่ที่ปากสายโยงในวิหาร ไปช่วยหยกวารีก่อน แล้วกลับมาหาข้า"
			if id == "ch2_throne":
				return "ประตูมืดข้างลานบัลลังก์... นั่นแหละทางไป ขอให้ดาวคุ้มครองเจ้า และ... ถ้าพบนาง บอกนางว่าพี่น้องของข้ายกโทษให้แล้ว"
			return "สายโยงเงาอยู่กลางเมือง ข้าจะรออยู่ตรงนี้"
	return "..."


# --- Rewards ----------------------------------------------------------------------------

## Pays quest `id` once (it is "done" afterwards) and tells the story on.
func _reward(id: String) -> void:
	if StoryChapter2.status(id) == "done":
		return
	var quest := StoryChapter2.get_quest(id)
	if String(quest.type) == "collect":
		if Game.jewel_count(String(quest.item)) < int(quest.count):
			_say("ยังมี%sไม่ครบ %d" % [ItemData.JEWELS[String(quest.item)].name, int(quest.count)], &"warning")
			return
		Game._spend_jewels(String(quest.item), int(quest.count))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pay := StoryChapter2.reward(id, rng)
	Game.set_quest(id, "done")
	Game.add_exp(int(pay.exp))
	Game.add_gold(int(pay.gold))
	for item in pay.items:
		Game.add_item(item)
	if String(quest.type) == "finale":
		_finale_rewards()
	AudioManager.play_sfx(&"quest_complete")
	_say("เควสต์สำเร็จ! %s — EXP +%d เหรียญ +%d" % [quest.name, int(pay.exp), int(pay.gold)], &"success")
	var next := StoryChapter2.current()
	if next != "" and StoryChapter2.status(next) == "new":
		var nq := StoryChapter2.get_quest(next)
		_say("ต่อไป: %s — คุยกับ%s" % [nq.name, StoryChapter2.role_name(String(nq.giver))])
	Game.check_achievements()
	Game.save()


## The chapter's close: the done flag (its titled achievement, Achievements), the title worn
## and รัศมีดาวเงา, the cosmetic aura (HeroVisual).
func _finale_rewards() -> void:
	Game.profile["flags"][StoryChapter2.DONE_FLAG] = 1
	Game.profile["flags"][StoryChapter2.AURA_FLAG] = 1
	Game._check_achievements()
	var k := Achievements.index_of(StoryChapter2.ACH_ID)
	if k >= 0:
		Game.set_title(k)
	_say("ได้รับตำแหน่ง \"%s\" และรัศมีดาวเงา!" % StoryChapter2.END_TITLE, &"success")
	var zone: Zone = main.zone
	if zone != null and is_instance_valid(zone) and is_instance_valid(zone.hero) and zone.hero.visual != null:
		zone.hero.visual.story_aura = true
		zone.hero.visual.refresh()


# --- The investigation -----------------------------------------------------------------

func _tick_marks(zone: Zone) -> void:
	var active := zone.zone_id == DivineRegionData.ID and StoryChapter2.status("ch2_landmarks") == "active"
	if not active:
		_clear_marks()
		return
	var quest := StoryChapter2.get_quest("ch2_landmarks")
	if _marks.is_empty() or _marks_zone != zone:
		_clear_marks()
		_marks_zone = zone
		for k in (quest.marks as Array).size():
			var mark: Array = quest.marks[k]
			var node := StoryChapter2Art.landmark(zone, mark[1], String(mark[0]), k)
			node.visible = not StoryChapter2.mark_seen(k)
			_marks.append(node)
	if not is_instance_valid(zone.hero):
		return
	var seen := StoryChapter2.marks_seen()
	for k in (quest.marks as Array).size():
		if seen & (1 << k) != 0:
			continue
		var at: Vector3 = quest.marks[k][1]
		var d := zone.hero.global_position - at
		d.y = 0.0
		if d.length() <= MARK_REACH:
			seen |= 1 << k
			Game.profile["flags"][StoryChapter2.MARKS_FLAG] = seen
			if k < _marks.size() and is_instance_valid(_marks[k]):
				_marks[k].visible = false
			VfxKit.shockwave(zone, at + Vector3(0, 0.1, 0), StoryChapter2Art.VIOLET, 3.0)
			var count := 0
			for j in (quest.marks as Array).size():
				if seen & (1 << j) != 0:
					count += 1
			if count >= int(quest.count):
				Game.set_quest("ch2_landmarks", "ready", count)
				_say("สำรวจครบทั้งสามแห่งแล้ว! กลับไปรายงานหยกวารี")
			else:
				Game.set_quest("ch2_landmarks", "active", count)
				_say("พบรอยเงา: %s (%d/%d)" % [quest.marks[k][0], count, int(quest.count)])


func _clear_marks() -> void:
	for m in _marks:
		if is_instance_valid(m):
			m.queue_free()
	_marks.clear()
	_marks_zone = null


# --- Collect quests -------------------------------------------------------------------

func _tick_collect() -> void:
	for id in StoryChapter2.ORDER:
		var quest := StoryChapter2.get_quest(id)
		if String(quest.type) != "collect":
			continue
		var st := StoryChapter2.status(id)
		if st not in ["active", "ready"]:
			continue
		var have := StoryChapter2.collected(id)
		var enough := have >= int(quest.count)
		if enough and st == "active":
			Game.set_quest(id, "ready", int(quest.count))
			if not _collect_told.has(id):
				_collect_told[id] = true
				_say("เก็บ%sครบแล้ว! กลับไปรายงาน%s" % [ItemData.JEWELS[String(quest.item)].name, StoryChapter2.turn_in_name(id)])
		elif not enough and st == "ready":
			Game.set_quest(id, "active", have)


# --- The escort -------------------------------------------------------------------------

## นาวิน runs to the conduit and reads; the waves come until the clock runs out.
func start_escort() -> void:
	var zone: Zone = main.zone
	if not escort.is_empty() or zone == null or zone.zone_id != DrownedAbyssData.ID or StoryChapter2.status("ch2_escort") != "active":
		return
	var body := StoryEscort.new()
	body.position = ESCORT_SPOT
	zone.add_child(body)
	body.setup(Game.stats_now(), Npc.LOOKS.get("abyss_exile", {}))
	body.fell.connect(func(): _end_escort(false))
	var npc: Npc = null
	for n in zone.npcs:
		if n.role == "abyss_exile":
			npc = n
	if npc != null:
		npc.visible = false
		zone.npcs.erase(npc)
	escort = {"escort": body, "elapsed": 0.0, "wave_timer": 1.5, "mobs": [], "npc": npc, "zone": zone}
	zone.banner_requested.emit("ปกป้องนาวิน %d วินาที!" % int(StoryChapter2.ESCORT_SECONDS))
	_say("นาวินวิ่งไปที่สายโยงเงาแล้ว ปกป้องเขาให้ครบ %d วินาที!" % int(StoryChapter2.ESCORT_SECONDS))


func _tick_escort(zone: Zone, delta: float) -> void:
	if escort.is_empty():
		return
	var body: StoryEscort = escort.escort
	if escort.zone != zone or body == null or not is_instance_valid(body):
		_end_escort(false, true)
		return
	if body.is_dead():
		_end_escort(false)
		return
	escort["elapsed"] = float(escort.elapsed) + delta
	escort["wave_timer"] = float(escort.wave_timer) - delta
	if float(escort.wave_timer) <= 0.0:
		escort["wave_timer"] = ESCORT_WAVE_EVERY
		_escort_wave(zone, body)
	# Every wave keeps its mind on the reader.
	for m in escort.mobs:
		if is_instance_valid(m) and not m.is_dead():
			m.add_threat(body, 40.0)
	if float(escort.elapsed) >= StoryChapter2.ESCORT_SECONDS:
		_end_escort(true)


func _escort_wave(zone: Zone, body: StoryEscort) -> void:
	var ids := DrownedAbyssData.NORMALS
	for i in ESCORT_WAVE_SIZE:
		var angle := TAU * float(i) / float(ESCORT_WAVE_SIZE) + randf() * 0.6
		var spot := body.global_position + Vector3(cos(angle), 0, sin(angle)) * ESCORT_RADIUS
		spot.y = 0.0
		var mob := Mob.new()
		mob.setup(ids[randi() % ids.size()], EndgameFields.CAMP_MIN + 5, spot, zone.hero)
		mob.position = spot + Vector3(0, 0.3, 0)
		mob.set_meta("escort_wave", true)
		zone.add_child(mob)
		mob.hostile = true
		mob.add_threat(body, 60.0)
		(escort.mobs as Array).append(mob)
		BattleVfx.burst(zone, spot + Vector3(0, 0.4, 0), StoryChapter2Art.VIOLET, 12, 0.8)


## The attempt ends: won (the quest is ready) or lost (it stays active, to try again).
func _end_escort(won: bool, silent := false) -> void:
	if escort.is_empty():
		return
	var body: StoryEscort = escort.escort
	var npc: Npc = escort.npc
	var zone: Node = escort.zone
	for m in escort.mobs:
		if is_instance_valid(m) and not m.is_dead():
			m.queue_free()
	if is_instance_valid(body):
		body.queue_free()
	if npc != null and is_instance_valid(npc) and zone != null and is_instance_valid(zone):
		npc.visible = true
		if not (zone as Zone).npcs.has(npc):
			(zone as Zone).npcs.append(npc)
	escort = {}
	if silent:
		return
	if won and StoryChapter2.status("ch2_escort") == "active":
		Game.set_quest("ch2_escort", "ready", 1)
		_say("นาวินอ่านจารึกจบแล้ว! กลับไปรายงานเขา", &"success")
	elif not won:
		_say("นาวินล้มลง... พิธีล้มเหลว คุยกับเขาอีกครั้งเพื่อลองใหม่", &"warning")


# --- The mid-boss -----------------------------------------------------------------------

## The guardian's rite: ซาเลีย rises before the sanctum with its two telegraphed moves.
func start_mid_boss() -> void:
	var zone: Zone = main.zone
	if zone == null or zone.zone_id != DivineRegionData.ID or StoryChapter2.status("ch2_midboss") != "active":
		return
	if mid_boss != null and is_instance_valid(mid_boss) and not mid_boss.is_dead():
		return
	var boss := Mob.new()
	boss.setup(&"shadow_seraph", MIDBOSS_LEVEL, MIDBOSS_SPOT, zone.hero)
	boss.position = MIDBOSS_SPOT + Vector3(0, 0.3, 0)
	zone.add_child(boss)
	boss.hostile = true
	var moves := StoryBoss.new()
	moves.setup(boss, zone, StoryChapter2.MONSTERS[&"shadow_seraph"].moves)
	boss.add_child(moves)
	mid_boss = boss
	VfxKit.shockwave(zone, MIDBOSS_SPOT + Vector3(0, 0.1, 0), StoryBoss.COLOR, 8.0)
	zone.banner_requested.emit("ซาเลีย วิหคเงาสะท้อน ปรากฏตัว!")
	_say("หลบคลื่นเงา (วงรอบตัว) และหอกเงา (เส้นตรง) บนพื้น แล้วปราบซาเลีย!", &"warning")


# --- The finale -------------------------------------------------------------------------

## The throne stage was won (Zone.story_stage_finished): the quest is finished and paid,
## the ending plays, then the hero is taken back up to the abyss.
func on_stage_finished(result: Dictionary) -> void:
	if not bool(result.get("won", false)):
		return
	if StoryChapter2.status(StoryChapter2.FINALE) == "active":
		Game.set_quest(StoryChapter2.FINALE, "ready", 1)
		_reward(StoryChapter2.FINALE)
	if _ending != null and is_instance_valid(_ending):
		return
	var ending := EndingScreen.new()
	ending.pages = StoryChapter2.ENDING_PAGES
	_ending = ending
	ending.closed.connect(func():
		_ending = null
		if _in_play() and main.has_method("go"):
			main.go(DrownedAbyssData.ID, false, true))
	main.add_child(ending)
