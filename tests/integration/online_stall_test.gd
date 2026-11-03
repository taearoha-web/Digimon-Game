extends Node
## Real players' stalls (OnlineStall over PlayerStall): publish, sell to a real buyer,
## refuse a low offer or a gone lot, view another stall, buy, pay and receive.
var checks := 0
var failures := 0

class Link:
	extends RefCounted
	var sent: Array[String] = []
	func send_text(text: String) -> void:
		sent.append(text)
	func poll() -> Array:
		return []
	func is_open() -> bool:
		return true
	func is_closed() -> bool:
		return false
	func frames(t: String) -> Array:
		var out: Array = []
		for text in sent:
			var d: Variant = JSON.parse_string(text)
			if d is Dictionary and String(d.get("t", "")) == t:
				out.append(d)
		return out


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", note)


func _ready() -> void:
	Game.set_process(false)
	GameSettings.online_play = true
	Game.new_profile(&"warrior", "แผงออนไลน์")
	Game.profile.level = 60
	Game.profile.inv.clear()
	Game.profile.gold = 100000
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var stall := OnlineStall.new()
	add_child(stall)
	var link := Link.new()
	Online.use_transport(link)
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "me"}, "players": [
		{"id": "p2", "name": "Buddy", "user": "buddy", "zone": "town", "pos": [0, 0, 0]}], "party": null})
	await get_tree().process_frame
	# Seller: listing publishes the lots.
	Game.profile.inv.append(ItemData.generate(55, &"mage", rng, 2, "weapon"))
	var price: int = PlayerStall.fair_price(Game.profile.inv[0])
	var lot: int = PlayerStall.list_item(0, price)
	check(lot > 0, "a lot is listed")
	var lists := link.frames("stall_list")
	check(not lists.is_empty() and (lists[-1].lots as Array).size() == 1 and int(lists[-1].lots[0].price) == price, "the stall is published with its lot")
	# A real buyer offers too little: refused, the lot stays.
	Online._dispatch({"t": "stall_buy", "from": "p2", "seller": "me", "lot": lot, "price": price - 1})
	check(link.frames("stall_refuse").size() == 1 and PlayerStall.lots().size() == 1, "an offer under the price is refused")
	var gold := int(Game.profile.gold)
	Online._dispatch({"t": "stall_buy", "from": "p2", "seller": "me", "lot": lot, "price": price})
	var sold := link.frames("stall_sold")
	check(sold.size() == 1 and String(sold[0].to) == "p2" and int(sold[0].price) == price and sold[0].item is Dictionary, "sold to the real buyer")
	check(PlayerStall.lots().is_empty() and int(Game.profile.gold) == gold + price, "the lot is gone and the gold is in")
	check(bool((Game.profile.stall.log as Array)[0].real) and String(Game.profile.stall.log[0].buyer) == "Buddy", "the log names the real buyer")
	check((link.frames("stall_list")[-1].lots as Array).is_empty(), "the emptier stall is published again")
	Online._dispatch({"t": "stall_buy", "from": "p2", "seller": "me", "lot": lot, "price": price})
	check(link.frames("stall_refuse").size() == 2, "a lot already sold is refused")
	# Buyer: view Buddy's stall and buy.
	stall.view("p2")
	check(stall.is_open and String(link.frames("stall_view")[-1].seller) == "p2", "viewing asks the server for the stall")
	var bow := ItemData.generate(50, &"archer", rng, 3, "weapon")
	Online._dispatch({"t": "stall", "seller": "p2", "lots": [{"lot": 4, "item": bow, "price": 2000}, {"lot": 5, "item": "junk", "price": 1}]})
	check(stall._lots.size() == 1, "a malformed lot is dropped")
	check(stall.buy(4) and int(link.frames("stall_buy")[-1].lot) == 4 and int(link.frames("stall_buy")[-1].price) == 2000, "buying sends stall_buy with the price")
	check(not stall.buy(4), "no double purchase while waiting")
	gold = int(Game.profile.gold)
	var changes: Array = []
	Game.gold_changed.connect(func(g): changes.append(g))
	Online._dispatch({"t": "stall_bought", "from": "p2", "seller": "p2", "lot": 4, "item": bow, "price": 2000})
	# (Taking a first legendary may also pay an achievement: look at the first change only.)
	check(not changes.is_empty() and int(changes[0]) == gold - 2000, "the price is paid first (%s)" % str(changes))
	check(Game.profile.inv.any(func(it): return ItemData.name_of(it) == ItemData.name_of(bow)), "the bow is in the bag")
	check(stall._lots.is_empty(), "the bought lot leaves the view")
	gold = int(Game.profile.gold)
	Online._dispatch({"t": "stall_bought", "from": "p2", "seller": "p2", "lot": 9, "item": {"kind": "nonsense"}, "price": 50})
	check(int(Game.profile.gold) == gold, "an invalid item is neither paid nor taken")
	Game.profile.gold = 10
	Online._dispatch({"t": "stall", "seller": "p2", "lots": [{"lot": 6, "item": bow, "price": 2000}]})
	check(not stall.buy(6), "not enough gold: no offer")
	stall.close_screen()
	Online.use_transport(null)
	stall.queue_free()
	await get_tree().process_frame
	print("ONLINE STALL: ", checks, " checks, ", failures, " failures")
	get_tree().quit(failures)
