class_name ShopService
extends RefCounted
## Pure buy/sell rules (unit-tested). Mutates the given profile + inventory.
## Results: {ok: bool, message: String, total: int}


static func get_buy_price(shop: ShopData, item: ItemData) -> int:
	if item == null or item.buy_price <= 0:
		return 0
	var multiplier := shop.price_multiplier if shop else 1.0
	return maxi(1, int(round(item.buy_price * multiplier)))


static func can_sell(item: ItemData) -> bool:
	return item != null and item.sell_price > 0 and item.category != ItemData.Category.QUEST \
		and item.category != ItemData.Category.KEY


## Largest quantity the player can buy right now (money and stack space).
static func max_affordable(shop: ShopData, item: ItemData, profile: PlayerProfile, inventory: Inventory) -> int:
	var price := get_buy_price(shop, item)
	if price <= 0:
		return 0
	var space := maxi(0, item.max_stack - inventory.count(item.id))
	return mini(space, profile.currency / price)


static func buy(shop: ShopData, item_id: StringName, quantity: int, profile: PlayerProfile, inventory: Inventory,
		registry: Node = null) -> Dictionary:
	var item := _item(item_id, registry)
	if shop == null or item == null or not shop.stock.has(item_id):
		return _fail(L10n.t("That item isn't sold here."))
	if quantity <= 0:
		return _fail(L10n.t("Choose how many to buy."))
	var price := get_buy_price(shop, item)
	if price <= 0:
		return _fail(L10n.t("That item isn't for sale."))
	if inventory.count(item_id) + quantity > item.max_stack:
		return _fail(L10n.t("You can't carry more %s.") % item.display_name)
	var total := price * quantity
	if not profile.spend_currency(total):
		return _fail(L10n.t("Not enough Data Coins."))
	inventory.add_item(item_id, quantity)
	return {"ok": true, "message": L10n.t("Bought %d× %s for %d Data Coins.") % [quantity, item.display_name, total], "total": total}


static func sell(item_id: StringName, quantity: int, profile: PlayerProfile, inventory: Inventory,
		registry: Node = null) -> Dictionary:
	var item := _item(item_id, registry)
	if not can_sell(item):
		return _fail(L10n.t("That item can't be sold."))
	if quantity <= 0 or not inventory.has_item(item_id, quantity):
		return _fail(L10n.t("You don't have that many."))
	inventory.remove_item(item_id, quantity)
	var total := item.sell_price * quantity
	profile.add_currency(total)
	return {"ok": true, "message": L10n.t("Sold %d× %s for %d Data Coins.") % [quantity, item.display_name, total], "total": total}


static func _item(item_id: StringName, registry: Node) -> ItemData:
	if registry == null:
		var loop := Engine.get_main_loop()
		if loop is SceneTree:
			registry = (loop as SceneTree).root.get_node_or_null("GameData")
	return registry.get_item(item_id) if registry else null


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message, "total": 0}
