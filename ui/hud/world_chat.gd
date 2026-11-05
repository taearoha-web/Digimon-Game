class_name WorldChat
extends PanelContainer
## The chat in the HUD: the last few lines of the world chat (Game.world_chat: the world
## players and the server's announcements, from WorldPresence) and of the hero's party and
## guild (Game.channel_chat, from AiChat and PartyTalk). A small tab row picks what shows:
## ทั้งหมด (everything), โลก, ปาร์ตี้ or กิลด์; the typing bar (AiChat) sends to the tab's
## channel (compose_channel). Party lines are green and guild lines orange, each with its
## tag ([ปาร์ตี้] / [กิลด์]). The tabs take a tap, and so does a world player's name in a
## line (a link: name_tapped, to talk to that player). line_for picks what a player says.
## In a guild war its news (GuildWarHud: kills, plans, gates, who takes the castle) comes
## on the "war" channel: no speaker, tagged [สงคราม], shown on ทั้งหมด and กิลด์.
## Real players online (Online "chat" frames) talk here too, beside the world players:
## their lines carry a small "ผู้เล่นจริง" mark, their names are links (real_name_tapped:
## whisper to them), the party's lines go to ปาร์ตี้ and whispers come tagged [กระซิบ]
## in pink on ทั้งหมด and โลก. The hero's own world and party lines are shown when typed
## (AiChat), so the server's copy of those is not shown again; its whispers show when the
## server sends them back.

signal tab_changed(tab: String)
## A world player's name in a line was tapped: the hero talks to that player.
signal name_tapped(player_name: String)
## A real player's name in a line was tapped (their online id): whisper to them.
signal real_name_tapped(id: String)

const LINES := 6
## Lines of history the box holds for its tab: drag the box up to read back through them.
const HISTORY := 60
## A finger has to move this far (px) before a press on the box becomes a scroll.
const DRAG_START := 8.0
## The panel's height: room for the tabs and the lines, so the box keeps its size.
const HEIGHT := 184.0
const FONT_SIZE := 21
## Lines kept per channel for the tabs (the box shows the last LINES of the tab's).
const KEEP := 30
const TAB_HEIGHT := 34.0
const TAB_FONT := 17
## The tabs: [tab, label]. "all" shows every channel.
const TABS := [["all", "ทั้งหมด"], ["world", "โลก"], ["party", "ปาร์ตี้"], ["guild", "กิลด์"]]
const TAGS := {"party": "ปาร์ตี้", "guild": "กิลด์", "war": "สงคราม", "whisper": "กระซิบ"}
const PARTY_COLOR := Color("7dff8a")
const GUILD_COLOR := Color("ffa64d")
const WAR_COLOR := Color("ffd84a")
const WHISPER_COLOR := Color("ff9ee8")
const CHANNEL_COLORS := {"party": PARTY_COLOR, "guild": GUILD_COLOR, "war": WAR_COLOR, "whisper": WHISPER_COLOR}
## Channels shown on a tab besides its own (the war's news on the guild's tab, whispers
## on the world's).
const ALSO_ON := {"war": "guild", "whisper": "world"}
## A real player's line: the small mark before the name, and the name's colour.
const REAL_MARK := "ผู้เล่นจริง"
const REAL_MARK_COLOR := Color("6dffd0")
const REAL_MARK_SIZE := 14
const REAL_NAME_COLOR := Color("bfe8ff")
## The link prefix of a real player's name (the rest is the online id).
const REAL_LINK := "rp:"

var tab := "all"
var _text: RichTextLabel
var _tabs := {}
## Every line kept: {channel, line} (BBCode), oldest first.
var _all: Array = []
var _lines: PackedStringArray = []
## Channels with lines the hero has not seen on their tab yet.
var _unread := {}
## Every line of the tab now shown (up to HISTORY), oldest first.
var _history: PackedStringArray = []
## The reader scrolled up: new lines do not pull the box back to the bottom.
var _held := false
var _press := false
var _dragging := false
var _press_y := 0.0
var _press_scroll := 0.0
## Set while the box replaces its own text or follows the end (not the reader's scroll).
var _rendering := false


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
	# A box of fixed size: the newest lines show at the bottom; drag (or wheel) to read
	# back through the last HISTORY lines. The scroll bar stays hidden.
	_text.fit_content = false
	_text.scroll_active = true
	_text.scroll_following = false
	_text.get_v_scroll_bar().modulate = Color(1, 1, 1, 0)
	_text.get_v_scroll_bar().mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Taps reach the label so a player's name can be tapped (name_tapped); a drag
	# scrolls the history and is kept from the camera (accept_event).
	_text.mouse_filter = Control.MOUSE_FILTER_STOP
	_text.gui_input.connect(_on_text_input)
	_text.meta_underlined = false
	_text.meta_clicked.connect(_on_meta)
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
	Online.message.connect(_on_online)


func _on_meta(meta: Variant) -> void:
	var link := str(meta)
	if link.begins_with(REAL_LINK):
		real_name_tapped.emit(link.substr(REAL_LINK.length()))
	else:
		name_tapped.emit(link)


## Online's frames: a real player's chat line.
func _on_online(type: String, data: Dictionary) -> void:
	if type == "chat":
		add_real_line(data)


## A real player's line from a "chat" frame {ch, from, user, name, text, to?}: world,
## party or whisper (to the hero, or the hero's own one coming back). Anything else, and
## the hero's own world / party lines coming back (shown already when typed), are left out.
func add_real_line(data: Dictionary) -> void:
	var ch := str(data.get("ch", ""))
	var from := Online.id_of(data.get("from"))
	var text: Variant = data.get("text")
	if not ch in ["world", "party", "whisper"] or from == "" or not text is String or String(text).strip_edges() == "":
		return
	if from == Online.my_id():
		# The server sends every line back to its sender: the hero's world and party lines
		# were shown when typed (beside the world players' answers), its whisper shows now
		# that it went out.
		if ch == "whisper":
			var to := Online.display_name(Online.player(Online.id_of(data.get("to"))))
			var tint := WHISPER_COLOR.to_html(false)
			_add(ch, "[color=#%s][lb]%s[rb][/color] [color=#%s]%s[/color]: [color=#%s](ถึง %s) %s[/color]" % [tint, TAGS[ch],
				Color("ffe27a").to_html(false), _clean(Online.display_name({"name": data.get("name", ""), "user": data.get("user", "")})),
				tint, _clean(to), _clean(String(text).strip_edges().left(Online.CHAT_MAX))])
		return
	var who := Online.display_name({"name": data.get("name", ""), "user": data.get("user", "")})
	var mark := "[font_size=%d][color=#%s]%s[/color][/font_size]" % [REAL_MARK_SIZE, REAL_MARK_COLOR.to_html(false), REAL_MARK]
	var name_part := "%s [color=#%s][url=%s%s]%s[/url][/color]" % [mark, REAL_NAME_COLOR.to_html(false), REAL_LINK, _clean(from), _clean(who)]
	var body := _clean(String(text).strip_edges().left(Online.CHAT_MAX))
	var line := "%s: %s" % [name_part, body]
	if TAGS.has(ch):
		var tint := String((CHANNEL_COLORS[ch] as Color).to_html(false))
		line = "[color=#%s][lb]%s[rb][/color] %s: [color=#%s]%s[/color]" % [tint, TAGS[ch], name_part, tint, body]
	_add(ch, line)


## A line of the world chat.
func add_line(speaker: String, text: String, color: Color) -> void:
	add_channel_line("world", speaker, text, color)


## A line on `channel` ("world", "party", "guild" or "war"); an empty speaker leaves
## the name out (the war's news), the line in `color`.
func add_channel_line(channel: String, speaker: String, text: String, color: Color) -> void:
	if not is_instance_valid(_text):
		return
	var who := _name_link(speaker)
	var line := "[color=#%s]%s[/color]: %s" % [color.to_html(false), who, _clean(text)]
	if speaker == "" and TAGS.has(channel):
		var tag_tint := String((CHANNEL_COLORS[channel] as Color).to_html(false))
		line = "[color=#%s][lb]%s[rb][/color] [color=#%s]%s[/color]" % [tag_tint, TAGS[channel], color.to_html(false), _clean(text)]
	elif TAGS.has(channel):
		var tint := String((CHANNEL_COLORS[channel] as Color).to_html(false))
		line = "[color=#%s][lb]%s[rb][/color] [color=#%s]%s[/color]: [color=#%s]%s[/color]" % [tint, TAGS[channel], color.to_html(false), who, tint, _clean(text)]
	_add(channel, line)


## Keeps `line` (BBCode) on `channel` and shows it.
func _add(channel: String, line: String) -> void:
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
	if tab != "all" and not _shows(tab, channel):
		_unread[String(ALSO_ON.get(channel, channel))] = true
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
	if changed:
		_held = false
	_render()
	if changed:
		tab_changed.emit(tab)


## The channel the typing bar sends to on this tab (ทั้งหมด and โลก: the world chat).
func compose_channel() -> String:
	return tab if tab == "party" or tab == "guild" else "world"


## The newest lines of the tab (the last LINES; tests).
func lines() -> PackedStringArray:
	return _lines


## Every line the tab holds now (up to HISTORY), oldest first.
func history() -> PackedStringArray:
	return _history


## True while the reader has scrolled up into the history.
func is_held() -> bool:
	return _held


## Scrolls the history by `pixels` (negative: back to older lines); tests and the drag.
func scroll_by(pixels: float) -> void:
	var bar := _text.get_v_scroll_bar()
	bar.value = clampf(bar.value + pixels, 0.0, maxf(0.0, bar.max_value - bar.page))
	_reader_scrolled()


## Back to the newest line, following new ones again.
func scroll_to_end() -> void:
	_held = false
	_follow_end()


func _at_bottom() -> bool:
	var bar := _text.get_v_scroll_bar()
	return bar.value >= bar.max_value - bar.page - 4.0


## After the reader's own scroll (a drag, the wheel, scroll_by): held unless back at the
## end. The label re-laying out its lines never changes this.
func _reader_scrolled() -> void:
	_held = not _at_bottom()


func _follow_end() -> void:
	if _held or not is_instance_valid(_text):
		return
	_rendering = true
	_text.scroll_to_line(maxi(0, _text.get_line_count() - 1))
	_rendering = false


func _on_text_input(event: InputEvent) -> void:
	var press := (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or event is InputEventScreenTouch
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_reader_scrolled.call_deferred()
		return
	if press:
		if event.is_pressed():
			_press = true
			_dragging = false
			_press_y = event.position.y
			_press_scroll = _text.get_v_scroll_bar().value
		else:
			if _dragging:
				_text.accept_event()
			_press = false
			_dragging = false
		return
	var moved := (event is InputEventMouseMotion or event is InputEventScreenDrag) and _press
	if moved:
		var dy: float = event.position.y - _press_y
		if not _dragging and absf(dy) >= DRAG_START:
			_dragging = true
		if _dragging:
			var bar := _text.get_v_scroll_bar()
			bar.value = clampf(_press_scroll - dy, 0.0, maxf(0.0, bar.max_value - bar.page))
			_reader_scrolled()
			_text.accept_event()


func _render() -> void:
	_history = PackedStringArray()
	for entry in _all:
		if tab == "all" or _shows(tab, String(entry.channel)):
			_history.append(String(entry.line))
	if _history.size() > HISTORY:
		_history = _history.slice(_history.size() - HISTORY)
	_lines = _history.slice(maxi(0, _history.size() - LINES)) if _history.size() > LINES else _history.duplicate()
	var keep := _text.get_v_scroll_bar().value
	_rendering = true
	_text.text = "\n".join(_history)
	if _held:
		# Reading back: stay on the same lines while new ones arrive below.
		_text.get_v_scroll_bar().value = keep
	else:
		_text.scroll_to_line(maxi(0, _text.get_line_count() - 1))
	_rendering = false
	# The label lays its lines out later: follow the end again once it has.
	_follow_end.call_deferred()


func _show_tabs() -> void:
	for entry in TABS:
		var key := String(entry[0])
		var b := _tabs[key] as Button
		b.set_pressed_no_signal(key == tab)
		b.text = String(entry[1]) + (" •" if _unread.has(key) else "")


static func _shows(on_tab: String, channel: String) -> bool:
	return channel == on_tab or String(ALSO_ON.get(channel, "")) == on_tab


## A world player's name as a tappable link (others, like ระบบ or the hero, stay plain).
static func _name_link(speaker: String) -> String:
	var clean := _clean(speaker)
	return "[url=%s]%s[/url]" % [clean, clean] if WorldPlayers.index_of(speaker) >= 0 else clean


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
## %gear / %potion / %jewel name a lot this stall really has (StallStock.lot_name); a line
## naming goods the stall does not have is never said.
const STALL := ["ร้านเปิดแล้ว %potion ถูกกว่าพ่อค้า", "ขาย%gear ทักได้เลย", "รับซื้อของจากกระเป๋า ให้ราคาดีกว่าพ่อค้า", "ขาย%jewel ของแท้ราคาเป็นมิตร",
	"AFK อยู่นะ ซื้อของวางเงินไว้ได้", "พักจากล่ามอน เอาของดีที่เก็บได้มาขาย", "ลดราคาช่วงนี้ แวะมาก่อนออกล่า",
	"ของหายากเพิ่งได้มา แตะที่ตัวแล้วดูร้านได้เลย", "ของชุดใหม่ลงร้านทุกสองชั่วโมง", "เพลงหมู่บ้านเพราะจัง นั่งขายของเพลิน ๆ"]
const STALL_GOODS := {"%gear": "equip", "%potion": "potion", "%jewel": "jewel"}
## Stall lines that name no goods, for when the named kind is not in stock.
const STALL_PLAIN := ["AFK อยู่นะ ซื้อของวางเงินไว้ได้", "พักจากล่ามอน เอาของดีที่เก็บได้มาขาย", "แตะที่ตัวแล้วดูร้านได้เลย", "รับซื้อของจากกระเป๋า ให้ราคาดีกว่าพ่อค้า"]
## A scheduled player in the village on a short errand, by the errand.
## A player in a party of world players (WorldParties) talks about it now and then
## (%leader: whose party, %n: how many, %zone: where it hunts); one hunting alone who
## likes parties asks for one (LFG).
const PARTY_IN := ["ตี้ %leader ฟาร์มที่%zone อยู่ มาเพิ่มได้อีกคน", "ไปฟาร์มที่%zone กัน ตี้เรา %n คนแล้ว", "ตี้ %leader ขาดฮีล ใครว่างมาหน่อย",
	"ตีกับตี้ %leader สนุกดี EXP ไหลเลย", "ตี้ %n คนที่%zone เก็บเลเวลไวขึ้นเยอะ", "ไปฟาร์มที่%zone กันต่อนะทุกคน"]
const PARTY_LEAD := ["ตี้ผมฟาร์มที่%zone อยู่ ใคร Lv.%level ใกล้ ๆ มาด้วยกัน", "ไปฟาร์มที่%zone กัน ตี้ %n คนแล้ว ขาดอีกนิด",
	"หัวตี้ขอพาไป%zone นะ ตามมาทุกคน"]
const LFG := ["ใครว่างมาตี้ด้วย Lv.%level", "หาตี้ฟาร์ม%zone ครับ", "ขอเข้าตี้หน่อย Lv.%level %job", "ใครไป%zone ตี้กันไหม", "หาตี้ครับ ฟาร์มคนเดียวช้ามาก"]
const ERRAND := {
	"quest": ["ส่งเควสก่อนนะ", "แวะส่งเควสที่ผู้ใหญ่บ้าน เดี๋ยวกลับไปล่าต่อ", "รับเควสใหม่แล้ว ไปต่อกัน", "เควสนี้ให้ของดีด้วย"],
	"enhance": ["ตีบวกติด +%plus แล้ว!", "ตีบวกแตกอีกแล้ว", "ลุ้นตีบวกอยู่ เพชรชมพูเหลือเม็ดเดียว", "ตีบวก +%plus ผ่าน! ไปล่าต่อ"],
	"skill": ["เรียนสกิลใหม่แล้ว", "อัปสกิลเสร็จ ไปลองของที่%field", "ได้สกิลใหม่ที่เลเวล %level แล้ว!"],
}


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
	var leader := int(s.get("party_leader", -1))
	var party_n := (s.get("party_members", []) as Array).size()
	if String(s.get("doing", "")) in ["hunt", "boss"]:
		if leader >= 0 and rng.randf() < 0.3:
			pool = PARTY_LEAD if leader == int(s.get("index", -2)) else PARTY_IN
		elif leader < 0 and s.has("index") and rng.randf() < 0.12 * WorldParties.taste(int(s.index)) / 0.5:
			pool = LFG
	var line := String(pool[rng.randi() % pool.size()])
	if leader >= 0 and leader < WorldPlayers.size():
		line = line.replace("%leader", String(WorldPlayers.entry(leader).name)).replace("%n", str(party_n))
	var place := StringName(s.get("place", ""))
	var zone_name := "หมู่บ้าน" if place == &"town" or place == &"" else String(ZoneData.get_zone(place).get("name", "สนาม"))
	var guild := WorldPlayers.guild_name(int(s.get("guild", 0)))
	if line.contains("%guild") and guild == "":
		line = String(ANY[rng.randi() % ANY.size()])
	for key in STALL_GOODS:
		if line.contains(key):
			var lot := StallStock.lot_name(int(s.get("index", -1)), STALL_GOODS[key], rng.randi())
			line = line.replace(key, lot) if lot != "" else STALL_PLAIN[rng.randi() % STALL_PLAIN.size()]
	line = line.replace("%zone", zone_name).replace("%guild", guild)
	line = line.replace("%plus", str(rng.randi_range(5, 9))).replace("%level", str(level))
	if line.contains("%field"):
		line = line.replace("%field", String(ZoneData.get_zone(WorldPlayers.hunting_zone(level, int(s.get("stars", 0)))).get("name", "สนาม")))
	line = line.replace("%job", String(ClassData.get_class_data(StringName(s.get("class", ClassData.START))).get("name", "")))
	return line
