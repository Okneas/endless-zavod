@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Гранаты (№92). Данные и генерация (тип, качество, число модификаторов по качеству, названия, цена, уровень), стартовая вечная
## граната, бросок на G с перезарядкой у каждой гранаты своей, поведение типов (осколочная по запалу, стихийная от касания врага,
## липкая, кассетная, сингулярность), цепной взрыв бочки, слот гранат и инвентарь (экипировка, снятие, смерть), источники (враг, ящик,
## торговец), продажа покупателям, значок в HUD.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_grenades.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.
## Классы снаряда, ящика и действий тянут автозагрузки, поэтому берутся через load(), а не по имени.

const PLAYER_POS: Vector3 = Vector3(0.0, 0.05, 15.0)

var _fails: int = 0
var _room: Node
var _player
var _config
var _settings: GrenadeSettings
var _generator: GrenadeGenerator
var _projectile_script
var _actions
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _secs(seconds: float) -> void:
	await _frames(int(seconds * 120.0))


func _reset_player(pos: Vector3 = PLAYER_POS) -> void:
	_player.is_dead = false
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.rotation.y = 0.0
	_player.set_look_pitch(0.0)
	_player.set_health(_player.max_health)


func _clear() -> void:
	for node: Node in get_nodes_in_group(&"enemies"):
		node.free()
	for node: Node in get_nodes_in_group(&"props"):
		node.free()
	for node: Node in get_nodes_in_group(&"grenades"):
		node.free()
	for child: Node in _room.get_children():
		var kind: String = child.get_script().get_global_name() if child.get_script() != null else ""
		if kind == "Pickup" or kind == "ItemPickup" or kind == "BlastEffect" or child.name == "Debris" or child is StaticBody3D and child.name == "TestWall":
			child.free()
	await _frames(2)


func _enemy(pos: Vector3, health_scale: float = 40.0):
	var enemy = (load("res://enemies/chaser.tscn") as PackedScene).instantiate()
	enemy.health_scale = health_scale
	_room.add_child(enemy)
	enemy.global_position = pos
	enemy.set_physics_process(false)
	return enemy


# Граната заданного типа без модификаторов, серийного качества, указанного уровня.
func _grenade(key: String, level: int = 1) -> GrenadeInstance:
	var definition: GrenadeDefinition = load("res://data/content/grenades/%s.tres" % key)
	var instance: GrenadeInstance = _generator.generate(_rng, level, definition)
	instance.modifiers.clear()
	instance.quality = 1
	return instance


func _launch(instance: GrenadeInstance, pos: Vector3, velocity: Vector3 = Vector3.ZERO):
	var projectile = _projectile_script.from_instance(instance, _settings)
	_room.add_child(projectile)
	projectile.global_position = pos
	projectile.linear_velocity = velocity
	return projectile


func _projectiles() -> Array:
	return get_nodes_in_group(&"grenades")


func _initialize() -> void:
	create_timer(600.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	_config = root.get_node("Config")
	_settings = _config.data.grenades
	_generator = GrenadeGenerator.new(_settings, _config.data.weapons.quality_scale)
	_projectile_script = load("res://weapons/grenade_projectile.gd")
	_actions = load("res://inventory/inventory_actions.gd")
	_rng.seed = 92
	root.get_node("Progress").reset()
	root.get_node("Inventory").clear()
	root.get_node("Inventory").reset_grenade()
	_room = (load("res://rooms/test_room.tscn") as PackedScene).instantiate()
	_room.get_node("Enemies").free()
	_room.get_node("Dummies").queue_free()
	root.add_child(_room)
	await _frames(10)
	_player = _room.get_node("Player")
	await _run()
	print("=== FAILS: ", _fails)
	quit(_fails)


func _run() -> void:
	var inventory = root.get_node("Inventory")
	var progress = root.get_node("Progress")
	var scale: QualityScale = _config.data.weapons.quality_scale

	print("--- Данные")
	var kinds: Dictionary = {}
	var elements: Dictionary = {}
	var texts_ok: bool = true
	for definition: GrenadeDefinition in _settings.types:
		kinds[definition.kind] = true
		elements[definition.element] = true
		texts_ok = texts_ok and tr(definition.name_key) != definition.name_key and tr(definition.name_lower_key) != definition.name_lower_key and tr(definition.description_key) != definition.description_key and definition.cooldown > 0.0 and definition.base_damage > 0.0
	_check(_settings.types.size() >= 8 and kinds.size() == 4 and elements.size() == 5 and texts_ok, "типы гранат: осколочная, четыре стихии, липкая, кассетная, сингулярность (%d типов), у всех название, описание, урон и перезарядка" % _settings.types.size())
	var mod_ok: bool = _settings.modifiers.size() >= 6
	for modifier: GrenadeModifier in _settings.modifiers:
		mod_ok = mod_ok and tr(modifier.name_key) != modifier.name_key and tr("GRENADE_STAT_" + GrenadeModifier.Stat.keys()[modifier.stat]) != "GRENADE_STAT_" + GrenadeModifier.Stat.keys()[modifier.stat]
	_check(mod_ok and _settings.starter != null and _settings.starter.kind == GrenadeDefinition.Kind.FRAG, "модификаторы с названиями и подписями характеристик, стартовая граната осколочная")

	print("--- Генерация")
	var counts_ok: bool = true
	var unique_ok: bool = true
	var fit_ok: bool = true
	var range_ok: bool = true
	var tiers_seen: Dictionary = {}
	var kinds_seen: Dictionary = {}
	for i: int in 600:
		var instance: GrenadeInstance = _generator.generate(_rng, 1 + i % 10)
		var tier: QualityTier = scale.tiers[instance.quality]
		tiers_seen[instance.quality] = true
		kinds_seen[instance.definition.kind] = true
		var stats_seen: Dictionary = {}
		var eligible: int = 0
		for modifier: GrenadeModifier in _settings.modifiers:
			if modifier.kinds.is_empty() or modifier.kinds.has(instance.definition.kind):
				eligible += 1
		counts_ok = counts_ok and instance.modifiers.size() == mini(tier.modifier_count, eligible)
		for rolled: GrenadeInstance.Rolled in instance.modifiers:
			unique_ok = unique_ok and not stats_seen.has(rolled.modifier.stat)
			stats_seen[rolled.modifier.stat] = true
			fit_ok = fit_ok and (rolled.modifier.kinds.is_empty() or rolled.modifier.kinds.has(instance.definition.kind))
			range_ok = range_ok and rolled.value >= rolled.modifier.min_value - 0.0001 and rolled.value <= maxf(rolled.modifier.min_value, rolled.modifier.max_value) + 0.0001
	_check(counts_ok and unique_ok and fit_ok and range_ok, "600 гранат: число модификаторов задаёт качество, без повторов, только подходящие типу, значения в диапазоне")
	_check(tiers_seen.size() >= 3 and kinds_seen.size() == 4, "выпадают разные качества (%d) и все виды (%d)" % [tiers_seen.size(), kinds_seen.size()])
	var plain: GrenadeInstance = _grenade("frag", 1)
	var powerful_mod: GrenadeModifier = load("res://data/content/grenades/modifiers/powerful.tres")
	var boosted: GrenadeInstance = _grenade("frag", 1)
	var rolled_power: GrenadeInstance.Rolled = GrenadeInstance.Rolled.new()
	rolled_power.modifier = powerful_mod
	rolled_power.value = 0.25
	boosted.modifiers.append(rolled_power)
	_check(is_equal_approx(boosted.compute_stats().damage, plain.compute_stats().damage * 1.25), "модификатор «Мощная» +25%% даёт урон x1.25 (%.0f -> %.0f)" % [plain.compute_stats().damage, boosted.compute_stats().damage])
	_check(boosted.get_display_name() == "%s %s" % [tr("GRENADE_MOD_POWERFUL"), tr("GRENADE_FRAG_L")] and plain.get_display_name() == tr("GRENADE_FRAG"), "название «%s», без модификаторов «%s»" % [boosted.get_display_name(), plain.get_display_name()])
	var leveled: GrenadeInstance = _grenade("frag", 11)
	_check(is_equal_approx(leveled.compute_stats().damage, plain.compute_stats().damage * (1.0 + _settings.damage_per_level * 10.0)) and leveled.get_price() > plain.get_price() and boosted.get_price() == plain.get_price() + _settings.modifier_price, "урон растёт с уровнем гранаты, цена с уровнем и модификаторами (%d -> %d)" % [plain.get_price(), leveled.get_price()])
	var swift: GrenadeInstance = _grenade("frag", 1)
	var rolled_swift: GrenadeInstance.Rolled = GrenadeInstance.Rolled.new()
	rolled_swift.modifier = load("res://data/content/grenades/modifiers/swift.tres")
	rolled_swift.value = -0.25
	swift.modifiers.append(rolled_swift)
	_check(is_equal_approx(swift.compute_stats().cooldown, plain.compute_stats().cooldown * 0.75), "«Скорая» -25%% сокращает перезарядку (%.1f -> %.1f с)" % [plain.compute_stats().cooldown, swift.compute_stats().cooldown])
	var cluster_plain: GrenadeInstance = _grenade("cluster", 1)
	var cluster_multi: GrenadeInstance = _grenade("cluster", 1)
	var rolled_multi: GrenadeInstance.Rolled = GrenadeInstance.Rolled.new()
	rolled_multi.modifier = load("res://data/content/grenades/modifiers/multi.tres")
	rolled_multi.value = 2.0
	cluster_multi.modifiers.append(rolled_multi)
	_check(cluster_multi.compute_stats().bomblets == cluster_plain.compute_stats().bomblets + 2 and plain.compute_stats().bomblets == 0, "«Многозарядная» добавляет малые гранаты кассетной (%d -> %d)" % [cluster_plain.compute_stats().bomblets, cluster_multi.compute_stats().bomblets])

	print("--- Стартовая граната и слот")
	_check(inventory.grenade != null and inventory.grenade.is_eternal and inventory.grenade.definition == _settings.starter and inventory.grenade.level == progress.level, "в слоте стартовая вечная осколочная граната, уровень равен уровню персонажа (%d)" % progress.level)
	progress.add_xp(progress.xp_to_next() - progress.xp)
	_check(inventory.grenade.level == progress.level and progress.level >= 2, "вечная граната растёт вместе с персонажем (ур. %d)" % inventory.grenade.level)

	print("--- Бросок на G")
	await _clear()
	_reset_player()
	var thrower = _player.get_grenades()
	var grenade: GrenadeInstance = inventory.grenade
	grenade.cooldown_left = 0.0
	var refused: Array = []
	thrower.refused.connect(func() -> void: refused.append(true))
	Input.action_press("grenade")
	await _frames(3)
	Input.action_release("grenade")
	await _frames(2)
	var in_air: Array = _projectiles()
	var forward: Vector3 = -_player.get_node("Head/Camera3D").global_basis.z
	_check(in_air.size() == 1 and in_air[0].linear_velocity.dot(forward) > _settings.throw_speed * 0.8, "G бросает гранату по взгляду (скорость вперёд %.1f м/с)" % (in_air[0].linear_velocity.dot(forward) if in_air.size() > 0 else 0.0))
	var cooldown: float = grenade.compute_stats().cooldown
	_check(grenade.cooldown_left > cooldown - 0.2 and grenade.cooldown_left <= cooldown and not thrower.can_throw(), "после броска перезарядка %.1f с, бросить нельзя" % grenade.cooldown_left)
	Input.action_press("grenade")
	await _frames(3)
	Input.action_release("grenade")
	await _frames(2)
	_check(_projectiles().size() == 1 and refused.size() >= 1, "пока перезарядка не кончилась, вторая граната не летит")
	await _clear()
	grenade.cooldown_left = 0.3
	await _secs(0.5)
	_check(grenade.cooldown_left == 0.0 and thrower.can_throw(), "перезарядка идёт со временем, потом граната снова готова")
	# У каждой гранаты своя перезарядка: смена гранаты не обнуляет чужую.
	grenade.cooldown_left = 7.0
	var other: GrenadeInstance = _grenade("sticky", 1)
	inventory.add(InventoryItem.from_grenade(other))
	_actions.equip_grenade(_player, inventory.items[inventory.items.size() - 1])
	_check(inventory.grenade == other and other.cooldown_left == 0.0 and thrower.can_throw() and grenade.cooldown_left == 7.0, "у каждой гранаты своя перезарядка: новая готова, прежняя в рюкзаке ещё ждёт (%.0f с)" % grenade.cooldown_left)
	_actions.unequip_grenade()
	_actions.equip_grenade(_player, inventory.items[0] if inventory.items[0].grenade == grenade else inventory.items[inventory.items.size() - 1])
	_check(inventory.grenade == grenade and grenade.cooldown_left > 0.0 and not thrower.can_throw(), "вернули прежнюю: её перезарядка не сбросилась")
	_player.is_dead = true
	grenade.cooldown_left = 0.0
	_check(not thrower.can_throw(), "мёртвый игрок гранату не бросает")
	_player.is_dead = false
	grenade.cooldown_left = 0.0

	print("--- Осколочная: запал, урон по радиусу, игрока не задевает")
	await _clear()
	_reset_player(Vector3(0.0, 0.05, 15.0))
	var frag: GrenadeInstance = _grenade("frag", 1)
	var frag_stats: GrenadeInstance.Stats = frag.compute_stats()
	var target = _enemy(Vector3(0.0, 0.05, 0.0))
	# Граната падает из точки x = 1.0: края и «за радиусом» отсчитываются от неё.
	var edge = _enemy(Vector3(1.0 - frag_stats.radius * 0.85, 0.05, 0.0))
	var far = _enemy(Vector3(1.0 - (frag_stats.radius + 4.0), 0.05, 0.0))
	var target_before: float = target.health
	var edge_before: float = edge.health
	var far_before: float = far.health
	await _frames(3)
	var shell = _launch(frag, Vector3(1.0, 0.4, 0.0))
	await _secs(frag_stats.fuse * 0.5)
	_check(is_instance_valid(shell) and not shell.detonated and target.health == target_before, "до запала граната не взрывается")
	await _secs(frag_stats.fuse * 0.5 + 0.6)
	var lost: float = target_before - target.health
	_check(not is_instance_valid(shell) and lost > frag_stats.damage * 0.8 and lost <= frag_stats.damage + 0.01, "по запалу взорвалась: враг рядом -%.0f из %.0f" % [lost, frag_stats.damage])
	_check(edge_before - edge.health > 0.0 and edge_before - edge.health < lost and far.health == far_before, "на краю радиуса слабее (-%.0f), за радиусом цел" % (edge_before - edge.health))
	_check(_player.health == _player.max_health, "игрока своя граната не задевает")
	await _clear()

	print("--- Стихийные: от касания врага, стихия накладывается")
	for key: String in ["acid", "electric", "frost", "fire"]:
		_reset_player()
		var elemental: GrenadeInstance = _grenade(key, 1)
		var enemy = _enemy(Vector3(0.0, 0.05, 0.0))
		var health_before: float = enemy.health
		await _frames(3)
		var ball = _launch(elemental, Vector3(0.0, 0.95, 0.0))
		await _secs(0.35)
		var state_ok: bool = false
		match elemental.definition.element:
			CombatEnums.Element.ACID:
				state_ok = enemy.get("_acid_left") > 0.0
			CombatEnums.Element.ELECTRIC:
				state_ok = enemy.get("_electric_left") > 0.0
			CombatEnums.Element.FROST:
				state_ok = enemy.get("_frost_left") > 0.0
			CombatEnums.Element.FIRE:
				state_ok = enemy.get("_fire_left") > 0.0
		_check(not is_instance_valid(ball) and health_before - enemy.health > 0.0 and state_ok, "%s: взорвалась от касания раньше запала (%.1f с), урон -%.0f, стихия на враге" % [key, elemental.definition.fuse_time, health_before - enemy.health])
		await _clear()

	print("--- Липкая")
	_reset_player()
	var sticky: GrenadeInstance = _grenade("sticky", 1)
	var sticky_stats: GrenadeInstance.Stats = sticky.compute_stats()
	var victim = _enemy(Vector3(0.0, 0.05, 0.0))
	var victim_before: float = victim.health
	await _frames(3)
	var glue = _launch(sticky, Vector3(-4.0, 0.95, 0.0), Vector3(14.0, 0.0, 0.0))
	await _secs(0.5)
	_check(is_instance_valid(glue) and glue.state == 1 and glue._stuck_to == victim, "липкая прилипла к врагу")
	victim.global_position = Vector3(1.5, 0.05, 0.0)
	await _frames(6)
	_check(glue.global_position.distance_to(victim.global_position + Vector3(0.0, 0.9, 0.0)) < 1.3, "и едет вместе с ним")
	await _secs(sticky_stats.fuse + 0.4)
	_check(not is_instance_valid(glue) and victim_before - victim.health > sticky_stats.damage * 0.8, "взорвалась через запал, враг -%.0f" % (victim_before - victim.health))
	await _clear()
	var wall: StaticBody3D = StaticBody3D.new()
	wall.name = "TestWall"
	var wall_shape: CollisionShape3D = CollisionShape3D.new()
	var wall_box: BoxShape3D = BoxShape3D.new()
	wall_box.size = Vector3(0.4, 6.0, 8.0)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	_room.add_child(wall)
	wall.global_position = Vector3(5.0, 3.0, 0.0)
	await _frames(3)
	var wall_glue = _launch(_grenade("sticky", 1), Vector3(0.0, 1.5, 0.0), Vector3(16.0, 0.0, 0.0))
	await _secs(0.7)
	_check(is_instance_valid(wall_glue) and wall_glue.state == 1 and wall_glue._stuck_to == null and wall_glue.freeze, "к стене прилипает и висит на месте")
	await _secs(sticky_stats.fuse + 0.4)
	_check(not is_instance_valid(wall_glue), "и взрывается через запал")
	wall.free()
	await _clear()

	print("--- Кассетная")
	_reset_player()
	var cluster: GrenadeInstance = _grenade("cluster", 1)
	var cluster_stats: GrenadeInstance.Stats = cluster.compute_stats()
	var near = _enemy(Vector3(1.0, 0.05, 0.0))
	var near_before: float = near.health
	# Враг успевает встать на место в физике (в кадр создания он числится в начале координат и вытолкнул бы гранату).
	await _frames(3)
	var parent_shell = _launch(cluster, Vector3(0.0, 1.5, 0.0))
	await _secs(0.6)
	var small: Array = _projectiles()
	var all_small: bool = small.size() > 0
	for piece in small:
		all_small = all_small and piece.is_bomblet
	_check(not is_instance_valid(parent_shell) and small.size() == cluster_stats.bomblets and all_small, "при ударе разлетелась на %d малых гранат (ждали %d)" % [small.size(), cluster_stats.bomblets])
	await _secs(1.5)
	_check(_projectiles().is_empty() and near_before - near.health > 0.0, "малые гранаты взорвались сами и не плодят новых, враг рядом -%.0f" % (near_before - near.health))
	await _clear()

	print("--- Сингулярность")
	_reset_player()
	var singularity: GrenadeInstance = _grenade("singularity", 1)
	var sing_stats: GrenadeInstance.Stats = singularity.compute_stats()
	var pulled = _enemy(Vector3(4.0, 0.05, 0.0))
	var pulled_before: float = pulled.health
	await _frames(3)
	var well = _launch(singularity, Vector3(0.0, 0.4, 0.0))
	await _secs(0.4)
	var d0: float = Vector2(pulled.global_position.x, pulled.global_position.z).length()
	await _secs(1.2)
	var d1: float = Vector2(pulled.global_position.x, pulled.global_position.z).length()
	_check(is_instance_valid(well) and well.state == 2 and d1 < d0 - 1.0, "стягивает врага к центру: %.1f -> %.1f м" % [d0, d1])
	await _secs(sing_stats.pull_time + 0.6)
	_check(not is_instance_valid(well) and pulled_before - pulled.health > sing_stats.damage * 0.7, "потом взрывается, враг -%.0f" % (pulled_before - pulled.health))
	await _clear()

	print("--- Бочка рядом с взрывом гранаты")
	_reset_player()
	var barrel_definition: BarrelDefinition = load("res://data/content/props/barrels/explosive.tres")
	var barrel = load("res://run/props/explosive_barrel.gd").create(barrel_definition, _config.data.props, 1.0)
	_room.add_child(barrel)
	barrel.global_position = Vector3(2.0, 0.6, 0.0)
	var bomb = _launch(_grenade("elementless_missing_ok_fallback" if false else "frag", 1), Vector3(0.0, 0.5, 0.0))
	await _secs(frag_stats.fuse + _settings.chain_delay + 0.6)
	_check(not is_instance_valid(bomb) and not is_instance_valid(barrel), "граната взорвала соседнюю бочку цепью")
	await _clear()

	print("--- Слот гранат и инвентарь")
	inventory.clear()
	inventory.reset_grenade()
	progress.reset()
	var found: GrenadeInstance = _grenade("cluster", 1)
	var found_item: InventoryItem = InventoryItem.from_grenade(found)
	inventory.add(found_item)
	_check(found_item.get_category() == ItemDefinition.Category.GRENADE and found_item.get_display_name() == found.get_display_name() and found_item.get_price() == found.get_price() and found_item.get_type_text() == tr("CARD_GRENADE_TYPE"), "в рюкзаке гранаты: категория, название, цена, тип")
	var filtered: Array = InventoryView.build(inventory.items, InventoryView.SortKey.LEVEL, true, InventoryView.Filter.GRENADE)
	_check(filtered.size() == 1 and filtered[0] == found_item, "фильтр «Гранаты» показывает только гранаты")
	var starter: GrenadeInstance = inventory.grenade
	_check(_actions.equip(_player, found_item, -1) and inventory.grenade == found and not inventory.items.has(found_item) and inventory.items.size() == 1 and inventory.items[0].grenade == starter, "экипировка: новая в слоте, прежняя вечная вернулась в рюкзак")
	_check(inventory.items[0].is_eternal() and _actions.drop(_player, inventory.items[0]) == null and not root.get_node("Shop").can_sell(inventory.items[0]), "вечную гранату нельзя выбросить и продать")
	var high: GrenadeInstance = _grenade("frag", progress.level + 5)
	var high_item: InventoryItem = InventoryItem.from_grenade(high)
	inventory.add(high_item)
	_check(not _actions.can_equip(high_item) and not _actions.equip_grenade(_player, high_item) and inventory.grenade == found, "гранату выше уровня персонажа экипировать нельзя")
	inventory.remove(high_item)
	_check(_actions.unequip_grenade() and inventory.grenade == null and inventory.items.size() == 2, "снять гранату в рюкзак можно")
	_check(not thrower.can_throw(), "без гранаты в слоте бросать нечего")
	_actions.equip_grenade(_player, inventory.items[0])
	# Смерть: невечная граната в слоте теряется, вечная возвращается.
	var lost_item: InventoryItem = InventoryItem.from_grenade(_grenade("frost", 1))
	inventory.add(lost_item)
	_actions.equip_grenade(_player, lost_item)
	var carried_back: int = root.get_node("Run").lose_loot(_player)
	_check(inventory.grenade != null and inventory.grenade.is_eternal and carried_back >= 1 and inventory.items.all(func(item) -> bool: return item.grenade == null or item.grenade.is_eternal), "после смерти невечные гранаты потеряны, в слоте вечная")
	inventory.clear()
	inventory.reset_grenade()

	print("--- Источники")
	await _clear()
	var shooter_settings: EnemySettings = (load("res://data/content/enemies/chaser.tres") as EnemySettings).duplicate()
	shooter_settings.grenade_chance = 1.0
	shooter_settings.junk_chance = 0.0
	shooter_settings.part_chance = 0.0
	var drop_enemy = (load("res://enemies/chaser.tscn") as PackedScene).instantiate()
	drop_enemy.settings = shooter_settings
	drop_enemy.level = 4
	_room.add_child(drop_enemy)
	drop_enemy.global_position = Vector3(0.0, 0.05, 0.0)
	drop_enemy.take_hit(DamageInfo.create(1.0e9, false, drop_enemy.global_position + Vector3(0, 1, 0)))
	await _frames(3)
	var grenade_pickups: Array = []
	for node in get_nodes_in_group(&"item_pickups"):
		if node.item.is_grenade():
			grenade_pickups.append(node)
	_check(grenade_pickups.size() == 1 and grenade_pickups[0].item.grenade.level == 4, "из врага с шансом 1.0 падает граната его уровня")
	await _clear()
	var crate_definition: CrateDefinition = (load("res://data/content/props/crates/wooden.tres") as CrateDefinition).duplicate()
	crate_definition.money_chance = 0.0
	crate_definition.medkit_chance = 0.0
	crate_definition.part_chance = 0.0
	crate_definition.junk_chance = 0.0
	crate_definition.grenade_chance = 1.0
	var crate = load("res://run/props/breakable_crate.gd").create(crate_definition, _config.data.props, 3)
	crate.zone_level = 6
	_room.add_child(crate)
	crate.global_position = Vector3(0.0, 0.0, 0.0)
	await _frames(2)
	crate.take_hit(DamageInfo.create(1000.0, false, Vector3.ZERO))
	await _frames(3)
	var crate_grenades: int = 0
	var crate_level: int = 0
	for node in get_nodes_in_group(&"item_pickups"):
		if node.item.is_grenade():
			crate_grenades += 1
			crate_level = node.item.grenade.level
	_check(crate_grenades == 1 and crate_level == 6, "из ящика падает граната уровня зоны (%d)" % crate_level)
	await _clear()
	var shop = root.get_node("Shop")
	shop.reset()
	shop.refresh_trader(1, true)
	var trader_grenades: int = 0
	for slot in shop.trader_stock:
		if slot.item.is_grenade():
			trader_grenades += 1
			_check(slot.price == ShopMath.trader_price(_config.data.shop, slot.item) and slot.price > slot.item.get_price(), "граната у торговца: цена выше обычной (%d вместо %d)" % [slot.price, slot.item.get_price()])
	_check(trader_grenades == _settings.trader_count, "у торговца %d гранат" % trader_grenades)
	var profile: CustomerProfile = CustomerProfile.new()
	profile.weapon_type = CombatEnums.WeaponType.SNIPER
	profile.likes_loose_items = false
	var loose: CustomerProfile = CustomerProfile.new()
	loose.likes_loose_items = true
	var sample: InventoryItem = InventoryItem.from_grenade(_grenade("frag", 1))
	_check(not ShopMath.matches(profile, sample) and ShopMath.matches(loose, sample), "гранату покупают любители мелочи (как расходники и детали)")
	inventory.clear()
	inventory.add(sample)
	_check(shop.place(0, sample, shop.actual_price(sample)) and shop.counters[0].item == sample, "гранату можно выставить на прилавок")
	shop.reset()
	inventory.clear()

	print("--- Значок и окно инвентаря")
	var hud = _room.get_node("Hud")
	var indicator = hud.get_node_or_null("Root/GrenadeIndicator")
	_check(indicator != null and indicator.visible, "в HUD есть значок гранаты")
	var screen = hud.get_node("InventoryScreen")
	var shown: GrenadeInstance = _grenade("singularity", 1)
	inventory.add(InventoryItem.from_grenade(shown))
	_reset_player()
	screen.open()
	await _frames(4)
	var grenade_cell = null
	for cell in screen._cells:
		if cell.item != null and cell.item.is_grenade():
			grenade_cell = cell
	_check(grenade_cell != null, "граната лежит в сетке рюкзака")
	if grenade_cell != null:
		grenade_cell.mouse_entered.emit()
		await _frames(4)
		var card_text: String = ""
		for label in screen._card.find_children("*", "Label", true, false):
			card_text += label.text + " "
		_check(screen._card.visible and card_text.contains(shown.get_display_name()) and card_text.contains(tr("CARD_GRENADE_PULL").format({"value": "%.1f" % shown.compute_stats().pull_time}).substr(0, 10)) and card_text.contains(tr("CARD_BTN_EQUIP")), "карточка гранаты: название, характеристики, подсказка «Экипировать»")
		grenade_cell.mouse_exited.emit()
	var row = screen._rows[4]
	_check(row.is_grenade_row and row.grenade == inventory.grenade and not row.locked, "строка слота гранат показывает гранату в слоте")
	screen.close()
	inventory.clear()
	inventory.reset_grenade()
