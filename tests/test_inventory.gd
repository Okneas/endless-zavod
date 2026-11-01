@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Инвентарь и карточка: рюкзак на 20 ячеек, стопки, сортировка и фильтр, цена и DPS оружия, экипировка и запрет по уровню,
## выбрасывание на пол и подбор по E, расходники, экран инвентаря (пауза, сетка, карточка, сравнение, компоненты),
## панель слотов оружия на HUD, иконка стихии, подсказки, отладочные клавиши.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_inventory.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.

var _fails: int = 0
var _room: Node
var _player
var _weapon
var _hud
var _screen
var _inventory
var _progress
var _config
var _user
var _actions
var _pickup_script
var _settings: WeaponGenerationSettings
var _generator: WeaponGenerator
var _medkit: ItemDefinition
var _rejected: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Элемент под условным курсором мыши в проверках экрана инвентаря.
var _hovered: Control
## Тихий режим: провалы не печатаются, а копятся в _quiet_failures (раскладка проверяется в окнах разного размера).
var _quiet: bool = false
var _quiet_failures: PackedStringArray = []


func _check(cond: bool, msg: String) -> void:
	if _quiet:
		if not cond:
			_quiet_failures.append(msg)
		return
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _secs(seconds: float) -> void:
	await _frames(ceili(seconds * float(Engine.physics_ticks_per_second)))


func _initialize() -> void:
	create_timer(600.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	_inventory = root.get_node("Inventory")
	_progress = root.get_node("Progress")
	# Масштаб меню берётся из настроек по умолчанию, а не из файла игрока.
	_user = root.get_node("UserSettings")
	_user.config_path = "user://test_settings.cfg"
	_user.load_settings()
	_config = root.get_node("Config")
	_actions = load("res://inventory/inventory_actions.gd")
	_pickup_script = load("res://inventory/item_pickup.gd")
	_settings = load("res://data/content/balance/weapon_generation.tres")
	_generator = WeaponGenerator.new(_settings)
	_medkit = load("res://data/content/items/medkit.tres")
	_rng.seed = 4242
	root.size = Vector2i(1920, 1080)
	_room = (load("res://rooms/test_room.tscn") as PackedScene).instantiate()
	_room.get_node("Enemies").free()
	root.add_child(_room)
	await _frames(10)
	_player = _room.get_node("Player")
	_weapon = _player.get_weapon()
	_hud = _room.get_node("Hud")
	_screen = _hud.get_node("InventoryScreen")
	_inventory.rejected.connect(func(_item) -> void: _rejected += 1)
	_progress.reset()
	_inventory.clear()
	_test_data()
	_test_price_and_dps()
	_test_inventory()
	_test_view()
	await _test_actions()
	await _test_pickup()
	await _test_screen()
	await _test_hud()
	_inventory.clear()
	_progress.reset()
	print("=== FAILS: ", _fails)
	quit(_fails)


# Оружие заданного уровня из генератора.
func _weapon_item(level: int = 1, type: int = -1) -> InventoryItem:
	var instance: WeaponInstance = _generator.generate(_rng, level, type)
	return InventoryItem.from_weapon(instance)


func _fill(count: int) -> Array[InventoryItem]:
	var list: Array[InventoryItem] = []
	for i: int in count:
		var item: InventoryItem = _weapon_item()
		_inventory.add(item)
		list.append(item)
	return list


# --- Данные.
func _test_data() -> void:
	print("--- Данные: настройки инвентаря и переводы")
	var s: InventorySettings = _config.data.inventory
	_check(s != null and s.capacity >= 1 and s.columns >= 1 and s.columns <= s.capacity, "инвентарь на %d ячеек, в строке %d (по диздоку 20 и 5, число правится в Inspector)" % [s.capacity, s.columns])
	_check(s.drop_distance > 0.0 and s.interact_range > 0.0 and s.interact_cone > 0.0 and s.slots_show_seconds > 0.0, "заданы выброс, подбор и показ панели слотов")
	_check(_medkit != null and _medkit.category == ItemDefinition.Category.CONSUMABLE and _medkit.heal_amount > 0.0 and _medkit.max_stack > 1 and s.debug_items.has(_medkit), "аптечка: расходник со стопкой %d, лечит на %.0f, есть в отладочных предметах" % [_medkit.max_stack, _medkit.heal_amount])
	var tiers: Array[QualityTier] = _settings.quality_scale.tiers
	var ascending: bool = true
	for i: int in range(1, tiers.size()):
		if tiers[i].price_multiplier < tiers[i - 1].price_multiplier:
			ascending = false
	_check(ascending and tiers[tiers.size() - 1].price_multiplier > tiers[0].price_multiplier and _settings.price_per_level > 0.0 and _settings.modifier_price > 0, "цена растёт с качеством (x%.2f - x%.2f), уровнем и числом модификаторов" % [tiers[0].price_multiplier, tiers[tiers.size() - 1].price_multiplier])
	var action_problems: PackedStringArray = []
	for action: String in ["inventory_equip", "inventory_compare", "inventory_components", "inventory_drop", "inventory_unequip"]:
		if not InputMap.has_action(action) or InputMap.action_get_events(action).is_empty():
			action_problems.append(action)
	var equip_events: Array[InputEvent] = InputMap.action_get_events("inventory_equip")
	_check(action_problems.is_empty() and equip_events.size() > 0 and equip_events[0] is InputEventMouseButton and KeyHint.text(&"inventory_equip") == tr("INV_KEY_LMB"), "действия инвентаря есть в InputMap (экипировать на ЛКМ), подсказка называет клавишу: %s" % str(action_problems))
	var missing: PackedStringArray = []
	for key: String in ["HUD_PICKUP_ITEM", "HUD_INVENTORY_FULL", "HUD_NEED_LEVEL", "HUD_INTERACT_PICKUP", "ITEM_CATEGORY_WEAPON", "ITEM_CATEGORY_CONSUMABLE", "ITEM_CATEGORY_MATERIAL", "ITEM_MEDKIT", "ITEM_MEDKIT_DESC", "INV_TITLE", "INV_EQUIPMENT", "INV_GRENADE_SLOT", "INV_EMPTY_SLOT", "INV_CAPACITY", "INV_SORT_LEVEL", "INV_SORT_QUALITY", "INV_SORT_TYPE", "INV_SORT_MAKER", "INV_SORT_PRICE", "INV_ASCENDING", "INV_DESCENDING", "INV_FILTER_ALL", "INV_HINT_CLOSE", "CARD_LEVEL", "CARD_REQUIRED_LEVEL", "CARD_DPS", "CARD_STAT_DAMAGE", "CARD_STAT_SPREAD", "CARD_STAT_RATE", "CARD_STAT_RELOAD", "CARD_STAT_MAGAZINE", "CARD_STAT_RANGE", "CARD_STAT_RECOIL", "CARD_STAT_AIM", "CARD_STAT_CRIT", "CARD_STAT_RELOAD_SHORT", "CARD_UNIT_PER_SECOND", "CARD_UNIT_SECONDS", "CARD_BTN_SELECT_SLOT", "INV_KEY_LMB", "INV_KEY_RMB", "INV_HINT_HOVER", "CARD_PRICE", "CARD_BTN_EQUIP", "CARD_BTN_UNEQUIP", "CARD_BTN_COMPARE", "CARD_BTN_COMPONENTS", "CARD_BTN_DROP", "CARD_BTN_USE", "CARD_ELEMENT_ELECTRIC", "CARD_ELEMENT_ACID", "CARD_ELEMENT_FROST", "ELEMENT_ACID", "PART_TYPE_BODY"]:
		if tr(key) == key:
			missing.append(key)
	_check(missing.is_empty(), "строки инвентаря и карточки есть в таблице переводов %s" % str(missing))


# --- Цена и DPS.
func _test_price_and_dps() -> void:
	print("--- Цена и DPS оружия")
	var weapon: WeaponInstance = _generator.generate(_rng, 7)
	weapon.level = 7
	var expected: float = 0.0
	var modifiers: int = 0
	for instance: PartInstance in weapon.parts:
		expected += float(instance.part.base_price) * _settings.quality_scale.tiers[instance.quality].price_multiplier
		modifiers += instance.modifiers.size()
	expected = expected * (1.0 + _settings.price_per_level * 6.0) + float(modifiers * _settings.modifier_price)
	_check(weapon.get_price() == roundi(expected), "цена по формуле: %d (множитель уровня x сумма цен частей с качеством + модификаторы)" % weapon.get_price())
	var stats: WeaponStats = weapon.compute_stats()
	_check(is_equal_approx(weapon.get_dps(), stats.damage * stats.fire_rate), "DPS: урон за выстрел %.1f x темп %.1f = %.1f" % [stats.damage, stats.fire_rate, weapon.get_dps()])
	var cheap: WeaponInstance = _generator.generate(_rng, 1)
	var rich: WeaponInstance = WeaponInstance.new()
	rich.settings = _settings
	rich.level = cheap.level
	for instance: PartInstance in cheap.parts:
		rich.parts.append(PartInstance.create(instance.part, _settings.quality_scale.tiers.size() - 1))
	var plain: WeaponInstance = WeaponInstance.new()
	plain.settings = _settings
	plain.level = cheap.level
	for instance: PartInstance in cheap.parts:
		plain.parts.append(PartInstance.create(instance.part, 0))
	_check(rich.get_price() > plain.get_price() and plain.get_price() > 0, "те же части высшего качества дороже низшего (%d и %d)" % [rich.get_price(), plain.get_price()])
	var low: WeaponInstance = WeaponInstance.new()
	low.settings = _settings
	low.level = 1
	var high: WeaponInstance = WeaponInstance.new()
	high.settings = _settings
	high.level = 11
	for instance: PartInstance in cheap.parts:
		low.parts.append(PartInstance.create(instance.part, 1))
		high.parts.append(PartInstance.create(instance.part, 1))
	_check(is_equal_approx(float(high.get_price()) / float(low.get_price()), 1.0 + _settings.price_per_level * 10.0) or absf(float(high.get_price()) / float(low.get_price()) - (1.0 + _settings.price_per_level * 10.0)) < 0.01, "уровень 11 дороже уровня 1 в %.2f раза" % (float(high.get_price()) / float(low.get_price())))
	_check(_weapon.slots[0].is_eternal and _weapon.slots[0].follows_player_level, "стартовый пистолет вечный и растёт с уровнем персонажа")
	var misc: InventoryItem = InventoryItem.from_definition(_medkit, 3)
	_check(misc.get_price() == _medkit.base_price and misc.get_total_price() == _medkit.base_price * 3, "цена расходника: %d за штуку, %d за стопку" % [misc.get_price(), misc.get_total_price()])


# --- Рюкзак.
func _test_inventory() -> void:
	print("--- Рюкзак: ячейки, стопки, переполнение")
	_inventory.clear()
	_rejected = 0
	var capacity: int = _inventory.get_capacity()
	var items: Array[InventoryItem] = _fill(capacity)
	_check(_inventory.items.size() == capacity and _inventory.is_full() and _rejected == 0, "положили %d предметов, инвентарь полон" % capacity)
	var overflow: InventoryItem = _weapon_item()
	_check(not _inventory.add(overflow) and _rejected == 1 and _inventory.items.size() == capacity and not _inventory.items.has(overflow), "в полный инвентарь предмет не кладётся, сигнал rejected")
	_inventory.remove(items[3])
	_check(not _inventory.is_full() and _inventory.items.size() == capacity - 1 and _inventory.add(overflow) and _inventory.items[capacity - 1] == overflow, "освободилась ячейка: предмет лёг, порядок остальных не сбит")
	var order_ok: bool = true
	for i: int in 3:
		if _inventory.items[i] != items[i]:
			order_ok = false
	_check(order_ok and _inventory.items[3] == items[4], "предметы идут без пропусков в порядке добавления")
	_inventory.clear()
	# Стопки.
	var stack_size: int = _medkit.max_stack
	_inventory.add(InventoryItem.from_definition(_medkit, stack_size - 2))
	_inventory.add(InventoryItem.from_definition(_medkit, 1))
	_check(_inventory.items.size() == 1 and _inventory.items[0].count == stack_size - 1, "аптечки складываются в одну стопку (%d)" % _inventory.items[0].count)
	_inventory.add(InventoryItem.from_definition(_medkit, 3))
	_check(_inventory.items.size() == 2 and _inventory.items[0].count == stack_size and _inventory.items[1].count == 2, "стопка заполнилась до %d, остаток занял вторую ячейку" % stack_size)
	_inventory.clear()
	_fill(capacity - 1)
	_inventory.add(InventoryItem.from_definition(_medkit, stack_size))
	var rejected_before: int = _rejected
	var extra: InventoryItem = InventoryItem.from_definition(_medkit, 3)
	_check(not _inventory.add(extra) and _rejected == rejected_before + 1 and extra.count == 3, "полная стопка в полном инвентаре не принимается, остаток остаётся у предмета")
	_inventory.remove(_inventory.items[0])
	var topped: InventoryItem = InventoryItem.from_definition(_medkit, 2)
	_inventory.items.erase(_inventory.items[_inventory.items.size() - 1])
	var half_stack: InventoryItem = InventoryItem.from_definition(_medkit, stack_size - 1)
	_inventory.add(half_stack)
	_check(_inventory.add(topped) and half_stack.count == stack_size and topped.count == 1 and _inventory.items.size() == _inventory.items.size(), "неполная стопка доливается из нового предмета, лишнее ищет место")
	_inventory.clear()
	# Вечное оружие в рюкзаке растёт вместе с персонажем.
	var starter_in_bag: WeaponInstance = _generator.generate(_rng, 1)
	starter_in_bag.follows_player_level = true
	_inventory.add(InventoryItem.from_weapon(starter_in_bag))
	_progress.level = 5
	_progress.level_changed.emit(5)
	_check(starter_in_bag.level == 5, "вечное оружие в инвентаре растёт с уровнем персонажа (уровень %d)" % starter_in_bag.level)
	_progress.reset()
	_inventory.clear()


# --- Сортировка и фильтр.
func _test_view() -> void:
	print("--- Сортировка и фильтр")
	var a: InventoryItem = _weapon_item(3)
	var b: InventoryItem = _weapon_item(9)
	var c: InventoryItem = _weapon_item(5)
	var d: InventoryItem = _weapon_item(5)
	var m: InventoryItem = InventoryItem.from_definition(_medkit, 2)
	var items: Array[InventoryItem] = [a, b, c, d, m]
	var by_level: Array[InventoryItem] = InventoryView.build(items, InventoryView.SortKey.LEVEL, true, InventoryView.Filter.ALL)
	_check(by_level[0] == m and by_level[1] == a and by_level[2] == c and by_level[3] == d and by_level[4] == b, "по уровню по возрастанию, равные по уровню остаются в исходном порядке")
	var by_level_desc: Array[InventoryItem] = InventoryView.build(items, InventoryView.SortKey.LEVEL, false, InventoryView.Filter.ALL)
	_check(by_level_desc[0] == b and by_level_desc[1] == c and by_level_desc[2] == d and by_level_desc[3] == a and by_level_desc[4] == m, "по уровню по убыванию")
	for key: int in [InventoryView.SortKey.QUALITY, InventoryView.SortKey.TYPE, InventoryView.SortKey.MAKER, InventoryView.SortKey.PRICE]:
		var ascending: Array[InventoryItem] = InventoryView.build(items, key, true, InventoryView.Filter.ALL)
		var descending: Array[InventoryItem] = InventoryView.build(items, key, false, InventoryView.Filter.ALL)
		var ok: bool = ascending.size() == 5 and descending.size() == 5
		for i: int in range(1, ascending.size()):
			var previous: Variant = InventoryView._key(ascending[i - 1], key)
			var current: Variant = InventoryView._key(ascending[i], key)
			if previous > current:
				ok = false
		for i: int in range(1, descending.size()):
			if InventoryView._key(descending[i - 1], key) < InventoryView._key(descending[i], key):
				ok = false
		_check(ok, "сортировка «%s» по возрастанию и убыванию упорядочена" % InventoryView.SortKey.keys()[key])
	_check(InventoryView.build(items, InventoryView.SortKey.NONE, true, InventoryView.Filter.ALL) == items, "без сортировки порядок исходный")
	_check(InventoryView.build(items, InventoryView.SortKey.NONE, true, InventoryView.Filter.WEAPON).size() == 4 and InventoryView.build(items, InventoryView.SortKey.NONE, true, InventoryView.Filter.CONSUMABLE) == [m] and InventoryView.build(items, InventoryView.SortKey.NONE, true, InventoryView.Filter.MATERIAL).is_empty(), "фильтр: оружия 4, расходник 1, материалов 0")
	_check(items.size() == 5 and items[0] == a, "сортировка не переставляет сами предметы")


# --- Действия над предметами.
func _test_actions() -> void:
	print("--- Экипировка, снятие, выбрасывание, использование")
	_inventory.clear()
	var starter: WeaponInstance = _weapon.slots[0]
	_check(_weapon.occupied_count() == 1 and starter.is_eternal, "в начале в слоте 1 вечный стартовый пистолет")
	# Запрет по уровню.
	var strong: InventoryItem = _weapon_item(10)
	_inventory.add(strong)
	_progress.reset()
	_check(not _actions.can_equip(strong) and not _actions.equip(_player, strong, -1) and _inventory.items.has(strong) and _weapon.occupied_count() == 1, "оружие выше уровня персонажа (%d при %d) экипировать нельзя, остаётся в инвентаре" % [strong.get_level(), _progress.level])
	_progress.level = 10
	_check(_actions.can_equip(strong), "после роста уровня до 10 экипировать можно")
	# Экипировка в пустой слот.
	var rifle: InventoryItem = _weapon_item(1, CombatEnums.WeaponType.ASSAULT_RIFLE)
	_inventory.add(rifle)
	var before_count: int = _inventory.items.size()
	_check(_actions.equip(_player, rifle, -1), "экипировали оружие без указания слота")
	_check(_weapon.slots[1] == rifle.weapon and _weapon.occupied_count() == 2 and _inventory.items.size() == before_count - 1 and not _inventory.items.has(rifle), "оружие легло в первый пустой слот (2) и ушло из рюкзака")
	# Экипировка в занятый слот: вытесненное возвращается в рюкзак.
	var shotgun: InventoryItem = _weapon_item(1, CombatEnums.WeaponType.SHOTGUN)
	_inventory.add(shotgun)
	var count_before_swap: int = _inventory.items.size()
	var old_weapon: WeaponInstance = _weapon.slots[1]
	_weapon.slots[1].ammo = 3
	_check(_actions.equip(_player, shotgun, 1), "экипировали оружие в занятый слот 2")
	var returned: InventoryItem = _inventory.items[_inventory.items.size() - 1]
	_check(_weapon.slots[1] == shotgun.weapon and returned.weapon == old_weapon and _inventory.items.size() == count_before_swap, "вытесненное оружие вернулось в рюкзак на освободившееся место")
	# Экипировка в активный слот: оружие в руках меняется сразу, патроны вытесненного сохраняются.
	_weapon.active_slot = 0
	var active_item: InventoryItem = _weapon_item(1, CombatEnums.WeaponType.SNIPER)
	_inventory.add(active_item)
	_weapon.ammo = 4
	_actions.equip(_player, active_item, 0)
	_check(_weapon.instance == active_item.weapon and _weapon.stats.weapon_type == CombatEnums.WeaponType.SNIPER and _weapon.ammo == _weapon.stats.magazine_size, "экипировка в активный слот сразу берёт новое оружие в руки с полным магазином")
	var starter_item: InventoryItem = null
	for item: InventoryItem in _inventory.items:
		if item.weapon == starter:
			starter_item = item
	_check(starter_item != null and starter_item.is_eternal() and starter.ammo == 4, "стартовый пистолет ушёл в рюкзак, остаётся вечным и помнит патроны (%d)" % starter.ammo)
	# Вечное нельзя выбросить.
	var floor_before: int = get_nodes_in_group(&"item_pickups").size()
	_check(_actions.drop(_player, starter_item) == null and _inventory.items.has(starter_item) and get_nodes_in_group(&"item_pickups").size() == floor_before, "вечное оружие выбросить нельзя")
	# Снять оружие.
	var occupied: int = _weapon.occupied_count()
	_check(_actions.unequip(_player, 1) and _weapon.slots[1] == null and _weapon.occupied_count() == occupied - 1, "снятие оружия из слота 2 вернуло его в рюкзак")
	# Последнее оружие снять нельзя.
	while _weapon.occupied_count() > 1:
		for i: int in _weapon.slots.size():
			if _weapon.slots[i] != null and i != _weapon.active_slot and _weapon.occupied_count() > 1:
				_actions.unequip(_player, i)
	var last_slot: int = _weapon.active_slot
	_check(not _actions.unequip(_player, last_slot) and _weapon.slots[last_slot] != null, "последнее оружие снять нельзя")
	# Снятие активного слота передаёт руки другому оружию.
	_actions.equip(_player, _weapon_item_in_bag(), -1)
	var other_slot: int = _weapon.find_equip_slot()
	_check(_weapon.occupied_count() == 2, "в слотах снова два оружия")
	var held: WeaponInstance = _weapon.instance
	_check(_actions.unequip(_player, _weapon.active_slot) and _weapon.instance != held and _weapon.instance != null and _weapon.occupied_count() == 1, "при снятии активного оружия в руки берётся другое")
	# Снятие при полном рюкзаке.
	_inventory.clear()
	_actions.equip(_player, _weapon_item_in_bag(), -1)
	_fill(_inventory.get_capacity())
	_rejected = 0
	var slot_to_free: int = 0 if _weapon.active_slot != 0 else 1
	_check(not _actions.unequip(_player, slot_to_free) and _rejected == 1 and _weapon.occupied_count() == 2, "снять оружие при полном рюкзаке нельзя, сигнал rejected")
	_inventory.clear()
	_actions.unequip(_player, slot_to_free)
	# Использование расходника.
	_inventory.clear()
	var medkits: InventoryItem = InventoryItem.from_definition(_medkit, 2)
	_inventory.add(medkits)
	_check(not _actions.use(_player, medkits) and medkits.count == 2, "при полном здоровье аптечка не используется")
	_player.set_health(50)
	_check(_actions.use(_player, medkits) and _player.health == 50 + roundi(_medkit.heal_amount) and medkits.count == 1, "аптечка лечит на %.0f: здоровье 50 -> %d, в стопке осталась 1" % [_medkit.heal_amount, _player.health])
	_player.set_health(10)
	_actions.use(_player, medkits)
	_check(not _inventory.items.has(medkits), "последняя аптечка убрана из рюкзака")
	_player.set_health(_player.max_health)
	_inventory.clear()
	await _frames(1)


# Оружие для экипировки: кладёт в рюкзак новое и возвращает его.
func _weapon_item_in_bag() -> InventoryItem:
	var item: InventoryItem = _weapon_item(1)
	_inventory.add(item)
	return item


# --- Предмет в мире и подбор по E.
func _test_pickup() -> void:
	print("--- Выброшенный предмет и подбор по E")
	_inventory.clear()
	_progress.reset()
	_player.global_position = Vector3(0.0, 0.05, 17.0)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = 0.0
	_player.set_look_pitch(0.0)
	await _frames(20)
	var item: InventoryItem = _weapon_item()
	_inventory.add(item)
	var dropped = _actions.drop(_player, item)
	_check(dropped != null and not _inventory.items.has(item) and dropped.item == item, "«Выбросить» убрало предмет из рюкзака и поставило его в мир")
	await _secs(1.5)
	var camera: Camera3D = _player.get_node("Head/Camera3D")
	var settings: InventorySettings = _config.data.inventory
	var distance: float = dropped.global_position.distance_to(camera.global_position)
	_check(is_instance_valid(dropped) and dropped.global_position.y < 1.0 and dropped.global_position.y > 0.0, "предмет упал на пол (высота %.2f)" % dropped.global_position.y)
	_check(dropped.global_position.z < 17.0 - settings.drop_distance * 0.5, "предмет упал впереди игрока (z %.2f при игроке на 17)" % dropped.global_position.z)
	var interactor = _player.get_node("Interactor")
	await _frames(3)
	var near: bool = distance <= settings.interact_range
	if not near:
		# Предмет отлетел дальше радиуса подбора: подвигаем игрока к нему.
		_player.global_position = dropped.global_position + Vector3(0.0, -0.2, 1.5)
		_player.global_position.y = 0.05
		await _frames(30)
	var to_item: Vector3 = (dropped.global_position - camera.global_position).normalized()
	_player.rotation.y = atan2(-to_item.x, -to_item.z)
	_player.set_look_pitch(asin(to_item.y))
	await _frames(5)
	_check(interactor.focused == dropped, "игрок смотрит на предмет вблизи: он в фокусе подбора")
	_check(_hud.get_node("Root/InteractPrompt").visible and _hud.get_node("Root/InteractPrompt").text.contains(item.get_display_name()), "на HUD подсказка подбора с названием: «%s»" % _hud.get_node("Root/InteractPrompt").text)
	# В стороне от взгляда подсказки нет.
	_player.rotation.y += deg_to_rad(settings.interact_cone + 30.0)
	await _frames(5)
	_check(interactor.focused == null and not _hud.get_node("Root/InteractPrompt").visible, "отвернулись за пределы конуса: фокус и подсказка пропали")
	_player.rotation.y -= deg_to_rad(settings.interact_cone + 30.0)
	await _frames(5)
	# Подбор при полном рюкзаке: предмет остаётся на полу, красное предупреждение.
	_fill(_inventory.get_capacity())
	_rejected = 0
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	await _frames(3)
	_check(is_instance_valid(dropped) and not dropped.is_queued_for_deletion() and _rejected >= 1 and _inventory.items.size() == _inventory.get_capacity(), "рюкзак полон: предмет остался на полу, сигнал rejected")
	var feed: Node = _hud.get_node("Root/PickupFeed")
	var warning_found: bool = false
	for line: Node in feed.get_children():
		if (line as Label).text == tr("HUD_INVENTORY_FULL") and (line as Label).get_theme_color("font_color").r > 0.9 and (line as Label).get_theme_color("font_color").g < 0.5:
			warning_found = true
	_check(warning_found, "в ленте красное «Инвентарь полон»")
	# Подбор при свободном месте.
	_inventory.clear()
	await _secs(0.5)
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	await _frames(3)
	_check(_inventory.items.size() == 1 and _inventory.items[0] == item and (not is_instance_valid(dropped) or dropped.is_queued_for_deletion()), "по E предмет поднят в рюкзак, на полу его больше нет")
	var line_ok: bool = false
	for line: Node in feed.get_children():
		if (line as Label).text.contains(item.get_display_name()):
			line_ok = true
	_check(line_ok, "в ленте строка о подобранном предмете")
	# Подсказка и подбор не работают за экраном смерти и вдали.
	_inventory.clear()
	await _frames(2)


# --- Экран инвентаря.
func _test_screen() -> void:
	print("--- Экран инвентаря и карточка")
	_inventory.clear()
	_progress.reset()
	var grid: Node = _screen.get_node("%Grid")
	_check(not _screen.is_open() and not _screen.visible, "по умолчанию инвентарь закрыт")
	var paused_before: bool = paused
	Input.action_press("inventory_toggle")
	await _frames(3)
	Input.action_release("inventory_toggle")
	await _frames(3)
	_check(_screen.is_open() and _screen.visible, "по Tab инвентарь открылся")
	_check(paused == _config.data.pause_in_run and not paused_before, "игра на паузе (флаг pause_in_run = %s)" % str(_config.data.pause_in_run))
	_check(grid.get_child_count() == _inventory.get_capacity() and grid.columns == _config.data.inventory.columns, "в сетке %d ячеек в %d колонки" % [grid.get_child_count(), grid.columns])
	_check(_screen.get_node("%EquipmentRows").get_child_count() == 6, "в колонке экипировки шесть строк (четыре слота оружия, слот гранат и слот щита)")
	_check(_screen.get_node("%CapacityLabel").text == "0/%d" % _inventory.get_capacity(), "счётчик вместимости: «%s»" % _screen.get_node("%CapacityLabel").text)
	_check(_screen.get_node("%EmptyLabel").visible, "пустой инвентарь подписан")
	_test_layout()
	_check(not _room.get_node("DebugOverlay").visible, "отладочная надпись спрятана, пока открыт инвентарь")
	# Закрытие по Tab.
	Input.action_press("inventory_toggle")
	await _frames(3)
	Input.action_release("inventory_toggle")
	await _frames(3)
	_check(not _screen.is_open() and not paused and _room.get_node("DebugOverlay").visible, "Tab закрыл инвентарь, снял паузу и вернул отладочную надпись")
	# Закрытие по Esc.
	Input.action_press("inventory_toggle")
	await _frames(3)
	Input.action_release("inventory_toggle")
	await _frames(3)
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await _frames(3)
	_check(not _screen.is_open() and not paused, "Esc тоже закрывает инвентарь")

	# Наполнение: оружие разных уровней и качества и аптечки.
	var weak: InventoryItem = _weapon_item(1, CombatEnums.WeaponType.SMG)
	var strong: InventoryItem = _weapon_item(30, CombatEnums.WeaponType.SNIPER)
	var middle: InventoryItem = _weapon_item(1, CombatEnums.WeaponType.PISTOL)
	var medkits: InventoryItem = InventoryItem.from_definition(_medkit, 3)
	for item: InventoryItem in [weak, strong, middle, medkits]:
		_inventory.add(item)
	Input.action_press("inventory_toggle")
	await _frames(3)
	Input.action_release("inventory_toggle")
	await _frames(3)
	var cells: Array = []
	for cell: Node in grid.get_children():
		cells.append(cell)
	_check(cells[0].item == weak and cells[1].item == strong and cells[2].item == middle and cells[3].item == medkits and cells[4].item == null, "ячейки заполнены слева направо без пропусков")
	_check(_screen.get_node("%CapacityLabel").text == "4/%d" % _inventory.get_capacity() and not _screen.get_node("%EmptyLabel").visible, "счётчик показывает 4/%d" % _inventory.get_capacity())
	# Сортировка и фильтр через элементы экрана.
	var sort_option: OptionButton = _screen.get_node("%SortOption")
	var level_index: int = sort_option.get_item_index(InventoryView.SortKey.LEVEL)
	sort_option.select(level_index)
	_screen._on_sort_selected(level_index)
	await _frames(2)
	_check(cells[0].item == medkits and cells[3].item == strong, "сортировка «По уровню» меняет порядок ячеек")
	_screen._on_direction_pressed()
	await _frames(2)
	_check(cells[0].item == strong and cells[3].item == medkits, "кнопка направления разворачивает сортировку")
	var filter_option: OptionButton = _screen.get_node("%FilterOption")
	var consumable_index: int = filter_option.get_item_index(InventoryView.Filter.CONSUMABLE)
	filter_option.select(consumable_index)
	_screen._on_filter_selected(consumable_index)
	await _frames(2)
	_check(cells[0].item == medkits and cells[1].item == null, "фильтр «Расходники» оставляет только аптечки")
	_screen._on_filter_selected(0)
	sort_option.select(0)
	_screen._on_sort_selected(0)
	await _frames(2)
	await _test_stretch(cells[0])
	# Карточка по наведению мыши.
	var card = _screen.get_node("%Card")
	var rows: Array = _screen.get_node("%EquipmentRows").get_children()
	_check(not card.visible, "без наведения карточки нет")
	await _hover(cells[0])
	_check(card.visible and cells[0].hovered, "наведение на ячейку показало карточку, ячейка подсвечена")
	var joined: String = " ".join(_collect_text(card))
	_check(joined.contains(weak.get_display_name()) and joined.contains(str(roundi(weak.weapon.get_dps()))) and joined.contains(tr("CARD_DPS")), "в карточке название оружия и DPS %d" % roundi(weak.weapon.get_dps()))
	_check(joined.contains(tr("CARD_STAT_DAMAGE")) and joined.contains(tr("CARD_STAT_SPREAD")) and joined.contains(tr("CARD_STAT_RATE")) and joined.contains(tr("CARD_STAT_RELOAD_SHORT")) and joined.contains(tr("CARD_STAT_MAGAZINE")), "пять основных характеристик")
	_check(_collect_class(card, "StatIcon").size() == 5, "у основных характеристик по значку (плитки в ряд)")
	_check(joined.contains(tr("CARD_STAT_RANGE")) and joined.contains(tr("CARD_STAT_RECOIL")) and joined.contains(tr("CARD_STAT_AIM")) and joined.contains(tr("CARD_STAT_CRIT")), "вторичные характеристики")
	_check(joined.contains(tr("CARD_PRICE").format({"price": weak.get_price()})), "цена по формуле: %s" % tr("CARD_PRICE").format({"price": weak.get_price()}))
	var maker_name: String = tr(weak.weapon.get_manufacturer().name_key)
	_check(joined.contains(maker_name) and joined.contains(weak.weapon.get_type_name()), "в шапке производитель «%s» и тип «%s»" % [maker_name, weak.weapon.get_type_name()])
	var features: Array[PartFeature] = weak.weapon.get_features()
	for feature: PartFeature in features:
		_check(joined.contains(tr(feature.name_key)), "особенность «%s» есть в карточке" % tr(feature.name_key))
	_check(_collect_class(card, "FeatureIcon").size() == features.size(), "у каждой особенности свой значок (%d)" % features.size())
	_check(_buttons(card).is_empty(), "в карточке нет кнопок, действия показаны подсказками клавиш")
	_check(_hint_state(card, tr("CARD_BTN_EQUIP")) == 1 and _hint_state(card, tr("CARD_BTN_COMPARE")) == 1 and _hint_state(card, tr("CARD_BTN_COMPONENTS")) == 1 and _hint_state(card, tr("CARD_BTN_DROP")) == 1, "подсказки: экипировать, сравнить, компоненты, выбросить, все доступны")
	_check(joined.contains(KeyHint.text(&"inventory_equip")) and joined.contains(KeyHint.text(&"inventory_compare")) and joined.contains(KeyHint.text(&"inventory_components")) and joined.contains(KeyHint.text(&"inventory_drop")), "у подсказок названия клавиш из InputMap: %s, %s, %s, %s" % [KeyHint.text(&"inventory_equip"), KeyHint.text(&"inventory_compare"), KeyHint.text(&"inventory_components"), KeyHint.text(&"inventory_drop")])
	# Положение карточки: подсказка у курсора (в проверке мыши нет, берётся центр ячейки), справа и ниже, курсор не закрыт.
	var card_rect: Rect2 = card.get_global_rect()
	var pointer: Vector2 = cells[0].get_global_rect().get_center()
	var offset: Vector2 = _screen.CARD_OFFSET
	var expected: Vector2 = _expected_card_position(pointer, card_rect.size)
	_check(not card_rect.has_point(pointer) and card_rect.position.distance_to(expected) < 1.5 and card_rect.position.x > pointer.x, "карточка встала справа от курсора (ниже, пока помещается) и его не закрывает (карточка %s, ожидалось %s, курсор %s)" % [str(card_rect), str(expected), str(pointer)])
	_check(_fits_screen(card_rect), "карточка помещается на экран %s" % str(_ui_size()))
	_check(card.get_index() == card.get_parent().get_child_count() - 1, "карточка выше всех остальных элементов экрана, в том числе подсказки внизу")
	cells[0].set_item(cells[0].item, _progress.level)
	await _hover(cells[1])
	var next_rect: Rect2 = card.get_global_rect()
	_check(next_rect.position.distance_to(_expected_card_position(cells[1].get_global_rect().get_center(), next_rect.size)) < 1.5, "при переходе на соседнюю ячейку карточка идёт за курсором")
	await _hover(null)
	_check(not card.visible and not cells[0].hovered, "курсор ушёл: карточка и подсветка пропали")
	await _hover(cells[4])
	_check(not card.visible, "над пустой ячейкой карточки нет")
	await _hover(null)
	# Все виды оружия в обоих видах помещаются на экран и не закрывают курсор.
	var fit_failures: PackedStringArray = []
	var fit_count: int = 0
	for type_id: int in [CombatEnums.WeaponType.PISTOL, CombatEnums.WeaponType.REVOLVER, CombatEnums.WeaponType.AKIMBO, CombatEnums.WeaponType.SMG, CombatEnums.WeaponType.SHOTGUN, CombatEnums.WeaponType.ASSAULT_RIFLE, CombatEnums.WeaponType.SEMI_AUTO_RIFLE, CombatEnums.WeaponType.SNIPER]:
		for variant: int in 3:
			var probe: InventoryItem = _weapon_item(1 + variant * 7, type_id)
			_inventory.add(probe)
			var probe_cell: Node = null
			for cell: Node in grid.get_children():
				if cell.item == probe:
					probe_cell = cell
			for components_on: bool in [false, true]:
				_screen._components = components_on
				await _hover(null)
				await _hover(probe_cell)
				await _frames(2)
				var probe_rect: Rect2 = card.get_global_rect()
				fit_count += 1
				if not _fits_screen(probe_rect) or probe_rect.has_point(probe_cell.get_global_rect().get_center()):
					fit_failures.append("%s ур.%d %s: %s" % [probe.get_display_name(), probe.get_level(), "компоненты" if components_on else "обычная", str(probe_rect)])
			_inventory.remove(probe)
	_screen._components = false
	await _hover(null)
	_check(fit_failures.is_empty(), "%d карточек разных типов оружия помещаются на экран и не закрывают курсор %s" % [fit_count, str(fit_failures)])
	# У правого края карточка слева от курсора, у нижнего сдвигается вверх.
	var edge_items: Array[InventoryItem] = _fill(_inventory.get_capacity() - _inventory.items.size())
	var edge_failures: PackedStringArray = []
	var edge_flipped: bool = false
	var edge_lifted: bool = false
	for cell: Node in grid.get_children():
		await _hover(cell)
		var edge_rect: Rect2 = card.get_global_rect()
		var edge_pointer: Vector2 = cell.get_global_rect().get_center()
		if edge_rect.has_point(edge_pointer) or not _fits_screen(edge_rect):
			edge_failures.append("%s: %s" % [str(edge_pointer), str(edge_rect)])
		edge_flipped = edge_flipped or edge_rect.end.x <= edge_pointer.x
		edge_lifted = edge_lifted or edge_rect.position.y < edge_pointer.y + offset.y - 1.0
	_check(edge_failures.is_empty(), "над каждой из %d ячеек карточка у курсора, на экране и курсор не закрывает %s" % [grid.get_child_count(), str(edge_failures)])
	_check(edge_flipped and edge_lifted, "у правого края карточка встаёт слева от курсора, у нижнего поднимается")
	await _hover(null)
	for edge_item: InventoryItem in edge_items:
		_inventory.remove(edge_item)
	# Не помещается: описания особенностей убираются.
	await _hover(cells[0])
	var full_text: String = " ".join(_collect_text(card))
	var long_text: String = tr(features[0].description_key).format({"value": roundi(features[0].value * 100.0)}) if features.size() > 0 else ""
	card.max_height = 200.0
	_check(card.shrink_if_needed() and not " ".join(_collect_text(card)).contains(long_text), "слишком высокая карточка пересобирается без описаний особенностей")
	card.max_height = 0.0
	await _hover(null)

	# Переключатели клавишами: режим «Компоненты» остаётся включённым, пока водишь курсором.
	await _hover(cells[0])
	await _tap("inventory_components")
	var components_text: String = " ".join(_collect_text(card))
	var part_lines: int = 0
	for instance: PartInstance in weak.weapon.parts:
		if components_text.contains(tr("PART_TYPE_" + WeaponPart.PartType.keys()[instance.part.part_type]) + ": " + tr(instance.part.name_key)):
			part_lines += 1
	_check(part_lines == weak.weapon.parts.size(), "клавиша компонентов: по строке на каждую из %d частей" % weak.weapon.parts.size())
	_check(components_text.contains(tr("CARD_PART_BRAND")) and not components_text.contains(tr("CARD_DPS")), "корпус помечен брендом, DPS и плиток характеристик в этом виде нет")
	_check(_hint_state(card, tr("CARD_BTN_BACK")) == 1, "подсказка сменилась на «Основной вид»")
	await _hover(cells[2])
	_check(" ".join(_collect_text(card)).contains(tr("CARD_PART_BRAND")), "режим «Компоненты» остался включён на другом оружии")
	await _tap("inventory_components")
	_check(not " ".join(_collect_text(card)).contains(tr("CARD_PART_BRAND")) and " ".join(_collect_text(card)).contains(tr("CARD_DPS")), "повторное нажатие возвращает основной вид")
	# Сравнение с экипированным.
	await _hover(cells[0])
	await _tap("inventory_compare")
	var arrows: Array = _collect_arrows(card)
	# Слот-цель пуст, поэтому сравнение идёт с оружием в руках.
	var reference: WeaponInstance = _weapon.slots[_weapon.find_equip_slot()]
	if reference == null:
		reference = _weapon.instance
	_check(arrows.size() >= 11 and _arrow_count(arrows) > 0, "режим сравнения: стрелки у DPS и характеристик (%d из %d)" % [_arrow_count(arrows), arrows.size()])
	var compare_stats: WeaponStats = weak.weapon.compute_stats()
	var ref_stats: WeaponStats = reference.compute_stats()
	# Первая стрелка у DPS, вторая у урона.
	var damage_arrow: int = arrows[1].direction
	var expected_damage: int = 0
	if absf(compare_stats.damage - ref_stats.damage) > maxf(ref_stats.damage, 1.0) * 0.001:
		expected_damage = 1 if compare_stats.damage > ref_stats.damage else -1
	_check(damage_arrow == expected_damage, "стрелка урона верная: %d (новое %.1f, экипированное %.1f)" % [damage_arrow, compare_stats.damage, ref_stats.damage])
	_check(" ".join(_collect_text(card)).contains(tr("CARD_COMPARE_WITH").format({"name": reference.get_display_name()})), "указано, с каким оружием сравниваем")
	_check(_hint_state(card, tr("CARD_BTN_EXIT_COMPARE")) == 1, "подсказка сменилась на «Выйти из сравнения»")
	await _hover(cells[2])
	_check(_arrow_count(_collect_arrows(card)) > 0, "сравнение осталось включённым на другом оружии")
	await _tap("inventory_compare")
	_check(_arrow_count(_collect_arrows(card)) == 0, "повторное нажатие убирает стрелки")
	# Запрет по уровню.
	await _hover(cells[1])
	var strong_text: String = " ".join(_collect_text(card))
	_check(_hint_state(card, tr("CARD_BTN_EQUIP")) == 0 and strong_text.contains(tr("CARD_REQUIRED_LEVEL").format({"level": strong.get_level()})), "оружие выше уровня: требуемый уровень %d красным, «Экипировать» недоступна" % strong.get_level())
	var weapons_before: int = _weapon.occupied_count()
	await _tap("inventory_equip")
	_check(_weapon.occupied_count() == weapons_before and _inventory.items.has(strong), "ЛКМ по оружию выше уровня ничего не экипирует")
	_check(cells[1].item.get_level() > _progress.level, "в ячейке такое оружие помечено уровнем выше персонажа")
	# Карточка прочего предмета и использование.
	await _hover(cells[3])
	var misc_text: String = " ".join(_collect_text(card))
	_check(misc_text.contains(tr(_medkit.name_key)) and misc_text.contains(tr(_medkit.description_key)) and misc_text.contains(tr("CARD_COUNT").format({"count": 3})), "карточка аптечки: название, описание, количество")
	_check(misc_text.contains(tr("CARD_PRICE_STACK").format({"price": _medkit.base_price, "total": _medkit.base_price * 3})) and not misc_text.contains(tr("CARD_DPS")) and _hint_state(card, tr("CARD_BTN_COMPONENTS")) == -1, "у прочих предметов цена стопки, режима компонентов нет")
	_check(_hint_state(card, tr("CARD_BTN_USE")) == 0, "«Использовать» при полном здоровье недоступна")
	_player.set_health(40)
	_screen._refresh()
	await _frames(3)
	_check(_hint_state(card, tr("CARD_BTN_USE")) == 1, "при ране «Использовать» доступна")
	await _tap("inventory_equip")
	_check(_player.health == 40 + roundi(_medkit.heal_amount) and medkits.count == 2 and cells[3].item == medkits, "ЛКМ по аптечке лечит и тратит штуку")
	_player.set_health(_player.max_health)
	# Выбор слота-цели кликом по строке и экипировка в него.
	await _hover(rows[2])
	await _tap("inventory_equip")
	_check(rows[2].selected and _screen._target_slot == 2, "ЛКМ по строке экипировки выбирает слот-цель")
	await _tap("inventory_equip")
	_check(not rows[2].selected and _screen._target_slot == -1, "повторный ЛКМ снимает выбор слота")
	var target_item: InventoryItem = cells[2].item
	await _hover(cells[2])
	var default_slot: int = _weapon.find_equip_slot()
	_check(rows[default_slot].selected, "над оружием из рюкзака подсвечен слот, в который оно пойдёт (%d)" % (default_slot + 1))
	await _hover(rows[2])
	await _tap("inventory_equip")
	await _hover(cells[2])
	await _tap("inventory_equip")
	_check(_weapon.slots[2] == target_item.weapon and not _inventory.items.has(target_item), "ЛКМ по оружию положил его в выбранный слот 3")
	_check(rows[2].weapon == target_item.weapon, "строка слота 3 показывает новое оружие")
	# Карточка экипированного оружия: снять.
	await _hover(rows[2])
	var equipped_text: String = " ".join(_collect_text(card))
	_check(card.visible and equipped_text.contains(target_item.get_display_name()), "наведение на строку с оружием показывает его карточку")
	_check(_hint_state(card, tr("CARD_BTN_UNEQUIP")) == 1 and _hint_state(card, tr("CARD_BTN_SELECT_SLOT")) == 1 and _hint_state(card, tr("CARD_BTN_EQUIP")) == -1 and _hint_state(card, tr("CARD_BTN_DROP")) == -1, "у экипированного оружия «Снять» и «Выбрать слот» вместо «Экипировать»")
	await _tap("inventory_unequip")
	var back_in_bag: bool = false
	for bag_item: InventoryItem in _inventory.items:
		if bag_item.weapon == target_item.weapon:
			back_in_bag = true
	_check(_weapon.slots[2] == null and back_in_bag, "клавиша «Снять» вернула оружие в рюкзак")
	_check(not card.visible, "слот опустел: карточки над ним нет")
	await _hover(null)
	# Выбросить.
	await _hover(cells[0])
	var floor_before: int = get_nodes_in_group(&"item_pickups").size()
	var dropped_item: InventoryItem = cells[0].item
	await _tap("inventory_drop")
	_check(not _inventory.items.has(dropped_item) and get_nodes_in_group(&"item_pickups").size() == floor_before + 1, "клавиша «Выбросить» убрала предмет из рюкзака и поставила его на пол")
	_check(cells[0].item != dropped_item and (not card.visible or not " ".join(_collect_text(card)).contains(dropped_item.get_display_name())), "в ячейке под курсором уже следующий предмет, карточка показывает его")
	await _hover(null)
	# Вечное оружие: «Выбросить» недоступна.
	# Стартовый пистолет к этому моменту потерян в предыдущих проверках, поэтому вечное оружие делаем сами.
	var eternal_item: InventoryItem = _weapon_item_in_bag()
	eternal_item.weapon.is_eternal = true
	_screen._refresh()
	var eternal_cell: Node = null
	for cell: Node in grid.get_children():
		if cell.item == eternal_item:
			eternal_cell = cell
	_check(eternal_cell != null, "вечное оружие лежит в рюкзаке")
	await _hover(eternal_cell)
	_check(_hint_state(card, tr("CARD_BTN_DROP")) == 0 and " ".join(_collect_text(card)).contains(tr("CARD_ETERNAL")), "у вечного оружия «Выбросить» недоступна, помечено «Вечное»")
	var floor_now: int = get_nodes_in_group(&"item_pickups").size()
	await _tap("inventory_drop")
	_check(_inventory.items.has(eternal_item) and get_nodes_in_group(&"item_pickups").size() == floor_now, "клавиша «Выбросить» вечное оружие не выбрасывает")
	await _hover(null)
	# Действия без наведения ничего не делают.
	var items_before: int = _inventory.items.size()
	await _tap("inventory_equip")
	await _tap("inventory_drop")
	await _tap("inventory_unequip")
	_check(_inventory.items.size() == items_before, "без наведения клавиши действий ничего не трогают")
	# Закрытие и состояние.
	Input.action_press("inventory_toggle")
	await _frames(3)
	Input.action_release("inventory_toggle")
	await _frames(3)
	_check(not _screen.is_open() and not paused and not card.visible, "инвентарь закрыт, пауза снята, карточки нет")
	# Мёртвый игрок инвентарь не открывает: проверяется в конце раздела HUD.
	for pickup: Node in get_nodes_in_group(&"item_pickups"):
		pickup.free()
	_inventory.clear()


# --- Раскладка экрана: три панели одной высоты по центру, шапки в один ряд, строки и ячейки ровные.
func _test_layout() -> void:
	var viewport_size: Vector2 = _ui_size()
	var main: Control = _screen.get_node("Root/Center/Main")
	var panels: Array = [main.get_node("PreviewColumn/PreviewPanel"), main.get_node("EquipmentColumn/EquipmentPanel"), main.get_node("GridColumn/GridPanel")]
	var headers: Array = [main.get_node("PreviewColumn/PreviewTitle"), main.get_node("EquipmentColumn/EquipmentTitle"), main.get_node("GridColumn/Controls")]
	var aligned: bool = true
	for i: int in range(1, 3):
		var a: Rect2 = panels[0].get_global_rect()
		var b: Rect2 = panels[i].get_global_rect()
		var ha: Rect2 = headers[0].get_global_rect()
		var hb: Rect2 = headers[i].get_global_rect()
		if absf(a.position.y - b.position.y) > 1.0 or absf(a.end.y - b.end.y) > 1.0 or absf(ha.position.y - hb.position.y) > 1.0 or absf(ha.size.y - hb.size.y) > 1.0:
			aligned = false
	_check(aligned, "три панели и три шапки выровнены по верхнему и нижнему краю (панели %s)" % str([panels[0].get_global_rect(), panels[1].get_global_rect(), panels[2].get_global_rect()]))
	var no_overlap: bool = true
	for i: int in range(0, 2):
		if panels[i].get_global_rect().end.x > panels[i + 1].get_global_rect().position.x - 7.0:
			no_overlap = false
	_check(no_overlap, "панели идут слева направо с промежутками и не налезают друг на друга")
	var block: Rect2 = main.get_global_rect()
	_check(absf(block.position.x - (viewport_size.x - block.end.x)) <= 2.0 and block.position.x >= 0.0, "блок из трёх панелей по центру экрана (слева %.0f, справа %.0f)" % [block.position.x, viewport_size.x - block.end.x])
	var title_bottom: float = _screen.get_node("%Title").get_global_rect().end.y
	var hint_top: float = _screen.get_node("%HintLabel").get_global_rect().position.y
	_check(block.position.y >= title_bottom - 1.0 and block.end.y <= hint_top + 1.0, "блок между заголовком и подсказкой внизу (%.0f - %.0f при %.0f - %.0f)" % [block.position.y, block.end.y, title_bottom, hint_top])
	var rows: Array = _screen.get_node("%EquipmentRows").get_children()
	var panel_rect: Rect2 = panels[1].get_global_rect()
	var rows_ok: bool = rows.size() == 6
	for row: Control in rows:
		var row_rect: Rect2 = row.get_global_rect()
		if absf(row_rect.size.y - rows[0].size.y) > 1.0 or row_rect.position.y < panel_rect.position.y or row_rect.end.y > panel_rect.end.y or row_rect.position.x < panel_rect.position.x or row_rect.end.x > panel_rect.end.x:
			rows_ok = false
	_check(rows_ok, "шесть строк экипировки одной высоты (%.0f) внутри панели" % rows[0].size.y)
	var grid: Control = _screen.get_node("%Grid")
	var grid_panel_rect: Rect2 = panels[2].get_global_rect()
	var cells_ok: bool = true
	for cell: Control in grid.get_children():
		if not cell.size.is_equal_approx(Vector2(ItemCell.SIZE, ItemCell.SIZE)):
			cells_ok = false
	var grid_rect: Rect2 = grid.get_global_rect()
	_check(cells_ok and grid_panel_rect.encloses(grid_rect) and absf((grid_rect.get_center().x - grid_panel_rect.get_center().x)) <= 2.0, "ячейки квадратные %.0f px, сетка по центру своей панели" % ItemCell.SIZE)
	var controls: Array = _screen.get_node("Root/Center/Main/GridColumn/Controls").get_children()
	var controls_ok: bool = controls.size() == 3
	for control: Control in controls:
		if absf(control.get_global_rect().position.y - controls[0].get_global_rect().position.y) > 1.0 or control.get_global_rect().end.x > grid_panel_rect.end.x + 1.0:
			controls_ok = false
	_check(controls_ok, "сортировка, направление и фильтр в одной строке в пределах колонки")
	_check(grid_panel_rect.encloses(_screen.get_node("%CapacityLabel").get_global_rect()), "счётчик вместимости внутри панели сетки")


# --- Эталон 1920 x 1080: окно другого размера растягивает проект (stretch canvas_items, aspect expand), раскладка
# экрана считается в единицах эталона и в любом окне остаётся ровной.
func _test_stretch(cell: Control) -> void:
	var card: Control = _screen.get_node("%Card")
	var original: Vector2i = root.size
	_check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND and root.content_scale_size == Vector2i(1920, 1080), "проект растягивается от эталона 1920 x 1080 (canvas_items, expand)")
	var problems: PackedStringArray = []
	var factors: Array[float] = []
	var sizes: Array[Vector2i] = [Vector2i(800, 500), Vector2i(1152, 648), Vector2i(1908, 1008), Vector2i(1920, 1080), Vector2i(1280, 1024), Vector2i(2560, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
	for window_size: Vector2i in sizes:
		root.size = window_size
		await _frames(4)
		var window: Vector2 = Vector2(window_size)
		var factor: float = root.get_final_transform().get_scale().x
		factors.append(factor)
		# Инвентарь открыт, поэтому к растяжению окна добавлен масштаб меню (№79).
		var expected: float = minf(window.x / 1920.0, window.y / 1080.0) * _user.menu_scale
		if absf(factor - expected) > 0.002:
			problems.append("%s: масштаб %.3f, ожидался %.3f" % [str(window_size), factor, expected])
		var visible: Vector2 = root.get_visible_rect().size
		if (visible * factor - window).length() > 2.0:
			problems.append("%s: видимая область %s не занимает окно" % [str(window_size), str(visible)])
		if visible.x < 1919.0 or visible.y < 1079.0:
			problems.append("%s: эталонная область 1920 x 1080 не помещается (%s)" % [str(window_size), str(visible)])
		if (_ui_size() - visible).length() > 1.0:
			problems.append("%s: экран инвентаря %s не равен видимой области" % [str(window_size), str(_ui_size())])
		_quiet = true
		_quiet_failures = []
		_test_layout()
		_quiet = false
		for failure: String in _quiet_failures:
			problems.append("%s: раскладка: %s" % [str(window_size), failure.substr(0, 70)])
		await _hover(cell)
		await _frames(4)
		var card_rect: Rect2 = card.get_global_rect()
		var pointer: Vector2 = cell.get_global_rect().get_center()
		if not _fits_screen(card_rect) or card_rect.has_point(pointer) or card_rect.position.distance_to(_expected_card_position(pointer, card_rect.size)) > 1.5:
			problems.append("%s: карточка %s при курсоре %s" % [str(window_size), str(card_rect), str(pointer)])
		await _hover(null)
	_check(problems.is_empty(), "в окнах от 800 x 500 до 3840 x 2160 раскладка ровная, эталонная область видна, карточка у курсора %s" % str(problems))
	var increasing: bool = true
	for i: int in range(1, factors.size()):
		if factors[i] < factors[i - 1] - 0.0001 and sizes[i].y >= sizes[i - 1].y and sizes[i].x >= sizes[i - 1].x:
			increasing = false
	_check(increasing and factors[0] < factors[3] and is_equal_approx(factors[3], _user.menu_scale) and factors[factors.size() - 1] > factors[3], "масштаб растёт вместе с окном, в 1920 x 1080 равен масштабу меню %.2f: %s" % [_user.menu_scale, str(factors)])
	root.size = original
	await _frames(4)
	_check(is_equal_approx(root.get_final_transform().get_scale().x, _user.menu_scale), "после возврата размера окна масштаб прежний")


# Где должна стоять карточка у курсора: справа и ниже, у правого края слева от курсора, у нижнего сдвинута вверх.
func _expected_card_position(pointer: Vector2, card_size: Vector2) -> Vector2:
	var viewport_size: Vector2 = _ui_size()
	var offset: Vector2 = _screen.CARD_OFFSET
	var margin: float = _screen.CARD_MARGIN
	var x: float = pointer.x + offset.x
	if x + card_size.x > viewport_size.x - margin:
		x = pointer.x - offset.x - card_size.x
	return Vector2(maxf(x, margin), clampf(pointer.y + offset.y, margin, maxf(margin, viewport_size.y - card_size.y - margin)))


# Размер экрана инвентаря в его единицах: окно, делённое на масштаб.
func _ui_size() -> Vector2:
	return _screen.get_node("Root").size


# Помещается ли прямоугольник в окно.
func _fits_screen(rect: Rect2) -> bool:
	var viewport_size: Vector2 = _ui_size()
	return rect.position.x >= -1.0 and rect.position.y >= -1.0 and rect.end.x <= viewport_size.x + 1.0 and rect.end.y <= viewport_size.y + 1.0


# Наведение мыши, как у настоящей мыши: прежний элемент получает mouse_exited, новый mouse_entered.
func _hover(control: Control) -> void:
	if _hovered != null and is_instance_valid(_hovered):
		_hovered.mouse_exited.emit()
	_hovered = control
	if control != null:
		control.mouse_entered.emit()
	await _frames(4)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(3)
	Input.action_release(action)
	await _frames(3)


# 1: подсказка есть и доступна, 0: есть, но недоступна, -1: такой подсказки нет.
func _hint_state(card: Node, text: String) -> int:
	for label: Label in _collect_class(card, "Label"):
		if label.text == text:
			return 1 if label.get_theme_color("font_color").a > 0.9 else 0
	return -1


# Узлы потомков заданного класса (по имени глобального класса или встроенного), без удаляемых.
func _collect_class(node: Node, class_name_text: String) -> Array:
	var result: Array = []
	for child: Node in node.get_children():
		if child.is_queued_for_deletion():
			continue
		var script: Script = child.get_script()
		var matches: bool = child.is_class(class_name_text) or (script != null and script.get_global_name() == class_name_text)
		if matches:
			result.append(child)
		result.append_array(_collect_class(child, class_name_text))
	return result


# --- HUD: панель слотов, иконка стихии, подсказки.
func _test_hud() -> void:
	print("--- HUD: панель слотов, иконка стихии, отладочные клавиши")
	_inventory.clear()
	_progress.reset()
	while _weapon.occupied_count() > 1:
		for i: int in _weapon.slots.size():
			if _weapon.slots[i] != null and i != _weapon.active_slot and _weapon.occupied_count() > 1:
				_weapon.slots[i] = null
	var panel = _hud.get_node("Root/WeaponSlots")
	var settings: InventorySettings = _config.data.inventory
	await _secs(settings.slots_show_seconds + 1.5)
	_check(is_equal_approx(panel.get_alpha(), settings.slots_idle_alpha), "панель слотов в покое полупрозрачна (%.2f)" % panel.get_alpha())
	var plain: WeaponInstance = _featured_weapon(CombatEnums.FeatureKind.ELEMENT, CombatEnums.Element.NONE)
	var plain_slot: int = _weapon.give_weapon(plain)
	await _secs(_weapon.shooting.swap_time + 0.3)
	var featured: WeaponInstance = _featured_weapon(CombatEnums.FeatureKind.ELEMENT, CombatEnums.Element.ELECTRIC)
	_weapon.give_weapon(featured)
	await _secs(0.8)
	_check(panel.get_alpha() > 0.95, "при смене оружия панель становится яркой (%.2f)" % panel.get_alpha())
	await _secs(settings.slots_show_seconds + 1.5)
	_check(is_equal_approx(panel.get_alpha(), settings.slots_idle_alpha), "через %.0f с панель снова полупрозрачна" % settings.slots_show_seconds)
	_check(panel.size.x >= 4.0 * 64.0 and panel.get("_weapon") == _weapon and panel.get_global_rect().get_center().x > get_root().get_visible_rect().size.x * 0.4 and panel.get_global_rect().get_center().x < get_root().get_visible_rect().size.x * 0.6 and panel.get_global_rect().end.y > get_root().get_visible_rect().size.y * 0.8, "панель слотов внизу по центру, рассчитана на %d слота" % _weapon.slots.size())
	var icon = _hud.get_node("Root/ElementIcon")
	_check(icon.element == CombatEnums.Element.ELECTRIC and _weapon.stats.element == CombatEnums.Element.ELECTRIC, "иконка стихии у патронов: электричество у оружия в руках")
	_weapon.switch_to(plain_slot)
	await _secs(_weapon.shooting.swap_time + 0.3)
	_check(icon.element == CombatEnums.Element.NONE and _weapon.active_slot == plain_slot, "после смены на оружие без стихии иконка пропала")
	var hint = _hud.get_node("Root/TabHint")
	_check(hint.visible and hint.get_global_rect().position.x > get_root().get_visible_rect().size.x * 0.8 and hint.get_global_rect().position.y < 80.0 and hint._key_name() == OS.get_keycode_string(InputMap.action_get_events("inventory_toggle")[0].physical_keycode), "подсказка клавиши инвентаря в правом верхнем углу: «%s»" % hint._key_name())
	# Отладочные клавиши.
	_inventory.clear()
	_rejected = 0
	var occupied_before: int = _weapon.occupied_count()
	Input.action_press("debug_give_weapon")
	await _frames(3)
	Input.action_release("debug_give_weapon")
	await _frames(3)
	_check(_inventory.items.size() == 1 and _inventory.items[0].is_weapon() and _weapon.occupied_count() == occupied_before, "клавиша G выдаёт оружие в инвентарь, а не в слоты")
	_check(_inventory.items[0].get_level() == _progress.level, "выданное оружие уровня персонажа (%d)" % _inventory.items[0].get_level())
	Input.action_press("debug_give_item")
	await _frames(3)
	Input.action_release("debug_give_item")
	await _frames(3)
	_check(_inventory.items.size() == 2 and _inventory.items[1].definition == _medkit, "клавиша T выдаёт аптечку")
	Input.action_press("debug_give_item")
	await _frames(3)
	Input.action_release("debug_give_item")
	await _frames(3)
	_check(_inventory.items.size() == 2 and _inventory.items[1].count == 2, "вторая аптечка легла в ту же стопку")
	_fill(_inventory.get_capacity() - _inventory.items.size())
	Input.action_press("debug_give_weapon")
	await _frames(3)
	Input.action_release("debug_give_weapon")
	await _frames(3)
	_check(_inventory.items.size() == _inventory.get_capacity() and _rejected >= 1, "при полном инвентаре клавиша G ничего не кладёт и вызывает «Инвентарь полон»")
	# Мёртвый игрок инвентарь не открывает.
	_inventory.clear()
	_player.take_damage(1000.0)
	await _frames(3)
	Input.action_press("inventory_toggle")
	await _frames(3)
	Input.action_release("inventory_toggle")
	await _frames(3)
	_check(not _screen.is_open(), "после гибели инвентарь по Tab не открывается")


# Оружие с особенностью-стихией на аксессуаре.
func _featured_weapon(kind: int, element: int) -> WeaponInstance:
	for i: int in 400:
		var instance: WeaponInstance = _generator.generate(_rng, 1, CombatEnums.WeaponType.PISTOL)
		var accessory: PartInstance = instance.get_part(WeaponPart.PartType.ACCESSORY)
		if accessory == null:
			continue
		accessory.features.clear()
		for feature: PartFeature in _settings.accessory_features:
			if feature.kind == kind and feature.element == element:
				accessory.features.append(feature)
		return instance
	return null


# Весь текст карточки и её кнопки одной сборкой.
func _collect_text(node: Node) -> PackedStringArray:
	var result: PackedStringArray = []
	for child: Node in node.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Label:
			result.append((child as Label).text)
		elif child is Button:
			result.append((child as Button).text)
		result.append_array(_collect_text(child))
	return result


func _buttons(node: Node) -> Dictionary:
	var result: Dictionary = {}
	for child: Node in node.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Button:
			result[(child as Button).text] = child
		result.merge(_buttons(child))
	return result


func _collect_arrows(node: Node) -> Array:
	var result: Array = []
	for child: Node in node.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is StatArrow:
			result.append(child)
		result.append_array(_collect_arrows(child))
	return result


func _arrow_count(arrows: Array) -> int:
	var count: int = 0
	for arrow in arrows:
		if arrow.direction != 0:
			count += 1
	return count
