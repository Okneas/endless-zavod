@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Бочки, ящики и хлам (№91). Стихийные бочки взрываются от выстрела, задевают врагов по радиусу и с падением урона, накладывают
## стихию, задевают игрока слабее, не бьют через стену, взрывают соседей цепью; удар в ближнем бою толкает бочку к ближайшему видимому
## врагу (без врагов вперёд), и она взрывается при ударе. Ящики ломаются выстрелами, из них падают монеты, аптечки, детали и хлам.
## Хлам: предметы, стопки, вес выпадения, фильтр, покупает любой покупатель. Расстановка по комнатам: плоские свободные места, не у проёмов.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_props.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.
## Классы бочки, ящика и расстановки тянут автозагрузки, поэтому берутся через load(), а не по имени.

const PLAYER_POS: Vector3 = Vector3(0.0, 0.05, 15.0)

var _fails: int = 0
var _room: Node
var _player
var _props: PropSettings
var _barrel_script
var _crate_script
var _scatter_script


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _secs(seconds: float) -> void:
	await _frames(int(seconds * 120.0))


func _reset_player(pos: Vector3 = PLAYER_POS, yaw_deg: float = 0.0) -> void:
	if _player.is_dead:
		_player.respawn(pos, 0.0)
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.rotation.y = deg_to_rad(yaw_deg)
	_player.set_look_pitch(0.0)
	_player.set_health(_player.max_health)


func _clear() -> void:
	for node: Node in get_nodes_in_group(&"enemies"):
		node.free()
	for node: Node in get_nodes_in_group(&"props"):
		node.free()
	for child: Node in _room.get_children():
		var kind: String = child.get_script().get_global_name() if child.get_script() != null else ""
		if kind == "Pickup" or kind == "ItemPickup" or kind == "BlastEffect" or child.name == "Debris":
			child.free()
	await _frames(2)


func _barrel(key: String, pos: Vector3, scale: float = 1.0, hold: bool = false):
	var definition: BarrelDefinition = load("res://data/content/props/barrels/%s.tres" % key)
	var barrel = _barrel_script.create(definition, _props, scale)
	_room.add_child(barrel)
	barrel.global_position = pos
	# Перенос будит тело: без этого бочка в воздухе (для проверок выстрела и удара) упала бы на пол.
	barrel.linear_velocity = Vector3.ZERO
	barrel.sleeping = true
	barrel.freeze = hold
	return barrel


func _enemy(pos: Vector3, health_scale: float = 30.0):
	var enemy = (load("res://enemies/chaser.tscn") as PackedScene).instantiate()
	enemy.health_scale = health_scale
	_room.add_child(enemy)
	enemy.global_position = pos
	enemy.set_physics_process(false)
	return enemy


func _pickups() -> Array:
	var result: Array = []
	for child: Node in _room.get_children():
		var kind: String = child.get_script().get_global_name() if child.get_script() != null else ""
		if kind == "Pickup" or kind == "ItemPickup":
			result.append(child)
	return result


func _initialize() -> void:
	create_timer(600.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	_props = root.get_node("Config").data.props
	_barrel_script = load("res://run/props/explosive_barrel.gd")
	_crate_script = load("res://run/props/breakable_crate.gd")
	_scatter_script = load("res://run/props/prop_scatterer.gd")
	_room = (load("res://rooms/test_room.tscn") as PackedScene).instantiate()
	_room.get_node("Enemies").free()
	_room.get_node("Dummies").queue_free()
	root.add_child(_room)
	await _frames(10)
	# Замеры здоровья без щита: он впитывал бы урон (щиты проверяет test_shields).
	root.get_node("Inventory").shield = null
	_player = _room.get_node("Player")
	await _run()
	print("=== FAILS: ", _fails)
	quit(_fails)


func _run() -> void:
	var explosive_def: BarrelDefinition = load("res://data/content/props/barrels/explosive.tres")
	print("--- Данные")
	var elements: Dictionary = {}
	for definition: BarrelDefinition in _props.barrels:
		elements[definition.element] = true
	_check(_props.enabled and _props.barrels.size() >= 5 and elements.has(CombatEnums.Element.NONE) and elements.has(CombatEnums.Element.ACID) and elements.has(CombatEnums.Element.ELECTRIC) and elements.has(CombatEnums.Element.FROST) and elements.has(CombatEnums.Element.FIRE), "виды бочек: взрывная и четыре стихии (%d видов)" % _props.barrels.size())
	_check(_props.crates.size() >= 2 and _props.junk_items.size() >= 10, "ящиков %d вида, хлама %d предметов" % [_props.crates.size(), _props.junk_items.size()])
	var junk_ok: bool = true
	for item: ItemDefinition in _props.junk_items:
		junk_ok = junk_ok and item.category == ItemDefinition.Category.JUNK and item.base_price > 0 and item.max_stack >= 1 and tr(item.name_key) != item.name_key and tr(item.description_key) != item.description_key
	_check(junk_ok, "у всего хлама категория «хлам», цена, стопка, название и описание в переводах")

	print("--- Бочка: выстрелы")
	await _clear()
	_reset_player()
	var shot_barrel = _barrel("explosive", Vector3(0.0, 1.6, 9.0), 1.0, true)
	var shots: int = ceili(shot_barrel.definition.health / (_player.get_weapon().stats.damage)) + 1
	_check(shot_barrel.collision_layer & _player.collision_mask != 0, "бочка твёрдая для игрока (слой совпадает с маской игрока)")
	for i: int in shots:
		if not is_instance_valid(shot_barrel):
			break
		Input.action_press("fire")
		await _frames(3)
		Input.action_release("fire")
		await _secs(0.4)
	_check(not is_instance_valid(shot_barrel), "бочка взорвалась от выстрелов оружия игрока (слой и маска дают попадание)")

	print("--- Бочка: урон по радиусу, стихия, видимость")
	await _clear()
	_reset_player(Vector3(0.0, 0.05, 30.0))
	for key: String in ["explosive", "acid", "electric", "frost", "fire"]:
		var barrel = _barrel(key, Vector3(0.0, 0.6, 0.0))
		var definition: BarrelDefinition = barrel.definition
		var near = _enemy(Vector3(definition.blast_radius * 0.3, 0.05, 0.0))
		var edge = _enemy(Vector3(-definition.blast_radius * 0.9, 0.05, 0.0))
		var far = _enemy(Vector3(-(definition.blast_radius + 4.0), 0.05, 0.0))
		var near_before: float = near.health
		var edge_before: float = edge.health
		var far_before: float = far.health
		barrel.detonate()
		await _frames(3)
		var near_lost: float = near_before - near.health
		var edge_lost: float = edge_before - edge.health
		var elem_ok: bool = true
		match definition.element:
			CombatEnums.Element.ACID:
				elem_ok = near.get("_acid_left") > 0.0
			CombatEnums.Element.ELECTRIC:
				elem_ok = near.get("_electric_left") > 0.0
			CombatEnums.Element.FROST:
				elem_ok = near.get("_frost_left") > 0.0
			CombatEnums.Element.FIRE:
				elem_ok = near.get("_fire_left") > 0.0
		_check(near_lost > 0.0 and edge_lost > 0.0 and near_lost > edge_lost and far.health == far_before and near_lost > definition.blast_damage * 0.95 and near_lost <= definition.blast_damage + 0.01 and elem_ok, "%s: в центре -%.0f, на краю -%.0f, за радиусом цел, стихия наложена (far цел %s, стихия %s)" % [key, near_lost, edge_lost, str(far.health == far_before), str(elem_ok)])
		await _clear()
	# Масштаб урона от уровня зоны: враги растут, бочка вместе с ними.
	var scaled = _barrel("explosive", Vector3(0.0, 0.6, 0.0), 3.0)
	var scaled_enemy = _enemy(Vector3(explosive_def.blast_radius * 0.3, 0.05, 0.0), 100.0)
	var scaled_before: float = scaled_enemy.health
	scaled.detonate()
	await _frames(3)
	_check(is_equal_approx(scaled_before - scaled_enemy.health, explosive_def.blast_damage * 3.0), "урон врагам растёт с уровнем зоны (x3 даёт x3)")
	await _clear()
	# Стена между бочкой и врагом: взрыв не пробивает.
	var wall: StaticBody3D = StaticBody3D.new()
	var wall_shape: CollisionShape3D = CollisionShape3D.new()
	var wall_box: BoxShape3D = BoxShape3D.new()
	wall_box.size = Vector3(0.4, 6.0, 10.0)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	_room.add_child(wall)
	wall.global_position = Vector3(explosive_def.blast_radius * 0.3, 3.0, 0.0)
	var hidden = _enemy(Vector3(explosive_def.blast_radius * 0.55, 0.05, 0.0))
	var hidden_before: float = hidden.health
	var walled = _barrel("explosive", Vector3(0.0, 0.6, 0.0))
	await _frames(2)
	walled.detonate()
	await _frames(3)
	_check(hidden.health == hidden_before, "за стеной взрыв не задевает")
	wall.free()
	await _clear()

	print("--- Бочка: игрок")
	_reset_player(Vector3(explosive_def.blast_radius * 0.25, 0.05, 0.0))
	var player_barrel = _barrel("explosive", Vector3(0.0, 0.6, 0.0))
	await _frames(2)
	player_barrel.detonate()
	await _frames(3)
	var lost: int = _player.max_health - _player.health
	_check(lost == ceili(explosive_def.player_damage) and float(lost) < explosive_def.blast_damage, "в центре взрыва игрок теряет %d (слабее, чем враги: %.0f)" % [lost, explosive_def.blast_damage])
	_reset_player(Vector3(0.0, 0.05, 14.0))
	var distant = _barrel("explosive", Vector3(0.0, 0.6, 0.0))
	await _frames(2)
	distant.detonate()
	await _frames(3)
	_check(_player.health == _player.max_health, "вне радиуса игрок цел")
	await _clear()

	print("--- Бочка: цепной взрыв")
	_reset_player(Vector3(0.0, 0.05, 30.0))
	var first = _barrel("explosive", Vector3(0.0, 0.6, 0.0))
	var second = _barrel("frost", Vector3(explosive_def.blast_radius * 0.5, 0.6, 0.0))
	await _frames(2)
	first.detonate()
	await _frames(3)
	_check(is_instance_valid(second) and not second.exploded, "соседняя бочка не взрывается мгновенно")
	await _secs(_props.chain_delay + 0.3)
	_check(not is_instance_valid(second), "через %.2f с соседняя бочка взорвалась цепью" % _props.chain_delay)
	await _clear()

	print("--- Бочка: толчок ударом")
	_reset_player()
	var melee = _player.get_node("Melee")
	var camera: Camera3D = _player.get_node("Head/Camera3D")
	var forward: Vector3 = -camera.global_basis.z
	var hit_point: Vector3 = camera.global_position + forward * melee.settings.reach
	var pushed = _barrel("explosive", hit_point)
	var target = _enemy(Vector3(10.0, 0.05, 14.0))
	var target_before: float = target.health
	await _frames(2)
	melee.swing()
	await _frames(2)
	var to_target: Vector3 = (target.global_position + Vector3(0.0, 0.9, 0.0) - pushed.global_position)
	var flat_velocity: Vector3 = Vector3(pushed.linear_velocity.x, 0.0, pushed.linear_velocity.z)
	var flat_dir: Vector3 = Vector3(to_target.x, 0.0, to_target.z).normalized()
	_check(pushed.launched and flat_velocity.length() > 5.0 and flat_velocity.normalized().dot(flat_dir) > 0.95, "удар толкнул бочку к врагу (совпадение направления %.2f)" % flat_velocity.normalized().dot(flat_dir))
	await _secs(3.0)
	_check(not is_instance_valid(pushed) and target.health < target_before, "бочка долетела и взорвалась у врага (-%.0f здоровья)" % (target_before - target.health))
	await _clear()
	# Два врага: летит к ближайшему.
	_reset_player()
	var pushed2 = _barrel("acid", camera.global_position + forward * melee.settings.reach)
	var near_enemy = _enemy(Vector3(-8.0, 0.05, 13.0))
	var far_enemy = _enemy(Vector3(12.0, 0.05, 10.0))
	await _frames(2)
	melee.swing()
	await _frames(2)
	var to_near: Vector3 = near_enemy.global_position - pushed2.global_position
	to_near.y = 0.0
	_check(Vector3(pushed2.linear_velocity.x, 0.0, pushed2.linear_velocity.z).normalized().dot(to_near.normalized()) > 0.95, "из двух врагов бочка выбирает ближайшего")
	await _clear()
	# Без врагов: вперёд по направлению удара, взрыв при ударе о преграду.
	_reset_player()
	var pushed3 = _barrel("explosive", camera.global_position + forward * melee.settings.reach)
	await _frames(2)
	melee.swing()
	await _frames(2)
	_check(pushed3.launched and pushed3.linear_velocity.dot(forward) > _props.push_idle_speed * 0.8, "врагов нет: бочка летит вперёд (%.1f м/с по взгляду)" % pushed3.linear_velocity.dot(forward))
	await _secs(6.0)
	_check(not is_instance_valid(pushed3), "и взрывается при ударе о преграду")
	await _clear()
	# Выстрел толчком не считается, а удар не ломает ящики и не лечит.
	_reset_player()
	var calm = _barrel("explosive", Vector3(0.0, 1.6, 9.0))
	await _frames(2)
	_check(not calm.take_hit(DamageInfo.create(1.0, false, calm.global_position)) and calm.health == calm.definition.health - 1.0 and not calm.launched, "обычное попадание только снимает прочность, не толкает")
	await _clear()

	print("--- Ящик")
	var wooden: CrateDefinition = (load("res://data/content/props/crates/wooden.tres") as CrateDefinition).duplicate()
	wooden.money_chance = 1.0
	wooden.medkit_chance = 1.0
	wooden.part_chance = 1.0
	wooden.junk_chance = 1.0
	wooden.junk_min = 2
	wooden.junk_max = 2
	var crate = _crate_script.create(wooden, _props, 77)
	_room.add_child(crate)
	crate.global_position = Vector3(0.0, 0.0, 0.0)
	await _frames(2)
	_check(not crate.take_hit(DamageInfo.create(wooden.health * 0.4, false, crate.global_position)) and not crate.is_broken, "один слабый удар ящик выдерживает")
	_check(crate.take_hit(DamageInfo.create(wooden.health, false, crate.global_position)), "достаточный урон ломает ящик")
	await _frames(3)
	var kinds: Dictionary = {}
	var junk_count: int = 0
	var money_amount: int = 0
	for pickup in _pickups():
		var kind: String = pickup.get_script().get_global_name()
		if kind == "Pickup":
			kinds["money" if pickup.kind == 0 else "medkit"] = true
			if pickup.kind == 0:
				money_amount = int(pickup.amount)
		elif pickup.item.part != null:
			kinds["part"] = true
		elif pickup.item.definition != null and pickup.item.definition.category == ItemDefinition.Category.JUNK:
			kinds["junk"] = true
			junk_count = pickup.item.count
	_check(kinds.has("money") and kinds.has("medkit") and kinds.has("part") and kinds.has("junk") and not is_instance_valid(crate), "из ящика выпали монеты, аптечка, деталь оружия и хлам: %s" % str(kinds.keys()))
	_check(money_amount >= wooden.money_min and money_amount <= wooden.money_max and junk_count == 2, "монет %d (от %d до %d), хлама стопкой %d" % [money_amount, wooden.money_min, wooden.money_max, junk_count])
	await _clear()
	# Нулевые шансы: ничего не падает.
	var empty_def: CrateDefinition = wooden.duplicate()
	empty_def.money_chance = 0.0
	empty_def.medkit_chance = 0.0
	empty_def.part_chance = 0.0
	empty_def.junk_chance = 0.0
	var empty_crate = _crate_script.create(empty_def, _props, 5)
	_room.add_child(empty_crate)
	empty_crate.global_position = Vector3(0.0, 0.0, 0.0)
	await _frames(2)
	empty_crate.take_hit(DamageInfo.create(1000.0, false, Vector3.ZERO))
	await _frames(3)
	_check(_pickups().is_empty(), "при нулевых шансах из ящика ничего не падает")
	await _clear()
	# Выстрел оружием ломает ящик.
	_reset_player()
	var shot_def: CrateDefinition = wooden.duplicate()
	var shot_crate = _crate_script.create(shot_def, _props, 9)
	_room.add_child(shot_crate)
	shot_crate.global_position = Vector3(0.0, 1.6 - shot_def.size.y * 0.5, 9.0)
	await _frames(2)
	var crate_shots: int = ceili(shot_def.health / _player.get_weapon().stats.damage) + 1
	for i: int in crate_shots:
		if not is_instance_valid(shot_crate):
			break
		Input.action_press("fire")
		await _frames(3)
		Input.action_release("fire")
		await _secs(0.4)
	_check(not is_instance_valid(shot_crate), "ящик разбит выстрелами оружия игрока")
	await _clear()
	# Взрыв ломает ящик в радиусе.
	var blasted_crate = _crate_script.create(wooden.duplicate(), _props, 11)
	_room.add_child(blasted_crate)
	blasted_crate.global_position = Vector3(2.5, 0.0, 0.0)
	var blast_barrel = _barrel("explosive", Vector3(0.0, 0.6, 0.0))
	_reset_player(Vector3(0.0, 0.05, 30.0))
	await _frames(2)
	blast_barrel.detonate()
	await _frames(3)
	_check(not is_instance_valid(blasted_crate), "взрыв бочки ломает ящик рядом")
	await _clear()

	print("--- Хлам")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 91
	var counts: Dictionary = {}
	var all_junk: bool = true
	for i: int in 4000:
		var item: InventoryItem = JunkLoot.roll(rng, _props)
		all_junk = all_junk and item != null and item.get_category() == ItemDefinition.Category.JUNK and item.count == 1
		counts[item.definition.name_key] = int(counts.get(item.definition.name_key, 0)) + 1
	_check(all_junk, "4000 бросков дают только хлам")
	var heavy: ItemDefinition = null
	var light: ItemDefinition = null
	for item_def: ItemDefinition in _props.junk_items:
		if heavy == null or item_def.drop_weight > heavy.drop_weight:
			heavy = item_def
		if light == null or item_def.drop_weight < light.drop_weight:
			light = item_def
	var ratio: float = float(counts[heavy.name_key]) / maxf(float(counts[light.name_key]), 1.0)
	var expected_ratio: float = heavy.drop_weight / light.drop_weight
	_check(ratio > expected_ratio * 0.6 and ratio < expected_ratio * 1.6, "вес выпадения работает: частый к редкому %.1f (ждали около %.1f)" % [ratio, expected_ratio])
	var stack_item: InventoryItem = JunkLoot.roll(rng, _props, 3, 50)
	_check(stack_item.count >= 3 and stack_item.count <= stack_item.definition.max_stack, "стопка не больше размера стопки предмета (%d из %d)" % [stack_item.count, stack_item.definition.max_stack])
	var inventory = root.get_node("Inventory")
	inventory.clear()
	var junk_item: InventoryItem = InventoryItem.from_definition(light, 1)
	var weapon_item: InventoryItem = InventoryItem.from_weapon(WeaponGenerator.new(root.get_node("Config").data.weapons).generate(rng, 1))
	inventory.add(junk_item)
	inventory.add(weapon_item)
	var junk_view: Array = InventoryView.build(inventory.items, InventoryView.SortKey.LEVEL, true, InventoryView.Filter.JUNK)
	_check(junk_view.size() == 1 and junk_view[0] == junk_item and junk_item.get_type_text() == tr("ITEM_CATEGORY_JUNK") and junk_item.get_price() == light.base_price, "в рюкзаке фильтр «Хлам» показывает только хлам, цена %d" % junk_item.get_price())
	var profile: CustomerProfile = CustomerProfile.new()
	profile.weapon_type = CombatEnums.WeaponType.SNIPER
	profile.manufacturer = null
	profile.likes_loose_items = false
	_check(ShopMath.matches(profile, junk_item) and not ShopMath.matches(profile, InventoryItem.from_definition(load("res://data/content/items/medkit.tres"), 1)), "хлам подходит любому покупателю (расходник без любви к мелочи нет)")
	var shop = root.get_node("Shop")
	shop.reset()
	inventory.clear()
	var pieces: int = mini(3, light.max_stack)
	var stack3: InventoryItem = InventoryItem.from_definition(light, pieces)
	inventory.add(stack3)
	_check(shop.actual_price(stack3) == light.base_price * pieces, "стопка из %d продаётся по цене всех штук (%d)" % [pieces, shop.actual_price(stack3)])
	_check(shop.place(0, stack3, shop.actual_price(stack3)) and shop.counters[0].price == light.base_price * pieces, "стопку хлама можно выставить на прилавок")
	shop.reset()
	inventory.clear()

	print("--- Расстановка по комнатам")
	var catalog: Array[RoomDefinition] = RoomCatalog.load_all()
	var combat_def: RoomDefinition = null
	var loot_def: RoomDefinition = null
	for definition: RoomDefinition in catalog:
		if definition.kind == RoomDefinition.Kind.COMBAT and combat_def == null:
			combat_def = definition
		if definition.kind == RoomDefinition.Kind.LOOT and loot_def == null:
			loot_def = definition
	for pair: Array in [[combat_def, false, Vector3(300.0, 0.0, 0.0)], [loot_def, true, Vector3(600.0, 0.0, 0.0)]]:
		var definition: RoomDefinition = pair[0]
		var is_loot: bool = pair[1]
		var room: RoomPiece = definition.scene.instantiate() as RoomPiece
		root.add_child(room)
		room.global_position = pair[2]
		await _frames(6)
		var holder_a: Node3D = Node3D.new()
		root.add_child(holder_a)
		var made_a: Dictionary = _scatter_script.scatter(room, is_loot, _props, 1.0, 1234, holder_a)
		var barrels_max: int = _props.loot_barrels_max if is_loot else _props.combat_barrels_max
		var crates_min: int = _props.loot_crates_min if is_loot else _props.combat_crates_min
		var crates_max: int = _props.loot_crates_max if is_loot else _props.combat_crates_max
		var label: String = "кладовая" if is_loot else "боевая комната"
		_check(int(made_a["barrels"]) <= barrels_max and int(made_a["crates"]) <= crates_max and int(made_a["crates"]) >= mini(crates_min, 2) and holder_a.get_child_count() == int(made_a["barrels"]) + int(made_a["crates"]), "%s: бочек %d (не больше %d), ящиков %d (%d-%d)" % [label, made_a["barrels"], barrels_max, made_a["crates"], crates_min, crates_max])
		await _frames(3)
		var space: PhysicsDirectSpaceState3D = room.get_world_3d().direct_space_state
		var entrances: Array[Vector3] = []
		for entrance: RoomEntrance in room.get_entrances():
			entrances.append(entrance.global_position)
		var grounded: bool = true
		var clear_of_doors: bool = true
		var spaced: bool = true
		var positions: Array[Vector3] = []
		for prop: Node3D in holder_a.get_children():
			var base: Vector3 = prop.global_position
			var ray: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(base + Vector3.UP * 0.5, base + Vector3.DOWN * 1.5, 1))
			grounded = grounded and not ray.is_empty() and absf((ray["position"] as Vector3).y - base.y) < 0.9
			for entrance_position: Vector3 in entrances:
				clear_of_doors = clear_of_doors and Vector2(entrance_position.x - base.x, entrance_position.z - base.z).length() >= _props.entrance_clearance - 0.01
			for other: Vector3 in positions:
				spaced = spaced and Vector2(other.x - base.x, other.z - base.z).length() >= _props.min_spacing - 0.01
			positions.append(base)
		_check(grounded and clear_of_doors and spaced, "%s: все предметы на опоре, не у проёмов (%.1f м), не ближе %.1f м друг к другу" % [label, _props.entrance_clearance, _props.min_spacing])
		# Повторяемость: тот же сид даёт те же места.
		holder_a.free()
		await _frames(3)
		var holder_b: Node3D = Node3D.new()
		root.add_child(holder_b)
		var made_b: Dictionary = _scatter_script.scatter(room, is_loot, _props, 1.0, 1234, holder_b)
		var same: bool = int(made_b["barrels"]) == int(made_a["barrels"]) and int(made_b["crates"]) == int(made_a["crates"]) and holder_b.get_child_count() == positions.size()
		for i: int in mini(positions.size(), holder_b.get_child_count()):
			same = same and positions[i].distance_to(holder_b.get_child(i).global_position) < 0.01
		_check(same, "%s: тот же сид даёт те же места" % label)
		holder_b.free()
		room.free()
		await _frames(2)
	var disabled_copy: PropSettings = _props.duplicate()
	disabled_copy.enabled = false
	var off_room: RoomPiece = combat_def.scene.instantiate() as RoomPiece
	root.add_child(off_room)
	var off_holder: Node3D = Node3D.new()
	root.add_child(off_holder)
	var off: Dictionary = _scatter_script.scatter(off_room, false, disabled_copy, 1.0, 5, off_holder)
	_check(int(off["barrels"]) == 0 and int(off["crates"]) == 0 and off_holder.get_child_count() == 0, "при enabled = false ничего не ставится")
	off_holder.free()
	off_room.free()
