class_name WorldChat
extends PanelContainer
## The chat in the HUD: the last few lines of the world chat (Game.world_chat: the world
## players and the server's announcements, from WorldPresence) and of the hero's party and
## guild (Game.channel_chat, from AiChat and PartyTalk). A small tab row picks what shows:
## ทั้งหมด (everything), โลก, ปาร์ตี้ or กิลด์; the typing bar (AiChat) sends to the tab's
## channel (compose_channel). Party lines are green and guild lines orange, each with its
## tag ([ปาร์ตี้] / [กิลด์]). Only the tabs take a tap; the lines never do, so the joystick
## under them keeps working. line_for picks what a player says.

signal tab_changed(tab: String)

const LINES := 6
## The panel's height: room for the tabs and the lines, so the box keeps its size.
const HEIGHT := 184.0
const FONT_SIZE := 21
## Lines kept per channel for the tabs (the box shows the last LINES of the tab's).
const KEEP := 30
const TAB_HEIGHT := 34.0
const TAB_FONT := 17
## The tabs: [tab, label]. "all" shows every channel.
const TABS := [["all", "ทั้งหมด"], ["world", "โลก"], ["party", "ปาร์ตี้"], ["guild", "กิลด์"]]
const TAGS := {"party": "ปาร์ตี้", "guild": "กิลด์"}
const PARTY_COLOR := Color("7dff8a")
const GUILD_COLOR := Color("ffa64d")
const CHANNEL_COLORS := {"party": PARTY_COLOR, "guild": GUILD_COLOR}

var tab := "all"
var _text: RichTextLabel
var _tabs := {}
## Every line kept: {channel, line} (BBCode), oldest first.
var _all: Array = []
var _lines: PackedStringArray = []
## Channels with lines the hero has not seen on their tab yet.
var _unread := {}


func _ready() -> void:
	name = "WorldChat"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.05, 0.1, 0.62)
	box.set_corner_radius_all(10)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 4
	box.content_margin_bottom = 6
	add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	var row := HBoxContainer.new()
	row.name = "ChatTabs"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	row.custom_minimum_size = Vector2(0, TAB_HEIGHT)
	column.add_child(row)
	for entry in TABS:
		var key := String(entry[0])
		var b := Button.new()
		b.name = "Tab_%s" % key
		b.text = String(entry[1])
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, TAB_HEIGHT)
		b.clip_text = true
		b.add_theme_font_size_override("font_size", TAB_FONT)
		var off := StyleBoxFlat.new()
		off.bg_color = Color(1, 1, 1, 0.08)
		off.set_corner_radius_all(8)
		var on := StyleBoxFlat.new()
		on.bg_color = Color(CHANNEL_COLORS.get(key, Color("8ff0ff")), 0.38)
		on.set_corner_radius_all(8)
		for state in ["normal", "hover", "focus", "disabled"]:
			b.add_theme_stylebox_override(state, off)
		for state in ["pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, on)
		b.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		b.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
		b.add_theme_color_override("font_hover_pressed_color", Color(1, 1, 1, 1))
		b.pressed.connect(set_tab.bind(key))
		row.add_child(b)
		_tabs[key] = b
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	# A box of fixed size: the newest lines show at the bottom, older ones scroll out.
	_text.fit_content = false
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Long lines wrap inside the panel: with wrapping off, the label's minimum width grew
	# with the longest line and pushed the panel over the skill slots.
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.clip_contents = true
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_text.add_theme_constant_override("outline_size", 6)
	_text.add_theme_constant_override("line_separation", 2)
	_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_text.add_theme_color_override("default_color", Color(1, 1, 1, 0.95))
	column.add_child(_text)
	custom_minimum_size = Vector2(0, HEIGHT)
	visible = false
	_show_tabs()
	Game.world_chat.connect(add_line)
	Game.channel_chat.connect(add_channel_line)


## A line of the world chat.
func add_line(speaker: String, text: String, color: Color) -> void:
	add_channel_line("world", speaker, text, color)


## A line on `channel` ("world", "party" or "guild").
func add_channel_line(channel: String, speaker: String, text: String, color: Color) -> void:
	if not is_instance_valid(_text):
		return
	var line := "[color=#%s]%s[/color]: %s" % [color.to_html(false), _clean(speaker), _clean(text)]
	if TAGS.has(channel):
		var tint := String((CHANNEL_COLORS[channel] as Color).to_html(false))
		line = "[color=#%s][lb]%s[rb][/color] [color=#%s]%s[/color]: [color=#%s]%s[/color]" % [tint, TAGS[channel], color.to_html(false), _clean(speaker), tint, _clean(text)]
	_all.append({"channel": channel, "line": line})
	# Each channel keeps its own last KEEP lines, so a busy world chat never pushes the
	# party's lines out of its tab.
	var count := 0
	for n in range(_all.size() - 1, -1, -1):
		if String(_all[n].channel) == channel:
			count += 1
			if count > KEEP:
				_all.remove_at(n)
				break
	if tab != "all" and tab != channel:
		_unread[channel] = true
		_show_tabs()
	_render()
	visible = true


## Shows `t` ("all", "world", "party" or "guild").
func set_tab(t: String) -> void:
	if not _tabs.has(t):
		return
	var changed := t != tab
	tab = t
	_unread.erase(t)
	if t == "all":
		_unread.clear()
	_show_tabs()
	_render()
	if changed:
		tab_changed.emit(tab)


## The channel the typing bar sends to on this tab (ทั้งหมด and โลก: the world chat).
func compose_channel() -> String:
	return tab if tab == "party" or tab == "guild" else "world"


## The lines shown now (tests).
func lines() -> PackedStringArray:
	return _lines


func _render() -> void:
	_lines = PackedStringArray()
	for entry in _all:
		if tab == "all" or String(entry.channel) == tab:
			_lines.append(String(entry.line))
	if _lines.size() > LINES:
		_lines = _lines.slice(_lines.size() - LINES)
	_text.text = "\n".join(_lines)
	_text.scroll_to_line(maxi(0, _text.get_line_count() - 1))


func _show_tabs() -> void:
	for entry in TABS:
		var key := String(entry[0])
		var b := _tabs[key] as Button
		b.set_pressed_no_signal(key == tab)
		b.text = String(entry[1]) + (" •" if _unread.has(key) else "")


## Names and lines are the game's own, but a bracket must never open a tag.
static func _clean(text: String) -> String:
	return text.replace("[", "(").replace("]", ")")


# --- What players say ----------------------------------------------------------------

## Lines anyone may say; the scheduled players are out levelling, never in the village.
const ANY := ["สวัสดีทุกคน", "วันนี้มอนเกิดไวดีนะ", "555 เมื่อกี้ล้มเพราะเผลอ", "เน็ตกระตุกนิดหน่อย", "ใครเห็นบอสสนามบ้าง",
	"ยาเลือดใกล้หมดแล้ว ฟาร์มต่ออีกนิด", "เพลง%zone เพราะจัง", "ขอบคุณที่ช่วยเมื่อกี้นะ", "ใครอยากเพิ่มเพื่อนบ้าง",
	"ใครอยู่แถวนี้บ้าง", "พักกินข้าวแป๊บ เดี๋ยวมาต่อ", "วันนี้เล่นยาวเลย", "เมื่อกี้มอนดรอปของดีด้วย"]
const LOW := ["มีใครพาเก็บเลเวลไหมครับ", "มือใหม่ครับ ฝากตัวด้วย", "%zone มอนเยอะดีจัง", "เลเวลขึ้นช้าจัง ทำไงดี",
	"อาชีพไหนเก่งสุดครับ", "ใครรู้ทางไปสนามถัดไปบ้าง", "ยาเลือดซื้อที่ไหนครับ", "เพิ่งเริ่มเล่นวันนี้ครับ",
	"ใครแนะนำที่เก็บเลเวลหน่อย", "มอนตัวใหญ่ตีไม่ไหวเลย 555"]
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
