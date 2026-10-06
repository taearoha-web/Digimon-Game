class_name EndingScreen
extends CanvasLayer
## The ending after the last boss: a few story pages that fade in one after the
## other, then the credits. Pauses the game while it plays.

signal closed()

const PAGES := [
	"เมื่อมังกรแมกมาล้มลง ภูเขาไฟที่คำรามมานานก็สงบลง\nควันดำจางหายไปจากท้องฟ้าของมิสต์วูด",
	"ชาวบ้านออกมาจากบ้าน ชูมือส่งเสียงเฮ\nเพราะวีรบุรุษของพวกเขากลับมาแล้ว",
	"ทุ่งหญ้า ป่า ทะเลทราย ภูเขาน้ำแข็ง และปล่องไฟ\nล้วนเป็นเรื่องเล่าที่ชาวบ้านจะเล่าต่อไปอีกนานแสนนาน",
	"แต่การผจญภัยยังไม่จบ... ยังมีสนามประลอง ของในตำนาน\nและความสำเร็จอีกมากรอเจ้าอยู่",
]
const CREDITS := [
	"TOON TALE",
	"",
	"ขอบคุณที่เล่น!",
	"",
	"โมเดลตัวละคร: KayKit (Kay Lousberg) — CC0",
	"มอนสเตอร์และธรรมชาติ: Quaternius — CC0",
	"เสียงเอฟเฟกต์: Kenney, OpenGameArt — CC0",
	"ฟอนต์: SIL OFL",
	"ดนตรีและเสียงอื่นๆ: สังเคราะห์สำหรับเกมนี้",
	"",
	"สร้างด้วย Godot Engine",
]

var _label: Label
var _button: Button
var _page := -1


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.1, 0.94)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_label = UIUtil.label("", &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 80
	_label.offset_right = -80
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 34)
	_label.modulate.a = 0.0
	add_child(_label)
	_button = UIUtil.button("ข้าม / ปิด", &"", Vector2(220, 60))
	_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_button.offset_left = -250
	_button.offset_top = -90
	_button.offset_right = -30
	_button.offset_bottom = -30
	_button.pressed.connect(_finish)
	add_child(_button)
	get_tree().paused = true
	AudioManager.play_music(&"victory")
	_next()


func _next() -> void:
	_page += 1
	var text := ""
	if _page < PAGES.size():
		text = PAGES[_page]
	elif _page == PAGES.size():
		text = "\n".join(CREDITS)
	else:
		_finish()
		return
	_label.text = text
	var tween := create_tween()
	tween.tween_property(_label, "modulate:a", 1.0, 0.8)
	tween.tween_interval(3.4 if _page < PAGES.size() else 6.0)
	tween.tween_property(_label, "modulate:a", 0.0, 0.7)
	tween.tween_callback(_next)


func _finish() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()
