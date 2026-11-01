@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Детали оружия отдельными предметами (срез 7б, №83): генерация, предмет в инвентаре (цена, качество, фильтр),
## карточка, выпадение из врагов (целое оружие из них не падает), потеря при смерти.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_parts.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.

var _fails: int = 0
var _room: Node
var _player
var _inventory
var _settings: WeaponGenerationSettings
var _generator: WeaponGenerator
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _collect_text(node: Node) -> PackedStringArray:
	var result: PackedStringArray = []
	for child: Node in node.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Label:
			result.append(child.text)
		result.append_array(_collect_text(child))
	return result


func _initialize() -> void:
	create_timer(300.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	_inventory = root.get_node("Inventory")
	root.get_node("Progress").reset()
	_inventory.clear()
	_settings = load("res://data/content/balance/weapon_generation.tres")
	_generator = WeaponGenerator.new(_settings)
	_rng.seed = 8383
	root.size = Vector2i(1920, 1080)
	_room = (load("res://rooms/test_room.tscn") as PackedScene).instantiate()
	_room.get_node("Enemies").free()
	root.add_child(_room)
	_room.get_node("Dummies").queue_free()
	await _frames(10)
	_player = _room.get_node("Player")
	await _run()
	_inventory.clear()
	print("=== FAILS: ", _fails)
	quit(_fails)


func _run() -> void:
	print("--- Генерация деталей")
	var seen_types: Dictionary = {}
	var broken: int = 0
	var rolled_total: int = 400
	var tier_ok: bool = true
	for i: int in rolled_total:
		var part: PartInstance = _generator.generate_part(_rng)
		if part == null or part.part.manufacturer == null or part.quality < 0 or part.quality >= _settings.quality_scale.tiers.size():
			broken += 1
			continue
		seen_types[part.part.part_type] = true
		var tier: QualityTier = _settings.quality_scale.tiers[part.quality]
		if part.modifiers.size() > tier.modifier_count:
			tier_ok = false
		if part.part.part_type == WeaponPart.PartType.ACCESSORY and part.features.size() > tier.accessory_feature_count:
			tier_ok = false
	_check(broken == 0, "%d деталей: у каждой есть производитель и качество в шкале" % rolled_total)
	_check(seen_types.size() == WeaponPart.PartType.size(), "выпадают все шесть типов деталей (%d из %d)" % [seen_types.size(), WeaponPart.PartType.size()])
	_check(tier_ok, "модификаторов и особенностей аксессуара не больше, чем даёт качество")

	print("--- Деталь как предмет")
	var part: PartInstance = _generator.generate_part(_rng)
	var item: InventoryItem = InventoryItem.from_part(part, _settings)
	var tier_data: QualityTier = _settings.quality_scale.tiers[part.quality]
	_check(item.is_part() and not item.is_weapon() and item.get_category() == ItemDefinition.Category.PART, "предмет-деталь: категория PART, не оружие")
	_check(item.get_display_name() == tr(part.part.name_key) and item.get_type_text() == tr("PART_TYPE_" + WeaponPart.PartType.keys()[part.part.part_type]), "название «%s», тип «%s»" % [item.get_display_name(), item.get_type_text()])
	_check(item.get_quality() == part.quality and item.get_quality_color() == tier_data.color and item.get_level() == 0, "качество и цвет рамки по шкале, уровня у детали нет")
	var expected_price: int = roundi(float(part.part.base_price) * tier_data.price_multiplier + float(part.modifiers.size() * _settings.modifier_price))
	_check(item.get_price() == expected_price and not item.can_stack_with(item) and not item.is_eternal(), "цена по справочнику частей: %d (база %d x%.2f плюс модификаторы), в стопку не складывается" % [item.get_price(), part.part.base_price, tier_data.price_multiplier])
	_check(item.get_maker_text() == tr(part.part.manufacturer.name_key), "производитель «%s»" % item.get_maker_text())

	print("--- Инвентарь и фильтр")
	var weapon_item: InventoryItem = InventoryItem.from_weapon(_generator.generate(_rng, 1))
	_inventory.add(weapon_item)
	_check(_inventory.add(item), "деталь кладётся в инвентарь и занимает клетку (%d предметов)" % _inventory.items.size())
	var parts_only: Array[InventoryItem] = InventoryView.build(_inventory.items, InventoryView.SortKey.NONE, true, InventoryView.Filter.PART)
	_check(parts_only.size() == 1 and parts_only[0] == item, "фильтр «Детали» оставляет только детали")
	var sorted: Array[InventoryItem] = InventoryView.build(_inventory.items, InventoryView.SortKey.TYPE, true, InventoryView.Filter.ALL)
	_check(sorted.size() == 2 and sorted[0] == weapon_item and sorted[1] == item, "по типу детали идут после оружия")

	print("--- Карточка детали")
	var card = _room.get_node("Hud").get_node("InventoryScreen").get_node("%Card")
	card.show_item(item, {"player_level": 1, "can_drop": true})
	await _frames(2)
	var texts: PackedStringArray = _collect_text(card)
	var joined: String = " ".join(texts)
	_check(joined.contains(item.get_display_name()) and joined.contains(item.get_maker_text()) and joined.contains(item.get_type_text()), "в карточке название, производитель и тип детали")
	_check(joined.contains(tr("CARD_PRICE").format({"price": item.get_price()})) or item.get_price() == 0, "в карточке цена %d" % item.get_price())
	_check(joined.contains(tr("CARD_BTN_DROP")) and not joined.contains(tr("CARD_BTN_EQUIP")) and not joined.contains(tr("CARD_BTN_COMPARE")) and not joined.contains(tr("CARD_BTN_COMPONENTS")), "из действий у детали только «выбросить»")
	_check(joined.contains(tr("CARD_PART_FITS_ANY")) or joined.contains(tr("CARD_PART_FITS").format({"types": ""}).trim_suffix(" ")), "сказано, каким видам оружия деталь подходит")

	print("--- Выпадение из врагов")
	var enemies_before: int = get_nodes_in_group(&"enemies").size()
	var chaser_settings: EnemySettings = load("res://data/content/enemies/chaser.tres")
	_check(chaser_settings.part_chance > 0.0 and chaser_settings.part_chance < 0.1, "у преследующего шанс детали из настроек: %.2f" % chaser_settings.part_chance)
	var kills: int = 1200
	var parts_dropped: int = 0
	var weapons_dropped: int = 0
	var before_pickups: Array = get_nodes_in_group(&"item_pickups")
	for i: int in kills:
		var enemy = (load("res://enemies/chaser.tscn") as PackedScene).instantiate()
		_room.add_child(enemy)
		enemy.global_position = Vector3(0.0, 0.05, -20.0)
		enemy.take_hit(DamageInfo.create(1.0e9, false, enemy.global_position + Vector3(0, 1, 0)))
		for pickup in get_nodes_in_group(&"item_pickups"):
			if before_pickups.has(pickup):
				continue
			before_pickups.append(pickup)
			if pickup.item.is_part():
				parts_dropped += 1
			else:
				weapons_dropped += 1
		enemy.free()
	var expected: float = float(kills) * chaser_settings.part_chance
	_check(float(parts_dropped) > expected * 0.4 and float(parts_dropped) < expected * 1.8, "из %d убитых детали выпали %d раз (ждём около %.0f)" % [kills, parts_dropped, expected])
	_check(weapons_dropped == 0, "целое оружие из врагов не выпадает (%d)" % weapons_dropped)
	for pickup in get_nodes_in_group(&"item_pickups").duplicate():
		pickup.free()
	var elite = (load("res://enemies/elite.tscn") as PackedScene).instantiate()
	_room.add_child(elite)
	elite.global_position = Vector3(0.0, 0.05, -20.0)
	elite.take_hit(DamageInfo.create(1.0e9, false, elite.global_position + Vector3(0, 1, 0)))
	var elite_parts: int = 0
	for pickup in get_nodes_in_group(&"item_pickups"):
		if pickup.item.is_part():
			elite_parts += 1
	_check(elite.settings.part_chance >= 1.0 and elite_parts >= 1, "элитный враг всегда роняет деталь")
	elite.free()
	for pickup in get_nodes_in_group(&"item_pickups").duplicate():
		pickup.free()
	_check(get_nodes_in_group(&"enemies").size() == enemies_before, "тестовые враги убраны")

	print("--- Смерть забирает детали")
	var lost: int = root.get_node("Run").lose_loot(_player)
	var parts_left: int = 0
	for entry: InventoryItem in _inventory.items:
		if entry.is_part():
			parts_left += 1
	_check(parts_left == 0 and lost >= 2, "после смерти деталей в рюкзаке нет (потеряно предметов %d)" % lost)
