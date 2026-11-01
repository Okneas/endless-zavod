@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Враги и урон: таблица уязвимостей, стихии, четыре типа врагов, награда, уровень, смерть игрока.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_enemies.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.
## Строки «INFO» ничего не проверяют, они показывают числа, которые автор оценивает на глаз.

const FAR: Vector3 = Vector3(-17.0, 0.0, -17.0)
const PLAYER_POS: Vector3 = Vector3(0.0, 0.05, 17.0)

var _fails: int = 0
var _room: Node
var _holder: Node3D
var _player
var _hud
# Счётчики событий. Словарь, потому что лямбда захватывает обычные переменные по значению.
var _ev: Dictionary = {"proj": 0, "hurt": 0, "last_hurt": 0.0, "hurt_dist": 0.0, "died": 0, "edied": 0, "restart": 0}
var _hurt_ticks: Array[int] = []
var _proj_ticks: Array[int] = []
var _tick: int = 0
var _progress
var _config
var _projectile_script
var _pickup_script


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _info(msg: String) -> void:
	print("INFO  " + msg)


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _secs(seconds: float) -> void:
	await _frames(ceili(seconds * float(Engine.physics_ticks_per_second)))


func _release_all() -> void:
	for a: String in ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "hook", "sprint", "fire", "aim", "reload", "melee", "interact"]:
		Input.action_release(a)


# Всё созданное в проверках удаляется, чтобы разделы не влияли друг на друга.
func _clear() -> void:
	for child: Node in _holder.get_children():
		_holder.remove_child(child)
		child.free()
	for sub: Node in _room.get_node("Dummies").get_children():
		if sub is DamageNumber:
			sub.free()


func _reset_player(pos: Vector3 = PLAYER_POS) -> void:
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.rotation.y = 0.0
	_player.set_health(_player.max_health)
	_ev["hurt"] = 0
	_hurt_ticks.clear()


# Враг со своей копией настроек: числа автора в .tres не трогаем. tweak подменяет числа в копии,
# когда проверке нужна геометрия, не зависящая от размеров комнаты и правок автора.
func _spawn(path: String, pos: Vector3, yaw: float = 0.0, tweak: Dictionary = {}):
	var enemy = (load(path) as PackedScene).instantiate()
	enemy.settings = enemy.settings.duplicate()
	# Прыжок преследующего случаен по времени и сбивает замеры ходьбы и ударов: тут он выключен, его проверяет test_enemy_types.
	enemy.settings.set("leap_cooldown", 0.0)
	# Охват (боковая полоса подхода) тоже случаен по стороне: в замерах ходьбы враг идёт прямо, охват проверяет test_enemy_types.
	enemy.settings.set("flank_width", 0.0)
	for key: String in tweak:
		enemy.settings.set(key, tweak[key])
	enemy.position = pos
	enemy.rotation.y = yaw
	_holder.add_child(enemy)
	return enemy


# Враг, который игрока не замечает (радиус обнаружения почти ноль): стоит там, где поставили.
func _spawn_idle(path: String, pos: Vector3):
	return _spawn(path, pos, 0.0, {"aggro_range": 0.5})


func _hit(target, amount: float, element: int = CombatEnums.Element.NONE, weapon_type: int = CombatEnums.WeaponType.PISTOL, vulnerability: bool = true) -> bool:
	var info: DamageInfo = DamageInfo.create(amount, false, target.global_position + Vector3(0.0, 1.0, 0.0))
	info.element = element
	info.weapon_type = weapon_type
	info.apply_vulnerability = vulnerability
	return target.take_hit(info)


func _initialize() -> void:
	create_timer(600.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	_progress = root.get_node("Progress")
	_config = root.get_node("Config")
	_projectile_script = load("res://enemies/enemy_projectile.gd")
	_pickup_script = load("res://run/pickup.gd")
	_room = (load("res://rooms/test_room.tscn") as PackedScene).instantiate()
	# Врагов комнаты убираем: тесту нужны только свои, поставленные в известные места.
	_room.get_node("Enemies").free()
	root.add_child(_room)
	await _frames(10)
	_player = _room.get_node("Player")
	_hud = _room.get_node("Hud")
	_holder = Node3D.new()
	_holder.name = "TestHolder"
	_room.add_child(_holder)
	_holder.child_entered_tree.connect(func(node: Node) -> void:
		if node.get_script() == _projectile_script:
			_ev["proj"] += 1
			_proj_ticks.append(_tick))
	_player.damaged.connect(func(amount: float, _from: Vector3) -> void:
		_ev["hurt"] += 1
		_ev["last_hurt"] = amount
		_hurt_ticks.append(_tick)
		# Расстояние до ближайшего живого врага в момент удара: удар должен быть вплотную.
		var best: float = INF
		for e: Node in get_nodes_in_group(&"enemies"):
			best = minf(best, (e as Node3D).global_position.distance_to(_player.global_position))
		_ev["hurt_dist"] = best)
	_player.died.connect(func() -> void: _ev["died"] += 1)
	physics_frame.connect(func() -> void: _tick += 1)
	_progress.reset()
	# Замеры здоровья без щита: он впитывал бы урон (щиты проверяет test_shields).
	root.get_node("Inventory").shield = null
	await _run()
	_release_all()
	print("=== FAILS: ", _fails)
	quit(_fails)


func _run() -> void:
	await _test_data()
	await _test_vulnerability()
	await _test_elements()
	await _test_chaser()
	await _test_no_blocking()
	await _test_flyer()
	await _test_turret()
	await _test_support()
	await _test_rewards()
	await _test_progression()
	await _test_time_to_kill()
	await _test_player_death()
	await _test_real_restart()


# --- Данные: части-аксессуары и характеристики оружия.
func _test_data() -> void:
	print("--- Данные: аксессуары со стихиями")
	var body: WeaponPart = load("res://data/content/parts/starter_body.tres")
	var base: WeaponDefinition = WeaponDefinition.new()
	base.parts.assign([body])
	var base_stats: WeaponStats = base.compute_stats()
	_check(base_stats.element == CombatEnums.Element.NONE, "оружие без аксессуара без стихии")
	_check(base_stats.weapon_type == body.weapon_type, "тип оружия берётся из корпуса")
	var accessories: Dictionary = {
		"accessory_acid": CombatEnums.Element.ACID,
		"accessory_electric": CombatEnums.Element.ELECTRIC,
		"accessory_frost": CombatEnums.Element.FROST,
		"accessory_fire": CombatEnums.Element.FIRE,
	}
	for file_name: String in accessories:
		var part: WeaponPart = load("res://data/content/parts/%s.tres" % file_name)
		var definition: WeaponDefinition = WeaponDefinition.new()
		definition.parts.assign([body, part])
		var stats: WeaponStats = definition.compute_stats()
		_check(part.part_type == WeaponPart.PartType.ACCESSORY and stats.element == accessories[file_name], "%s: аксессуар даёт оружию стихию %s" % [file_name, CombatEnums.Element.keys()[accessories[file_name]]])
		_check(is_equal_approx(stats.damage, base_stats.damage) and is_equal_approx(stats.fire_rate, base_stats.fire_rate), "%s: числа оружия не меняет, только стихию" % file_name)
	_check(tr("PART_ACCESSORY_ACID") != "PART_ACCESSORY_ACID" and tr("ENEMY_CLASS_SWARM") != "ENEMY_CLASS_SWARM" and tr("HUD_DEAD") != "HUD_DEAD", "названия берутся из таблицы переводов, а не ключами")
	for path: String in ["chaser", "flyer", "turret", "support"]:
		var settings: EnemySettings = load("res://data/content/enemies/%s.tres" % path)
		_check(settings.max_health > 0.0 and tr(settings.name_key) != settings.name_key, "враг %s: здоровье %.0f и название «%s»" % [path, settings.max_health, tr(settings.name_key)])


# --- Таблица уязвимостей.
func _test_vulnerability() -> void:
	print("--- Таблица уязвимостей")
	var table: VulnerabilityTable = _config.data.vulnerabilities
	_check(table.plus_multiplier > 1.0 and table.minus_multiplier < 1.0, "плюс усиливает (x%.2f), минус ослабляет (x%.2f)" % [table.plus_multiplier, table.minus_multiplier])
	_info("в диздоке ±25%%; сейчас +%d%% и %d%%" % [roundi((table.plus_multiplier - 1.0) * 100.0), roundi((table.minus_multiplier - 1.0) * 100.0)])
	var classes_seen: int = 0
	for entry: ClassVulnerability in table.entries:
		classes_seen += 1
		var klass: String = CombatEnums.EnemyClass.keys()[entry.enemy_class]
		_check(not entry.plus_types.is_empty() and not entry.minus_types.is_empty(), "класс %s: есть и плюсы, и минусы" % klass)
		for weapon_type: int in entry.plus_types:
			_check(is_equal_approx(table.get_multiplier(entry.enemy_class, weapon_type), table.plus_multiplier), "класс %s: %s в плюсе" % [klass, CombatEnums.WeaponType.keys()[weapon_type]])
			_check(not entry.minus_types.has(weapon_type), "класс %s: %s не в плюсе и минусе сразу" % [klass, CombatEnums.WeaponType.keys()[weapon_type]])
		for weapon_type: int in entry.minus_types:
			_check(is_equal_approx(table.get_multiplier(entry.enemy_class, weapon_type), table.minus_multiplier), "класс %s: %s в минусе" % [klass, CombatEnums.WeaponType.keys()[weapon_type]])
	_check(classes_seen == 4, "в таблице все четыре класса (%d)" % classes_seen)
	_check(is_equal_approx(table.get_multiplier(CombatEnums.EnemyClass.HEAVY, CombatEnums.WeaponType.PISTOL), 1.0), "пистолет нейтрален для тяжёлых (стартовое оружие без бонусов и штрафов)")

	# Применение на мишени и на враге: урон меняется на множитель, ближний бой таблицу обходит.
	var dummy = _room.get_node("Dummies/TargetDummy3")
	var dummy_max: float = dummy.settings.max_health
	for entry: ClassVulnerability in table.entries:
		dummy.enemy_class = entry.enemy_class
		var klass: String = CombatEnums.EnemyClass.keys()[entry.enemy_class]
		var cases: Array = [[entry.plus_types[0], table.plus_multiplier, "плюс"], [entry.minus_types[0], table.minus_multiplier, "минус"]]
		for c: Array in cases:
			dummy.health = dummy_max
			_hit(dummy, 10.0, CombatEnums.Element.NONE, c[0])
			var lost: float = dummy_max - dummy.health
			_check(is_equal_approx(lost, 10.0 * c[1]), "мишень %s, %s (%s): урон 10 -> %.2f (x%.2f)" % [klass, CombatEnums.WeaponType.keys()[c[0]], c[2], lost, c[1]])
		dummy.health = dummy_max
		_hit(dummy, 10.0, CombatEnums.Element.NONE, entry.plus_types[0], false)
		_check(is_equal_approx(dummy_max - dummy.health, 10.0), "мишень %s: удар без таблицы (ближний бой) наносит ровно 10" % klass)
	var chaser = _spawn_idle("res://enemies/chaser.tscn", FAR)
	var chaser_entry: ClassVulnerability = null
	for entry: ClassVulnerability in table.entries:
		if entry.enemy_class == chaser.settings.enemy_class:
			chaser_entry = entry
	var amount: float = chaser.settings.max_health * 0.1
	_hit(chaser, amount, CombatEnums.Element.NONE, chaser_entry.plus_types[0])
	_check(is_equal_approx(chaser.settings.max_health - chaser.health, amount * table.plus_multiplier), "враг (класс %s): плюсовое оружие %.1f -> %.2f" % [CombatEnums.EnemyClass.keys()[chaser.settings.enemy_class], amount, chaser.settings.max_health - chaser.health])

	# Оружие игрока передаёт стихию и тип в урон.
	var weapon = _player.get_weapon()
	var saved_element: int = weapon.stats.element
	var saved_type: int = weapon.stats.weapon_type
	var saved_crit: float = weapon.stats.crit_chance
	var saved_bonus: float = weapon.crit_bonus
	weapon.stats.crit_chance = 0.0
	weapon.crit_bonus = 0.0
	weapon.stats.element = CombatEnums.Element.ACID
	weapon.stats.weapon_type = chaser_entry.minus_types[0]
	chaser.health = chaser.settings.max_health
	weapon.call("_apply_hit", chaser, chaser.global_position + Vector3(0.0, 1.0, 0.0))
	var expected: float = weapon.stats.damage * table.minus_multiplier
	_check(is_equal_approx(chaser.settings.max_health - chaser.health, expected), "выстрел игрока: тип оружия попадает в таблицу (%.1f x%.2f = %.1f)" % [weapon.stats.damage, table.minus_multiplier, chaser.settings.max_health - chaser.health])
	_check(chaser.is_acidified(), "выстрел оружия со стихией «кислота» накладывает кислоту на врага")
	weapon.stats.element = saved_element
	weapon.stats.weapon_type = saved_type
	weapon.stats.crit_chance = saved_crit
	weapon.crit_bonus = saved_bonus
	_clear()


# --- Стихии.
func _test_elements() -> void:
	print("--- Стихии: кислота, ток, мороз, огонь")
	var elements: ElementSettings = _config.data.elements
	_reset_player(PLAYER_POS)
	var enemy = _spawn_idle("res://enemies/chaser.tscn", FAR)
	var max_hp: float = enemy.settings.max_health
	var unit: float = max_hp * 0.05

	# Кислота: враг получает больше урона, пока она действует.
	_hit(enemy, unit, CombatEnums.Element.ACID, CombatEnums.WeaponType.PISTOL, false)
	_check(enemy.is_acidified(), "кислота: после попадания враг под кислотой")
	enemy.health = max_hp
	_hit(enemy, unit, CombatEnums.Element.NONE, CombatEnums.WeaponType.PISTOL, false)
	_check(is_equal_approx(max_hp - enemy.health, unit * elements.acid_damage_taken_multiplier), "кислота: следующий удар %.1f -> %.2f (x%.2f)" % [unit, max_hp - enemy.health, elements.acid_damage_taken_multiplier])

	# Ток: урон продолжается после попадания.
	var electric = _spawn_idle("res://enemies/chaser.tscn", FAR + Vector3(0.0, 0.0, 6.0))
	_hit(electric, unit, CombatEnums.Element.ELECTRIC, CombatEnums.WeaponType.PISTOL, false)
	_check(electric.is_electrified(), "ток: после попадания враг под током")
	var after_hit: float = electric.health
	await _secs(1.0)
	var dot: float = after_hit - electric.health
	var expected_dot: float = unit * elements.electric_dps_fraction
	_check(absf(dot - expected_dot) < expected_dot * 0.08, "ток: за секунду без соседей урон по времени %.2f (ожидалось %.2f)" % [dot, expected_dot])

	# Связь между врагами: соседи под током в радиусе усиливают урон по времени, не больше предела.
	_clear()
	var ring: Array = []
	var center: Vector3 = FAR
	var ring_count: int = elements.electric_chain_max_neighbors + 2
	for i: int in ring_count + 1:
		var angle: float = TAU * float(i) / float(ring_count + 1)
		ring.append(_spawn_idle("res://enemies/chaser.tscn", center + Vector3(cos(angle), 0.0, sin(angle)) * 1.6))
	for e in ring:
		_hit(e, unit, CombatEnums.Element.ELECTRIC, CombatEnums.WeaponType.PISTOL, false)
	var probe = ring[0]
	var before: float = probe.health
	await _secs(1.0)
	var chained: float = before - probe.health
	var neighbors: int = mini(ring_count, elements.electric_chain_max_neighbors)
	var expected_chain: float = unit * elements.electric_dps_fraction * (1.0 + elements.electric_chain_bonus * neighbors)
	_check(absf(chained - expected_chain) < expected_chain * 0.08, "ток: %d соседей под током усиливают урон по времени %.2f (ожидалось %.2f, предел соседей %d)" % [ring_count, chained, expected_chain, elements.electric_chain_max_neighbors])
	var lone: float = unit * elements.electric_dps_fraction
	_check(chained > lone * 1.05, "ток: цепь сильнее одиночного (%.2f против %.2f)" % [chained, lone])

	# Огонь пока заглушка: состояние ставится, урона по времени нет.
	_clear()
	var fire = _spawn_idle("res://enemies/chaser.tscn", FAR)
	_hit(fire, unit, CombatEnums.Element.FIRE, CombatEnums.WeaponType.PISTOL, false)
	var fire_hp: float = fire.health
	await _secs(1.0)
	_check(fire.is_burning() and is_equal_approx(fire.health, fire_hp), "огонь (заглушка): состояние горения есть, урона по времени пока нет")

	# Мороз: враг медленнее. Игрок в зоне видимости, меряем сдвиг за короткое время.
	_clear()
	_reset_player(PLAYER_POS)
	var normal = _spawn("res://enemies/chaser.tscn", Vector3(0.0, 0.0, 9.0))
	await _frames(3)
	var start_a: Vector3 = normal.global_position
	await _secs(0.4)
	var moved_normal: float = start_a.distance_to(normal.global_position)
	var frozen = _spawn("res://enemies/chaser.tscn", Vector3(0.0, 0.0, 9.0))
	frozen.apply_element(CombatEnums.Element.FROST, 1.0)
	_check(frozen.is_frozen() and is_equal_approx(frozen.get_speed_multiplier(), elements.frost_speed_multiplier), "мороз: враг заморожен, множитель скорости x%.2f" % elements.frost_speed_multiplier)
	normal.free()
	await _frames(3)
	var start_b: Vector3 = frozen.global_position
	await _secs(0.4)
	var moved_frozen: float = start_b.distance_to(frozen.global_position)
	_check(moved_normal > 0.5 and absf(moved_frozen / moved_normal - elements.frost_speed_multiplier) < 0.12, "мороз: за 0.4 с враг прошёл %.2f м против %.2f м без мороза (x%.2f)" % [moved_frozen, moved_normal, moved_frozen / maxf(moved_normal, 0.001)])
	_clear()

	# Длительность: все эффекты проходят сами. Ждём самый долгий.
	_reset_player(PLAYER_POS)
	var timed = _spawn_idle("res://enemies/chaser.tscn", FAR)
	timed.settings.max_health = 100000.0
	timed.health = 100000.0
	var longest: float = 0.0
	for element: int in [CombatEnums.Element.ACID, CombatEnums.Element.FROST, CombatEnums.Element.FIRE]:
		_hit(timed, 1.0, element, CombatEnums.WeaponType.PISTOL, false)
	longest = maxf(elements.acid_duration, maxf(elements.frost_duration, elements.fire_duration))
	_check(timed.is_acidified() and timed.is_frozen() and timed.is_burning(), "несколько стихий действуют одновременно")
	await _secs(longest + 0.3)
	_check(not timed.is_acidified() and not timed.is_frozen() and not timed.is_burning(), "кислота, мороз и огонь заканчиваются сами через %.0f-%.0f с" % [minf(elements.fire_duration, minf(elements.acid_duration, elements.frost_duration)), longest])
	_hit(timed, 1.0, CombatEnums.Element.ELECTRIC, CombatEnums.WeaponType.PISTOL, false)
	await _secs(elements.electric_duration + 0.3)
	_check(not timed.is_electrified(), "ток заканчивается сам через %.0f с" % elements.electric_duration)
	_clear()


# --- Преследующий.
func _test_chaser() -> void:
	print("--- Преследующий")
	_reset_player(PLAYER_POS)
	var chaser_settings: EnemySettings = load("res://data/content/enemies/chaser.tres")
	var chaser = _spawn("res://enemies/chaser.tscn", Vector3(0.0, 0.0, 17.0 - minf(chaser_settings.aggro_range * 0.7, 12.0)))
	var s: EnemySettings = chaser.settings
	var d0: float = chaser.global_position.distance_to(_player.global_position)
	await _secs(0.5)
	var d1: float = chaser.global_position.distance_to(_player.global_position)
	_check(d0 - d1 > s.move_speed * 0.5 * 0.7, "идёт к игроку: за 0.5 с дистанция %.1f -> %.1f (скорость %.1f)" % [d0, d1, s.move_speed])
	_check((-chaser.global_basis.z).dot((_player.global_position - chaser.global_position).normalized()) > 0.95, "смотрит на игрока")
	await _secs((d1 - s.melee_range) / s.move_speed + s.melee_cooldown * 2.5 + 0.5)
	_check(_ev["hurt"] >= 2, "бьёт игрока в ближнем бою (ударов %d)" % _ev["hurt"])
	if _hurt_ticks.size() >= 2:
		var interval: float = float(_hurt_ticks[1] - _hurt_ticks[0]) / float(Engine.physics_ticks_per_second)
		_check(absf(interval - s.melee_cooldown) < 0.05, "пауза между ударами %.2f с (в настройках %.2f с)" % [interval, s.melee_cooldown])
	_check(is_equal_approx(_ev["last_hurt"], s.melee_damage), "урон удара %.0f (в настройках %.0f)" % [_ev["last_hurt"], s.melee_damage])
	_check(_player.health == _player.max_health - _ev["hurt"] * ceili(s.melee_damage), "здоровье игрока упало на %d за %d ударов" % [_player.max_health - _player.health, _ev["hurt"]])
	_check(_ev["hurt_dist"] <= s.melee_range + 0.15, "удар приходится вплотную (%.2f м при дальности %.1f)" % [_ev["hurt_dist"], s.melee_range])
	_clear()

	# Вне радиуса обнаружения враг стоит, внутри идёт. Числа подменены в копии: проверка не зависит от размеров комнаты.
	_reset_player(PLAYER_POS)
	var idle = _spawn("res://enemies/chaser.tscn", Vector3(0.0, 0.0, 4.0), 0.0, {"aggro_range": 9.0})
	var idle_start: Vector3 = idle.global_position
	await _secs(1.0)
	_check(idle.global_position.distance_to(idle_start) < 0.1 and _ev["hurt"] == 0, "игрок на 13 м, радиус обнаружения 9 м: стоит на месте")
	_clear()
	var triggered = _spawn("res://enemies/chaser.tscn", Vector3(0.0, 0.0, 4.0), 0.0, {"aggro_range": 16.0})
	var trig_start: Vector3 = triggered.global_position
	await _secs(1.0)
	_check(triggered.global_position.distance_to(trig_start) > s.move_speed * 0.5, "игрок на 13 м, радиус обнаружения 16 м: идёт к игроку")
	var flyer_data: EnemySettings = load("res://data/content/enemies/flyer.tres")
	var turret_data: EnemySettings = load("res://data/content/enemies/turret.tres")
	_info("радиус обнаружения: преследующий %.0f м, летающий %.0f м, турель %.0f м (угол обзора) и %.0f м (вокруг)" % [chaser_settings.aggro_range, flyer_data.aggro_range, turret_data.shoot_range, turret_data.awareness_radius])
	_clear()

	# Ступенька 0.3 м поперёк пути: сетка навигации считает такую проходимой, а тело без прыжка нет. Упёршийся в неподвижную
	# геометрию враг подпрыгивает (№81), а упор в другого врага прыжком не считается.
	_reset_player(PLAYER_POS)
	var lip: StaticBody3D = StaticBody3D.new()
	var lip_shape: CollisionShape3D = CollisionShape3D.new()
	var lip_box: BoxShape3D = BoxShape3D.new()
	lip_box.size = Vector3(30.0, 0.3, 0.6)
	lip_shape.shape = lip_box
	lip.add_child(lip_shape)
	lip.position = Vector3(0.0, 0.15, 11.0)
	_holder.add_child(lip)
	var climber = _spawn("res://enemies/chaser.tscn", Vector3(0.0, 0.0, 6.0), 0.0, {"aggro_range": 60.0})
	await _secs(3.0)
	_check(climber.global_position.z > 11.6 or _ev["hurt"] > 0, "ступенька 0.3 м поперёк пути: враг перепрыгнул (z %.1f, ступенька на z 11)" % climber.global_position.z)
	_clear()


# --- Враги не держат игрока: зажатый толпой игрок не мог сдвинуться и погибал.
func _test_no_blocking() -> void:
	print("--- Тела врагов не блокируют игрока")
	_reset_player(PLAYER_POS)
	for i: int in 6:
		var angle: float = TAU * float(i) / 6.0
		_spawn_idle("res://enemies/chaser.tscn", PLAYER_POS + Vector3(sin(angle), 0.0, cos(angle)) * 1.1)
	await _frames(5)
	Input.action_press("move_forward")
	await _secs(1.0)
	_release_all()
	_check(_player.global_position.z < PLAYER_POS.z - 3.0, "кольцо врагов вплотную: игрок прошёл сквозь них (сдвиг %.1f м)" % (PLAYER_POS.z - _player.global_position.z))
	_check(_player.collision_mask & 4 == 0, "маска игрока не содержит слой врагов")
	_clear()


# --- Летающий.
func _test_flyer() -> void:
	print("--- Летающий")
	_reset_player(PLAYER_POS)
	var idle = _spawn_idle("res://enemies/flyer.tscn", FAR + Vector3(0.0, 2.5, 0.0))
	await _secs(1.0)
	_check(absf(idle.global_position.y - 2.5) < 0.7 and not idle.is_on_floor(), "висит в воздухе без игрока рядом (высота %.2f), не падает" % idle.global_position.y)
	_clear()
	var s: EnemySettings = (load("res://data/content/enemies/flyer.tres") as EnemySettings)
	var flyer = _spawn("res://enemies/flyer.tscn", Vector3(0.0, 4.0, 17.0 - minf(s.aggro_range * 0.7, 12.0)))
	_check(flyer.motion_mode == CharacterBody3D.MOTION_MODE_FLOATING, "летающий двигается в режиме FLOATING")
	var start: Vector3 = flyer.global_position
	await _secs(0.5)
	_check(flyer.global_position.y < start.y - 0.5 and flyer.global_position.z > start.z + 1.0, "летит к игроку по прямой в 3D (вниз и вперёд): высота %.1f -> %.1f" % [start.y, flyer.global_position.y])
	await _secs(2.5)
	_check(_ev["hurt"] >= 1 and is_equal_approx(_ev["last_hurt"], flyer.settings.melee_damage), "бьёт игрока в ближнем бою на %.0f (ударов %d)" % [flyer.settings.melee_damage, _ev["hurt"]])
	_check(absf(flyer.global_position.y - (_player.get_center_position().y + flyer.settings.fly_height_offset)) < 1.0, "держится на уровне корпуса игрока (высота %.2f)" % flyer.global_position.y)
	_check(flyer.settings.max_health < (load("res://data/content/enemies/chaser.tres") as EnemySettings).max_health, "у летающего меньше здоровья, чем у преследующего")
	_clear()


# --- Турель.
# Турель в (0, 0, z) лицом по yaw, игрок у южной стены (0, 0, 19). Возвращает число выпущенных снарядов.
# tweak подменяет числа в копии настроек, with_wall ставит стену между турелью и игроком.
func _turret_run(yaw: float, z: float, seconds: float, tweak: Dictionary = {}, with_wall: bool = false) -> int:
	_clear()
	_reset_player(Vector3(0.0, 0.05, 19.0))
	_ev["proj"] = 0
	_proj_ticks.clear()
	if with_wall:
		var wall: StaticBody3D = StaticBody3D.new()
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(8.0, 6.0, 0.3)
		shape.shape = box
		wall.add_child(shape)
		wall.position = Vector3(0.0, 2.0, (z + 19.0) * 0.5)
		_holder.add_child(wall)
	_ev["t0"] = _tick
	_spawn("res://enemies/turret.tscn", Vector3(0.0, 0.0, z), yaw, tweak)
	await _secs(seconds)
	return _ev["proj"]


func _test_turret() -> void:
	print("--- Турель")
	var s: EnemySettings = (load("res://data/content/enemies/turret.tres") as EnemySettings)
	var tps: float = float(Engine.physics_ticks_per_second)
	var burst_length: float = float(s.burst_count - 1) * s.burst_shot_interval
	var window: float = s.aim_time + maxf(s.shoot_interval, burst_length) + burst_length + 0.3
	var distance: float = minf(s.shoot_range * 0.6, 14.0)
	var near_z: float = 19.0 - distance
	var facing: float = PI
	var no_close: Dictionary = {"awareness_radius": 0.0}
	_info("турель: замечает на %.0f м в угле %.0f° и на %.0f м вокруг, помнит игрока %.1f с; очередь %d пуль по %.2f с, очереди каждые %.2f с, до %.0f урона за очередь" % [s.shoot_range, s.view_angle, s.awareness_radius, s.lose_sight_time, s.burst_count, s.burst_shot_interval, s.shoot_interval, s.projectile_damage * s.burst_count])
	_check(s.burst_count > 1 and s.awareness_radius > 0.0 and s.lose_sight_time > 0.0 and s.shoot_range > s.awareness_radius, "в данных турели заданы очередь, ближний радиус обзора и память (дальность больше ближнего радиуса)")

	var shots: int = await _turret_run(facing, near_z, window)
	_check(shots >= s.burst_count * 2, "в зоне видимости стреляет очередями: за %.1f с выпущено %d снарядов (две очереди по %d)" % [window, shots, s.burst_count])
	if _proj_ticks.size() > s.burst_count:
		var spacing_ok: bool = true
		for i: int in s.burst_count - 1:
			if absi(_proj_ticks[i + 1] - _proj_ticks[i] - roundi(s.burst_shot_interval * tps)) > 2:
				spacing_ok = false
		_check(spacing_ok, "внутри очереди пули идут через %.2f с" % s.burst_shot_interval)
		var cycle: float = float(_proj_ticks[s.burst_count] - _proj_ticks[0]) / tps
		_check(absf(cycle - maxf(s.shoot_interval, burst_length)) < 0.05, "очереди начинаются каждые %.2f с (настройка %.2f с)" % [cycle, s.shoot_interval])
		var first_delay: float = float(_proj_ticks[0] - _ev["t0"]) / tps
		_check(first_delay >= s.aim_time - 0.03, "перед первой очередью турель целится %.2f с (настройка %.2f с)" % [first_delay, s.aim_time])
	else:
		_check(false, "выпущено меньше пуль, чем нужно для проверки очередей (%d)" % _proj_ticks.size())
	_info("снаряд летит со скоростью %.0f м/с; до игрока %.0f м = %.2f с" % [s.projectile_speed, distance, distance / s.projectile_speed])

	# Поле зрения.
	shots = await _turret_run(0.0, near_z, window, no_close)
	_check(shots == 0, "игрок за спиной, ближний радиус отключён: не стреляет (%d)" % shots)
	var half: float = s.view_angle * 0.5
	shots = await _turret_run(PI + deg_to_rad(half - 15.0), near_z, window, no_close)
	_check(shots >= 1, "игрок внутри угла обзора (на %.0f° от оси из %.0f° в сторону): стреляет (%d)" % [half - 15.0, half, shots])
	shots = await _turret_run(PI + deg_to_rad(half + 15.0), near_z, window, no_close)
	_check(shots == 0, "игрок за краем угла обзора (на %.0f° от оси): не стреляет (%d)" % [half + 15.0, shots])

	# Дальность: числа подменены в копии, чтобы проверка не зависела от размеров комнаты.
	shots = await _turret_run(facing, near_z, window, {"awareness_radius": 0.0, "shoot_range": distance * 0.7})
	_check(shots == 0, "игрок на %.0f м, дальность %.0f м: не стреляет (%d)" % [distance, distance * 0.7, shots])
	shots = await _turret_run(facing, near_z, window, {"awareness_radius": 0.0, "shoot_range": distance * 1.3})
	_check(shots >= 1, "игрок на %.0f м, дальность %.0f м: стреляет (%d)" % [distance, distance * 1.3, shots])

	# Ближний радиус: вплотную турель видит игрока со всех сторон, даже за спиной.
	var close_z: float = 15.0
	shots = await _turret_run(0.0, close_z, window, {"awareness_radius": 6.0})
	_check(shots >= 1, "игрок за спиной в 4 м, ближний радиус 6 м: стреляет (%d)" % shots)
	shots = await _turret_run(0.0, close_z, window, {"awareness_radius": 0.0})
	_check(shots == 0, "то же без ближнего радиуса: не стреляет, значит дело именно в радиусе (%d)" % shots)
	shots = await _turret_run(0.0, 10.0, window, {"awareness_radius": 6.0})
	_check(shots == 0, "игрок за спиной в 9 м, ближний радиус 6 м: за радиусом не видит (%d)" % shots)
	shots = await _turret_run(0.0, close_z, window, {"awareness_radius": 6.0}, true)
	_check(shots == 0, "в ближнем радиусе, но за стеной: не видит (%d)" % shots)
	shots = await _turret_run(facing, near_z, window, {}, true)
	_check(shots == 0, "между турелью и игроком стена: не стреляет (%d)" % shots)

	# Память: игрок вышел из поля зрения, турель помнит его заданное время.
	_clear()
	_reset_player(Vector3(0.0, 0.05, 19.0))
	var memory: float = 1.0
	var remembering = _spawn("res://enemies/turret.tscn", Vector3(0.0, 0.0, near_z), facing, {"awareness_radius": 0.0, "lose_sight_time": memory})
	await _secs(0.3)
	_check(remembering.is_tracking(), "турель заметила игрока в поле зрения")
	_player.global_position = Vector3(0.0, 0.05, near_z - 6.0)
	await _secs(memory * 0.5)
	_check(remembering.is_tracking(), "игрок ушёл за спину: через %.1f с турель его ещё помнит" % (memory * 0.5))
	await _secs(memory * 0.5 + 0.3)
	_check(not remembering.is_tracking(), "через %.1f с после потери из виду турель забыла игрока" % (memory + 0.3))
	_clear()
	_reset_player(Vector3(0.0, 0.05, 19.0))
	var forgetful = _spawn("res://enemies/turret.tscn", Vector3(0.0, 0.0, near_z), facing, {"awareness_radius": 0.0, "lose_sight_time": 0.0})
	await _secs(0.3)
	_player.global_position = Vector3(0.0, 0.05, near_z - 6.0)
	await _frames(3)
	_check(not forgetful.is_tracking(), "без памяти (0 с) турель теряет игрока сразу")
	_ev["hurt"] = 0

	# Снаряд: попадание, увёртывание, стена.
	_clear()
	_reset_player(Vector3(0.0, 0.05, 19.0))
	var from: Vector3 = Vector3(0.0, 1.0, 19.0 - 10.0)
	var target: Vector3 = _player.get_center_position()
	var direction: Vector3 = (target - from).normalized()
	_projectile_script.spawn(_holder, from, direction * s.projectile_speed, s.projectile_damage, s.projectile_lifetime)
	await _secs(10.0 / s.projectile_speed + 0.4)
	_check(_ev["hurt"] == 1 and _player.health == _player.max_health - ceili(s.projectile_damage), "снаряд, летящий в игрока, попадает: -%d здоровья" % ceili(s.projectile_damage))
	_reset_player(Vector3(0.0, 0.05, 19.0))
	_projectile_script.spawn(_holder, from, direction * s.projectile_speed, s.projectile_damage, s.projectile_lifetime)
	await _frames(2)
	_player.global_position = Vector3(3.0, 0.05, 19.0)
	await _secs(10.0 / s.projectile_speed + 0.6)
	_check(_ev["hurt"] == 0 and _player.health == _player.max_health, "шаг в сторону в полёте снаряда: увернулся, урона нет")
	_projectile_script.spawn(_holder, Vector3(0.0, 1.0, 10.0), Vector3.UP * s.projectile_speed, s.projectile_damage, s.projectile_lifetime)
	await _secs(s.projectile_lifetime + 0.3)
	var alive: int = 0
	for child: Node in _holder.get_children():
		if child.get_script() == _projectile_script:
			alive += 1
	_check(alive == 0, "снаряд исчезает после %.1f с или попадания, ничего не остаётся" % s.projectile_lifetime)
	_clear()

	# Поворот головы: ограниченная скорость и наведение на цель.
	_reset_player(Vector3(0.0, 0.05, 19.0))
	var off_angle: float = half - 15.0
	var turret = _spawn("res://enemies/turret.tscn", Vector3(0.0, 0.0, near_z), PI + deg_to_rad(off_angle))
	var head: Node3D = turret.get_node("Head")
	var max_step: float = 0.0
	var previous: Vector3 = -head.global_basis.z
	var ticks: int = ceili((deg_to_rad(off_angle * 2.0) / deg_to_rad(s.turn_speed) + 0.3) * float(Engine.physics_ticks_per_second))
	for i: int in ticks:
		await physics_frame
		var current: Vector3 = -head.global_basis.z
		max_step = maxf(max_step, rad_to_deg(previous.angle_to(current)))
		previous = current
	var to_target: Vector3 = (_player.get_center_position() - head.global_position).normalized()
	var limit: float = s.turn_speed / float(Engine.physics_ticks_per_second)
	_check(max_step <= limit * 1.05 + 0.01, "голова поворачивается не быстрее %.0f°/с (за такт максимум %.2f° при пределе %.2f°)" % [s.turn_speed, max_step, limit])
	_check((-head.global_basis.z).dot(to_target) > 0.995, "голова наведена на игрока")
	_check(turret.global_position.is_equal_approx(Vector3(0.0, 0.0, near_z)), "турель сама не двигается")
	_clear()


# --- Саппорт.
func _test_support() -> void:
	print("--- Саппорт (небольшой летающий)")
	_reset_player(PLAYER_POS)
	# Вне радиуса нападения без союзников висит на месте и не падает.
	var idle = _spawn("res://enemies/support.tscn", FAR + Vector3(0.0, 2.0, 0.0))
	idle.settings = idle.settings.duplicate()
	idle.settings.aggro_range = 5.0
	await _secs(0.5)
	_check(idle.ally == null and not idle.get("_beam").visible, "без союзников никого не лечит, луча нет")
	_check(idle.motion_mode == CharacterBody3D.MOTION_MODE_FLOATING and not idle.is_on_floor() and absf(idle.global_position.y - 2.0) < 0.05, "летает: вне радиуса нападения висит на месте и не падает")
	_clear()
	# №91: без союзника лекарь нападает на игрока: подлетает и бьёт в ближнем бою.
	var lonely = _spawn("res://enemies/support.tscn", FAR + Vector3(0.0, 2.0, 0.0))
	var before: float = lonely.global_position.distance_to(_player.global_position)
	await _secs(1.5)
	_check(lonely.ally == null and lonely.global_position.distance_to(_player.global_position) < before - 5.0, "без союзников летит к игроку: %.1f -> %.1f м" % [before, lonely.global_position.distance_to(_player.global_position)])
	lonely.global_position = _player.global_position + Vector3(0.6, 1.0, 0.0)
	_player.set_health(_player.max_health)
	await _secs(2.0)
	_check(_player.health < _player.max_health and not lonely.get("_beam").visible, "добравшись, бьёт игрока в ближнем бою (здоровье %d из %d), луча нет" % [_player.health, _player.max_health])
	# Появился союзник: возвращается к лечению и перестаёт бить.
	var buddy = _spawn_idle("res://enemies/chaser.tscn", _player.global_position + Vector3(6.0, 0.0, 0.0))
	await _secs(1.0)
	_player.set_health(_player.max_health)
	_check(lonely.ally == buddy, "появился союзник: лекарь привязался к нему")
	await _secs(2.0)
	_check(_player.health == _player.max_health, "с союзником игрока не бьёт")
	_clear()

	var s: EnemySettings = (load("res://data/content/enemies/support.tres") as EnemySettings)
	var ally_a = _spawn_idle("res://enemies/chaser.tscn", FAR)
	var ally_b = _spawn_idle("res://enemies/chaser.tscn", FAR + Vector3(0.0, 0.0, 8.0))
	var support = _spawn("res://enemies/support.tscn", FAR + Vector3(s.heal_range * 0.7, 2.0, 0.0))
	var max_hp: float = ally_a.settings.max_health
	ally_a.health = max_hp * 0.5
	var start_hp: float = ally_a.health
	await _secs(2.0)
	_check(support.ally == ally_a, "привязывается к ближайшему союзнику")
	var healed: float = ally_a.health - start_hp
	var expected: float = s.heal_per_second * 2.0
	_check(absf(healed - expected) < expected * 0.1 + 0.5, "лечит союзника %.1f за 2 с (%.0f в секунду)" % [healed, s.heal_per_second])
	_check(support.get("_beam").visible, "луч привязки виден, пока идёт лечение")
	await _secs(1.5)
	var hover_y: float = ally_a.global_position.y + ally_a.settings.health_bar_height + s.hover_height
	var offset: Vector2 = Vector2(support.global_position.x - ally_a.global_position.x, support.global_position.z - ally_a.global_position.z)
	_check(offset.length() < 0.5 and absf(support.global_position.y - hover_y) < 0.25, "парит над союзником: смещение %.2f м, высота %.2f (над полоской здоровья на %.1f м)" % [offset.length(), support.global_position.y, s.hover_height])
	_check(support.global_position.y > ally_a.global_position.y + ally_a.settings.health_bar_height, "саппорт выше полоски здоровья союзника")
	ally_a.global_position += Vector3(6.0, 0.0, 0.0)
	await _secs(2.0)
	offset = Vector2(support.global_position.x - ally_a.global_position.x, support.global_position.z - ally_a.global_position.z)
	_check(offset.length() < 0.5, "союзник сместился на 6 м: саппорт полетел за ним (смещение %.2f м)" % offset.length())
	ally_a.health = max_hp - 1.0
	await _secs(0.5)
	_check(is_equal_approx(ally_a.health, max_hp), "лечение не поднимает выше максимума")
	ally_a.health = max_hp
	_hit(ally_a, max_hp * 2.0, CombatEnums.Element.NONE, CombatEnums.WeaponType.PISTOL, false)
	await _secs(0.3)
	_check(support.ally == ally_b, "союзник погиб: саппорт выбрал другого")
	ally_b.health = max_hp * 0.5
	var b_start: float = ally_b.health
	await _secs(1.5)
	_check(ally_b.health > b_start + s.heal_per_second * 0.5, "и лечит нового (+%.1f)" % (ally_b.health - b_start))
	_clear()
	var supports: Array = [_spawn("res://enemies/support.tscn", FAR + Vector3(0.0, 2.0, 0.0)), _spawn("res://enemies/support.tscn", FAR + Vector3(2.0, 2.0, 0.0))]
	await _secs(0.4)
	_check(supports[0].ally == null and supports[1].ally == null, "саппорты друг друга не лечат")
	_clear()


# --- Награда за убийство, подбор.
func _pickups() -> Array:
	var result: Array = []
	for child: Node in _holder.get_children():
		if child.get_script() == _pickup_script:
			result.append(child)
	return result


func _test_rewards() -> void:
	print("--- Смерть врага и награда")
	_progress.reset()
	_reset_player(PLAYER_POS)
	var enemy = _spawn("res://enemies/chaser.tscn", Vector3(0.0, 0.0, 14.5))
	enemy.settings.xp_reward = 1
	enemy.settings.money_min = 7
	enemy.settings.money_max = 7
	enemy.settings.medkit_chance = 0.0
	enemy.died.connect(func(_e) -> void: _ev["edied"] += 1)
	var edied_before: int = _ev["edied"]
	var killed: bool = _hit(enemy, enemy.settings.max_health, CombatEnums.Element.NONE, CombatEnums.WeaponType.PISTOL, false)
	await physics_frame
	_check(killed and enemy.is_dead and not enemy.visible and enemy.collision_layer == 0, "смертельное попадание возвращает true, враг скрыт и больше не принимает выстрелы")
	_check(_ev["edied"] == edied_before + 1 and not _hit(enemy, 5.0), "сигнал died пришёл один раз, мёртвого повторно не убить")
	_check(_progress.xp == 1, "опыт за убийство начислен (xp %d)" % _progress.xp)
	var drops: Array = _pickups()
	_check(drops.size() == 1 and drops[0].kind == _pickup_script.Kind.MONEY and is_equal_approx(drops[0].amount, 7.0), "выпала монета на 7 денег (предметов %d), аптечки нет при шансе 0" % drops.size())
	await _secs(2.0)
	_check(_progress.money == 7, "деньги подтянулись к игроку и подобраны (деньги %d)" % _progress.money)
	var feed: Node = _room.get_node("Hud/Root/PickupFeed")
	_check(feed.get_child_count() >= 1 and feed.get_child_count() <= 3, "в ленте подбора есть строки (%d, не больше трёх)" % feed.get_child_count())
	_check((_room.get_node("Hud/Root/MoneyRow/MoneyLabel") as Label).text == "7", "счётчик денег в HUD показывает 7")
	_check(not is_instance_valid(enemy), "труп убран из сцены")
	_clear()

	# Аптечка: выпадает по шансу, подбирается только при неполном здоровье.
	var medic = _spawn("res://enemies/chaser.tscn", Vector3(0.0, 0.0, 14.5))
	medic.settings.medkit_chance = 1.0
	medic.settings.medkit_heal = 25.0
	medic.settings.money_min = 0
	medic.settings.money_max = 0
	_hit(medic, medic.settings.max_health, CombatEnums.Element.NONE, CombatEnums.WeaponType.PISTOL, false)
	drops = _pickups()
	_check(drops.size() == 1 and drops[0].kind == _pickup_script.Kind.MEDKIT, "при шансе 100%% выпадает аптечка (предметов %d), денег при 0 нет" % drops.size())
	await _secs(2.0)
	_check(is_instance_valid(drops[0]) and _player.health == _player.max_health, "при полном здоровье аптечка лежит и не подбирается")
	_player.take_damage(40.0)
	var hp: int = _player.health
	await _secs(1.5)
	_check(_player.health == hp + 25 and not is_instance_valid(drops[0]), "при ране аптечка подбирается: %d -> %d" % [hp, _player.health])
	_clear()

	# Случайность дропа: все выпавшие деньги в диапазоне из настроек.
	var real: EnemySettings = (load("res://data/content/enemies/chaser.tres") as EnemySettings)
	var ranged = _spawn_idle("res://enemies/chaser.tscn", FAR)
	var inside: bool = true
	for i: int in 30:
		ranged.call("_drop_loot")
	for d in _pickups():
		if d.kind == _pickup_script.Kind.MONEY and (d.amount < real.money_min or d.amount > real.money_max):
			inside = false
	_check(inside, "суммы денег с врага лежат в диапазоне %d-%d" % [real.money_min, real.money_max])
	_clear()

	# Точка появления возвращает врага.
	var spawner = load("res://enemies/enemy_spawner.gd").new()
	spawner.enemy_scene = load("res://enemies/chaser.tscn")
	spawner.respawn_time = 1.0
	spawner.position = FAR
	_holder.add_child(spawner)
	var first = spawner.enemy
	_check(first != null and not first.is_dead, "точка появления создала врага")
	_hit(first, first.settings.max_health * 2.0, CombatEnums.Element.NONE, CombatEnums.WeaponType.PISTOL, false)
	await _secs(1.3)
	_check(spawner.enemy != first and spawner.enemy != null and not spawner.enemy.is_dead, "через 1 с после смерти появился новый враг")
	_clear()
	_progress.reset()


# --- Опыт, уровень, крит от уровня.
func _test_progression() -> void:
	print("--- Опыт и уровень")
	var p: ProgressionSettings = _config.data.progression
	_progress.reset()
	_check(_progress.level == p.start_level and _progress.xp == 0 and _progress.money == 0, "сброс: уровень %d, опыт 0, деньги 0" % p.start_level)
	var need: int = maxi(1, roundi(p.xp_base * pow(float(_progress.level), p.xp_exponent)))
	_check(_progress.xp_to_next() == need, "опыта до следующего уровня: %d (по формуле из настроек)" % need)
	var levels: Array = []
	_progress.level_changed.connect(func(level: int) -> void: levels.append(level))
	_progress.add_xp(need - 1)
	_check(_progress.level == p.start_level and _progress.xp == need - 1, "на единицу меньше порога: уровень прежний")
	_progress.add_xp(1)
	_check(_progress.level == p.start_level + 1 and _progress.xp == 0 and levels == [p.start_level + 1], "ровно порог: уровень +1, опыт сгорает в ноль, сигнал один раз")
	var need2: int = _progress.xp_to_next()
	var need3: int = maxi(1, roundi(p.xp_base * pow(float(_progress.level + 1), p.xp_exponent)))
	levels.clear()
	_progress.add_xp(need2 + need3 + 5)
	_check(_progress.level == p.start_level + 3 and _progress.xp == 5, "много опыта сразу: два уровня подряд, остаток 5 (уровень %d, опыт %d)" % [_progress.level, _progress.xp])
	_check(levels.size() == 2, "по сигналу на каждый уровень (%d)" % levels.size())
	_check(is_equal_approx(_progress.get_crit_bonus(), float(_progress.level - 1) * p.crit_per_level), "уровень даёт шанс крита +%.1f%% за уровень (сейчас %.1f%%)" % [p.crit_per_level * 100.0, _progress.get_crit_bonus() * 100.0])
	var weapon = _player.get_weapon()
	_check(is_equal_approx(weapon.crit_bonus, _player.settings.crit_chance + _progress.get_crit_bonus()), "шанс крита оружия игрока = крит игрока + бонус уровня (%.1f%%)" % (weapon.crit_bonus * 100.0))
	_progress.level = p.max_level - 1
	_progress.xp = 0
	_progress.add_xp(1000000)
	_check(_progress.level == p.max_level and _progress.xp == 0 and _progress.xp_to_next() == 0, "верхний уровень %d: опыт не копится" % p.max_level)
	_progress.add_xp(500)
	_check(_progress.level == p.max_level and _progress.xp == 0, "на верхнем уровне опыт игнорируется")
	_progress.reset()
	_check(is_equal_approx(weapon.crit_bonus, _player.settings.crit_chance), "после сброса крит возвращается к базовому")
	var badge: Node = _room.get_node("Hud/Root/LevelBadge")
	_check(badge is Control, "кружок уровня на месте в HUD")


# --- Время убийства (оценивает автор, тест только считает).
func _test_time_to_kill() -> void:
	print("--- Время убийства стартовым пистолетом (справочно)")
	var stats: WeaponStats = _player.get_weapon().stats
	for path: String in ["chaser", "flyer", "turret", "support"]:
		var s: EnemySettings = load("res://data/content/enemies/%s.tres" % path)
		var mult: float = _config.data.vulnerabilities.get_multiplier(s.enemy_class, stats.weapon_type)
		var shots: int = ceili(s.max_health / (stats.damage * mult))
		var seconds: float = float(shots - 1) / stats.fire_rate
		_info("%s: здоровье %.0f, выстрелов %d, время %.2f с (цель из диздока 0.3-1.0 с у рядового врага)" % [path, s.max_health, shots, seconds])


# --- Гибель игрока, экран, перезапуск. Раздел последний: игрок остаётся мёртвым.
func _test_player_death() -> void:
	print("--- Игрок: урон, лечение, гибель")
	_clear()
	_reset_player(PLAYER_POS)
	var max_hp: int = _player.max_health
	_player.take_damage(30.0)
	_check(_player.health == max_hp - 30 and _ev["hurt"] == 1, "урон 30: здоровье %d -> %d, сигнал damaged" % [max_hp, _player.health])
	_player.take_damage(0.2)
	_check(_player.health == max_hp - 31, "дробный урон округляется вверх до целого здоровья (%d)" % _player.health)
	_player.heal(5.0)
	_check(_player.health == max_hp - 26, "лечение +5 (%d)" % _player.health)
	_player.heal(1000.0)
	_check(_player.health == max_hp, "лечение не выше максимума")
	_check(not _player.is_dead and not _room.get_node("Hud/Root/DeathScreen").visible, "живой игрок: экран смерти скрыт")

	var weapon = _player.get_weapon()
	var ammo: int = weapon.ammo
	_ev["died"] = 0
	_player.take_damage(float(max_hp + 10))
	await _frames(3)
	_check(_player.is_dead and _player.health == 0 and _ev["died"] == 1, "смертельный урон: здоровье 0, сигнал died один раз")
	var screen: Control = _room.get_node("Hud/Root/DeathScreen")
	var hint: Label = _room.get_node("Hud/Root/DeathScreen/Center/Box/DeathHint")
	_check(screen.visible, "появился экран «%s»" % tr("HUD_DEAD"))
	var interact_key: String = OS.get_keycode_string(InputMap.action_get_events("interact")[0].physical_keycode)
	_check(hint.text.contains(interact_key), "подсказка называет клавишу перезапуска (%s): «%s»" % [interact_key, hint.text])
	_player.take_damage(10.0)
	_check(_player.health == 0 and _ev["died"] == 1, "по мёртвому урон не проходит и смерть не повторяется")
	Input.action_press("move_forward")
	Input.action_press("jump")
	var before: Vector3 = _player.global_position
	await _secs(0.3)
	Input.action_release("move_forward")
	Input.action_release("jump")
	_check(_player.global_position.distance_to(before) < 0.05, "мёртвый игрок не двигается")
	Input.action_press("fire")
	await _secs(0.3)
	Input.action_release("fire")
	_check(weapon.ammo == ammo, "мёртвый игрок не стреляет")
	_ev["hurt"] = 0
	var enemy = _spawn("res://enemies/chaser.tscn", Vector3(0.0, 0.0, 12.0))
	await _secs(2.5)
	_check(_ev["hurt"] == 0 and enemy.global_position.distance_to(Vector3(0.0, 0.0, 12.0)) < 0.1, "враги мёртвого игрока не преследуют и не бьют")

	# Перезапуск по клавише действия «interact» (в игре по умолчанию перезагружает сцену).
	_hud.restart_action = func() -> void: _ev["restart"] += 1
	await _frames(3)
	Input.action_press("interact")
	await _frames(4)
	Input.action_release("interact")
	await _frames(3)
	_check(_ev["restart"] == 1, "клавиша перезапуска вызывает перезапуск ровно один раз (%d)" % _ev["restart"])
	_release_all()


# Настоящий путь перезапуска: без restart_action HUD перезагружает текущую сцену, деньги и опыт остаются.
func _test_real_restart() -> void:
	print("--- Перезапуск сцены по клавише")
	_room.free()
	_progress.reset()
	_progress.add_money(12)
	change_scene_to_file("res://rooms/test_room.tscn")
	await _frames(10)
	var scene: Node = current_scene
	var player = scene.get_node("Player")
	player.take_damage(1000.0)
	await _frames(3)
	_check(player.is_dead and scene.get_node("Hud/Root/DeathScreen").visible, "в главной сцене игрок гибнет, экран смерти показан")
	Input.action_press("interact")
	await _frames(4)
	Input.action_release("interact")
	await _frames(10)
	var again: Node = current_scene
	var player_again = again.get_node("Player")
	_check(again != scene and not player_again.is_dead and player_again.health == player_again.max_health, "перезагрузка создала новую сцену: игрок жив, здоровье полное")
	_check(not again.get_node("Hud/Root/DeathScreen").visible, "экран смерти в новой сцене закрыт")
	_check(_progress.money == 12 and (again.get_node("Hud/Root/MoneyRow/MoneyLabel") as Label).text == "12", "деньги пережили перезапуск (%d)" % _progress.money)
	_progress.reset()