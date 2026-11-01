@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: забег целиком в игре (срез 7, №82): сцена run/run.tscn. Шлюз с волнами (двери, волны одна за другой, портал, переход
## в следующую зону), шлюз с элитным врагом, эвакуационная комната (оплата деньгами и лутом через экран инвентаря, отстоять
## волны, панель терминала), комната босса отдела (босс, приспешники, победа и конец забега), магазин (цены, покупка),
## смерть (итоги, потеря лута) и новый забег.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_run_flow.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.

var _fails: int = 0
var _scene: Node
var _builder
var _player
var _hud
var _config
var _progress
var _inventory
var _run
var _settings: ZoneSettings
var _run_settings
var _catalog: Array[RoomDefinition]
var _wave_pause_before: float = 0.0


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _secs(seconds: float) -> void:
	await _frames(int(seconds * 120.0))


func _initialize() -> void:
	create_timer(1200.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	_config = root.get_node("Config")
	_progress = root.get_node("Progress")
	_inventory = root.get_node("Inventory")
	_run = root.get_node("Run")
	_settings = _config.data.zones
	_run_settings = _config.data.run
	_catalog = RoomCatalog.load_all()
	_settings.debug_seed = 4242
	root.size = Vector2i(1920, 1080)
	_scene = (load("res://run/run.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	_builder = _scene.get_node("Zone")
	_player = _scene.get_node("Player")
	_hud = _scene.get_node("Hud")
	await _wait_built()
	_wave_pause_before = _run_settings.wave_pause
	_run_settings.wave_pause = 0.2
	await _test_start()
	await _test_gate_waves()
	await _test_gate_elite()
	await _test_evacuation()
	await _test_boss_room()
	await _test_shop()
	await _test_death_and_new_run()
	_run_settings.wave_pause = _wave_pause_before
	print("=== FAILS: ", _fails)
	quit(_fails)


func _wait_built() -> void:
	# Зона строится вместе с ожиданием карты навигации: на крупной зоне это тысячи кадров.
	for i: int in 20000:
		await process_frame
		if _scene.layout != null and not _scene._busy:
			break
	await _frames(5)


# Строит зону заданного номера с заданными сидами (сид забега определяет эвакуацию, сид зоны планировку).
func _load_zone(zone: int, debug_seed: int, run_seed: int) -> void:
	_settings.debug_seed = debug_seed
	_scene.run_seed = run_seed
	if not _run.active:
		_run.start(run_seed)
		await _wait_built()
	_run.set_zone(zone)
	await _wait_built()


# Сид зоны, при котором раскладка удовлетворяет условию (ищется генератором, без построения).
func _find_seed(zone: int, run_seed: int, predicate: Callable) -> int:
	for debug_seed: int in range(1, 400):
		var layout: ZoneLayout = ZoneGenerator.new().generate(_catalog, _settings, zone, run_seed, hash([debug_seed, zone]), _progress.world_level)
		if layout.warnings.is_empty() and predicate.call(layout):
			return debug_seed
	return 0


func _has_kind(layout: ZoneLayout, kind: int, gate_mode: int = -1) -> bool:
	for piece: PlacedPiece in layout.pieces:
		if piece.kind() == kind and (gate_mode < 0 or piece.definition.gate_mode == gate_mode):
			return true
	return false


func _challenge(mode: int):
	for challenge in _builder.challenges:
		if challenge.mode == mode:
			return challenge
	return null


# Игрок встаёт на пол внутри комнаты (на самый нижний маркер появления врагов, ближайший к центру): там срабатывает зона входа.
func _stand_in(room: RoomPiece) -> void:
	var center: Vector3 = room.global_transform * (room.get_bounds().get_center() * Vector3(1, 0, 1))
	var best: Vector3 = center
	var best_rank: float = INF
	for marker: Marker3D in room.get_markers(&"enemy_spawn"):
		var point: Vector3 = marker.global_position
		var rank: float = point.y * 1000.0 + Vector2(point.x - center.x, point.z - center.z).length()
		if rank < best_rank:
			best_rank = rank
			best = point
	_player.velocity = Vector3.ZERO
	_player.global_position = best + Vector3(0.0, 0.1, 0.0)


func _kill_all(director) -> void:
	for enemy in director.enemies.duplicate():
		enemy.set_physics_process(false)
		enemy.take_hit(DamageInfo.create(1.0e9, false, enemy.global_position + Vector3(0, 1, 0)))


func _doors_closed(challenge, closed: bool) -> bool:
	if challenge.doors.is_empty():
		return false
	for door in challenge.doors:
		if door.is_closed != closed:
			return false
	return true


# --- Старт забега.
func _test_start() -> void:
	print("--- Старт забега")
	_check(_run.active and _run.zone == 1 and _scene.zone_number == 1 and _scene.layout != null, "забег идёт, первая зона построена")
	_check(not _hud._death_screen.visible and not _hud.shows_death_screen, "собственный экран смерти HUD выключен: его заменяет экран итогов")
	_check(_hud._zone_label.visible and _hud._zone_label.text.contains("1/%d" % _settings.zones_in_department), "в HUD видна зона: «%s»" % _hud._zone_label.text.strip_edges())
	_check(_has_kind(_scene.layout, RoomDefinition.Kind.GATE) and _scene.layout.count(RoomDefinition.Kind.GATE) == 1, "в зоне 1 есть ровно один шлюз")
	# Бочки и ящики (№91): только в боевых комнатах и кладовых, в стартовой, шлюзе, эвакуации, боссе и магазине их нет.
	var props_root: Node = _builder.get_node_or_null("Props")
	var props_total: int = props_root.get_child_count() if props_root != null else 0
	var misplaced: int = 0
	for prop: Node3D in props_root.get_children() if props_root != null else []:
		var inside_allowed: bool = false
		for piece: PlacedPiece in _scene.layout.pieces:
			var room: RoomPiece = _builder.pieces[piece.index]
			if room.get_bounds().has_point(room.to_local(prop.global_position)) and (piece.kind() == RoomDefinition.Kind.COMBAT or piece.kind() == RoomDefinition.Kind.LOOT):
				inside_allowed = true
		if not inside_allowed:
			misplaced += 1
	_check(props_total > 0 and misplaced == 0, "в зоне расставлены бочки и ящики (%d), все в боевых комнатах и кладовых" % props_total)


# --- Шлюз с волнами.
func _test_gate_waves() -> void:
	print("--- Шлюз с волнами")
	var run_seed: int = 31
	var found: int = _find_seed(1, run_seed, func(l: ZoneLayout) -> bool: return _has_kind(l, RoomDefinition.Kind.GATE, RoomDefinition.GateMode.WAVES))
	_check(found != 0, "нашёлся сид зоны со шлюзом с волнами (%d)" % found)
	await _load_zone(1, found, run_seed)
	var challenge = _challenge(0)
	_check(challenge != null and challenge.state == 0 and not challenge.portal.is_open and challenge.waves_total == 0, "шлюз ждёт игрока, портал закрыт")
	_check(_doors_closed(challenge, false), "двери шлюза до входа открыты")
	_stand_in(challenge.room)
	await _frames(40)
	var first: int = ZoneMath.wave_enemy_count(_run_settings, 1, 1)
	_check(challenge.state == 1 and challenge.wave == 1 and challenge.waves_total == _run_settings.gate_waves, "вход игрока начал волну 1 из %d" % challenge.waves_total)
	_check(challenge.director.enemies_alive == first and _doors_closed(challenge, true), "в волне %d врагов, двери закрыты" % challenge.director.enemies_alive)
	_check(_hud._objective.visible and _hud._objective.text.contains("1/%d" % challenge.waves_total), "цель на экране: «%s»" % _hud._objective.text)
	for wave: int in range(1, challenge.waves_total):
		_kill_all(challenge.director)
		await _secs(0.6)
		_check(challenge.wave == wave + 1 and challenge.state == 1 and challenge.director.enemies_alive == ZoneMath.wave_enemy_count(_run_settings, 1, wave + 1), "волна %d побеждена, пошла волна %d (%d врагов)" % [wave, wave + 1, challenge.director.enemies_alive])
	_check(not challenge.portal.is_open, "пока последняя волна не побеждена, портал закрыт")
	_kill_all(challenge.director)
	await _frames(10)
	_check(challenge.state == 3 and challenge.portal.is_open and _doors_closed(challenge, false), "последняя волна побеждена: двери открыты, портал горит")
	_check(_hud._objective.text == tr("OBJ_PORTAL_OPEN"), "цель на экране: «%s»" % _hud._objective.text)
	# Портал переносит в следующую зону.
	_player.velocity = Vector3.ZERO
	_player.global_position = challenge.portal.global_position + Vector3(0.0, 0.1, 0.0)
	await _frames(10)
	await _wait_built()
	_check(_run.zone == 2 and _scene.zone_number == 2 and _scene.layout.zone_number == 2, "вход в портал открыл зону 2")
	_check(_player.global_position.distance_to(_builder.player_spawn.global_position) < 1.5 and not _hud._objective.visible, "игрок на старте новой зоны, цель убрана")


# --- Шлюз с элитным врагом.
func _test_gate_elite() -> void:
	print("--- Шлюз с элитным врагом")
	var run_seed: int = 32
	var found: int = _find_seed(1, run_seed, func(l: ZoneLayout) -> bool: return _has_kind(l, RoomDefinition.Kind.GATE, RoomDefinition.GateMode.ELITE))
	_check(found != 0, "нашёлся сид зоны со шлюзом с элитным врагом (%d)" % found)
	await _load_zone(1, found, run_seed)
	var challenge = _challenge(1)
	_check(challenge != null and challenge.state == 0, "шлюз с элитным врагом ждёт игрока")
	_stand_in(challenge.room)
	await _frames(40)
	var elites: Array = []
	for enemy in challenge.director.enemies:
		if enemy.scene_file_path.ends_with("elite.tscn"):
			elites.append(enemy)
	var elite = elites[0] if not elites.is_empty() else null
	_check(challenge.state == 1 and elites.size() == _run_settings.elite_count and _doors_closed(challenge, true), "вход закрыл двери, вышел элитный враг (%d)" % elites.size())
	_check(elite != null and elite.get_max_health() > 0.0 and elite.settings.max_health > (load("res://data/content/enemies/chaser.tres") as EnemySettings).max_health, "элитный враг крепче обычного (%.0f здоровья)" % (elite.settings.max_health if elite != null else -1.0))
	_check(challenge.director.enemies_alive >= _run_settings.elite_count and challenge.director.enemies_alive <= _run_settings.elite_count + _run_settings.elite_escort, "элитный враг и свита из пула (%d врагов, свита до %d)" % [challenge.director.enemies_alive, _run_settings.elite_escort])
	_kill_all(challenge.director)
	await _frames(10)
	_check(challenge.state == 3 and challenge.portal.is_open and _doors_closed(challenge, false), "элитный враг побеждён: двери открыты, портал горит")


# --- Эвакуация.
func _test_evacuation() -> void:
	print("--- Эвакуация")
	# Эвакуация стоит в зонах, кратных evacuation_every (3, 6, 9: №86): проверяем в первой такой зоне.
	var evac_zone: int = _settings.evacuation_every
	var run_seed: int = 31
	_check(ZoneMath.has_evacuation(_settings, evac_zone), "в зоне %d есть комната эвакуации по правилу" % evac_zone)
	var found: int = _find_seed(evac_zone, run_seed, func(l: ZoneLayout) -> bool: return _has_kind(l, RoomDefinition.Kind.EVACUATION))
	_check(run_seed != 0 and found != 0, "нашлись сид забега и сид зоны с эвакуационной комнатой (%d, %d)" % [run_seed, found])
	await _load_zone(evac_zone, found, run_seed)
	var challenge = _challenge(3)
	var price: int = ZoneMath.evacuation_price(_run_settings, evac_zone)
	_check(challenge != null and challenge.price == price and challenge.terminal != null and challenge.state == 0, "эвакуационная комната: терминал, цена %d, способ оплаты %s" % [price, "лутом" if challenge.pays_loot else "деньгами"])
	_check(challenge.terminal.get_prompt().contains(KeyHint.text(&"interact")), "подсказка у терминала: «%s»" % challenge.terminal.get_prompt())
	# Панель терминала открывается и закрывается отменой.
	challenge.terminal.interact(_player)
	await _frames(3)
	_check(challenge._panel != null and challenge._panel.is_open() and paused, "терминал открыл панель выбора, игра на паузе")
	challenge._panel._on_cancel()
	await _frames(3)
	_check(not challenge._panel.is_open() and not paused and challenge.state == 0, "отмена закрыла панель, ничего не случилось")
	# Оплата деньгами.
	challenge.pays_loot = false
	_progress.reset()
	_progress.add_money(price - 1)
	challenge._on_choice(0)
	_check(challenge.state == 0 and _progress.money == price - 1, "денег не хватает: оплата не прошла, деньги целы")
	_progress.add_money(8)
	challenge._on_choice(0)
	_check(challenge.state == 3 and _progress.money == 7 and challenge.portal.is_open and challenge.portal.exit_kind == _run.Exit.EVACUATE, "оплата деньгами: списано %d, осталось 7, портал эвакуации горит" % price)
	# Оплата лутом через экран инвентаря.
	await _load_zone(evac_zone, found, run_seed)
	challenge = _challenge(3)
	challenge.pays_loot = true
	_inventory.clear()
	var generator: WeaponGenerator = WeaponGenerator.new(_config.data.weapons)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9
	var items: Array[InventoryItem] = []
	for i: int in 6:
		var item: InventoryItem = InventoryItem.from_weapon(generator.generate(rng, 1))
		items.append(item)
		_inventory.add(item)
	var paid: Dictionary = {"total": -1}
	var screen = _hud._inventory_screen
	var total_value: int = challenge.loot_value()
	_check(total_value >= price, "ценность лута в рюкзаке %d, цена выхода %d" % [total_value, price])
	challenge._on_choice(1)
	await _frames(5)
	_check(screen.is_open() and screen.is_payment_mode() and screen.marked_total() == 0 and screen._pay_button.disabled, "выбран «лутом»: экран инвентаря в режиме оплаты, ничего не выбрано, кнопка недоступна")
	var marked_sum: int = 0
	for item: InventoryItem in items:
		if marked_sum >= price:
			break
		screen._marked.append(item)
		marked_sum += item.get_total_price()
		screen._refresh()
		if marked_sum < price:
			_check(screen._pay_button.disabled, "выбрано на %d из %d: кнопка недоступна" % [marked_sum, price])
	_check(marked_sum >= price and not screen._pay_button.disabled and screen.marked_total() == marked_sum, "выбрано на %d (цена %d): кнопка «Заплатить» доступна" % [marked_sum, price])
	var count_before: int = _inventory.items.size()
	var marked_count: int = screen._marked.size()
	screen._on_pay_pressed()
	await _frames(5)
	_check(not screen.is_open() and not paused and _inventory.items.size() == count_before - marked_count, "оплата прошла: %d выбранных предметов убраны из рюкзака, экран закрыт" % marked_count)
	_check(challenge.state == 3 and challenge.portal.is_open, "оплата лутом открыла портал")
	# Закрытие экрана без оплаты ничего не отнимает.
	await _load_zone(evac_zone, found, run_seed)
	challenge = _challenge(3)
	challenge.pays_loot = true
	_inventory.clear()
	for item: InventoryItem in items:
		_inventory.add(item)
	var before: int = _inventory.items.size()
	challenge._on_choice(1)
	await _frames(5)
	screen._marked.append(items[0])
	screen.close()
	await _frames(3)
	_check(_inventory.items.size() == before and challenge.state == 0 and not screen.is_payment_mode(), "закрыли экран без оплаты: предметы на месте, комната ждёт")
	# Отстоять волны.
	challenge._on_choice(2)
	await _frames(40)
	_check(challenge.state == 1 and challenge.wave == 1 and challenge.waves_total == _run_settings.evacuation_waves and _doors_closed(challenge, true), "выбраны волны: началась волна 1 из %d, двери закрыты" % challenge.waves_total)
	for wave: int in range(1, challenge.waves_total + 1):
		_kill_all(challenge.director)
		await _secs(0.6)
	_check(challenge.state == 3 and challenge.portal.is_open and _doors_closed(challenge, false), "волны отстояты: двери открыты, портал эвакуации горит")
	# Портал эвакуации заканчивает забег.
	_inventory.clear()
	_progress.reset()
	_player.velocity = Vector3.ZERO
	_player.global_position = challenge.portal.global_position + Vector3(0.0, 0.1, 0.0)
	await _frames(10)
	var result = _scene._result_screen
	_check(not _run.active and _run.outcome == _run.Outcome.EVACUATED and result.is_open() and paused, "портал эвакуации закончил забег и показал итоги")
	# Основной выход после забега: в магазин-хаб (срез 8). Смену сцены подменяем записью, снаряжение уезжает с игроком.
	var recorded: Array = []
	_scene.hub_changer = func(path: String) -> void: recorded.append(path)
	_run.carried_loadout = []
	result._on_to_shop()
	await _frames(3)
	_check(recorded == ["res://hub/hub.tscn"] and not paused and _run.carried_loadout.size() > 0 and _run.carried_loadout[0] != null and _run.carried_loadout[0].is_eternal, "«Вернуться в магазин»: сцена хаба, экран итогов закрыт, снаряжение несётся с игроком")
	result.present(_run.Outcome.EVACUATED, 3, 10, 0, 0, 20, 20, 0)
	result._on_new_run()
	await _wait_built()
	_check(_run.active and _run.zone == 1 and not paused, "«Новый забег» начал забег с первой зоны")


# --- Босс отдела.
func _test_boss_room() -> void:
	print("--- Босс отдела")
	var last: int = _settings.zones_in_department
	var found: int = _find_seed(last, 41, func(l: ZoneLayout) -> bool: return _has_kind(l, RoomDefinition.Kind.BOSS))
	_check(found != 0, "нашёлся сид последней зоны с комнатой босса (%d)" % found)
	await _load_zone(last, found, 41)
	var challenge = _challenge(2)
	_check(challenge != null and challenge.portal.exit_kind == _run.Exit.BOSS_VICTORY and _challenge(0) == null and _challenge(1) == null, "в последней зоне комната босса и нет шлюза")
	_stand_in(challenge.room)
	# Босс (как и все враги) появляется после паузы со свечением места (№87): ждём, пока он проснётся.
	await _frames(int(_run_settings.spawn_warning_time * 120.0) + 40)
	var boss = challenge.boss
	_check(boss != null and boss.get_script().get_global_name() == "EnemyBoss" and challenge.state == 1 and _doors_closed(challenge, true), "вход закрыл двери, появился босс отдела")
	_check(_hud._objective.visible and _hud._objective.text == tr("OBJ_BOSS"), "цель на экране: «%s»" % _hud._objective.text)
	# Во второй фазе приспешники встают на свободные места.
	var summoned_before: int = challenge.director.enemies_alive
	boss.health = boss.get_max_health() * boss.settings.phase2_health_fraction * 0.9
	await _frames(20)
	_check(boss.phase == 2 and challenge.director.enemies_alive > summoned_before, "вторая фаза: босс позвал приспешников (было %d, стало %d врагов)" % [summoned_before, challenge.director.enemies_alive])
	var world_before: int = _progress.world_level
	boss.set_physics_process(false)
	boss.take_hit(DamageInfo.create(1.0e9, false, boss.global_position + Vector3(0, 1, 0)))
	await _frames(20)
	_check(challenge.state == 3 and challenge.director.enemies_alive == 0 and challenge.portal.is_open and _doors_closed(challenge, false), "босс побеждён: приспешники не остались, двери открыты, портал горит")
	_player.velocity = Vector3.ZERO
	_player.global_position = challenge.portal.global_position + Vector3(0.0, 0.1, 0.0)
	await _frames(10)
	var expected: int = ZoneMath.next_world_level(_run_settings, world_before)
	_check(not _run.active and _run.outcome == _run.Outcome.BOSS_DEFEATED and _progress.world_level == expected and _scene._result_screen.is_open(), "портал босса закончил забег: уровень мира %d -> %d, показаны итоги" % [world_before, _progress.world_level])
	_scene._result_screen._on_new_run()
	await _wait_built()
	_progress.reset()


# --- Магазин.
func _test_shop() -> void:
	print("--- Магазин")
	var found: int = _find_seed(1, 51, func(l: ZoneLayout) -> bool: return _has_kind(l, RoomDefinition.Kind.SHOP))
	_check(found != 0, "нашёлся сид зоны с магазином (%d)" % found)
	await _load_zone(1, found, 51)
	_check(_builder.shops.size() == 1, "в зоне один магазин")
	var shop = _builder.shops[0]
	var markers: int = shop.room.get_markers(&"shop_item").size()
	var expected_weapons: int = mini(_run_settings.shop_weapons, markers)
	var expected_medkits: int = mini(_run_settings.shop_medkits, maxi(markers - expected_weapons, 0))
	var weapons: int = 0
	var medkits: int = 0
	var prices_ok: bool = true
	for pickup in shop.stock:
		if pickup.item.is_weapon():
			weapons += 1
		else:
			medkits += 1
		if pickup.price != maxi(roundi(float(pickup.item.get_price()) * _run_settings.shop_markup), 1):
			prices_ok = false
	_check(weapons == expected_weapons and medkits == expected_medkits and prices_ok, "на постаментах %d оружия и %d аптечек, цена = цена предмета x %.2f" % [weapons, medkits, _run_settings.shop_markup])
	await _frames(30)
	var pickup = shop.stock[0]
	_check(pickup.price > 0 and pickup.has_node("PriceTag") and pickup.get_prompt().contains(str(pickup.price)), "у предмета ценник, подсказка: «%s»" % pickup.get_prompt())
	_inventory.clear()
	_progress.reset()
	_progress.add_money(pickup.price - 1)
	var bought: bool = pickup.interact(_player)
	_check(not bought and _inventory.items.is_empty() and _progress.money == pickup.price - 1, "денег не хватает: покупка не прошла, деньги целы")
	_progress.add_money(5)
	var price: int = pickup.price
	bought = pickup.interact(_player)
	_check(bought and _inventory.items.size() == 1 and _progress.money == 4, "куплено за %d: предмет в рюкзаке, осталось 4" % price)
	# Полный рюкзак: покупка не проходит, деньги не списываются.
	var second = shop.stock[1] if shop.stock.size() > 1 else null
	if second != null:
		var generator: WeaponGenerator = WeaponGenerator.new(_config.data.weapons)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 3
		_inventory.clear()
		for i: int in _inventory.get_capacity():
			_inventory.add(InventoryItem.from_weapon(generator.generate(rng, 1)))
		_progress.reset()
		_progress.add_money(second.price + 10)
		var full_buy: bool = second.interact(_player)
		_check(not full_buy and _progress.money == second.price + 10 and is_instance_valid(second), "рюкзак полон: покупка не прошла, деньги целы")
	_inventory.clear()
	_progress.reset()


# --- Смерть и новый забег.
func _test_death_and_new_run() -> void:
	print("--- Смерть и новый забег")
	await _load_zone(1, 4242, 61)
	_inventory.clear()
	var generator: WeaponGenerator = WeaponGenerator.new(_config.data.weapons)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4
	for i: int in 3:
		_inventory.add(InventoryItem.from_weapon(generator.generate(rng, 1)))
	_progress.add_money(250)
	var money: int = _progress.money
	_player.take_damage(1.0e6)
	await _frames(40)
	_check(_player.is_dead and _run.active, "игрок погиб, забег ещё идёт (пауза перед итогами)")
	await _secs(1.5)
	var result = _scene._result_screen
	_check(not _run.active and _run.outcome == _run.Outcome.DEATH and result.is_open() and paused, "через пару секунд экран итогов: погиб, игра на паузе")
	_check(_inventory.items.is_empty() and _run.lost_items == 3 and _progress.money == money, "лут потерян (%d), деньги сохранились (%d)" % [_run.lost_items, _progress.money])
	result._on_new_run()
	await _wait_built()
	_check(_run.active and _run.zone == 1 and not _player.is_dead and _player.health == _player.max_health and not paused, "новый забег: первая зона, игрок жив и здоров, пауза снята")
	_check(_player.global_position.distance_to(_builder.player_spawn.global_position) < 1.5, "игрок на старте новой зоны")
