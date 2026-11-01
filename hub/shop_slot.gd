class_name ShopSlot
extends RefCounted
## Место на прилавке или у торговца (срез 8, №88): предмет и цена игрока. Пока покупатель несёт предмет к кассе, место держит он (holder),
## игрок такой предмет забрать или переоценить не может.

var item: InventoryItem
var price: int = 0
## Кто сейчас присматривает этот товар или несёт его к кассе (покупатель), иначе null.
var holder: Object
## Покупатель уже взял товар и несёт его к кассе: на прилавке его не видно, но место занято до оплаты или возврата.
var carried: bool = false


func is_empty() -> bool:
	return item == null


func is_free() -> bool:
	return item != null and holder == null
