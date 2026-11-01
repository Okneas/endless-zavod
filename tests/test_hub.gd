@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Магазин-хаб в сцене hub/hub.tscn (срез 8, №88): состав зала, прилавки и окна, покупатель идёт к товару, показывает реакцию, покупает,
## платит на кассе; отказ при завышенной цене; терпение у кассы; закрытие магазина возвращает товар; поток покупателей днём и ночью; сундук,
## торговец, справочник; дверь в забег уносит снаряжение; день и ночь меняют свет.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_hub.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.

# Значения Customer.State и HubStation.Kind: сами классы тянут автозагрузки и в тесте называться не могут.
const S_INSPECT: int = 1
const S_WAIT_REGISTER: int = 3
const S_LEAVE: int = 4
const S_WANDER: int = 5
const K_CHEST: int = 0
const K_PRICE_BOOK: int = 1
const K_RUN_DOOR: int = 3
const K_TRADER: int = 4

var _fails: int = 0
var _hub
var _player
var _shop
var _inventory
var _progress
var _clock
var _settings: ShopSettings
var _generator: WeaponGenerator
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


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


func _initialize() -> void:
	create_timer(900.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	var config = root.get_node("Config")
	_settings = config.data.shop
	_shop = root.get_node("Shop")
	_inventory = root.get_node("Inventory")
	_progress = root.get_node("Progress")
	_clock = root.get_node("GameClock")
	_generator = WeaponGenerator.new(config.data.weapons)
	_rng.seed = 880
	_progress.reset()
	_inventory.clear()
	_shop.reset()
	root.size = Vector2i(1920, 1080)
	_hub = (load("res://hub/hub.tscn") as PackedScene).instantiate()
	root.add_child(_hub)
	await _frames(10)
	await _until(func() -> bool: return _hub.is_navigation_ready(), 600)
	_player = _hub.get_node("Player")
	# Быстрее ходьба и осмотр, короче терпение: проверка идёт секунды, а не минуты. Это правка в памяти, файл не меняется.
	_settings.walk_speed = 12.0
	_settings.inspect_time = 0.5
	_settings.register_patience = 3.0
	_settings.max_customers = 99
	# Покупатели не приходят сами, пока проверка не займётся потоком: ведём только своих.
	_hub.floor_node.auto_spawn = false
	await _layout()
	await _customer_flow()
	await _browsing()
	await _register_side()
	await _avoid_player()
	await _closing()
	await _traffic()
	await _stations()
	await _run_door()
	_lighting()
	_loadout()
	print("=== FAILS: ", _fails)
	quit(_fails)


# Выставляет оружие на прилавок и возвращает его.
func _stock(index: int, price_factor: float, weapon_type: int = -1) -> InventoryItem:
	var item: InventoryItem = InventoryItem.from_weapon(_generator.generate(_rng, 2, weapon_type))
	_inventory.add(item)
	_shop.place(index, item, roundi(float(_shop.actual_price(item)) * price_factor))
	return item


# Покупатель с заданными предпочтениями под этот товар (бюджет большой, нежелание 1.0).
func _profile_for(item: InventoryItem) -> CustomerProfile:
	var profile: CustomerProfile = CustomerProfile.new()
	profile.weapon_type = item.weapon.get_weapon_type()
	profile.manufacturer = item.weapon.get_manufacturer()
	profile.unwillingness = 1.0
	profile.budget = 1000000
	profile.color = Color(0.3, 0.6, 0.9)
	return profile


func _clear_customers() -> void:
	for customer in _hub.floor_node.customers.duplicate():
		if is_instance_valid(customer):
			customer.free()
	_hub.floor_node.customers.clear()
	_hub.register.queue.clear()


func _layout() -> void:
	print("--- Зал хаба")
	_check(_hub.counters.size() == _settings.counter_count and _hub.register != null and _hub.floor_node != null, "в зале %d прилавков, касса и торговый зал" % _hub.counters.size())
	var kinds: Array = []
	for station in _hub.find_children("*", "HubStation", true, false):
		kinds.append(station.kind)
	kinds.sort()
	_check(kinds == [0, 1, 2, 3, 4], "есть сундук, справочник, вывеска, дверь в забег и торговец: %s" % str(kinds))
	_check(_player.global_position.distance_to(_hub.get_node("PlayerSpawn").global_position) < 0.5 and _hub.get_node("Hud") != null, "игрок стоит на старте, интерфейс на месте")
	_check(not _shop.is_open and _shop.trader_stock.size() == _settings.trader_stock_size, "магазин закрыт, торговец разложил товар (%d)" % _shop.trader_stock.size())
	_check(_hub.is_navigation_ready(), "сетка навигации зала запечена и подхвачена картой")
	var clock_label: Label = _hub.get_node("Hud/Root/MoneyRow/ClockLabel")
	await _frames(3)
	_check(clock_label != null and clock_label.text.contains(str(_clock.day_index)) and (clock_label.text.contains(tr("HUD_PHASE_DAY")) or clock_label.text.contains(tr("HUD_PHASE_NIGHT"))), "в интерфейсе часы суток: «%s»" % clock_label.text.strip_edges())
	# Прилавок и его окно.
	var counter = _hub.counters[0]
	_check(counter.get_prompt().contains(KeyHint.text(&"interact")), "подсказка у пустого прилавка: «%s»" % counter.get_prompt())
	counter.interact(_player)
	await _frames(3)
	_check(_hub.counter_panel.is_open() and paused, "жмём E у прилавка: открылось окно, игра на паузе")
	var item: InventoryItem = InventoryItem.from_weapon(_generator.generate(_rng, 2))
	_inventory.add(item)
	_hub.counter_panel._pick(item)
	var actual: int = _shop.actual_price(item)
	_check(_hub.counter_panel._price == actual, "выбран предмет, цена по умолчанию равна цене по формуле (%d)" % actual)
	var step: int = ShopMath.price_step(_settings, actual)
	_hub.counter_panel._change_price(step, item, false)
	_check(_hub.counter_panel._price == actual + step, "кнопка «плюс» подняла цену на шаг %d" % step)
	_hub.counter_panel._place(item)
	_check(_shop.counters[0].item == item and _shop.counters[0].price == actual + step and not _inventory.items.has(item), "«Выставить»: товар на прилавке за %d" % _shop.counters[0].price)
	_hub.counter_panel._change_price(step, item, true)
	_check(_shop.counters[0].price == actual + 2 * step, "цену выставленного товара можно менять: %d" % _shop.counters[0].price)
	_hub.counter_panel.close()
	await _frames(3)
	var display_children: int = counter.get_child(counter.get_child_count() - 1).get_child_count()
	_check(display_children > 0 and counter._price_label.text == str(actual + 2 * step), "на столе виден товар, над ним цена %s" % counter._price_label.text)
	_check(counter.get_prompt() != tr("HUD_INTERACT_COUNTER_EMPTY").format({"key": KeyHint.text(&"interact"), "number": 1}), "у занятого прилавка другая подсказка")
	_shop.take_back(0)
	_check(counter._price_label.text == "" and _inventory.items.has(item), "товар снят: стол пуст, предмет вернулся в рюкзак")
	_inventory.clear()
	_shop.reset()


func _customer_flow() -> void:
	print("--- Покупатель: осмотр, покупка, касса")
	_progress.reset()
	_inventory.clear()
	_shop.reset()
	_hub.toggle_shop()
	_check(_shop.is_open, "вывеска: магазин открыт")
	var item: InventoryItem = _stock(2, 1.0)
	var customer = _hub.floor_node.spawn_customer(_profile_for(item))
	_check(customer.route.size() == 1 and customer.route[0] == _hub.counters[2] and customer.slot == null, "маршрут покупателя это единственный прилавок с товаром, пока идёт, товар не занят")
	await _until(func() -> bool: return customer.state == S_INSPECT, 3000)
	_check(customer.slot == _shop.counters[2] and _shop.counters[2].holder == customer, "у прилавка покупатель держит товар, пока разглядывает")
	_check(customer.state == S_INSPECT and customer.last_reaction == ShopMath.Reaction.FAIR and is_equal_approx(customer.last_chance, 100.0), "дошёл до прилавка, разглядывает: реакция «нормально», шанс 100%")
	_check(customer._label.text == tr("HUB_REACT_FAIR"), "над головой реакция «%s»" % customer._label.text)
	await _until(func() -> bool: return customer.state == S_WAIT_REGISTER, 3000)
	_check(_shop.counters[2].carried and _hub.counters[2]._price_label.text == "", "взял товар: на столе его уже нет")
	await _until(func() -> bool: return _hub.register.has_customer_waiting(), 3000)
	_check(_hub.register.has_customer_waiting() and _hub.register.get_prompt().contains(str(_shop.counters[2].price)), "ждёт у кассы, подсказка кассы: «%s»" % _hub.register.get_prompt())
	var money_before: int = _progress.money
	var price: int = _shop.counters[2].price
	_check(_hub.register.interact(_player), "игрок жмёт на кассе")
	_check(_progress.money == money_before + price and _shop.counters[2].is_empty() and _shop.earned_today == price, "оплата принята: +%d, прилавок пуст, выручка дня %d" % [price, _shop.earned_today])
	await _until(func() -> bool: return _hub.floor_node.customers.is_empty(), 3000)
	_check(_hub.floor_node.customers.is_empty() and _hub.register.queue.is_empty(), "покупатель ушёл из магазина")
	# Слишком дорого: отказ, товар остаётся.
	var pricey: InventoryItem = _stock(3, 4.0)
	var haggler = _hub.floor_node.spawn_customer(_profile_for(pricey))
	await _until(func() -> bool: return haggler.state == S_LEAVE, 3000)
	_check(haggler.last_reaction == ShopMath.Reaction.TOO_EXPENSIVE and _shop.counters[3].item == pricey and _shop.counters[3].holder == null and not _shop.counters[3].carried, "цена x4: реакция «грабёж», отказ, товар на месте")
	await _until(func() -> bool: return _hub.floor_node.customers.is_empty(), 3000)
	# Дёшево.
	_shop.take_back(3)
	var cheap: InventoryItem = _stock(3, 0.5)
	var bargain_hunter = _hub.floor_node.spawn_customer(_profile_for(cheap))
	await _until(func() -> bool: return bargain_hunter.state == S_INSPECT, 3000)
	_check(bargain_hunter.last_reaction == ShopMath.Reaction.CHEAP, "цена вдвое ниже: реакция «дёшево»")
	_clear_customers()
	_shop.counters[3].holder = null
	# Нет подходящего: ни одно оружие не подходит и ни у кого нет денег.
	_shop.take_back(3)
	_shop.reset()
	_shop.open_shop()
	var empty_handed = _hub.floor_node.spawn_customer(_profile_for(item))
	_check(empty_handed.slot == null and empty_handed.route.is_empty(), "на прилавках пусто: маршрута нет, покупатель ничего не присмотрел")
	var touched_empty: bool = false
	for i: int in 3000:
		await physics_frame
		if not is_instance_valid(empty_handed):
			break
		for counter in _hub.counters:
			if counter.get_slot().holder == empty_handed:
				touched_empty = true
	_check(_hub.floor_node.customers.is_empty() and not touched_empty, "оглядел зал у входа и ушёл без покупки, к пустым прилавкам не подходил")
	_inventory.clear()


func _browsing() -> void:
	print("--- Обход прилавков (Moonlighter)")
	_progress.reset()
	_inventory.clear()
	_shop.reset()
	_hub.toggle_shop()
	_clear_customers()
	var config = root.get_node("Config")
	var types: Array = config.data.weapons.weapon_types
	var occupied: Array = [0, 2, 4]
	var items: Array = []
	for index: int in occupied:
		# Дорого: никто не купит, покупатель просто обходит прилавки.
		items.append(_stock(index, 4.0, types[0]))
	var keep_chance: float = _settings.wander_chance
	_settings.wander_chance = 0.0
	_hub.floor_node._rng.seed = 11
	var sizes: Dictionary = {}
	var valid: bool = true
	for n: int in 30:
		var probe = _hub.floor_node.spawn_customer(_profile_for(items[0]))
		var indexes: Array = []
		for counter in probe.route:
			indexes.append(counter.index)
		sizes[indexes.size()] = true
		var only_occupied: bool = true
		var unique: Dictionary = {}
		for i: int in indexes:
			only_occupied = only_occupied and occupied.has(i)
			unique[i] = true
		var ordered: bool = true
		for k: int in range(2, probe.route.size()):
			var before: bool = probe.route[k - 1].global_position.x > probe.route[k - 2].global_position.x
			ordered = ordered and (probe.route[k].global_position.x > probe.route[k - 1].global_position.x) == before
		valid = valid and only_occupied and unique.size() == indexes.size() and indexes.size() >= 1 and indexes.size() <= _settings.max_visits and ordered
		_clear_customers()
	_check(valid, "30 маршрутов: только прилавки с товаром %s, без повторов, от 1 до %d, вдоль стены в одну сторону" % [str(occupied), _settings.max_visits])
	var all_sizes: bool = true
	for k: int in range(1, mini(_settings.max_visits, occupied.size()) + 1):
		all_sizes = all_sizes and sizes.has(k)
	_check(all_sizes, "длина маршрута разная, от 1 до %d: %s" % [mini(_settings.max_visits, occupied.size()), str(sizes.keys())])
	# Обходит все прилавки маршрута и уходит; осмотр только там, где есть товар.
	var walker = null
	for n: int in 60:
		walker = _hub.floor_node.spawn_customer(_profile_for(items[0]))
		if walker.route.size() >= 2:
			break
		_clear_customers()
	var stops: int = walker.route.size()
	var inspect_empty: int = 0
	var seen_inspect: Dictionary = {}
	for i: int in 6000:
		await physics_frame
		if not is_instance_valid(walker):
			break
		if walker.state == S_INSPECT:
			if walker.slot == null or walker.slot.item == null:
				inspect_empty += 1
			else:
				seen_inspect[walker.slot] = true
	_check(stops >= 2 and seen_inspect.size() == stops and inspect_empty == 0 and _hub.floor_node.customers.is_empty(), "обошёл %d прилавка по очереди, везде был товар, ушёл: осмотров %d" % [stops, seen_inspect.size()])
	var holders_free: bool = true
	for k: int in occupied.size():
		var slot = _shop.counters[occupied[k]]
		holders_free = holders_free and slot.holder == null and not slot.carried and slot.item == items[k]
	_check(holders_free, "после обхода товар на месте и никем не занят")
	# Товар не по вкусу: «Не моё», дальше, без покупки.
	var stranger: CustomerProfile = _profile_for(items[0])
	stranger.weapon_type = types[1]
	stranger.manufacturer = null
	stranger.likes_loose_items = false
	var foreign = null
	for n: int in 60:
		foreign = _hub.floor_node.spawn_customer(stranger)
		if foreign.route.size() >= 2:
			break
		_clear_customers()
	var said_not_mine: int = 0
	var bought: bool = false
	var last_text: String = ""
	for i: int in 6000:
		await physics_frame
		if not is_instance_valid(foreign):
			break
		if foreign.state == S_INSPECT and foreign._label.text == tr("HUB_REACT_NOT_MINE") and last_text != foreign._label.text:
			said_not_mine += 1
		last_text = foreign._label.text
		bought = bought or foreign.is_carrying()
	_check(not bought and said_not_mine >= 2 and _shop.counters[0].item == items[0], "чужой товар: «Не моё» на %d прилавках, ничего не взял" % said_not_mine)
	_clear_customers()
	# Прогулка между осмотрами.
	_settings.wander_chance = 1.0
	var stroller = null
	for n: int in 60:
		stroller = _hub.floor_node.spawn_customer(_profile_for(items[0]))
		if stroller.route.size() >= 2:
			break
		_clear_customers()
	var wandered: bool = false
	for i: int in 6000:
		await physics_frame
		if not is_instance_valid(stroller):
			break
		wandered = wandered or stroller.state == S_WANDER
	_check(wandered and _hub.floor_node.customers.is_empty(), "между осмотрами прогулялся по залу и всё равно ушёл")
	_settings.wander_chance = keep_chance
	_clear_customers()
	_inventory.clear()
	_shop.reset()


func _register_side() -> void:
	print("--- Касса: сторона покупателей")
	_progress.reset()
	_inventory.clear()
	_shop.reset()
	_hub.toggle_shop()
	_clear_customers()
	var register = _hub.register
	var center: Vector3 = _hub.floor_node._stands_center()
	var first: Vector3 = register.queue_point(0)
	_check(first.distance_to(center) < register.global_position.distance_to(center) and register.queue_point(1).distance_to(center) < first.distance_to(center), "первое место и очередь с лицевой стороны кассы, со стороны зала")
	var map: RID = _hub.get_world_3d().navigation_map
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, _hub.counters[5].stand_point(), first, true)
	var crossed: bool = false
	for point: Vector3 in path:
		var local: Vector3 = register.global_transform.affine_inverse() * point
		crossed = crossed or (absf(local.x) < 0.9 and absf(local.z) < 0.7)
	_check(path.size() >= 2 and not crossed, "путь от дальнего прилавка до кассы идёт мимо неё (точек пути %d)" % path.size())
	var item: InventoryItem = _stock(5, 1.0)
	var customer = _hub.floor_node.spawn_customer(_profile_for(item))
	var inside_box: bool = false
	var from_back: bool = false
	for i: int in 6000:
		await physics_frame
		if not is_instance_valid(customer) or customer.state == S_LEAVE:
			break
		var local: Vector3 = register.global_transform.affine_inverse() * customer.global_position
		inside_box = inside_box or (absf(local.x) < 0.9 and absf(local.z) < 0.7)
		if customer.state == S_WAIT_REGISTER and register.has_customer_waiting():
			from_back = local.z < 0.0
			break
	_check(not inside_box and not from_back and register.has_customer_waiting(), "покупатель дошёл до кассы, не заходя в неё, и стоит со стороны зала")
	register.interact(_player)
	await _until(func() -> bool: return _hub.floor_node.customers.is_empty(), 3000)
	_clear_customers()
	_inventory.clear()
	_shop.reset()


func _avoid_player() -> void:
	print("--- Покупатель обходит игрока")
	_progress.reset()
	_inventory.clear()
	_shop.reset()
	_hub.toggle_shop()
	_clear_customers()
	var item: InventoryItem = _stock(2, 1.0)
	var customer = _hub.floor_node.spawn_customer(_profile_for(item))
	var spot: Vector3 = _hub.counters[2].stand_point().lerp(_hub.floor_node.entrance, 0.5)
	spot.y = 0.1
	var closest: float = INF
	for i: int in 3000:
		_player.global_position = spot
		_player.velocity = Vector3.ZERO
		await physics_frame
		if not is_instance_valid(customer) or customer.state == S_INSPECT:
			break
		closest = minf(closest, Vector2(customer.global_position.x - spot.x, customer.global_position.z - spot.z).length())
	_check(is_instance_valid(customer) and customer.state == S_INSPECT and closest > 0.55, "игрок стоит на пути к прилавку: покупатель прошёл мимо, не сквозь (ближе всего %.2f м) и дошёл" % closest)
	_player.global_position = _hub.get_node("PlayerSpawn").global_position
	_clear_customers()
	_inventory.clear()
	_shop.reset()


func _closing() -> void:
	print("--- Терпение у кассы и закрытие магазина")
	_progress.reset()
	_inventory.clear()
	_shop.reset()
	_hub.toggle_shop()
	var item: InventoryItem = _stock(0, 1.0)
	var customer = _hub.floor_node.spawn_customer(_profile_for(item))
	await _until(func() -> bool: return customer.state == S_WAIT_REGISTER, 3000)
	var money: int = _progress.money
	var moods: Dictionary = {}
	for i: int in int(_settings.register_patience * 120.0) + 400:
		await physics_frame
		if customer.state == S_WAIT_REGISTER:
			moods[customer.get_mood_text()] = true
		if customer.state == S_LEAVE:
			break
	_check(moods.has("^_^") and moods.has(">_<"), "терпение у кассы видно по значку над головой: %s" % str(moods.keys()))
	_check(customer.state == S_LEAVE and _shop.counters[0].item == item and not _shop.counters[0].carried and _shop.counters[0].holder == null and _progress.money == money, "не дождался оплаты: ушёл, товар вернулся на прилавок, денег нет")
	await _until(func() -> bool: return _hub.floor_node.customers.is_empty(), 3000)
	# Закрытие магазина с покупателем, несущим товар.
	var second = _hub.floor_node.spawn_customer(_profile_for(item))
	await _until(func() -> bool: return second.state == S_WAIT_REGISTER, 3000)
	_check(_shop.counters[0].carried, "второй покупатель несёт товар к кассе")
	_hub.toggle_shop()
	await _frames(4)
	_check(not _shop.is_open and not _shop.counters[0].carried and _shop.counters[0].item == item and _shop.counters[0].holder == null and second.state == S_LEAVE and _hub.register.queue.is_empty(), "магазин закрыт: покупатель вернул товар на прилавок и уходит")
	_clear_customers()
	_inventory.clear()
	_shop.reset()


func _traffic() -> void:
	print("--- Поток покупателей днём и ночью")
	_shop.reset()
	_settings.customer_interval = 4.0
	_hub.floor_node.auto_spawn = true
	var counts: Dictionary = {}
	for night: bool in [false, true]:
		_clear_customers()
		_clock.is_night = night
		_shop.is_open = false
		await _frames(2)
		_shop.open_shop()
		var entered: Array = []
		var listener: Callable = func(customer) -> void: entered.append(customer)
		_hub.floor_node.customer_entered.connect(listener)
		await _frames(int(44.0 * 120.0))
		_hub.floor_node.customer_entered.disconnect(listener)
		counts[night] = entered.size()
		_shop.close_shop()
		await _frames(2)
	_clear_customers()
	_hub.floor_node.auto_spawn = false
	_clock.is_night = false
	_check(int(counts[false]) >= 6 and int(counts[true]) >= 1 and float(counts[true]) <= float(counts[false]) * 0.7, "за 44 с днём пришло %d покупателей, ночью %d (поток x%.1f)" % [int(counts[false]), int(counts[true]), _settings.night_traffic_multiplier])
	_shop.reset()


func _stations() -> void:
	print("--- Сундук, справочник, торговец")
	_progress.reset()
	_inventory.clear()
	_shop.reset()
	var item: InventoryItem = InventoryItem.from_weapon(_generator.generate(_rng, 1))
	_inventory.add(item)
	_hub._on_station(K_CHEST)
	await _frames(3)
	_check(_hub.chest_panel.is_open(), "сундук открыл окно")
	_hub.chest_panel._to_chest(item)
	_check(_shop.chest.has(item) and not _inventory.items.has(item), "предмет переехал в сундук")
	_hub.chest_panel._to_backpack(item)
	_check(_inventory.items.has(item) and _shop.chest.is_empty(), "и обратно в рюкзак")
	_hub.chest_panel.close()
	_hub._on_station(K_PRICE_BOOK)
	await _frames(3)
	_check(_hub.price_book_panel.is_open(), "справочник цен открылся")
	var texts: String = ""
	for label in _hub.price_book_panel.find_children("*", "Label", true, false):
		texts += label.text + " "
	var catalog_parts: Array = WeaponCatalog.for_directory(root.get_node("Config").data.weapons.parts_directory).parts
	_check(texts.contains(tr(catalog_parts[0].name_key)) and texts.contains(str(catalog_parts[0].base_price)) and texts.contains("x"), "в справочнике названия и базовые цены частей, множители качества (частей %d)" % catalog_parts.size())
	_hub.price_book_panel.close()
	_hub._on_station(K_TRADER)
	await _frames(3)
	_check(_hub.trader_panel.is_open(), "торговец открыл окно")
	var offer: ShopSlot = _shop.trader_stock[0]
	_progress.add_money(offer.price)
	_hub.trader_panel._buy(0)
	_check(_inventory.items.has(offer.item) and _progress.money == 0 and _shop.trader_stock.size() == _settings.trader_stock_size - 1, "покупка у торговца через окно: оружие в рюкзаке, деньги списаны")
	_hub.trader_panel.close()
	await _frames(3)
	_check(not paused, "окна закрыты: игра снова идёт")
	_inventory.clear()
	_shop.reset()


func _run_door() -> void:
	print("--- Дверь в забег")
	_shop.reset()
	_hub.toggle_shop()
	var item: InventoryItem = _stock(1, 1.0)
	var customer = _hub.floor_node.spawn_customer(_profile_for(item))
	await _until(func() -> bool: return customer.state == S_WAIT_REGISTER, 3000)
	var recorded: Array = []
	_hub.scene_changer = func(path: String) -> void: recorded.append(path)
	var run = root.get_node("Run")
	run.carried_loadout = []
	_hub._on_station(K_RUN_DOOR)
	await _frames(3)
	_check(recorded == ["res://run/run.tscn"], "дверь уводит в сцену забега: %s" % str(recorded))
	_check(not _shop.is_open and _shop.counters[1].item == item and not _shop.counters[1].carried, "уход в забег закрыл магазин и вернул товар покупателя на прилавок")
	_check(run.carried_loadout.size() == _player.get_weapon().slots.size() and run.carried_loadout[0] != null and run.carried_loadout[0].is_eternal, "снаряжение уехало с игроком: стартовый пистолет в слоте 1")
	_clear_customers()
	_shop.reset()


func _lighting() -> void:
	print("--- День и ночь")
	var sun: DirectionalLight3D = _hub.get_node("Sun")
	var lamps: Array = _hub.get_node("Lamps").get_children()
	_hub._apply_phase(true, true)
	_check(is_equal_approx(sun.light_energy, _hub.NIGHT_SUN) and is_equal_approx(lamps[0].light_energy, _hub.NIGHT_LAMPS), "ночью солнце тусклое (%.2f), лампы горят (%.1f)" % [sun.light_energy, lamps[0].light_energy])
	_hub._apply_phase(false, true)
	_check(is_equal_approx(sun.light_energy, _hub.DAY_SUN) and is_equal_approx(lamps[0].light_energy, _hub.DAY_LAMPS), "днём солнце яркое (%.2f), лампы погашены" % sun.light_energy)


func _loadout() -> void:
	print("--- Снаряжение между сценами")
	var weapon = _player.get_weapon()
	var extra: WeaponInstance = _generator.generate(_rng, 1)
	weapon.equip_into(1, extra)
	var snapshot: Array = weapon.export_loadout()
	weapon.slots[1] = null
	weapon.import_loadout(snapshot)
	_check(weapon.slots[1] == extra and weapon.slots[0] != null and weapon.occupied_count() == 2, "снимок снаряжения вернул оба оружия в слоты")
	weapon.import_loadout([])
	_check(weapon.occupied_count() >= 1 and weapon.instance != null, "пустой снимок оставляет игрока с оружием в руках")
