class_name OnlineStall
extends CanvasLayer
## Real players' stalls (docs/ONLINE_PROTOCOL.md, stall_* frames) on top of PlayerStall.
##
## Seller side: the hero's lots are published with `stall_list` when the link opens and on
## every Game.stall_changed; a real buyer's `stall_buy` is sold through PlayerStall.sell
## (gold in at once, the log marks it as a real player) and answered with `stall_sold`,
## or `stall_refuse` when the lot is gone or the offer is under the price.
## Buyer side: "ดูแผง" in the online list opens this screen (`stall_view`); "ซื้อ" sends
## `stall_buy` when the hero has the gold, and `stall_bought` pays the price and gives
## the item (bag, else the shared storage). Items from the wire are checked with the save
## game's own item validation before they reach the bag.

## Keep the published list under the server's 8 KB frame limit.
const MAX_FRAME := 7000
const BUTTON := Vector2(150, 56)

var is_open := false
var seller_id := ""
var _lots: Array = []
var _pending := {}
var _root: Control
var _body: Control


func _ready() -> void:
	layer = 61
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.1, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var safe := SafeAreaContainer.new()
	_root.add_child(safe)
	var frame := Control.new()
	safe.add_child(frame)
	var panel := UIUtil.panel(&"GlassPanel")
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 16
	panel.offset_top = 12
	panel.offset_right = -16
	panel.offset_bottom = -12
	frame.add_child(panel)
	_body = Control.new()
	panel.add_child(_body)
	Online.connected.connect(publish)
	Online.message.connect(_on_message)
	Game.stall_changed.connect(publish)


# ---------------------------------------------------------------------------
# Seller
# ---------------------------------------------------------------------------

## The hero's lots as sent to the server: [{lot, item, price}], cut to fit one frame.
static func wire_lots() -> Array:
	var out: Array = []
	if not Game.has_profile:
		return out
	var size := 64
	for entry in PlayerStall.lots():
		var lot := {"lot": int(entry.lot), "item": entry.item, "price": int(entry.price)}
		var bytes := JSON.stringify(lot).length() + 1
		if size + bytes > MAX_FRAME:
			break
		size += bytes
		out.append(lot)
	return out


func publish() -> void:
	if Online.is_online():
		Online.send("stall_list", {"lots": wire_lots()})


func _sell_to(buyer: String, lot: int, offer: int) -> void:
	var entry := {}
	for e in PlayerStall.lots():
		if int(e.lot) == lot:
			entry = e
	if entry.is_empty() or offer < int(entry.price):
		Online.send("stall_refuse", {"to": buyer, "lot": lot})
		return
	var name := Online.display_name(Online.player(buyer)) if not Online.player(buyer).is_empty() else "ผู้เล่น"
	var sold := PlayerStall.sell(lot, name, true)
	if sold.is_empty():
		Online.send("stall_refuse", {"to": buyer, "lot": lot})
		return
	Online.send("stall_sold", {"to": buyer, "lot": lot, "item": sold.item, "price": int(sold.price)})


# ---------------------------------------------------------------------------
# Buyer
# ---------------------------------------------------------------------------

func view(id: String) -> void:
	seller_id = id
	_lots = []
	is_open = true
	_root.visible = true
	AudioManager.play_ui(&"ui_open")
	Online.send("stall_view", {"seller": id})
	_build()


func close_screen() -> void:
	is_open = false
	_root.visible = false
	UIUtil.clear(_body)


func buy(lot: int) -> bool:
	var entry := {}
	for e in _lots:
		if int(e.get("lot", -1)) == lot:
			entry = e
	if entry.is_empty() or _pending.has(lot):
		return false
	var price := int(entry.get("price", 0))
	if int(Game.profile.get("gold", 0)) < price:
		Game.say("เงินไม่พอ", &"warning")
		return false
	_pending[lot] = true
	Online.send("stall_buy", {"seller": seller_id, "lot": lot, "price": price})
	return true


func _bought(data: Dictionary) -> void:
	var lot := int(data.get("lot", -1))
	_pending.erase(lot)
	var item: Variant = data.get("item")
	var price := maxi(0, int(data.get("price", 0)))
	if not (item is Dictionary) or not Game._valid_item(item):
		Game.say("ข้อมูลไอเทมจากผู้ขายผิดพลาด", &"warning")
		return
	var got: Dictionary = (item as Dictionary).duplicate(true)
	Game._repair_item(got)
	Game.add_gold(-price)
	Game.give_or_store(got)
	Game.mark_dirty()
	var seller := Online.display_name(Online.player(String(data.get("seller", data.get("from", "")))))
	Game.say("ซื้อ %s จาก %s แล้ว (%s เหรียญ)" % [ItemData.name_of(got), seller, PlayerStall.thousands(price)], &"success")
	_lots = _lots.filter(func(e): return int(e.get("lot", -1)) != lot)
	if is_open:
		_build()


func _on_message(type: String, data: Dictionary) -> void:
	match type:
		"stall_buy":
			_sell_to(String(data.get("from", "")), int(data.get("lot", -1)), int(data.get("price", 0)))
		"stall":
			if String(data.get("seller", "")) == seller_id:
				_lots = (data.get("lots", []) as Array).filter(func(e): return e is Dictionary and e.get("item") is Dictionary)
				if is_open:
					_build()
		"stall_bought":
			_bought(data)
		"stall_refuse":
			_pending.erase(int(data.get("lot", -1)))
			Game.say("ของชิ้นนั้นขายไปแล้ว", &"warning")
			if is_open:
				Online.send("stall_view", {"seller": seller_id})


func _build() -> void:
	UIUtil.clear(_body)
	var column := UIUtil.vbox(8)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 14
	column.offset_right = -14
	column.offset_top = 10
	column.offset_bottom = -10
	_body.add_child(column)
	var head := UIUtil.hbox(12)
	column.add_child(head)
	var who := Online.display_name(Online.player(seller_id)) if not Online.player(seller_id).is_empty() else "ผู้เล่น"
	var title := UIUtil.label("แผงของ %s" % who, &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var gold := UIUtil.label("เงิน %s" % PlayerStall.thousands(int(Game.profile.get("gold", 0))), &"BoldLabel")
	head.add_child(gold)
	var close := UIUtil.button("ปิด", &"PrimaryButton", Vector2(140, 60))
	close.name = "Close"
	close.pressed.connect(close_screen)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := UIUtil.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if _lots.is_empty():
		list.add_child(UIUtil.label("แผงว่าง หรือกำลังโหลด…", &"SmallLabel"))
		return
	for entry in _lots:
		var item: Dictionary = entry.item
		var row := UIUtil.panel(&"CardPanel")
		var line := UIUtil.hbox(10)
		row.add_child(line)
		var info := UIUtil.vbox(0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(info)
		var name := UIUtil.label(ItemData.name_of(item), &"BoldLabel")
		name.add_theme_color_override("font_color", ItemData.color_of(item))
		name.clip_text = true
		info.add_child(name)
		var tag := ItemData.class_tag(item, String(Game.class_id()))
		info.add_child(UIUtil.label("%s เหรียญ%s" % [PlayerStall.thousands(int(entry.price)), "  ·  " + tag if tag != "" else ""], &"SmallLabel"))
		var lot := int(entry.lot)
		var b := UIUtil.button("ซื้อ", &"PrimaryButton", BUTTON)
		b.name = "Buy_%d" % lot
		b.disabled = _pending.has(lot) or int(Game.profile.get("gold", 0)) < int(entry.price)
		b.pressed.connect(func(): buy(lot))
		line.add_child(b)
		list.add_child(row)
