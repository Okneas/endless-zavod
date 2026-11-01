class_name ShopController
extends Node3D
## Магазин в забеге (срез 7, №82): на постаментах (маркеры shop_item) лежат оружие уровня зоны и аптечки с ценами. Цена это
## цена предмета (цена продажи) на множитель shop_markup. Купить: смотреть на предмет и нажать interact, деньги списываются при
## подборе (ItemPickup с ценой). Набор не обновляется: он выкладывается один раз при построении зоны.

var room: RoomPiece
## Предметы на постаментах (для проверки и отладки).
var stock: Array[ItemPickup] = []


func setup(p_room: RoomPiece, zone_level: int, seed_value: int) -> void:
	room = p_room
	name = "Shop"
	room.add_child(self)
	var run: RunSettings = Config.data.run
	var markers: Array[Marker3D] = room.get_markers(&"shop_item")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var generator: WeaponGenerator = WeaponGenerator.new(Config.data.weapons)
	var slot: int = 0
	for i: int in run.shop_weapons:
		if slot >= markers.size():
			break
		var weapon: WeaponInstance = generator.generate(rng, zone_level)
		if weapon == null:
			continue
		var item: InventoryItem = InventoryItem.from_weapon(weapon)
		_put(item, markers[slot].global_position, roundi(float(item.get_price()) * run.shop_markup))
		slot += 1
	for i: int in run.shop_medkits:
		if slot >= markers.size() or run.shop_medkit == null:
			break
		var medkit: InventoryItem = InventoryItem.from_definition(run.shop_medkit, 1)
		_put(medkit, markers[slot].global_position, roundi(float(medkit.get_price()) * run.shop_markup))
		slot += 1


func _put(item: InventoryItem, at: Vector3, price: int) -> void:
	var pickup: ItemPickup = ItemPickup.spawn(room, item, at, Vector3.ZERO, maxi(price, 1))
	if pickup != null:
		stock.append(pickup)
