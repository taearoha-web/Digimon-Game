class_name ShopData
extends Resource
## A shop's catalogue. Prices come from each item's [member ItemData.buy_price];
## [ShopService] applies [member price_multiplier] and handles buying/selling.

@export var id: StringName
@export var display_name: String = ""
@export var greeting: String = ""
## Item ids offered for sale (in display order).
@export var stock: Array[StringName] = []
## Scales every buy price (e.g. 1.2 for a remote outpost).
@export var price_multiplier: float = 1.0
## Whether the player can sell items here.
@export var buys_items: bool = true
