@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Новые враги и правки врагов (срез 7б, №83): прыжок преследующего, наземный и летающий стрелки, камикадзе,
## турель-лучемёт, щитовик, уровень врага и табличка над ним, пул зоны.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_enemy_types.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.
## Классы врагов и игрока называть по имени тут нельзя (они тянут автозагрузки): тип сверяется по get_script().get_global_name().

const PLAYER_POS: Vector3 = Vector3(0.0, 0.05, 15.0)

var _fails: int = 0
var _room: Node
var _player


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _type_of(node: Object) -> String:
	return node.get_script().get_global_name() if node != null and node.get_script() != null else ""


func _projectiles() -> Array:
	var result: Array = []
	for child: Node in _room.get_children():
		if _type_of(child) == "EnemyProjectile":
			result.append(child)
	return result


func _reset_player() -> void:
	# Стрелки могут убить игрока посреди раздела: мёртвого игрока враги не видят, поэтому оживляем.
	if _player.is_dead:
		_player.respawn(PLAYER_POS, 0.0)
	_player.global_position = PLAYER_POS
	_player.velocity = Vector3.ZERO
	_player.rotation.y = 0.0
	_player.set_look_pitch(0.0)
	_player.set_health(_player.max_health)


func _clear_enemies() -> void:
	for node: Node in get_nodes_in_group(&"enemies"):
		node.free()
	for projectile in _projectiles():
		projectile.free()
	await _frames(2)


# Враг из сцены в точке; always_aggro, чтобы он сразу знал, где игрок. Масштабы силы задаются отдельно.
func _spawn(scene_name: String, pos: Vector3, level: int = 1, health_scale: float = 1.0, damage_scale: float = 1.0):
	var enemy = (load("res://enemies/%s.tscn" % scene_name) as PackedScene).instantiate()
	enemy.always_aggro = true
	enemy.level = level
	enemy.health_scale = health_scale
	enemy.damage_scale = damage_scale
	_room.add_child(enemy)
	enemy.global_position = pos
	return enemy


func _initialize() -> void:
	create_timer(600.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	_room = (load("res://rooms/test_room.tscn") as PackedScene).instantiate()
	_room.get_node("Enemies").free()
	root.add_child(_room)
	_room.get_node("Dummies").queue_free()
	await _frames(10)
	_player = _room.get_node("Player")
	# Замеры здоровья без щита: он впитывал бы урон (щиты проверяет test_shields).
	root.get_node("Inventory").shield = null
	await _run()
	print("=== FAILS: ", _fails)
	quit(_fails)


func _run() -> void:
	var zones: ZoneSettings = load("res://data/content/balance/zone_settings.tres")

	print("--- Сцены и данные новых врагов")
	var expected: Dictionary = {
		"gunner": ["EnemyGunner", false], "fly_shooter": ["EnemyFlyShooter", true], "bomber": ["EnemyBomber", true],
		"beam_turret": ["EnemyBeamTurret", false], "warden": ["EnemyWarden", true],
	}
	for scene_name: String in expected:
		var enemy = _spawn(scene_name, Vector3(0.0, 40.0, -40.0))
		var settings: EnemySettings = enemy.settings
		_check(_type_of(enemy) == expected[scene_name][0] and enemy.is_flier() == expected[scene_name][1] and tr(settings.name_key) != settings.name_key, "%s: класс %s, летает: %s, название «%s»" % [scene_name, _type_of(enemy), str(enemy.is_flier()), tr(settings.name_key)])
		enemy.free()
	var pool_scenes: Dictionary = {}
	for entry: EnemyPoolEntry in zones.enemy_pool:
		pool_scenes[entry.scene.resource_path.get_file().get_basename()] = entry
	var all_in_pool: bool = true
	for scene_name: String in expected:
		if not pool_scenes.has(scene_name) or pool_scenes[scene_name].weight <= 0.0:
			all_in_pool = false
	_check(all_in_pool, "все новые враги есть в пуле зоны с весом (%s)" % str(pool_scenes.keys()))
	# Стреляющие враги (турель, наземный и летающий стрелки) попадаются с первой зоны, особые (камикадзе, лучемёт, щитовик) позже.
	var shooters_first: bool = true
	for scene_name: String in ["gunner", "fly_shooter", "turret"]:
		if not pool_scenes.has(scene_name) or pool_scenes[scene_name].min_zone != 1:
			shooters_first = false
	var specials_later: bool = true
	for scene_name: String in ["bomber", "beam_turret", "warden"]:
		if not pool_scenes.has(scene_name) or pool_scenes[scene_name].min_zone < 2:
			specials_later = false
	_check(shooters_first and specials_later, "стрелки (турель, стрелок, летающий стрелок) в пуле с первой зоны, камикадзе, лучемёт и щитовик позже")
	var first_zone_weight: float = 0.0
	var shooter_weight: float = 0.0
	for entry: EnemyPoolEntry in zones.enemy_pool:
		if entry.scene != null and entry.min_zone <= 1:
			first_zone_weight += entry.weight
			if entry.scene.resource_path.get_file().get_basename() in ["gunner", "fly_shooter", "turret"]:
				shooter_weight += entry.weight
	_check(first_zone_weight > 0.0 and shooter_weight / first_zone_weight >= 0.35, "в первой зоне стрелки это %.0f%% пула (не меньше 35%%)" % (100.0 * shooter_weight / maxf(first_zone_weight, 0.001)))

	print("--- Плашка цели над прицелом и уровень врага")
	_reset_player()
	var panel = _room.get_node("Hud/Root/EnemyTargetPanel")
	await _frames(4)
	_check(panel.get_target() == null and not panel.is_showing(), "пока прицел смотрит в пустоту, плашки нет")
	var level_enemy = _spawn("chaser", Vector3(0.0, 0.05, PLAYER_POS.z - 10.0), 5, 1.5, 1.2)
	level_enemy.set_physics_process(false)
	await _frames(8)
	_check(panel.is_showing() and panel.get_target() == level_enemy, "прицел на враге: плашка показана")
	var has_world_label: bool = false
	for child: Node in level_enemy.get_children():
		if child is Label3D:
			has_world_label = true
	_check(not has_world_label, "над самим врагом в мире подписей и полосок нет")
	_check(panel.get_name_text() == tr("ENEMY_CHASER") and panel.get_level_text() == "5", "на плашке название «%s» и уровень %s" % [panel.get_name_text(), panel.get_level_text()])
	var level_color: Color = panel.get("_level_label").get_theme_color("font_color")
	_check(level_color.r > 0.9 and level_color.g < 0.5, "враг на 4 уровня выше игрока: уровень красный")
	_check(is_equal_approx(level_enemy.get_max_health(), level_enemy.settings.max_health * 1.5) and absf(panel.get_fill_ratio() - 1.0) < 0.01, "здоровье растёт с масштабом (%.0f), полоска полная" % level_enemy.get_max_health())
	level_enemy.take_hit(DamageInfo.create(level_enemy.get_max_health() * 0.4, false, level_enemy.global_position + Vector3(0, 1, 0)))
	await _frames(40)
	_check(absf(panel.get_fill_ratio() - level_enemy.health / level_enemy.get_max_health()) < 0.03 and panel.get_fill_ratio() < 0.7, "полоска упала вслед за здоровьем: %.2f" % panel.get_fill_ratio())
	_player.rotation.y = deg_to_rad(90.0)
	await _frames(int(float(panel.LINGER_TIME) * 120.0) + 25)
	_check(not panel.is_showing(), "прицел ушёл с врага: плашка погасла")
	_player.rotation.y = 0.0
	await _frames(6)
	_check(panel.is_showing(), "прицел вернулся: плашка снова показана")
	level_enemy.take_hit(DamageInfo.create(1.0e9, false, level_enemy.global_position + Vector3(0, 1, 0)))
	await _frames(6)
	_check(not panel.is_showing(), "враг погиб: плашка погасла")
	level_enemy.free()
	# Стена между прицелом и врагом закрывает его: плашки нет.
	var hidden_enemy = _spawn("chaser", Vector3(0.0, 0.05, PLAYER_POS.z - 10.0), 1, 1.0, 1.0)
	hidden_enemy.set_physics_process(false)
	var wall: StaticBody3D = StaticBody3D.new()
	var wall_shape: CollisionShape3D = CollisionShape3D.new()
	var wall_box: BoxShape3D = BoxShape3D.new()
	wall_box.size = Vector3(6.0, 6.0, 0.5)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	_room.add_child(wall)
	wall.global_position = Vector3(0.0, 3.0, PLAYER_POS.z - 5.0)
	await _frames(int(float(panel.LINGER_TIME) * 120.0) + 20)
	_check(not panel.is_showing(), "враг за стеной: плашки нет")
	wall.free()
	hidden_enemy.free()

	print("--- Охват: враги заходят на игрока с разных сторон")
	var direct_run: Dictionary = await _approach_group(false)
	var flank_run: Dictionary = await _approach_group(true)
	_check(float(direct_run["spread"]) < 6.0, "без охвата группа идёт кучей: разброс по ширине %.1f м" % float(direct_run["spread"]))
	_check(float(flank_run["spread"]) > float(direct_run["spread"]) + 3.0 and float(flank_run["spread"]) > 7.0, "с охватом группа делится и заходит с разных сторон: разброс %.1f м (от %.1f до %.1f), без охвата %.1f" % [float(flank_run["spread"]), float(flank_run["min_x"]), float(flank_run["max_x"]), float(direct_run["spread"])])
	_check(int(flank_run["arrived"]) == 8 and int(direct_run["arrived"]) == 8, "в конце все сходятся на игроке: дошли %d и %d из 8" % [int(flank_run["arrived"]), int(direct_run["arrived"])])

	print("--- Преследующий: прыжок на игрока")
	await _clear_enemies()
	_reset_player()
	var chaser = _spawn("chaser", PLAYER_POS + Vector3(0.0, 0.0, -9.0), 1, 1.0, 1.0)
	var cs: EnemySettings = chaser.settings
	chaser.set("_leap_cooldown_left", 0.0)
	var leaped: bool = false
	var telegraph_seen: bool = false
	var jumped_high: bool = false
	var hit_health: int = _player.health
	for i: int in 240:
		await physics_frame
		if chaser.get("_leap_phase") != 0:
			leaped = true
		if chaser.telegraph_amount > 0.0:
			telegraph_seen = true
		if chaser.global_position.y > 0.4:
			jumped_high = true
		if _player.health < hit_health:
			break
	_check(cs.leap_cooldown > 0.0 and leaped and telegraph_seen, "на дистанции прыжка враг замахивается (подсветка) и прыгает")
	_check(jumped_high, "в прыжке отрывается от земли (высота %.2f м)" % chaser.global_position.y)
	var taken: int = hit_health - _player.health
	var leap_damage: int = ceili(cs.melee_damage * cs.leap_damage_multiplier)
	var melee_damage: int = ceili(cs.melee_damage)
	_check(taken >= melee_damage and taken <= leap_damage, "прыжок бьёт сильнее обычного удара: урон %d (удар %d, прыжок %d)" % [taken, melee_damage, leap_damage])
	await _frames(int(cs.leap_cooldown * 120.0 * 0.5))
	_check(chaser.get("_leap_phase") == 0 and chaser.get("_leap_cooldown_left") > 0.0, "после прыжка пауза до следующего (%.1f с осталось)" % chaser.get("_leap_cooldown_left"))
	chaser.free()
	_reset_player()
	var elite = _spawn("elite", PLAYER_POS + Vector3(0.0, 0.0, -9.0))
	var elite_leaped: bool = false
	for i: int in 200:
		await physics_frame
		if elite.get("_leap_phase") != 0:
			elite_leaped = true
	_check(elite.settings.leap_cooldown == 0.0 and not elite_leaped, "у элитного врага прыжок выключен (leap_cooldown 0)")
	elite.free()

	print("--- Наземный стрелок")
	await _clear_enemies()
	_reset_player()
	var gunner = _spawn("gunner", PLAYER_POS + Vector3(0.0, 0.0, -30.0), 1, 1.0, 2.0)
	var gs: EnemySettings = gunner.settings
	var closest: float = INF
	var seen_projectiles: int = 0
	var projectile_speed_ok: bool = false
	var damaged: bool = false
	for i: int in 900:
		await physics_frame
		closest = minf(closest, gunner.global_position.distance_to(_player.global_position))
		for projectile in _projectiles():
			if projectile.get_meta("counted", false):
				continue
			projectile.set_meta("counted", true)
			seen_projectiles += 1
			if absf(projectile.velocity.length() - gs.projectile_speed) < 0.5 and is_equal_approx(projectile.damage, gs.projectile_damage * 2.0):
				projectile_speed_ok = true
		if _player.health < _player.max_health:
			damaged = true
			# Пока идёт замер, игрока лечим: иначе он погиб бы от очереди снарядов и враг перестал бы его видеть.
			_player.set_health(_player.max_health)
	_check(closest > gs.melee_range + 3.0 and closest < gs.preferred_range + 3.0, "подходит на дистанцию стрельбы и не лезет в ближний бой: ближе всего %.1f м (держится на %.0f)" % [closest, gs.preferred_range])
	_check(seen_projectiles >= 4, "стреляет одиночными снарядами: за 7.5 с выпущено %d" % seen_projectiles)
	_check(projectile_speed_ok, "снаряд летит со скоростью из настроек (%.0f м/с) и несёт урон x2 по масштабу" % gs.projectile_speed)
	_check(damaged, "снаряды стрелка достигают игрока")
	gunner.free()

	print("--- Летающий стрелок")
	await _clear_enemies()
	_reset_player()
	var flyer = _spawn("fly_shooter", PLAYER_POS + Vector3(0.0, 4.0, -30.0))
	var fs: EnemySettings = flyer.settings
	var shots: int = 0
	for i: int in 700:
		await physics_frame
		for projectile in _projectiles():
			if not projectile.get_meta("counted", false):
				projectile.set_meta("counted", true)
				shots += 1
	var flyer_distance: float = flyer.global_position.distance_to(_player.get_center_position())
	_check(flyer_distance < fs.preferred_range + 4.0 and flyer_distance > fs.retreat_range, "летающий стрелок держится на дистанции стрельбы: %.1f м (%.0f..%.0f)" % [flyer_distance, fs.retreat_range, fs.preferred_range])
	_check(shots >= 3 and flyer.global_position.y > 0.5, "стреляет с воздуха: выпущено %d снарядов, высота %.1f м" % [shots, flyer.global_position.y])
	flyer.free()
	await _clear_enemies()
	_reset_player()
	var close_flyer = _spawn("fly_shooter", PLAYER_POS + Vector3(0.0, 1.5, -3.0))
	await _frames(240)
	_check(close_flyer.global_position.distance_to(_player.get_center_position()) > fs.retreat_range - 1.5, "если подойти вплотную, пятится: теперь %.1f м (порог отступления %.0f)" % [close_flyer.global_position.distance_to(_player.get_center_position()), fs.retreat_range])
	close_flyer.free()

	print("--- Камикадзе")
	await _clear_enemies()
	_reset_player()
	var bomber = _spawn("bomber", PLAYER_POS + Vector3(0.0, 1.0, -26.0), 1, 1.0, 1.5)
	var bs: EnemySettings = bomber.settings
	var windup_seen: bool = false
	var windup_stopped: bool = false
	var charge_speed_seen: float = 0.0
	var xp_before: int = root.get_node("Progress").xp
	var pickups_before: int = get_nodes_in_group(&"item_pickups").size()
	var start_health: int = _player.health
	for i: int in 900:
		await physics_frame
		if bomber.phase == 1:
			windup_seen = true
			windup_stopped = bomber.velocity.length() < 0.5
		if bomber.phase == 2:
			charge_speed_seen = maxf(charge_speed_seen, bomber.velocity.length())
		if bomber.exploded:
			break
	_check(windup_seen and windup_stopped, "на дистанции заряда зависает и мигает (замах)")
	_check(absf(charge_speed_seen - bs.charge_speed) < 1.0, "рывок идёт со скоростью из настроек: %.1f м/с" % charge_speed_seen)
	_check(bomber.exploded and start_health - _player.health == ceili(bs.explosion_damage * 1.5), "взрыв наносит урон по масштабу: %d (ждём %d)" % [start_health - _player.health, ceili(bs.explosion_damage * 1.5)])
	await _frames(10)
	_check(bomber.is_dead and root.get_node("Progress").xp == xp_before, "взорвавшийся камикадзе погиб и награды (опыт) не дал")
	bomber.free()
	await _clear_enemies()
	# Игрок успевает отойти за замах: взрыв не задевает.
	_reset_player()
	var dodger = _spawn("bomber", PLAYER_POS + Vector3(0.0, 1.0, -22.0))
	var dodged: bool = false
	var moved_away: bool = false
	for i: int in 900:
		await physics_frame
		if dodger.phase == 2 and not moved_away:
			# Когда рывок уже начался, игрок уходит далеко от точки, куда он нацелен: камикадзе летит в прежнюю точку.
			_player.global_position = PLAYER_POS + Vector3(12.0, 0.0, 0.0)
			moved_away = true
		if dodger.exploded:
			dodged = true
			break
	_check(moved_away and dodged and _player.health == _player.max_health, "уклонился: рывок идёт в прежнюю точку, взрыв игрока не задевает (здоровье %d)" % _player.health)
	dodger.free()

	print("--- Турель-лучемёт")
	await _clear_enemies()
	_reset_player()
	var beam = _spawn("beam_turret", PLAYER_POS + Vector3(0.0, 0.0, -5.0), 1, 1.0, 1.0)
	var ts: EnemySettings = beam.settings
	var head: Node3D = beam.get_node("Head")
	var spin_before: float = head.rotation.y
	await _frames(60)
	_check(absf(head.rotation.y - spin_before) > deg_to_rad(ts.spin_speed) * 0.5 * 0.9, "голова вращается: %.0f° за 0.5 с" % rad_to_deg(head.rotation.y - spin_before))
	var pivots: int = 0
	for child: Node in head.get_children():
		if child.get_class() == "Node3D":
			pivots += 1
	_check(pivots == ts.beam_count and is_equal_approx(head.position.y, ts.beam_height), "лучей %d, высота %.2f м" % [pivots, ts.beam_height])
	# Игрок в 3 м от оси: луч проходит по нему раз за оборот, урон пока он в луче.
	_reset_player()
	_player.global_position = beam.global_position + Vector3(3.0, 0.0, 0.0)
	var total_damage: int = 0
	for i: int in int(360.0 / ts.spin_speed * 120.0) + 60:
		await physics_frame
		_player.global_position = beam.global_position + Vector3(3.0, 0.0, 0.0)
	total_damage = _player.max_health - _player.health
	_check(total_damage >= ceili(ts.beam_damage) and total_damage % ceili(ts.beam_damage) == 0, "за оборот луч бьёт игрока на расстоянии луча: получено %d урона (удар %d)" % [total_damage, ceili(ts.beam_damage)])
	_reset_player()
	_player.global_position = beam.global_position + Vector3(ts.beam_length + 2.5, 0.0, 0.0)
	for i: int in int(360.0 / ts.spin_speed * 120.0):
		await physics_frame
		_player.global_position = beam.global_position + Vector3(ts.beam_length + 2.5, 0.0, 0.0)
	_check(_player.health == _player.max_health, "дальше длины луча урона нет")
	_reset_player()
	_player.global_position = beam.global_position + Vector3(3.0, ts.beam_height + 1.0, 0.0)
	for i: int in int(360.0 / ts.spin_speed * 120.0):
		await physics_frame
		_player.velocity = Vector3.ZERO
		_player.global_position = beam.global_position + Vector3(3.0, ts.beam_height + 1.0, 0.0)
	_check(_player.health == _player.max_health, "перепрыгнул луч (ступни выше него): урона нет")
	# Стена на пути луча (№89): без неё луч достаёт до игрока на 0.7 длины, со стеной на полдлины за ней урона нет, а луч обрезан.
	var far: float = ts.beam_length * 0.7
	_reset_player()
	_player.global_position = beam.global_position + Vector3(far, 0.0, 0.0)
	for i: int in int(360.0 / ts.spin_speed * 120.0) + 60:
		await physics_frame
		_player.global_position = beam.global_position + Vector3(far, 0.0, 0.0)
	_check(_player.health < _player.max_health, "без стены луч достаёт до игрока на %.1f м" % far)
	var slab: StaticBody3D = StaticBody3D.new()
	var slab_shape: CollisionShape3D = CollisionShape3D.new()
	var slab_box: BoxShape3D = BoxShape3D.new()
	slab_box.size = Vector3(0.5, 6.0, 30.0)
	slab_shape.shape = slab_box
	slab.add_child(slab_shape)
	_room.add_child(slab)
	slab.global_position = beam.global_position + Vector3(ts.beam_length * 0.5, 3.0, 0.0)
	_reset_player()
	_player.global_position = beam.global_position + Vector3(far, 0.0, 0.0)
	var shortest: float = ts.beam_length
	for i: int in int(360.0 / ts.spin_speed * 120.0) + 60:
		await physics_frame
		_player.global_position = beam.global_position + Vector3(far, 0.0, 0.0)
		for length: float in beam._lengths:
			shortest = minf(shortest, length)
	_check(_player.health == _player.max_health, "стена на пути: за ней луч не бьёт")
	_check(shortest < ts.beam_length * 0.6, "луч обрезан по стене до %.1f м (полная длина %.1f)" % [shortest, ts.beam_length])
	slab.free()
	beam.free()

	print("--- Щитовик")
	await _clear_enemies()
	_reset_player()
	var target = _spawn("chaser", Vector3(0.0, 0.05, -10.0))
	target.set_physics_process(false)
	var warden = _spawn("warden", Vector3(0.0, 3.0, -8.0))
	var ws: EnemySettings = warden.settings
	await _frames(240)
	_check(warden.ally == target and target.warded_by == warden, "щитовик привязался к врагу и прикрыл его")
	_check(is_equal_approx(target.get_damage_taken_multiplier(), ws.ward_damage_taken), "урон по прикрытому врагу проходит на %.0f%%" % (ws.ward_damage_taken * 100.0))
	var hp: float = target.health
	target.take_hit(DamageInfo.create(100.0, false, target.global_position + Vector3(0, 1, 0)))
	var lost: float = hp - target.health
	_check(lost > 0.0 and lost <= 100.0 * ws.ward_damage_taken * 1.3 + 0.5, "выстрел на 100 урона отнял всего %.1f HP" % lost)
	warden.take_hit(DamageInfo.create(1.0e9, false, warden.global_position))
	await _frames(4)
	hp = target.health
	target.take_hit(DamageInfo.create(10.0, false, target.global_position + Vector3(0, 1, 0)))
	_check(warden.is_dead and hp - target.health > 5.0, "щитовик убит: барьер пропал, урон идёт полностью (%.1f)" % (hp - target.health))
	target.free()
	# Два щитовика берут разных врагов и не прикрывают друг друга.
	await _clear_enemies()
	var first = _spawn("chaser", Vector3(-3.0, 0.05, -10.0))
	var second = _spawn("chaser", Vector3(3.0, 0.05, -10.0))
	first.set_physics_process(false)
	second.set_physics_process(false)
	var w1 = _spawn("warden", Vector3(-3.0, 3.0, -8.0))
	var w2 = _spawn("warden", Vector3(3.0, 3.0, -8.0))
	await _frames(300)
	_check(w1.ally != null and w2.ally != null and w1.ally != w2.ally and w1.ally != w2 and w2.ally != w1, "два щитовика прикрывают разных врагов и не друг друга")
	await _clear_enemies()
	_reset_player()


# Восемь преследующих из плотной кучи в 22 м от игрока (тестовая комната 40 x 40 м). Возвращает разброс по ширине (x), когда группа ближе 14 м,
# крайние x и сколько врагов дошло до игрока ближе 4.5 м (кольцо вокруг него). flank: включён ли охват (иначе боковая полоса 0).
func _approach_group(flank: bool) -> Dictionary:
	await _clear_enemies()
	_reset_player()
	var group: Array = []
	for i: int in 8:
		var enemy = (load("res://enemies/chaser.tscn") as PackedScene).instantiate()
		enemy.settings = enemy.settings.duplicate()
		enemy.settings.set("leap_cooldown", 0.0)
		enemy.settings.set("melee_damage", 0.0)
		if not flank:
			enemy.settings.set("flank_width", 0.0)
		enemy.always_aggro = true
		_room.add_child(enemy)
		enemy.global_position = Vector3(float(i - 4) * 0.45, 0.05, PLAYER_POS.z - 22.0)
		group.append(enemy)
	var result: Dictionary = {"spread": 0.0, "min_x": 0.0, "max_x": 0.0, "arrived": 0}
	var sampled: bool = false
	var arrived: Dictionary = {}
	for tick: int in 1500:
		await physics_frame
		var mean_distance: float = 0.0
		for enemy in group:
			mean_distance += enemy.global_position.distance_to(PLAYER_POS)
			if enemy.global_position.distance_to(PLAYER_POS) < 4.5:
				arrived[enemy] = true
		mean_distance /= float(group.size())
		if not sampled and mean_distance <= 14.0:
			sampled = true
			var low: float = INF
			var high: float = -INF
			for enemy in group:
				low = minf(low, enemy.global_position.x)
				high = maxf(high, enemy.global_position.x)
			result["spread"] = high - low
			result["min_x"] = low
			result["max_x"] = high
		if sampled and arrived.size() == group.size():
			break
	result["arrived"] = arrived.size()
	await _clear_enemies()
	return result
