@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: забег (срез 7, №82): формулы (волны, цена эвакуации, способ оплаты, сила врагов по уровню зоны, уровень мира), состояние
## забега Run (зоны, исходы, смерть отнимает весь невечный лут, победа над боссом поднимает уровень мира), множители врагов,
## босс отдела (ударная волна: урон на земле и пролёт над ней в прыжке, вторая фаза со скоростью и призывом).
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_run.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.

var _fails: int = 0
var _room: Node
var _player
var _config
var _progress
var _inventory
var _run
var _holder: Node3D


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
	create_timer(600.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	_config = root.get_node("Config")
	_progress = root.get_node("Progress")
	_inventory = root.get_node("Inventory")
	_run = root.get_node("Run")
	_room = (load("res://rooms/test_room.tscn") as PackedScene).instantiate()
	_room.get_node("Enemies").free()
	root.add_child(_room)
	await _frames(10)
	_player = _room.get_node("Player")
	_holder = Node3D.new()
	_room.add_child(_holder)
	_progress.reset()
	_test_math()
	await _test_run_state()
	await _test_death_loss()
	await _test_enemy_scaling()
	await _test_boss()
	print("=== FAILS: ", _fails)
	quit(_fails)


# --- Формулы забега.
func _test_math() -> void:
	print("--- Формулы забега")
	var run = _config.data.run
	var zones = _config.data.zones
	_check(run != null and run.elite_scene != null and run.boss_scene != null and run.shop_medkit != null, "настройки забега назначены: элитный враг, босс, аптечка магазина")
	var ok: bool = true
	var previous: int = 0
	for wave: int in range(1, 8):
		var count: int = ZoneMath.wave_enemy_count(run, 1, wave)
		if count < previous or count < 1 or count > run.wave_enemies_max:
			ok = false
		previous = count
	_check(ok and ZoneMath.wave_enemy_count(run, zones.zones_in_department, 7) >= ZoneMath.wave_enemy_count(run, 1, 1), "врагов в волне растёт с волной и зоной, в пределах от 1 до %d" % run.wave_enemies_max)
	_check(ZoneMath.evacuation_price(run, 5) == roundi(5.0 * float(run.evacuation_price) * run.evacuation_price_modifier), "цена эвакуации = номер зоны x стандартная цена x модификатор (зона 5: %d)" % ZoneMath.evacuation_price(run, 5))
	var loot_count: int = 0
	var repeat_ok: bool = true
	for seed_value: int in 200:
		var first: bool = ZoneMath.evacuation_pays_loot(run, seed_value, 3)
		if first != ZoneMath.evacuation_pays_loot(run, seed_value, 3):
			repeat_ok = false
		if first:
			loot_count += 1
	var expected_share: float = run.evacuation_loot_chance
	_check(repeat_ok and absf(float(loot_count) / 200.0 - expected_share) < 0.15, "способ оплаты эвакуации случаен и повторяем по сиду: лутом в %d из 200 (шанс %.2f)" % [loot_count, expected_share])
	_check(is_equal_approx(ZoneMath.enemy_health_scale(run, 1), 1.0) and ZoneMath.enemy_health_scale(run, 11) >= ZoneMath.enemy_health_scale(run, 6) and is_equal_approx(ZoneMath.enemy_damage_scale(run, 1), 1.0), "здоровье и урон врагов растут с уровнем зоны (на 1-м множитель 1.0, на 11-м %.2f и %.2f)" % [ZoneMath.enemy_health_scale(run, 11), ZoneMath.enemy_damage_scale(run, 11)])
	_check(is_equal_approx(ZoneMath.enemy_health_scale(run, 4), pow(1.0 + run.enemy_health_per_level, 3.0)) and is_equal_approx(ZoneMath.enemy_damage_scale(run, 4), pow(1.0 + run.enemy_damage_per_level, 3.0)), "рост силы врагов сложным процентом: на 4-м уровне x%.2f здоровья и x%.2f урона" % [ZoneMath.enemy_health_scale(run, 4), ZoneMath.enemy_damage_scale(run, 4)])
	_check(ZoneMath.next_world_level(run, 10) == mini(10 + run.world_level_step, run.world_level_max) and ZoneMath.next_world_level(run, run.world_level_max) == run.world_level_max, "уровень мира растёт на шаг и упирается в предел %d" % run.world_level_max)
	var gate_ok: bool = true
	for zone: int in range(1, zones.zones_in_department + 1):
		if ZoneMath.has_gate(zones, zone) == ZoneMath.has_boss(zones, zone):
			gate_ok = false
	_check(gate_ok, "в каждой зоне либо шлюз в следующую, либо босс отдела (в последней)")


# --- Состояние забега.
func _test_run_state() -> void:
	print("--- Состояние забега")
	var zones = _config.data.zones
	var events: Dictionary = {"started": 0, "zones": [], "ended": []}
	_run.run_started.connect(func() -> void: events["started"] += 1)
	_run.zone_entered.connect(func(zone: int) -> void: events["zones"].append(zone))
	_run.run_ended.connect(func(outcome: int) -> void: events["ended"].append(outcome))
	_progress.add_money(120)
	_run.start(777)
	_check(_run.active and _run.zone == 1 and events["started"] == 1 and events["zones"] == [1] and _run.run_seed == 777, "забег начался с первой зоны, сид сохранён")
	_check(_run.zone_level() == ZoneMath.zone_level(zones, _progress.world_level, 1), "уровень зоны по формуле от уровня мира")
	var last: int = zones.zones_in_department
	for i: int in range(1, last):
		_run.advance_zone()
	_check(_run.zone == last and not _run.advance_zone() and _run.zone == last, "зон в отделе %d, дальше последней идти нельзя" % last)
	_run.use_exit(_run.Exit.NEXT_ZONE)
	_check(_run.zone == last and _run.active, "портал следующей зоны в последней зоне ничего не делает")
	var world_before: int = _progress.world_level
	_run.use_exit(_run.Exit.EVACUATE)
	_check(not _run.active and _run.outcome == _run.Outcome.EVACUATED and events["ended"] == [_run.Outcome.EVACUATED] and _progress.world_level == world_before, "эвакуация заканчивает забег, уровень мира не растёт")
	_run.start(778)
	_run.use_exit(_run.Exit.BOSS_VICTORY)
	var expected: int = ZoneMath.next_world_level(_config.data.run, world_before)
	_check(_run.outcome == _run.Outcome.BOSS_DEFEATED and _progress.world_level == expected and _run.world_level_before == world_before and _run.world_level_after == expected, "победа над боссом отдела поднимает уровень мира с %d до %d" % [world_before, expected])
	_check(_progress.money == 120, "деньги забега сохраняются (%d)" % _progress.money)
	_run.finish(_run.Outcome.DEATH)
	_check(events["ended"].size() == 2, "конец забега, которого нет, ничего не делает")
	_progress.reset()


# --- Смерть: теряется весь лут без пометки «Вечный».
func _test_death_loss() -> void:
	print("--- Смерть отнимает лут")
	_inventory.clear()
	var weapon = _player.get_weapon()
	var generator: WeaponGenerator = WeaponGenerator.new(_config.data.weapons)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var medkit_item: InventoryItem = InventoryItem.from_definition(_config.data.run.shop_medkit, 3)
	_inventory.add(medkit_item)
	for i: int in 3:
		_inventory.add(InventoryItem.from_weapon(generator.generate(rng, 1)))
	weapon.equip_into(1, generator.generate(rng, 1))
	weapon.equip_into(2, generator.generate(rng, 1))
	var xp_before: int = 40
	_progress.add_xp(xp_before)
	_progress.add_money(333)
	var money_before: int = _progress.money
	var xp_now: int = _progress.xp
	var level_now: int = _progress.level
	_run.start(11)
	var backpack: int = _inventory.items.size()
	_check(backpack == 4 and weapon.occupied_count() == 3, "перед смертью: рюкзак 4 предмета, в слотах 3 оружия")
	_run.finish(_run.Outcome.DEATH, _player)
	var eternal_left: bool = true
	for item: InventoryItem in _inventory.items:
		if not item.is_eternal():
			eternal_left = false
	var slots_ok: bool = weapon.occupied_count() == 1
	for instance: WeaponInstance in weapon.slots:
		if instance != null and not instance.is_eternal:
			slots_ok = false
	_check(eternal_left and _inventory.items.is_empty() and slots_ok, "рюкзак пуст, в слотах только вечный стартовый пистолет")
	_check(_run.lost_items == 3 + 3 + 2, "потеряно предметов %d (3 оружия, 3 аптечки, 2 оружия из слотов)" % _run.lost_items)
	_check(_progress.money == money_before and _progress.xp == xp_now and _progress.level == level_now, "деньги и опыт сохранились (деньги %d)" % _progress.money)
	# Вечный пистолет, спрятанный в рюкзак, при смерти возвращается в руки.
	_progress.reset()
	_inventory.clear()
	var starter: WeaponInstance = weapon.slots[0]
	weapon.equip_into(1, generator.generate(rng, 1))
	_check(weapon.occupied_count() == 2, "готовим: два оружия в слотах")
	var kept: WeaponInstance = weapon.remove_from_slot(0)
	_inventory.add(InventoryItem.from_weapon(kept))
	weapon.equip_into(2, generator.generate(rng, 1))
	_run.start(12)
	_run.finish(_run.Outcome.DEATH, _player)
	var has_eternal: bool = false
	for instance: WeaponInstance in weapon.slots:
		if instance != null and instance.is_eternal:
			has_eternal = true
	_check(has_eternal and weapon.occupied_count() == 1 and starter == kept, "вечное оружие из рюкзака вернулось в слот, остальное потеряно")
	_progress.reset()


# --- Множители врагов по уровню зоны.
func _test_enemy_scaling() -> void:
	_inventory.shield = null
	print("--- Враги растут с уровнем зоны")
	var scene: PackedScene = load("res://enemies/chaser.tscn")
	var base_enemy = scene.instantiate()
	var base_health: float = base_enemy.settings.max_health
	var base_damage: float = base_enemy.settings.melee_damage
	base_enemy.free()
	var enemy = scene.instantiate()
	enemy.health_scale = 2.0
	enemy.damage_scale = 1.5
	_holder.add_child(enemy)
	enemy.global_position = Vector3(500.0, 0.0, 500.0)
	await _frames(2)
	_check(is_equal_approx(enemy.get_max_health(), base_health * 2.0) and is_equal_approx(enemy.health, base_health * 2.0), "множитель здоровья применён: %.0f вместо %.0f" % [enemy.health, base_health])
	var ground: StaticBody3D = _floor_at(Vector3(500.0, -0.5, 500.0))
	enemy.global_position = Vector3(500.0, 0.05, 500.0)
	_player.global_position = Vector3(500.0, 0.05, 502.0)
	_player.velocity = Vector3.ZERO
	var hits: Array = []
	var on_damage: Callable = func(amount: float, _from: Vector3) -> void: hits.append(amount)
	_player.damaged.connect(on_damage)
	await _secs(2.0)
	_player.damaged.disconnect(on_damage)
	_check(not hits.is_empty() and is_equal_approx(hits[0], base_damage * 1.5), "множитель урона применён: удар %.1f вместо %.1f" % [hits[0] if not hits.is_empty() else -1.0, base_damage])
	enemy.free()
	ground.free()
	_player.set_health(_player.max_health)


func _floor_at(center: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(120.0, 1.0, 120.0)
	shape.shape = box
	body.add_child(shape)
	body.position = center
	_holder.add_child(body)
	return body


# --- Босс отдела.
func _test_boss() -> void:
	_inventory.shield = null
	print("--- Босс отдела")
	var ground: StaticBody3D = _floor_at(Vector3(900.0, -0.5, 900.0))
	await _frames(3)
	_player.global_position = Vector3(900.0, 0.05, 920.0)
	_player.velocity = Vector3.ZERO
	var boss = (load("res://enemies/boss.tscn") as PackedScene).instantiate()
	boss.settings = boss.settings.duplicate()
	var s: EnemySettings = boss.settings
	# Числа в копии: проверка не зависит от размеров комнаты и правок автора. Босс стоит на месте, волны частые.
	s.move_speed = 0.0
	s.aggro_range = 100.0
	s.shockwave_interval = 0.6
	s.shockwave_windup = 0.2
	s.shockwave_speed = 14.0
	s.shockwave_radius = 40.0
	s.shockwave_thickness = 1.5
	s.shockwave_height = 1.1
	s.shockwave_damage = 25.0
	s.phase2_health_fraction = 0.5
	s.phase2_speed_multiplier = 1.4
	s.phase2_interval_multiplier = 0.5
	_holder.add_child(boss)
	boss.global_position = Vector3(900.0, 0.05, 900.0)
	var hits: Array = []
	var on_damage: Callable = func(amount: float, _from: Vector3) -> void: hits.append(amount)
	_player.damaged.connect(on_damage)
	var waves: Dictionary = {"count": 0}
	boss.shockwave_launched.connect(func() -> void: waves["count"] += 1)
	# Игрок на земле в 20 м: первая волна доходит до него и бьёт один раз.
	await _secs(2.6)
	_check(waves["count"] >= 1 and hits.size() >= 1 and is_equal_approx(hits[0], s.shockwave_damage), "ударная волна бьёт стоящего на земле игрока (%d волн, ударов %d, урон %.0f)" % [waves["count"], hits.size(), hits[0] if not hits.is_empty() else -1.0])
	_check(hits.size() <= waves["count"], "одна волна бьёт не больше одного раза (ударов %d из %d волн)" % [hits.size(), waves["count"]])
	# Игрок в прыжке: ступни выше высоты волны, волна проходит под ним. Физику игрока отключаем, чтобы он завис.
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_player.global_position = Vector3(900.0, s.shockwave_height + 0.6, 920.0)
	var before: int = hits.size()
	var waves_before: int = waves["count"]
	await _secs(2.6)
	_check(waves["count"] > waves_before and hits.size() == before, "волна проходит под игроком в прыжке (новых волн %d, новых ударов %d)" % [waves["count"] - waves_before, hits.size() - before])
	_player.damaged.disconnect(on_damage)
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	# Вторая фаза: на заданной доле здоровья босс быстрее и зовёт приспешников.
	var summon: Dictionary = {"scene": null, "count": 0}
	boss.summon_requested.connect(func(scene: PackedScene, count: int) -> void:
		summon["scene"] = scene
		summon["count"] = count)
	_check(boss.phase == 1 and is_equal_approx(boss.speed_multiplier, 1.0), "в начале первая фаза, скорость обычная")
	boss.health = boss.get_max_health() * s.phase2_health_fraction * 0.9
	await _frames(3)
	_check(boss.phase == 2 and is_equal_approx(boss.speed_multiplier, s.phase2_speed_multiplier), "на %.0f%% здоровья вторая фаза: скорость x%.2f" % [s.phase2_health_fraction * 100.0, boss.speed_multiplier])
	_check(summon["scene"] == s.summon_scene and summon["count"] == s.summon_count, "вторая фаза зовёт приспешников: %d из сцены %s" % [summon["count"], str(s.summon_scene.resource_path.get_file() if s.summon_scene != null else null)])
	boss.free()
	ground.free()
	_player.set_health(_player.max_health)
