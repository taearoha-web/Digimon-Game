class_name StarPathPanel
extends RefCounted
## A readable endgame journal and forge, using the same save/inventory rules.
static func build(parent: Control, tier: int, choose: Callable) -> void:
	var shell := UIUtil.vbox(9)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(shell)
	var stars := int(Game.paragon().level)
	shell.add_child(UIUtil.label("เส้นทางแห่งดวงดาว • %d / 200" % stars,&"HeaderLabel"))
	var note := UIUtil.label("เลเวล 100 แล้วสะสม EXP ต่อเพื่อเพิ่มดาว • สกิลใหม่เลือกใส่ในช่องเดิม 8 ช่องได้ที่เมนูสกิล",&"SmallLabel")
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	shell.add_child(note)
	var tabs := UIUtil.hbox(8)
	shell.add_child(tabs)
	for value in StarProgression.TIERS:
		var button := UIUtil.button("ดาว %d" % value,&"PrimaryButton" if tier==value else &"",Vector2(130,46))
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.pressed.connect(choose.bind(value))
		tabs.add_child(button)
	var scroller := TouchScroll.new()
	scroller.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroller)
	var box := UIUtil.vbox(10)
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroller.add_child(box)
	var idx := StarProgression.TIERS.find(tier)
	var heading := UIUtil.label("%s • เข้าได้ตั้งแต่ดาว %d" % [StarProgression.TITLES[idx],StarProgression.ENTRY[idx]],&"SubHeaderLabel")
	box.add_child(heading)
	var skill:Dictionary=StarSkillData.pool(Game.class_id())[idx]
	var skill_row := UIUtil.hbox(14)
	box.add_child(skill_row)
	var icon := TextureRect.new()
	icon.texture=load("res://assets/icons/skills/%s.svg" % skill.id)
	icon.custom_minimum_size=Vector2(76,76)
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	skill_row.add_child(icon)
	var detail:=UIUtil.vbox(3)
	detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	skill_row.add_child(detail)
	detail.add_child(UIUtil.label("%s • %s" % [skill.name,"ปลดล็อกแล้ว" if Game.skill_unlocked(skill) else "ปลดล็อกดาว %d" % tier],&"BoldLabel"))
	var desc:=UIUtil.label(String(skill.desc),&"SmallLabel")
	desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(desc)
	var claimed:=int(Game.profile.flags.get("star_reward_%d" % tier,0))>0
	var claim:=UIUtil.button("รับแล้ว" if claimed else "รับรางวัลหลักไมล์ • แต้มสกิล 2 + วัตถุดิบ 25",&"PrimaryButton",Vector2(0,46))
	claim.disabled=claimed or stars<tier or int(Game.profile.level)<100
	claim.pressed.connect(func(): StarProgression.claim(tier))
	box.add_child(claim)
	box.add_child(UIUtil.label("%s %d • แก่นบอส %d • เหรียญ %d" % [StarProgression.MATERIALS[idx],StarProgression.material_count(tier),StarProgression.material_count(tier,true),int(Game.profile.gold)],&"BoldLabel"))
	var instructions:=UIUtil.label("มอนสเตอร์ทั่วไปให้วัตถุดิบ • ตัวชั้นสูงให้มากขึ้น • บอสให้แก่นและอุปกรณ์แน่นอน • ปีกเทพใหม่ต้องมี 100 ดาวและตรงอาชีพ",&"SmallLabel")
	instructions.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	box.add_child(instructions)
	var bonus:=UIUtil.label(StarProgression.set_bonus_text(String(Game.class_id())),&"SmallLabel")
	bonus.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	box.add_child(bonus)
	if tier == 200: _divine_collection(box)
	for slot in ItemData.SLOTS:
		var card:=UIUtil.panel(&"CardPanel")
		box.add_child(card)
		var row:=UIUtil.hbox(12)
		card.add_child(row)
		var look:=StarGearData.look_of({"star_tier":tier,"star_class":String(Game.class_id()),"slot":slot})
		var item_icon:=TextureRect.new()
		item_icon.texture=ItemLook.icon_for_id(look)
		item_icon.custom_minimum_size=Vector2(70,70)
		item_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		item_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(item_icon)
		var text:=UIUtil.vbox(3)
		text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(text)
		text.add_child(UIUtil.label(StarGearData.item_name(slot,String(Game.class_id()),tier),&"BoldLabel"))
		var cost:=StarProgression.cost(tier,slot)
		text.add_child(UIUtil.label("วัตถุดิบ %d • แก่น %d • เหรียญ %d" % [cost.material,cost.core,cost.gold],&"SmallLabel"))
		var problem:=StarProgression.craft_problem(tier,slot)
		if problem!="": text.add_child(UIUtil.label(problem,&"SmallLabel"))
		var forge:=UIUtil.button("สร้าง",&"PrimaryButton",Vector2(105,54))
		forge.disabled=problem!=""
		forge.pressed.connect(func(): StarProgression.craft(tier,slot))
		row.add_child(forge)

	var wing_card:=UIUtil.panel(&"CardPanel")
	box.add_child(wing_card)
	var wing_row:=UIUtil.hbox(12)
	wing_card.add_child(wing_row)
	var wing_icon:=TextureRect.new()
	wing_icon.texture=ItemLook.icon_for_id(StarWingData.look(String(Game.class_id())))
	wing_icon.custom_minimum_size=Vector2(70,70)
	wing_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	wing_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wing_row.add_child(wing_icon)
	var wing_text:=UIUtil.vbox(4)
	wing_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	wing_row.add_child(wing_text)
	wing_text.add_child(UIUtil.label(StarWingData.item_name(String(Game.class_id()))+" • 100 ดาว",&"BoldLabel"))
	var wing_note:=UIUtil.label("ดรอปทั้ง 4 ดินแดนใหม่ ตรงตามอาชีพที่เล่น • ทั่วไป 0.5% / ชั้นสูง 3% / บอส 20%\nต้องเลเวล 100 และ 100 ดาว • ได้จากการดรอปเท่านั้น",&"SmallLabel")
	wing_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	wing_text.add_child(wing_note)


static func _divine_collection(parent: Control) -> void:
	parent.add_child(UIUtil.label("วิหารบัวดารา • ชุดเทพ 200 ดาว", &"SubHeaderLabel"))
	var note := UIUtil.label("เข้าได้ที่เสาวาปเมื่อเลเวล 100 ดาว 200 • ดรอปตามอาชีพที่เล่น\nทั่วไป 3.5% / ชั้นสูง 18% / บอสรับแน่นอน 2 ชิ้นต่างช่อง • ดรอปเท่านั้น", &"SmallLabel")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(note)
	for slot in DivineGearData.SLOTS:
		var card := UIUtil.panel(&"CardPanel")
		parent.add_child(card)
		var row := UIUtil.hbox(12)
		card.add_child(row)
		var cls := String(Game.class_id())
		var icon := TextureRect.new()
		icon.texture = ItemLook.icon_for_id(DivineGearData.look_of({"slot":slot, "star_class":cls}))
		icon.custom_minimum_size = Vector2(70,70)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var label := UIUtil.label(DivineGearData.item_name(cls, slot) + ("\nรวมเสื้อ กางเกง ถุงมือ" if slot == "armor" else "\nอุปกรณ์เทพนิยายประจำอาชีพ"), &"BoldLabel")
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
