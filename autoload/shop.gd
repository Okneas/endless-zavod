extends Node
## Состояние магазина-хаба (срез 8, №88, 05-shop-economy): прилавки с ценами игрока, сундук, ассортимент торговца, выручка торгового дня.
## Живёт между сценами (хаб, забег), как Progress и Inventory. Сам ничего не рисует: сцена хаба читает это состояние и показывает.

signal changed
## Торговый день закончен (магазин закрыт): сколько выручено.
signal day_closed(earned: int)
## Продажа состоялась: за сколько.
signal sold(price: int)

var counters: Array[ShopSlot] = []
var chest: Array[InventoryItem] = []
var trader_stock: Array[ShopSlot] = []
var is_open: bool = false
## Выручка текущего торгового дня.
var earned_today: int = 0
## Номер суток, в которые ассортимент торговца обновлялся последний раз (0, пока торговец не раскладывался).
var trader_refreshed_day: int = 0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	reset()


## Начальное состояние: пустые прилавки и сундук, магазин закрыт, ассортимент торговца не разложен.
func reset() -> void:
	counters.clear()
	for i: int in Config.data.shop.counter_count:
		counters.append(ShopSlot.new())
	chest.clear()
	trader_stock.clear()
	trader_refreshed_day = 0
	is_open = false
	earned_today = 0
	changed.emit()


# --- прилавки

## Фактическая цена предмета по формуле (05-shop-economy, №18, №29): от неё считается шанс покупки.
func actual_price(item: InventoryItem) -> int:
	# Стопка продаётся целиком: цена штуки на число штук (хлам и расходники лежат стопками, №91).
	return item.get_total_price()


## Можно ли выставить предмет на продажу: вечное оружие (стартовый пистолет) продавать нельзя (04-extraction).
func can_sell(item: InventoryItem) -> bool:
	return item != null and not item.is_eternal()


## Выставить предмет из рюкзака на пустой прилавок по цене игрока. false, если прилавок занят, предмета нет в рюкзаке или его нельзя продавать.
func place(index: int, item: InventoryItem, price: int) -> bool:
	if index < 0 or index >= counters.size() or not counters[index].is_empty() or not can_sell(item) or not Inventory.items.has(item):
		return false
	Inventory.remove(item)
	counters[index].item = item
	counters[index].price = ShopMath.clamp_price(Config.data.shop, actual_price(item), price)
	changed.emit()
	return true


## Убрать товар с прилавка обратно в рюкзак. false, если его несёт покупатель или рюкзак полон.
func take_back(index: int) -> bool:
	if index < 0 or index >= counters.size() or not counters[index].is_free():
		return false
	var item: InventoryItem = counters[index].item
	if not Inventory.add(item):
		return false
	counters[index].item = null
	counters[index].price = 0
	changed.emit()
	return true


func set_price(index: int, price: int) -> bool:
	if index < 0 or index >= counters.size() or not counters[index].is_free():
		return false
	counters[index].price = ShopMath.clamp_price(Config.data.shop, actual_price(counters[index].item), price)
	changed.emit()
	return true


# --- сундук

func chest_capacity() -> int:
	return Config.data.shop.chest_capacity


func chest_is_full() -> bool:
	return chest.size() >= chest_capacity()


## Положить предмет из рюкзака в сундук.
func store(item: InventoryItem) -> bool:
	if item == null or chest_is_full() or not Inventory.items.has(item):
		return false
	Inventory.remove(item)
	chest.append(item)
	changed.emit()
	return true


## Достать предмет из сундука в рюкзак. false, если рюкзак полон.
func retrieve(item: InventoryItem) -> bool:
	if not chest.has(item) or not Inventory.add(item):
		return false
	chest.erase(item)
	changed.emit()
	return true


# --- касса и торговый день

## Покупатель расплатился: деньги игроку, место на прилавке освобождается (товар ушёл с покупателем).
func complete_sale(slot: ShopSlot) -> int:
	var price: int = slot.price
	slot.item = null
	slot.price = 0
	slot.holder = null
	slot.carried = false
	earned_today += price
	Progress.add_money(price)
	sold.emit(price)
	changed.emit()
	return price


func open_shop() -> void:
	if is_open:
		return
	is_open = true
	earned_today = 0
	changed.emit()


## Закрыть магазин: торговый день кончается. Возвращает выручку.
func close_shop() -> int:
	if not is_open:
		return 0
	is_open = false
	var earned: int = earned_today
	day_closed.emit(earned)
	changed.emit()
	return earned


# --- торговец

## Обновляет ассортимент торговца, если прошло достаточно суток (или он ещё не раскладывался). Возвращает true, если обновил.
func refresh_trader(day: int, force: bool = false) -> bool:
	var settings: ShopSettings = Config.data.shop
	if not force and not trader_stock.is_empty() and day - trader_refreshed_day < settings.trader_refresh_days:
		return false
	trader_stock.clear()
	var generator: WeaponGenerator = WeaponGenerator.new(Config.data.weapons)
	for i: int in settings.trader_stock_size:
		var level: int = Progress.level + _rng.randi_range(0, settings.trader_level_spread)
		var weapon: WeaponInstance = generator.generate(_rng, level)
		if weapon == null:
			continue
		var slot: ShopSlot = ShopSlot.new()
		slot.item = InventoryItem.from_weapon(weapon)
		slot.price = ShopMath.trader_price(settings, slot.item)
		trader_stock.append(slot)
	# Гранаты у торговца (№92): уровня персонажа плюс разброс, как у оружия.
	var grenade_generator: GrenadeGenerator = GrenadeGenerator.new(Config.data.grenades, Config.data.weapons.quality_scale)
	for i: int in Config.data.grenades.trader_count:
		var grenade_slot: ShopSlot = ShopSlot.new()
		grenade_slot.item = InventoryItem.from_grenade(grenade_generator.generate(_rng, Progress.level + _rng.randi_range(0, settings.trader_level_spread)))
		grenade_slot.price = ShopMath.trader_price(settings, grenade_slot.item)
		trader_stock.append(grenade_slot)
	# Щиты у торговца (№93): так же, как гранаты.
	var shield_generator: ShieldGenerator = ShieldGenerator.new(Config.data.shields, Config.data.weapons.quality_scale)
	for i: int in Config.data.shields.trader_count:
		var shield_slot: ShopSlot = ShopSlot.new()
		shield_slot.item = InventoryItem.from_shield(shield_generator.generate(_rng, Progress.level + _rng.randi_range(0, settings.trader_level_spread)))
		shield_slot.price = ShopMath.trader_price(settings, shield_slot.item)
		trader_stock.append(shield_slot)
	trader_refreshed_day = day
	changed.emit()
	return true


## Купить у торговца: деньги списываются, предмет идёт в рюкзак. false, если денег не хватает или рюкзак полон (деньги целы).
func buy_from_trader(index: int) -> bool:
	if index < 0 or index >= trader_stock.size() or Inventory.is_full():
		return false
	var slot: ShopSlot = trader_stock[index]
	if not Progress.spend_money(slot.price):
		return false
	Inventory.add(slot.item)
	trader_stock.remove_at(index)
	changed.emit()
	return true
