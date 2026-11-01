@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Магазин-хаб, данные и формулы (срез 8, №88): шанс покупки по формуле №6, реакция на цену, поток покупателей днём и ночью, предпочтения
## и бюджет покупателя, прилавки (выставить, цена, забрать), сундук на 40 ячеек, касса и выручка, торговец (ассортимент раз в 2 суток, покупка).
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_shop.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.

var _fails: int = 0
var _shop
var _inventory
var _progress
var _settings: ShopSettings
var _generator: WeaponGenerator
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _weapon_item(level: int = 1) -> InventoryItem:
	return InventoryItem.from_weapon(_generator.generate(_rng, level))


func _initialize() -> void:
	await process_frame
	_shop = root.get_node("Shop")
	_inventory = root.get_node("Inventory")
	_progress = root.get_node("Progress")
	_settings = root.get_node("Config").data.shop
	_generator = WeaponGenerator.new(root.get_node("Config").data.weapons)
	_rng.seed = 88
	_formulas()
	_customers()
	_counters()
	_chest()
	_register()
	_trader()
	print("=== FAILS: ", _fails)
	quit(_fails)


func _formulas() -> void:
	print("--- Формулы цены и шанса покупки")
	_check(is_equal_approx(ShopMath.purchase_chance(120, 100, 1.0), 80.0) and is_equal_approx(ShopMath.purchase_chance(120, 100, 2.0), 60.0), "наценка 20%: шанс 80% при нежелании 1.0 и 60% при 2.0 (пример из диздока)")
	_check(is_equal_approx(ShopMath.purchase_chance(100, 100, 2.0), 100.0) and is_equal_approx(ShopMath.purchase_chance(40, 100, 3.0), 100.0), "цена не выше фактической: шанс 100%, недоплата штрафа не даёт")
	_check(is_equal_approx(ShopMath.purchase_chance(250, 100, 1.0), 0.0), "наценка 150% при нежелании 1.0: шанс упирается в 0")
	_check(is_equal_approx(ShopMath.markup(150, 100), 0.5) and is_equal_approx(ShopMath.markup(80, 100), 0.0) and ShopMath.markup(5, 0) >= 0.0, "наценка считается только за переплату и не делит на ноль")
	var actual: int = 200
	_check(ShopMath.reaction(_settings, actual * 5, actual, 0.0) == ShopMath.Reaction.TOO_EXPENSIVE, "шанс 0: «слишком дорого»")
	_check(ShopMath.reaction(_settings, 300, actual, ShopMath.purchase_chance(300, actual, 1.0)) == ShopMath.Reaction.EXPENSIVE, "шанс ниже порога: «дорого»")
	_check(ShopMath.reaction(_settings, actual, actual, 100.0) == ShopMath.Reaction.FAIR, "честная цена: «нормально»")
	_check(ShopMath.reaction(_settings, int(actual * (1.0 - _settings.cheap_markdown)) - 1, actual, 100.0) == ShopMath.Reaction.CHEAP, "заметно ниже фактической: «дёшево»")
	_check(is_equal_approx(ShopMath.customer_interval(_settings, false), _settings.customer_interval) and is_equal_approx(ShopMath.customer_interval(_settings, true), _settings.customer_interval / _settings.night_traffic_multiplier) and ShopMath.customer_interval(_settings, true) > ShopMath.customer_interval(_settings, false), "ночью покупатели приходят реже: пауза %.1f с вместо %.1f" % [ShopMath.customer_interval(_settings, true), ShopMath.customer_interval(_settings, false)])
	_check(ShopMath.clamp_price(_settings, 100, 0) == 1 and ShopMath.clamp_price(_settings, 100, 1000000) == roundi(100.0 * _settings.max_price_multiplier) and ShopMath.price_step(_settings, 200) == roundi(200.0 * float(_settings.price_step_percent) / 100.0), "цена не ниже 1 и не выше %.0f x фактической, шаг кнопок %d%%" % [_settings.max_price_multiplier, _settings.price_step_percent])


func _customers() -> void:
	print("--- Покупатели")
	var weapons: WeaponGenerationSettings = root.get_node("Config").data.weapons
	var bounds_ok: bool = true
	var seen_lovers: int = 0
	for i: int in 200:
		var profile: CustomerProfile = CustomerProfile.roll(_settings, weapons, _rng, 1)
		if profile.budget < _settings.budget_min or profile.budget > _settings.budget_max or profile.unwillingness < _settings.unwillingness_min - 0.001 or profile.unwillingness > _settings.unwillingness_max + 0.001 or profile.manufacturer == null or not weapons.weapon_types.has(profile.weapon_type):
			bounds_ok = false
		if profile.likes_loose_items:
			seen_lovers += 1
	_check(bounds_ok, "200 покупателей: бюджет %d-%d, нежелание %.1f-%.1f, свой тип оружия и производитель" % [_settings.budget_min, _settings.budget_max, _settings.unwillingness_min, _settings.unwillingness_max])
	_check(seen_lovers > 200 * _settings.loose_item_lover_chance * 0.4 and seen_lovers < 200 * _settings.loose_item_lover_chance * 1.8, "любителей деталей и расходников около %.0f%%: %d из 200" % [_settings.loose_item_lover_chance * 100.0, seen_lovers])
	var rich: CustomerProfile = CustomerProfile.roll(_settings, weapons, _rng, 21)
	_check(rich.budget >= roundi(float(_settings.budget_min) * (1.0 + _settings.budget_per_world_level * 20.0)) - 1, "бюджет растёт с уровнем мира (на уровне 21 не меньше %d, выпало %d)" % [roundi(float(_settings.budget_min) * (1.0 + _settings.budget_per_world_level * 20.0)), rich.budget])
	var profile: CustomerProfile = CustomerProfile.new()
	profile.weapon_type = CombatEnums.WeaponType.SHOTGUN
	profile.manufacturer = weapons.manufacturers[0]
	var shotgun: InventoryItem = InventoryItem.from_weapon(_generator.generate(_rng, 1, CombatEnums.WeaponType.SHOTGUN))
	var other_type: int = CombatEnums.WeaponType.SNIPER
	var sniper: InventoryItem = InventoryItem.from_weapon(_generator.generate(_rng, 1, other_type))
	_check(ShopMath.matches(profile, shotgun), "покупатель с дробовиком в предпочтениях берёт дробовик")
	var sniper_matches: bool = ShopMath.matches(profile, sniper)
	_check(sniper_matches == (sniper.weapon.get_manufacturer() == profile.manufacturer), "снайперку он берёт, только если она его производителя (%s)" % str(sniper_matches))
	var part: InventoryItem = InventoryItem.from_part(_generator.generate_part(_rng), weapons)
	var medkit: InventoryItem = InventoryItem.from_definition(load("res://data/content/items/medkit.tres"))
	profile.likes_loose_items = false
	var plain_medkit: bool = ShopMath.matches(profile, medkit)
	profile.likes_loose_items = true
	_check(not plain_medkit and ShopMath.matches(profile, medkit) and ShopMath.matches(profile, part), "аптечки и детали берут любители деталей и расходников")
	_check(ShopMath.trader_price(_settings, shotgun) == maxi(1, roundi(float(shotgun.get_price()) * _settings.trader_markup)) and ShopMath.trader_price(_settings, shotgun) >= shotgun.get_price(), "цена торговца выше цены по формуле в %.2f раза" % _settings.trader_markup)


func _counters() -> void:
	print("--- Прилавки")
	_progress.reset()
	_inventory.clear()
	_shop.reset()
	_check(_shop.counters.size() == _settings.counter_count and _shop.counters[0].is_empty() and not _shop.is_open, "после сброса %d пустых прилавков, магазин закрыт" % _shop.counters.size())
	var item: InventoryItem = _weapon_item(3)
	_inventory.add(item)
	var actual: int = _shop.actual_price(item)
	_check(actual == item.get_price() and actual > 0, "фактическая цена по формуле: %d" % actual)
	_check(_shop.place(0, item, actual * 2) and not _inventory.items.has(item) and _shop.counters[0].item == item and _shop.counters[0].price == actual * 2, "оружие выставлено: ушло из рюкзака, цена игрока %d" % _shop.counters[0].price)
	var second: InventoryItem = _weapon_item(1)
	_inventory.add(second)
	_check(not _shop.place(0, second, 10) and _inventory.items.has(second), "на занятый прилавок второй товар не встаёт")
	_check(_shop.place(1, second, 10 * 1000 * 1000) and _shop.counters[1].price == ShopMath.clamp_price(_settings, _shop.actual_price(second), 10 * 1000 * 1000), "слишком высокая цена обрезается до %d" % _shop.counters[1].price)
	_check(not _shop.place(2, item, 5), "предмет, которого нет в рюкзаке, выставить нельзя")
	var starter: InventoryItem = InventoryItem.from_weapon(_generator.generate(_rng, 1))
	starter.weapon.is_eternal = true
	_inventory.add(starter)
	_check(not _shop.can_sell(starter) and not _shop.place(2, starter, 5) and _inventory.items.has(starter), "вечное оружие (стартовый пистолет) продать нельзя")
	_check(_shop.set_price(0, actual) and _shop.counters[0].price == actual, "цену можно поменять: %d" % _shop.counters[0].price)
	_shop.counters[0].holder = self
	_check(not _shop.take_back(0) and not _shop.set_price(0, 1), "товар, который несёт покупатель, забрать и переоценить нельзя")
	_shop.counters[0].holder = null
	_check(_shop.take_back(0) and _inventory.items.has(item) and _shop.counters[0].is_empty(), "товар снят с прилавка и вернулся в рюкзак")
	# Рюкзак полон: снять нечем, товар остаётся на прилавке.
	_shop.place(0, item, actual)
	_inventory.clear()
	for i: int in _inventory.get_capacity():
		_inventory.add(_weapon_item(1))
	_check(not _shop.take_back(0) and _shop.counters[0].item == item, "рюкзак полон: товар остаётся на прилавке")
	_inventory.clear()
	_shop.reset()


func _chest() -> void:
	print("--- Сундук")
	_inventory.clear()
	_shop.reset()
	var item: InventoryItem = _weapon_item(1)
	_inventory.add(item)
	_check(_shop.chest_capacity() == _settings.chest_capacity and _shop.store(item) and _shop.chest.has(item) and not _inventory.items.has(item), "предмет лёг в сундук (вместимость %d)" % _shop.chest_capacity())
	_check(_shop.retrieve(item) and _inventory.items.has(item) and _shop.chest.is_empty(), "и вернулся в рюкзак")
	for i: int in _shop.chest_capacity():
		_shop.chest.append(_weapon_item(1))
	var extra: InventoryItem = _weapon_item(1)
	_inventory.add(extra)
	_check(_shop.chest_is_full() and not _shop.store(extra) and _inventory.items.has(extra), "сундук полон: ещё один предмет не помещается")
	_inventory.clear()
	for i: int in _inventory.get_capacity():
		_inventory.add(_weapon_item(1))
	_check(not _shop.retrieve(_shop.chest[0]), "рюкзак полон: из сундука ничего не достать")
	_inventory.clear()
	_shop.reset()


func _register() -> void:
	print("--- Касса и торговый день")
	_progress.reset()
	_inventory.clear()
	_shop.reset()
	var item: InventoryItem = _weapon_item(2)
	_inventory.add(item)
	_shop.place(0, item, 300)
	var money_before: int = _progress.money
	var sold: Array = []
	_shop.sold.connect(func(price: int) -> void: sold.append(price))
	_shop.open_shop()
	_check(_shop.is_open, "магазин открыт")
	_shop.counters[0].holder = self
	var paid: int = _shop.complete_sale(_shop.counters[0])
	_check(paid == 300 and _progress.money == money_before + 300 and _shop.earned_today == 300 and _shop.counters[0].is_empty() and sold == [300], "продажа: деньги получены (+%d), прилавок освободился, выручка дня %d" % [paid, _shop.earned_today])
	var days: Array = []
	_shop.day_closed.connect(func(earned: int) -> void: days.append(earned))
	var earned: int = _shop.close_shop()
	_check(earned == 300 and not _shop.is_open and days == [300], "магазин закрыт: торговый день дал %d" % earned)
	_shop.open_shop()
	_check(_shop.earned_today == 0, "новый торговый день начинается с нуля")
	_shop.reset()


func _trader() -> void:
	print("--- Торговец")
	_progress.reset()
	_inventory.clear()
	_shop.reset()
	var grenade_count: int = root.get_node("Config").data.grenades.trader_count
	_check(_shop.refresh_trader(1) and _shop.trader_stock.size() == _settings.trader_stock_size + grenade_count + root.get_node("Config").data.shields.trader_count, "первая раскладка: %d позиций (оружие, гранаты и щиты)" % _shop.trader_stock.size())
	var grenades_on_sale: int = 0
	for slot: ShopSlot in _shop.trader_stock:
		if slot.item.is_grenade():
			grenades_on_sale += 1
	_check(grenades_on_sale == grenade_count, "из них гранат %d (GrenadeSettings.trader_count)" % grenades_on_sale)
	var levels_ok: bool = true
	var prices_ok: bool = true
	for slot: ShopSlot in _shop.trader_stock:
		if slot.item.get_level() < _progress.level or slot.item.get_level() > _progress.level + _settings.trader_level_spread:
			levels_ok = false
		if slot.price != ShopMath.trader_price(_settings, slot.item):
			prices_ok = false
	_check(levels_ok and prices_ok, "уровень оружия от уровня персонажа до +%d, цена с наценкой торговца" % _settings.trader_level_spread)
	var first_item: InventoryItem = _shop.trader_stock[0].item
	_check(not _shop.refresh_trader(1 + _settings.trader_refresh_days - 1) and _shop.trader_stock[0].item == first_item, "раньше, чем через %d суток, ассортимент не меняется" % _settings.trader_refresh_days)
	_check(_shop.refresh_trader(1 + _settings.trader_refresh_days) and _shop.trader_stock[0].item != first_item and _shop.trader_refreshed_day == 1 + _settings.trader_refresh_days, "через %d суток ассортимент обновился" % _settings.trader_refresh_days)
	var price: int = _shop.trader_stock[0].price
	var bought: InventoryItem = _shop.trader_stock[0].item
	_check(not _shop.buy_from_trader(0) and _inventory.items.is_empty(), "без денег покупка не проходит")
	_progress.add_money(price + 5)
	var stock_before: int = _shop.trader_stock.size()
	_check(_shop.buy_from_trader(0) and _inventory.items.has(bought) and _progress.money == 5 and _shop.trader_stock.size() == stock_before - 1, "покупка: деньги списаны (%d), оружие в рюкзаке, на витрине осталось %d" % [price, _shop.trader_stock.size()])
	_inventory.clear()
	for i: int in _inventory.get_capacity():
		_inventory.add(_weapon_item(1))
	_progress.add_money(100000)
	var money: int = _progress.money
	_check(not _shop.buy_from_trader(0) and _progress.money == money, "рюкзак полон: покупка не проходит, деньги целы")
	_inventory.clear()
	_shop.reset()
	_progress.reset()
