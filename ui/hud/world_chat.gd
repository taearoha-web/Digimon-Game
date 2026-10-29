class_name WorldChat
extends PanelContainer
## The world chat in the HUD: the last few lines the world players said and the server's
## announcements (Game.world_chat, from WorldPresence). It only shows; it never takes a tap,
## so the joystick under it keeps working. line_for picks what a player says.

const LINES := 4
## A line fades out after this many seconds without a newer one.
const FADE_AFTER := 40.0

var _text: RichTextLabel
var _lines: PackedStringArray = []
var _quiet := 0.0


func _ready() -> void:
	name = "WorldChat"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.05, 0.1, 0.42)
	box.set_corner_radius_all(10)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	add_theme_stylebox_override("panel", box)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Long lines wrap inside the panel: with wrapping off, the label's minimum width grew
	# with the longest line and pushed the panel over the skill slots.
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.clip_contents = true
	_text.add_theme_font_size_override("normal_font_size", 17)
	_text.add_theme_constant_override("outline_size", 4)
	_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_text.add_theme_color_override("default_color", Color(1, 1, 1, 0.95))
	add_child(_text)
	visible = false
	Game.world_chat.connect(add_line)


func _process(delta: float) -> void:
	if not visible:
		return
	_quiet += delta
	modulate.a = clampf(1.0 - (_quiet - FADE_AFTER) / 3.0, 0.0, 1.0)


func add_line(speaker: String, text: String, color: Color) -> void:
	if not is_instance_valid(_text):
		return
	var line := "[color=#%s]%s[/color]: %s" % [color.to_html(false), _clean(speaker), _clean(text)]
	_lines.append(line)
	while _lines.size() > LINES:
		_lines.remove_at(0)
	_text.text = "\n".join(_lines)
	_quiet = 0.0
	modulate.a = 1.0
	visible = true


## The lines shown now (tests).
func lines() -> PackedStringArray:
	return _lines


## Names and lines are the game's own, but a bracket must never open a tag.
static func _clean(text: String) -> String:
	return text.replace("[", "(").replace("]", ")")


# --- What players say ----------------------------------------------------------------

## Lines anyone may say; the scheduled players are out levelling, never in the village.
const ANY := ["สวัสดีทุกคน", "วันนี้มอนเกิดไวดีนะ", "555 เมื่อกี้ล้มเพราะเผลอ", "เน็ตกระตุกนิดหน่อย", "ใครเห็นบอสสนามบ้าง",
	"ยาเลือดใกล้หมดแล้ว ฟาร์มต่ออีกนิด", "เพลง%zone เพราะจัง", "ขอบคุณที่ช่วยเมื่อกี้นะ", "ใครอยากเพิ่มเพื่อนบ้าง"]
const LOW := ["มีใครพาเก็บเลเวลไหมครับ", "มือใหม่ครับ ฝากตัวด้วย", "%zone มอนเยอะดีจัง", "เลเวลขึ้นช้าจัง ทำไงดี",
	"อาชีพไหนเก่งสุดครับ", "ใครรู้ทางไปสนามถัดไปบ้าง"]
const JOB := ["เพิ่งเปลี่ยนอาชีพเป็น%job แล้ว!", "%job สนุกกว่าที่คิด", "ใครเล่น%job บ้าง แนะนำสกิลหน่อย"]
const MID := ["หาปาร์ตี้ลงหอคอย ขาดอีก 1", "ใครไป %zone บ้าง ไปด้วยกัน", "อีกนิดจะถึงเลเวล 100 แล้ว", "ตีบวกแตกอีกแล้ว เศร้า",
	"ได้ของหายากจาก %zone ด้วย!", "ใครมีหินตีบวกขายบ้าง"]
const HIGH := ["กิลด์ %guild รับสมาชิกเลเวล 100 ขึ้นไป", "กิลด์วอรอบหน้าใครว่างมารวมที่หมู่บ้าน", "ได้ปีกแล้ว บินสบายเลย",
	"ดาวขึ้นช้ามากที่ %zone", "ใครไปเก็บดาวด้วยกันบ้าง", "%guild ต้องชนะกิลด์วอรอบนี้!"]
const TOP := ["ตีบวกชุดเทพต่อ ใครมีหินขายบ้าง", "รับพาเก็บดาว ทักมาได้", "ล่าบอสวิหารบัววันนี้ได้ของดี",
	"ชุดเทพครบแล้ว เหลือตีบวกให้ครบ +10", "มือใหม่มาถามได้นะ ยินดีช่วย", "กิลด์ %guild แกร่งที่สุด"]
## Stall keepers: players taking a break in the village, selling what they found.
const STALL := ["ร้านเปิดแล้ว ยาเลือดถูกกว่าพ่อค้า", "ขาย%gear ทักได้เลย", "รับซื้อของจากกระเป๋า ให้ราคาดีกว่าพ่อค้า", "ขายเพชรตีบวก ของแท้ราคาเป็นมิตร",
	"AFK อยู่นะ ซื้อของวางเงินไว้ได้", "พักจากล่ามอน เอาของดีที่เก็บได้มาขาย", "ลดราคาช่วงนี้ แวะมาก่อนออกล่า",
	"ของหายากเพิ่งได้มา แตะที่ตัวแล้วดูร้านได้เลย", "ของชุดใหม่ลงร้านทุกสองชั่วโมง", "เพลงหมู่บ้านเพราะจัง นั่งขายของเพลิน ๆ"]
## A scheduled player in the village on a short errand, by the errand.
const ERRAND := {
	"quest": ["ส่งเควสก่อนนะ", "แวะส่งเควสที่ผู้ใหญ่บ้าน เดี๋ยวกลับไปล่าต่อ", "รับเควสใหม่แล้ว ไปต่อกัน", "เควสนี้ให้ของดีด้วย"],
	"enhance": ["ตีบวกติด +%plus แล้ว!", "ตีบวกแตกอีกแล้ว", "ลุ้นตีบวกอยู่ เพชรชมพูเหลือเม็ดเดียว", "ตีบวก +%plus ผ่าน! ไปล่าต่อ"],
	"skill": ["เรียนสกิลใหม่แล้ว", "อัปสกิลเสร็จ ไปลองของที่%field", "ได้สกิลใหม่ที่เลเวล %level แล้ว!"],
}
const GEAR := ["พิณ +7", "ดาบ +8", "คทา +6", "โล่ใหญ่ +7", "ธนู +8", "ไม้เท้า +6", "หอก +7", "มีด +8", "ชุดเกราะ +5", "ปีกเลเวล 100"]


## What player state s says now (seed picks the line).
static func line_for(s: Dictionary, seed_value: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var level := int(s.get("level", 1))
	var pool: Array = []
	var errand := String(s.get("errand", ""))
	if String(s.get("doing", "")) == "errand" and ERRAND.has(errand):
		pool = ERRAND[errand]
	elif String(s.get("doing", "")) == "stall":
		pool = STALL
	elif bool(s.get("divine", false)):
		pool = TOP
	elif level >= Game.GUILD_LEVEL:
		pool = HIGH
	elif level >= 40:
		pool = MID
	elif level >= ClassData.LINE_LEVEL and level < 20 and rng.randf() < 0.4:
		pool = JOB
	else:
		pool = LOW
	if rng.randf() < (0.1 if String(s.get("doing", "")) in ["stall", "errand"] else 0.25):
		pool = ANY
	var line := String(pool[rng.randi() % pool.size()])
	var place := StringName(s.get("place", ""))
	var zone_name := "หมู่บ้าน" if place == &"town" or place == &"" else String(ZoneData.get_zone(place).get("name", "สนาม"))
	var guild := WorldPlayers.guild_name(int(s.get("guild", 0)))
	if line.contains("%guild") and guild == "":
		line = String(ANY[rng.randi() % ANY.size()])
	line = line.replace("%zone", zone_name).replace("%guild", guild).replace("%gear", String(GEAR[rng.randi() % GEAR.size()]))
	line = line.replace("%plus", str(rng.randi_range(5, 9))).replace("%level", str(level))
	if line.contains("%field"):
		line = line.replace("%field", String(ZoneData.get_zone(WorldPlayers.hunting_zone(level, int(s.get("stars", 0)))).get("name", "สนาม")))
	line = line.replace("%job", String(ClassData.get_class_data(StringName(s.get("class", ClassData.START))).get("name", "")))
	return line
