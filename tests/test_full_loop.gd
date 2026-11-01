@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Сквозной цикл прототипа (срез 9, №89, условие готовности из 10-prototype-scope): из магазина в забег, лут, эвакуация, возврат
## в магазин, продажа покупателю, трата у торговца, новый забег, смерть с потерей лута, возврат, товар на прилавке и деньги целы.
## Сцены меняются как в игре (хаб -> забег -> хаб), только сам вызов смены сцены подменён, чтобы не уходить из теста.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_full_loop.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.

const HUB_PATH: String = "res://hub/hub.tscn"
const RUN_PATH: String = "res://run/run.tscn"
# Значения Customer.State: сам класс тянет автозагрузки и в тесте называться не может.
const S_WAIT_REGISTER: int = 3

var _fails: int = 0
var _scene: Node
var _config
var _progress
var _inventory
var _run
var _shop
var _clock
var _zone_settings: ZoneSettings
var _shop_settings: ShopSettings
var _generator: WeaponGenerator
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _recorded: Array = []


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _until(cond: Callable, max_frames: int) -> int:
	for i: int in max_frames:
		if cond.call():
			return i
		await physics_frame
	return -1


# Смена сцены как в игре: старая убирается, новая создаётся и входит в дерево.
func _switch(path: String) -> void:
	if _scene != null:
		root.remove_child(_scene)
		_scene.free()
	_scene = (load(path) as PackedScene).instantiate()
	root.add_child(_scene)
	if path == HUB_PATH:
		_scene.floor_node.auto_spawn = false
		_scene.scene_changer = func(changed_path: String) -> void: _recorded.append(changed_path)
		await _until(func() -> bool: return _scene.is_navigation_ready(), 600)
	else:
		_scene.hub_changer = func(changed_path: String) -> void: _recorded.append(changed_path)
		await _wait_built()
	await _frames(5)


func _wait_built() -> void:
	for i: int in 20000:
		await process_frame
		if _scene.layout != null and not _scene._busy:
			break
	await _frames(5)


func _initialize() -> void:
	create_timer(1500.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	_config = root.get_node("Config")
	_progress = root.get_node("Progress")
	_inventory = root.get_node("Inventory")
	_run = root.get_node("Run")
	_shop = root.get_node("Shop")
	_clock = root.get_node("GameClock")
	_zone_settings = _config.data.zones
	_shop_settings = _config.data.shop
	_generator = WeaponGenerator.new(_config.data.weapons)
	_rng.seed = 890
	var seed_before: int = _zone_settings.debug_seed
	var walk_before: float = _shop_settings.walk_speed
	var inspect_before: float = _shop_settings.inspect_time
	var patience_before: float = _shop_settings.register_patience
	# Быстрее ходьба и осмотр, чтобы проверка шла секунды. Правка в памяти, файлы не меняются.
	_shop_settings.walk_speed = 12.0
	_shop_settings.inspect_time = 0.5
	_shop_settings.register_patience = 4.0
	_zone_settings.debug_seed = 4242
	root.size = Vector2i(1920, 1080)
	_progress.reset()
	_inventory.clear()
	_shop.reset()
	_run.carried_loadout = []
	_run.active = false
	await _stage_first_run()
	await _stage_sell_and_spend()
	await _stage_death_and_return()
	_shop_settings.walk_speed = walk_before
	_shop_settings.inspect_time = inspect_before
	_shop_settings.register_patience = patience_before
	_zone_settings.debug_seed = seed_before
	print("=== FAILS: ", _fails)
	quit(_fails)


# 1. Магазин, дверь в забег, лут, эвакуация, возврат.
func _stage_first_run() -> void:
	print("--- Магазин, забег, эвакуация, возврат")
	await _switch(HUB_PATH)
	var hub = _scene
	_check(not _run.active and hub.get_node("Player").get_weapon().instance.is_eternal, "старт в хабе: забега нет, в руках стартовый пистолет")
	_check(_shop.trader_stock.size() == _shop_settings.trader_stock_size + _config.data.grenades.trader_count + _config.data.shields.trader_count, "торговец разложил товар: оружие, гранаты и щиты (%d)" % _shop.trader_stock.size())
	_recorded.clear()
	hub.enter_run()
	_check(_recorded == [RUN_PATH], "дверь в забег: смена сцены на забег")
	await _switch(RUN_PATH)
	var player = _scene.get_node("Player")
	_check(_run.active and _run.zone == 1 and player.get_weapon().instance != null and player.get_weapon().instance.is_eternal, "забег начался: зона 1, снаряжение с игроком (стартовый пистолет)")
	# Лут: оружие и деньги, как после боёв и кладовых.
	var loot: Array = []
	for i: int in 3:
		var item: InventoryItem = InventoryItem.from_weapon(_generator.generate(_rng, 2))
		_inventory.add(item)
		loot.append(item)
	var money: int = _progress.money
	_progress.add_money(500)
	_run.use_exit(_run.Exit.EVACUATE)
	await _frames(5)
	var result = _scene._result_screen
	_check(not _run.active and _run.outcome == _run.Outcome.EVACUATED and result.is_open(), "эвакуация: забег окончен, показаны итоги")
	_check(_inventory.items.size() == 3 and _progress.money == money + 500, "при эвакуации лут и деньги целы (оружия %d, монет +500)" % _inventory.items.size())
	_recorded.clear()
	result._on_to_shop()
	_check(_recorded == [HUB_PATH] and not paused, "«Вернуться в магазин»: смена сцены на хаб, пауза снята")
	await _switch(HUB_PATH)
	_check(_inventory.items.size() == 3 and _shop.trader_stock.size() == _shop_settings.trader_stock_size + _config.data.grenades.trader_count + _config.data.shields.trader_count, "в хабе лут в рюкзаке, состояние магазина сохранилось")


# 2. Продажа покупателю и трата у торговца.
func _stage_sell_and_spend() -> void:
	print("--- Продажа и трата")
	var hub = _scene
	var item: InventoryItem = _inventory.items[0]
	var price: int = _shop.actual_price(item)
	_shop.place(1, item, price)
	hub.toggle_shop()
	_check(_shop.is_open and _shop.counters[1].item == item and not _inventory.items.has(item), "товар на прилавке за %d, магазин открыт" % price)
	var profile: CustomerProfile = CustomerProfile.new()
	profile.weapon_type = item.weapon.get_weapon_type()
	profile.manufacturer = item.weapon.get_manufacturer()
	profile.unwillingness = 1.0
	profile.budget = 1000000
	var customer = hub.floor_node.spawn_customer(profile)
	await _until(func() -> bool: return customer.state == S_WAIT_REGISTER and hub.register.has_customer_waiting(), 6000)
	_check(hub.register.has_customer_waiting(), "покупатель взял товар и ждёт у кассы")
	var money: int = _progress.money
	hub.register.interact(hub.get_node("Player"))
	_check(_progress.money == money + price and _shop.counters[1].is_empty() and _shop.earned_today == price, "оплата принята: +%d" % price)
	await _until(func() -> bool: return hub.floor_node.customers.is_empty(), 3000)
	hub.toggle_shop()
	await _frames(3)
	_check(not _shop.is_open, "магазин закрыт, торговый день записан")
	# Трата: торговец продаёт оружие за деньги.
	var offer: ShopSlot = _shop.trader_stock[0]
	if _progress.money < offer.price:
		_progress.add_money(offer.price - _progress.money)
	money = _progress.money
	var count: int = _inventory.items.size()
	hub.trader_panel._buy(0)
	_check(_progress.money == money - offer.price and _inventory.items.size() == count + 1 and _inventory.items.has(offer.item), "покупка у торговца: -%d монет, оружие в рюкзаке" % offer.price)
	_check(offer.item.weapon.level <= _progress.level + _shop_settings.trader_level_spread, "уровень купленного оружия (%d) не выше уровня персонажа плюс разброс" % offer.item.weapon.level)


# 3. Новый забег, смерть, возврат: на прилавке всё цело, рюкзак пуст, деньги целы.
func _stage_death_and_return() -> void:
	print("--- Новый забег, смерть, возврат")
	var hub = _scene
	var kept: InventoryItem = _inventory.items[0]
	_shop.place(3, kept, _shop.actual_price(kept))
	_progress.add_money(300)
	_recorded.clear()
	hub.enter_run()
	await _switch(RUN_PATH)
	var player = _scene.get_node("Player")
	_check(_run.active and _run.zone == 1 and not _inventory.items.is_empty(), "второй забег: зона 1, добыча с собой (оружия %d)" % _inventory.items.size())
	var carried: int = _inventory.items.size()
	var money: int = _progress.money
	player.take_damage(1.0e6)
	await _frames(40)
	await _until(func() -> bool: return _scene._result_screen.is_open(), 600)
	_check(not _run.active and _run.outcome == _run.Outcome.DEATH and _scene._result_screen.is_open(), "смерть: забег окончен, показаны итоги")
	_check(_inventory.items.is_empty() and _run.lost_items == carried and _progress.money == money, "лут потерян (%d), деньги целы (%d)" % [_run.lost_items, _progress.money])
	_recorded.clear()
	_scene._result_screen._on_to_shop()
	await _switch(HUB_PATH)
	var weapon = _scene.get_node("Player").get_weapon()
	_check(_recorded == [HUB_PATH] and weapon.instance != null and weapon.instance.is_eternal, "возврат в хаб: в руках стартовый пистолет")
	_check(_shop.counters[3].item == kept and _shop.counters[3].price == _shop.actual_price(kept), "товар на прилавке пережил смерть")
	_check(_progress.money == money, "деньги целы после смерти и возврата: %d" % _progress.money)
